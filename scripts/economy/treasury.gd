class_name Treasury
extends RefCounted
## What the player owns (GDD §9): gold (unlimited), blueprint pieces, and the inventory of
## placeable items. A full set of blueprints of one kind (see Island.blueprints_needed)
## becomes a tower of that type, or a neutral tile, in the inventory; that is the only way to
## get new towers and tiles.

signal changed

## Biomes whose stones can drop (one per faction).
const STONE_BIOMES: Array[Biome.Type] = [
	Biome.Type.FOREST, Biome.Type.MOUNTAIN, Biome.Type.PLAINS, Biome.Type.SWAMP, Biome.Type.LAKE,
]

var gold := 0
var blueprints: Dictionary[StringName, int] = {}
## Faction resources (Biome.Type -> amount): Wood, Ore, Aether, Life Essence, Pearls.
var resources: Dictionary[int, int] = {}
## Blueprints found so far per kind, for the bad luck protection.
var blueprints_found: Dictionary[StringName, int] = {}
## Bad luck protection: extra chance for the least found blueprint, grows every kill
## without a blueprint and resets when one is found.
var pity := 0.0
var inventory := Inventory.new()


func _init(starting_gold := 0) -> void:
	gold = starting_gold
	inventory.changed.connect(changed.emit)


func to_dict() -> Dictionary:
	return {gold = gold, blueprints = blueprints, inventory = inventory.to_dict(), resources = resources,
		blueprints_found = blueprints_found, pity = pity}


## Replaces gold, blueprints and inventory with saved data (see to_dict()).
func load_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", gold))
	blueprints.clear()
	var saved: Dictionary = data.get("blueprints", {})
	for type in saved:
		blueprints[StringName(type)] = int(saved[type])
	if data.has("inventory"):
		inventory.load_dict(data.inventory)
	resources.clear()
	var saved_resources: Dictionary = data.get("resources", {})
	for biome in saved_resources:
		resources[int(biome)] = int(saved_resources[biome])
	load_luck(data)
	changed.emit()


## Bad luck protection state from saved data.
func load_luck(data: Dictionary) -> void:
	var found: Dictionary = data.get("blueprints_found", {})
	for kind in found:
		blueprints_found[StringName(kind)] = int(found[kind])
	pity = float(data.get("pity", pity))


## The blueprint kind found least often so far (the bad luck protection favours it).
func least_found_blueprint() -> StringName:
	var best: StringName = &""
	for kind in Economy.blueprint_kinds():
		if best == &"" or blueprints_found.get(kind, 0) < blueprints_found.get(best, 0):
			best = kind
	return best


func add_resource(biome: int, amount := 1) -> void:
	resources[biome] = resources.get(biome, 0) + amount
	changed.emit()


## Spends gold and one faction resource together; false (and nothing spent) if short.
func spend(gold_cost: int, biome: int, amount: int) -> bool:
	if gold < gold_cost or resources.get(biome, 0) < amount:
		return false
	gold -= gold_cost
	resources[biome] -= amount
	changed.emit()
	return true


## The inventory item a blueprint set of `kind` becomes.
static func blueprint_item(kind: StringName) -> Dictionary:
	return Inventory.tile_item() if kind == &"tile" else Inventory.tower_item(kind)


func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	changed.emit()
	return true


## Adds a blueprint of `kind` (a tower type or &"tile"); with `needed` of them the set
## becomes one of that kind in the inventory. Returns true then.
func add_blueprint(kind: StringName, needed: int) -> bool:
	blueprints[kind] = blueprints.get(kind, 0) + 1
	var built := blueprints[kind] >= needed
	if built:
		blueprints[kind] -= needed
		inventory.add(blueprint_item(kind))
	blueprints_found[kind] = blueprints_found.get(kind, 0) + 1
	pity = 0.0
	changed.emit()
	return built
