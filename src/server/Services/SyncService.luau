-- Junta o estado de cada jogador (perfil, mochila, raid, sobrevivência) num snapshot
-- e manda ao cliente. Os serviços registram "providers" para não dependerem uns dos outros.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SyncService = {}

local providers: { [string]: (Player) -> any } = {}
local pending: { [Player]: boolean } = {}

function SyncService.Register(key: string, provider: (Player) -> any)
	providers[key] = provider
end

-- Agenda um envio no fim do frame; várias mudanças no mesmo frame viram um envio só.
function SyncService.MarkDirty(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		if player.Parent ~= Players then
			return
		end
		local snapshot = {}
		for key, provider in providers do
			snapshot[key] = provider(player)
		end
		Remotes.Sync:FireClient(player, snapshot)
	end)
end

function SyncService.Notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function SyncService.Init()
	Remotes.RequestSync.OnServerEvent:Connect(SyncService.MarkDirty)
end

return SyncService
