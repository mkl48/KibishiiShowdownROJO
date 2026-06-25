-- Kibishii Showdown
-- Client/Modules/Controllers/InterfaceController.luau
--
-- SCAFFOLD -- the data plumbing is wired; the UI is YOURS to build (Icon / Sleek).
-- This controller owns the screens: character-select and the combat HUD. Everything
-- that talks to the server already works (list characters, send a pick, receive HUD
-- snapshots); the `_build*` / `_refresh*` methods are intentionally empty TODOs for
-- you to fill with actual widgets.

local InterfaceController = {}

function InterfaceController:Start(context)
	self._context = context
	self._character = context:Network("Character")
	self._selected = nil :: string?

	-- HUD: StatusController fans the authoritative snapshot out on Local Hud.Refresh
	-- (Network Status.Sync is destination-filtered to StatusController).
	context:Local("Hud"):Subscribe("Refresh", function(snapshot)
		self._latest = snapshot
		self:_refreshHud(snapshot)
	end)

	-- Pull the roster, then hand it to your select screen.
	self:RequestCharacterList()
		:Next(function(names)
			self:_buildCharacterSelect(names)
		end)
		:Catch(function(err)
			warn("[InterfaceController] character list failed:", err)
		end)

	self:_buildHud()
end

-- ===== data flow (DONE -- call these from your UI) =====

-- Ask the server for the selectable characters. Resolves with { string }.
function InterfaceController:RequestCharacterList()
	return self._character:Request("List")
end

-- Tell the server which character the player picked. Resolves with
-- { ok = boolean, character?, reason? }. Updates local state on success.
function InterfaceController:SelectCharacter(name: string)
	return self._character:Request("Select", { Name = name })
		:Next(function(result)
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
