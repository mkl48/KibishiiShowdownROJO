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
-- Junction -- the routing topology. Every event declared once, with where it goes.
--   Network = crosses client <-> server (Substance transport).
--   Local   = stays on one side, resolved in-process.
-- ============================================================================
Config.Junction = {
	Network = {
		Combat = {
			-- client -> server: "I threw M1 #n, here are the targets my client saw"
			Swing = { Destination = "CombatManager" },
			-- client -> server: guard raised / lowered
			Block = { Destination = "CombatManager" },
			-- server -> the victim: authoritative hit result (damage, knockback, crit)
			Hit = { Destination = "CombatController" },
		},
		Status = {
			-- server -> a client: their own HP / posture / vital-force snapshot
			Sync = { Destination = "StatusController" },
			-- server -> a client: you were knocked Down (ragdoll + respawn flow)
			Down = { Destination = "StatusController" },
		},
		Character = {
			-- client -> server request: the selectable characters
			List = { Destination = "CharacterService" },
			-- client -> server request: pick a character (returns { ok, character? })
			Select = { Destination = "CharacterService" },
		},
	},

	Local = {
		-- client-only: InputController fans raw input out to CombatController.
		Input = {
			Pressed = { Destination = "CombatController", Side = "Client" },
		},
		-- server-only: StatusService announces a changed slice; StatusManager forwards.
		Status = {
			Changed = { Destination = "StatusManager", Side = "Server" },
		},
		-- server-only: PlayerService announces a spawned player so state can init.
		Data = {
			Loaded = { Destination = "StatusService", Side = "Server" },
		},
		-- client-only: StatusController fans status snapshots out to the HUD.
		Hud = {
			Refresh = { Destination = "InterfaceController", Side = "Client" },
		},
	},
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
	[2] = { "CombatController", "CombatManager" },
	[3] = { "InputController", "AnimationController" },
	[4] = { "InterfaceController" }, -- builds the HUD/select screens last
}

-- ============================================================================
-- StandalonePriority -- numeric boot order for Services (ascending). PlayerService
-- announces spawns before StatusService inits per-player state from them.
-- ============================================================================
Config.StandalonePriority = {
	PlayerService = 1,
	StatusService = 2,
	CombatService = 3,
	CharacterService = 4, -- builds the catalog (registers moves with Memo)
}

return Config
