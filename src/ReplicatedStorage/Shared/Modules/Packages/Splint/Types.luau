--!strict
-- Splint
-- Types.luau
-- Plinko Labs
--
-- Shapes for the ragdoll core. A Config is the declarative recipe; a Handle is the
-- live ragdoll on one character. Controller `type` selects behaviour:
--   Classic -- full limp, the character faints.
--   Active  -- limp joints but the root fights to stay upright (hit-stagger that
--              recovers), good for melee knockback that doesn't fully KO.

export type ControllerType = "Classic" | "Active"

export type Config = {
	type: ControllerType,
	joints: "all" | { string }, -- which Motor6Ds go limp (by name)
	inheritVelocity: boolean, -- carry the character's momentum into the ragdoll
	collisions: boolean, -- limbs collide with the world (self-collision off)
	autoRecover: number?, -- seconds, then recover automatically (nil = manual)
	uprightForce: number?, -- Active only: AlignOrientation torque toward upright
}

export type JointRecord = {
	motor: Motor6D,
	a0: Attachment,
	a1: Attachment,
	bsc: BallSocketConstraint,
}

export type Snapshot = { [string]: CFrame }

return nil
