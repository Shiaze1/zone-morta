-- Catálogo de itens. `size` ocupa espaço na mochila/stash, `value` é o preço de venda.
export type ItemDef = {
	id: string,
	name: string,
	kind: string,
	size: number,
	value: number,
	rarity: string,
	use: { heal: number?, hunger: number?, thirst: number? }?,
}

local DEFINITIONS: { [string]: ItemDef } = {
	-- Consumíveis
	bandage = { name = "Bandagem", kind = "medical", size = 1, value = 40, rarity = "common", use = { heal = 25 } },
	medkit = { name = "Kit Médico", kind = "medical", size = 2, value = 150, rarity = "rare", use = { heal = 80 } },
	canned_food = { name = "Comida Enlatada", kind = "food", size = 1, value = 30, rarity = "common", use = { hunger = 40 } },
	water_bottle = { name = "Garrafa de Água", kind = "drink", size = 1, value = 25, rarity = "common", use = { thirst = 50 } },
	energy_drink = { name = "Energético", kind = "drink", size = 1, value = 60, rarity = "uncommon", use = { thirst = 25, hunger = 10 } },

	-- Valiosos (só servem para vender)
	scrap = { name = "Sucata", kind = "valuable", size = 1, value = 15, rarity = "common" },
	copper_wire = { name = "Fios de Cobre", kind = "valuable", size = 1, value = 35, rarity = "common" },
	gpu = { name = "Placa de Vídeo", kind = "valuable", size = 2, value = 600, rarity = "rare" },
	gold_watch = { name = "Relógio de Ouro", kind = "valuable", size = 1, value = 900, rarity = "epic" },
	intel = { name = "Documentos Secretos", kind = "valuable", size = 1, value = 1500, rarity = "legendary" },
} :: any

for id, def in DEFINITIONS do
	def.id = id
end

local Items = {}

Items.All = DEFINITIONS

Items.RarityColors = {
	common = Color3.fromRGB(220, 220, 220),
	uncommon = Color3.fromRGB(110, 220, 110),
	rare = Color3.fromRGB(90, 160, 255),
	epic = Color3.fromRGB(190, 110, 255),
	legendary = Color3.fromRGB(255, 180, 60),
}

function Items.Get(id: any): ItemDef?
	if typeof(id) ~= "string" then
		return nil
	end
	return DEFINITIONS[id]
end

-- Espaço total ocupado por um saco { [itemId] = quantidade }
function Items.TotalSize(bag: { [string]: number }): number
	local total = 0
	for id, count in bag do
		local def = DEFINITIONS[id]
		if def then
			total += def.size * count
		end
	end
	return total
end

function Items.TotalValue(bag: { [string]: number }): number
	local total = 0
	for id, count in bag do
		local def = DEFINITIONS[id]
		if def then
			total += def.value * count
		end
	end
	return total
end

return Items
