

local Promise  = require(script.Parent.Promise)
local AtomMod  = require(script.Parent.Atom)

type MoleculeInternal = {
	_atoms:     { [string]: any },
	_listeners: { (string, any, any) -> () },
}

local Molecule = {}
Molecule.__index = Molecule

local function new(atoms: { [string]: any }): any
	local self: MoleculeInternal = {
		_atoms     = atoms,
		_listeners = {},
	}
	local mol = setmetatable(self :: any, Molecule)

	for key, atom in atoms do
		atom:onChange(function(newVal, oldVal)
			for _, fn in mol._listeners do
				task.spawn(fn, key, newVal, oldVal)
			end
		end)
	end

	return mol
end

function Molecule:get(): { [string]: any }
	local snapshot = {}
	for key, atom in self._atoms do
		snapshot[key] = atom:get()
	end
	return snapshot
end

function Molecule:patch(values: { [string]: any })
	AtomMod.batch(function()
		for key, value in values do
			local atom = self._atoms[key]
			if atom then
				atom:set(value)
			end
		end
	end)
end

function Molecule:onChange(cb: (string, any, any) -> ()): () -> ()
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

function Molecule:promise(): any
	return Promise.new(function(resolve)
		local disconnect: (() -> ())?
		disconnect = self:onChange(function(key, new, old)
			if disconnect then disconnect() end
			resolve(key, new, old)
		end)
	end)
end

return { new = new }