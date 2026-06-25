local Players = game:GetService("Players")

local PlayerService = {}

local _NetworkController: any
local _Switchboard: any
local _Enums: any

local _PlayerServiceSwitch: any

type PlayerExport = {
	Profile : {any},
	Session : {any},
	Instance : Player
}

local function CreatePlayer(SessionInfo, InstanceInfo)

end

function PlayerService.Start(ctx)
	warn("PlayerService")
	_NetworkController = ctx.GetManager("NetworkManager")
	_Switchboard = _NetworkController.GetServiceBoard()
	_Enums = ctx.Enums
	_PlayerServiceSwitch = _Switchboard:Get("PlayerService")


	_NetworkController.Subscribe(_PlayerServiceSwitch, function(player, payload)
		warn("PlayerService ->", player, payload)
	end)
	
	Players.PlayerAdded:Connect(function(Player)
		_NetworkController.Post(_PlayerServiceSwitch, Player, {
			Term = _Enums.Term.PlayerService.ClientPayload,
			Data = {
				Message = "Test Message"	
			}
		})
	end)

end

function PlayerService.GetPlayer()

end

return PlayerService