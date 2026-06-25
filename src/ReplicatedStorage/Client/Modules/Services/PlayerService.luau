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
	_NetworkController = ctx.GetController("NetworkController")
	_Switchboard = _NetworkController.GetServiceBoard()
	_Enums = ctx.Enums
	_PlayerServiceSwitch = _Switchboard:Get("PlayerService")
	
	warn(_PlayerServiceSwitch)
	_NetworkController.Subscribe(_PlayerServiceSwitch, function(Payload, P2)
		warn("PlayerService ->", Payload, P2)
	end)
end

function PlayerService.GetPlayer()

end

return PlayerService