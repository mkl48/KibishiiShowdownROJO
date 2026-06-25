local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Utility = {}

function Utility.IsStudio()
	return RunService:IsStudio()
end

function Utility.ResolveUserId(plrOrId)
	if type(plrOrId) == "number" then
		return plrOrId
	elseif typeof(plrOrId) == "Instance" and plrOrId:IsA("Player") then
		return plrOrId.UserId
	end
	return nil
end

function Utility.ResolvePlayer(plrOrId)
	if typeof(plrOrId) == "Instance" and plrOrId:IsA("Player") then
		return plrOrId
	elseif type(plrOrId) == "number" then
		return Players:GetPlayerByUserId(plrOrId)
	end
	return nil
end

function Utility.GenerateSessionId(userId)
	return "usr_" .. userId .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

function Utility.DeepCopy(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for key, value in pairs(t) do
		copy[key] = Utility.DeepCopy(value)
	end
	return copy
end

function Utility.DeepMerge(target, patch)
	for key, value in pairs(patch) do
		if type(value) == "table" and type(target[key]) == "table" then
			Utility.DeepMerge(target[key], value)
		else
			target[key] = value
		end
	end
end

function Utility.Reconcile(data, schema)
	for key, default in pairs(schema) do
		if data[key] == nil then
			data[key] = Utility.DeepCopy(default)
		elseif type(default) == "table" and type(data[key]) == "table" then
			Utility.Reconcile(data[key], default)
		end
	end
end

function Utility.GetPath(t, path)
	if type(path) ~= "string" then return t[path] end

	local current = t
	for segment in path:gmatch("[^.]+") do
		if type(current) ~= "table" then return nil end
		current = current[segment]
	end
	return current
end

function Utility.SetPath(t, path, value)
	if type(path) ~= "string" then
		t[path] = value
		return
	end

	local segments = {}
	for segment in path:gmatch("[^.]+") do
		table.insert(segments, segment)
	end

	local current = t
	for i = 1, #segments - 1 do
		local seg = segments[i]
		if type(current[seg]) ~= "table" then
			current[seg] = {}
		end
		current = current[seg]
	end

	current[segments[#segments]] = value
end

local _typeTag = "__roblox_type"

local _serializers = {
	Vector3 = {
		serialize = function(v)
			return { [_typeTag] = "Vector3", x = v.X, y = v.Y, z = v.Z }
		end,
		deserialize = function(t)
			return Vector3.new(t.x, t.y, t.z)
		end,
	},
	Vector2 = {
		serialize = function(v)
			return { [_typeTag] = "Vector2", x = v.X, y = v.Y }
		end,
		deserialize = function(t)
			return Vector2.new(t.x, t.y)
		end,
	},
	CFrame = {
		serialize = function(cf)
			local c = { cf:GetComponents() }
			return { [_typeTag] = "CFrame", c = c }
		end,
		deserialize = function(t)
			return CFrame.new(table.unpack(t.c))
		end,
	},
	Color3 = {
		serialize = function(c)
			return { [_typeTag] = "Color3", r = c.R, g = c.G, b = c.B }
		end,
		deserialize = function(t)
			return Color3.new(t.r, t.g, t.b)
		end,
	},
	EnumItem = {
		serialize = function(e)
			return { [_typeTag] = "EnumItem", enum = tostring(e.EnumType), value = e.Name }
		end,
		deserialize = function(t)
			return Enum[t.enum][t.value]
		end,
	},
	UDim2 = {
		serialize = function(u)
			return { [_typeTag] = "UDim2", xs = u.X.Scale, xo = u.X.Offset, ys = u.Y.Scale, yo = u.Y.Offset }
		end,
		deserialize = function(t)
			return UDim2.new(t.xs, t.xo, t.ys, t.yo)
		end,
	},
	UDim = {
		serialize = function(u)
			return { [_typeTag] = "UDim", s = u.Scale, o = u.Offset }
		end,
		deserialize = function(t)
			return UDim.new(t.s, t.o)
		end,
	},
}

function Utility.Serialize(value)
	local t = typeof(value)

	if _serializers[t] then
		return _serializers[t].serialize(value)
	end

	if type(value) == "table" then
		local result = {}
		for k, v in pairs(value) do
			result[k] = Utility.Serialize(v)
		end
		return result
	end

	return value
end

function Utility.Deserialize(value)
	if type(value) == "table" then
		local tag = value[_typeTag]
		if tag and _serializers[tag] then
			return _serializers[tag].deserialize(value)
		end

		local result = {}
		for k, v in pairs(value) do
			result[k] = Utility.Deserialize(v)
		end
		return result
	end

	return value
end

function Utility.SerializeData(data)
	return Utility.Serialize(data)
end

function Utility.DeserializeData(data)
	return Utility.Deserialize(data)
end

function Utility.Log(level, config, ...)
	if config.LogLevel == "None" then return end
	if level == "Verbose" and config.LogLevel ~= "Verbose" then return end
	if level == "Warn" then
		warn("[Keep]", ...)
	else
		print("[Keep]", ...)
	end
end

function Utility.AssertType(value, expected, label)
	assert(type(value) == expected, string.format("[Keep] %s expected %s, got %s", label, expected, type(value)))
end

function Utility.SafeCall(fn, ...)
	local ok, result = pcall(fn, ...)
	if not ok then
		warn("[Keep] SafeCall error:", result)
		return nil, result
	end
	return result, nil
end

function Utility.TableLength(t)
	local count = 0
	for _ in pairs(t) do
		count += 1
	end
	return count
end

function Utility.Keys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	return keys
end

function Utility.Values(t)
	local values = {}
	for _, v in pairs(t) do
		table.insert(values, v)
	end
	return values
end

function Utility.Filter(t, fn)
	local result = {}
	for k, v in pairs(t) do
		if fn(v, k) then
			result[k] = v
		end
	end
	return result
end

function Utility.Map(t, fn)
	local result = {}
	for k, v in pairs(t) do
		result[k] = fn(v, k)
	end
	return result
end

return Utility