-- Sphereite Reject / Moveset / Base / Doo Doo Duel
--
-- The base plunger combo. A move module is data + a single `Build(memo)` that
-- returns a (variant) spec. NOTHING touches `memo` at require time -- the old
-- `local D = Memo.Drive` ran before Memo existed and crashed the require. Drive (D)
-- and Crossfade (X) are pulled from `memo` inside Build, where they actually exist.

local DooDooDuel = {}

DooDooDuel.Name = "Doo Doo Duel"
DooDooDuel.Class = "Base"

function DooDooDuel.Build(memo)
	local D = memo.Drive
	local X = memo.Crossfade

	local function buildBase(b: any)
		return b
			:priority("normal")
			:tag("combo", "melee", "plunger")
			:crossfade(X.hard())

			:phase("startup")
			:drive(D.time(0.12))
			:track("anim")
			:side("shared")
			:data({ id = "rbxassetid://91550420179401" })
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Startup")
			end)
			:done()
			:done()

			:phase("strike_1")
			:drive(D.time(0.18))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Strike1")
			end)
			:done()
			:track("hitbox")
			:side("server")
			:onEnter(function(ctx)
				ctx.hitbox:spawn("PlungerSwing1", ctx.character, {
					damage = 8,
					knockback = Vector3.new(0, 5, 12),
					hitlag = 4,
				})
			end)
			:onExit(function(ctx)
				ctx.hitbox:stop("PlungerSwing1")
			end)
			:done()
			:done()

			:phase("link_1")
			:drive(D.time(0.08))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Link1")
			end)
			:done()
			:done()

			:phase("strike_2")
			:drive(D.time(0.18))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Strike2")
			end)
			:done()
			:track("hitbox")
			:side("server")
			:onEnter(function(ctx)
				ctx.hitbox:spawn("PlungerSwing2", ctx.character, {
					damage = 8,
					knockback = Vector3.new(0, 5, -12),
					hitlag = 4,
				})
			end)
			:onExit(function(ctx)
				ctx.hitbox:stop("PlungerSwing2")
			end)
			:done()
			:done()

			:phase("link_2")
			:drive(D.time(0.08))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Link2")
			end)
			:done()
			:done()

			:phase("strike_3")
			:drive(D.time(0.2))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Strike3")
			end)
			:done()
			:track("hitbox")
			:side("server")
			:onEnter(function(ctx)
				ctx.hitbox:spawn("PlungerSwing3", ctx.character, {
					damage = 10,
					knockback = Vector3.new(0, 8, 18),
					hitlag = 6,
				})
			end)
			:onExit(function(ctx)
				ctx.hitbox:stop("PlungerSwing3")
			end)
			:done()
			:window({
				name = "cancel_special",
				phase = "strike_3",
				from = 0.08,
				to = 0.18,
			})
			:done()

			:phase("recovery")
			:drive(D.time(0.22))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Recovery")
			end)
			:done()
			:done()

			:build()
	end

	local function buildAir(b: any)
		return b
			:priority("normal")
			:tag("combo", "melee", "plunger", "air")
			:crossfade(X.hard())

			:phase("startup")
			:drive(D.time(0.1))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Air_Startup")
			end)
			:done()
			:done()

			:phase("strike_1")
			:drive(D.time(0.16))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Air_Strike1")
			end)
			:done()
			:track("hitbox")
			:side("server")
			:onEnter(function(ctx)
				ctx.hitbox:spawn("PlungerAir1", ctx.character, {
					damage = 7,
					knockback = Vector3.new(0, 3, 14),
					hitlag = 3,
				})
			end)
			:onExit(function(ctx)
				ctx.hitbox:stop("PlungerAir1")
			end)
			:done()
			:done()

			:phase("link_1")
			:drive(D.time(0.06))
			:done()

			:phase("strike_2")
			:drive(D.time(0.16))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Air_Strike2")
			end)
			:done()
			:track("hitbox")
			:side("server")
			:onEnter(function(ctx)
				ctx.hitbox:spawn("PlungerAir2", ctx.character, {
					damage = 12,
					knockback = Vector3.new(0, -20, 10),
					hitlag = 8,
				})
			end)
			:onExit(function(ctx)
				ctx.hitbox:stop("PlungerAir2")
			end)
			:done()
			:done()

			:phase("recovery")
			:drive(D.time(0.28))
			:track("anim")
			:side("shared")
			:onEnter(function(ctx)
				ctx.animator:play("DDD_Air_Recovery")
			end)
			:done()
			:done()

			:build()
	end

	return memo.defineVariants("DooDooDuel")
		:variant("base", buildBase)
		:variant("air", buildAir)
		:resolver(function(ctx)
			local char = ctx.character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
				return "air"
			end
			return "base"
		end)
		:build()
end

return DooDooDuel
