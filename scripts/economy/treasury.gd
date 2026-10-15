class_name Treasury
extends RefCounted
## What the player owns (GDD §9): gold (unlimited), blueprints that unlock tower types, and
## the inventory of placeable items. Rare drops are biome stones in the inventory; the HQ
## holds them and the blueprints (unlimited for now).

signal changed

## Biomes whose stones can drop (one per faction).
const STONE_BIOMES: Array[Biome.Type] = [
	Biome.Type.FOREST, Biome.Type.MOUNTAIN, Biome.Type.PLAINS, Biome.Type.SWAMP, Biome.Type.LAKE,
]
## Tower types available without a blueprint.
const STARTING_TOWERS: Array[StringName] = [&"attack", &"wall", &"energy"]

var gold := 0
var blueprints: Dictionary[StringName, int] = {}
var inventory := Inventory.new()


func _init(starting_gold := 0) -> void:
	gold = starting_gold
	inventory.changed.connect(changed.emit)


func to_dict() -> Dictionary:
	return {gold = gold, blueprints = blueprints, inventory = inventory.to_dict()}


## Replaces gold, blueprints and inventory with saved data (see to_dict()).
func load_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", gold))
	blueprints.clear()
	var saved: Dictionary = data.get("blueprints", {})
	for type in saved:
		blueprints[StringName(type)] = int(saved[type])
	if data.has("inventory"):
		inventory.load_dict(data.inventory)
	changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	changed.emit()
	return true


func add_blueprint(tower_type: StringName) -> void:
	blueprints[tower_type] = blueprints.get(tower_type, 0) + 1
	changed.emit()


func is_unlocked(tower_type: StringName) -> bool:
	return STARTING_TOWERS.has(tower_type) or blueprints.get(tower_type, 0) > 0


func locked_towers() -> Array[StringName]:
	var result: Array[StringName] = []
	for type in TowerDefs.TYPES:
		if not is_unlocked(type):
			result.append(type)
	return result


## Buys one item into the inventory: towers (unlocked types) and tiles cost gold.
func buy(item: Dictionary, price: int) -> bool:
	if item.kind == &"tower" and not is_unlocked(item.type):
		return false
	if not spend_gold(price):
		return false
	inventory.add(item)
	return true
