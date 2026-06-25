--!strict
-- Splint
-- Handle.luau
-- Plinko Labs
--
-- One live ragdoll on one character. :engage() swaps joints + sets up the Humanoid,
-- velocity, collisions and (Active) an upright-fighting force; :recover() puts it all
-- back. Server-authoritative: on engage the server takes network ownership of the
-- assembly so its physics is the truth and replicates to clients automatically.

local RunService = game:GetService("RunService")

local Rig = require(script.Parent.Rig)
local Collision = require(script.Parent.Collision)
local Replication = require(script.Parent.Replication)
local Signal = require(script.Parent.Signal)
local Types = require(script.Parent.Types)

type Config = Types.Config

local Handle = {}
Handle.__index = Handle

function Handle.new(config: Config, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return setmetatable({
		Config = config,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Active = false,
		_records = {},
		_collided = {}, -- [part] = previous CanCollide
		_upright = nil :: AlignOrientation?,
		_recoverThread = nil :: thread?,
		_streamThread = nil :: thread?,
		OnRecovered = Signal.new(),
		OnEngaged = Signal.new(),
	}, Handle)
end

function Handle:engage()
	if self.Active then
		return self
	end
	self.Active = true
	local cfg = self.Config
	local char = self.Character
	local humanoid = self.Humanoid
	local root = self.Root

	-- 1. capture momentum before joints break the assembly apart
	local inheritedV = Vector3.zero
	if cfg.inheritVelocity and root then
		inheritedV = root.AssemblyLinearVelocity
	end

	-- 2. Humanoid into a physics state so it stops trying to stand / animate over us
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end

	-- 3. limp the masked joints
	for _, motor in Rig.discover(char, cfg.joints) do
		local rec = Rig.limp(motor)
		if rec then
			table.insert(self._records, rec)
		end
	end

	-- 4. collisions + network ownership (server is authoritative)
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			if cfg.collisions then
				self._collided[p] = p.CanCollide
				p.CanCollide = true
				Collision.assign(p)
			end
			if RunService:IsServer() and not p.Anchored then
				pcall(function()
					p:SetNetworkOwner(nil)
				end)
			end
		end
	end

	-- 5. carry momentum into the now-loose limbs
	if cfg.inheritVelocity and inheritedV.Magnitude > 0 then
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") and not p.Anchored then
				p.AssemblyLinearVelocity = inheritedV
			end
		end
	end

	-- 6. Active: fight back toward upright so it staggers instead of fainting
	if cfg.type == "Active" and root then
		local att = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
		local ao = Instance.new("AlignOrientation")
		ao.Name = "SplintUpright"
		ao.Attachment0 = att
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.RigidityEnabled = false
		ao.MaxTorque = cfg.uprightForce or 6000
		ao.Responsiveness = 30
		ao.CFrame = CFrame.new()
		ao.Parent = root
		self._upright = ao
	end

	if cfg.autoRecover then
		self._recoverThread = task.delay(cfg.autoRecover, function()
			self:recover()
		end)
	end

	self.OnEngaged:Fire()
	return self
end

function Handle:recover()
	if not self.Active then
		return
	end
	self.Active = false

	if self._streamThread then
		task.cancel(self._streamThread)
		self._streamThread = nil
	end
	if self._upright then
		self._upright:Destroy()
		self._upright = nil
	end

	for _, rec in self._records do
		Rig.restore(rec)
	end
	table.clear(self._records)

	for part, prev in self._collided do
		if part.Parent then
			part.CanCollide = prev
			Collision.clear(part)
		end
	end
	table.clear(self._collided)

	local humanoid = self.Humanoid
	if humanoid and humanoid.Parent then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	self.OnRecovered:Fire()
end

-- Stream limb CFrames at `rate` Hz to `send`. Wire `send` to a remote/Chrono; apply
-- on clients with Splint.applySnapshot. Server-only.
function Handle:startStreaming(send: (Types.Snapshot) -> (), rate: number?)
	if not RunService:IsServer() or self._streamThread then
		return
	end
	local parts = Replication.trackedParts(self.Character)
	local interval = 1 / (rate or 20)
	self._streamThread = task.spawn(function()
		while self.Active do
			send(Replication.snapshot(parts))
			task.wait(interval)
		end
	end)
end

function Handle:destroy()
	self:recover()
	self.OnRecovered:DisconnectAll()
	self.OnEngaged:DisconnectAll()
end

return Handle
