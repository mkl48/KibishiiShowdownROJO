

local Promise = require(script.Parent.Promise)

type OrganismInternal = {
	_molecules: { [string]: any },
	_listeners: { (string, string, any, any) -> () },
}

local Organism = {}
Organism.__index = Organism

local function new(molecules: { [string]: any }): any
	local self: OrganismInternal = {
		_molecules = molecules,
		_listeners = {},
	}
	local org = setmetatable(self :: any, Organism)

	for molKey, molecule in molecules do
		molecule:onChange(function(atomKey, newVal, oldVal)
			for _, fn in org._listeners do
				task.spawn(fn, molKey, atomKey, newVal, oldVal)
			end
		end)
	end

	return org
end

function Organism:get(): { [string]: any }
	local snapshot = {}
	for key, molecule in self._molecules do
		snapshot[key] = molecule:get()
	end
	return snapshot
end

function Organism:patch(values: { [string]: { [string]: any } })
	for molKey, fields in values do
		local molecule = self._molecules[molKey]
		if molecule then
			molecule:patch(fields)
		end
	end
end

function Organism:onChange(cb: (string, string, any, any) -> ()): () -> ()
	table.insert(self._listeners, cb)
	return function()
		for i, fn in self._listeners do
			if fn == cb then
				table.remove(self._listeners, i)
				break
			end
		end
	end
end

function Organism:promise(): any
	return Promise.new(function(resolve)
		local disconnect: (() -> ())?
		disconnect = self:onChange(function(mol, key, new, old)
			if disconnect then disconnect() end
			resolve(mol, key, new, old)
		end)
	end)
end

return { new = new }