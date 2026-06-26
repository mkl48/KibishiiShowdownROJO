-- Kibishii Showdown
-- Shared/Modules/Utility/Config.luau
--
-- One config surface for the whole game. Everything Junky.Configure needs lives
-- here: the Junction (routing), the Manifest (tuning), and the two boot-order maps.
-- Utility/Bootstrap reads this and hands it to Junky. Add a domain = edit one file.
--
-- Combat-spine scope only. Ability / Movement / Loadout / Round / Effect / Hud
-- (and Jinki movesets) extend these tables as they come online.

local Config = {}

-- ============================================================================
-- Junction -- DEPRECATED. Messaging moved to the Network package (Packages/Network):
-- channels are "Domain.Event" strings created on the fly, no central routing table.
-- Junky still wants this key to exist for Configure(), so it's empty. See each
-- module for `local Net = require(...Network)` and Net:ToServer/OnClient/Ask/Signal.
-- ============================================================================
Config.Junction = {
	Network = {},
	Local = {},
}

-- ============================================================================
-- Manifest -- read-only tuning, deep-frozen at boot. All combat feel is numbers
-- here, so balancing never touches logic. Reach it via context:GetPackage("Manifest").
-- ============================================================================
Config.Manifest = {
	PlayerSettings = {
		MaxHealth = 100,
		BaseSpeed = 16,
		MaxPosture = 100, -- block meter; breaks at 0 -> guard-broken stun
		MaxVitalForce = 100, -- ability resource (Gachiakuta's life-energy)
		VitalRegenPerSec = 8,
		PostureRegenPerSec = 12,
		RespawnDelay = 4,
	},

	Combat = {
		M1Damage = 7,
		ComboLength = 4, -- M1s in a chain; the last is the finisher
		ComboResetTime = 0.8, -- seconds before the chain drops back to hit 1
		M1Cooldown = 0.35, -- min seconds between swings (server-enforced cadence)
		Range = 6, -- studs; server re-verifies hits within this
		RangeFudge = 1.5, -- leniency for latency on the server range check
		FinisherKnockback = 45,
		LightKnockback = 8,
		HitStun = 0.25,
		FinisherStun = 0.6,

		-- "Reverberation" -- the Black-Flash-style timing crit (JJK shenanigan).
		-- A swing landed within ReverbWindow of the ideal cadence crits.
		ReverbWindow = 0.12,
		ReverbMultiplier = 1.6,
	},

	Block = {
		DamageReduction = 0.5,
		PostureCostPerHit = 18,
		GuardBreakStun = 1.25,
	},

	Keybinds = {
		M1 = Enum.UserInputType.MouseButton1,
		Block = Enum.KeyCode.F,
	},

	Enums = {
		-- Coarse combat state. StatusService owns the transitions.
		Status = {
			Alive = "Alive",
			Stunned = "Stunned",
			Down = "Down",
		},
	},

	GameConfig = {},
}

-- ============================================================================
-- ClassPriority -- tier-based boot order for Controllers + Managers (ascending).
-- Everything in a lower tier :Start before anything in a higher tier. Status boots
-- first (everyone reads authoritative state from it); input wires last.
-- ============================================================================
Config.ClassPriority = {
	[1] = { "StatusController", "StatusManager" },
	[2] = { "CombatController", "CombatManager", "AbilityManager" },
	[3] = { "InputController", "AnimationController", "MemoryController" },
	[4] = { "InterfaceController", "AbilityController" }, -- need Animation booted first
}

-- ============================================================================
-- StandalonePriority -- numeric boot order for Services (ascending). PlayerService
-- announces spawns before StatusService inits per-player state from them.
-- ============================================================================
Config.StandalonePriority = {
	PlayerService = 1, -- sessions (server + client halves, side-split)
	StatusService = 2, -- self-inits per player on spawn
	CombatService = 3,
	CharacterService = 4, -- builds the catalog (registers moves with Memo)
	HitboxService = 5, -- ctx.hitbox provider for ability hit detection
	MemoryService = 6, -- defines the Session/Keybinds/Settings Plinko caches
}

return Config
