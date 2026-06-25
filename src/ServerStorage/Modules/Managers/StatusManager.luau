-- Kibishii Showdown
-- server/Modules/Managers/StatusManager.luau
--
-- Server half of the Status domain. It owns no state -- it forwards StatusService's
-- authoritative snapshots to the right client and answers state queries. The bridge
-- between the server's truth (StatusService) and each client's view.

local StatusManager = {}

function StatusManager:Start(context)
	local Network = context:Network("Status")
	local StatusLocal = context:Local("Status")
	local downStatus = context:GetPackage("Manifest").Enums.Status.Down

	-- A slice changed server-side -> push the fresh snapshot to its owner.
	StatusLocal:Subscribe("Changed", function(payload)
		if payload.Snapshot then
			Network:PostTo(payload.Player, "Sync", payload.Snapshot)
			if payload.Snapshot.Status == downStatus then
				Network:PostTo(payload.Player, "Down", payload.Snapshot)
			end
		end
	end)
end

return StatusManager
