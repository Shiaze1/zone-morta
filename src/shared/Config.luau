-- Números de balanceamento e ajustes gerais. Tudo que for "tuning" mora aqui.
return {
	-- Persistência
	DATASTORE_NAME = "PlayerData_v1",
	DATASTORE_RETRIES = 4,
	AUTOSAVE_INTERVAL = 120,
	SESSION_LOCK_TIMEOUT = 600, -- segundos até o lock de outro servidor ser considerado abandonado

	-- Raid
	RAID_DURATION = 900, -- 15 minutos
	EXTRACT_TIME = 8, -- segundos parado na zona para extrair
	RAID_CAPACITY = 20, -- espaço da mochila (soma de item.size)
	MAX_LOADOUT_SIZE = 10, -- quanto do stash dá para levar
	STASH_CAPACITY = 200,

	-- Sobrevivência
	MAX_HUNGER = 100,
	MAX_THIRST = 100,
	HUNGER_DECAY = 0.12, -- por segundo (~14 min de cheio a 0)
	THIRST_DECAY = 0.18, -- por segundo (~9 min)
	STARVING_DAMAGE = 2, -- dano por segundo com fome ou sede em 0
	SURVIVAL_TICK = 1,
	USE_COOLDOWN = 0.75,

	-- Loot
	LOOT_RESPAWN_TIME = 300,
	LOOT_PICKUP_DISTANCE = 14,
	BODY_DESPAWN_TIME = 300,
}
