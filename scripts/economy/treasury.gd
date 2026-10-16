class_name Treasury
extends RefCounted
## What the player owns (GDD §9): gold (unlimited), blueprints, faction resources and the inventory of
## placeable items. Blueprints are a currency: new towers and tiles are bought with them
## (Island.ensure_item); that is the only way to get them.

signal changed

## Biomes whose stones can drop (one per faction).
const STONE_BIOMES: Array[Biome.Type] = [
	Biome.Type.FOREST, Biome.Type.MOUNTAIN, Biome.Type.PLAINS, Biome.Type.SWAMP, Biome.Type.LAKE,
]

var gold := 0
## Blueprints: the currency for new towers and tiles (see Island.blueprint_cost).
var blueprints := 0
## Faction resources (Biome.Type -> amount): Wood, Ore, Aether, Life Essence, Pearls.
var resources: Dictionary[int, int] = {}
## Bad luck protection: extra blueprint chance per kill, grows every kill without a blueprint
## and resets when one is found. Rare drops (biome stones) don't get it.
var pity := 0.0
var inventory := Inventory.new()


func _init(starting_gold := 0) -> void:
	gold = starting_gold
	inventory.changed.connect(changed.emit)


func to_dict() -> Dictionary:
	return {gold = gold, blueprints = blueprints, inventory = inventory.to_dict(), resources = resources, pity = pity}


## Replaces gold, blueprints and inventory with saved data (see to_dict()).
func load_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", gold))
	blueprints = blueprints_from(data.get("blueprints", 0))
	if data.has("inventory"):
		inventory.load_dict(data.inventory)
	resources.clear()
	var saved_resources: Dictionary = data.get("resources", {})
	for biome in saved_resources:
		resources[int(biome)] = int(saved_resources[biome])
	pity = float(data.get("pity", pity))
	changed.emit()


## A saved blueprint count; older saves kept blueprints per tower type, which are added up.
static func blueprints_from(saved: Variant) -> int:
	if saved is Dictionary:
		var total := 0
		for kind in saved:
			total += int(saved[kind])
		return total
	return int(saved)


func add_blueprint(amount := 1) -> void:
	blueprints += amount
	pity = 0.0
	changed.emit()


func spend_blueprints(amount: int) -> bool:
	if blueprints < amount:
		return false
	blueprints -= amount
	changed.emit()
	return true


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


## The inventory item bought for blueprints as `kind` (a tower type or &"tile").
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

