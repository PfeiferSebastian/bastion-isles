class_name Economy
extends RefCounted
## Loot (GDD §9). Nothing is bought with gold: towers and neutral tiles are bought with
## blueprints (Island.blueprint_cost), which drop from enemies like biome stones.
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
## ships a little more). Biome stones are very rare.
const STONE_DROP_CHANCE := 0.001
const BLUEPRINT_DROP_CHANCE := 0.02
## Faction resources (one random faction per drop).
const RESOURCE_DROP_CHANCE := 0.2
## Bad luck protection: blueprints gain up to this much chance every kill without one, until
## one drops (rare drops like biome stones don't get it). The step shrinks with every
## blueprint the player owns and every one found this mission (see pity_step).
const PITY_STEP := 0.0005
const PITY_DAMPING_OWNED := 0.1
const PITY_DAMPING_FOUND := 0.25
const MAX_DROP_CHANCE := 0.6


static func kill_gold(enemy: Enemy) -> int:
	return KILL_GOLD.get(enemy.kind, 1)


static func drop_factor(enemy: Enemy) -> float:
	return EnemyDefs.DROP_FACTOR.get(enemy.kind, 1.0)


static func stone_chance(enemy: Enemy) -> float:
	return minf(STONE_DROP_CHANCE * drop_factor(enemy), MAX_DROP_CHANCE)


## Things blueprints can buy: every tower type and neutral tiles.
static func blueprint_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = TowerDefs.TYPES.duplicate()
	kinds.append(&"tile")
	return kinds


## Extra blueprint chance a kill without one adds: PITY_STEP / (1 + 0.1 per blueprint owned
## + 0.25 per blueprint found this mission).
static func pity_step(owned: int, found_this_mission: int) -> float:
	return PITY_STEP / (1.0 + PITY_DAMPING_OWNED * maxi(owned, 0) + PITY_DAMPING_FOUND * maxi(found_this_mission, 0))


## Chance that `enemy` drops a blueprint, plus the bad luck protection's `pity`.
static func blueprint_chance(enemy: Enemy, pity := 0.0) -> float:
	return minf(BLUEPRINT_DROP_CHANCE * drop_factor(enemy) + pity, MAX_DROP_CHANCE)


## Loot of one kill: {gold, stone (Biome.Type or -1), resource (Biome.Type or -1), blueprint
## (bool)}. `pity` is the bad luck protection's extra blueprint chance. `rng` makes drops
## reproducible.
static func roll_loot(enemy: Enemy, rng: RandomNumberGenerator, pity := 0.0) -> Dictionary:
	var loot := {gold = kill_gold(enemy), stone = -1, resource = -1, blueprint = false}
	if rng.randf() < stone_chance(enemy):
		loot.stone = Treasury.STONE_BIOMES[rng.randi() % Treasury.STONE_BIOMES.size()]
	if rng.randf() < minf(RESOURCE_DROP_CHANCE * drop_factor(enemy), MAX_DROP_CHANCE):
		loot.resource = Treasury.STONE_BIOMES[rng.randi() % Treasury.STONE_BIOMES.size()]
	loot.blueprint = rng.randf() < blueprint_chance(enemy, pity)
	return loot
