-- Kibishii Showdown
-- ServerStorage/Modules/Managers/AbilityManager.luau
--
-- The authority for casting moves. A client posts Ability.Cast { action } (e.g. M1);
-- the server resolves which move that is for the caster's chosen character, checks it
-- can act + afford it + isn't locked out by a higher-priority move, deducts cost,
-- runs the move SERVER-side (its hitbox tracks), and broadcasts Ability.Play so every
-- client runs the SAME move's client tracks (anim/vfx) on the caster. Server tracks
-- only run here; client tracks only run there -- Memo's side filtering does the split.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local AbilityManager = {}

local NOOP_ANIMATOR = { play = function() end, stop = function() end, stopAll = function() end }

function AbilityManager:Start(context)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Memo = require(ReplicatedStorage.Shared.Modules.Packages.Memo)

	self._memo = Memo
	self._active = {} -- [player] = { tl, spec }

	local Status = context:GetService("StatusService")
	local Character = context:GetService("CharacterService")
	local Hitbox = context:GetService("HitboxService")

	-- client -> server: "I pressed <action>". Network puts the player FIRST.
	Net:OnClient("Ability.Cast", function(player, payload)
		local action = type(payload) == "table" and payload.action or payload
		self:_cast(context, Memo, Status, Character, Hitbox, player, action)
	end)
end

function AbilityManager:_cast(context, Memo, Status, Character, Hitbox, player, action)
	if not Status:CanAct(player) then
		return
	end
	local char = player.Character
	if not char then
		return
	end

	-- Resolve <action> -> (class, moveName) from the caster's character order.
	local def = Character:GetPlayerDef(player)
	if not def then
		return
	end
	local order = def.Manifest and def.Manifest.MovesetOverview and def.Manifest.MovesetOverview.Order
	local class, moveName
	if action == "M1" then
		class = "Base"
		moveName = order and order.Base and order.Base[1]
	end
	-- (skills 1-4 / specials slot in here as more actions are bound)
	if not moveName then
		return
	end

	local byClass = def.Moves[class]
	local registered = byClass and byClass[moveName]
	if not registered then
		return
	end

	-- Build the server-side context (real hitbox; a no-op animator so shared anim
	-- tracks don't error server-side).
	local serverCtx = {
		character = char,
		player = player,
		hitbox = Hitbox:For(char),
		animator = NOOP_ANIMATOR,
	}

	-- Resolve a variant (base/air) authoritatively; we broadcast the choice.
	local moveSpec, variantName = registered, nil
	if registered.variants then
		moveSpec, variantName = Memo.resolveVariant(registered, serverCtx)
	end
	if not moveSpec then
		return
	end

	-- Gates: conditions, then cost.
	local ok = Memo.canStart(moveSpec, serverCtx)
	if not ok then
		return
	end
	local cost = Memo.costOf(moveSpec)
	if cost.VitalForce and not Status:SpendVitalForce(player, cost.VitalForce) then
		return -- not enough vital force
	end

	-- Interrupt arbitration against the player's current move.
	local current = self._active[player]
	if current and current.tl and current.tl:isActive() then
		if not Memo.canInterrupt(current.spec, moveSpec) then
			return -- locked into a higher/equal-priority move
		end
		current.tl:interrupt()
	end

	-- Run server tracks (hitbox) and track the timeline for interrupt/cleanup.
	local tl = Memo.executeTracked(moveSpec, serverCtx)
	self._active[player] = { tl = tl, spec = moveSpec }
	local function clear()
		if self._active[player] and self._active[player].tl == tl then
			self._active[player] = nil
		end
	end
	tl.onCompleted:Connect(clear)
	tl.onInterrupted:Connect(clear)
	tl.onCancelled:Connect(clear)

	-- Tell every client to run this move's client tracks on the caster.
	Net:ToAll("Ability.Play", {
		Caster = player,
		Character = def.Name,
		Class = class,
		Move = moveName,
		Variant = variantName,
	})
end

return AbilityManager
