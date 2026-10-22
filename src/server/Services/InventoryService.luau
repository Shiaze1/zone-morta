-- Mochila da raid. Só existe enquanto o jogador está numa raid e NÃO é salva:
-- ela só vira stash ao extrair.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local SyncService = require(script.Parent.SyncService)

local InventoryService = {}

local bags: { [Player]: { [string]: number } } = {}

function InventoryService.Open(player: Player, initial: { [string]: number }?)
	bags[player] = initial or {}
	SyncService.MarkDirty(player)
end

-- Fecha a mochila e devolve o conteúdo
function InventoryService.Close(player: Player): { [string]: number }?
	local bag = bags[player]
	bags[player] = nil
	SyncService.MarkDirty(player)
	return bag
end

function InventoryService.Get(player: Player)
	return bags[player]
end

-- Adiciona o que couber; retorna quantos entraram
function InventoryService.Add(player: Player, id: string, count: number): number
	local bag = bags[player]
	local item = Items.Get(id)
	if not bag or not item or count <= 0 then
		return 0
	end
	local free = Config.RAID_CAPACITY - Items.TotalSize(bag)
	local fit = math.clamp(math.floor(free / item.size), 0, count)
	if fit > 0 then
		bag[id] = (bag[id] or 0) + fit
		SyncService.MarkDirty(player)
	end
	return fit
end

function InventoryService.Remove(player: Player, id: string, count: number): boolean
	local bag = bags[player]
	if not bag or count <= 0 then
		return false
	end
	local have = bag[id] or 0
	if have < count then
		return false
	end
	local left = have - count
	bag[id] = if left > 0 then left else nil
	SyncService.MarkDirty(player)
	return true
end

function InventoryService.Init()
	SyncService.Register("raid", function(player)
		local bag = bags[player]
		if not bag then
			return nil
		end
		return { items = bag, used = Items.TotalSize(bag), capacity = Config.RAID_CAPACITY }
	end)
end

return InventoryService
