--[[ Welcome To Schema

	-- Table of Contents --
	
	# 1. Overview
	# 2. Types
	# 3. Usage
	# 4. Contact

	-- 1. Overview --
	
	Schema is a network library that is designed to make networking as easy and simple as possible.
	Schema is designed to keep at least a minimal level of security in any game that uses it.
	Schema uses a simple handshake, token and key system to ensure that only your client and server can communicate with each other.
	Schema is also strictly typed in the context of that any data that is sent over the network is checked agaisnt its paramter definitions to make sure it is the correct type.
	
	-- 2. Types --
	
		1. Controls
			Controls are Data Structures That Describe Definitions. Definitions are Events in a sense that they are the interface.
			
	-- 3. Usage --
	
		1. Basics
			To create a new control, you must first require the Schema module.
			
			local Schema = require(path.to.Schema) -- This will require the module
			
			To create a definition first you must define it.
			
			Schema.define("Example", {}, {})
			
			^ The first argument is the name of the definition.
			^ The second argument are the paramters of definition. -- Tip. You can use "!" to allow the paramter to be possibly nil -- its is the equivelant to doing [type test = {
			testParameter : string?}]
			^ The third argument are the modifictions/options. -- For exmaple you can do [
				Schema.define("Example", {string = "string!"}, {mode = "invoke"}) -- mode is the modifiction.
				-- There are 3 different possible modifications.
				-- 1. "invoke" -- it will make the control behave as a remote function.
				-- 2. "reliable" -- it will make the control behave as a reliable remote event.
				-- 3. "unreliable" -- it will make the control behave as an unreliable remote event."
			]
			
			To fire a basic control you must call Schema.post(name, {...} -- the data)
			-- for example [
				Schema.post("Example", {message = "Hello World!"})
			]
			
			-- IMPORTANT --
			
			if your modification is "invoke" and you want to get the return data, you must call .next() on the control.
			-- for example [
				Schema.post("Example", {message = "Hello World!"}).next(function(data)
					print(data)
				end)
			]
			
			To listen for a control you must use Schema.subscribe(name, function(plr, data)
			-- for example [
				
				Schema.subscribe("Example", function(plr, data)
					print(data.message)
				end)
			]
			
			-- IMPORTANT --
			
			if your modification is "invoke" and you want to return data, you must return the data from the function using data.remit()
			-- for example [
				
				Schema.subscribe("Example", function(plr, data)
					local request = data.request
					if request == "Hello" then
						return data.remit("World")
					end
				end)
			]
			
	-- 4. Contact --
	
	You can contact me at the following [
		Roblox = Kr3ativeKrayon
		Github = TheRealKr3ative
		Youtube = TotallyKr3ative
		Email = TheRealKr3ative@gmail.com
		Discord = @TheRealKr3ative / @TotallyNotKr3ative
	]
	
	Feel free to add any suggestions or bug reports.
	
	
	
	-- 5. Full Example --
	
		-- Server --
		
		Schema.define("EUNR", {string = "string!"}, {mode = "unreliable"})
		Schema.define("EREL", {string = "string!"}, {mode = "reliable"})
		Schema.define("EINV", {string = "string!"}, {mode = "invoke"})
		
		Schema.subscribe("EUNR", function(plr, data)
			print("EUNR: ", data.string)
		end)
		
		Schema.subscribe("EREL", function(plr, data)
			print("EREL: ", data.string)
		end)
		
		Schema.subscribe("EINV", function(plr, data)
			print("EINV: ", data.request)
			return data.remit(data.request.."!")
		end)
		
		-- Client --
		
		Schema.define("EUNR", {string = "string!"}, {mode = "unreliable"})
		Schema.define("EREL", {string = "string!"}, {mode = "reliable"})
		Schema.define("EINV", {string = "string!"}, {mode = "invoke"})
		
		Schema.post("EUNR", {string = "Hello World!"})
		Schema.post("EREL", {string = "Hello World!"})
		Schema.post("EINV", {string = "Hello World!"}).next(function(data)
			warn("EINV: ", data)
		end)
		
]]--