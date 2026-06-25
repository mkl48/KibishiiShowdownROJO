-- Kibishii Showdown
-- Shared/Modules/Services/CharacterService.luau
--
-- Owns the character catalog and each player's chosen character. At boot it builds
-- every character under Classes.Characters (registering their moves with Memo), then
-- answers the client's "List" and "Select" requests. Other server systems read a
-- player's pick + moveset through Get* -- e.g. an AbilityManager asks for the spec
-- to execute. Selection here is the kit/moveset; applying a model is a later step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Shared.Modules.Packages
local Memo = require(Packages.Memo)
local CharacterBuilder = require(ReplicatedStorage.Shared.Modules.Utility.CharacterBuilder)

local CharacterService = {}
CharacterService.Catalog = {} -- [name] = CharacterDef
CharacterService.Selected = {} -- [player] = characterName

function CharacterService:Start(context)
	self._context = context

	-- Build every character once; this registers all their moves with Memo.
	local charactersFolder = ReplicatedStorage.Shared.Classes:FindFirstChild("Characters")
	if charactersFolder then
		self.Catalog = CharacterBuilder.buildAll(charactersFolder, Memo)
		print(("[CharacterService] built %d character(s)"):format(self:Count()))
	else
		warn("[CharacterService] no Classes.Characters folder found")
	end

	local Character = context:Network("Character")

	-- client -> server request: the selectable characters.
	Character:Respond("List", function()
		return self:Names()
	end)

	-- client -> server request: pick a character. Returns { ok, character?, reason? }.
	Character:Respond("Select", function(payload, player)
		local name = type(payload) == "table" and payload.Name or payload
		return self:Select(player, name)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.Selected[player] = nil
	end)
end

function CharacterService:Count(): number
	local n = 0
	for _ in self.Catalog do
		n += 1
	end
	return n
end

function CharacterService:Names(): { string }
	local names = {}
	for name in self.Catalog do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function CharacterService:GetDef(name: string)
	return self.Catalog[name]
end

-- Record a player's choice. Authoritative: refuses unknown characters.
function CharacterService:Select(player: Player, name: string?)
	if not name or not self.Catalog[name] then
		return { ok = false, reason = "Unknown character: " .. tostring(name) }
	end
	self.Selected[player] = name
	print(("[CharacterService] %s selected %s"):format(player.Name, name))
	return { ok = true, character = name }
end

function CharacterService:GetSelected(player: Player): string?
	return self.Selected[player]
end

-- The built CharacterDef a player is currently playing. Falls back to a default
-- character if they haven't chosen yet, so combat works before the select UI exists.
function CharacterService:GetPlayerDef(player: Player)
	local name = self.Selected[player] or self:DefaultName()
	return name and self.Catalog[name] or nil
end

function CharacterService:DefaultName(): string?
	return self:Names()[1]
end

-- Look up a registered move spec for a player by class + move name (for executors).
function CharacterService:GetMove(player: Player, class: string, moveName: string)
	local def = self:GetPlayerDef(player)
	local byClass = def and def.Moves[class]
	return byClass and byClass[moveName] or nil
end

return CharacterService
