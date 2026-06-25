-- Kibishii Showdown
-- Shared/Modules/Utility/CharacterBuilder.luau
--
-- Turns a character folder under Classes.Characters into a usable CharacterDef:
-- requires its Manifest, walks the Moveset (Base / Melee / Movement / Final), calls
-- each move's `Build(memo)`, and registers the resulting (variant) specs with Memo.
-- A move module is `{ Name, Class, Type?, Build(memo) -> spec }`; modules without a
-- valid Build (the WIP stubs) are skipped, not fatal.
--
--   local def = CharacterBuilder.build(charFolder, Memo)
--   def.Moves.Base["Doo Doo Duel"]  -- the registered spec (under name "DooDooDuel")

local CharacterBuilder = {}

-- A spec from defineVariants has `.variants`; a plain move spec has `.phases`.
local function isVariant(spec): boolean
	return type(spec) == "table" and spec.variants ~= nil
end

local function registerSpec(memo, spec)
	if isVariant(spec) then
		memo.registerVariants(spec)
	else
		memo.register(spec)
	end
end

-- Build one move module into a registered spec, or nil if it isn't buildable.
local function buildMove(memo, module: ModuleScript)
	local ok, move = pcall(require, module)
	if not ok then
		warn(("[CharacterBuilder] require failed for %s: %s"):format(module:GetFullName(), tostring(move)))
		return nil
	end
	if type(move) ~= "table" or type(move.Build) ~= "function" then
		return nil -- a stub / data-only module; skip quietly
	end

	local built, spec = pcall(move.Build, memo)
	if not built then
		warn(("[CharacterBuilder] Build() errored for %s: %s"):format(module:GetFullName(), tostring(spec)))
		return nil
	end
	if type(spec) ~= "table" then
		return nil
	end

	registerSpec(memo, spec)
	return move, spec
end

-- Build a whole character. `charFolder` is the Classes.Characters.<Name> folder.
function CharacterBuilder.build(charFolder: Instance, memo)
	local manifestModule = charFolder:FindFirstChild("Manifest")
	local manifest = {}
	if manifestModule then
		local ok, result = pcall(require, manifestModule)
		if ok then
			manifest = result
		else
			warn(("[CharacterBuilder] Manifest errored for %s: %s"):format(charFolder.Name, tostring(result)))
		end
	end

	local def = {
		Name = charFolder.Name,
		Manifest = manifest,
		Folder = charFolder,
		Moves = {}, -- [className] = { [moveName] = spec }
		Movement = {}, -- [moveName] = move module (movement modules use .Build(ctx, memo))
	}

	local moveset = charFolder:FindFirstChild("Moveset")
	if not moveset then
		warn(("[CharacterBuilder] '%s' has no Moveset folder"):format(charFolder.Name))
		return def
	end

	for _, classFolder in moveset:GetChildren() do
		if classFolder:IsA("Folder") then
			local className = classFolder.Name
			-- Movement is structural, not Memo moves -- keep the modules as-is.
			if className == "Movement" then
				for _, module in classFolder:GetDescendants() do
					if module:IsA("ModuleScript") then
						def.Movement[module.Name] = module
					end
				end
			else
				def.Moves[className] = def.Moves[className] or {}
				for _, module in classFolder:GetDescendants() do
					if module:IsA("ModuleScript") then
						local move, spec = buildMove(memo, module)
						if move then
							def.Moves[className][move.Name or module.Name] = spec
						end
					end
				end
			end
		end
	end

	return def
end

-- Build every character under a Characters folder. Returns { [name] = CharacterDef }.
function CharacterBuilder.buildAll(charactersFolder: Instance, memo)
	local catalog = {}
	for _, charFolder in charactersFolder:GetChildren() do
		if charFolder:IsA("Folder") then
			catalog[charFolder.Name] = CharacterBuilder.build(charFolder, memo)
		end
	end
	return catalog
end

return CharacterBuilder
