class_name Economy
extends RefCounted
## Loot (GDD §9). Nothing is bought with gold: towers and neutral tiles come from blueprints
## (several make one, see Island.blueprints_needed); biome stones drop from enemies.
## Placeholder numbers until playtesting.

const STARTING_GOLD := 30
## Towers a fresh island starts with in the inventory (one each).
const STARTING_TOWERS: Array[StringName] = [&"attack", &"wall", &"energy", &"repair"]
## Neutral tiles in the start kit, so the island can grow before the first tiles drop.
const STARTING_TILES := 4

## Gold per kill, normalised by weight class: light 1, normal 3, heavy 5. (Nothing to spend
## it on yet.)
const KILL_GOLD := {&"corsair": 1, &"rammer": 1, &"gunboat": 3, &"bomber": 5}
## Drop chances per kill, times the enemy type's EnemyDefs.DROP_FACTOR (swarmers less, big
## ships a little more). Biome stones are very rare; blueprints of something the player has
## none of are a little likelier.
const STONE_DROP_CHANCE := 0.001
const BLUEPRINT_DROP_CHANCE := 0.02
const MISSING_BLUEPRINT_DROP_CHANCE := 0.024
## Faction resources (one random faction per drop).
const RESOURCE_DROP_CHANCE := 0.2
## Bad luck protection: the least found blueprint gains this much chance every kill
## without any blueprint, until one drops.
const PITY_STEP := 0.0005
const MAX_DROP_CHANCE := 0.6


static func kill_gold(enemy: Enemy) -> int:
	return KILL_GOLD.get(enemy.kind, 1)


static func drop_factor(enemy: Enemy) -> float:
	return EnemyDefs.DROP_FACTOR.get(enemy.kind, 1.0)


static func stone_chance(enemy: Enemy) -> float:
	return minf(STONE_DROP_CHANCE * drop_factor(enemy), MAX_DROP_CHANCE)


## Things blueprints exist for: every tower type and neutral tiles.
static func blueprint_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = TowerDefs.TYPES.duplicate()
	kinds.append(&"tile")
	return kinds


## Chance that `enemy` drops a blueprint of one kind: higher if the player has none.
static func blueprint_chance(enemy: Enemy, missing: bool) -> float:
	return minf((MISSING_BLUEPRINT_DROP_CHANCE if missing else BLUEPRINT_DROP_CHANCE) * drop_factor(enemy), MAX_DROP_CHANCE)


## Loot of one kill: {gold, stone (Biome.Type or -1), resource (Biome.Type or -1),
## blueprint (a tower type, &"tile" or &"")}. A random kind is picked for the blueprint roll;
## `missing` lists the kinds the player has none of. Without a blueprint, the bad luck
## protection rolls `pity` for `pity_kind`. `rng` makes drops reproducible.
static func roll_loot(enemy: Enemy, rng: RandomNumberGenerator, missing: Array[StringName] = [],
		pity := 0.0, pity_kind: StringName = &"") -> Dictionary:
	var loot := {gold = kill_gold(enemy), stone = -1, resource = -1, blueprint = &""}
	if rng.randf() < stone_chance(enemy):
		loot.stone = Treasury.STONE_BIOMES[rng.randi() % Treasury.STONE_BIOMES.size()]
	if rng.randf() < minf(RESOURCE_DROP_CHANCE * drop_factor(enemy), MAX_DROP_CHANCE):
		loot.resource = Treasury.STONE_BIOMES[rng.randi() % Treasury.STONE_BIOMES.size()]
	var kinds := blueprint_kinds()
	var type: StringName = kinds[rng.randi() % kinds.size()]
	if rng.randf() < blueprint_chance(enemy, missing.has(type)):
		loot.blueprint = type
	elif pity_kind != &"" and rng.randf() < pity:
		loot.blueprint = pity_kind
	return loot
