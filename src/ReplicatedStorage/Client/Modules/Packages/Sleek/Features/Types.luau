local Types = {}

local Packages = script.Parent.Parent.Packages
local Features = script.Parent.Parent.Features

local GoodSignal = require(Packages.GoodSignal)
local Janitor    = require(Packages.Janitor)

export type Signal  = typeof(GoodSignal.new())
export type Janitor = typeof(Janitor.new())
export type Theme   = typeof(require(Features.Themes.Default))
export type ElementProperties = (GuiObject & TextLabel & ImageLabel & TextButton & TextBox & ImageLabel & ImageButton & CanvasGroup & Frame & ScrollingFrame & UIStroke & UIGradient & UIGridLayout & UIListLayout & UIPadding) 
export type Extentions = {
	new: (self: Element, {[string]: any}) -> (),
}

export type Element = {
	Instance: GuiObject,
	UID: string,
	ZIndex: number,
	Methods: { [string]: (...any) -> (...any) },
	Theme: Theme,
	Events: { [string]: RBXScriptConnection },
}

export type DropdownOption = (() -> ()) | {
	Label    : string?,
	Icon     : string?,
	Disabled : boolean?,
	Callback : (() -> ())?,
}

export type DropdownProperties = {
	Name             : string?,
	LayoutOrder      : number?,
	Options          : { [string]: DropdownOption }?,
	Placeholder      : string?,
	Size             : UDim2?,
	Variant          : string?,
	SelectedVariant  : string?,
	Disabled         : boolean?,
	DisabledTransparency : number?,
	Icon             : string?,
	IconSize         : UDim2?,
	IconTransparency : number?,
	ShowIcon         : boolean?,
	OptionVariant    : string?,
	OptionHeight     : number?,
	MaxHeight        : number?,
	ListOffset       : UDim2?,
	ListWidth        : number?,
	ListWidthOffset  : number?,
	CloseOnSelect    : boolean?,
	OnChange         : ((selected: string) -> ())?,
	OnOpen           : (() -> ())?,
	OnClose          : (() -> ())?,
}


export type ToggleProperties = {
	Name     : string?,
	Label    : string?,
	Default  : boolean?,
	OnChange : ((state: boolean) -> ())?,
}


export type SliderProperties = {
	Name     : string?,
	Label    : string?,
	Min      : number?,
	Max      : number?,
	Default  : number?,
	Step     : number?,
	OnChange : ((value: number) -> ())?,
}


export type TooltipProperties = {
	Name   : string?,
	Target : string?,
	Text   : string?,
	Offset : UDim2?,
}


export type BadgeProperties = {
	Name    : string?,
	Text    : string?,
	Variant : string?,
	Size    : UDim2?,
}


export type TabsProperties = {
	Name     : string?,
	SelectedVariant  : string?,
	Variant  : string?,
	Tabs     : { string }?,
	Default  : string?,
	OnChange : ((tab: string) -> ())?,
}


export type ForEachOptions = {
	stop      : () -> (),
	app       : any,
	iteration : number,
	isFirst   : boolean,
	isLast    : boolean,
	progress  : number,
}

return Types