-- Kibishii Showdown
-- client/Modules/Controllers/CombatController.luau
--
-- Client half of the Combat domain. Predicts the swing for instant feel (plays a
-- local hitbox + animation now), reports the targets it saw to the server, and then
-- reconciles against the server's authoritative Hit result (knockback, hitstop,
-- crit flash). The local hitbox is for FEEL only -- the server re-verifies and is
-- the final word. It never references CombatManager or any Service directly.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local CombatController = {}

local LocalPlayer = Players.LocalPlayer

function CombatController:Start(context)
	self._context = context
	self._manifest = context:GetPackage("Manifest")
	self._lastSwing = 0

	-- Block input (M1 is handled by the Ability domain now). Same-side signal.
	Net:OnSignal("Input.Pressed", function(action)
		if action == "Block:Down" then
			Net:ToServer("Combat.Block", { Active = true })
		elseif action == "Block:Up" then
			Net:ToServer("Combat.Block", { Active = false })
		end
	end)

	-- The server's authoritative result of US being hit (knockback / ragdoll / crit).
	Net:OnServer("Combat.Hit", function(result)
		self:PlayHitReaction(result)
	end)
end

-- Predict + report. Client-side cooldown keeps us from spamming the wire; the
-- server enforces the real cadence regardless.
function CombatController:Swing()
	local now = os.clock()
	if now - self._lastSwing < self._manifest.Combat.M1Cooldown then
		return
	end
	self._lastSwing = now

	local targets = self:ScanTargets()
	-- TODO: play swing animation / trail here for feel.
	Net:ToServer("Combat.Swing", { Targets = targets, At = workspace:GetServerTimeNow() })
end

-- A cheap client hitbox: players in a forward cone within range. The server only
-- trusts these as *claims* and re-checks distance, so being generous here is fine.
function CombatController:ScanTargets(): { Player }
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return {}
	end

	local cfg = self._manifest.Combat
	local origin = root.Position
	local look = root.CFrame.LookVector
	local found = {}

	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer then
			local pr = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if pr then
				local offset = pr.Position - origin
				local dist = offset.Magnitude
				if dist <= cfg.Range and dist > 0 and look:Dot(offset.Unit) > 0.35 then
					table.insert(found, player)
				end
			end
		end
	end

	return found
end

-- Apply the authoritative reaction to being hit: knockback impulse, brief hitstop,
-- crit flag. Down handling lives in StatusController (via Status.Down).
function CombatController:PlayHitReaction(result)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	if result.Knockback then
		local kb = result.Knockback
		root.AssemblyLinearVelocity = kb.Direction * kb.Force + Vector3.new(0, kb.Force * 0.25, 0)
	end

	if result.Reverb then
		-- Reverberation crit landed on us -- punchier feedback hook.
		-- TODO: red flash + heavier hitstop + impact SFX.
	end

	-- Tiny hitstop so impacts read. Real version freezes animation, not the script.
	RunService.Heartbeat:Wait()
end

return CombatController
