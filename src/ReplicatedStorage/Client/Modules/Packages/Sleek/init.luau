local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer  = Players.LocalPlayer

local Features   = script.Features
local Extensions = script.Extensions
local Elements   = script.Elements
local Packages   = script.Packages

local GoodSignal = require(Packages.GoodSignal)
local Janitor    = require(Packages.Janitor)
local Themes     = require(Features.Themes)
local Types      = require(Features.Types)
local Utility    = require(script.Utility)
local Icons      = require(script.Utility.Icons)

local attributeKeys = Utility.attributeKeys
local uiLayoutTypes = Utility.uiLayoutTypes

local DEFAULT_LAYERS = Themes._loaded["Default"].ZIndex

local function getOrCreateScreenGui(): ScreenGui
	local gui      = LocalPlayer:WaitForChild("PlayerGui")
	local existing = gui:FindFirstChild("^SleekStandard")
	if existing then return existing :: ScreenGui end

	local container          = Instance.new("ScreenGui")
	container.Name           = "^SleekStandard"
	container.IgnoreGuiInset = true
	container.ResetOnSpawn   = false
	container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	container.DisplayOrder   = 10
	container.Parent         = gui
	return container
end

local function Err(msg: string)
	error("[Sleek] " .. msg, 3)
end

local State = {}
State.__index = State

function State.new(initial: any)
	local self   = setmetatable({}, State)
	self._value  = initial
	self._signal = GoodSignal.new()
	self._dead   = false
	return self
end

function State:get(): any
	return self._value
end

function State:set(value: any)
	if self._dead then return end
	local prev  = self._value
	self._value = value
	if prev ~= value then self._signal:Fire(value, prev) end
end

function State:update(fn: (any) -> any)
	self:set(fn(self._value))
end

function State:onChange(fn: (new: any, old: any) -> ()): RBXScriptConnection
	return self._signal:Connect(fn)
end

function State:subscribe(fn: (new: any, old: any) -> ()): RBXScriptConnection
	fn(self._value, self._value)
	return self._signal:Connect(fn)
end

function State:destroy()
	self._dead = true
	self._signal:DisconnectAll()
end

local Computed = {}
Computed.__index = Computed

function Computed.new(deps: { any }, fn: (...any) -> any, janitor: any)
	local self   = setmetatable({}, Computed)
	self._signal = GoodSignal.new()
	self._dead   = false

	local function evaluate()
		local args = {}
		for _, dep in deps do table.insert(args, dep:get()) end
		return fn(table.unpack(args))
	end

	self._value = evaluate()

	for _, dep in deps do
		local conn = dep:onChange(function()
			if self._dead then return end
			local prev = self._value
			local next = evaluate()
			self._value = next
			if prev ~= next then self._signal:Fire(next, prev) end
		end)
		if janitor then janitor:Add(conn, "Disconnect") end
	end

	return self
end

function Computed:get(): any
	return self._value
end

function Computed:onChange(fn: (new: any, old: any) -> ()): RBXScriptConnection
	return self._signal:Connect(fn)
end

function Computed:subscribe(fn: (new: any, old: any) -> ()): RBXScriptConnection
	fn(self._value, self._value)
	return self._signal:Connect(fn)
end

function Computed:destroy()
	self._dead = true
	self._signal:DisconnectAll()
end

local function resolveVariant(variant: string, theme: Types.Theme): (Color3?, Color3?, number, Color3?)
	local C = theme.Colors
	local V = theme.Variants

	if V and V[variant] then
		local v = V[variant]
		return v.Background, v.Text, v.Transparency or 0, v.Color
	end

	if variant == "Primary" then
		return V and V.Primary and V.Primary.Background or C.Brand.BrandBlue, C.Brand.BrandWhite, 0
	elseif variant == "Secondary" then
		return V and V.Secondary and V.Secondary.Background or C.Surface.Overlay, C.Text.Primary, 0
	elseif variant == "Danger" then
		return V and V.Danger and V.Danger.Background or C.Brand.BrandRed, C.Brand.BrandWhite, 0
	elseif variant == "Ghost" then
		return nil, C.Text.Primary, 1
	elseif variant == "Outline" then
		return nil, C.Text.Primary, 1
	end

	return C.Brand.BrandBlue, C.Brand.BrandWhite, 0
end

local function applyStructuralDefaults(
	instance     : GuiObject,
	instanceType : string,
	properties   : { [any]: any },
	theme        : Types.Theme
)
	local R = theme.Roundness
	local T = theme.Text
	local S = theme.Sizes
	local C = theme.Colors

	local userSet = {}
	for k in properties do userSet[k] = true end

	local function def(prop, value)
		if userSet[prop] then return end
		pcall(function() instance[prop] = value end)
	end

	local function addCorner(radius: UDim)
		if instance:FindFirstChildOfClass("UICorner") then return end
		local c        = Instance.new("UICorner")
		c.CornerRadius = radius
		c.Parent       = instance
	end

	local function addStroke(color: Color3, thickness: number)
		if instance:FindFirstChildOfClass("UIStroke") then return end
		local s           = Instance.new("UIStroke")
		s.Color           = color
		s.Thickness       = thickness
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent          = instance
	end

	local function addPadding(h: UDim, v: UDim?)
		if instance:FindFirstChildOfClass("UIPadding") then return end
		local p         = Instance.new("UIPadding")
		p.PaddingLeft   = h
		p.PaddingRight  = h
		p.PaddingTop    = v or h
		p.PaddingBottom = v or h
		p.Parent        = instance
	end

	if instanceType == "TextButton" then
		def("Size",            UDim2.new(1, 0, 0, S.ButtonHeight))
		def("BorderSizePixel", 0)
		def("Text",            "Button")
		def("TextSize",        T.SizeMD)
		def("FontFace",        T.FontBold)
		def("TextXAlignment",  Enum.TextXAlignment.Center)

		local variant                 = instance:GetAttribute("Variant") or "Primary"
		local bg, fg, transp, outline = resolveVariant(variant, theme)

		def("BackgroundColor3",       bg)
		def("BackgroundTransparency", transp)
		if fg      then def("TextColor3", fg) end
		if outline then addStroke(outline, 1.5) end
		addCorner(R.ButtonRoundness)

	elseif instanceType == "TextLabel" then
		def("Size",                   UDim2.new(1, 0, 0, S.LabelHeight))
		def("BackgroundTransparency", 1)
		def("BorderSizePixel",        0)
		def("TextSize",               T.SizeMD)
		def("FontFace",               T.Font)
		def("TextXAlignment",         Enum.TextXAlignment.Left)
		def("TextWrapped",            true)
		def("TextColor3",             C.Text.Primary)

	elseif instanceType == "TextBox" then
		def("Size",              UDim2.new(1, 0, 0, S.InputHeight))
		def("BorderSizePixel",   0)
		def("TextSize",          T.SizeMD)
		def("FontFace",          T.Font)
		def("TextXAlignment",    Enum.TextXAlignment.Left)
		def("ClearTextOnFocus",  false)
		def("BackgroundColor3",  C.Surface.Raised)
		def("TextColor3",        C.Text.Primary)
		def("PlaceholderColor3", C.Text.Disabled)
		addCorner(R.InputRoundness)
		addPadding(UDim.new(0, 10))
		addStroke(C.Surface.Border, 1.5)

	elseif instanceType == "Frame" or instanceType == "CanvasGroup" or instanceType == "ViewportFrame" then
		def("BorderSizePixel", 0)
		local e = instance:GetAttribute("Elevation") or 0
		if     e >= 2 then def("BackgroundColor3", C.Surface.Overlay)
		elseif e == 1 then def("BackgroundColor3", C.Surface.Raised)
		else               def("BackgroundColor3", C.Surface.Base)
		end
		local rKey = instance:GetAttribute("Roundness") or "CornerRoundness"
		addCorner(R[rKey] or R.CornerRoundness)

	elseif instanceType == "ScrollingFrame" then
		def("BorderSizePixel",      0)
		def("ScrollBarThickness",   4)
		def("ScrollBarImageColor3", C.Surface.Subtle)
		def("CanvasSize",           UDim2.fromScale(0, 0))
		def("AutomaticCanvasSize",  Enum.AutomaticSize.Y)
		def("ScrollingDirection",   Enum.ScrollingDirection.Y)
		def("BackgroundColor3",     C.Surface.Base)
		addCorner(R.CornerRoundness)

	elseif instanceType == "ImageLabel" or instanceType == "ImageButton" then
		def("BackgroundTransparency", 1)
		def("BorderSizePixel",        0)
		def("Size",                   UDim2.fromOffset(S.IconMD, S.IconMD))
		def("ImageColor3",            C.Text.Primary)

	elseif instanceType == "VideoFrame" then
		def("BorderSizePixel",  0)
		def("BackgroundColor3", Color3.new(0, 0, 0))
		addCorner(R.CornerRoundness)
	end
end

local function makeKey(self, name: string): string
	if not self._parallels then return name end
	if string.find(name, "/", 1, true) then return name end
	return self:_currentParent().Name .. "/" .. name
end

local function resolveKey(self, name: string): string
	if not self._parallels then return name end
	if string.find(name, "/", 1, true) then return name end
	local scoped = self:_currentParent().Name .. "/" .. name
	return self.objects.elements[scoped] and scoped or name
end

local Sleek          = {}
Sleek.__index        = Sleek
Sleek.DefaultTheme   = Themes.Fetch("Default")
Sleek.SleekContainer = getOrCreateScreenGui()
Sleek.State          = State
Sleek.Computed       = Computed

task.defer(function()
	require(Features.Attribute)
end)

local function buildLayerManager(layers: { { name: string, base: number } }): { [string]: any }
	local gates    = {}
	local counters = {}

	for i, entry in layers do
		local ceiling = layers[i + 1] and (layers[i + 1].base - 1) or math.huge
		gates[entry.name]    = { base = entry.base, ceiling = ceiling }
		counters[entry.name] = entry.base
	end

	return {
		gates    = gates,
		counters = counters,

		allocate = function(self, layerName: string): number
			local gate = self.gates[layerName]
			if not gate then
				warn("[Sleek] layer '" .. layerName .. "' not found, defaulting to Content")
				layerName = "Content"
				gate = self.gates["Content"]
			end
			local z = self.counters[layerName]
			self.counters[layerName] = math.min(z + 1, gate.ceiling)
			return z
		end,

		clamp = function(self, layerName: string, z: number): number
			local gate = self.gates[layerName] or self.gates["Content"]
			if gate.ceiling == math.huge then
				return math.max(z, gate.base)
			end
			return math.clamp(z, gate.base, gate.ceiling)
		end,

		info = function(self, layerName: string): { base: number, ceiling: number, counter: number }?
			local gate = self.gates[layerName]
			if not gate then return nil end
			return { base = gate.base, ceiling = gate.ceiling, counter = self.counters[layerName] }
		end,
	}
end

function Sleek.new(theme: Types.Theme?, size: UDim2?, position: UDim2?, opts: { parallels: boolean? }?)
	local self = setmetatable({}, Sleek)

	local t: Types.Theme
	if typeof(theme) == "string" then
		t = Themes.Fetch(theme) or Sleek.DefaultTheme
	else
		t = theme or Sleek.DefaultTheme
	end
	self.theme = t

	local panel                  = Instance.new("Frame")
	panel.Name                   = "SleekPanel_" .. Utility.generateUID(6)
	panel.Size                   = size     or t.Sizes.ContainerSize
	panel.Position               = position or t.Sizes.ContainerPosition
	panel.AnchorPoint            = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3       = t.Colors.Surface.Base
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel        = 0
	panel.ZIndex                 = 2
	panel.ClipsDescendants       = true
	panel.Parent                 = Sleek.SleekContainer

	local corner        = Instance.new("UICorner")
	corner.CornerRadius = t.Roundness.CornerRoundness
	corner.Parent       = panel

	local outline        = Instance.new("UIStroke")
	outline.Color        = t.Colors.Surface.Border
	outline.Thickness    = 1.5
	outline.Transparency = 0.6
	outline.Parent       = panel

	local padding         = Instance.new("UIPadding")
	local padSize         = t.Spacing.MD
	padding.PaddingLeft   = padSize
	padding.PaddingRight  = padSize
	padding.PaddingTop    = padSize
	padding.PaddingBottom = padSize
	padding.Parent        = panel

	self.panel = panel

	local janitor = Janitor.new()
	self.janitor  = janitor
	janitor:Add(panel, "Destroy")

	self.maids = {
		clicked    = janitor:Add(Janitor.new(), "Destroy"),
		clicking   = janitor:Add(Janitor.new(), "Destroy"),
		hovering   = janitor:Add(Janitor.new(), "Destroy"),
		dragging   = janitor:Add(Janitor.new(), "Destroy"),
		destroying = janitor:Add(Janitor.new(), "Destroy"),
	}

	self.objects = {
		elements = {},
		signals  = {},
		zindexes = {},
		states   = {},
	}

	self._contextStack = { panel }
	self._aliases      = {}
	self._apps         = {}
	self._debouncing   = false
	self._parallels    = opts ~= nil and opts.parallels == true
	self._eventBus     = {}
	self._layerMgr     = buildLayerManager(t.Layers or DEFAULT_LAYERS)

	self.Extensions = {}
	for _, module in Extensions:GetChildren() do
		if module:IsA("ModuleScript") then
			local ext = require(module)
			self.Extensions[module.Name] = typeof(ext) == "function"
				and function(...) return ext.new(self, ...) end
				or  ext
		end
	end

	return self
end

function Sleek:_currentParent(): Instance
	return self._contextStack[#self._contextStack]
end

function Sleek:into(name: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("into: name must be a string") end
	local el = self.objects.elements[resolveKey(self, name)]
	if not el then Err("into: no element named '" .. name .. "'") end
	if not el.Instance:IsA("GuiObject") and not uiLayoutTypes[el.Instance.ClassName] then
		Err("into: '" .. name .. "' cannot act as a parent")
	end
	table.insert(self._contextStack, el.Instance)
	return self
end

function Sleek:back(count: number?): typeof(setmetatable({}, Sleek))
	if typeof(count) ~= "number" then count = 1 end
	for i = 1, count do
		if #self._contextStack > 1 then
			table.remove(self._contextStack)
		end
	end
	return self
end

function Sleek:root(): typeof(setmetatable({}, Sleek))
	while #self._contextStack > 1 do table.remove(self._contextStack) end
	return self
end

function Sleek:scope(name: string, fn: (typeof(setmetatable({}, Sleek))) -> ()): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string"   then Err("scope: name must be a string") end
	if typeof(fn)   ~= "function" then Err("scope: fn must be a function") end
	self:into(name) ; fn(self) ; self:back()
	return self
end

function Sleek:alias(name: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("alias: name must be a string") end
	self._aliases[name] = self:_currentParent()
	return self
end

function Sleek:jump(name: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("jump: name must be a string") end
	local target = self._aliases[name]
	if not target then Err("jump: no alias named '" .. name .. "'") end
	table.insert(self._contextStack, target)
	return self
end

function Sleek:scopeName(): string
	return self:_currentParent().Name
end

function Sleek:scopePath(): string
	local parts = {}
	for _, inst in self._contextStack do table.insert(parts, inst.Name) end
	return table.concat(parts, "/")
end

function Sleek:state(key: string, initial: any): typeof(State.new(nil))
	if typeof(key) ~= "string" then Err("state: key must be a string") end
	if self.objects.states[key] then
		warn("[Sleek] state: '" .. key .. "' already exists — returning existing")
		return self.objects.states[key]
	end
	local s = State.new(initial)
	self.objects.states[key] = s
	self.janitor:Add(s, "destroy")
	return s
end

function Sleek:getState(key: string): typeof(State.new(nil))?
	if typeof(key) ~= "string" then Err("getState: key must be a string") end
	return self.objects.states[key]
end

function Sleek:removeState(key: string): typeof(setmetatable({}, Sleek))
	if typeof(key) ~= "string" then Err("removeState: key must be a string") end
	local s = self.objects.states[key]
	if s then s:destroy() ; self.objects.states[key] = nil end
	return self
end

function Sleek:computed(deps: { any }, fn: (...any) -> any): typeof(Computed.new({}, function() end, nil))
	if typeof(deps) ~= "table"    then Err("computed: deps must be a table of State/Computed") end
	if typeof(fn)   ~= "function" then Err("computed: fn must be a function") end
	local c = Computed.new(deps, fn, self.janitor)
	self.janitor:Add(c, "destroy")
	return c
end

function Sleek:bind(
	elementName : string,
	property    : string,
	source      : typeof(State.new(nil)) | typeof(Computed.new({}, function() end, nil)),
	mapper      : ((any) -> any)?
): typeof(setmetatable({}, Sleek))
	if typeof(elementName) ~= "string" then Err("bind: elementName must be a string") end
	if typeof(property)    ~= "string" then Err("bind: property must be a string") end
	if source == nil                   then Err("bind: source must be a State or Computed") end

	local el = self.objects.elements[resolveKey(self, elementName)]
	if not el then Err("bind: no element named '" .. elementName .. "'") end

	local function apply(value: any)
		local mapped = mapper and mapper(value) or value
		if attributeKeys[property] then
			el.Instance:SetAttribute(property, mapped)
		else
			local ok, err = pcall(function() el.Instance[property] = mapped end)
			if not ok then
				warn("[Sleek] bind: failed to set '" .. property .. "' on '" .. elementName .. "' — " .. err)
			end
		end
	end

	apply(source:get())
	local conn = source:onChange(function(new) apply(new) end)
	self.janitor:Add(conn, "Disconnect")
	return self
end

function Sleek:link(
	elementName : string,
	target      : typeof(State.new(nil)),
	mode        : ("commit" | "change")?
): typeof(setmetatable({}, Sleek))
	if typeof(elementName) ~= "string" then Err("link: elementName must be a string") end
	if target == nil                   then Err("link: target must be a State") end

	local el = self.objects.elements[resolveKey(self, elementName)]
	if not el then Err("link: no element named '" .. elementName .. "'") end

	local inst         = el.Instance
	local resolvedMode = mode or "commit"

	local conn = target:subscribe(function(new)
		pcall(function()
			if inst:IsA("TextBox") or inst:IsA("TextButton") or inst:IsA("TextLabel") then
				inst.Text = tostring(new)
			elseif typeof(new) == "boolean" then
				inst.Visible = new
			else
				pcall(function() inst.Value = new end)
			end
		end)
	end)
	self.janitor:Add(conn, "Disconnect")

	if inst:IsA("TextBox") then
		if resolvedMode == "change" then
			local c = inst.Changed:Connect(function(prop)
				if prop == "Text" then target:set(inst.Text) end
			end)
			self.janitor:Add(c, "Disconnect")
		else
			local c = inst.FocusLost:Connect(function() target:set(inst.Text) end)
			self.janitor:Add(c, "Disconnect")
		end
	elseif inst:IsA("TextButton") then
		local c = inst.Activated:Connect(function() target:set(not target:get()) end)
		self.janitor:Add(c, "Disconnect")
	end

	return self
end

local _globalBus: { [string]: any } = {}

local function getBusSignal(bus: { [string]: any }, name: string): any
	if not bus[name] then bus[name] = GoodSignal.new() end
	return bus[name]
end

function Sleek:emit(name: string, payload: any?, global: boolean?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("emit: name must be a string") end
	getBusSignal(global and _globalBus or self._eventBus, name):Fire(payload)
	return self
end

function Sleek:receive(name: string, fn: (payload: any) -> (), global: boolean?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string"   then Err("receive: name must be a string") end
	if typeof(fn)   ~= "function" then Err("receive: fn must be a function") end
	local conn = getBusSignal(global and _globalBus or self._eventBus, name):Connect(fn)
	self.janitor:Add(conn, "Disconnect")
	return self
end

function Sleek:receiveOnce(name: string, fn: (payload: any) -> (), global: boolean?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string"   then Err("receiveOnce: name must be a string") end
	if typeof(fn)   ~= "function" then Err("receiveOnce: fn must be a function") end
	local sig  = getBusSignal(global and _globalBus or self._eventBus, name)
	local conn: RBXScriptConnection
	conn = sig:Connect(function(payload) conn:Disconnect() ; fn(payload) end)
	self.janitor:Add(conn, "Disconnect")
	return self
end

function Sleek:bridge(name: string, source: any, global: boolean?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("bridge: name must be a string") end
	if source == nil            then Err("bridge: source must be a signal") end

	local bus         = global and _globalBus or self._eventBus
	local connectable = source
	if typeof(source) == "table" then
		connectable = source.Event or source.OnClientEvent or source.OnServerEvent or source
	end

	if typeof(connectable) ~= "RBXScriptSignal" and typeof(connectable) ~= "table" then
		Err("bridge: source is not a connectable signal")
	end

	local conn = connectable:Connect(function(...)
		local args    = { ... }
		local payload = #args == 1 and args[1] or (#args == 0 and nil or args)
		getBusSignal(bus, name):Fire(payload)
	end)
	self.janitor:Add(conn, "Disconnect")
	return self
end

function Sleek:clearEvent(name: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("clearEvent: name must be a string") end
	local sig = self._eventBus[name]
	if sig then sig:DisconnectAll() end
	return self
end


local themeCategories = {
	Colors = true, Roundness = true, Text = true,
	Spacing = true, Sizes = true, Motion = true, Variants = true, Layers = true,
}


local function applyCallerProps(instance: Instance, properties: { [any]: any })
	for prop, value in properties do
		if prop == "Name" then continue end

		if themeCategories[prop] and typeof(value) == "table" then continue end 

		if attributeKeys and attributeKeys[prop] then
			instance:SetAttribute(prop, value)
		else
			local ok, err = pcall(function() instance[prop] = value end)
			if not ok then
				warn("[Sleek] applyCallerProps: '" .. tostring(prop) .. "' failed — " .. err)
			end
		end
	end
end

local function applyInlineThemePatch(el: Types.Element, properties: { [any]: any })
	local patched = false
	for cat, value in properties do
		if themeCategories[cat] and typeof(value) == "table" then
			el.Theme[cat] = el.Theme[cat] or {}
			for subKey, subVal in value do
				el.Theme[cat][subKey] = subVal
			end
			patched = true
		end
	end
	return patched
end

local function build(
	self         : typeof(setmetatable({}, Sleek)),
	instanceType : string,
	properties   : Types.ElementProperties,
	theme        : Types.Theme?,
	apply        : boolean?
): typeof(setmetatable({}, Sleek))

	local rawName = properties.Name
	if not rawName or typeof(rawName) ~= "string" then
		Err("build: properties.Name is required and must be a string")
	end

	local key = makeKey(self, rawName)

	if self.objects.elements[key] then
		warn("[Sleek] '" .. key .. "' already exists — skipping")
		return self
	end

	local shouldApply   = if apply ~= nil then apply else true
	local resolvedTheme = theme or self.theme
	local parent        = self:_currentParent()

	local ok, instance = pcall(Instance.new, instanceType)
	if not ok then Err("build: invalid instanceType '" .. instanceType .. "'") end

	instance.Name = rawName

	if uiLayoutTypes[instanceType] then
		applyCallerProps(instance, properties)
		instance.Parent = parent
		local uid = Utility.generateUID()
		instance:SetAttribute("UID", uid)
		self.objects.elements[key] = {
			Instance = instance,
			UID      = uid,
			ZIndex   = 0,
			Layer    = "Content",
			Methods  = {},
			Theme    = resolvedTheme,
			Events   = {},
		} :: Types.Element
		
		self.janitor:Add(instance, "Destroy")
		return self
	end

	if not instance:IsA("GuiObject") then
		instance:Destroy()
		Err("build: '" .. instanceType .. "' is not a GuiObject or supported UI type")
	end

	local layerName = properties.Layer or "Content"
	local patchedTheme = resolvedTheme

	if applyInlineThemePatch({ Theme = resolvedTheme } :: any, properties) then
	end

	local elementTheme = Utility.deepCopy and Utility.deepCopy(resolvedTheme) or resolvedTheme
	for cat, value in properties do
		if themeCategories[cat] and typeof(value) == "table" then
			elementTheme[cat] = elementTheme[cat] or {}
			for subKey, subVal in value do
				elementTheme[cat][subKey] = subVal
			end
		end
	end

	applyCallerProps(instance, properties)
	applyStructuralDefaults(instance, instanceType, properties, elementTheme)

	if shouldApply then
		Themes.Apply(elementTheme, instance)
	end

	applyCallerProps(instance, properties)

	local zindex = self._layerMgr:allocate(layerName)
	local uid    = Utility.generateUID()
	instance:SetAttribute("UID", uid)
	instance:SetAttribute("Layer", layerName)
	instance.ZIndex = zindex
	instance.Parent = parent
	self.objects.zindexes[key] = zindex

	self.objects.elements[key] = {
		Instance = instance,
		UID      = uid,
		ZIndex   = zindex,
		Layer    = layerName,
		Methods  = {},
		Theme    = elementTheme,
		Events   = {},
	} :: Types.Element

	self.janitor:Add(instance, "Destroy")
	return self
end

function Sleek:setLayer(name: string, layerName: string, cascade: boolean?): typeof(setmetatable({}, Sleek))
	if typeof(name)      ~= "string" then Err("setLayer: name must be a string") end
	if typeof(layerName) ~= "string" then Err("setLayer: layerName must be a string") end

	local el = self.objects.elements[resolveKey(self, name)]
	if not el then Err("setLayer: no element named '" .. name .. "'") end

	local zindex = self._layerMgr:allocate(layerName)
	el.Layer             = layerName
	el.ZIndex            = zindex
	el.Instance.ZIndex   = zindex
	el.Instance:SetAttribute("Layer", layerName)

	if cascade then
		for _, child in el.Instance:GetDescendants() do
			if child:IsA("GuiObject") then
				local childZ = self._layerMgr:allocate(layerName)
				child.ZIndex = childZ
			end
		end
	end

	return self
end

function Sleek:moveToLayer(name: string, layerName: string, cascade: boolean?): typeof(setmetatable({}, Sleek))
	return self:setLayer(name, layerName, cascade)
end

function Sleek:promote(name: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("promote: name must be a string") end
	local el = self.objects.elements[resolveKey(self, name)]
	if not el then Err("promote: no element named '" .. name .. "'") end
	local newZ = self._layerMgr:clamp(el.Layer, el.ZIndex + 1)
	el.ZIndex          = newZ
	el.Instance.ZIndex = newZ
	return self
end

function Sleek:demote(name: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("demote: name must be a string") end
	local el = self.objects.elements[resolveKey(self, name)]
	if not el then Err("demote: no element named '" .. name .. "'") end
	local newZ = self._layerMgr:clamp(el.Layer, el.ZIndex - 1)
	el.ZIndex          = newZ
	el.Instance.ZIndex = newZ
	return self
end

function Sleek:getLayer(name: string): string?
	if typeof(name) ~= "string" then Err("getLayer: name must be a string") end
	local el = self.objects.elements[resolveKey(self, name)]
	if not el then return nil end
	return el.Layer
end

function Sleek:getLayerInfo(layerName: string): { base: number, ceiling: number, counter: number }?
	if typeof(layerName) ~= "string" then Err("getLayerInfo: layerName must be a string") end
	return self._layerMgr:info(layerName)
end

function Sleek:createElement(instanceType: string, properties: Types.ElementProperties, theme: Types.Theme?, apply: boolean?): Types.Element?
	if typeof(instanceType) ~= "string" then Err("createElement: instanceType must be a string") end
	if typeof(properties)   ~= "table"  then Err("createElement: properties must be a table") end
	build(self, instanceType, properties, theme, apply)
	return self.objects.elements[makeKey(self, properties.Name)]
end

function Sleek:addDropdown(properties: Types.DropdownProperties): typeof(setmetatable({}, Sleek))
	local props = properties or {}
	if typeof(props) ~= "table" then Err("addDropdown: properties must be a table") end
	self.Extensions.Dropdown.new(self, props)
	return self
end

function Sleek:addToggle(properties: Types.ToggleProperties): typeof(setmetatable({}, Sleek))
	local props = properties or {}
	if typeof(props) ~= "table" then Err("addToggle: properties must be a table") end
	self.Extensions.Toggle.new(self, props)
	return self
end

function Sleek:addSlider(properties: Types.SliderProperties): typeof(setmetatable({}, Sleek))
	local props = properties or {}
	if typeof(props) ~= "table" then Err("addSlider: properties must be a table") end
	self.Extensions.Slider.new(self, props)
	return self
end

function Sleek:addTooltip(properties: Types.TooltipProperties): typeof(setmetatable({}, Sleek))
	local props = properties or {}
	if typeof(props) ~= "table" then Err("addTooltip: properties must be a table") end
	self.Extensions.Tooltip.new(self, props)
	return self
end

function Sleek:addBadge(properties: Types.BadgeProperties): typeof(setmetatable({}, Sleek))
	local props = properties or {}
	if typeof(props) ~= "table" then Err("addBadge: properties must be a table") end
	self.Extensions.Badge.new(self, props)
	return self
end

function Sleek:addTabs(properties: Types.TabsProperties): typeof(setmetatable({}, Sleek))
	local props = properties or {}
	if typeof(props) ~= "table" then Err("addTabs: properties must be a table") end

	local result = self.Extensions.Tabs.new(self, props)
	local name   = props.Name

	if name then
		local barEl = self:getElement(name .. "_Bar")
		if barEl then self.objects.elements[name] = barEl end

		if result then
			local el = self:getElement(name)
			if el then
				for k, fn in pairs(result) do
					if el.Methods then el.Methods[k] = fn
					else rawset(el, k, fn) end
				end
			end
		end
	end

	return self
end

function Sleek:addButton(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "TextButton", opts)
end

function Sleek:addLabel(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "TextLabel", opts)
end

function Sleek:addInput(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "TextBox", opts)
end

function Sleek:addFrame(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "Frame", opts)
end

function Sleek:addImage(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	if opts.Icon and Icons[opts.Icon] then opts.Image = Icons[opts.Icon] end
	return build(self, "ImageLabel", opts)
end

function Sleek:addImageButton(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "ImageButton", opts)
end

function Sleek:addCanvasGroup(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "CanvasGroup", opts)
end

function Sleek:addCanvas(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	return self:addCanvasGroup(name, options)
end

function Sleek:addViewport(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "ViewportFrame", opts)
end

function Sleek:addVideo(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "VideoFrame", opts)
end

function Sleek:addScrollFrame(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "ScrollingFrame", opts)
end

function Sleek:addList(name: string | (Types.ElementProperties & Types.Theme), options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts: { [string]: any }
	if typeof(name) == "table" then
		opts = name :: any
		if not opts.Name then Err("addList: options.Name is required when calling addList(options)") end
	else opts = options or {} ; opts.Name = name end
	return build(self, "UIListLayout", opts)
end

function Sleek:addGrid(name: string | (Types.ElementProperties & Types.Theme), options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts: { [string]: any }
	if typeof(name) == "table" then
		opts = name :: any
		if not opts.Name then Err("addGrid: options.Name is required") end
	else opts = options or {} ; opts.Name = name end
	return build(self, "UIGridLayout", opts)
end

function Sleek:addTable(name: string | (Types.ElementProperties & Types.Theme), options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts: { [string]: any }
	if typeof(name) == "table" then
		opts = name :: any
		if not opts.Name then Err("addTable: options.Name is required") end
	else opts = options or {} ; opts.Name = name end
	return build(self, "UITableLayout", opts)
end

function Sleek:addPageLayout(name: string | (Types.ElementProperties & Types.Theme), options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts: { [string]: any }
	if typeof(name) == "table" then
		opts = name :: any
		if not opts.Name then Err("addPageLayout: options.Name is required") end
	else opts = options or {} ; opts.Name = name end
	return build(self, "UIPageLayout", opts)
end

function Sleek:addPadding(name: string, horizontal: UDim?, vertical: UDim?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("addPadding: name must be a string") end
	local h = horizontal or UDim.new(0, 8) ; local v = vertical or h
	return build(self, "UIPadding", { Name = name, PaddingLeft = h, PaddingRight = h, PaddingTop = v, PaddingBottom = v })
end

function Sleek:addCorner(name: string, radius: UDim?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("addCorner: name must be a string") end
	return build(self, "UICorner", { Name = name, CornerRadius = radius or self.theme.Roundness.CornerRoundness or UDim.new(0, 8) })
end

function Sleek:addStroke(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "UIStroke", opts)
end

function Sleek:addGradient(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "UIGradient", opts)
end

function Sleek:addScale(name: string, scale: number?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("addScale: name must be a string") end
	return build(self, "UIScale", { Name = name, Scale = scale or 1 })
end

function Sleek:addFlex(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "UIFlexItem", opts)
end

function Sleek:addAspectRatio(name: string, ratio: number?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("addAspectRatio: name must be a string") end
	return build(self, "UIAspectRatioConstraint", { Name = name, AspectRatio = ratio or 1 })
end

function Sleek:addSizeConstraint(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "UISizeConstraint", opts)
end

function Sleek:addTextSizeConstraint(name: string, options: (Types.ElementProperties & Types.Theme)?): typeof(setmetatable({}, Sleek))
	local opts = options or {} ; opts.Name = name
	return build(self, "UITextSizeConstraint", opts)
end

function Sleek:on(name: string, event: string, fn: (...any) -> ()): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("on: name must be a string") end
	local el = self.objects.elements[resolveKey(self, name)]
	if not el then Err("on: no element named '" .. name .. "'") end
	local ok, signal = pcall(function() return el.Instance[event] end)
	if not ok or typeof(signal) ~= "RBXScriptSignal" then
		Err("on: '" .. event .. "' is not a valid event on '" .. name .. "'")
	end
	local conn = signal:Connect(fn)
	el.Events[event] = conn
	self.janitor:Add(conn, "Disconnect")
	return self
end

function Sleek:once(name: string, event: string, fn: (...any) -> ()): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("once: name must be a string") end
	local el = self.objects.elements[resolveKey(self, name)]
	if not el then Err("once: no element named '" .. name .. "'") end
	local ok, signal = pcall(function() return el.Instance[event] end)
	if not ok or typeof(signal) ~= "RBXScriptSignal" then
		Err("once: '" .. event .. "' is not a valid event on '" .. name .. "'")
	end
	local conn: RBXScriptConnection
	conn = signal:Connect(function(...) conn:Disconnect() ; fn(...) end)
	self.janitor:Add(conn, "Disconnect")
	return self
end

function Sleek:off(name: string, event: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("off: name must be a string") end
	local el = self.objects.elements[resolveKey(self, name)]
	if not el then return self end
	local conn = el.Events[event]
	if conn then conn:Disconnect() ; el.Events[event] = nil end
	return self
end

function Sleek:tween(name: string, props: { [string]: any }, duration: number?, easingStyle: Enum.EasingStyle?, onComplete: (() -> ())?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("tween: name must be a string") end
	local el = self.objects.elements[resolveKey(self, name)]
	if not el then Err("tween: no element named '" .. name .. "'") end
	local d  = duration    or self.theme.Motion.DurationNormal
	local e  = easingStyle or self.theme.Motion.EasingOut
	local ti = TweenInfo.new(d, e, Enum.EasingDirection.Out)
	local t  = TweenService:Create(el.Instance, ti, props)
	if onComplete then t.Completed:Once(onComplete) end
	t:Play()
	return self
end

function Sleek:forEach(index: number, total: number, by: number?, callback: (number, Types.ForEachOptions) -> ()): typeof(setmetatable({}, Sleek))
	if typeof(index)    ~= "number"   then Err("forEach: index must be a number") end
	if typeof(total)    ~= "number"   then Err("forEach: total must be a number") end
	if by ~= nil and typeof(by) ~= "number" then Err("forEach: by must be a number or nil") end
	if typeof(callback) ~= "function" then Err("forEach: callback must be a function") end

	local step = by or 1 ; local isStopped = false
	local totalIter = math.floor((total - index) / step) + 1 ; local currentIter = 0

	local options: Types.ForEachOptions = {
		stop = function() isStopped = true end,
		app  = self, iteration = 0, isFirst = false, isLast = false, progress = 0,
	}

	for i = index, total, step do
		currentIter += 1 ; options.iteration = currentIter
		options.isFirst  = currentIter == 1
		options.isLast   = currentIter == totalIter
		options.progress = currentIter / totalIter
		callback(i, options)
		if isStopped then break end
	end

	return self
end

function Sleek:debounce(duration: number, callbackOrYield: (() -> ())?): typeof(setmetatable({}, Sleek))
	if typeof(duration) ~= "number" then Err("debounce: duration must be a number") end
	if self._debouncing then return self end
	self._debouncing = true

	if type(callbackOrYield) == "function" then
		callbackOrYield()
		task.delay(duration, function() self._debouncing = false end)
	else
		local thread = coroutine.running()
		task.delay(duration, function() self._debouncing = false ; coroutine.resume(thread) end)
		coroutine.yield()
	end

	return self
end

function Sleek:show(name: string?): typeof(setmetatable({}, Sleek))
	if name then
		local el = self.objects.elements[resolveKey(self, name)]
		if el then el.Instance.Visible = true end
	else self.panel.Visible = true end
	return self
end

function Sleek:hide(name: string?): typeof(setmetatable({}, Sleek))
	if name then
		local el = self.objects.elements[resolveKey(self, name)]
		if el then el.Instance.Visible = false end
	else self.panel.Visible = false end
	return self
end

function Sleek:toggle(name: string?): typeof(setmetatable({}, Sleek))
	if name then
		local el = self.objects.elements[resolveKey(self, name)]
		if el then el.Instance.Visible = not el.Instance.Visible end
	else self.panel.Visible = not self.panel.Visible end
	return self
end

function Sleek:createSignal(name: string): Types.Signal
	if typeof(name) ~= "string" then Err("createSignal: name must be a string") end
	local existing = self.objects.signals[name]
	if existing then return existing end
	local signal = GoodSignal.new()
	self.objects.signals[name] = signal
	self.janitor:Add(signal, "DisconnectAll")
	return signal
end

function Sleek:getSignal(name: string): Types.Signal?
	if typeof(name) ~= "string" then Err("getSignal: name must be a string") end
	return self.objects.signals[name]
end

function Sleek:removeSignal(name: string)
	if typeof(name) ~= "string" then Err("removeSignal: name must be a string") end
	local signal = self.objects.signals[name]
	if signal then signal:DisconnectAll() ; self.objects.signals[name] = nil end
end

function Sleek:bindSignal(signalOrName: string | Types.Signal, source: RBXScriptSignal | BindableEvent)
	if typeof(signalOrName) ~= "string" and typeof(signalOrName) ~= "table" then
		Err("bindSignal: first arg must be a signal name or signal instance")
	end
	if source == nil then Err("bindSignal: source must be an RBXScriptSignal or BindableEvent") end

	local target: Types.Signal = typeof(signalOrName) == "string"
		and (self.objects.signals[signalOrName] or self:createSignal(signalOrName))
		or  signalOrName :: Types.Signal

	local native = typeof(source) == "RBXScriptSignal" and source or source.Event
	local conn   = native:Connect(function(...) target:Fire(...) end)
	self.janitor:Add(conn, "Disconnect")
	return self
end

function Sleek:setTheme(themeOrName: string | Types.Theme, reapply: boolean?): typeof(setmetatable({}, Sleek))
	local resolved: Types.Theme

	if typeof(themeOrName) == "string" then
		resolved = Themes.Fetch(themeOrName)
		if not resolved then
			warn("[Sleek] setTheme: unknown theme '" .. themeOrName .. "', falling back to Default")
			resolved = Themes.Fetch("Default")
		end
	elseif typeof(themeOrName) == "table" then
		if Utility.countTable(themeOrName) == 0 then
			warn("[Sleek] setTheme: theme table is empty, falling back to Default")
			resolved = Themes.Fetch("Default")
		else
			resolved = themeOrName
		end
	else
		Err("setTheme: expected a theme name or theme table, got " .. typeof(themeOrName))
		return self
	end

	self.theme = resolved
	self.panel.BackgroundColor3 = resolved.Colors.Surface.Base
	Themes.Apply(resolved, self.panel)

	if reapply then
		for _, element in self.objects.elements do
			element.Theme = resolved
			Themes.Apply(resolved, element.Instance)
		end
	end

	return self
end

function Sleek:modifyTheme(modifications: Types.Theme, reapply: boolean?): typeof(setmetatable({}, Sleek))
	if typeof(modifications) ~= "table" then Err("modifyTheme: modifications must be a table") end
	if Utility.countTable(modifications) == 0 then
		warn("[Sleek] modifyTheme: empty, nothing changed")
		return self
	end

	self.theme = Themes.Modify(self.theme, modifications)
	self.panel.BackgroundColor3 = self.theme.Colors.Surface.Base
	Themes.Apply(self.theme, self.panel)

	if reapply then
		for _, element in self.objects.elements do
			element.Theme = self.theme
			Themes.Apply(self.theme, element.Instance)
		end
	end

	return self
end

function Sleek:wrapTheme(name: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("wrapTheme: name must be a string") end
	local el = self.objects.elements[resolveKey(self, name)]
	if not el then Err("wrapTheme: no element named '" .. name .. "'") end
	Themes.Apply(el.Theme, el.Instance)
	return self
end

function Sleek:getElement(name: string): Types.Element?
	if typeof(name) ~= "string" then Err("getElement: name must be a string") end
	return self.objects.elements[resolveKey(self, name)]
end

function Sleek:getInstance(name: string): Instance?
	if typeof(name) ~= "string" then Err("getInstance: name must be a string") end
	local result = self.panel:FindFirstChild(name, true)
	if not result then warn("[Sleek] getInstance: no instance named '" .. name .. "'") end
	return result
end

function Sleek:modifyElement(name: string, modifications: { [any]: any }): typeof(setmetatable({}, Sleek))
	if typeof(name)          ~= "string" then Err("modifyElement: name must be a string") end
	if typeof(modifications) ~= "table"  then Err("modifyElement: modifications must be a table") end

	local el = self.objects.elements[resolveKey(self, name)]
	if not el then Err("modifyElement: no element named '" .. name .. "'") end

	local needsThemeReapply = false

	for prop, value in modifications do
		if prop == "ZIndex" then
			local clamped = self._layerMgr:clamp(el.Layer, value)
			el.ZIndex          = clamped
			el.Instance.ZIndex = clamped
		elseif prop == "Layer" then
			self:setLayer(name, value)
		elseif themeCategories[prop] and typeof(value) == "table" then
			el.Theme[prop] = el.Theme[prop] or {}
			for subKey, subVal in value do el.Theme[prop][subKey] = subVal end
			needsThemeReapply = true
		elseif attributeKeys and attributeKeys[prop] then
			el.Instance:SetAttribute(prop, value)
		else
			local ok, err = pcall(function() el.Instance[prop] = value end)
			if not ok then warn("[Sleek] modifyElement: '" .. tostring(prop) .. "' failed — " .. err) end
		end
	end

	if needsThemeReapply then Themes.Apply(el.Theme, el.Instance) end
	return self
end

function Sleek:removeElement(name: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("removeElement: name must be a string") end
	local key = resolveKey(self, name)
	local el  = self.objects.elements[key]
	if el then
		for i = #self._contextStack, 1, -1 do
			if self._contextStack[i] == el.Instance then table.remove(self._contextStack, i) end
		end
		for aliasName, inst in self._aliases do
			if inst == el.Instance then self._aliases[aliasName] = nil end
		end
		el.Instance:Destroy()
		self.objects.elements[key] = nil
	end
	return self
end

function Sleek:setAppPosition(position: UDim2): typeof(setmetatable({}, Sleek))
	if typeof(position) ~= "UDim2" then Err("setAppPosition: position must be a UDim2") end
	self.panel.Position = position
	return self
end

function Sleek:setAppSize(size: UDim2): typeof(setmetatable({}, Sleek))
	if typeof(size) ~= "UDim2" then Err("setAppSize: size must be a UDim2") end
	self.panel.Size = size
	return self
end

function Sleek:modifyApp(modifications: { [string]: any }): typeof(setmetatable({}, Sleek))
	for prop, value in modifications do
		local ok, err = pcall(function() self.panel[prop] = value end)
		if not ok then warn("[Sleek] modifyApp: '" .. tostring(prop) .. "' failed — " .. err) end
	end
	return self
end

function Sleek:install(name: string, builder: (typeof(setmetatable({}, Sleek)), { [any]: any }?) -> ()): typeof(setmetatable({}, Sleek))
	if typeof(name)    ~= "string"   then Err("install: name must be a string") end
	if typeof(builder) ~= "function" then Err("install: builder must be a function") end
	if self._apps[name] then warn("[Sleek] install: '" .. name .. "' already installed — overwriting") end
	self._apps[name] = builder
	return self
end

function Sleek:open(name: string, parameters: { [any]: any }?): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("open: name must be a string") end
	local builder = self._apps[name]
	if not builder then Err("open: no app installed named '" .. name .. "'") end
	builder(Sleek.new(self.theme), parameters)
	return self
end

function Sleek:uninstall(name: string): typeof(setmetatable({}, Sleek))
	if typeof(name) ~= "string" then Err("uninstall: name must be a string") end
	self._apps[name] = nil
	return self
end

function Sleek:destroy()
	for _, sig in self.objects.signals do sig:DisconnectAll() end
	for _, s   in self.objects.states  do s:destroy() end
	for _, sig in self._eventBus       do sig:DisconnectAll() end
	self.objects.signals  = {}
	self.objects.elements = {}
	self.objects.states   = {}
	self._contextStack    = {}
	self._aliases         = {}
	self._eventBus        = {}
	self.janitor:Destroy()
end

return Sleek