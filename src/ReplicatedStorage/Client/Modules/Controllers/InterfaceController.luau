-- Kibishii Showdown
-- Client/Modules/Controllers/InterfaceController.luau
--
-- SCAFFOLD -- the data plumbing is wired; the UI is YOURS to build (Icon / Sleek).
-- This controller owns the screens: character-select and the combat HUD. Everything
-- that talks to the server already works (list characters, send a pick, receive HUD
-- snapshots); the `_build*` / `_refresh*` methods are intentionally empty TODOs for
-- you to fill with actual widgets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local InterfaceController = {}

function InterfaceController:Start(context)
	self._context = context
	self._selected = nil :: string?

	-- HUD: StatusController fans the snapshot out on the Hud.Refresh signal.
	Net:OnSignal("Hud.Refresh", function(snapshot)
		self._latest = snapshot
		self:_refreshHud(snapshot)
	end)

	-- Pull the roster, then hand it to your select screen.
	self:RequestCharacterList()
		:next(function(names)
			self:_buildCharacterSelect(names)
		end)
		:toss(function(err)
			warn("[InterfaceController] character list failed:", err)
		end)

	self:_buildHud()
end

-- ===== data flow (DONE -- call these from your UI) =====

-- Ask the server for the selectable characters. Resolves with { string }.
function InterfaceController:RequestCharacterList()
	return Net:Ask("Character.List")
end

-- Tell the server which character the player picked. Resolves with
-- { ok = boolean, character?, reason? }. Updates local state on success.
function InterfaceController:SelectCharacter(name: string)
	return Net:Ask("Character.Select", { Name = name })
		:next(function(result)
			if result and result.ok then
				self._selected = result.character
			end
			return result
		end)
end

function InterfaceController:GetSelected(): string?
	return self._selected
end

-- ===== UI (TODO -- YOU build these) =====

-- Build the character-select screen from the roster. Each entry should call
-- self:SelectCharacter(name) on click; on success, close the screen.
function InterfaceController:_buildCharacterSelect(_names: { string })
	-- TODO: build the select screen (Icon/Sleek). For each name make a button that
	-- calls self:SelectCharacter(name).
end

-- Build the persistent combat HUD (health bar, posture, vital force, cooldowns).
function InterfaceController:_buildHud()
	-- TODO: construct the HUD frames once here.
end

-- Push a fresh status snapshot into the HUD. Called on every Status.Sync.
function InterfaceController:_refreshHud(_snapshot)
	-- TODO: update the HUD widgets from _snapshot
	--   (_snapshot.Health, .MaxHealth, .Posture, .VitalForce, .Status)
end

return InterfaceController
