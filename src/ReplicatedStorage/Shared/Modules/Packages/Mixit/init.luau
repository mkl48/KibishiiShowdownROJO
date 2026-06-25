--!nonstrict
-- Mixit
-- init.luau
-- Plinko Labs
--
-- A timeline-driven animation controller. An "all-in-one" animation is a MIXTAPE: one
-- clip carved into named SCENES (Windup/Active/Recovery...) with STAMPS -- markers that
-- fire as the PLAYHEAD (a normalized 0..1 position) crosses them. That's how you turn a
-- single combo animation into precise game beats: open a hitbox at a stamp, cut on a
-- scene, loop or pause a region.
--
--   Mixit.define("M1Combo", {
--       AnimationId = "rbxassetid://0000001",
--       Duration = 0.9,                  -- seconds for one full pass (if not track-synced)
--       Scene = {
--           Windup   = { Start = 0,   End = 0.2 },
--           Active   = { Start = 0.2, End = 0.5 },
--           Recovery = { Start = 0.5, End = 1.0, Cut = true },  -- auto-cut when it ends
--       },
--   })
--
--   Mixit.stamp("M1Combo", "HitboxOpen", 0.2):next(function(f) Hitbox.open() end)
--   Mixit.stamp("M1Combo", "HitboxClose", 0.5):next(function(f) Hitbox.close() end)
--
--   local deck = Mixit.play("M1Combo", { Animator = humanoidAnimator })
--   deck.onScene:next(function(name) print("scene:", name) end)
--   deck:done():next(function() print("combo finished") end)
--
-- Builders/registration use dot; the hooks + thenables chain with colon (:next), same
-- as Accede everywhere.

local RunService = game:GetService("RunService")
local Accede = require(script.Parent.Accede)

-- ===================================================================== Hook ========
-- A persistent event (stamps/scenes fire every time they're crossed, across loops).

local Hook = {}
Hook.__index = Hook

local function newHook()
	return setmetatable({ _fns = {} }, Hook)
end

function Hook:next(fn) -- subscribe; fires every time
	table.insert(self._fns, fn)
	return function()
		local i = table.find(self._fns, fn)
		if i then
			table.remove(self._fns, i)
		end
	end
end

function Hook:once(fn)
	local disconnect
	disconnect = self:next(function(...)
		disconnect()
		fn(...)
	end)
	return disconnect
end

function Hook:_fire(...)
	for _, fn in table.clone(self._fns) do
		task.spawn(fn, ...)
	end
end

-- ===================================================================== Mixit =======

local Mixit = {}
local _tapes = {} -- [name] = tape

local function getTape(name: string)
	local t = _tapes[name]
	assert(t, "[Mixit] no mixtape named '" .. tostring(name) .. "'")
	return t
end

-- Resolve a stamp position: a number, or a scene name -> that scene's Start.
local function resolvePos(tape, posOrScene): number
	if type(posOrScene) == "number" then
		return posOrScene
	end
	local scene = tape.scenes[posOrScene]
	return scene and scene.Start or 0
end

local function sceneAt(tape, playhead: number): string?
	for name, scene in tape.scenes do
		if playhead >= scene.Start and playhead < scene.End then
			return name
		end
	end
	return nil
end

-- ---- definition ----

function Mixit.define(name: string, config)
	local tape = {
		name = name,
		config = config,
		scenes = config.Scene or {},
		stamps = {}, -- [stampName] = { pos, persistent, hook }
		speed = config.Speed or 1,
		duration = config.Duration or 1,
		deck = nil,
		onCut = newHook(),
		onScene = newHook(),
	}
	_tapes[name] = tape
	return Mixit.tape(name)
end

-- Define a stamp and return its Hook (subscribe with :next). Re-defining updates pos.
function Mixit.stamp(name: string, stampName: string, posOrScene, opts)
	local tape = getTape(name)
	local existing = tape.stamps[stampName]
	local hook = existing and existing.hook or newHook()
	tape.stamps[stampName] = {
		pos = resolvePos(tape, posOrScene),
		persistent = opts and opts.Persistent or false,
		hook = hook,
	}
	return hook
end

function Mixit.onCut(name: string)
	return getTape(name).onCut
end

-- ---- live deck ----

local function stopDeck(tape, kind: string, sceneName: string?)
	local deck = tape.deck
	if not deck then
		return
	end
	if deck._conn then
		deck._conn:Disconnect()
	end
	if deck._track then
		deck._track:Stop(0.1)
	end
	tape.deck = nil
	tape.onCut:_fire({ Type = kind, Name = sceneName, Playhead = deck.playhead })
	if deck._done then
		deck._done(true)
	end
end

-- Advance one frame: move the playhead, fire crossed stamps, scene changes, loop/cut.
local function step(tape, dt: number)
	local deck = tape.deck
	if not deck or deck.paused then
		return
	end
	local prev = deck.playhead

	if deck._track and deck._track.Length > 0 then
		-- Track-synced: the real animation drives the playhead.
		deck.playhead = math.clamp(deck._track.TimePosition / deck._track.Length, 0, 1)
	else
		deck.playhead = prev + (dt / tape.duration) * deck.speed
	end
	local now = deck.playhead

	-- stamps crossed in (prev, now]
	for stampName, stamp in tape.stamps do
		if stamp.pos > prev and stamp.pos <= now and not deck._fired[stampName] then
			deck._fired[stampName] = true
			stamp.hook:_fire({ Stamp = stampName, Playhead = now })
		end
	end

	-- scene change
	local scene = sceneAt(tape, now)
	if scene ~= deck.scene then
		local exited = deck.scene
		deck.scene = scene
		if scene then
			tape.onScene:_fire(scene, exited)
		end
		-- auto-cut when a scene flagged Cut is left behind
		if exited and tape.scenes[exited] and tape.scenes[exited].Cut and now >= tape.scenes[exited].End then
			stopDeck(tape, "Scene", exited)
			return
		end
	end

	-- loop region
	if deck.loop and now >= deck.loop.To then
		deck.playhead = deck.loop.From
		for k in deck._fired do
			if not (tape.stamps[k] and tape.stamps[k].persistent) then
				deck._fired[k] = nil
			end
		end
		return
	end

	-- end of tape
	if now >= 1 then
		deck.playhead = 1
		stopDeck(tape, "End")
	end
end

-- Play a mixtape. opts = { Animator, Pos, Speed }. Returns the live deck.
function Mixit.play(name: string, opts)
	local tape = getTape(name)
	opts = opts or {}
	if tape.deck then
		stopDeck(tape, "Interrupt")
	end

	local deck = {
		playhead = opts.Pos or 0,
		speed = opts.Speed or tape.speed,
		paused = false,
		scene = nil,
		loop = nil,
		_fired = {},
		_track = nil,
		_conn = nil,
		_doneAccede = nil,
		_done = nil,
	}

	-- Optionally load + play the real animation, synced to the playhead.
	if opts.Animator and tape.config.AnimationId then
		local anim = Instance.new("Animation")
		anim.AnimationId = tape.config.AnimationId
		deck._track = opts.Animator:LoadAnimation(anim)
		deck._track.TimePosition = deck.playhead * math.max(deck._track.Length, 0.001)
		deck._track:Play(0.1)
		deck._track:AdjustSpeed(deck.speed)
	end

	deck.onScene = tape.onScene
	deck.onCut = tape.onCut

	function deck:seek(pos: number)
		self.playhead = math.clamp(pos, 0, 1)
		if self._track and self._track.Length > 0 then
			self._track.TimePosition = self.playhead * self._track.Length
		end
		table.clear(self._fired)
	end

	function deck:setLoop(from, to)
		self.loop = { From = resolvePos(tape, from), To = resolvePos(tape, to) }
	end

	function deck:pause()
		self.paused = true
		if self._track then
			self._track:AdjustSpeed(0)
		end
	end

	function deck:resume()
		self.paused = false
		if self._track then
			self._track:AdjustSpeed(self.speed)
		end
	end

	function deck:cut()
		stopDeck(tape, "Manual")
	end

	function deck:done()
		if not self._doneAccede then
			self._doneAccede = Accede.new(function(resolve)
				self._done = resolve
			end)
		end
		return self._doneAccede
	end

	tape.deck = deck
	deck._conn = RunService.Heartbeat:Connect(function(dt)
		step(tape, dt)
	end)
	return deck
end

function Mixit.seek(name: string, pos: number)
	local deck = getTape(name).deck
	if deck then
		deck:seek(pos)
	end
end

function Mixit.cut(name: string)
	local tape = getTape(name)
	if tape.deck then
		stopDeck(tape, "Manual")
	end
end

function Mixit.loop(name: string, from, to)
	local deck = getTape(name).deck
	if deck then
		deck:setLoop(from, to)
	end
end

-- Mutate config (Speed / Scene) at runtime without losing the playhead.
function Mixit.tamper(name: string, changes)
	local tape = getTape(name)
	if changes.Speed then
		tape.speed = changes.Speed
		if tape.deck then
			tape.deck.speed = changes.Speed
			if tape.deck._track then
				tape.deck._track:AdjustSpeed(tape.deck.paused and 0 or changes.Speed)
			end
		end
	end
	if changes.Scene then
		for sceneName, patch in changes.Scene do
			tape.scenes[sceneName] = tape.scenes[sceneName] or {}
			for k, v in patch do
				tape.scenes[sceneName][k] = v
			end
		end
	end
end

-- A pre-bound interface so you don't repeat the mixtape name.
function Mixit.tape(name: string)
	return {
		play = function(opts) return Mixit.play(name, opts) end,
		seek = function(pos) Mixit.seek(name, pos) end,
		cut = function() Mixit.cut(name) end,
		loop = function(from, to) Mixit.loop(name, from, to) end,
		stamp = function(stampName, posOrScene, opts) return Mixit.stamp(name, stampName, posOrScene, opts) end,
		onCut = function() return Mixit.onCut(name) end,
		tamper = function(changes) Mixit.tamper(name, changes) end,
	}
end

return Mixit
