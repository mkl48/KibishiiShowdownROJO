local TweenService = game:GetService("TweenService")
local Extensions   = script.Parent
local Features     = Extensions.Parent.Features
local Types        = require(Features.Types)
local Themes       = require(Features.Parent.Features.Themes) -- Moved up for performance

local Tabs = {}

Tabs.DefaultOptions = {
	Name    = "Tabs",
	Tabs    = {} :: { string },
	Default = nil :: string?,
	SelectedVariant = "Primary",
	Variant = "Ghost",
	OnChange = nil :: ((string) -> ())?,
}

function Tabs.new(Sleek, properties: Types.TabsProperties)
	local props = setmetatable(properties or {}, { __index = Tabs.DefaultOptions })

	local name      = props.Name
	local barName   = name .. "_Bar"
	local pageName  = name .. "_Pages"
	local tabList   = props.Tabs

	local C          = Sleek.theme.Colors
	local R          = Sleek.theme.Roundness
	local activeTab  = props.Default or (tabList[1] or "")
	local pageLayout : UIPageLayout

	local TAB_H      = Sleek.theme.Sizes.ButtonHeight or 36
	local PAGE_H     = 300

	local SelectedVariant = props.SelectedVariant
	local Variant = props.Variant

	Sleek:addScrollFrame(barName, {
		Size             = UDim2.new(1, 0, 0, TAB_H),
		BackgroundColor3 = C.Surface.Raised,
		IgnoreTheme      = true,
		ScrollingDirection  = Enum.ScrollingDirection.X,
	}):into(barName)

	Sleek:addCorner(barName .. "_Corner", R.CornerRoundness)
	Sleek:addList(barName .. "_Layout", {
		FillDirection       = Enum.FillDirection.Horizontal,
		SortOrder           = Enum.SortOrder.Name,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding             = UDim.new(0, 4),
	})
	Sleek:back()

	Sleek:addScrollFrame(pageName, {
		Size                   = UDim2.new(1, 0, 0, PAGE_H),
		ScrollBarThickness     = 0,
		AutomaticCanvasSize    = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		ScrollingEnabled       = false,
		IgnoreTheme            = true,
	})
		:into(pageName)
	local pl = Instance.new("UIPageLayout")
	pl.SortOrder        = Enum.SortOrder.LayoutOrder
	pl.FillDirection    = Enum.FillDirection.Horizontal
	pl.TweenTime        = 0.2
	pl.EasingStyle      = Enum.EasingStyle.Quad
	pl.TouchInputEnabled = false
	pl.GamepadInputEnabled = false
	pl.ScrollWheelInputEnabled = false
	pl.Parent           = Sleek:getElement(pageName).Instance
	pageLayout = pl
	Sleek:back()
	
	local function switchTo(tabLabel: string)
		if tabLabel == activeTab then return end
		activeTab = tabLabel

		for _, tl in tabList do
			local btnEl = Sleek:getElement(name .. "_Tab_" .. tl)
			if btnEl then
				btnEl.Instance:SetAttribute("Variant", tl == tabLabel and SelectedVariant or Variant)
				Themes.Apply(btnEl.Theme, btnEl.Instance)
			end
		end

		local pgEl = Sleek:getElement(name .. "_Page_" .. tabLabel)
		if pgEl then pageLayout:JumpTo(pgEl.Instance) end

		if props.OnChange then props.OnChange(tabLabel) end
	end

	-- Internal helper to build a single tab
	local function createTabInternal(label: string)
		local idx = #tabList + 1
		table.insert(tabList, label)

		-- Build Button in Bar
		Sleek:into(barName)
		local btnName = name .. "_Tab_" .. label
		Sleek:addButton(btnName, {
			Text        = label,
			Size        = UDim2.new(0, 100, 1, 0), -- Use fixed or flexible width
			Variant     = (label == activeTab) and SelectedVariant or Variant,
			LayoutOrder = idx,
		})

		Sleek:on(btnName, "Activated", function() switchTo(label) end)
		Sleek:back()

		-- Build Page in Container
		Sleek:into(pageName)
		local pgName = name .. "_Page_" .. label
		Sleek:addFrame(pgName, {
			Size                   = UDim2.fromScale(1, 1),
			LayoutOrder            = idx,
			IgnoreTheme            = true,
			BackgroundTransparency = 1,
		})
		Sleek:back()
	end

	for _, label in props.Tabs do
		tabList = {} 
		break
	end
	for _, label in props.Tabs do
		createTabInternal(label)
	end

	task.defer(function()
		local pgEl = Sleek:getElement(name .. "_Page_" .. activeTab)
		if pgEl then pageLayout:JumpTo(pgEl.Instance) end
	end)

	return {
		addTab = function(tabLabel: string)
			createTabInternal(tabLabel)
			return Sleek:getElement(name .. "_Page_" .. tabLabel)
		end,
		getPage = function(tabLabel: string)
			return Sleek:getElement(name .. "_Page_" .. tabLabel)
		end,
		switchTo = switchTo,
		getActive = function() return activeTab end,
	}
end

return Tabs