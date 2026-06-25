local Extensions = script.Parent
local Features = Extensions.Parent.Features
local Types = require(Features.Types)
local Themes = require(Features.Themes)
local TweenService = game:GetService("TweenService")

local Dropdown = {}

Dropdown.DefaultOptions = {
	Name = "Dropdown",
	Options = {},
	Placeholder = "Select Option",
	Icon = "rbxassetid://10709790948",

	Variant = "Secondary",
	SelectedVariant = "Primary",
	OptionVariant = "Secondary",
	OptionHeight = 32,

	OnChange = nil :: ((string) -> ())?,
}

local function animateToggle(api, list, icon, mainBtnName, expanding)
	local listEl = api:getElement(list).Instance
	local iconEl = api:getElement(icon).Instance
	local mainBtn = api:getElement(mainBtnName).Instance
	local scaleEl = listEl:FindFirstChildOfClass("UIScale")

	mainBtn.ClipsDescendants = not expanding 

	if expanding then
		listEl.Visible = true
		if scaleEl then scaleEl.Scale = 0.98 end
		api:tween(list, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 1, 6) }, 0.2, Enum.EasingStyle.Quart)
		api:tween(icon, { Rotation = 180 }, 0.2, Enum.EasingStyle.Back)
		if scaleEl then TweenService:Create(scaleEl, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play() end
	else
		api:tween(icon, { Rotation = 0 }, 0.2, Enum.EasingStyle.Back)
		api:tween(list, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 1, 2) }, 0.15, Enum.EasingStyle.Quad, function()
			listEl.Visible = false
		end)
		if scaleEl then TweenService:Create(scaleEl, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Scale = 0.96 }):Play() end
	end
end

function Dropdown.new(Sleek, properties: Types.DropdownProperties)
	local props = setmetatable(properties or {}, { __index = Dropdown.DefaultOptions })

	local name = props.Name
	local listName = name .. "_List"
	local iconName = name .. "_Icon"
	local currentSelection = nil
	local isOpen = false

	local C       = Sleek.theme.Colors
	local R       = Sleek.theme.Roundness
	local T       = Sleek.theme.Text
	local S       = Sleek.theme.Spacing

	Sleek:addButton(name, {
		Text = props.Placeholder,
		Variant = props.Variant,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = false,
	})
		:into(name)

	Sleek:addPadding(name .. "_Padding", UDim.new(0, 12), UDim.new(0, 0))

	Sleek:addImage(iconName, {
		Image = props.Icon,
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		ImageTransparency = 0.4,
	})

	Sleek:addCanvasGroup(listName, {
		Visible = false,
		Size = UDim2.new(1, 0, 0, 0), 
		Position = UDim2.new(0.5, 0, 1, 2),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 1000,
		AutomaticSize = Enum.AutomaticSize.Y,
		GroupTransparency = 1,
		BackgroundColor3 = Sleek.theme.Colors.Surface.Raised,
	})

	Sleek:modifyElement(listName, {
		Roundness = { CornerRoundness = UDim.new(0, 6) }
	})

	Sleek:into(listName)
	Sleek:addPadding(listName .. "_Padding", UDim.new(0, 4), UDim.new(0, 4))
	Sleek:addScale(listName .. "_Scale", 1)
	Sleek:addStroke(listName .. "_Stroke", { Color = Sleek.theme.Colors.Surface.Border, Transparency = 0.6 })
	Sleek:addList(listName .. "_Layout", { Padding = UDim.new(0, 4) })

	for optionName, optionData in props.Options do
		local optBtnName = listName .. "_" .. optionName
		local callback = typeof(optionData) == "function" and optionData or (typeof(optionData) == "table" and optionData.Callback)

		Sleek:addButton(optBtnName, {
			Size = UDim2.new(1, 0, 0, props.OptionHeight),
			Text =  string.rep(" ", S.XS.Offset) .. optionName,
			Variant = props.OptionVariant,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
			:on(optBtnName, "MouseButton1Click", function()
				if currentSelection then
					Sleek:modifyElement(listName .. "_" .. currentSelection, { Variant = props.OptionVariant })
				end

				currentSelection = optionName
				Sleek:modifyElement(optBtnName, { Variant = props.SelectedVariant })
				Sleek:modifyElement(name, { Text = optionName, Variant = props.SelectedVariant })

				if callback then callback() end
				if props.OnChange then props.OnChange(optionName) end

				isOpen = false
				animateToggle(Sleek, listName, iconName, name, false)
			end)
	end

	Sleek:back(2)
	--Sleek:back()

	Sleek:on(name, "MouseButton1Click", function()
		isOpen = not isOpen
		animateToggle(Sleek, listName, iconName, name, isOpen)
	end)

	return Sleek:getElement(name)
end

return Dropdown