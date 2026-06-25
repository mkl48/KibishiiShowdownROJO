-- Kibishii Showdown
-- server/Modules/Services/StatusService.luau
--
-- The single source of truth for combat state: HP, posture, vital force, and the
-- coarse Status (Alive / Stunned / Down) per player. EVERYTHING authoritative reads
-- and mutates state through here -- Combat and (later) Ability never touch HP
-- directly. It posts Status.Changed whenever a slice moves so the Manager can sync
-- the owning client. It is decoupled: it doesn't know how hits arrive.

local StatusService = {}
StatusService.State = {} -- [player] = { Health, Posture, VitalForce, Status, StunUntil }

function StatusService:Start(context)
	self._context = context
	self._manifest = context:GetPackage("Manifest")

	-- Self-init per player on spawn. Owns its own lifecycle so it doesn't depend on a
	-- separate PlayerService posting Data.Loaded (avoids the duplicate-PlayerService
	-- clash with the game's own ServerStorage PlayerService).
	local Players = game:GetService("Players")
	local function onPlayer(player: Player)
		if player.Character then
			self:Init(player)
		end
		player.CharacterAdded:Connect(function()
			self:Init(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerAdded:Connect(onPlayer)

	-- Resource regen tick. Cheap, server-side, fixed cadence.
	task.spawn(function()
		while true do
			task.wait(1)
			self:Regen(1)
		end
	end)
end

function StatusService:Init(player: Player, maxHealth: number?)
	local ps = self._manifest.PlayerSettings
	local enums = self._manifest.Enums
	self.State[player] = {
		Health = maxHealth or ps.MaxHealth,
		MaxHealth = maxHealth or ps.MaxHealth,
		Posture = ps.MaxPosture,
		VitalForce = ps.MaxVitalForce,
		Status = enums.Status.Alive,
		StunUntil = 0,
	}
	self:_changed(player)
end

-- A read-only snapshot for syncing to the client / HUD.
function StatusService:Snapshot(player: Player)
	local s = self.State[player]
	if not s then
		return nil
	end
	return {
		Health = s.Health,
		MaxHealth = s.MaxHealth,
		Posture = s.Posture,
		VitalForce = s.VitalForce,
		Status = s.Status,
	}
end

-- Can this player initiate an action right now? (Combat asks this in a Guard.)
function StatusService:CanAct(player: Player): boolean
	local s = self.State[player]
	if not s then
		return false
	end
	if s.Status == self._manifest.Enums.Status.Down then
		return false
	end
	if s.Status == self._manifest.Enums.Status.Stunned and os.clock() < s.StunUntil then
		return false
	end
	return true
end

function StatusService:IsAlive(player: Player): boolean
	local s = self.State[player]
	return s ~= nil and s.Status ~= self._manifest.Enums.Status.Down
end

function StatusService:SetBlocking(player: Player, blocking: boolean)
	local s = self.State[player]
	if s then
		s.Blocking = blocking
	end
end

-- How much vital force a player has right now.
function StatusService:GetVitalForce(player: Player): number
	local s = self.State[player]
	return s and s.VitalForce or 0
end

-- Spend vital force if the player can afford it. Returns true on success (and a cost
-- of 0/nil always succeeds). AbilityManager calls this before executing a move.
function StatusService:SpendVitalForce(player: Player, amount: number?): boolean
	local s = self.State[player]
	if not s then
		return false
	end
	amount = amount or 0
	if amount <= 0 then
		return true
	end
	if s.VitalForce < amount then
		return false
	end
	s.VitalForce -= amount
	self:_changed(player)
	return true
end

-- Apply an authoritative hit. `hit` = { Damage, Stun, Knockback }. Returns the
-- result the caller replicates to the victim, or nil if the target wasn't valid.
function StatusService:ApplyHit(player: Player, hit)
	local s = self.State[player]
	local enums = self._manifest.Enums
	if not s or s.Status == enums.Status.Down then
		return nil
	end

	local blockCfg = self._manifest.Block
	local damage = hit.Damage
	local blocked = false

	if s.Blocking then
		blocked = true
		s.Posture -= blockCfg.PostureCostPerHit
		damage *= (1 - blockCfg.DamageReduction)
		if s.Posture <= 0 then
			-- Guard break: posture gone, take a long stun and full damage.
			s.Posture = self._manifest.PlayerSettings.MaxPosture
			s.Blocking = false
			blocked = false
			damage = hit.Damage
			self:Stun(player, blockCfg.GuardBreakStun)
		end
	end

	s.Health -= damage
	if hit.Stun and hit.Stun > 0 and not blocked then
		self:Stun(player, hit.Stun)
	end

	local downed = false
	if s.Health <= 0 then
		s.Health = 0
		s.Status = enums.Status.Down
		downed = true
	end

	self:_changed(player)

	return {
		Health = s.Health,
		MaxHealth = s.MaxHealth,
		Status = s.Status,
		Damage = damage,
		Blocked = blocked,
		Downed = downed,
		Knockback = hit.Knockback, -- { Direction = Vector3, Force = number } | nil
		Reverb = hit.Reverb == true,
	}
end

function StatusService:Stun(player: Player, seconds: number)
	local s = self.State[player]
	if not s or s.Status == self._manifest.Enums.Status.Down then
		return
	end
	s.Status = self._manifest.Enums.Status.Stunned
	s.StunUntil = os.clock() + seconds
	task.delay(seconds, function()
		local cur = self.State[player]
		if cur and cur.Status == self._manifest.Enums.Status.Stunned and os.clock() >= cur.StunUntil then
			cur.Status = self._manifest.Enums.Status.Alive
			self:_changed(player)
		end
	end)
end

function StatusService:Regen(dt: number)
	local ps = self._manifest.PlayerSettings
	for player, s in self.State do
		if s.Status ~= self._manifest.Enums.Status.Down then
			local moved = false
			if s.VitalForce < ps.MaxVitalForce then
				s.VitalForce = math.min(ps.MaxVitalForce, s.VitalForce + ps.VitalRegenPerSec * dt)
				moved = true
			end
			if not s.Blocking and s.Posture < ps.MaxPosture then
				s.Posture = math.min(ps.MaxPosture, s.Posture + ps.PostureRegenPerSec * dt)
				moved = true
			end
			if moved then
				self:_changed(player)
			end
		end
	end
end

-- Internal: announce a changed slice. StatusManager forwards it to the client.
function StatusService:_changed(player: Player)
	self._context:Local("Status"):Post("Changed", {
		Player = player,
		Snapshot = self:Snapshot(player),
	})
end

function StatusService:Stop()
	table.clear(self.State)
end

return StatusService
