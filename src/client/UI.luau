-- Helpers pequenos para montar interface por código.
local UI = {}

UI.Font = Enum.Font.GothamMedium
UI.FontBold = Enum.Font.GothamBold
UI.White = Color3.fromRGB(240, 240, 240)

function UI.new(className: string, props: { [string]: any }?, children: { Instance }?, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		(instance :: any)[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

function UI.label(text: string, props: { [string]: any }?): TextLabel
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = UI.White,
		Font = UI.Font,
		TextSize = 14,
	})
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

function UI.button(text: string, color: Color3, onClick: () -> ()): TextButton
	local button = UI.new("TextButton", {
		Text = text,
		BackgroundColor3 = color,
		TextColor3 = UI.White,
		Font = UI.FontBold,
		TextSize = 13,
		AutoButtonColor = true,
	}, { UI.corner(4) })
	button.Activated:Connect(onClick)
	return button
end

-- Barra de status; retorna uma função set(ratio, texto)
function UI.bar(parent: Instance, label: string, color: Color3): (number, string) -> ()
	local frame = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.3,
	}, { UI.corner(4) }, parent)
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, { UI.corner(4) }, frame)
	local text = UI.label(label, { Size = UDim2.fromScale(1, 1), Font = UI.FontBold, ZIndex = 2 })
	text.Parent = frame

	return function(ratio: number, value: string)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		text.Text = `{label}: {value}`
	end
end

return UI
