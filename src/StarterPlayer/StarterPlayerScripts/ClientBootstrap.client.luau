-- Kibishii Showdown
-- StarterPlayer/StarterPlayerScripts/ClientBootstrap (LocalScript)
--
-- The single client entry point. Defers to Utility.Bootstrap, passing the folders
-- Junky discovers client modules under.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bootstrap = require(ReplicatedStorage:WaitForChild("Shared").Modules.Utility.Bootstrap)
local ClientModules = ReplicatedStorage:WaitForChild("Client").Modules

Bootstrap.Configure({
	ClientModules.Controllers,
	ClientModules.Services,
})
