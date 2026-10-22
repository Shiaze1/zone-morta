-- Zonas de extração (Parts em Workspace.Map.ExtractZones).
-- Atributos opcionais: DisplayName (string), OpensAfter (segundos desde o início da raid).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MatchService = require(script.Parent.MatchService)

local ExtractionService = {}

local TICK = 0.2
local progress: { [Player]: number } = {}

local function isInside(part: BasePart, position: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function findZone(zones: { Instance }, position: Vector3): BasePart?
	for _, zone in zones do
		if zone:IsA("BasePart") and isInside(zone, position) then
			return zone
		end
	end
	return nil
end

local function reset(player: Player)
	if progress[player] then
		progress[player] = nil
		Remotes.ExtractProgress:FireClient(player, nil)
	end
end

function ExtractionService.Init()
	MatchService.RaidEnded:Connect(function(player)
		progress[player] = nil
		if player.Parent then
			Remotes.ExtractProgress:FireClient(player, nil)
		end
	end)
end

function ExtractionService.Start()
	local zonesFolder = Workspace:WaitForChild("Map"):WaitForChild("ExtractZones")
	while true do
		local dt = task.wait(TICK)
		local zones = zonesFolder:GetChildren()
		local t = Workspace:GetServerTimeNow()

		for _, player in MatchService.GetRaidPlayers() do
			local raid = MatchService.GetRaid(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local zone = root and findZone(zones, root.Position)
			if not raid or not zone then
				reset(player)
				continue
			end

			local zoneName = zone:GetAttribute("DisplayName") or zone.Name
			local opensAt = raid.startedAt + (zone:GetAttribute("OpensAfter") or 0)
			if t < opensAt then
				progress[player] = 0
				Remotes.ExtractProgress:FireClient(player, 0, zoneName, math.ceil(opensAt - t))
				continue
			end

			local value = (progress[player] or 0) + dt
			progress[player] = value
			if value >= Config.EXTRACT_TIME then
				MatchService.Extract(player)
			else
				Remotes.ExtractProgress:FireClient(player, value / Config.EXTRACT_TIME, zoneName)
			end
		end
	end
end

return ExtractionService
