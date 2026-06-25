--!nonstrict
-- Network
-- init.luau
-- Plinko Labs
--
-- The messaging core -- the simpler replacement for Junky's Junction. There is NO
-- central routing table to declare: a channel is just a "Domain.Event" string, made on
-- the fly. Direction lives in the METHOD NAME, so you never wonder which way it goes:
--
--   CLIENT                              SERVER
--   Net:ToServer("Combat.Swing", hit)   Net:OnClient("Combat.Swing", function(plr, hit) end)
--   Net:OnServer("Combat.Hit", fn)      Net:ToClient(plr, "Combat.Hit", result)
--                                       Net:ToAll("Round.Begin", payload)
--   Net:Ask("Character.List")           Net:Answer("Character.List", function(plr) return list end)
--     :next(function(list) ... end)
--
--   -- same side, in-process (replaces the old "Local" namespace):
--   Net:Signal("Input.Pressed", "M1")   Net:OnSignal("Input.Pressed", function(a) end)
--
-- Require it and go -- it's side-aware (the client instance is your "NetworkController",
-- the server instance your "NetworkManager"); it wires its own RemoteEvent/Function.
-- Requests return Accede thenables (:next/:toss), consistent with the rest of the stack.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Accede = require(script.Parent.Accede)

local IS_SERVER = RunService:IsServer()
local EVENT_NAME = "NetworkEvent"
local FUNC_NAME = "NetworkFunction"

local Network = {}

-- channel -> { fn } for cross-context receivers; channel -> fn for responders;
-- channel -> { fn } for in-process signals.
local _wire = {} -- OnServer (client) / OnClient (server)
local _responders = {} -- Answer (server)
local _local = {} -- OnSignal (same side)

-- ===================================================================== infra =======

local remoteEvent: RemoteEvent
local remoteFunction: RemoteFunction

local function dispatch(channel: string, ...)
	local list = _wire[channel]
	if list then
		for _, fn in table.clone(list) do
			task.spawn(fn, ...)
		end
	end
end

if IS_SERVER then
	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = EVENT_NAME
	remoteEvent.Parent = ReplicatedStorage
	remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = FUNC_NAME
	remoteFunction.Parent = ReplicatedStorage

	-- inbound from a client: first arg is the channel, then the payload + the player.
	remoteEvent.OnServerEvent:Connect(function(player, channel, ...)
		dispatch(channel, player, ...)
	end)
	remoteFunction.OnServerInvoke = function(player, channel, ...)
		local responder = _responders[channel]
		if not responder then
			return nil
		end
		return responder(player, ...)
	end
else
	remoteEvent = ReplicatedStorage:WaitForChild(EVENT_NAME)
	remoteFunction = ReplicatedStorage:WaitForChild(FUNC_NAME)

	remoteEvent.OnClientEvent:Connect(function(channel, ...)
		dispatch(channel, ...)
	end)
end

-- ===================================================================== subscribe ====

local function connect(registry, channel: string, fn)
	registry[channel] = registry[channel] or {}
	table.insert(registry[channel], fn)
	return function()
		local list = registry[channel]
		if list then
			local i = table.find(list, fn)
			if i then
				table.remove(list, i)
			end
		end
	end
end

-- ===================================================================== cross-context

-- CLIENT -> server (fire & forget).
function Network:ToServer(channel: string, ...)
	assert(not IS_SERVER, "[Network] ToServer is client-only")
	remoteEvent:FireServer(channel, ...)
end

-- SERVER -> one client.
function Network:ToClient(player: Player, channel: string, ...)
	assert(IS_SERVER, "[Network] ToClient is server-only")
	remoteEvent:FireClient(player, channel, ...)
end

-- SERVER -> every client.
function Network:ToAll(channel: string, ...)
	assert(IS_SERVER, "[Network] ToAll is server-only")
	remoteEvent:FireAllClients(channel, ...)
end

-- SERVER -> every client except one.
function Network:ToAllExcept(except: Player, channel: string, ...)
	assert(IS_SERVER, "[Network] ToAllExcept is server-only")
	for _, player in Players:GetPlayers() do
		if player ~= except then
			remoteEvent:FireClient(player, channel, ...)
		end
	end
end

-- CLIENT: receive a message the server sent. fn(...).
function Network:OnServer(channel: string, fn): () -> ()
	assert(not IS_SERVER, "[Network] OnServer is client-only")
	return connect(_wire, channel, fn)
end

-- SERVER: receive a message a client sent. fn(player, ...).
function Network:OnClient(channel: string, fn): () -> ()
	assert(IS_SERVER, "[Network] OnClient is server-only")
	return connect(_wire, channel, fn)
end

-- ===================================================================== request =====

-- CLIENT asks the server and gets an Accede that resolves with the answer.
function Network:Ask(channel: string, ...)
	assert(not IS_SERVER, "[Network] Ask is client-only")
	local args = table.pack(...)
	return Accede.new(function(resolve, reject)
		task.spawn(function()
			local ok, result = pcall(function()
				return remoteFunction:InvokeServer(channel, table.unpack(args, 1, args.n))
			end)
			if ok then
				resolve(result)
			else
				reject(result, "AskError")
			end
		end)
	end)
end

-- SERVER answers an Ask. fn(player, ...) -> result. One responder per channel.
function Network:Answer(channel: string, fn)
	assert(IS_SERVER, "[Network] Answer is server-only")
	_responders[channel] = fn
	return function()
		if _responders[channel] == fn then
			_responders[channel] = nil
		end
	end
end

-- ===================================================================== local ========

-- Fire an in-process event on THIS side (replaces the old Local namespace).
function Network:Signal(channel: string, ...)
	local list = _local[channel]
	if list then
		for _, fn in table.clone(list) do
			task.spawn(fn, ...)
		end
	end
end

-- Subscribe to an in-process event on this side.
function Network:OnSignal(channel: string, fn): () -> ()
	return connect(_local, channel, fn)
end

Network.Side = IS_SERVER and "Server" or "Client"

return Network
