-- Kibishii Showdown
-- Client/Modules/Controllers/AnimationController.luau
--
-- Provides the `ctx.animator` object that move tracks call -- `animator:play("DDD_Startup")`.
-- A move references animations by NAME; this controller resolves names to asset ids
-- through a library you register (anims come later, so an unknown name warns once and
-- no-ops instead of erroring). One animator wrapper per character, tracks cached.
--
-- An executor builds a move's ctx like:
--   local animator = context:GetService("AnimationController"):For(character)
--   Memo.execute(spec, { character = character, player = player, animator = animator })

local DEFAULT_FADE = 0.1

local AnimationController = {}

function AnimationController:Start(context)
	self._context = context
	self._library = {} -- [name] = "rbxassetid://..."
	self._rigs = setmetatable({}, { __mode = "k" }) -- [character] = wrapper (weak)
	self._warned = {}
end

-- Register name -> animation id pairs. Call as anims are authored:
--   AnimationController:RegisterLibrary({ DDD_Startup = "rbxassetid://123", ... })
function AnimationController:RegisterLibrary(map: { [string]: string })
	for name, id in map do
		self._library[name] = id
	end
end

-- Resolve a name (or a raw id) to an asset id, or nil.
function AnimationController:_resolve(name: string): string?
	if name:match("^rbxassetid://") or name:match("^%d+$") then
		return (name:match("^%d+$")) and ("rbxassetid://" .. name) or name
	end
	return self._library[name]
end

-- Get (or build) the animator wrapper for a character.
function AnimationController:For(character: Model)
	local existing = self._rigs[character]
	if existing then
		return existing
	end

	local controller = self
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if humanoid and not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local tracks: { [string]: AnimationTrack } = {}

	local wrapper = {}

	function wrapper:play(name: string, fade: number?)
		if not animator then
			return
		end
		local track = tracks[name]
		if not track then
			local id = controller:_resolve(name)
			if not id then
				if not controller._warned[name] then
					controller._warned[name] = true
					warn(("[AnimationController] no animation registered for '%s' (no-op until you add it)"):format(name))
				end
				return
			end
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			track = animator:LoadAnimation(anim)
			tracks[name] = track
		end
		track:Play(fade or DEFAULT_FADE)
		return track
	end

	function wrapper:stop(name: string, fade: number?)
		local track = tracks[name]
		if track then
			track:Stop(fade or DEFAULT_FADE)
		end
	end

	function wrapper:stopAll(fade: number?)
		for _, track in tracks do
			track:Stop(fade or DEFAULT_FADE)
		end
	end

	self._rigs[character] = wrapper
	return wrapper
end

return AnimationController
