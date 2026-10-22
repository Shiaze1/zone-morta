-- Persistência do jogador: stash, dinheiro e estatísticas.
-- UpdateAsync com retry + session lock simples para evitar duplicação entre servidores.
-- Em Studio, ative "Enable Studio Access to API Services" em Game Settings > Security.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local SyncService = require(script.Parent.SyncService)

local DataService = {}

local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
local profiles: { [Player]: any } = {}
local pendingWrites = 0

local function defaultData()
	return {
		version = 1,
		money = 0,
		stash = {
			-- kit inicial
			bandage = 2,
			canned_food = 1,
			water_bottle = 1,
		},
		stats = { raids = 0, extracts = 0, deaths = 0 },
	}
end

-- Preenche campos que não existiam em versões antigas dos dados
local function reconcile(data)
	local default = defaultData()
	for key, value in default do
		if data[key] == nil then
			data[key] = value
		end
	end
	for key, value in default.stats do
		if data.stats[key] == nil then
			data.stats[key] = value
		end
	end
	for id in data.stash do
		if not Items.Get(id) then
			data.stash[id] = nil -- item removido do jogo
		end
	end
	return data
end

local function keyFor(userId: number): string
	return "player_" .. userId
end

local function withRetries(label: string, fn: () -> any): (boolean, any)
	for attempt = 1, Config.DATASTORE_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataService] {label} falhou (tentativa {attempt}): {result}`)
		if attempt < Config.DATASTORE_RETRIES then
			task.wait(2 ^ attempt)
		end
	end
	return false, nil
end

local function write(userId: number, data, release: boolean)
	pendingWrites += 1
	withRetries("save " .. userId, function()
		return store:UpdateAsync(keyFor(userId), function(old)
			-- Outro servidor assumiu o lock (o nosso expirou): não sobrescreve.
			if old and old.lock and old.lock.jobId ~= game.JobId then
				return nil
			end
			data.lock = if release then nil else { jobId = game.JobId, time = os.time() }
			return data
		end)
	end)
	pendingWrites -= 1
end

local function tryAcquire(player: Player)
	local locked = false
	local ok, data = withRetries("load " .. player.UserId, function()
		locked = false
		return store:UpdateAsync(keyFor(player.UserId), function(old)
			local data = reconcile(old or defaultData())
			local lock = data.lock
			if lock and lock.jobId ~= game.JobId and os.time() - lock.time < Config.SESSION_LOCK_TIMEOUT then
				locked = true
				return nil -- cancela a escrita
			end
			data.lock = { jobId = game.JobId, time = os.time() }
			return data
		end)
	end)
	return ok, data, locked
end

function DataService.Load(player: Player)
	for _ = 1, 6 do
		local ok, data, locked = tryAcquire(player)
		if not ok then
			player:Kick("Não foi possível carregar seus dados. Tente novamente.")
			return
		end
		if not locked then
			if player.Parent ~= Players then
				write(player.UserId, data, true) -- saiu durante o carregamento
				return
			end
			profiles[player] = data
			SyncService.MarkDirty(player)
			return
		end
		task.wait(5)
	end
	player:Kick("Seus dados ainda estão abertos em outro servidor. Tente de novo em alguns minutos.")
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if data then
		task.spawn(write, player.UserId, data, false)
	end
end

-- Salva e libera o lock. Chamado pelo MatchService quando o jogador sai.
function DataService.Release(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	profiles[player] = nil
	write(player.UserId, data, true)
end

function DataService.AddToStash(player: Player, id: string, count: number): number
	local data = profiles[player]
	local item = Items.Get(id)
	if not data or not item or count <= 0 then
		return 0
	end
	local free = Config.STASH_CAPACITY - Items.TotalSize(data.stash)
	local fit = math.clamp(math.floor(free / item.size), 0, count)
	if fit > 0 then
		data.stash[id] = (data.stash[id] or 0) + fit
		SyncService.MarkDirty(player)
	end
	return fit
end

function DataService.RemoveFromStash(player: Player, id: string, count: number): boolean
	local data = profiles[player]
	if not data or count <= 0 then
		return false
	end
	local have = data.stash[id] or 0
	if have < count then
		return false
	end
	local left = have - count
	data.stash[id] = if left > 0 then left else nil
	SyncService.MarkDirty(player)
	return true
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		DataService.Load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.Load, player)
	end

	SyncService.Register("profile", function(player)
		local data = profiles[player]
		if not data then
			return nil
		end
		return {
			money = data.money,
			stash = data.stash,
			stats = data.stats,
			stashUsed = Items.TotalSize(data.stash),
			stashCapacity = Config.STASH_CAPACITY,
		}
	end)

	game:BindToClose(function()
		for player, data in profiles do
			profiles[player] = nil
			task.spawn(write, player.UserId, data, true)
		end
		while pendingWrites > 0 do
			task.wait()
		end
	end)
end

function DataService.Start()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for player in profiles do
			DataService.Save(player)
		end
	end
end

return DataService
