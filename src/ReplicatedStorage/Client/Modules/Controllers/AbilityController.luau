-- Kibishii Showdown
-- Client/Modules/Controllers/AbilityController.luau
--
-- The client half of casting. It builds every character's moveset into the CLIENT
-- Memo registry at boot (so it has the specs to run client tracks), turns input into
-- Ability.Cast requests, and -- on the server's authoritative Ability.Play broadcast
-- -- runs the move's client tracks (animation / vfx) on the caster's character. The
-- server already ran the hitbox tracks; Memo's side filtering keeps the two halves
-- from stepping on each other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)
local Mixit = require(ReplicatedStorage.Shared.Modules.Packages.Mixit)

local AbilityController = {}

function AbilityController:Start(context)
	local Memo = require(ReplicatedStorage.Shared.Modules.Packages.Memo)
	local CharacterBuilder = require(ReplicatedStorage.Shared.Modules.Utility.CharacterBuilder)

	self._memo = Memo
	self._animation = context:GetService("AnimationController")

	-- Mirror the server: build all characters so their specs exist client-side.
	local charactersFolder = ReplicatedStorage.Shared.Classes:FindFirstChild("Characters")
	self._catalog = charactersFolder and CharacterBuilder.buildAll(charactersFolder, Memo) or {}

	-- Input -> cast request. (M1 = the character's base combo; skills slot in later.)
	Net:OnSignal("Ability.Input", function(action)
		print("[DBG] AbilityController: Ability.Input", action, "-> ToServer Cast")
		Net:ToServer("Ability.Cast", { action = action })
	end)

	-- Server says a move went off -> run its client tracks on the caster.
	Net:OnServer("Ability.Play", function(payload)
		print("[DBG] AbilityController: got Ability.Play", payload and payload.Move)
		self:_play(payload)
	end)
end

function AbilityController:_play(payload)
	local def = self._catalog[payload.Character]
	local byClass = def and def.Moves[payload.Class]
	local registered = byClass and byClass[payload.Move]
	if not registered then
		return
	end

	-- Run the exact variant the server picked, so visuals match authority.
	local moveSpec = registered
	if registered.variants then
		moveSpec = (payload.Variant and registered.variants[payload.Variant]) or moveSpec
		if moveSpec.variants then
			return -- couldn't resolve to a concrete move spec
		end
	end

	local caster = payload.Caster
	local character = caster and caster.Character
	if not character then
		return
	end

	self._memo.execute(moveSpec, {
		character = character,
		player = caster,
		animator = self._animation:For(character),
	})

	-- Play the all-in-one Mixit tape for this move (real animation + scene/stamp
	-- timing). Tape name matches the move's spec name; pcall = no tape -> no-op.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animatorInst = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animatorInst then
		pcall(function()
			Mixit.play(registered.name, { Animator = animatorInst })
		end)
	end
end

return AbilityController
