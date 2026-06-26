-- Kibishii Showdown
-- client/Modules/Controllers/InputController.luau
--
-- Raw input -> intent. It owns no combat logic; it translates device input into
-- same-side Network signals (M1 -> Ability.Input drives the moveset; Block ->
-- Input.Pressed flows to the combat spine). Centralizing input means rebinding never
-- touches combat code. (Migrate the keys to the Memory keybinds cache when ready.)

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)

local InputController = {}

function InputController:Start(_context)
	UserInputService.InputBegan:Connect(function(io, gameProcessed)
		if gameProcessed then
			return
		end
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			Net:Signal("Ability.Input", "M1")
		elseif io.KeyCode == Enum.KeyCode.F then
			Net:Signal("Input.Pressed", "Block:Down")
		end
	end)

	UserInputService.InputEnded:Connect(function(io)
		if io.KeyCode == Enum.KeyCode.F then
			Net:Signal("Input.Pressed", "Block:Up")
		end
	end)
end

return InputController
