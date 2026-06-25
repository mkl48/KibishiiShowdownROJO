--!strict
-- Types.lua  (Material)
-- Full type definitions for Icon + all Material extensions.
-- Replaces the original TopbarPlus Types.lua — drop this in the same location.

-- ── Primitives ────────────────────────────────────────────────────────────────

type Connection<T... = ...any> = {
	Disconnect: (self: Connection<T...>) -> (),
}

type Signal<T... = ...any> = {
	Connect : (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	Once    : (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	Wait    : (self: Signal<T...>) -> T...,
	Fire    : (self: Signal<T...>, T...) -> (),
}

-- ── Shared enums ──────────────────────────────────────────────────────────────

export type IconState   = "Deselected" | "Selected" | "Viewing"
export type Alignment   = "Left" | "Center" | "Right"
export type EventSource = "User" | "OneClick" | "AutoDeselect" | "HideParentFeature" | "Overflow" | string
export type Events      = "selected" | "deselected" | "toggled" | "viewingStarted" | "viewingEnded"
| "notified" | "stateChanged" | "badgeUpdated"
export type Modification = { any }
export type BadgeMode   = "dot" | "count" | "custom"
export type AnnouncementType = "info" | "warn" | "error" | "success"

-- ── Theme token tables ────────────────────────────────────────────────────────

export type WidgetTokens = {
	BackgroundColor3       : Color3?,
	BackgroundTransparency : number?,
	BorderSize             : number?,
	MinimumWidth           : number?,
	MinimumHeight          : number?,
	DesiredWidth           : number?,
}

export type LabelTokens = {
	TextColor3 : Color3?,
	TextSize   : number?,
	FontFace   : Font?,
}

export type BadgeTokens = {
	BackgroundColor3 : Color3?,
	TextColor3       : Color3?,
	TextSize         : number?,
}

export type DropdownTokens = {
	BackgroundColor3       : Color3?,
	BackgroundTransparency : number?,
	MaxIcons               : number?,
}

export type MenuTokens = {
	MaxIcons : number?,
}

export type ThemeTokens = {
	Widget   : WidgetTokens?,
	Label    : LabelTokens?,
	Badge    : BadgeTokens?,
	Dropdown : DropdownTokens?,
	Menu     : MenuTokens?,
}

-- ── Element handle ────────────────────────────────────────────────────────────
-- Every Element constructor returns a Handle.
-- Pass handle.icon to :setDropdown() / :setMenu().
-- Use handle.set(value) / handle.get() for programmatic control.

export type Handle = {
	icon : Icon,
	set  : ((value: any) -> ())?,
	get  : (() -> any)?,
}

-- ── GroupController ───────────────────────────────────────────────────────────

export type GroupController = {
	icons    : { Icon },
	isolated : boolean,
	add            : (self: GroupController, icon: Icon) -> GroupController,
	setEnabled     : (self: GroupController, enabled: boolean) -> GroupController,
	applyTheme     : (self: GroupController, name: string, overrides: ThemeTokens?) -> GroupController,
	exclusiveSelect: (self: GroupController, enabled: boolean) -> GroupController,
	isolate        : (self: GroupController) -> GroupController,
	unisolate      : (self: GroupController) -> GroupController,
	destroy        : (self: GroupController) -> (),
}

-- ── BadgeOptions ──────────────────────────────────────────────────────────────

export type BadgeOptions = {
	clearAfter : number?,
}

export type CustomBadgeCfg = {
	image : (number | string)?,
	text  : string?,
	color : Color3?,
}

-- ── Transition ────────────────────────────────────────────────────────────────

export type TransitionSide = {
	style     : Enum.EasingStyle?,
	direction : Enum.EasingDirection?,
	time      : number?,
}

export type TransitionPair = {
	open  : TransitionSide?,
	close : TransitionSide?,
}

-- ── Element config types (re-exported for external use) ───────────────────────

export type ItemCfg = {
	label       : string?,
	image       : (number | string)?,
	description : string?,
	badge       : string?,
	badgeColor  : Color3?,
	disabled    : boolean?,
	onSelect    : ((icon: Icon) -> ())?,
}

export type HeaderCfg = {
	text     : string?,
	showLine : boolean?,
	icon     : (number | string)?,
} | string

export type DividerCfg = {
	label : string?,
	color : Color3?,
}

export type ToggleCfg = {
	label    : string?,
	value    : boolean?,
	color    : Color3?,
	onChange : ((value: boolean) -> ())?,
}

export type SliderCfg = {
	label    : string?,
	min      : number?,
	max      : number?,
	default  : number?,
	step     : number?,
	color    : Color3?,
	onChange : ((value: number) -> ())?,
}

export type DisplayCfg = {
	label  : string?,
	value  : any?,
	color  : Color3?,
	prefix : string?,
	suffix : string?,
	format : ((value: any) -> string)?,
}

export type InputCfg = {
	label         : string?,
	placeholder   : string?,
	default       : string?,
	maxLength     : number?,
	clearOnSubmit : boolean?,
	onSubmit      : ((text: string) -> ())?,
	onChange      : ((text: string) -> ())?,
}

export type StepperCfg = {
	label    : string?,
	min      : number?,
	max      : number?,
	default  : number?,
	step     : number?,
	onChange : ((value: number) -> ())?,
}

export type KeybindCfg = {
	label     : string?,
	default   : Enum.KeyCode?,
	blacklist : { Enum.KeyCode }?,
	onChange  : ((key: Enum.KeyCode) -> ())?,
}

export type ColorCfg = {
	label    : string?,
	value    : Color3?,
	showHex  : boolean?,
	onChange : ((color: Color3) -> ())?,
}

export type ProgressCfg = {
	label    : string?,
	value    : any?,
	min      : number?,
	max      : number?,
	color    : Color3?,
	showPct  : boolean?,
	animate  : boolean?,
	binding  : any?,
}

export type RadioCfg = {
	options  : { string }?,
	default  : number?,
	color    : Color3?,
	onChange : ((index: number, label: string) -> ())?,
}

export type MultiCfg = {
	options  : { string }?,
	default  : { boolean }?,
	color    : Color3?,
	onChange : (({ boolean }) -> ())?,
}

export type TextareaCfg = {
	label       : string?,
	placeholder : string?,
	default     : string?,
	rows        : number?,
	onSubmit    : ((text: string) -> ())?,
	onChange    : ((text: string) -> ())?,
}

export type ConfirmCfg = {
	label        : string?,
	confirmText  : string?,
	cancelText   : string?,
	confirmColor : Color3?,
	onConfirm    : (() -> ())?,
	onCancel     : (() -> ())?,
}

export type LinkCfg = {
	label   : string?,
	url     : string?,
	onClick : (() -> ())?,
}

export type RatingCfg = {
	label    : string?,
	max      : number?,
	default  : number?,
	color    : Color3?,
	readOnly : boolean?,
	onChange : ((value: number) -> ())?,
}

export type SearchCfg = {
	placeholder : string?,
	targets     : { Handle | Icon }?,
	onSearch    : ((text: string) -> ())?,
}

export type AnnounceCfg = {
	text    : string?,
	type    : AnnouncementType?,
	dismiss : boolean?,
}

export type DropdownCfg = {
	label : string?,
	image : (number | string)?,
	items : { Handle | Icon }?,
}

export type TagsCfg = {
	label    : string?,
	options  : { string }?,
	default  : { string }?,
	max      : number?,
	color    : Color3?,
	onChange : (({ string }) -> ())?,
}

export type SpinnerCfg = {
	label    : string?,
	options  : { string }?,
	default  : number?,
	onChange : ((index: number, value: string) -> ())?,
}

export type StatRowCfg = {
	label : string?,
	value : any?,
	delta : any?,
	color : Color3?,
}

-- ── Element module type ───────────────────────────────────────────────────────

export type ElementModule = {
	_init        : (Icon: StaticIcon) -> (),
	item         : (cfg: ItemCfg) -> Handle,
	header       : (cfg: HeaderCfg) -> Handle,
	divider      : (cfg: DividerCfg?) -> Handle,
	separator    : (text: string?) -> Handle,
	toggle       : (cfg: ToggleCfg) -> Handle,
	slider       : (cfg: SliderCfg) -> Handle,
	display      : (cfg: DisplayCfg) -> Handle,
	input        : (cfg: InputCfg) -> Handle,
	stepper      : (cfg: StepperCfg) -> Handle,
	keybind      : (cfg: KeybindCfg) -> Handle,
	color        : (cfg: ColorCfg) -> Handle,
	progress     : (cfg: ProgressCfg) -> Handle,
	radio        : (cfg: RadioCfg) -> { Handle },
	multiselect  : (cfg: MultiCfg) -> { Handle },
	textarea     : (cfg: TextareaCfg) -> Handle,
	confirm      : (cfg: ConfirmCfg) -> Handle,
	link         : (cfg: LinkCfg) -> Handle,
	rating       : (cfg: RatingCfg) -> Handle,
	search       : (cfg: SearchCfg) -> Handle,
	announcement : (cfg: AnnounceCfg) -> Handle,
	dropdown     : (cfg: DropdownCfg) -> Handle,
	tags         : (cfg: TagsCfg) -> Handle,
	spinner      : (cfg: SpinnerCfg) -> Handle,
	stat         : (cfg: StatRowCfg) -> Handle,
}

-- ── Icon instance methods ─────────────────────────────────────────────────────

type IconMethods = {
	-- Core
	setName        : (self: Icon, name: string) -> Icon,
	getInstance    : (self: Icon, name: string) -> Instance?,
	setState       : (self: Icon, state: IconState?, source: EventSource?, sourceIcon: Icon?) -> (),
	modifyTheme    : (self: Icon, mods: { Modification } | Modification, uid: string?) -> (Icon, string),
	modifyChildTheme : (self: Icon, mods: { Modification }, uid: string?) -> Icon,
	removeModification    : (self: Icon, uid: string) -> Icon,
	removeModificationWith: (self: Icon, instance: string, property: string, state: IconState?) -> Icon,
	setTheme       : (self: Icon, theme: any) -> Icon,
	refreshAppearance : (self: Icon, instance: Instance?, property: string?) -> Icon,
	refresh        : (self: Icon) -> Icon,
	setEnabled     : (self: Icon, enabled: boolean) -> Icon,
	select         : (self: Icon, source: EventSource?, sourceIcon: Icon?) -> Icon,
	deselect       : (self: Icon, source: EventSource?, sourceIcon: Icon?) -> Icon,
	notify         : (self: Icon, clearSignal: Signal?, noticeId: string?) -> Icon,
	clearNotices   : (self: Icon) -> Icon,
	disableOverlay : (self: Icon, disabled: boolean) -> Icon,
	-- Appearance
	setImage       : (self: Icon, id: number | string, state: IconState?) -> Icon,
	setLabel       : (self: Icon, text: string, state: IconState?) -> Icon,
	setOrder       : (self: Icon, order: number, state: IconState?) -> Icon,
	setCornerRadius: (self: Icon, udim: UDim, state: IconState?) -> Icon,
	align          : (self: Icon, side: Alignment?) -> Icon,
	setAlignment   : (self: Icon, side: Alignment?) -> Icon,
	setLeft        : (self: Icon) -> Icon,
	setMid         : (self: Icon) -> Icon,
	setRight       : (self: Icon) -> Icon,
	setWidth       : (self: Icon, min: number, state: IconState?) -> Icon,
	setImageScale  : (self: Icon, scale: number, state: IconState?) -> Icon,
	setImageRatio  : (self: Icon, ratio: number, state: IconState?) -> Icon,
	setTextSize    : (self: Icon, size: number, state: IconState?) -> Icon,
	setTextFont    : (self: Icon, font: string | Enum.Font, weight: Enum.FontWeight?, style: Enum.FontStyle?, state: IconState?) -> Icon,
	setTextColor   : (self: Icon, color: Color3, state: IconState?) -> Icon,
	-- Input
	bindToggleItem  : (self: Icon, obj: GuiObject | LayerCollector) -> Icon,
	unbindToggleItem: (self: Icon, obj: GuiObject | LayerCollector) -> Icon,
	bindEvent       : (self: Icon, event: Events, fn: (...any) -> ()) -> Icon,
	unbindEvent     : (self: Icon, event: Events) -> Icon,
	bindToggleKey   : (self: Icon, key: Enum.KeyCode) -> Icon,
	unbindToggleKey : (self: Icon, key: Enum.KeyCode) -> Icon,
	call            : (self: Icon, fn: (icon: Icon, ...any) -> (), ...any) -> Icon,
	addToJanitor    : (self: Icon, obj: any, method: string?, index: any?) -> Icon,
	lock            : (self: Icon) -> Icon,
	unlock          : (self: Icon) -> Icon,
	debounce        : (self: Icon, seconds: number) -> Icon,
	autoDeselect    : (self: Icon, enabled: boolean?) -> Icon,
	oneClick        : (self: Icon, enabled: boolean?) -> Icon,
	setCaption      : (self: Icon, text: string?) -> Icon,
	setCaptionHint  : (self: Icon, key: Enum.KeyCode) -> Icon,
	-- Hierarchy
	setDropdown  : (self: Icon, icons: { Icon | Handle }) -> Icon,
	joinDropdown : (self: Icon, parent: Icon) -> Icon,
	getDropdown  : (self: Icon) -> Frame,
	setMenu      : (self: Icon, icons: { Icon | Handle }) -> Icon,
	joinMenu     : (self: Icon, parent: Icon) -> Icon,
	setFixedMenu : (self: Icon, icons: { Icon | Handle }) -> Icon,
	leave        : (self: Icon) -> Icon,
	-- Material extensions
	theme        : (self: Icon, name: string, overrides: ThemeTokens?) -> Icon,
	badge        : (self: Icon, mode: BadgeMode, value: (number | string | CustomBadgeCfg)?, options: BadgeOptions?) -> Icon,
	clearBadge   : (self: Icon) -> Icon,
	transition   : (self: Icon, pair: TransitionPair) -> Icon,
	onSelect     : (self: Icon, fn: (icon: Icon) -> ()) -> Icon,
	onDeselect   : (self: Icon, fn: (icon: Icon) -> ()) -> Icon,
	onChange     : (self: Icon, fn: (icon: Icon, state: IconState) -> ()) -> Icon,
	overflow     : (self: Icon, enabled: boolean?) -> Icon,
	group        : (self: Icon | string, name: string?) -> (Icon | GroupController),
	standalone   : (self: Icon) -> Icon,
	tooltip      : (self: Icon, text: string) -> Icon,
	destroy      : (self: Icon) -> (),
	Destroy      : (self: Icon) -> (),
	-- Signals
	selected         : Signal<EventSource>,
	deselected       : Signal<EventSource>,
	toggled          : Signal<boolean, EventSource>,
	viewingStarted   : Signal<boolean>,
	viewingEnded     : Signal<boolean>,
	stateChanged     : Signal<IconState>,
	notified         : Signal<>,
	badgeUpdated     : Signal<BadgeMode?, any?>,
	-- Fields
	name             : string,
	UID              : string,
	isSelected       : boolean,
	isEnabled        : boolean,
	isViewing        : boolean,
	isDestroyed      : boolean,
	locked           : boolean,
	totalNotices     : number,
	activeState      : IconState,
	alignment        : Alignment,
	dropdownIcons    : { string },
	menuIcons        : { string },
	parentIconUID    : string | boolean,
	widget           : Frame,
	janitor          : any,
	_badgeMode       : BadgeMode?,
	_badgeCount      : number,
	_transition      : TransitionPair?,
	_overflowOverride: boolean?,
	_groupName       : string?,
}

-- ── Icon static methods ───────────────────────────────────────────────────────

type IconStatic = {
	new : () -> Icon,
	getIcons       : () -> { [string]: Icon },
	getIconByUID   : (uid: string) -> Icon?,
	getIcon        : (nameOrUID: string) -> Icon?,
	getGroup       : (name: string) -> GroupController,
	group          : (nameOrIconOrSelf: Icon | string, name: string?) -> (Icon | GroupController),
	setTopbarEnabled   : (enabled: boolean, internal: boolean?) -> (),
	modifyBaseTheme    : (mods: { Modification }) -> (),
	setDisplayOrder    : (order: number) -> (),
	registerTheme      : (name: string, tokens: ThemeTokens) -> (),
	applyTheme         : (name: string) -> (),
	setOverflowEnabled : (enabled: boolean) -> (),
	-- Tables
	Transitions : {
		Default : TransitionPair,
		Smooth  : TransitionPair,
		Bouncy  : TransitionPair,
		Snap    : TransitionPair,
		Fade    : TransitionPair,
		None    : TransitionPair,
	},
	Element : ElementModule,
	-- Signals
	iconAdded   : Signal<Icon>,
	iconRemoved : Signal<Icon>,
	iconChanged : Signal<Icon>,
	baseDisplayOrderChanged : Signal<number>,
	insetHeightChanged      : Signal<number>,
	-- Fields
	baseDisplayOrder : number,
	baseTheme        : any,
	isOldTopbar      : boolean,
	iconsDictionary  : { [string]: Icon },
	topbarEnabled    : boolean,
	container        : { [string]: ScreenGui },
}

export type Icon       = IconMethods
export type StaticIcon = IconStatic

return {}