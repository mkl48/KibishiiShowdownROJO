local Extensions = script.Parent
local Features   = Extensions.Parent.Features
local Types      = require(Features.Types)

local Badge = {}

Badge.DefaultOptions = {
	Name    = "Badge",
	Target  = nil :: (string | Instance)?, 
	Text    = "New",
	Variant = "Primary", 
	Size    = UDim2.fromOffset(0, 20),
}

local VARIANT_COLORS = {
	Primary   = function(C) return C.Brand.BrandBlue,   C.Brand.BrandWhite end,
	Secondary = function(C) return C.Surface.Overlay,   C.Text.Primary      end,
	Danger    = function(C) return C.Brand.BrandRed,    C.Brand.BrandWhite end,
	Ghost     = function(C) return C.Surface.Base,      C.Text.Secondary   end,
}

function Badge.new(Sleek, properties: Types.BadgeProperties)
	local props = setmetatable(properties or {}, { __index = Badge.DefaultOptions })

	local name    = props.Name
	local txtName = name .. "_Text"
	local C       = Sleek.theme.Colors
	local T       = Sleek.theme.Text

	local colorFn = VARIANT_COLORS[props.Variant] or VARIANT_COLORS.Primary
	local bg, fg  = colorFn(C)

	if props.Target then
		Sleek:into(props.Target)
	end

	Sleek:addCanvasGroup(name, {
		AutomaticSize    = Enum.AutomaticSize.X,
		Size             = props.Size,
		BackgroundColor3 = bg,
		IgnoreTheme      = true,
		ZIndex           = 2000,
	})
		:into(name)
	Sleek:addCorner(name .. "_Corner", UDim.new(1, 0))
	Sleek:addPadding(name .. "_Pad",   UDim.new(0, 8), UDim.new(0, 0))

	Sleek:addLabel(txtName, {
		Text           = props.Text,
		TextColor3     = fg,
		AutomaticSize  = Enum.AutomaticSize.X,
		Size           = UDim2.new(0, 0, 1, 0),
		TextSize       = T.SizeSM or T.SizeMD - 2,
		FontFace       = T.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		IgnoreTheme    = true,
	})
	Sleek:back() 

	local badgeEl = Sleek:getElement(name)
	if badgeEl then
		local inst = badgeEl.Instance
		if inst:IsA("GuiObject") then
			inst.LayoutOrder = -999999
		end
	end

	if props.Target then
		Sleek:back()
	end

	return {
		Instance = badgeEl.Instance,
		setText = function(text: string)
			local el = Sleek:getElement(txtName)
			if el then el.Instance.Text = text end
		end,
		setVariant = function(variant: string)
			local fn = VARIANT_COLORS[variant] or VARIANT_COLORS.Primary
			local newBg, newFg = fn(C)
			local bgEl  = Sleek:getElement(name)
			local txtEl = Sleek:getElement(txtName)
			if bgEl  then bgEl.Instance.BackgroundColor3 = newBg end
			if txtEl then txtEl.Instance.TextColor3      = newFg end
		end,
	}
end

return Badge