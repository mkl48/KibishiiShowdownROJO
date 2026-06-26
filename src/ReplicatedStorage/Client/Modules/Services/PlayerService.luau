-- Kibishii Showdown
-- Client/Modules/Services/PlayerService.luau
--
-- Client half of the Player domain. Converted from the old Switchboard API to Junky's
-- Context. Receives the server's Welcome payload; send up to the server with
-- context:Network("Player"):Post("Message", ...). Same domain name as the server half
-- -- they're side-split, so "PlayerService" resolves per side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local PlayerService = {}

function PlayerService:Start(_context)
	-- server -> client: the welcome payload.
	Net:OnServer("Player.Welcome", function(payload)
		warn("[PlayerService] welcome:", payload and payload.Message)
	end)
end

function PlayerService:GetPlayer()
	-- session accessor stub (client mirror of server session, when wired)
end

return PlayerService
