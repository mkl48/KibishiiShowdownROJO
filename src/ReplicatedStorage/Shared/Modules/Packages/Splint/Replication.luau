--!strict
-- Splint
-- Replication.luau
-- Plinko Labs
--
-- Server-authoritative ragdoll: the server owns the assembly and Roblox replicates
-- the physics for free. This module is the OPTIONAL precision layer on top -- sample
-- limb CFrames into a snapshot, ship the delta over your own transport (a remote, or
-- Chrono), and apply it on clients for tight, lag-compensated visuals. Core works
-- without it; wire it when you want frame-tight ragdolls.

local Types = require(script.Parent.Types)
type Snapshot = Types.Snapshot

local Replication = {}

-- Parts worth streaming (skip massless cosmetics). Returns ordered BaseParts.
function Replication.trackedParts(character: Model): { BasePart }
	local parts = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and not d.Massless then
			table.insert(parts, d)
		end
	end
	return parts
end

function Replication.snapshot(parts: { BasePart }): Snapshot
	local snap: Snapshot = {}
	for _, p in parts do
		snap[p.Name] = p.CFrame
	end
	return snap
end

-- Apply a snapshot to a character (client side). Anchors briefly to avoid fighting
-- local physics, sets the CFrame, then releases.
function Replication.apply(character: Model, snap: Snapshot)
	for name, cf in snap do
		local p = character:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			p.CFrame = cf
		end
	end
end

return Replication
