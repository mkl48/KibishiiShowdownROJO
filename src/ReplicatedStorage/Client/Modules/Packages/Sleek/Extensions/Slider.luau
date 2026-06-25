local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Extensions       = script.Parent
local Features         = Extensions.Parent.Features
local Types            = require(Features.Types)

local Slider = {}

Slider.DefaultOptions = {
	Name     = "Slider",
	Label    = "Slider",
	Min      = 0,
	Max      = 100,
	Default  = 50,
	Step     = 1,
	OnChange = nil :: ((number) -> ())?,
}

function Slider.new(Sleek, properties: Types.SliderProperties)
	local props = setmetatable(properties or {}, { __index = Slider.DefaultOptions })

	local name      = props.Name
	local trackName = name .. "_Track"
	local fillName  = name .. "_Fill"
	local thumbName = name .. "_Thumb"
	local labelName = name .. "_Label"
	local valueName = name .. "_Value"
	local rowName   = name .. "_Row"

	local C   = Sleek.theme.Colors
	local min = props.Min
	local max = props.Max
	local step = props.Step
	local value = math.clamp(props.Default, min, max)

	local TRACK_H  = 6
	local THUMB_SZ = 16
	local ROW_H    = Sleek.theme.Sizes.ButtonHeight + 24

	local function snapToStep(v: number): number
		return math.clamp(math.round((v - min) / step) * step + min, min, max)
	end

	local function normalise(v: number): number
		return (v - min) / (max - min)
	end

	Sleek:addFrame(rowName, {
		Size                   = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
		IgnoreTheme            = true,
	})
	Sleek:into(rowName)

	Sleek:addLabel(labelName, {
		Text     = props.Label,
		Size     = UDim2.new(0.7, 0, 0, Sleek.theme.Sizes.LabelHeight),
		Position = UDim2.fromOffset(0, 0),
	})
	Sleek:addLabel(valueName, {
		Text           = tostring(value),
		Size           = UDim2.new(0.3, 0, 0, Sleek.theme.Sizes.LabelHeight),
		Position       = UDim2.new(0.7, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	Sleek:addFrame(trackName, {
		Size             = UDim2.new(1, 0, 0, TRACK_H),
		Position         = UDim2.new(0, 0, 1, -(THUMB_SZ / 2)),
		AnchorPoint      = Vector2.new(0, 1),
		BackgroundColor3 = C.Surface.Overlay,
		IgnoreTheme      = true,
	})
	Sleek:into(trackName)
	Sleek:addCorner(trackName .. "_Corner", UDim.new(1, 0))

	Sleek:addFrame(fillName, {
		Size             = UDim2.new(normalise(value), 0, 1, 0),
		BackgroundColor3 = C.Brand.BrandBlue,
		IgnoreTheme      = true,
	})
	Sleek:into(fillName)
	Sleek:addCorner(fillName .. "_Corner", UDim.new(1, 0))
	Sleek:back()

	Sleek:addFrame(thumbName, {
		Size             = UDim2.fromOffset(THUMB_SZ, THUMB_SZ),
		Position         = UDim2.new(normalise(value), -THUMB_SZ / 2, 0.5, -THUMB_SZ / 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex           = 5,
		IgnoreTheme      = true,
	})
	Sleek:into(thumbName)
	Sleek:addCorner(thumbName .. "_Corner", UDim.new(1, 0))
	Sleek:back()
	Sleek:back() -- trackName

	Sleek:back() -- rowName

	local trackEl = Sleek:getElement(trackName)
	local fillEl  = Sleek:getElement(fillName)
	local thumbEl = Sleek:getElement(thumbName)
	local valEl   = Sleek:getElement(valueName)

	local dragging = false
	local conn: RBXScriptConnection

	local function updateFromPos(absX: number)
		local trackAbs = trackEl.Instance.AbsolutePosition.X
		local trackSz  = trackEl.Instance.AbsoluteSize.X
		local ratio    = math.clamp((absX - trackAbs) / trackSz, 0, 1)
		local raw      = min + ratio * (max - min)
		local snapped  = snapToStep(raw)
		if snapped == value then return end
		value = snapped

		local n = normalise(value)
		fillEl.Instance.Size     = UDim2.new(n, 0, 1, 0)
		thumbEl.Instance.Position = UDim2.new(n, -THUMB_SZ / 2, 0.5, -THUMB_SZ / 2)
		valEl.Instance.Text      = tostring(value)

		if props.OnChange then props.OnChange(value) end
	end

	trackEl.Instance.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		dragging = true
		updateFromPos(input.Position.X)
		conn = UserInputService.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
				or i.UserInputType == Enum.UserInputType.Touch) then
				updateFromPos(i.Position.X)
			end
		end)
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			if conn then conn:Disconnect() ; conn = nil end
		end
	end)

	return {
		getValue = function() return value end,
		setValue = function(v: number)
			value = snapToStep(v)
			local n = normalise(value)
			fillEl.Instance.Size          = UDim2.new(n, 0, 1, 0)
			thumbEl.Instance.Position     = UDim2.new(n, -THUMB_SZ / 2, 0.5, -THUMB_SZ / 2)
			valEl.Instance.Text           = tostring(value)
			if props.OnChange then props.OnChange(value) end
		end,
	}
end

return Slider