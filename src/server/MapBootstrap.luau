-- Se o place não tiver Workspace.Map, gera um mapa de teste para dar Play direto no Studio.
-- Estrutura esperada de um mapa real:
--   Workspace.Map.RaidSpawns    (Parts onde o jogador aparece ao entrar na raid)
--   Workspace.Map.LootSpawns    (Parts com atributo LootTable)
--   Workspace.Map.ExtractZones  (Parts com atributos DisplayName e OpensAfter)
-- O lobby é qualquer SpawnLocation fora da raid.
local Workspace = game:GetService("Workspace")

local MapBootstrap = {}

local RAID_ORIGIN = Vector3.new(0, 0, 3000)
local RAID_SIZE = 500

local function makePart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

function MapBootstrap.Ensure()
	if Workspace:FindFirstChild("Map") then
		return
	end
	warn("[MapBootstrap] Workspace.Map não encontrado: gerando mapa de teste.")

	local rng = Random.new(42)
	local map = Instance.new("Folder")
	map.Name = "Map"
	local function folder(name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = map
		return f
	end
	local geometry = folder("Geometry")
	local raidSpawns = folder("RaidSpawns")
	local lootSpawns = folder("LootSpawns")
	local extractZones = folder("ExtractZones")

	-- Lobby (só se o place não tiver nenhum SpawnLocation)
	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		makePart(geometry, {
			Name = "LobbyFloor",
			Size = Vector3.new(80, 2, 80),
			Position = Vector3.new(0, -1, 0),
			Material = Enum.Material.Concrete,
		})
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = Vector3.new(0, 0.5, 0)
		spawn.Parent = geometry
	end

	-- Chão e muros da raid
	local half = RAID_SIZE / 2
	makePart(geometry, {
		Name = "RaidGround",
		Size = Vector3.new(RAID_SIZE, 4, RAID_SIZE),
		Position = RAID_ORIGIN - Vector3.new(0, 2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(85, 105, 65),
	})
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		makePart(geometry, {
			Name = "Wall",
			Size = if dir.X ~= 0 then Vector3.new(4, 40, RAID_SIZE) else Vector3.new(RAID_SIZE, 40, 4),
			Position = RAID_ORIGIN + dir * half + Vector3.new(0, 20, 0),
			Material = Enum.Material.Concrete,
			Transparency = 0.5,
		})
	end

	-- Prédios (blocos), evitando o centro onde fica o heliponto
	local buildings = {}
	local function overlapsBuilding(offset: Vector3, margin: number): boolean
		for _, b in buildings do
			if math.abs(offset.X - b.X) < b.W / 2 + margin and math.abs(offset.Z - b.Z) < b.D / 2 + margin then
				return true
			end
		end
		return false
	end
	for _ = 1, 22 do
		local w, h, d = rng:NextInteger(14, 34), rng:NextInteger(10, 45), rng:NextInteger(14, 34)
		-- prédios ficam longe da borda, onde estão spawns e extrações
		local x, z = rng:NextNumber(-half + 60, half - 60), rng:NextNumber(-half + 60, half - 60)
		if Vector2.new(x, z).Magnitude > 50 then
			table.insert(buildings, { X = x, Z = z, W = w, D = d })
			makePart(geometry, {
				Name = "Building",
				Size = Vector3.new(w, h, d),
				Position = RAID_ORIGIN + Vector3.new(x, h / 2, z),
				Material = Enum.Material.Concrete,
				Color = Color3.fromRGB(rng:NextInteger(90, 130), rng:NextInteger(90, 120), rng:NextInteger(85, 110)),
			})
		end
	end

	local function freeSpot(margin: number): Vector3
		for _ = 1, 50 do
			local offset = Vector3.new(rng:NextNumber(-half + 15, half - 15), 0, rng:NextNumber(-half + 15, half - 15))
			if not overlapsBuilding(offset, margin) then
				return offset
			end
		end
		return Vector3.zero
	end

	-- Loot: militar é mais comum perto do centro
	for _ = 1, 32 do
		local offset = freeSpot(4)
		local military = offset.Magnitude < 130 and rng:NextNumber() < 0.5
		local spawn = makePart(lootSpawns, {
			Name = "LootSpawn",
			Size = Vector3.one,
			Position = RAID_ORIGIN + offset + Vector3.new(0, 1.25, 0),
			Transparency = 1,
			CanCollide = false,
		})
		spawn:SetAttribute("LootTable", if military then "military" else "common")
	end

	-- Spawns da raid em volta da borda
	local edge = half - 15
	local spawnOffsets = {
		Vector3.new(-120, 0, edge), Vector3.new(120, 0, edge),
		Vector3.new(-edge, 0, -120), Vector3.new(-edge, 0, 120),
		Vector3.new(edge, 0, -120), Vector3.new(edge, 0, -40),
		Vector3.new(-160, 0, -edge), Vector3.new(160, 0, -edge),
	}
	for _, offset in spawnOffsets do
		makePart(raidSpawns, {
			Name = "RaidSpawn",
			Size = Vector3.new(4, 1, 4),
			Position = RAID_ORIGIN + offset + Vector3.new(0, 0.5, 0),
			Transparency = 1,
			CanCollide = false,
		})
	end

	-- Extrações
	local extracts = {
		{ name = "Ponte Norte", offset = Vector3.new(0, 0, -half + 20), opensAfter = 0 },
		{ name = "Túnel Leste", offset = Vector3.new(half - 20, 0, 60), opensAfter = 0 },
		{ name = "Heliponto", offset = Vector3.zero, opensAfter = 300 },
	}
	for _, info in extracts do
		local zone = makePart(extractZones, {
			Name = "Extract",
			Size = Vector3.new(24, 12, 24),
			Position = RAID_ORIGIN + info.offset + Vector3.new(0, 6, 0),
			Material = Enum.Material.ForceField,
			Color = Color3.fromRGB(80, 255, 120),
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
		})
		zone:SetAttribute("DisplayName", info.name)
		zone:SetAttribute("OpensAfter", info.opensAfter)

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(200, 40)
		billboard.StudsOffset = Vector3.new(0, 10, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 300
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "⬆ EXTRAÇÃO: " .. info.name
		label.TextColor3 = Color3.fromRGB(120, 255, 150)
		label.TextStrokeTransparency = 0.3
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = billboard
		billboard.Parent = zone
	end

	map.Parent = Workspace
end

return MapBootstrap
