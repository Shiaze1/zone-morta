-- Fome, sede e uso de consumíveis durante a raid.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SyncService = require(script.Parent.SyncService)
local InventoryService = require(script.Parent.InventoryService)

local SurvivalService = {}

type State = { hunger: number, thirst: number }
local states: { [Player]: State } = {}
local lastUse: { [Player]: number } = {}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function SurvivalService.Enable(player: Player)
	states[player] = { hunger = Config.MAX_HUNGER, thirst = Config.MAX_THIRST }
	SyncService.MarkDirty(player)
end

function SurvivalService.Disable(player: Player)
	states[player] = nil
	SyncService.MarkDirty(player)
end

local function onUseItem(player: Player, id: any)
	local state = states[player]
	local item = Items.Get(id)
	if not state or not item or not item.use then
		return
	end
	if os.clock() - (lastUse[player] or 0) < Config.USE_COOLDOWN then
		return
	end
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if not InventoryService.Remove(player, item.id, 1) then
		return
	end
	lastUse[player] = os.clock()

	local use = item.use
	if use.heal then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + use.heal)
	end
	if use.hunger then
		state.hunger = math.min(Config.MAX_HUNGER, state.hunger + use.hunger)
	end
	if use.thirst then
		state.thirst = math.min(Config.MAX_THIRST, state.thirst + use.thirst)
	end
	SyncService.MarkDirty(player)
end

function SurvivalService.Init()
	Remotes.UseItem.OnServerEvent:Connect(onUseItem)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
	SyncService.Register("survival", function(player)
		local state = states[player]
		if not state then
			return nil
		end
		return {
			hunger = state.hunger,
			thirst = state.thirst,
			maxHunger = Config.MAX_HUNGER,
			maxThirst = Config.MAX_THIRST,
		}
	end)
end

function SurvivalService.Start()
	while true do
		local dt = task.wait(Config.SURVIVAL_TICK)
		for player, state in states do
			state.hunger = math.max(0, state.hunger - Config.HUNGER_DECAY * dt)
			state.thirst = math.max(0, state.thirst - Config.THIRST_DECAY * dt)
			if state.hunger <= 0 or state.thirst <= 0 then
				local humanoid = getHumanoid(player)
				if humanoid then
					humanoid:TakeDamage(Config.STARVING_DAMAGE * dt)
				end
			end
			SyncService.MarkDirty(player)
		end
	end
end

return SurvivalService
