-- Caixas de loot (em Workspace.Map.LootSpawns) e corpos de jogadores mortos.
-- Coloque Parts em LootSpawns com o atributo LootTable = "common" | "military".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local SyncService = require(script.Parent.SyncService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local LootTables = require(script.Parent.Parent.LootTables)

local LootService = {}

local rng = Random.new()
local containers: { [BasePart]: { [string]: number } } = {}
local lootFolder: Folder

type ContainerOptions = {
	name: string,
	label: string,
	color: Color3,
	size: Vector3,
	hold: number,
	onEmpty: (() -> ())?,
}

local function rollTable(tableName: string): { [string]: number }
	local def = LootTables[tableName] or LootTables.common
	local totalWeight = 0
	for _, entry in def.entries do
		totalWeight += entry.weight
	end
	local result = {}
	for _ = 1, rng:NextInteger(def.rolls[1], def.rolls[2]) do
		local pick = rng:NextNumber() * totalWeight
		for _, entry in def.entries do
			pick -= entry.weight
			if pick <= 0 then
				result[entry.id] = (result[entry.id] or 0) + rng:NextInteger(entry.count[1], entry.count[2])
				break
			end
		end
	end
	return result
end

local function lootContainer(player: Player, part: BasePart, onEmpty: (() -> ())?)
	local contents = containers[part]
	if not contents or not MatchService.IsInRaid(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - part.Position).Magnitude > Config.LOOT_PICKUP_DISTANCE then
		return
	end

	local taken, full = {}, false
	for id, count in contents do
		local added = InventoryService.Add(player, id, count)
		if added > 0 then
			table.insert(taken, `{added}x {(Items.Get(id) :: any).name}`)
		end
		local left = count - added
		contents[id] = if left > 0 then left else nil
		if left > 0 then
			full = true
		end
	end

	if #taken > 0 then
		SyncService.Notify(player, "Pegou: " .. table.concat(taken, ", "), "loot")
	end
	if full then
		SyncService.Notify(player, "Mochila cheia! Sobrou coisa na caixa.", "error")
	end
	if next(contents) == nil then
		containers[part] = nil
		part:Destroy()
		if onEmpty then
			onEmpty()
		end
	end
end

local function createContainer(cframe: CFrame, contents: { [string]: number }, options: ContainerOptions): BasePart
	local part = Instance.new("Part")
	part.Name = options.name
	part.Size = options.size
	part.Color = options.color
	part.Material = Enum.Material.WoodPlanks
	part.Anchored = true
	part.CFrame = cframe

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Saquear"
	prompt.ObjectText = options.label
	prompt.HoldDuration = options.hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		lootContainer(player, part, options.onEmpty)
	end)

	containers[part] = contents
	part.Parent = lootFolder
	return part
end

local function spawnCrate(spawnPart: BasePart)
	if not spawnPart.Parent then
		return
	end
	local tableName = spawnPart:GetAttribute("LootTable") or "common"
	local def = LootTables[tableName] or LootTables.common
	createContainer(spawnPart.CFrame, rollTable(tableName), {
		name = "LootCrate",
		label = def.label,
		color = def.color,
		size = Vector3.new(4, 2.5, 3),
		hold = 1.5,
		onEmpty = function()
			task.delay(Config.LOOT_RESPAWN_TIME, spawnCrate, spawnPart)
		end,
	})
end

local function spawnBody(player: Player, bag: { [string]: number }, position: Vector3)
	local body = createContainer(CFrame.new(position - Vector3.new(0, 2, 0)), bag, {
		name = "Body",
		label = `Corpo de {player.DisplayName}`,
		color = Color3.fromRGB(60, 50, 50),
		size = Vector3.new(3, 1, 5),
		hold = 2,
	})
	task.delay(Config.BODY_DESPAWN_TIME, function()
		containers[body] = nil
		body:Destroy()
	end)
end

function LootService.Init()
	lootFolder = Instance.new("Folder")
	lootFolder.Name = "Loot"
	lootFolder.Parent = Workspace

	MatchService.RaidEnded:Connect(function(player, reason, bag, position)
		if reason ~= "extracted" and position and next(bag) ~= nil then
			spawnBody(player, bag, position)
		end
	end)
end

function LootService.Start()
	local spawns = Workspace:WaitForChild("Map"):WaitForChild("LootSpawns")
	for _, spawnPart in spawns:GetChildren() do
		if spawnPart:IsA("BasePart") then
			spawnPart.Transparency = 1
			spawnPart.CanCollide = false
			spawnCrate(spawnPart)
		end
	end
end

return LootService
