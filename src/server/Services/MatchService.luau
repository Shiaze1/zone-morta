-- Fluxo do jogador: Lobby → Raid → (extração | morte) → Lobby.
-- Também cuida da venda de itens no lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SyncService = require(script.Parent.SyncService)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local SurvivalService = require(script.Parent.SurvivalService)

local MatchService = {}

type Raid = { startedAt: number, endsAt: number }
local raids: { [Player]: Raid } = {}

-- (player, reason: "extracted" | "died" | "timeout" | "left", bag, position?)
local raidEnded = Instance.new("BindableEvent")
MatchService.RaidEnded = raidEnded.Event

local END_MESSAGES = {
	died = "Você morreu e perdeu tudo que carregava.",
	timeout = "O tempo acabou. Você ficou preso na zona e perdeu tudo.",
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function MatchService.IsInRaid(player: Player): boolean
	return raids[player] ~= nil
end

function MatchService.GetRaid(player: Player): Raid?
	return raids[player]
end

function MatchService.GetRaidPlayers(): { Player }
	local list = {}
	for player in raids do
		table.insert(list, player)
	end
	return list
end

-- Valida o loadout pedido pelo cliente contra o stash real
local function parseLoadout(player: Player, loadout: any): { [string]: number }?
	if loadout == nil then
		return {}
	end
	if typeof(loadout) ~= "table" then
		return nil
	end
	local data = DataService.Get(player)
	local result, entries, size = {}, 0, 0
	for id, count in loadout do
		entries += 1
		local item = Items.Get(id)
		if entries > 30 or not item or typeof(count) ~= "number" or count ~= math.floor(count) or count < 1 then
			return nil
		end
		if (data.stash[id] or 0) < count then
			return nil
		end
		size += item.size * count
		result[id] = count
	end
	if size > Config.MAX_LOADOUT_SIZE then
		return nil
	end
	return result
end

local function pickRaidSpawn(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("RaidSpawns")
	local spawns = folder and folder:GetChildren() or {}
	if #spawns == 0 then
		return nil
	end
	return spawns[math.random(#spawns)] :: BasePart
end

local function onDeploy(player: Player, loadout: any)
	local data = DataService.Get(player)
	if raids[player] or not data then
		return
	end
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local spawnPart = pickRaidSpawn()
	if not spawnPart then
		warn("[MatchService] Nenhum spawn em Workspace.Map.RaidSpawns")
		return
	end
	local items = parseLoadout(player, loadout)
	if not items then
		SyncService.Notify(player, "Loadout inválido.", "error")
		return
	end

	for id, count in items do
		DataService.RemoveFromStash(player, id, count)
	end
	data.stats.raids += 1

	local t = now()
	raids[player] = { startedAt = t, endsAt = t + Config.RAID_DURATION }
	InventoryService.Open(player, items)
	SurvivalService.Enable(player)

	humanoid.Health = humanoid.MaxHealth
	;(player.Character :: Model):PivotTo(spawnPart.CFrame + Vector3.new(0, 5, 0))

	DataService.Save(player)
	SyncService.MarkDirty(player)
	SyncService.Notify(player, "Raid iniciada! Ache uma extração antes do tempo acabar.", "info")
end

local function endRaid(player: Player, reason: string)
	if not raids[player] then
		return
	end
	raids[player] = nil

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local position = root and root.Position
	local bag = InventoryService.Close(player) or {}
	SurvivalService.Disable(player)
	local data = DataService.Get(player)

	if reason == "extracted" then
		local stored, soldValue = 0, 0
		for id, count in bag do
			local added = DataService.AddToStash(player, id, count)
			stored += added
			if added < count then
				soldValue += (Items.Get(id) :: any).value * (count - added)
			end
		end
		if data then
			data.money += soldValue
			data.stats.extracts += 1
		end
		local message = `Extraído! {stored} itens foram para o stash (valor ${Items.TotalValue(bag)}).`
		if soldValue > 0 then
			message ..= ` Stash cheio: o excesso foi vendido por ${soldValue}.`
		end
		SyncService.Notify(player, message, "success")
		DataService.Save(player)
	else
		if data then
			data.stats.deaths += 1
		end
		if END_MESSAGES[reason] then
			SyncService.Notify(player, END_MESSAGES[reason], "error")
		end
	end

	raidEnded:Fire(player, reason, bag, position)
	SyncService.MarkDirty(player)
end

function MatchService.Extract(player: Player)
	if not raids[player] then
		return
	end
	endRaid(player, "extracted")
	if player.Parent == Players then
		player:LoadCharacter() -- volta para o lobby
	end
end

local function onSell(player: Player, id: any, count: any)
	if raids[player] then
		return
	end
	local item = Items.Get(id)
	local data = DataService.Get(player)
	if not item or not data or typeof(count) ~= "number" or count ~= count then
		return
	end
	count = math.floor(count)
	if count < 1 then
		return
	end
	if DataService.RemoveFromStash(player, item.id, count) then
		data.money += item.value * count
		SyncService.MarkDirty(player)
	end
end

function MatchService.Init()
	Remotes.Deploy.OnServerEvent:Connect(onDeploy)
	Remotes.SellItem.OnServerEvent:Connect(onSell)

	SyncService.Register("match", function(player)
		local raid = raids[player]
		return {
			phase = if raid then "InRaid" else "Lobby",
			endsAt = raid and raid.endsAt,
			maxLoadout = Config.MAX_LOADOUT_SIZE,
		}
	end)

	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			endRaid(player, "died")
		end)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		endRaid(player, "left") -- sair no meio da raid = morte
		DataService.Release(player)
	end)
end

function MatchService.Start()
	while true do
		task.wait(1)
		local t = now()
		for player, raid in raids do
			if t >= raid.endsAt then
				endRaid(player, "timeout")
				local humanoid = getHumanoid(player)
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
	end
end

return MatchService
