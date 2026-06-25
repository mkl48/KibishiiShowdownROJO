-- Kibishii Showdown
-- client/Modules/Controllers/InputController.luau
--
-- Raw input -> intent. It owns no combat logic; it just translates device input
-- into Local "Input.Pressed" intents (M1, Block, later Skill1..4 / Dash). The
-- Junction routes those to CombatController. Keeping input in one place means
-- rebinding never touches combat code.

local UserInputService = game:GetService("UserInputService")

local InputController = {}

function InputController:Start(context)
	local Input = context:Local("Input")

	UserInputService.InputBegan:Connect(function(io, gameProcessed)
		if gameProcessed then
			return
		end
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			Input:Post("Pressed", "M1")
		elseif io.KeyCode == Enum.KeyCode.F then
			Input:Post("Pressed", "Block:Down")
		end
	end)

	UserInputService.InputEnded:Connect(function(io)
		if io.KeyCode == Enum.KeyCode.F then
			Input:Post("Pressed", "Block:Up")
		end
	end)
end

return InputController
