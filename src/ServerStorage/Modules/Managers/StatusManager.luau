-- Kibishii Showdown
-- server/Modules/Managers/StatusManager.luau
--
-- Server half of the Status domain. It forwards StatusService's authoritative
-- snapshots to each owner, and -- when a player is knocked Down -- ragdolls them with
-- Splint (server-authoritative, replicates to everyone) with an auto-get-up after the
-- respawn delay. Messaging is the Network lib; it listens for the in-process
-- "Status.Changed" signal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)
local Splint = require(ReplicatedStorage.Shared.Modules.Packages.Splint)

local StatusManager = {}

function StatusManager:Start(context)
	local manifest = context:GetPackage("Manifest")
	local downStatus = manifest.Enums.Status.Down

	-- KO recipe: full limp, carry momentum, auto-recover after RespawnDelay.
	Splint.define("KO", {
		type = "Classic",
		joints = "all",
		inheritVelocity = true,
		collisions = true,
		autoRecover = manifest.PlayerSettings.RespawnDelay,
	})

	local ragdolled = {} -- [player] = true (debounce repeated Down snapshots)

	Net:OnSignal("Status.Changed", function(payload)
		local snap = payload.Snapshot
		if not snap then
			return
		end
		Net:ToClient(payload.Player, "Status.Sync", snap)

		if snap.Status == downStatus then
			if not ragdolled[payload.Player] then
				ragdolled[payload.Player] = true
				Net:ToClient(payload.Player, "Status.Down", snap)
				local char = payload.Player.Character
				if char then
					local handle = Splint.apply("KO", char)
					if handle and handle.OnRecovered then
						handle.OnRecovered:Connect(function()
							ragdolled[payload.Player] = nil
						end)
					end
				end
			end
		else
			ragdolled[payload.Player] = nil
		end
	end)
end

return StatusManager
