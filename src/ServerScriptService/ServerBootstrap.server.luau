-- Kibishii Showdown
-- ServerScriptService/ServerBootstrap (Script)
--
-- The single server entry point. All the real work lives in Utility.Bootstrap;
-- this just points it at the folders Junky discovers server modules under.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Bootstrap = require(ReplicatedStorage:WaitForChild("Shared").Modules.Utility.Bootstrap)

Bootstrap.Configure({
	ServerStorage:WaitForChild("Modules"), -- Managers (+ any server Packages/Utility)
	ReplicatedStorage.Shared.Modules.Services, -- shared Services boot on the server
})
