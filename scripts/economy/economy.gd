class_name Economy
extends RefCounted
## Loot (GDD §9). Nothing is bought with gold: towers come from blueprints (several make one
## tower, see Island.blueprints_needed), tiles and biome stones drop from enemies.
## Placeholder numbers until playtesting.

const STARTING_GOLD := 30
## Towers a fresh island starts with in the inventory (one each).
const STARTING_TOWERS: Array[StringName] = [&"attack", &"wall", &"energy", &"repair"]
## Neutral tiles in the start kit, so the island can grow before the first tiles drop.
const STARTING_TILES := 4

## Gold per kill, normalised by weight class: light 1, normal 3, heavy 5. (Nothing to spend
## it on yet.)
const KILL_GOLD := {&"corsair": 1, &"rammer": 1, &"gunboat": 3, &"bomber": 5}
## Drop chances per kill; stones and blueprints get likelier with enemy strength (max HP
## relative to a basic rammer), neutral tiles drop at a flat rate. Biome stones are very
## rare; blueprints of a tower type the player has none of are a little likelier.
const TILE_DROP_CHANCE := 0.12
const STONE_DROP_CHANCE := 0.001
const BLUEPRINT_DROP_CHANCE := 0.01
const MISSING_BLUEPRINT_DROP_CHANCE := 0.012
const MAX_DROP_CHANCE := 0.6
const REFERENCE_HP := 60.0


static func strength(enemy: Enemy) -> float:
	return enemy.max_hp / REFERENCE_HP


static func kill_gold(enemy: Enemy) -> int:
	return KILL_GOLD.get(enemy.kind, 1)


static func stone_chance(enemy: Enemy) -> float:
	return minf(STONE_DROP_CHANCE * strength(enemy), MAX_DROP_CHANCE)


## Chance that `enemy` drops a blueprint of one tower type: higher if the player has none.
static func blueprint_chance(enemy: Enemy, missing: bool) -> float:
	return minf((MISSING_BLUEPRINT_DROP_CHANCE if missing else BLUEPRINT_DROP_CHANCE) * strength(enemy), MAX_DROP_CHANCE)


## Loot of one kill: {gold, tile (bool), stone (Biome.Type or -1), blueprint (StringName or
## &"")}. A random tower type is picked for the blueprint roll; `missing` lists the types the
## player has none of. `rng` makes drops reproducible (tests, simulation).
static func roll_loot(enemy: Enemy, rng: RandomNumberGenerator, missing: Array[StringName] = []) -> Dictionary:
	var loot := {gold = kill_gold(enemy), tile = false, stone = -1, blueprint = &""}
	loot.tile = rng.randf() < TILE_DROP_CHANCE
	if rng.randf() < stone_chance(enemy):
		loot.stone = Treasury.STONE_BIOMES[rng.randi() % Treasury.STONE_BIOMES.size()]
	var type: StringName = TowerDefs.TYPES[rng.randi() % TowerDefs.TYPES.size()]
	if rng.randf() < blueprint_chance(enemy, missing.has(type)):
		loot.blueprint = type
	return loot
