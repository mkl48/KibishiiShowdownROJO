-- Kibishii Showdown
-- Shared/Modules/Utility/Bootstrap.luau
--
-- The one place boot happens. It locates Junky, reads everything from Utility.Config,
-- auto-injects the side's packages (so modules reach them via context:GetPackage),
-- and calls Junky.Configure. The ServerBootstrap / ClientBootstrap entry scripts do
-- nothing but hand it the folders to discover modules under.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bootstrap = {}

-- Find the Junky package wherever it lives (recommended layout first, then fallbacks).
local function findJunky()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local modules = shared and shared:FindFirstChild("Modules")
	local packages = modules and modules:FindFirstChild("Packages")
	if packages and packages:FindFirstChild("Junky") then
		return require(packages.Junky)
	end
	local flat = ReplicatedStorage:FindFirstChild("Packages")
	if flat and flat:FindFirstChild("Junky") then
		return require(flat.Junky)
	end
	return require(ReplicatedStorage:WaitForChild("Junky"))
end

-- Inject every top-level package under a folder by its own name, so a module can do
-- context:GetPackage("Facet"). Direct children only -- never descends into a package.
local function injectPackages(container, into)
	if not container then
		return
	end
	for _, module in container:GetChildren() do
		if module:IsA("ModuleScript") then
			into[module.Name] = require(module)
		end
	end
end

-- Configure this side. `moduleRoots` = the folders Junky discovers modules under.
function Bootstrap.Configure(moduleRoots: { Instance })
	local Junky = findJunky()
	local sharedModules = ReplicatedStorage:WaitForChild("Shared").Modules
	local Config = require(sharedModules.Utility.Config)

	local inject = {}
	injectPackages(sharedModules:FindFirstChild("Packages"), inject)
	if RunService:IsClient() then
		local clientModules = ReplicatedStorage:WaitForChild("Client").Modules
		injectPackages(clientModules:FindFirstChild("Packages"), inject)
	else
		local serverModules = game:GetService("ServerStorage"):WaitForChild("Modules")
		injectPackages(serverModules:FindFirstChild("Packages"), inject)
	end

	local app = Junky.Configure({
		Junction = Config.Junction,
		Manifest = Config.Manifest,
		ClassPriority = Config.ClassPriority,
		StandalonePriority = Config.StandalonePriority,
		Inject = inject,
		Modules = moduleRoots,
	})

	print(("[Kibishii] booted (%s)"):format(if RunService:IsServer() then "Server" else "Client"))
	return app
end

return Bootstrap
