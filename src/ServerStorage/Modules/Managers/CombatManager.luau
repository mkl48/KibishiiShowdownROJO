-- Kibishii Showdown
-- server/Modules/Managers/CombatManager.luau
--
-- Server half of the Combat domain and counterpart of CombatController. It is the
-- authority: it never trusts the client's swing. It re-checks the player can act,
-- re-validates cadence + targets via CombatService, routes each resolved hit through
-- StatusService (the only thing that mutates HP), and replicates the result to the
-- victim. Messaging is the Network lib now ("Combat.*" channels), not the Junction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local CombatManager = {}

function CombatManager:Start(context)
	local Combat = context:GetService("CombatService")
	local Status = context:GetService("StatusService")

	-- A confirmed swing. With Network, the sending player is the FIRST arg.
	Net:OnClient("Combat.Swing", function(player, data)
		if not Status:CanAct(player) then
			return -- was the old Guard: stunned / downed players can't swing
		end
		local comboIndex, reverb = Combat:RegisterSwing(player)
		if not comboIndex then
			return -- cadence cheat / spam; silently dropped
		end

		local targets = Combat:VerifyTargets(player, data.Targets or {})
		for _, target in targets do
			local hit = Combat:HitFor(player, comboIndex, reverb, target)
			local result = Status:ApplyHit(target, hit)
			if result then
				Net:ToClient(target, "Combat.Hit", result)
			end
		end
	end)

	-- Guard up / down. Just records intent in authoritative state.
	Net:OnClient("Combat.Block", function(player, data)
		Status:SetBlocking(player, data and data.Active == true)
	end)
end

return CombatManager
