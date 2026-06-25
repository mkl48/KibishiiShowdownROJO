-- Kibishii Showdown
-- server/Modules/Services/PlayerService.luau
--
-- Owns player sessions. For the spine it just announces when a character is ready
-- to fight so StatusService can initialize that player's combat slice. Real profile
-- persistence (unlocks, currency, stats) slots in here later via config.Inject.

local Players = game:GetService("Players")

local PlayerService = {}

function PlayerService:Start(context)
	local Data = context:Local("Data")
	local manifest = context:GetPackage("Manifest")

	-- Announce a fightable character. StatusService subscribes to Data.Loaded.
	local function announce(player: Player)
		Data:Post("Loaded", {
			Player = player,
			MaxHealth = manifest.PlayerSettings.MaxHealth,
		})
	end

	local function onPlayer(player: Player)
		if player.Character then
			announce(player)
		end
		player.CharacterAdded:Connect(function()
			announce(player)
		end)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return PlayerService
