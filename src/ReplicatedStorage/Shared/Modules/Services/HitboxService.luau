-- Kibishii Showdown
-- Shared/Modules/Services/HitboxService.luau
--
-- The `ctx.hitbox` that move hitbox-tracks call. A move does
-- `ctx.hitbox:spawn("PlungerSwing1", ctx.character, { damage, knockback, hitlag })`
-- on a phase enter and `ctx.hitbox:stop("PlungerSwing1")` on exit. We hand out a
-- per-character wrapper (so ids are scoped to the caster), sweep for targets each
-- frame while a box is live, and route every hit through StatusService -- then reuse
-- the combat spine's Combat.Hit so victims get the same knockback/ragdoll reaction.
-- Server-authoritative: only ever runs on the server (hitbox tracks are side="server").

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local DEFAULT_RANGE = 8
local FRONT_DOT = 0.2 -- forward cone leniency

local HitboxService = {}

function HitboxService:Start(context)
	self._context = context
	self._wrappers = setmetatable({}, { __mode = "k" }) -- [character] = wrapper (weak)
end

-- Per-character hitbox wrapper. ids are unique within one character's casts.
function HitboxService:For(character: Model)
	local existing = self._wrappers[character]
	if existing then
		return existing
	end

	local service = self
	local active: { [string]: RBXScriptConnection } = {}
	local wrapper = {}

	wrapper.spawn = function(_, id: string, char: Model?, params)
		char = char or character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		if active[id] then
			active[id]:Disconnect()
		end

		local hitSet: { [Player]: boolean } = {}
		local range = (params and params.range) or DEFAULT_RANGE
		active[id] = RunService.Heartbeat:Connect(function()
			if not root.Parent then
				return
			end
			service:_sweep(char, root, params, hitSet, range)
		end)
	end

	wrapper.stop = function(_, id: string)
		local conn = active[id]
		if conn then
			conn:Disconnect()
			active[id] = nil
		end
	end

	wrapper.stopAll = function()
		for id, conn in active do
			conn:Disconnect()
			active[id] = nil
		end
	end

	self._wrappers[character] = wrapper
	return wrapper
end

-- One detection sweep: any new player in the forward cone takes the hit once.
function HitboxService:_sweep(attackerChar: Model, root: BasePart, params, hitSet, range: number)
	local Status = self._context:GetService("StatusService")
	local origin = root.Position
	local look = root.CFrame.LookVector

	for _, player in Players:GetPlayers() do
		local targetChar = player.Character
		local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetChar and targetRoot and targetChar ~= attackerChar and not hitSet[player] then
			local offset = targetRoot.Position - origin
			local dist = offset.Magnitude
			if dist <= range and (dist == 0 or look:Dot(offset.Unit) > FRONT_DOT) then
				hitSet[player] = true

				local kb = params and params.knockback
				local force = typeof(kb) == "Vector3" and kb.Magnitude or 0
				local dir = if dist > 0 then offset.Unit else look

				local result = Status:ApplyHit(player, {
					Damage = (params and params.damage) or 0,
					Stun = ((params and params.hitlag) or 0) * 0.02,
					Knockback = if force > 0 then { Direction = dir, Force = force } else nil,
				})
				if result then
					-- Reuse the combat spine: the victim's CombatController plays the
					-- knockback/ragdoll reaction from this authoritative result.
					Net:ToClient(player, "Combat.Hit", result)
				end
			end
		end
	end
end

return HitboxService
