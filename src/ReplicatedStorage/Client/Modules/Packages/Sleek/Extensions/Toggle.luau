local TweenService = game:GetService("TweenService")
local Extensions   = script.Parent
local Features     = Extensions.Parent.Features
local Types        = require(Features.Types)

local Toggle = {}

Toggle.DefaultOptions = {
	Name     = "Toggle",
	Label    = "Toggle",
	Default  = false,
	OnChange = nil :: ((boolean) -> ())?,
}

function Toggle.new(Sleek, properties: Types.ToggleProperties)
	local props = setmetatable(properties or {}, { __index = Toggle.DefaultOptions })

	local name      = props.Name
	local trackName = name .. "_Track"
	local thumbName = name .. "_Thumb"
	local labelName = name .. "_Label"
	local rowName   = name .. "_Row"

	local C      = Sleek.theme.Colors
	local R      = Sleek.theme.Roundness
	local on     = props.Default
	local locked = false

	local TRACK_W = 40
	local TRACK_H = 22
	local THUMB   = 16
	local PAD     = 3

	local offBg = C.Surface.Overlay
	local onBg  = C.Brand.BrandBlue

	Sleek:addFrame(rowName, {
		Size              = UDim2.new(1, 0, 0, Sleek.theme.Sizes.ButtonHeight),
		BackgroundTransparency = 1,
		IgnoreTheme       = true,
	})
	Sleek:into(rowName)

	Sleek:addLabel(labelName, {
		Text     = props.Label,
		Size     = UDim2.new(1, -(TRACK_W + 8), 1, 0),
		Position = UDim2.fromOffset(0, 0),
	})

	Sleek:addFrame(trackName, {
		Size              = UDim2.fromOffset(TRACK_W, TRACK_H),
		Position          = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint       = Vector2.new(1, 0.5),
		BackgroundColor3  = on and onBg or offBg,
		IgnoreTheme       = true,
	})
	Sleek:into(trackName)
	Sleek:addCorner(trackName .. "_Corner", UDim.new(1, 0))
	Sleek:addFrame(thumbName, {
		Size             = UDim2.fromOffset(THUMB, THUMB),
		Position         = UDim2.fromOffset(on and (TRACK_W - THUMB - PAD) or PAD, PAD),
		BackgroundColor3 = Color3.new(1, 1, 1),
		IgnoreTheme      = true,
	})
	Sleek:into(thumbName)
	Sleek:addCorner(thumbName .. "_Corner", UDim.new(1, 0))
	Sleek:back()
	Sleek:back()

	Sleek:back() -- out of rowName

	local function animate(state: boolean)
		local trackEl = Sleek:getElement(trackName)
		local thumbEl = Sleek:getElement(thumbName)
		if not trackEl or not thumbEl then return end

		local targetX = state and (TRACK_W - THUMB - PAD) or PAD
		local targetC = state and onBg or offBg

		local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(trackEl.Instance, ti, { BackgroundColor3 = targetC }):Play()
		TweenService:Create(thumbEl.Instance, ti, { Position = UDim2.fromOffset(targetX, PAD) }):Play()
	end

	for _, target in { trackName, rowName } do
		local el = Sleek:getElement(target)
		if el and el.Instance:IsA("GuiButton") or el and el.Instance:IsA("Frame") then
			el.Instance.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch then return end
				if locked then return end
				locked = true
				on = not on
				animate(on)
				task.delay(0.2, function() locked = false end)
				if props.OnChange then props.OnChange(on) end
			end)
		end
	end

	local trackEl = Sleek:getElement(trackName)
	if trackEl then
		trackEl.Instance.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then return end
			if locked then return end
			locked = true
			on = not on
			animate(on)
			task.delay(0.2, function() locked = false end)
			if props.OnChange then props.OnChange(on) end
		end)
	end

	return {
		getValue = function() return on end,
		setValue = function(state: boolean)
			on = state
			animate(state)
			if props.OnChange then props.OnChange(on) end
		end,
	}
end

return Toggle