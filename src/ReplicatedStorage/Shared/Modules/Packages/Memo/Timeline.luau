local Signal = require(script.Parent.Signal)
local Promise = require(script.Parent.Promise)
local Types = require(script.Parent.Types)

type MoveSpec = Types.MoveSpec
type PhaseDescriptor = Types.PhaseDescriptor
type TrackDescriptor = Types.TrackDescriptor
type DriveMode = Types.DriveMode
type CrossfadeConfig = Types.CrossfadeConfig
type CancelWindow = Types.CancelWindow
type CounterWindow = Types.CounterWindow
type Ctx = Types.Ctx

local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()

local function sideAllowed(side: Types.TrackSide): boolean
	if side == "shared" then return true end
	if side == "server" and IS_SERVER then return true end
	if side == "client" and not IS_SERVER then return true end
	return false
end

local function resolveDrive(mode: DriveMode, onDone: () -> ()): () -> ()
	local cancelled = false
	local cleanup = function() cancelled = true end

	if mode.kind == "time" then
		local conn
		local elapsed = 0
		conn = RunService.Heartbeat:Connect(function(dt)
			if cancelled then conn:Disconnect() return end
			elapsed += dt
			if elapsed >= mode.duration then
				conn:Disconnect()
				if not cancelled then onDone() end
			end
		end)
		cleanup = function()
			cancelled = true
			conn:Disconnect()
		end

	elseif mode.kind == "frames" then
		local remaining = mode.count
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if cancelled then conn:Disconnect() return end
			remaining -= 1
			if remaining <= 0 then
				conn:Disconnect()
				if not cancelled then onDone() end
			end
		end)
		cleanup = function()
			cancelled = true
			conn:Disconnect()
		end

	elseif mode.kind == "gate" then
		local conn = mode.signal:Once(function()
			if not cancelled then onDone() end
		end)
		cleanup = function()
			cancelled = true
			if conn then conn:Disconnect() end
		end

	elseif mode.kind == "any" then
		local done = false
		local cleanups: { () -> () } = {}
		local function tryDone()
			if done or cancelled then return end
			done = true
			for _, c in cleanups do pcall(c) end
			onDone()
		end
		for _, sub in mode.modes do
			table.insert(cleanups, resolveDrive(sub, tryDone))
		end
		cleanup = function()
			cancelled = true
			for _, c in cleanups do pcall(c) end
		end

	elseif mode.kind == "all" then
		local remaining = #mode.modes
		local cleanups: { () -> () } = {}
		local function tryDone()
			if cancelled then return end
			remaining -= 1
			if remaining <= 0 then
				for _, c in cleanups do pcall(c) end
				onDone()
			end
		end
		for _, sub in mode.modes do
			table.insert(cleanups, resolveDrive(sub, tryDone))
		end
		cleanup = function()
			cancelled = true
			for _, c in cleanups do pcall(c) end
		end
	end

	return cleanup
end

local function runTrackTick(track: TrackDescriptor, ctx: Ctx): (() -> ())?
	if not sideAllowed(track.side) then return nil end
	if track.onEnter then
		local ok, err = pcall(track.onEnter, ctx)
		if not ok then warn("[Memo] track.onEnter:", err) end
	end

	local tickConn: RBXScriptConnection? = nil
	if track.onTick then
		local fn = track.onTick
		tickConn = RunService.Heartbeat:Connect(function(dt)
			local ok, err = pcall(fn, ctx, dt)
			if not ok then warn("[Memo] track.onTick:", err) end
		end)
	end

	return function()
		if tickConn then tickConn:Disconnect() end
		if track.onExit and sideAllowed(track.side) then
			local ok, err = pcall(track.onExit, ctx)
			if not ok then warn("[Memo] track.onExit:", err) end
		end
	end
end

local function findPhaseIndex(spec: MoveSpec, name: string): number?
	for i, p in spec.phases do
		if p.name == name then return i end
	end
	return nil
end

local function windowActive(w: CancelWindow, phase: string, elapsed: number): boolean
	if w.phase ~= phase then return false end
	if w.from and elapsed < w.from then return false end
	if w.to and elapsed > w.to then return false end
	return true
end

export type Timeline = {
	_spec: MoveSpec,
	_ctx: Ctx,
	_active: boolean,
	_currentPhase: string?,
	_phaseIndex: number,
	_phaseElapsed: number,
	_driveCleanup: (() -> ())?,
	_trackCleanups: { () -> () },
	_counterCleanup: (() -> ())?,
	_tickConn: RBXScriptConnection?,

	onPhaseChanged: any,
	onCompleted: any,
	onInterrupted: any,
	onCancelled: any,
	onCounter: any,

	_advancePhase: (self: Timeline) -> (),
	_enterPhase: (self: Timeline, phase: PhaseDescriptor) -> (),
	_exitCurrentPhase: (self: Timeline) -> (),
	_bindCounter: (self: Timeline, counter: CounterWindow) -> (),
	interrupt: (self: Timeline, crossfade: CrossfadeConfig?) -> (),
	cancel: (self: Timeline, windowName: string, crossfade: CrossfadeConfig?) -> boolean,
	isActive: (self: Timeline) -> boolean,
	getPhase: (self: Timeline) -> string?,
}

local Timeline = {}
Timeline.__index = Timeline

function Timeline._bindCounter(self: Timeline, counter: CounterWindow)
	if self._counterCleanup then
		self._counterCleanup()
		self._counterCleanup = nil
	end

	local conn = counter.signal:Connect(function(attacker: any)
		if not self._active then return end

		if counter.onTriggered then
			pcall(counter.onTriggered, self._ctx, attacker)
		end

		local targetMove: string? = counter.punishMove
		if counter.resolver then
			local ok, result = pcall(counter.resolver, self._ctx, attacker)
			if ok then targetMove = result end
		end

		self.onCounter:Fire({
			attacker = attacker,
			punishMove = targetMove,
			crossfade = counter.crossfade or self._spec.defaultCrossfade,
		})

		self:interrupt(counter.crossfade)
	end)

	self._counterCleanup = function()
		conn:Disconnect()
	end
end

function Timeline._exitCurrentPhase(self: Timeline)
	if self._counterCleanup then
		self._counterCleanup()
		self._counterCleanup = nil
	end
	if self._driveCleanup then
		self._driveCleanup()
		self._driveCleanup = nil
	end
	for _, cleanup in self._trackCleanups do
		pcall(cleanup)
	end
	table.clear(self._trackCleanups)

	local phase = self._spec.phases[self._phaseIndex]
	if phase and phase.onExit then
		pcall(phase.onExit, self._ctx)
	end
end

function Timeline._enterPhase(self: Timeline, phase: PhaseDescriptor)
	self._currentPhase = phase.name
	self._phaseElapsed = 0
	self.onPhaseChanged:Fire(phase.name)

	if phase.onEnter then
		pcall(phase.onEnter, self._ctx)
	end

	for _, track in phase.tracks do
		local cleanup = runTrackTick(track, self._ctx)
		if cleanup then
			table.insert(self._trackCleanups, cleanup)
		end
	end

	if phase.counter then
		self:_bindCounter(phase.counter)
	end

	self._driveCleanup = resolveDrive(phase.drive, function()
		if self._active then
			self:_advancePhase()
		end
	end)

	if self._tickConn then
		self._tickConn:Disconnect()
	end
	self._tickConn = RunService.Heartbeat:Connect(function(dt)
		self._phaseElapsed += dt
	end)
end

function Timeline._advancePhase(self: Timeline)
	if self._tickConn then
		self._tickConn:Disconnect()
		self._tickConn = nil
	end
	self:_exitCurrentPhase()
	self._phaseIndex += 1

	local nextPhase = self._spec.phases[self._phaseIndex]
	if nextPhase then
		self:_enterPhase(nextPhase)
	else
		self._active = false
		self._currentPhase = nil
		self.onCompleted:Fire(nil)
	end
end

function Timeline.interrupt(self: Timeline, crossfade: CrossfadeConfig?)
	if not self._active then return end
	self._active = false
	if self._tickConn then
		self._tickConn:Disconnect()
		self._tickConn = nil
	end
	self:_exitCurrentPhase()
	self._currentPhase = nil
	self.onInterrupted:Fire(crossfade or self._spec.defaultCrossfade)
end

function Timeline.cancel(self: Timeline, windowName: string, crossfade: CrossfadeConfig?): boolean
	if not self._active or not self._currentPhase then return false end

	local matchedWindow: CancelWindow? = nil
	for _, w in self._spec.windows do
		if w.name == windowName and windowActive(w, self._currentPhase, self._phaseElapsed) then
			matchedWindow = w
			break
		end
	end

	if not matchedWindow then return false end

	local route: Types.BranchRoute? = nil
	for _, r in self._spec.routes do
		if r.from == windowName then
			route = r
			break
		end
	end

	local cf = crossfade or (route and route.crossfade) or self._spec.defaultCrossfade
	local entryPhase = (route and route.entryPhase) or matchedWindow.entryPhase

	self._active = false
	if self._tickConn then
		self._tickConn:Disconnect()
		self._tickConn = nil
	end
	self:_exitCurrentPhase()
	self._currentPhase = nil

	self.onCancelled:Fire({
		window = matchedWindow,
		route = route,
		crossfade = cf,
		entryPhase = entryPhase,
	})

	return true
end

function Timeline.isActive(self: Timeline): boolean
	return self._active
end

function Timeline.getPhase(self: Timeline): string?
	return self._currentPhase
end

local function new(spec: MoveSpec, ctx: Ctx): Timeline
	local self: Timeline = setmetatable({
		_spec = spec,
		_ctx = ctx,
		_active = false,
		_currentPhase = nil,
		_phaseIndex = 0,
		_phaseElapsed = 0,
		_driveCleanup = nil,
		_trackCleanups = {},
		_counterCleanup = nil,
		_tickConn = nil,
		onPhaseChanged = Signal.new(),
		onCompleted = Signal.new(),
		onInterrupted = Signal.new(),
		onCancelled = Signal.new(),
		onCounter = Signal.new(),
	}, Timeline) :: any

	return self
end

local function start(spec: MoveSpec, ctx: Ctx): (Timeline, typeof(Promise.new(function() end)))
	local tl = new(spec, ctx)
	local promise = Promise.new(function(resolve, reject)
		tl._active = true
		local first = spec.phases[1]
		if not first then
			tl._active = false
			reject("MoveSpec has no phases")
			return
		end
		tl._phaseIndex = 1
		tl:_enterPhase(first)
		resolve(tl)
	end)
	return tl, promise
end

local function startAt(spec: MoveSpec, ctx: Ctx, phaseName: string): (Timeline, typeof(Promise.new(function() end)))
	local tl = new(spec, ctx)
	local promise = Promise.new(function(resolve, reject)
		local idx: number? = nil
		for i, p in spec.phases do
			if p.name == phaseName then idx = i break end
		end
		if not idx then
			reject("Phase not found: " .. phaseName)
			return
		end
		tl._active = true
		tl._phaseIndex = idx
		tl:_enterPhase(spec.phases[idx])
		resolve(tl)
	end)
	return tl, promise
end

return { new = new, start = start, startAt = startAt }