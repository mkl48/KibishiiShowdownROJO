--!strict
-- Splint
-- Collision.luau
-- Plinko Labs
--
-- One collision group for all ragdoll limbs, set non-collidable with itself so a
-- limp body doesn't jitter against its own parts while still hitting the world.
-- Registration is server-only (PhysicsService); the CollisionGroup property then
-- replicates to clients.

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local GROUP = "SplintRagdoll"
local registered = false

local Collision = {}

function Collision.ensure()
	if registered or not RunService:IsServer() then
		return
	end
	registered = true
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
		PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	end)
end

function Collision.assign(part: BasePart)
	Collision.ensure()
	pcall(function()
		part.CollisionGroup = GROUP
	end)
end

function Collision.clear(part: BasePart)
	pcall(function()
		part.CollisionGroup = "Default"
	end)
end

return Collision
