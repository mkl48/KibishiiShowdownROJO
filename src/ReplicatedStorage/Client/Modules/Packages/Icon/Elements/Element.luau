--!nonstrict
-- Element.lua  (Material — complete rewrite)
-- Typed constructors for TopbarPlus dropdown / menu children.
-- Each returns a real Icon instance that can be passed to :setDropdown() / :setMenu().
-- Call Element._init(Icon) once before use (done automatically by Icon.lua).

-- ─────────────────────────────────────────────────────────────────────────────
-- DESIGN NOTES
--
-- TopbarPlus widgets have no "Contents" frame.  The correct injection target
-- is the widget Frame itself (icon:getInstance("Widget")).  All accessories
-- are parented there with high ZIndex so they sit above the IconButton layer.
--
-- Drag logic for sliders uses UserInputService.InputChanged (fires every frame
-- with mouse delta) rather than TextButton.MouseMoved (unreliable).
--
-- Every element that needs a right-hand accessory uses a consistent layout:
--   • IconLabel  anchors Left, so it acts as the row title
--   • Accessory frame anchors Right inside the Widget
-- ─────────────────────────────────────────────────────────────────────────────

local Element    = {}
local _Icon

-- ── Services ──────────────────────────────────────────────────────────────────
local TweenService    = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService      = game:GetService("RunService")

-- ── Design tokens ─────────────────────────────────────────────────────────────
local ACCENT   = Color3.fromRGB(108, 62, 244)
local ACCENT2  = Color3.fromRGB(80,  180, 255)
local SUCCESS  = Color3.fromRGB(60,  200, 120)
local WARN     = Color3.fromRGB(240, 160,  40)
local DANGER   = Color3.fromRGB(220,  60,  60)
local MUTED    = Color3.fromRGB(140, 140, 160)
local WHITE    = Color3.new(1, 1, 1)
local DIVIDER  = Color3.fromRGB(50,  50,  60)
local SURFACE  = Color3.fromRGB(25,  25,  32)

local ROW_W    = 190
local EASING   = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASING_FAST = TweenInfo.new(0.08, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- ── Shared helpers ────────────────────────────────────────────────────────────

-- Wait for the widget to be ready, then call fn(widget).
-- TopbarPlus builds the widget tree asynchronously so we must defer.
local function withWidget(icon, fn)
	task.defer(function()
		local widget = icon:getInstance("Widget")
		if widget then fn(widget) end
	end)
end

-- Inject a GuiObject as a right-hand accessory inside the Widget frame.
-- pos / size are optional UDim2 overrides; defaults place it on the right.
local function injectRight(icon, instance, widthPx, offsetY)
	withWidget(icon, function(widget)
		instance.AnchorPoint = Vector2.new(1, 0.5)
		instance.Position    = UDim2.new(1, -(offsetY or 12), 0.5, 0)
		instance.Size        = UDim2.new(0, widthPx, 0, widthPx)
		instance.ZIndex      = 25
		instance.Parent      = widget
	end)
end

-- Inject at an absolute position inside the Widget.
local function injectAt(icon, instance, pos, size)
	withWidget(icon, function(widget)
		instance.Position = pos
		instance.Size     = size
		instance.ZIndex   = instance.ZIndex or 25
		instance.Parent   = widget
	end)
end

-- Make an icon non-interactive (locked, no overlay, won't auto-deselect).
local function makeInert(icon)
	icon:lock()
	icon:disableOverlay(true)
	icon:autoDeselect(false)
end

-- Rounded corner helper.
local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = parent
	return c
end

-- UIStroke helper.
local function addStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color        = color or ACCENT
	s.Thickness    = thickness or 1.5
	s.Transparency = transparency or 0
	s.Parent       = parent
	return s
end

-- Tween shorthand.
local function tween(instance, info, props)
	TweenService:Create(instance, info, props):Play()
end

-- ── _init ─────────────────────────────────────────────────────────────────────
function Element._init(Icon)
	_Icon = Icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ITEM  — standard selectable row
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label       : string | nil,
    image       : number | string | nil,
    description : string | nil,   -- small subtitle line below label
    badge       : string | nil,   -- short text pill on the right ("NEW", "HOT", etc)
    badgeColor  : Color3 | nil,   -- pill background, default ACCENT
    disabled    : boolean | nil,  -- locks and dims the row
    onSelect    : function(icon) | nil,
}
--]]
function Element.item(cfg)
	cfg = cfg or {}
	local icon = _Icon.new()

	if cfg.label then icon:setLabel(cfg.label) end
	if cfg.image then icon:setImage(cfg.image) end
	if cfg.onSelect then icon:onSelect(cfg.onSelect) end

	if cfg.description then
		withWidget(icon, function(widget)
			local sub = Instance.new("TextLabel")
			sub.Name                  = "ItemDescription"
			sub.Size                  = UDim2.new(1, -16, 0, 14)
			sub.Position              = UDim2.new(0, 8, 1, -18)
			sub.AnchorPoint           = Vector2.new(0, 1)
			sub.BackgroundTransparency = 1
			sub.Text                  = cfg.description
			sub.TextColor3            = MUTED
			sub.TextSize              = 11
			sub.Font                  = Enum.Font.Gotham
			sub.TextXAlignment        = Enum.TextXAlignment.Left
			sub.ZIndex                = 25
			sub.Parent                = widget
		end)
		icon:modifyTheme({ { "Widget", "MinimumHeight", 62 } })
	end

	if cfg.badge then
		withWidget(icon, function(widget)
			local pill = Instance.new("Frame")
			pill.Name             = "ItemBadge"
			pill.Size             = UDim2.new(0, 36, 0, 18)
			pill.AnchorPoint      = Vector2.new(1, 0.5)
			pill.Position         = UDim2.new(1, -10, 0.5, 0)
			pill.BackgroundColor3 = cfg.badgeColor or ACCENT
			pill.BorderSizePixel  = 0
			pill.ZIndex           = 26
			addCorner(pill, UDim.new(1, 0))

			local lbl = Instance.new("TextLabel")
			lbl.Size                  = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text                  = cfg.badge
			lbl.TextColor3            = WHITE
			lbl.TextSize              = 10
			lbl.Font                  = Enum.Font.GothamBold
			lbl.ZIndex                = 27
			lbl.Parent                = pill

			pill.Parent = widget
		end)
	end

	if cfg.disabled then
		icon:lock()
		icon:modifyTheme({ { "IconButton", "BackgroundTransparency", 0.5 } })
		withWidget(icon, function(widget)
			local overlay = Instance.new("Frame")
			overlay.Size                  = UDim2.fromScale(1, 1)
			overlay.BackgroundColor3      = Color3.new(0, 0, 0)
			overlay.BackgroundTransparency = 0.6
			overlay.BorderSizePixel       = 0
			overlay.ZIndex                = 50
			overlay.Name                  = "DisabledOverlay"
			overlay.Parent                = widget
		end)
	end

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. HEADER  — section label, non-interactive
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    text      : string,
    showLine  : boolean | nil,   -- show separator line above (default true)
    icon      : number | nil,    -- optional small icon asset ID
}
--]]
function Element.header(textOrCfg)
	local cfg = type(textOrCfg) == "table" and textOrCfg or { text = textOrCfg }
	local icon = _Icon.new()
	makeInert(icon)

	local showLine = cfg.showLine ~= false  -- default true

	icon:modifyTheme({
		{ "Widget", "MinimumHeight", 32 },
		{ "Widget", "MinimumWidth",  ROW_W },
	})
	icon:setLabel(cfg.text and string.upper(cfg.text) or "")
	icon:setTextColor(MUTED)
	icon:setTextSize(11)

	if cfg.icon then icon:setImage(cfg.icon) end

	if showLine then
		withWidget(icon, function(widget)
			local line = Instance.new("Frame")
			line.Name                  = "HeaderLine"
			line.Size                  = UDim2.new(1, -20, 0, 1)
			line.Position              = UDim2.new(0, 10, 0, 0)
			line.BackgroundColor3      = DIVIDER
			line.BackgroundTransparency = 0
			line.BorderSizePixel       = 0
			line.ZIndex                = 30
			line.Parent                = widget
		end)
	end

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. DIVIDER  — visual separator
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label : string | nil,   -- optional centered label ("OR", "─ More ─")
    color : Color3 | nil,
}
--]]
function Element.divider(cfg)
	cfg = cfg or {}
	local icon = _Icon.new()
	makeInert(icon)

	icon:modifyTheme({
		{ "Widget",     "MinimumHeight",          cfg.label and 24 or 10 },
		{ "Widget",     "MinimumWidth",            ROW_W },
		{ "IconButton", "BackgroundTransparency",  1 },
	})

	withWidget(icon, function(widget)
		local line = Instance.new("Frame")
		line.Name                  = "DividerLine"
		line.Size                  = UDim2.new(1, -20, 0, 1)
		line.AnchorPoint           = Vector2.new(0, 0.5)
		line.Position              = UDim2.new(0, 10, 0.5, 0)
		line.BackgroundColor3      = cfg.color or DIVIDER
		line.BackgroundTransparency = 0
		line.BorderSizePixel       = 0
		line.ZIndex                = 30
		line.Parent                = widget

		if cfg.label then
			local lbl = Instance.new("TextLabel")
			lbl.Size                  = UDim2.new(0, 60, 1, 0)
			lbl.AnchorPoint           = Vector2.new(0.5, 0.5)
			lbl.Position              = UDim2.fromScale(0.5, 0.5)
			lbl.BackgroundColor3      = Color3.fromRGB(10, 10, 14) -- match dropdown bg
			lbl.BackgroundTransparency = 1
			lbl.Text                  = cfg.label
			lbl.TextColor3            = MUTED
			lbl.TextSize              = 11
			lbl.Font                  = Enum.Font.GothamMedium
			lbl.ZIndex                = 31
			lbl.Parent                = widget
		end
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. TOGGLE  — boolean pill switch
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label    : string,
    value    : boolean,
    onChange : function(newValue: boolean) | nil,
    color    : Color3 | nil,   -- active colour, default ACCENT
}
--]]
function Element.toggle(cfg)
	cfg = cfg or {}
	local icon  = _Icon.new()
	local state = cfg.value == true
	local activeColor = cfg.color or ACCENT

	if cfg.label then icon:setLabel(cfg.label) end
	icon:autoDeselect(false)
	icon:disableOverlay(true)

	-- Pill
	local pill = Instance.new("Frame")
	pill.Name             = "TogglePill"
	pill.Size             = UDim2.fromOffset(34, 18)
	pill.BackgroundColor3 = state and activeColor or DIVIDER
	pill.BorderSizePixel  = 0
	addCorner(pill)

	local knob = Instance.new("Frame")
	knob.Name             = "Knob"
	knob.Size             = UDim2.fromOffset(12, 12)
	knob.AnchorPoint      = Vector2.new(0.5, 0.5)
	knob.Position         = state and UDim2.new(0.75, 0, 0.5, 0) or UDim2.new(0.28, 0, 0.5, 0)
	knob.BackgroundColor3 = WHITE
	knob.BorderSizePixel  = 0
	knob.ZIndex           = 2
	addCorner(knob)
	knob.Parent = pill

	injectRight(icon, pill, 34, 10)

	local function applyState(on, instant)
		local info = instant and TweenInfo.new(0) or EASING
		tween(pill,  info, { BackgroundColor3 = on and activeColor or DIVIDER })
		tween(knob,  info, { Position = on and UDim2.new(0.75, 0, 0.5, 0) or UDim2.new(0.28, 0, 0.5, 0) })
	end
	applyState(state, true)

	-- Click toggles state; immediately deselect so icon doesn't stay "selected"
	icon:onSelect(function()
		state = not state
		applyState(state, false)
		icon:deselect()
		if cfg.onChange then cfg.onChange(state) end
	end)

	-- Expose a programmatic setter
	icon.setValue = function(_, newVal)
		state = newVal == true
		applyState(state, false)
		if cfg.onChange then cfg.onChange(state) end
	end

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. SLIDER  — draggable value track
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label    : string,
    min      : number,   default 0
    max      : number,   default 1
    default  : number,   default min
    step     : number | nil,
    color    : Color3 | nil,
    onChange : function(value: number) | nil,
}
--]]
function Element.slider(cfg)
	cfg = cfg or {}
	local icon    = _Icon.new()
	local minV    = cfg.min     or 0
	local maxV    = cfg.max     or 1
	local stepV   = cfg.step
	local current = math.clamp(cfg.default or minV, minV, maxV)
	local trackColor = cfg.color or ACCENT

	if cfg.label then icon:setLabel(cfg.label) end
	makeInert(icon)
	icon:modifyTheme({ { "Widget", "MinimumHeight", 64 } })

	-- Track
	local track = Instance.new("Frame")
	track.Name             = "SliderTrack"
	track.BackgroundColor3 = DIVIDER
	track.BorderSizePixel  = 0
	addCorner(track)

	local fill = Instance.new("Frame")
	fill.Name             = "SliderFill"
	fill.Size             = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = trackColor
	fill.BorderSizePixel  = 0
	addCorner(fill)
	fill.Parent = track

	local thumb = Instance.new("Frame")
	thumb.Name             = "SliderThumb"
	thumb.Size             = UDim2.fromOffset(14, 14)
	thumb.AnchorPoint      = Vector2.new(0.5, 0.5)
	thumb.BackgroundColor3 = WHITE
	thumb.BorderSizePixel  = 0
	thumb.ZIndex           = 6
	addCorner(thumb)
	addStroke(thumb, trackColor, 2, 0)
	thumb.Parent = track

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name                = "SliderValue"
	valueLabel.BackgroundTransparency = 1
	valueLabel.TextColor3          = MUTED
	valueLabel.TextSize            = 11
	valueLabel.Font                = Enum.Font.GothamMedium
	valueLabel.TextXAlignment      = Enum.TextXAlignment.Right
	valueLabel.ZIndex              = 30

	local function snap(raw)
		if not stepV then return raw end
		return math.round((raw - minV) / stepV) * stepV + minV
	end

	local function formatVal(v)
		if stepV and stepV >= 1 then return tostring(math.round(v)) end
		return string.format("%.2f", v)
	end

	local function updateVisuals(val, instant)
		local pct = math.clamp((val - minV) / math.max(maxV - minV, 0.0001), 0, 1)
		local info = instant and TweenInfo.new(0) or EASING_FAST
		tween(fill,  info, { Size     = UDim2.new(pct, 0, 1, 0) })
		tween(thumb, info, { Position = UDim2.new(pct, 0, 0.5, 0) })
		valueLabel.Text = formatVal(val)
	end

	updateVisuals(current, true)

	withWidget(icon, function(widget)
		-- Layout track and value label inside widget
		track.Size     = UDim2.new(1, -32, 0, 4)
		track.AnchorPoint = Vector2.new(0.5, 1)
		track.Position = UDim2.new(0.5, 0, 1, -12)
		track.Parent   = widget

		valueLabel.Size        = UDim2.new(0, 40, 0, 16)
		valueLabel.AnchorPoint = Vector2.new(1, 0)
		valueLabel.Position    = UDim2.new(1, -6, 0, 8)
		valueLabel.Parent      = widget

		-- Transparent drag region over the whole widget
		local drag = Instance.new("TextButton")
		drag.Name                  = "SliderDrag"
		drag.Size                  = UDim2.fromScale(1, 1)
		drag.BackgroundTransparency = 1
		drag.Text                  = ""
		drag.ZIndex                = 40
		drag.Parent                = widget

		local dragging = false

		local function valueFromAbsX(absX)
			local tAbs  = track.AbsolutePosition.X
			local tSize = track.AbsoluteSize.X
			local pct   = math.clamp((absX - tAbs) / math.max(tSize, 1), 0, 1)
			return snap(math.clamp(minV + pct * (maxV - minV), minV, maxV))
		end

		drag.MouseButton1Down:Connect(function()
			dragging = true
			-- sample mouse pos immediately
			local mp = UserInputService:GetMouseLocation()
			current  = valueFromAbsX(mp.X)
			updateVisuals(current, false)
			if cfg.onChange then cfg.onChange(current) end
		end)

		drag.MouseButton1Up:Connect(function()
			dragging = false
		end)

		-- Touch support
		drag.TouchLongPress:Connect(function()
			dragging = true
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				local absX = input.Position.X
				current    = valueFromAbsX(absX)
				updateVisuals(current, false)
				if cfg.onChange then cfg.onChange(current) end
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end)

	icon.setValue = function(_, val)
		current = snap(math.clamp(val, minV, maxV))
		updateVisuals(current, false)
	end

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. DISPLAY  — read-only reactive value row
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label   : string,
    value   : any,            -- initial display value (tostring'd)
                              -- can also be a ValueBase / Ink.Var / anything
                              -- with .Changed or .changed signal
    color   : Color3 | nil,  -- value text colour, default ACCENT
    prefix  : string | nil,  -- prepended to value  e.g. "$"
    suffix  : string | nil,  -- appended  to value  e.g. " ms"
    format  : function(v) | nil,  -- custom formatter, overrides prefix/suffix
}
--]]
function Element.display(cfg)
	cfg = cfg or {}
	local icon = _Icon.new()
	makeInert(icon)

	if cfg.label then icon:setLabel(cfg.label) end

	local valLabel = Instance.new("TextLabel")
	valLabel.Name                  = "DisplayValue"
	valLabel.Size                  = UDim2.new(0, 70, 0.6, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.BorderSizePixel       = 0
	valLabel.TextColor3            = cfg.color or ACCENT
	valLabel.TextSize              = 14
	valLabel.Font                  = Enum.Font.GothamBold
	valLabel.TextXAlignment        = Enum.TextXAlignment.Right
	valLabel.ZIndex                = 25

	local function render(v)
		if cfg.format then
			valLabel.Text = tostring(cfg.format(v))
		else
			local s = tostring(v)
			valLabel.Text = (cfg.prefix or "") .. s .. (cfg.suffix or "")
		end
	end

	render(cfg.value or "")

	-- Reactive binding: ValueBase, Ink.Var (.changed), or anything with .Changed
	local source = cfg.value
	if typeof(source) == "Instance" and source:IsA("ValueBase") then
		source.Changed:Connect(function(v) render(v) end)
	elseif type(source) == "table" then
		local sig = rawget(source, "changed") or rawget(source, "Changed")
		if sig and type(sig.Connect) == "function" then
			sig:Connect(function(v) render(v) end)
		end
	end

	injectRight(icon, valLabel, 70, 8)

	-- Expose a programmatic setter
	icon.setValue = function(_, v) render(v) end

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. INPUT  — single-line text field
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label       : string | nil,
    placeholder : string | nil,
    default     : string | nil,
    maxLength   : number | nil,
    onSubmit    : function(text: string) | nil,
    onChange    : function(text: string) | nil,   -- fires on every keystroke
    clearOnSubmit : boolean | nil,                -- default true
}
--]]
function Element.input(cfg)
	cfg = cfg or {}
	local icon = _Icon.new()
	makeInert(icon)

	if cfg.label then icon:setLabel(cfg.label) end
	icon:modifyTheme({ { "Widget", "MinimumHeight", 68 } })

	withWidget(icon, function(widget)
		local box = Instance.new("TextBox")
		box.Name                  = "InputBox"
		box.Size                  = UDim2.new(1, -20, 0, 28)
		box.AnchorPoint           = Vector2.new(0.5, 1)
		box.Position              = UDim2.new(0.5, 0, 1, -8)
		box.BackgroundColor3      = SURFACE
		box.BackgroundTransparency = 0
		box.BorderSizePixel       = 0
		box.TextColor3            = WHITE
		box.PlaceholderText       = cfg.placeholder or ""
		box.PlaceholderColor3     = MUTED
		box.Text                  = cfg.default or ""
		box.TextSize              = 13
		box.Font                  = Enum.Font.Gotham
		box.ClearTextOnFocus      = false
		box.ZIndex                = 30
		addCorner(box, UDim.new(0, 6))

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft  = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent       = box

		local stroke = addStroke(box, ACCENT, 1.5, 1)

		box.Focused:Connect(function()
			tween(stroke, EASING, { Transparency = 0 })
		end)
		box.FocusLost:Connect(function(enter)
			tween(stroke, EASING, { Transparency = 1 })
			if enter and cfg.onSubmit then
				cfg.onSubmit(box.Text)
				if cfg.clearOnSubmit ~= false then box.Text = "" end
			end
		end)
		if cfg.onChange then
			box:GetPropertyChangedSignal("Text"):Connect(function()
				if cfg.maxLength and #box.Text > cfg.maxLength then
					box.Text = string.sub(box.Text, 1, cfg.maxLength)
				end
				cfg.onChange(box.Text)
			end)
		end

		box.Parent = widget
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. NUMBER STEPPER  — +/- buttons with numeric value
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label    : string,
    min      : number,   default 0
    max      : number,   default 100
    default  : number,   default min
    step     : number,   default 1
    onChange : function(value: number) | nil,
}
--]]
function Element.stepper(cfg)
	cfg = cfg or {}
	local icon    = _Icon.new()
	local minV    = cfg.min     or 0
	local maxV    = cfg.max     or 100
	local stepV   = cfg.step    or 1
	local current = math.clamp(cfg.default or minV, minV, maxV)

	if cfg.label then icon:setLabel(cfg.label) end
	makeInert(icon)

	local PILL_W = 80

	withWidget(icon, function(widget)
		local container = Instance.new("Frame")
		container.Name             = "StepperContainer"
		container.Size             = UDim2.new(0, PILL_W, 0, 24)
		container.AnchorPoint      = Vector2.new(1, 0.5)
		container.Position         = UDim2.new(1, -10, 0.5, 0)
		container.BackgroundColor3 = SURFACE
		container.BorderSizePixel  = 0
		container.ZIndex           = 25
		addCorner(container, UDim.new(0, 8))
		addStroke(container, DIVIDER, 1, 0)

		local minus = Instance.new("TextButton")
		minus.Name                  = "Minus"
		minus.Size                  = UDim2.new(0, 24, 1, 0)
		minus.Position              = UDim2.new(0, 0, 0, 0)
		minus.BackgroundTransparency = 1
		minus.Text                  = "−"
		minus.TextColor3            = WHITE
		minus.TextSize              = 16
		minus.Font                  = Enum.Font.GothamBold
		minus.ZIndex                = 26
		minus.Parent                = container

		local numLbl = Instance.new("TextLabel")
		numLbl.Name                  = "StepValue"
		numLbl.Size                  = UDim2.new(1, -48, 1, 0)
		numLbl.Position              = UDim2.new(0, 24, 0, 0)
		numLbl.BackgroundTransparency = 1
		numLbl.Text                  = tostring(current)
		numLbl.TextColor3            = WHITE
		numLbl.TextSize              = 13
		numLbl.Font                  = Enum.Font.GothamBold
		numLbl.ZIndex                = 26
		numLbl.Parent                = container

		local plus = Instance.new("TextButton")
		plus.Name                  = "Plus"
		plus.Size                  = UDim2.new(0, 24, 1, 0)
		plus.Position              = UDim2.new(1, -24, 0, 0)
		plus.BackgroundTransparency = 1
		plus.Text                  = "+"
		plus.TextColor3            = WHITE
		plus.TextSize              = 16
		plus.Font                  = Enum.Font.GothamBold
		plus.ZIndex                = 26
		plus.Parent                = container

		local function updateDisplay()
			numLbl.Text = tostring(current)
			minus.TextColor3 = current <= minV and MUTED or WHITE
			plus.TextColor3  = current >= maxV and MUTED or WHITE
		end
		updateDisplay()

		minus.MouseButton1Click:Connect(function()
			current = math.clamp(current - stepV, minV, maxV)
			updateDisplay()
			if cfg.onChange then cfg.onChange(current) end
		end)
		plus.MouseButton1Click:Connect(function()
			current = math.clamp(current + stepV, minV, maxV)
			updateDisplay()
			if cfg.onChange then cfg.onChange(current) end
		end)

		container.Parent = widget
	end)

	icon.setValue = function(_, v)
		current = math.clamp(v, minV, maxV)
	end

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. KEYBIND  — click to capture a key
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label     : string,
    default   : Enum.KeyCode | nil,
    onChange  : function(keyCode: Enum.KeyCode) | nil,
    blacklist : { Enum.KeyCode } | nil,   -- keys to ignore
}
--]]
function Element.keybind(cfg)
	cfg = cfg or {}
	local icon     = _Icon.new()
	local bound    = cfg.default
	local listening = false

	if cfg.label then icon:setLabel(cfg.label) end
	makeInert(icon)

	local blacklist = {}
	for _, k in ipairs(cfg.blacklist or {}) do blacklist[k] = true end
	-- Always blacklist Escape (cancel listening)
	blacklist[Enum.KeyCode.Escape] = true

	withWidget(icon, function(widget)
		local pill = Instance.new("TextButton")
		pill.Name             = "KeybindPill"
		pill.Size             = UDim2.new(0, 72, 0, 24)
		pill.AnchorPoint      = Vector2.new(1, 0.5)
		pill.Position         = UDim2.new(1, -10, 0.5, 0)
		pill.BackgroundColor3 = SURFACE
		pill.BorderSizePixel  = 0
		pill.TextColor3       = WHITE
		pill.TextSize         = 12
		pill.Font             = Enum.Font.GothamMedium
		pill.ZIndex           = 26
		addCorner(pill, UDim.new(0, 6))
		local stroke = addStroke(pill, DIVIDER, 1, 0)

		local function refreshPill()
			if listening then
				pill.Text             = "..."
				pill.BackgroundColor3 = Color3.fromRGB(40, 20, 70)
				stroke.Color          = ACCENT
				tween(stroke, EASING, { Transparency = 0 })
			elseif bound then
				pill.Text             = tostring(bound.Name)
				pill.BackgroundColor3 = SURFACE
				stroke.Color          = DIVIDER
			else
				pill.Text             = "None"
				pill.BackgroundColor3 = SURFACE
				stroke.Color          = DIVIDER
			end
		end
		refreshPill()

		local conn
		pill.MouseButton1Click:Connect(function()
			listening = not listening
			if listening then
				-- Cancel any previous connection
				if conn then conn:Disconnect() end
				conn = UserInputService.InputBegan:Connect(function(input, processed)
					if not listening then return end
					if processed then return end
					if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
					listening = false
					if input.KeyCode == Enum.KeyCode.Escape then
						refreshPill()
						return
					end
					if blacklist[input.KeyCode] then return end
					bound = input.KeyCode
					if cfg.onChange then cfg.onChange(bound) end
					conn:Disconnect()
					refreshPill()
				end)
			end
			refreshPill()
		end)

		pill.Parent = widget
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. COLOR SWATCH  — shows a color, click to copy hex / fire callback
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label    : string,
    value    : Color3,
    onChange : function(color: Color3) | nil,   -- called when swatch is clicked
                                                 -- (opens a simple hue/sat picker)
    showHex  : boolean | nil,   -- show hex label (default true)
}
--]]
function Element.color(cfg)
	cfg = cfg or {}
	local icon    = _Icon.new()
	local current = cfg.value or Color3.fromRGB(108, 62, 244)
	local showHex = cfg.showHex ~= false

	if cfg.label then icon:setLabel(cfg.label) end
	icon:autoDeselect(false)
	icon:disableOverlay(true)

	withWidget(icon, function(widget)
		local swatch = Instance.new("TextButton")
		swatch.Name             = "ColorSwatch"
		swatch.Size             = UDim2.new(0, 36, 0, 22)
		swatch.AnchorPoint      = Vector2.new(1, 0.5)
		swatch.Position         = UDim2.new(1, -10, 0.5, 0)
		swatch.BackgroundColor3 = current
		swatch.BorderSizePixel  = 0
		swatch.Text             = ""
		swatch.ZIndex           = 26
		addCorner(swatch, UDim.new(0, 6))
		addStroke(swatch, WHITE, 1.5, 0.5)

		local hexLbl
		if showHex then
			hexLbl = Instance.new("TextLabel")
			hexLbl.Size                  = UDim2.new(0, 52, 0, 18)
			hexLbl.AnchorPoint           = Vector2.new(1, 0.5)
			hexLbl.Position              = UDim2.new(1, -54, 0.5, 0)
			hexLbl.BackgroundTransparency = 1
			hexLbl.TextColor3            = MUTED
			hexLbl.TextSize              = 10
			hexLbl.Font                  = Enum.Font.RobotoMono
			hexLbl.ZIndex                = 25
			hexLbl.TextXAlignment        = Enum.TextXAlignment.Right

			local function toHex(c)
				return string.format("#%02X%02X%02X",
					math.round(c.R * 255),
					math.round(c.G * 255),
					math.round(c.B * 255))
			end
			hexLbl.Text   = toHex(current)
			hexLbl.Parent = widget

			icon.setValue = function(_, c)
				current               = c
				swatch.BackgroundColor3 = c
				hexLbl.Text           = toHex(c)
				if cfg.onChange then cfg.onChange(c) end
			end
		end

		swatch.MouseButton1Click:Connect(function()
			if cfg.onChange then cfg.onChange(current) end
		end)

		swatch.Parent = widget
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. PROGRESS BAR  — read-only progress indicator
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label    : string,
    value    : number,   -- 0–1 fraction, or use min/max
    min      : number | nil,
    max      : number | nil,
    color    : Color3 | nil,
    showPct  : boolean | nil,   -- show percentage label (default true)
    animate  : boolean | nil,   -- animate value changes (default true)
    binding  : { changed signal } | nil,
}
--]]
function Element.progress(cfg)
	cfg = cfg or {}
	local icon    = _Icon.new()
	local minV    = cfg.min or 0
	local maxV    = cfg.max or 1
	local barColor = cfg.color or SUCCESS
	local showPct = cfg.showPct ~= false
	local animate = cfg.animate ~= false

	local function normalize(v)
		return math.clamp((v - minV) / math.max(maxV - minV, 0.0001), 0, 1)
	end

	local initPct = normalize(cfg.value or 0)

	if cfg.label then icon:setLabel(cfg.label) end
	makeInert(icon)
	icon:modifyTheme({ { "Widget", "MinimumHeight", 60 } })

	withWidget(icon, function(widget)
		local track = Instance.new("Frame")
		track.Name             = "ProgressTrack"
		track.Size             = UDim2.new(1, -32, 0, 6)
		track.AnchorPoint      = Vector2.new(0.5, 1)
		track.Position         = UDim2.new(0.5, 0, 1, -12)
		track.BackgroundColor3 = DIVIDER
		track.BorderSizePixel  = 0
		addCorner(track)

		local fill = Instance.new("Frame")
		fill.Name             = "ProgressFill"
		fill.Size             = UDim2.new(initPct, 0, 1, 0)
		fill.BackgroundColor3 = barColor
		fill.BorderSizePixel  = 0
		addCorner(fill)
		fill.Parent = track
		track.Parent = widget

		local pctLbl
		if showPct then
			pctLbl = Instance.new("TextLabel")
			pctLbl.Size                  = UDim2.new(0, 36, 0, 16)
			pctLbl.AnchorPoint           = Vector2.new(1, 0)
			pctLbl.Position              = UDim2.new(1, -4, 0, 8)
			pctLbl.BackgroundTransparency = 1
			pctLbl.Text                  = math.round(initPct * 100) .. "%"
			pctLbl.TextColor3            = MUTED
			pctLbl.TextSize              = 11
			pctLbl.Font                  = Enum.Font.GothamMedium
			pctLbl.TextXAlignment        = Enum.TextXAlignment.Right
			pctLbl.ZIndex                = 25
			pctLbl.Parent                = widget
		end

		local function update(v, instant)
			local pct  = normalize(v)
			local info = (instant or not animate) and TweenInfo.new(0) or
				TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			tween(fill, info, { Size = UDim2.new(pct, 0, 1, 0) })
			if pctLbl then pctLbl.Text = math.round(pct * 100) .. "%" end
		end

		icon.setValue = function(_, v) update(v, false) end

		-- Reactive binding
		local source = cfg.binding or cfg.value
		if typeof(source) == "Instance" and source:IsA("ValueBase") then
			source.Changed:Connect(function(v) update(v, false) end)
		elseif type(source) == "table" then
			local sig = rawget(source, "changed") or rawget(source, "Changed")
			if sig and type(sig.Connect) == "function" then
				sig:Connect(function(v) update(v, false) end)
			end
		end
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. RADIO GROUP  — mutually exclusive option list
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    options  : { string },     -- option labels
    default  : number | nil,   -- index of initially selected option (1-based)
    color    : Color3 | nil,
    onChange : function(index: number, label: string) | nil,
}

Returns an ARRAY of Icon instances (one per option), ready to pass to setDropdown/setMenu.
--]]
function Element.radio(cfg)
	cfg = cfg or {}
	local options  = cfg.options or {}
	local selected = cfg.default or 1
	local radioColor = cfg.color or ACCENT
	local icons = {}

	for i, optLabel in ipairs(options) do
		local icon = _Icon.new()
		icon:autoDeselect(false)
		icon:disableOverlay(true)
		icon:setLabel(optLabel)

		local dot
		withWidget(icon, function(widget)
			local ring = Instance.new("Frame")
			ring.Name             = "RadioRing"
			ring.Size             = UDim2.fromOffset(18, 18)
			ring.AnchorPoint      = Vector2.new(1, 0.5)
			ring.Position         = UDim2.new(1, -12, 0.5, 0)
			ring.BackgroundColor3 = SURFACE
			ring.BorderSizePixel  = 0
			ring.ZIndex           = 25
			addCorner(ring)
			addStroke(ring, i == selected and radioColor or DIVIDER, 2, 0)

			dot = Instance.new("Frame")
			dot.Name             = "RadioDot"
			dot.Size             = UDim2.fromOffset(8, 8)
			dot.AnchorPoint      = Vector2.new(0.5, 0.5)
			dot.Position         = UDim2.fromScale(0.5, 0.5)
			dot.BackgroundColor3 = radioColor
			dot.BorderSizePixel  = 0
			dot.BackgroundTransparency = i == selected and 0 or 1
			dot.ZIndex           = 26
			addCorner(dot)
			dot.Parent = ring

			icon._radioDot  = dot
			icon._radioRing = ring

			ring.Parent = widget
		end)

		local capturedI = i
		icon:onSelect(function()
			-- Deselect all others
			for j, other in ipairs(icons) do
				if j ~= capturedI then
					other:deselect()
					if other._radioDot and other._radioRing then
						tween(other._radioDot,  EASING, { BackgroundTransparency = 1 })
						tween(other._radioRing, EASING, { }) -- stroke handled below
						if other._radioRingStroke then
							tween(other._radioRingStroke, EASING, { Color = DIVIDER })
						end
					end
				end
			end
			selected = capturedI
			if icon._radioDot then
				tween(icon._radioDot, EASING, { BackgroundTransparency = 0 })
			end
			icon:deselect()  -- radio items don't stay "selected" visually via TopbarPlus
			if cfg.onChange then cfg.onChange(selected, optLabel) end
		end)

		table.insert(icons, icon)
	end

	return icons
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. MULTISELECT  — checkbox list
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    options  : { string },
    default  : { boolean } | nil,  -- per-option initial checked state
    color    : Color3 | nil,
    onChange : function(states: { boolean }) | nil,
}

Returns an array of Icon instances.
--]]
function Element.multiselect(cfg)
	cfg = cfg or {}
	local options = cfg.options or {}
	local states  = {}
	for i = 1, #options do states[i] = cfg.default and cfg.default[i] == true or false end
	local checkColor = cfg.color or ACCENT
	local icons = {}

	for i, optLabel in ipairs(options) do
		local icon = _Icon.new()
		icon:autoDeselect(false)
		icon:disableOverlay(true)
		icon:setLabel(optLabel)

		withWidget(icon, function(widget)
			local box = Instance.new("Frame")
			box.Name             = "Checkbox"
			box.Size             = UDim2.fromOffset(18, 18)
			box.AnchorPoint      = Vector2.new(1, 0.5)
			box.Position         = UDim2.new(1, -12, 0.5, 0)
			box.BackgroundColor3 = states[i] and checkColor or SURFACE
			box.BorderSizePixel  = 0
			box.ZIndex           = 25
			addCorner(box, UDim.new(0, 4))
			local stroke = addStroke(box, states[i] and checkColor or DIVIDER, 1.5, 0)

			local check = Instance.new("TextLabel")
			check.Size                  = UDim2.fromScale(1, 1)
			check.BackgroundTransparency = 1
			check.Text                  = "✓"
			check.TextColor3            = WHITE
			check.TextSize              = 13
			check.Font                  = Enum.Font.GothamBold
			check.BackgroundTransparency = 1
			check.TextTransparency      = states[i] and 0 or 1
			check.ZIndex                = 26
			check.Parent                = box

			icon._checkbox     = box
			icon._checkmark    = check
			icon._checkStroke  = stroke

			box.Parent = widget
		end)

		local capturedI = i
		icon:onSelect(function()
			states[capturedI] = not states[capturedI]
			local on = states[capturedI]
			tween(icon._checkbox, EASING, { BackgroundColor3 = on and checkColor or SURFACE })
			tween(icon._checkmark, EASING, { TextTransparency = on and 0 or 1 })
			icon:deselect()
			if cfg.onChange then cfg.onChange(states) end
		end)

		table.insert(icons, icon)
	end

	return icons
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. TEXTAREA  — multi-line text input
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label       : string | nil,
    placeholder : string | nil,
    default     : string | nil,
    rows        : number | nil,   -- visual height in lines, default 3
    onSubmit    : function(text) | nil,
    onChange    : function(text) | nil,
}
--]]
function Element.textarea(cfg)
	cfg = cfg or {}
	local rows   = cfg.rows or 3
	local height = 16 + rows * 20 + 20  -- label row + rows + padding

	local icon = _Icon.new()
	makeInert(icon)
	if cfg.label then icon:setLabel(cfg.label) end
	icon:modifyTheme({ { "Widget", "MinimumHeight", height } })

	withWidget(icon, function(widget)
		local box = Instance.new("TextBox")
		box.Name                  = "TextArea"
		box.Size                  = UDim2.new(1, -20, 0, rows * 20)
		box.AnchorPoint           = Vector2.new(0.5, 1)
		box.Position              = UDim2.new(0.5, 0, 1, -8)
		box.BackgroundColor3      = SURFACE
		box.BackgroundTransparency = 0
		box.BorderSizePixel       = 0
		box.TextColor3            = WHITE
		box.PlaceholderText       = cfg.placeholder or ""
		box.PlaceholderColor3     = MUTED
		box.Text                  = cfg.default or ""
		box.TextSize              = 13
		box.Font                  = Enum.Font.Gotham
		box.MultiLine             = true
		box.TextWrapped           = true
		box.TextXAlignment        = Enum.TextXAlignment.Left
		box.TextYAlignment        = Enum.TextYAlignment.Top
		box.ClearTextOnFocus      = false
		box.ZIndex                = 30
		addCorner(box, UDim.new(0, 6))

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft   = UDim.new(0, 8)
		pad.PaddingRight  = UDim.new(0, 8)
		pad.PaddingTop    = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent        = box

		local stroke = addStroke(box, ACCENT, 1.5, 1)
		box.Focused:Connect(function()  tween(stroke, EASING, { Transparency = 0 }) end)
		box.FocusLost:Connect(function(enter)
			tween(stroke, EASING, { Transparency = 1 })
			if enter and cfg.onSubmit then cfg.onSubmit(box.Text) end
		end)
		if cfg.onChange then
			box:GetPropertyChangedSignal("Text"):Connect(function() cfg.onChange(box.Text) end)
		end

		box.Parent = widget
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. LABELED SEPARATOR  — divider with a visible centered text label
-- ─────────────────────────────────────────────────────────────────────────────
-- Alias kept for clarity — same as Element.divider({ label = text })
function Element.separator(text)
	return Element.divider({ label = text, color = DIVIDER })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. CONFIRM ROW  — inline confirm / cancel buttons
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label      : string | nil,
    confirmText : string | nil,   default "Confirm"
    cancelText  : string | nil,   default "Cancel"
    confirmColor : Color3 | nil,  default DANGER (destructive action)
    onConfirm  : function() | nil,
    onCancel   : function() | nil,
}
--]]
function Element.confirm(cfg)
	cfg = cfg or {}
	local icon = _Icon.new()
	makeInert(icon)
	if cfg.label then icon:setLabel(cfg.label) end

	withWidget(icon, function(widget)
		local confirmBtn = Instance.new("TextButton")
		confirmBtn.Name             = "ConfirmBtn"
		confirmBtn.Size             = UDim2.new(0, 72, 0, 24)
		confirmBtn.AnchorPoint      = Vector2.new(1, 0.5)
		confirmBtn.Position         = UDim2.new(1, -10, 0.5, 0)
		confirmBtn.BackgroundColor3 = cfg.confirmColor or DANGER
		confirmBtn.BorderSizePixel  = 0
		confirmBtn.Text             = cfg.confirmText or "Confirm"
		confirmBtn.TextColor3       = WHITE
		confirmBtn.TextSize         = 12
		confirmBtn.Font             = Enum.Font.GothamBold
		confirmBtn.ZIndex           = 26
		addCorner(confirmBtn, UDim.new(0, 6))

		local cancelBtn = Instance.new("TextButton")
		cancelBtn.Name             = "CancelBtn"
		cancelBtn.Size             = UDim2.new(0, 60, 0, 24)
		cancelBtn.AnchorPoint      = Vector2.new(1, 0.5)
		cancelBtn.Position         = UDim2.new(1, -90, 0.5, 0)
		cancelBtn.BackgroundColor3 = SURFACE
		cancelBtn.BorderSizePixel  = 0
		cancelBtn.Text             = cfg.cancelText or "Cancel"
		cancelBtn.TextColor3       = MUTED
		cancelBtn.TextSize         = 12
		cancelBtn.Font             = Enum.Font.Gotham
		cancelBtn.ZIndex           = 26
		addCorner(cancelBtn, UDim.new(0, 6))
		addStroke(cancelBtn, DIVIDER, 1, 0)

		confirmBtn.MouseButton1Click:Connect(function()
			tween(confirmBtn, EASING, { BackgroundColor3 = WHITE })
			task.delay(0.15, function()
				tween(confirmBtn, EASING, { BackgroundColor3 = cfg.confirmColor or DANGER })
			end)
			if cfg.onConfirm then cfg.onConfirm() end
		end)
		cancelBtn.MouseButton1Click:Connect(function()
			if cfg.onCancel then cfg.onCancel() end
		end)

		confirmBtn.Parent = widget
		cancelBtn.Parent  = widget
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 17. LINK ROW  — label + external-link styled button
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label   : string,
    url     : string | nil,   -- shown truncated on the right
    onClick : function() | nil,
}
--]]
function Element.link(cfg)
	cfg = cfg or {}
	local icon = _Icon.new()
	icon:autoDeselect(false)
	icon:disableOverlay(true)
	if cfg.label then icon:setLabel(cfg.label) end

	withWidget(icon, function(widget)
		local urlLbl = Instance.new("TextLabel")
		urlLbl.Name                  = "LinkUrl"
		urlLbl.Size                  = UDim2.new(0, 90, 0.6, 0)
		urlLbl.AnchorPoint           = Vector2.new(1, 0.5)
		urlLbl.Position              = UDim2.new(1, -10, 0.5, 0)
		urlLbl.BackgroundTransparency = 1
		urlLbl.Text                  = cfg.url and ("↗ " .. cfg.url) or "↗"
		urlLbl.TextColor3            = ACCENT2
		urlLbl.TextSize              = 12
		urlLbl.Font                  = Enum.Font.Gotham
		urlLbl.TextXAlignment        = Enum.TextXAlignment.Right
		urlLbl.TextTruncate          = Enum.TextTruncate.AtEnd
		urlLbl.ZIndex                = 26
		urlLbl.Parent                = widget

		-- Make the whole row clickable
		local hitbox = Instance.new("TextButton")
		hitbox.Size                  = UDim2.fromScale(1, 1)
		hitbox.BackgroundTransparency = 1
		hitbox.Text                  = ""
		hitbox.ZIndex                = 30
		hitbox.Parent                = widget

		hitbox.MouseButton1Click:Connect(function()
			tween(urlLbl, EASING, { TextColor3 = WHITE })
			task.delay(0.2, function() tween(urlLbl, EASING, { TextColor3 = ACCENT2 }) end)
			if cfg.onClick then cfg.onClick() end
		end)
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 18. RATING  — star rating row
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    label    : string,
    max      : number | nil,    default 5
    default  : number | nil,    default 0
    color    : Color3 | nil,    default WARN (gold)
    readOnly : boolean | nil,
    onChange : function(rating: number) | nil,
}
--]]
function Element.rating(cfg)
	cfg = cfg or {}
	local icon    = _Icon.new()
	local maxStar = cfg.max or 5
	local current = cfg.default or 0
	local starColor = cfg.color or WARN

	if cfg.label then icon:setLabel(cfg.label) end
	if cfg.readOnly then makeInert(icon) else icon:autoDeselect(false) end

	withWidget(icon, function(widget)
		local STAR_SIZE = 18
		local STAR_GAP  = 2
		local totalW    = maxStar * STAR_SIZE + (maxStar - 1) * STAR_GAP
		local stars = {}

		for s = 1, maxStar do
			local btn = Instance.new(cfg.readOnly and "TextLabel" or "TextButton")
			btn.Name                  = "Star" .. s
			btn.Size                  = UDim2.fromOffset(STAR_SIZE, STAR_SIZE)
			btn.AnchorPoint           = Vector2.new(1, 0.5)
			btn.Position              = UDim2.new(1, -(totalW - (s-1)*(STAR_SIZE+STAR_GAP)) + STAR_SIZE - 10, 0.5, 0)
			btn.BackgroundTransparency = 1
			btn.Text                  = "★"
			btn.TextSize              = STAR_SIZE - 2
			btn.Font                  = Enum.Font.GothamBold
			btn.TextColor3            = s <= current and starColor or DIVIDER
			btn.ZIndex                = 26
			btn.Parent                = widget
			stars[s] = btn
		end

		local function refresh(val)
			for s, star in ipairs(stars) do
				tween(star, EASING, { TextColor3 = s <= val and starColor or DIVIDER })
			end
		end

		if not cfg.readOnly then
			for s, btn in ipairs(stars) do
				btn.MouseEnter:Connect(function() refresh(s) end)
				btn.MouseLeave:Connect(function() refresh(current) end)
				btn.MouseButton1Click:Connect(function()
					current = s
					refresh(current)
					icon:deselect()
					if cfg.onChange then cfg.onChange(current) end
				end)
			end
		end

		icon.setValue = function(_, v)
			current = math.clamp(v, 0, maxStar)
			refresh(current)
		end
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 19. SEARCH  — input that filters sibling items live
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    placeholder : string | nil,
    targets     : { Icon } | nil,   -- icons whose labels to filter
                                     -- if nil, you wire it manually via .filter(text)
    onSearch    : function(text: string) | nil,
}
--]]
function Element.search(cfg)
	cfg = cfg or {}
	local icon = _Icon.new()
	makeInert(icon)
	icon:modifyTheme({ { "Widget", "MinimumHeight", 52 } })

	withWidget(icon, function(widget)
		-- Search icon glyph
		local glyph = Instance.new("TextLabel")
		glyph.Size                  = UDim2.fromOffset(16, 16)
		glyph.AnchorPoint           = Vector2.new(0, 0.5)
		glyph.Position              = UDim2.new(0, 12, 0.5, 0)
		glyph.BackgroundTransparency = 1
		glyph.Text                  = "🔍"
		glyph.TextSize              = 14
		glyph.ZIndex                = 31
		glyph.Parent                = widget

		local box = Instance.new("TextBox")
		box.Name                  = "SearchBox"
		box.Size                  = UDim2.new(1, -36, 0, 28)
		box.AnchorPoint           = Vector2.new(0.5, 0.5)
		box.Position              = UDim2.new(0.5, 10, 0.5, 0)
		box.BackgroundColor3      = SURFACE
		box.BackgroundTransparency = 0
		box.BorderSizePixel       = 0
		box.TextColor3            = WHITE
		box.PlaceholderText       = cfg.placeholder or "Search..."
		box.PlaceholderColor3     = MUTED
		box.Text                  = ""
		box.TextSize              = 13
		box.Font                  = Enum.Font.Gotham
		box.ClearTextOnFocus      = false
		box.ZIndex                = 30
		addCorner(box, UDim.new(0, 6))

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft  = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent       = box

		local stroke = addStroke(box, ACCENT, 1.5, 1)
		box.Focused:Connect(function()  tween(stroke, EASING, { Transparency = 0 }) end)
		box.FocusLost:Connect(function() tween(stroke, EASING, { Transparency = 1 }) end)

		box:GetPropertyChangedSignal("Text"):Connect(function()
			local query = string.lower(box.Text)
			if cfg.targets then
				for _, target in ipairs(cfg.targets) do
					local lbl = target.getInstance and target:getInstance("IconLabel")
					if lbl then
						local visible = query == "" or string.find(string.lower(lbl.Text), query, 1, true) ~= nil
						target:setEnabled(visible)
					end
				end
			end
			if cfg.onSearch then cfg.onSearch(box.Text) end
		end)

		-- Expose a programmatic filter
		icon.filter = function(_, text) box.Text = text end

		box.Parent = widget
	end)

	return icon
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 20. ANNOUNCEMENT  — info/warn/error banner row
-- ─────────────────────────────────────────────────────────────────────────────
--[[
cfg = {
    text    : string,
    type    : "info" | "warn" | "error" | "success" | nil,  default "info"
    dismiss : boolean | nil,   -- show × button to hide row
}
--]]
function Element.announcement(cfg)
	cfg = cfg or {}
	local icon = _Icon.new()
	makeInert(icon)

	local palette = {
		info    = { bg = Color3.fromRGB(20, 50, 90),   accent = ACCENT2,  label = "ℹ" },
		warn    = { bg = Color3.fromRGB(70, 45, 10),   accent = WARN,     label = "⚠" },
		error   = { bg = Color3.fromRGB(70, 15, 15),   accent = DANGER,   label = "✕" },
		success = { bg = Color3.fromRGB(10, 55, 30),   accent = SUCCESS,  label = "✓" },
	}
	local style = palette[cfg.type or "info"] or palette.info
	local accent = cfg.accent
	warn(cfg.accent)

	icon:modifyTheme({
		{ "Widget",     "MinimumHeight",          44 },
		{ "IconButton", "BackgroundColor3",        style.bg },
		{ "IconButton", "BackgroundTransparency",  0 },
	})

	withWidget(icon, function(widget)
		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size                  = UDim2.fromOffset(18, 18)
		iconLbl.AnchorPoint           = Vector2.new(0, 0.5)
		iconLbl.Position              = UDim2.new(0, 10, 0.5, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text                  = style.label
		iconLbl.TextColor3            = style.accent
		iconLbl.TextSize              = 14
		iconLbl.Font                  = Enum.Font.GothamBold
		iconLbl.ZIndex                = 26
		iconLbl.Parent                = widget

		local msgLbl = Instance.new("TextLabel")
		msgLbl.Size                  = UDim2.new(1, cfg.dismiss and -60 or -40, 1, 0)
		msgLbl.Position              = UDim2.new(0, 34, 0, 0)
		msgLbl.BackgroundTransparency = 1
		msgLbl.Text                  = cfg.text or ""
		msgLbl.TextColor3            = WHITE
		msgLbl.TextSize              = 12
		msgLbl.Font                  = Enum.Font.Gotham
		msgLbl.TextXAlignment        = Enum.TextXAlignment.Left
		msgLbl.TextWrapped           = true
		msgLbl.ZIndex                = 26
		msgLbl.Parent                = widget

		if cfg.dismiss then
			local x = Instance.new("TextButton")
			x.Size                  = UDim2.fromOffset(20, 20)
			x.AnchorPoint           = Vector2.new(1, 0.5)
			x.Position              = UDim2.new(1, -8, 0.5, 0)
			x.BackgroundTransparency = 1
			x.Text                  = "×"
			x.TextColor3            = MUTED
			x.TextSize              = 18
			x.Font                  = Enum.Font.GothamBold
			x.ZIndex                = 30
			x.Parent                = widget
			x.MouseButton1Click:Connect(function()
				icon:setEnabled(false)
			end)
		end

		if accent then
			local bar = Instance.new("Frame")
			bar.Size             = UDim2.new(0, 3, 1, 0)
			bar.Position         = UDim2.new(0, 0, 0, 0)
			bar.BackgroundColor3 = style.accent
			bar.BorderSizePixel  = 0
			bar.ZIndex           = 27
			bar.Parent           = widget
		end
		
		
	end)

	return icon
end

return Element