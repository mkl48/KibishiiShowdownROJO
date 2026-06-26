-- Kibishii Showdown
-- client/Modules/Controllers/StatusController.luau
--
-- Client half of the Status domain. It caches this player's authoritative snapshot
-- (HP / posture / vital force) so the HUD has a single source to read, and handles
-- being knocked Down (ragdoll-lite + a respawn timer). When HudController lands it
-- will subscribe to a Local "Hud.Refresh" that this controller posts on every Sync.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local StatusController = {}

local LocalPlayer = Players.LocalPlayer

function StatusController:Start(context)
	self.Snapshot = nil
	self._manifest = context:GetPackage("Manifest")

	-- Authoritative state stream from the server.
	Net:OnServer("Status.Sync", function(snapshot)
		self.Snapshot = snapshot
		-- Fan it out to the HUD (InterfaceController) via a same-side signal.
		Net:Signal("Hud.Refresh", snapshot)
		print(("[Status] HP %d/%d  Posture %d  Vital %d  (%s)"):format(
			snapshot.Health,
			snapshot.MaxHealth,
			snapshot.Posture or 0,
			snapshot.VitalForce or 0,
			snapshot.Status
		))
	end)

	-- We got knocked out. The SERVER ragdolls us authoritatively (Splint) and it
	-- replicates, so there's nothing physical to do here -- just react in UI/camera.
	Net:OnServer("Status.Down", function(_snapshot)
		-- TODO: KO screen / camera knock. (No client ragdoll -- server owns it.)
	end)
end

-- Lightweight ragdoll: drop into a Physics state and unstand the humanoid. A full
-- ragdoll rig (Motor6D -> BallSocketConstraint swap) is a later polish pass.
function StatusController:Ragdoll()
	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Respawn is a SERVER concern (LoadCharacter is server-only). The Round milestone
	-- owns it: RoundManager watches for Down, waits PlayerSettings.RespawnDelay, then
	-- LoadPlayerCharacter + StatusService:Init. Nothing to do client-side here yet.
end

return StatusController
