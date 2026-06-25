-- Sphereite Reject / Manifest
--
-- Declares the character's moveset order and movement set. CharacterService reads
-- this when building the character. (Was a syntax error before: `Idle` missing its
-- comma, and the direction entries were bare nil identifiers -- now strings.)

local Manifest = {}

Manifest.MovesetOverview = {
	Name = "Sphereite Reject",

	-- Move order by class. Numeric keys = the combo/slot order; named keys = specials.
	Order = {
		Base = {
			[1] = "Doo Doo Duel",
			["Special"] = "Shin No Kachi",
		},
	},

	Movement = {
		Base = {
			Dash = { "Forward", "Backward", "SideLeft", "SideRight" },
			Move = { "Idle", "Forward", "Backward", "SideLeft", "SideRight" },
		},
	},
}

return Manifest
