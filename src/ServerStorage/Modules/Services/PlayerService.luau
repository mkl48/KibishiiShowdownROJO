-- Kibishii Showdown
-- ServerStorage/Modules/Services/PlayerService.luau
--
-- Owns player sessions (join/leave; profile data slots in later). Converted from the
-- old Switchboard/NetworkController API to Junky's Context: networking goes through
-- context:Network, and there's no ctx.GetManager/ctx.Enums -- enums live in the
-- Manifest (context:GetPackage("Manifest")). CreatePlayer/GetPlayer are the session
-- stubs to fill in when data (Keep/Pik) is wired.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local PlayerService = {}
PlayerService.Sessions = {} -- [player] = PlayerExport

export type PlayerExport = {
	Profile: { any }?,
	Session: { any },
	Instance: Player,
}

function PlayerService:Start(context)
	self._context = context

	-- client -> server: a player message (Net puts the sending player first).
	Net:OnClient("Player.Message", function(player, payload)
		warn("[PlayerService] message from", player.Name, payload)
	end)

	local function onPlayer(player: Player)
		self:CreatePlayer(player)
		-- server -> that client: welcome payload.
		Net:ToClient(player, "Player.Welcome", { Message = "Test Message" })
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		self.Sessions[player] = nil
	end)
end

function PlayerService:CreatePlayer(player: Player): PlayerExport
	local export: PlayerExport = { Instance = player, Profile = nil, Session = {} }
	self.Sessions[player] = export
	return export
end

function PlayerService:GetPlayer(player: Player): PlayerExport?
	return self.Sessions[player]
end

return PlayerService
