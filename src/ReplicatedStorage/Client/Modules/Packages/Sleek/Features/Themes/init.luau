local Types = require(script.Parent.Types)

local function reindex(children : { Instance }) : { [string]: Types.Theme }
	local map = {}
	for _, v in children do
		if v:IsA("ModuleScript") then
			map[v.Name] = require(v)
		end
	end
	return map
end

local Themes = {}
Themes._loaded = reindex(script:GetChildren()) :: { [string]: Types.Theme }

function Themes.Fetch(ThemeName : string) : Types.Theme
	return Themes._loaded[ThemeName] or Themes._loaded["Default"]
end

function Themes.Modify(CurrentTheme : Types.Theme, Modifications : Types.Theme) : Types.Theme
	local Result = {}
	for k, v in CurrentTheme do Result[k] = v end
	for k, v in Modifications do
		if typeof(v) == "table" and typeof(Result[k]) == "table" then
			Result[k] = Themes.Modify(Result[k], v)
		else
			Result[k] = v
		end
	end
	return Result
end

local SIZE_MAP = {
	XS      = "SizeXS",
	SM      = "SizeSM",
	MD      = "SizeMD",
	LG      = "SizeLG",
	XL      = "SizeXL",
	Title   = "SizeTitle",
	Display = "SizeDisplay",
}

local function resolveFont(T, w : string?)
	if     w == "Bold"   then return T.FontBold
	elseif w == "Medium" then return T.FontMedium
	else                      return T.Font
	end
end

local function resolveSize(T, key : string?, default : number) : number
	if not key then return default end
	local mapped = SIZE_MAP[key]
	return mapped and T[mapped] or default
end

local function resolveRoundness(R, key : string?)
	if not key then return R.CornerRoundness end
	return R[key] or R.CornerRoundness
end

local function applyOne(obj : Instance, theme : Types.Theme)
	if obj:GetAttribute("IgnoreTheme") then return end

	local skipColor = obj:GetAttribute("IgnorePrimaryColor") ~= nil
	local C = theme.Colors
	local R = theme.Roundness
	local T = theme.Text
	local S = theme.Sizes

	if obj:IsA("UICorner") then
		local p = obj.Parent
		if not p then return end

		local custom = p:GetAttribute("Roundness")
		if custom then
			obj.CornerRadius = R[custom] or R.CornerRoundness
		elseif p:IsA("TextButton") then
			obj.CornerRadius = R.ButtonRoundness
		elseif p:IsA("TextBox") or p:GetAttribute("Input") then
			obj.CornerRadius = R.InputRoundness
		elseif p:GetAttribute("Badge") then
			obj.CornerRadius = R.BadgeRoundness
		else
			obj.CornerRadius = R.CornerRoundness
		end
		return
	end

	if obj:IsA("UIStroke") then
		if not skipColor then
			obj.Color     = C.Surface.Border
			obj.Thickness = obj.Thickness > 0 and obj.Thickness or 1
		end
		return
	end

	if obj:IsA("ScrollingFrame") then
		if not skipColor then
			local e = obj:GetAttribute("Elevation") or 0
			if     e >= 2 then obj.BackgroundColor3 = C.Surface.Overlay
			elseif e == 1 then obj.BackgroundColor3 = C.Surface.Raised
			else               obj.BackgroundColor3 = C.Surface.Base
			end
			obj.ScrollBarImageColor3 = C.Surface.Subtle
		end
		return
	end

	if obj:IsA("Frame") then
		if not skipColor then
			local e = obj:GetAttribute("Elevation") or 0
			if     e >= 2 then obj.BackgroundColor3 = C.Surface.Overlay
			elseif e == 1 then obj.BackgroundColor3 = C.Surface.Raised
			else               obj.BackgroundColor3 = C.Surface.Base
			end
		end
		return
	end

	if obj:IsA("TextLabel") then
		if not skipColor then
			local role = obj:GetAttribute("TextRole") or "Primary"
			obj.TextColor3 = C.Text[role] or C.Text.Primary
		end
		obj.FontFace = resolveFont(T, obj:GetAttribute("FontWeight"))
		obj.TextSize = resolveSize(T, obj:GetAttribute("TextSize"), T.SizeMD)
		return
	end

	if obj:IsA("TextButton") then
		local variant = obj:GetAttribute("Variant") or "Primary"

		if not skipColor then
			local customVariant = theme.Variants and theme.Variants[variant]

			if customVariant then
				obj.BackgroundColor3       = customVariant.Background or C.Brand.BrandBlue
				obj.BackgroundTransparency = customVariant.Transparency or 0
				obj.TextColor3             = customVariant.Text or C.Brand.BrandWhite

				local stroke = obj:FindFirstChildOfClass("UIStroke")
				if stroke and customVariant.Outline then
					stroke.Color = customVariant.Outline
				end
				
			elseif variant == "Primary" then
				obj.BackgroundColor3       = C.Brand.BrandBlue
				obj.BackgroundTransparency = 0
				obj.TextColor3             = C.Brand.BrandWhite
			elseif variant == "Secondary" then
				obj.BackgroundColor3       = C.Surface.Overlay
				obj.BackgroundTransparency = 0
				obj.TextColor3             = C.Text.Primary
			elseif variant == "Danger" then
				obj.BackgroundColor3       = C.Brand.BrandRed
				obj.BackgroundTransparency = 0
				obj.TextColor3             = C.Brand.BrandWhite
			elseif variant == "Ghost" or variant == "Outline" then
				obj.BackgroundTransparency = 1
				obj.TextColor3             = C.Text.Primary
			else
				obj.TextColor3 = C.Text.Primary
			end
		end

		obj.FontFace = resolveFont(T, obj:GetAttribute("FontWeight"))
		obj.TextSize = resolveSize(T, obj:GetAttribute("TextSize"), T.SizeMD)
		return
	end

	if obj:IsA("TextBox") then
		if not skipColor then
			obj.BackgroundColor3  = C.Surface.Raised
			obj.TextColor3        = C.Text.Primary
			obj.PlaceholderColor3 = C.Text.Disabled
		end
		obj.FontFace = resolveFont(T, obj:GetAttribute("FontWeight"))
		obj.TextSize = resolveSize(T, obj:GetAttribute("TextSize"), T.SizeMD)
		return
	end

	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		if not skipColor then
			local role = obj:GetAttribute("TintRole")
			if role then
				obj.ImageColor3 = C.Text[role] or C.Brand[role] or obj.ImageColor3
			end
		end
		return
	end
end

function Themes.Apply(ThemeOrName : string | Types.Theme, Object : GuiObject)
	local theme : Types.Theme = typeof(ThemeOrName) == "string"
		and Themes.Fetch(ThemeOrName)
		or  ThemeOrName

	if not theme then
		warn("Themes.Apply: could not resolve theme →", tostring(ThemeOrName))
		return
	end

	applyOne(Object, theme)
	for _, obj in Object:GetDescendants() do
		applyOne(obj, theme)
	end
end

function Themes.ApplyLive(ThemeOrName : string | Types.Theme, Object : GuiObject) : RBXScriptConnection
	Themes.Apply(ThemeOrName, Object)

	return Object.DescendantAdded:Connect(function(obj)
		local theme : Types.Theme = typeof(ThemeOrName) == "string"
			and Themes.Fetch(ThemeOrName)
			or  ThemeOrName
		applyOne(obj, theme)
	end)
end

return Themes