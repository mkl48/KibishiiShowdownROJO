local Builder = require(script.Parent.Builder)
local Types = require(script.Parent.Types)

type MoveSpec = Types.MoveSpec
type VariantSpec = Types.VariantSpec
type VariantResolver = Types.VariantResolver
type Ctx = Types.Ctx

export type VariantBuilder = {
	variant: (self: VariantBuilder, name: string, fn: (b: typeof(Builder.new(""))) -> MoveSpec) -> VariantBuilder,
	resolver: (self: VariantBuilder, fn: VariantResolver) -> VariantBuilder,
	tag: (self: VariantBuilder, ...string) -> VariantBuilder,
	build: (self: VariantBuilder) -> VariantSpec,
}

local DEFAULT_RESOLVER: VariantResolver = function(_ctx: Ctx): string
	return "base"
end

local function new(name: string): VariantBuilder
	local vb = {} :: any
	vb._name = name
	vb._variants = {} :: { [string]: MoveSpec }
	vb._resolver = DEFAULT_RESOLVER
	vb._tags = {} :: { string }

	function vb:variant(variantName: string, fn: (b: any) -> MoveSpec)
		local b = Builder.new(name .. "/" .. variantName)
		vb._variants[variantName] = fn(b)
		return self
	end

	function vb:resolver(fn: VariantResolver)
		vb._resolver = fn
		return self
	end

	function vb:tag(...)
		for _, t in { ... } do
			table.insert(vb._tags, t)
		end
		return self
	end

	function vb:build(): VariantSpec
		local spec: VariantSpec = {
			name = vb._name,
			variants = vb._variants,
			resolver = vb._resolver,
			tags = vb._tags,
		}
		table.freeze(spec)
		return spec
	end

	return vb
end

return { new = new }