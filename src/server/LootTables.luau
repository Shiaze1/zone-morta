-- Tabelas de loot. `rolls` = quantos sorteios por caixa; `weight` = chance relativa.
return {
	common = {
		label = "Caixa",
		color = Color3.fromRGB(140, 105, 70),
		rolls = { 2, 4 },
		entries = {
			{ id = "scrap", weight = 35, count = { 1, 3 } },
			{ id = "copper_wire", weight = 20, count = { 1, 2 } },
			{ id = "canned_food", weight = 15, count = { 1, 1 } },
			{ id = "water_bottle", weight = 15, count = { 1, 1 } },
			{ id = "bandage", weight = 12, count = { 1, 2 } },
			{ id = "energy_drink", weight = 3, count = { 1, 1 } },
		},
	},
	military = {
		label = "Caixa Militar",
		color = Color3.fromRGB(75, 95, 60),
		rolls = { 2, 3 },
		entries = {
			{ id = "medkit", weight = 20, count = { 1, 1 } },
			{ id = "gpu", weight = 20, count = { 1, 1 } },
			{ id = "bandage", weight = 20, count = { 1, 3 } },
			{ id = "energy_drink", weight = 15, count = { 1, 2 } },
			{ id = "gold_watch", weight = 8, count = { 1, 1 } },
			{ id = "intel", weight = 3, count = { 1, 1 } },
		},
	},
}
