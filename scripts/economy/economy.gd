class_name Economy
extends RefCounted
## Prices and loot (GDD §9). Placeholder numbers until playtesting.

const STARTING_GOLD := 30
## Towers a fresh island starts with in the inventory (one each).
const STARTING_TOWERS: Array[StringName] = [&"attack", &"wall", &"energy", &"repair"]

## Prices on the normalised gold scale (1 gold per light enemy).
const TOWER_COST := {
	&"attack": 10,
	&"wall": 8,
	&"energy": 12,
	&"repair": 14,
	&"aura": 16,
	&"scout": 10,
	&"warehouse": 12,
}

## New tiles get more expensive the bigger the island is: base + 1 gold per few tiles.
const TILE_BASE_COST := 3
const TILES_PER_EXTRA_GOLD := 3

## Gold per kill, normalised by weight class: light 1, normal 3, heavy 5.
const KILL_GOLD := {&"corsair": 1, &"rammer": 1, &"gunboat": 3, &"bomber": 5}
## Rare drops (biome stones) get likelier with enemy strength (max HP relative to a basic rammer).
const RARE_DROP_CHANCE := 0.06
const BLUEPRINT_DROP_CHANCE := 0.025
const MAX_DROP_CHANCE := 0.6
const REFERENCE_HP := 60.0


static func tower_cost(type: StringName) -> int:
	return TOWER_COST.get(type, 10)


static func tile_cost(island: Island) -> int:
	return TILE_BASE_COST + int(island.tile_count() / float(TILES_PER_EXTRA_GOLD))


## Gold price of buying `item`, or -1 if it cannot be bought (biome stones only drop).
static func price_of(item: Dictionary, island: Island) -> int:
	match item.kind:
		&"tower":
			return tower_cost(item.type)
		&"tile":
			return tile_cost(island)
	return -1


## Gold price if the player may buy `item` right now (basic tiles, level-1 towers of
## unlocked types), else -1.
static func buy_price(item: Dictionary, island: Island) -> int:
	if item.kind == &"tower" and (item.level != 1 or not island.treasury.is_unlocked(item.type)):
		return -1
	return price_of(item, island)


## True if the player has `item` in the inventory or the gold to buy one.
static func can_get(item: Dictionary, island: Island) -> bool:
	if island.treasury.inventory.count(item) > 0:
		return true
	var price := buy_price(item, island)
	return price >= 0 and island.treasury.gold >= price


## Makes sure one `item` is in the inventory, buying it if none is left. False if that fails.
static func ensure_one(item: Dictionary, island: Island) -> bool:
	if island.treasury.inventory.count(item) > 0:
		return true
	var price := buy_price(item, island)
	return price >= 0 and island.treasury.buy(item, price)


static func strength(enemy: Enemy) -> float:
	return enemy.max_hp / REFERENCE_HP


static func kill_gold(enemy: Enemy) -> int:
	return KILL_GOLD.get(enemy.kind, 1)


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
