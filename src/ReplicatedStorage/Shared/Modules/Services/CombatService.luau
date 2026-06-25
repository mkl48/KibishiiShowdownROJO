-- Kibishii Showdown
-- server/Modules/Services/CombatService.luau
--
-- The rules of M1 combat, server-side. Owns each attacker's combo index + cadence,
-- validates swings, and re-verifies targets the client claimed (range only -- never
-- trust the client's target list blindly). It computes damage but does NOT mutate
-- health; that is StatusService's job. CombatService decides "what should happen",
-- StatusService decides "what is true".

local CombatService = {}
CombatService.Combo = {} -- [player] = { Index, LastSwing }

function CombatService:Start(context)
	self._manifest = context:GetPackage("Manifest")
end

local function getRoot(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function CombatService:_combo(player: Player)
	local c = self.Combo[player]
	if not c then
		c = { Index = 0, LastSwing = 0 }
		self.Combo[player] = c
	end
	return c
end

-- Advance the attacker's combo if cadence is legal. Returns the resolved combo
-- index (1..ComboLength) and whether this swing was a "reverberation" crit, or nil
-- if the swing came in too fast (cadence cheat / lag spam).
function CombatService:RegisterSwing(player: Player)
	local cfg = self._manifest.Combat
	local c = self:_combo(player)
	local now = os.clock()
	local since = now - c.LastSwing

	if since < cfg.M1Cooldown then
		return nil -- swinging faster than allowed; drop it
	end

	-- Reverb: a swing landed crisply on cadence (Black-Flash-style timing crit).
	local ideal = cfg.M1Cooldown
	local reverb = c.Index > 0 and math.abs(since - ideal) <= cfg.ReverbWindow

	if since > cfg.ComboResetTime then
		c.Index = 1
	else
		c.Index = (c.Index % cfg.ComboLength) + 1
	end
	c.LastSwing = now

	return c.Index, reverb
end

-- Re-verify the targets the client reported. Accept only players whose character
-- is within (Range * RangeFudge) studs of the attacker right now.
function CombatService:VerifyTargets(player: Player, claimed: { Player })
	local cfg = self._manifest.Combat
	local attackerRoot = getRoot(player)
	if not attackerRoot then
		return {}
	end

	local maxDist = cfg.Range * cfg.RangeFudge
	local origin = attackerRoot.Position
	local valid = {}

	for _, target in claimed do
		if typeof(target) == "Instance" and target:IsA("Player") and target ~= player then
			local root = getRoot(target)
			if root and (root.Position - origin).Magnitude <= maxDist then
				table.insert(valid, target)
			end
		end
	end

	return valid
end

-- Build the hit descriptor for a given combo index. Pure data -> StatusService.
function CombatService:HitFor(player: Player, comboIndex: number, reverb: boolean, target: Player)
	local cfg = self._manifest.Combat
	local isFinisher = comboIndex >= cfg.ComboLength

	local damage = cfg.M1Damage
	if reverb then
		damage *= cfg.ReverbMultiplier
	end

	local force = isFinisher and cfg.FinisherKnockback or cfg.LightKnockback
	local knockback
	local attackerRoot = getRoot(player)
	local targetRoot = getRoot(target)
	if attackerRoot and targetRoot then
		local dir = (targetRoot.Position - attackerRoot.Position)
		dir = if dir.Magnitude > 0 then dir.Unit else attackerRoot.CFrame.LookVector
		knockback = { Direction = dir, Force = force }
	end

	return {
		Damage = damage,
		Stun = isFinisher and cfg.FinisherStun or cfg.HitStun,
		Knockback = knockback,
		Reverb = reverb,
	}
end

function CombatService:Stop()
	table.clear(self.Combo)
end

return CombatService
