export type ConfigureOptions = {
	NetworkManager    : any,
	NetworkController : any,
	Manifest          : any?,
	ContextStructure  : ContextStructure,
	Verbosity         : ("trace" | "warn" | "error" | "silent")?,
	Timeout           : number?,
	Strict            : boolean?,
	TierOrder         : { string }?,
}

export type ContextStructure = {
	Server : ContextBranch?,
	Client : ContextBranch?,
	Shared : ContextBranch?,
}

export type ContextBranch = {
	Host      : Instance,
	Structure : { string },
}

export type ModuleStatus =
	"pending"   |
"warmup"    |
"init"      |
"starting"  |
"started"   |
"errored"   |
"skipped"   |
"destroyed"

export type ModuleInfo = {
	name    : string,
	status  : ModuleStatus,
	tier    : string,
	context : string,
	timing  : number,
	tags    : { string },
	version : string?,
	alias   : string?,
}

export type MiddlewareContext = {
	module  : string,
	phase   : string,
	tier    : string,
	context : string,
	time    : number,
}

export type PluginHandle = {
	[string] : (...any) -> any,
}

export type Plugin = {
	name     : string,
	version  : string?,
	requires : { string }?,
	install  : (self: Plugin, artext: any, opts: any?) -> PluginHandle?,
}

export type CacheNamespace = {
	set      : (key: string, value: any) -> (),
	get      : (key: string) -> any,
	has      : (key: string) -> boolean,
	delete   : (key: string) -> (),
	watch    : (key: string, fn: (any, any) -> ()) -> () -> (),
	keys     : (pattern: string?) -> { string },
	snapshot : () -> { [string]: any },
}

export type Logger = {
	trace : (message: string) -> (),
	info  : (message: string) -> (),
	warn  : (message: string) -> (),
	error : (message: string) -> (),
}

export type StateSnapshot = {
	time    : number,
	cache   : { [string]: any },
	modules : { [string]: ModuleStatus },
	ctx     : { [string]: any },
}

export type WorkflowStatus = "pending" | "running" | "done" | "cancelled" | "failed"

export type ArTexDiagnostics = {
	bootTime     : number,
	moduleCount  : number,
	errorCount   : number,
	skippedCount : number,
	slowest      : string,
	fastest      : string,
	byTier       : { [string]: { count: number, totalTime: number } },
}

export type Ctx = {
	ArTex             : any,
	Cache             : any,
	Context           : string,
	Env               : any,
	Net               : any,
	Log               : Logger,
	Module            : any,
	Name              : string,
	Tier              : string,
	Version           : string,
	Manifest          : any?,
	NetworkManager    : any?,
	NetworkController : any?,
	Server            : { PlaceId: number, JobId: string, PlayerCount: number }?,
	Player            : Player?,
	[string]          : any,
}

return nil