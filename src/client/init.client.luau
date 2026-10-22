-- HUD: barras de vida/fome/sede, timer da raid, extração, stash/loadout e mochila.
-- Tecla B mostra/esconde o painel.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UI = require(script:WaitForChild("UI"))

local player = Players.LocalPlayer

local GREEN = Color3.fromRGB(60, 150, 80)
local RED = Color3.fromRGB(170, 60, 60)
local GRAY = Color3.fromRGB(70, 70, 75)
local BLUE = Color3.fromRGB(60, 110, 180)

local snapshot: any = nil
local lastRenderKey = ""
local loadout: { [string]: number } = {}

local gui = UI.new("ScreenGui", { Name = "ExtractionHUD", ResetOnSpawn = false }, nil, player:WaitForChild("PlayerGui"))

-- Barras de status (canto superior esquerdo)
local bars = UI.new("Frame", {
	Size = UDim2.fromOffset(240, 80),
	Position = UDim2.fromOffset(16, 60),
	BackgroundTransparency = 1,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 5) }) }, gui)
local setHealth = UI.bar(bars, "Vida", Color3.fromRGB(200, 60, 60))
local setHunger = UI.bar(bars, "Fome", Color3.fromRGB(215, 150, 50))
local setThirst = UI.bar(bars, "Sede", Color3.fromRGB(60, 140, 215))

-- Timer e extração (topo central)
local timerLabel = UI.label("", {
	Size = UDim2.fromOffset(200, 36),
	Position = UDim2.new(0.5, -100, 0, 8),
	Font = UI.FontBold,
	TextSize = 28,
	TextStrokeTransparency = 0.4,
	Visible = false,
})
timerLabel.Parent = gui

local extractFrame = UI.new("Frame", {
	Size = UDim2.fromOffset(320, 30),
	Position = UDim2.new(0.5, -160, 0, 50),
	BackgroundColor3 = Color3.fromRGB(20, 20, 20),
	BackgroundTransparency = 0.3,
	Visible = false,
}, { UI.corner(6) }, gui)
local extractFill = UI.new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(70, 200, 110),
	BorderSizePixel = 0,
}, { UI.corner(6) }, extractFrame)
local extractText = UI.label("", { Size = UDim2.fromScale(1, 1), Font = UI.FontBold, ZIndex = 2 })
extractText.Parent = extractFrame

-- Painel lateral (stash/loadout no lobby, mochila na raid)
local panel = UI.new("Frame", {
	Size = UDim2.new(0, 330, 0.62, 0),
	Position = UDim2.new(1, -346, 0.18, 0),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	BackgroundTransparency = 0.12,
}, {
	UI.corner(8),
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}),
}, gui)
local title = UI.label("Carregando...", {
	Size = UDim2.new(1, 0, 0, 28),
	Font = UI.FontBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
})
title.Parent = panel
local list = UI.new("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -122),
	Position = UDim2.fromOffset(0, 32),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) }, panel)
local footer = UI.label("", {
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.new(0, 0, 1, -86),
	TextSize = 13,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(180, 180, 180),
})
footer.Parent = panel
local deployButton = UI.button("ENTRAR NA RAID", GREEN, function()
	Remotes.Deploy:FireServer(loadout)
end)
deployButton.Size = UDim2.new(1, 0, 0, 40)
deployButton.Position = UDim2.new(0, 0, 1, -40)
deployButton.TextSize = 18
deployButton.Visible = false -- aparece quando os dados do jogador chegarem
deployButton.Parent = panel

-- Notificações (baixo central)
local toasts = UI.new("Frame", {
	Size = UDim2.new(0, 460, 0, 200),
	Position = UDim2.new(0.5, -230, 1, -260),
	BackgroundTransparency = 1,
}, {
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
}, gui)

local TOAST_COLORS = {
	info = Color3.fromRGB(40, 40, 48),
	success = Color3.fromRGB(35, 110, 60),
	error = Color3.fromRGB(130, 40, 40),
	loot = Color3.fromRGB(90, 75, 35),
}

local function toast(text: string, kind: string)
	local label = UI.label(text, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.15,
		BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info,
		TextWrapped = true,
		TextSize = 15,
	})
	UI.new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, nil, label)
	UI.corner(6).Parent = label
	label.Parent = toasts
	task.delay(4, function()
		label:Destroy()
	end)
end

-- Lista ------------------------------------------------------------------

local rowOrder = 0

local function clearList()
	rowOrder = 0
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function addHeader(text: string)
	rowOrder += 1
	local header = UI.label(text, {
		Size = UDim2.new(1, -6, 0, 22),
		Font = UI.FontBold,
		TextColor3 = Color3.fromRGB(160, 160, 170),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = rowOrder,
	})
	header.Parent = list
end

local function addRow(text: string, color: Color3, buttons: { { any } })
	rowOrder += 1
	local row = UI.new("Frame", {
		Size = UDim2.new(1, -6, 0, 30),
		BackgroundColor3 = Color3.fromRGB(38, 38, 44),
		LayoutOrder = rowOrder,
	}, { UI.corner(4) }, list)
	local label = UI.label(text, {
		Size = UDim2.new(1, -(#buttons * 62 + 12), 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	label.Parent = row
	for i, spec in buttons do
		local button = UI.button(spec[1], spec[2], spec[3])
		button.Size = UDim2.fromOffset(58, 24)
		button.Position = UDim2.new(1, -i * 62, 0.5, -12)
		button.Parent = row
	end
end

local function sortedIds(bag: { [string]: number }): { string }
	local ids = {}
	for id in bag do
		if Items.Get(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return (Items.Get(a) :: any).name < (Items.Get(b) :: any).name
	end)
	return ids
end

local render

local function changeLoadout(id: string, delta: number)
	local profile = snapshot and snapshot.profile
	if not profile then
		return
	end
	local item = Items.Get(id) :: any
	local new = (loadout[id] or 0) + delta
	if new > (profile.stash[id] or 0) then
		return
	end
	if delta > 0 and Items.TotalSize(loadout) + item.size > Config.MAX_LOADOUT_SIZE then
		toast("Loadout cheio.", "error")
		return
	end
	loadout[id] = if new > 0 then new else nil
	render(true)
end

local function renderRaid()
	local raid = snapshot.raid
	title.Text = "Mochila"
	deployButton.Visible = false
	if not raid then
		return
	end
	for _, id in sortedIds(raid.items) do
		local item = Items.Get(id) :: any
		local buttons = {}
		if item.use then
			table.insert(buttons, { "Usar", GREEN, function()
				Remotes.UseItem:FireServer(id)
			end })
		end
		addRow(`{item.name} x{raid.items[id]}`, Items.RarityColors[item.rarity], buttons)
	end
	footer.Text = `Espaço: {raid.used}/{raid.capacity}  •  valor ${Items.TotalValue(raid.items)}`
end

local function renderLobby()
	local profile = snapshot.profile
	deployButton.Visible = profile ~= nil
	if not profile then
		title.Text = "Carregando dados..."
		return
	end
	title.Text = `Stash  •  ${profile.money}`

	addHeader(`Loadout ({Items.TotalSize(loadout)}/{Config.MAX_LOADOUT_SIZE})`)
	for _, id in sortedIds(loadout) do
		local item = Items.Get(id) :: any
		addRow(`{item.name} x{loadout[id]}`, Items.RarityColors[item.rarity], {
			{ "Tirar", GRAY, function()
				changeLoadout(id, -1)
			end },
		})
	end

	addHeader("Stash")
	for _, id in sortedIds(profile.stash) do
		local item = Items.Get(id) :: any
		local available = profile.stash[id] - (loadout[id] or 0)
		if available > 0 then
			addRow(`{item.name} x{available}  (${item.value})`, Items.RarityColors[item.rarity], {
				{ "Vender", RED, function()
					Remotes.SellItem:FireServer(id, 1)
				end },
				{ "Levar", BLUE, function()
					changeLoadout(id, 1)
				end },
			})
		end
	end

	local stats = profile.stats
	footer.Text = `Stash: {profile.stashUsed}/{profile.stashCapacity}\n`
		.. `Raids {stats.raids}  •  Extrações {stats.extracts}  •  Mortes {stats.deaths}`
end

function render(force: boolean?)
	if not snapshot then
		return
	end
	-- Só reconstrói a lista quando algo relevante mudou (a fome muda todo segundo)
	local key = HttpService:JSONEncode({
		profile = snapshot.profile,
		raid = snapshot.raid,
		phase = snapshot.match and snapshot.match.phase,
	})
	if key == lastRenderKey and not force then
		return
	end
	lastRenderKey = key
	clearList()
	if snapshot.match and snapshot.match.phase == "InRaid" then
		renderRaid()
	else
		renderLobby()
	end
end

-- Eventos do servidor -----------------------------------------------------

Remotes.Sync.OnClientEvent:Connect(function(newSnapshot)
	local wasInRaid = snapshot and snapshot.match and snapshot.match.phase == "InRaid"
	snapshot = newSnapshot
	local inRaid = snapshot.match and snapshot.match.phase == "InRaid"
	if inRaid and not wasInRaid then
		loadout = {}
	end
	-- remove do loadout o que não existe mais no stash
	local stash = snapshot.profile and snapshot.profile.stash or {}
	for id, count in loadout do
		local have = stash[id] or 0
		loadout[id] = if have > 0 then math.min(count, have) else nil
	end
	render()
end)

Remotes.Notify.OnClientEvent:Connect(toast)

Remotes.ExtractProgress.OnClientEvent:Connect(function(ratio, zoneName, lockedFor)
	if ratio == nil then
		extractFrame.Visible = false
		return
	end
	extractFrame.Visible = true
	extractFill.Size = UDim2.fromScale(ratio, 1)
	if lockedFor then
		extractText.Text = `{zoneName} abre em {lockedFor}s`
	else
		extractText.Text = `Extraindo em {zoneName}... {math.floor(ratio * 100)}%`
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.B then
		panel.Visible = not panel.Visible
	end
end)

RunService.RenderStepped:Connect(function()
	local match = snapshot and snapshot.match
	local inRaid = match and match.phase == "InRaid"
	bars.Visible = inRaid == true
	timerLabel.Visible = inRaid == true
	if not inRaid then
		return
	end

	local remaining = math.max(0, math.floor(match.endsAt - Workspace:GetServerTimeNow()))
	timerLabel.Text = string.format("%02d:%02d", remaining // 60, remaining % 60)
	timerLabel.TextColor3 = if remaining < 60 then Color3.fromRGB(255, 90, 90) else UI.White

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		setHealth(humanoid.Health / humanoid.MaxHealth, tostring(math.ceil(humanoid.Health)))
	end
	local survival = snapshot.survival
	if survival then
		setHunger(survival.hunger / survival.maxHunger, tostring(math.ceil(survival.hunger)))
		setThirst(survival.thirst / survival.maxThirst, tostring(math.ceil(survival.thirst)))
	end
end)

Remotes.RequestSync:FireServer()
