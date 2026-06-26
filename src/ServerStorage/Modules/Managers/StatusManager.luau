-- Kibishii Showdown
-- server/Modules/Managers/StatusManager.luau
--
-- Server half of the Status domain. It owns no state -- it forwards StatusService's
-- authoritative snapshots to the right client. The bridge between the server's truth
-- (StatusService) and each client's view. Messaging via the Network lib: it listens
-- for the in-process "Status.Changed" signal and pushes "Status.*" to the owner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local StatusManager = {}

function StatusManager:Start(context)
	local downStatus = context:GetPackage("Manifest").Enums.Status.Down

	-- A slice changed server-side (same-side signal) -> push it to the owner client.
	Net:OnSignal("Status.Changed", function(payload)
		if payload.Snapshot then
			Net:ToClient(payload.Player, "Status.Sync", payload.Snapshot)
			if payload.Snapshot.Status == downStatus then
				Net:ToClient(payload.Player, "Status.Down", payload.Snapshot)
			end
		end
	end)
end

return StatusManager
