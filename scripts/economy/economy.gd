class_name Economy
extends RefCounted
## Prices and loot (GDD §9). Placeholder numbers until playtesting.

const STARTING_GOLD := 300
## Towers a fresh island starts with in the inventory (one each).
const STARTING_TOWERS: Array[StringName] = [&"attack", &"wall", &"energy", &"repair"]

const TOWER_COST := {
	&"attack": 50,
	&"wall": 40,
	&"energy": 60,
	&"repair": 70,
	&"aura": 80,
	&"scout": 50,
	&"warehouse": 60,
}

## New tiles get more expensive the bigger the island is.
const TILE_BASE_COST := 20
const TILE_COST_PER_TILE := 2

## Gold per kill by enemy type (scaled with the enemy's strength).
const KILL_GOLD := {&"rammer": 5, &"gunboat": 8, &"corsair": 6, &"bomber": 12}
## Rare drops (biome stones) get likelier with enemy strength (max HP relative to a basic rammer).
const RARE_DROP_CHANCE := 0.06
const BLUEPRINT_DROP_CHANCE := 0.025
const MAX_DROP_CHANCE := 0.6
const REFERENCE_HP := 60.0


static func tower_cost(type: StringName) -> int:
	return TOWER_COST.get(type, 50)


static func tile_cost(island: Island) -> int:
	return TILE_BASE_COST + TILE_COST_PER_TILE * island.tile_count()


static func strength(enemy: Enemy) -> float:
	return enemy.max_hp / REFERENCE_HP


static func kill_gold(enemy: Enemy) -> int:
	return maxi(1, roundi(KILL_GOLD.get(enemy.kind, 5) * maxf(1.0, enemy.max_hp / EnemyDefs.TYPES[enemy.kind].hp)))


## Loot of one kill: {gold, stone (Biome.Type or -1), blueprint (StringName or &"")}.
## `rng` makes drops reproducible (tests, simulation).
static func roll_loot(enemy: Enemy, treasury: Treasury, rng: RandomNumberGenerator) -> Dictionary:
	var loot := {gold = kill_gold(enemy), stone = -1, blueprint = &""}
	var s := strength(enemy)
	if rng.randf() < minf(RARE_DROP_CHANCE * s, MAX_DROP_CHANCE):
		loot.stone = Treasury.STONE_BIOMES[rng.randi() % Treasury.STONE_BIOMES.size()]
	if rng.randf() < minf(BLUEPRINT_DROP_CHANCE * s, MAX_DROP_CHANCE):
		# Locked types first, so blueprints unlock something new while they can.
		var pool := treasury.locked_towers()
		if pool.is_empty():
			pool = TowerDefs.TYPES.duplicate()
		loot.blueprint = pool[rng.randi() % pool.size()]
	return loot
