-- Ponto de entrada do servidor: garante o mapa e sobe os serviços em ordem.
require(script.MapBootstrap).Ensure()

local ORDER = {
	"SyncService",
	"DataService",
	"InventoryService",
	"SurvivalService",
	"MatchService",
	"LootService",
	"ExtractionService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(script.Services[name])
end

for _, name in ORDER do
	if services[name].Init then
		services[name].Init()
	end
end

for _, name in ORDER do
	if services[name].Start then
		task.spawn(services[name].Start)
	end
end

print("[Server] serviços prontos")
