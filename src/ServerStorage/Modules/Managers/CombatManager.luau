-- Kibishii Showdown
-- server/Modules/Managers/CombatManager.luau
--
-- Server half of the Combat domain and counterpart of CombatController. It is the
-- authority: it never trusts the client's swing. A Guard drops swings from players
-- who can't act; the handler re-validates cadence + targets via CombatService, then
-- routes each resolved hit through StatusService (the only thing that mutates HP),
-- and replicates the authoritative result back to the victim.

local CombatManager = {}

function CombatManager:Start(context)
	local Network = context:Network("Combat")
	local Combat = context:GetService("CombatService")
	local Status = context:GetService("StatusService")

	-- Edge guard: a stunned / downed / unknown player cannot swing. Vetoed posts
	-- never reach the handler below.
	Network:Guard("Swing", function(_data, player)
		return Status:CanAct(player)
	end)

	-- A confirmed swing. `player` is the trailing arg Junky appends server-side --
	-- trust it, never a player field inside the payload.
	Network:Subscribe("Swing", function(data, player)
		local comboIndex, reverb = Combat:RegisterSwing(player)
		if not comboIndex then
			return -- cadence cheat / spam; silently dropped
		end

		local targets = Combat:VerifyTargets(player, data.Targets or {})
		for _, target in targets do
			local hit = Combat:HitFor(player, comboIndex, reverb, target)
			local result = Status:ApplyHit(target, hit)
			if result then
				-- Authoritative outcome to the victim: knockback, stun, crit flash.
				Network:PostTo(target, "Hit", result)
			end
		end
	end)

	-- Guard up / down. Just records intent in authoritative state.
	Network:Subscribe("Block", function(data, player)
		Status:SetBlocking(player, data and data.Active == true)
	end)
end

return CombatManager
