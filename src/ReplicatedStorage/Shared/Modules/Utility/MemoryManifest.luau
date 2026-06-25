-- Kibishii Showdown
-- Shared/Modules/Utility/MemoryManifest.luau
--
-- The GLOBAL MANIFEST -- the per-player state the game keeps in memory: session info,
-- keybinds, and settings. Each block is a Plinko schema (field -> default). The Memory
-- domain defines a Plinko cache per block from this, so both the server (authority) and
-- the client (replicated, read-only) share one definition. Add a field here and it
-- exists everywhere. `replicate = "owner"` means each player only sees their own.

local MemoryManifest = {}

-- Session: live, per-session stats. Not persisted by default (wire onSave later).
MemoryManifest.Session = {
	schema = {
		Character = "", -- the chosen character (kit) name
		Kills = 0,
		Deaths = 0,
		PlayTime = 0,
		InRound = false,
	},
	replicate = { Character = "owner", Kills = "all", Deaths = "all", InRound = "owner" },
}

-- Keybinds: the player's input map. Values are KeyCode / UserInputType NAMES (strings),
-- resolved to Enums at bind time so they survive save/replication cleanly.
MemoryManifest.Keybinds = {
	schema = {
		M1 = "MouseButton1",
		Skill1 = "Q",
		Skill2 = "E",
		Skill3 = "R",
		Skill4 = "T",
		Dash = "Q",
		Block = "F",
		Sprint = "LeftShift",
	},
	replicate = {
		M1 = "owner", Skill1 = "owner", Skill2 = "owner", Skill3 = "owner",
		Skill4 = "owner", Dash = "owner", Block = "owner", Sprint = "owner",
	},
}

-- Settings: client-facing preferences, clamped/validated by middleware in the service.
MemoryManifest.Settings = {
	schema = {
		MasterVolume = 80,
		SfxVolume = 80,
		MusicVolume = 60,
		ScreenShake = true,
		ShowDamageNumbers = true,
		Sensitivity = 1,
	},
	replicate = {
		MasterVolume = "owner", SfxVolume = "owner", MusicVolume = "owner",
		ScreenShake = "owner", ShowDamageNumbers = "owner", Sensitivity = "owner",
	},
}

-- The order the Memory domain builds them in.
MemoryManifest.Order = { "Session", "Keybinds", "Settings" }

return MemoryManifest
