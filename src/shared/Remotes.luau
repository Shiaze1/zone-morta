-- Todos os RemoteEvents do jogo. O servidor cria, o cliente espera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- cliente → servidor
	"RequestSync",
	"Deploy", -- (loadout: { [itemId]: number })
	"UseItem", -- (itemId)
	"SellItem", -- (itemId, count)
	-- servidor → cliente
	"Sync", -- (snapshot)
	"Notify", -- (text, kind)
	"ExtractProgress", -- (ratio?, zoneName?, lockedFor?)
}

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes: { [string]: RemoteEvent } = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
