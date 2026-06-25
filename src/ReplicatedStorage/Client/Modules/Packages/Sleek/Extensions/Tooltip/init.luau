local TweenService = game:GetService("TweenService")
local Extensions   = script.Parent
local Features     = Extensions.Parent.Features
local Types        = require(Features.Types)
local Call = require(script.Call)

local Tooltip = {}

local OverlaySleek = nil

Tooltip.DefaultOptions = {
	Name   = "Tooltip",
	Target = nil :: string?, 
	Text   = "",
	Offset = UDim2.fromOffset(0, -8), 
}

function Tooltip.new(Sleek, properties: Types.TooltipProperties)
	local props = setmetatable(properties or {}, { __index = Tooltip.DefaultOptions })

	if not OverlaySleek then
		local SleekModule = Call.Call(Features.Parent)

		OverlaySleek = SleekModule.new(Sleek.theme) 

		OverlaySleek:modifyApp({
			Size                 = UDim2.fromScale(1, 1),
			Position             = UDim2.fromOffset(0, 0),
			AnchorPoint          = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			ClipsDescendants     = false,
			ZIndex               = 100,
		})

		local overlayPanel = OverlaySleek.panel
		overlayPanel.Name = "Sleek_Tooltip_Overlay"

		if overlayPanel:FindFirstChildOfClass("UIPadding") then overlayPanel:FindFirstChildOfClass("UIPadding"):Destroy() end
		if overlayPanel:FindFirstChildOfClass("UIStroke")  then overlayPanel:FindFirstChildOfClass("UIStroke"):Destroy() end
		if overlayPanel:FindFirstChildOfClass("UICorner")  then overlayPanel:FindFirstChildOfClass("UICorner"):Destroy() end
	end

	local name    = props.Name
	local bgName  = name .. "_Bg"
	local txtName = name .. "_Text"

	local C = Sleek.theme.Colors
	local R = Sleek.theme.Roundness

	OverlaySleek:addCanvasGroup(bgName, {
		Visible           = false,
		AutomaticSize     = Enum.AutomaticSize.XY,
		BackgroundColor3  = C.Surface.Overlay,
		GroupTransparency = 1,
		ZIndex            = 100,
	})

	OverlaySleek:into(bgName)
	OverlaySleek:addCorner(bgName .. "_Corner", R.CornerRoundness)
	OverlaySleek:addPadding(bgName .. "_Pad", UDim.new(0, 10), UDim.new(0, 6))
	OverlaySleek:addLabel(txtName, {
		Text          = props.Text,
		TextColor3    = C.Text.Primary,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size          = UDim2.fromOffset(0, 0),
	})
	OverlaySleek:back()

	local bgEl = OverlaySleek:getElement(bgName)

	if props.Target then
		local targetEl = Sleek:getElement(props.Target)
		local GuiService = game:GetService("GuiService")

		if targetEl and bgEl then
			local ti = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			targetEl.Instance.MouseEnter:Connect(function()
				local inset, _ = GuiService:GetGuiInset()

				local targetPos = targetEl.Instance.AbsolutePosition
				local targetSz  = targetEl.Instance.AbsoluteSize

				local centerX = targetPos.X + (targetSz.X / 2)
				local topY = targetPos.Y + props.Offset.Y.Offset

				bgEl.Instance.AnchorPoint = Vector2.new(0.5, 1)

				bgEl.Instance.Position = UDim2.fromOffset(centerX, topY + inset.Y)

				bgEl.Instance.Visible = true
				TweenService:Create(bgEl.Instance, ti, { GroupTransparency = 0 }):Play()
			end)

			targetEl.Instance.MouseLeave:Connect(function()
				local t = TweenService:Create(bgEl.Instance, ti, { GroupTransparency = 1 })
				t:Play()
				t.Completed:Once(function()
					bgEl.Instance.Visible = false
				end)
			end)
		end
	end

	return bgEl
end

return Tooltip