local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local game = roblox.deserializePlace(fs.readFile("/home/kr3ative/Documents/KibishiiShwodwon.rbxl"))

local OUT = "/home/kr3ative/Documents/Projects/Games/Roblox/KibishiiShowdownROJO"
local SRC = OUT .. "/src"
local SCRIPT = { Script = "server", LocalScript = "client", ModuleScript = "module" }

-- does this subtree contain any script? (so we only emit script-bearing structure)
local function hasScript(inst): boolean
	for _, d in inst:GetDescendants() do
		if SCRIPT[d.ClassName] then return true end
	end
	return SCRIPT[inst.ClassName] ~= nil
end

local function sane(name: string): string
	return (name:gsub("[/\\]", "_"))
end

local function ext(cls: string): string
	if cls == "LocalScript" then return ".client.luau"
	elseif cls == "Script" then return ".server.luau"
	else return ".luau" end
end

local counts = { scripts = 0, folders = 0 }

-- emit children of `inst` into directory `dir`
local function emit(inst, dir)
	fs.writeDir(dir)
	local used = {}
	for _, child in inst:GetChildren() do
		if not hasScript(child) then continue end
		local base = sane(child.Name)
		if used[base] then base = base .. "_" .. tostring(used[base]); used[child.Name] = (used[child.Name] or 0) end
		used[child.Name] = (used[child.Name] or 0) + 1

		local cls = child.ClassName
		local kids = child:GetChildren()
		if SCRIPT[cls] then
			counts.scripts += 1
			if #kids > 0 and hasScript(child) and (function() for _,k in kids do if hasScript(k) then return true end end return false end)() then
				-- script WITH script-bearing children -> init pattern
				local sub = dir .. "/" .. base
				fs.writeDir(sub)
				fs.writeFile(sub .. "/init" .. ext(cls), child.Source or "")
				emit(child, sub)
			else
				fs.writeFile(dir .. "/" .. base .. ext(cls), child.Source or "")
			end
		else
			-- non-script container that holds scripts -> folder (preserve class if not Folder)
			counts.folders += 1
			local sub = dir .. "/" .. base
			fs.writeDir(sub)
			if cls ~= "Folder" then
				fs.writeFile(sub .. "/init.meta.json",
					('{\n\t"className": "%s"\n}\n'):format(cls))
			end
			emit(child, sub)
		end
	end
end

-- wipe + regenerate src
if fs.isDir(SRC) then fs.removeDir(SRC) end
fs.writeDir(OUT)
fs.writeDir(SRC)

local services = { "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer", "StarterGui", "ReplicatedFirst" }
local mapped = {}
for _, name in services do
	local ok, svc = pcall(function() return game:GetService(name) end)
	if ok and svc and hasScript(svc) then
		emit(svc, SRC .. "/" .. name)
		table.insert(mapped, name)
	end
end

print("scripts:", counts.scripts, "containers:", counts.folders)
print("mapped services:", table.concat(mapped, ", "))
