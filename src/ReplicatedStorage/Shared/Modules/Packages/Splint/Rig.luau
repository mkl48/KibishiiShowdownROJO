--!strict
-- Splint
-- Rig.luau
-- Plinko Labs
--
-- The joint engine. Turns a rigid Motor6D into a limp BallSocketConstraint (and
-- back) by mirroring the motor's C0/C1 as two Attachments and disabling the motor.
-- Works on R6 and R15 alike -- it discovers Motor6Ds by walking the character, so it
-- doesn't care about the naming scheme; per-joint angle limits keep limbs from
-- folding through the body.

local Types = require(script.Parent.Types)
type JointRecord = Types.JointRecord

local Rig = {}

-- Per-joint cone limits (degrees). Falls back to DEFAULT for anything unlisted,
-- covering both R6 ("Right Shoulder") and R15 ("RightShoulder") names.
local LIMIT: { [string]: number } = {
	Neck = 45,
	RootJoint = 15,
	Root = 15,
	Waist = 30,
	["Right Shoulder"] = 135,
	["Left Shoulder"] = 135,
	RightShoulder = 135,
	LeftShoulder = 135,
	["Right Hip"] = 90,
	["Left Hip"] = 90,
	RightHip = 90,
	LeftHip = 90,
	RightElbow = 100,
	LeftElbow = 100,
	RightKnee = 100,
	LeftKnee = 100,
}
local DEFAULT_LIMIT = 90

function Rig.isR15(character: Model): boolean
	return character:FindFirstChild("UpperTorso") ~= nil
end

-- All Motor6Ds in the character, optionally filtered to a name whitelist.
function Rig.discover(character: Model, joints: "all" | { string }): { Motor6D }
	local allow: { [string]: boolean }? = nil
	if joints ~= "all" then
		allow = {}
		for _, name in joints :: { string } do
			allow[name] = true
		end
	end

	local motors = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			if not allow or allow[d.Name] then
				table.insert(motors, d)
			end
		end
	end
	return motors
end

-- Limp one joint. Returns a record to restore it later, or nil if unswappable.
function Rig.limp(motor: Motor6D): JointRecord?
	local p0, p1 = motor.Part0, motor.Part1
	if not (p0 and p1) then
		return nil
	end

	local a0 = Instance.new("Attachment")
	a0.Name = "SplintA0_" .. motor.Name
	a0.CFrame = motor.C0
	a0.Parent = p0

	local a1 = Instance.new("Attachment")
	a1.Name = "SplintA1_" .. motor.Name
	a1.CFrame = motor.C1
	a1.Parent = p1

	local limit = LIMIT[motor.Name] or DEFAULT_LIMIT
	local bsc = Instance.new("BallSocketConstraint")
	bsc.Name = "SplintJoint_" .. motor.Name
	bsc.Attachment0 = a0
	bsc.Attachment1 = a1
	bsc.LimitsEnabled = true
	bsc.UpperAngle = limit
	bsc.TwistLimitsEnabled = true
	bsc.TwistLowerAngle = -limit * 0.5
	bsc.TwistUpperAngle = limit * 0.5
	bsc.MaxFrictionTorque = 0
	bsc.Parent = p1

	motor.Enabled = false

	return { motor = motor, a0 = a0, a1 = a1, bsc = bsc }
end

-- Restore a joint to its rigid Motor6D state.
function Rig.restore(rec: JointRecord)
	if rec.bsc then
		rec.bsc:Destroy()
	end
	if rec.a0 then
		rec.a0:Destroy()
	end
	if rec.a1 then
		rec.a1:Destroy()
	end
	if rec.motor and rec.motor.Parent then
		rec.motor.Enabled = true
	end
end

return Rig
