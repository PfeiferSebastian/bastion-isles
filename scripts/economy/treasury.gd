class_name Treasury
extends RefCounted
## What the player owns (GDD §9): gold (unlimited), blueprint pieces, and the inventory of
## placeable items. A full set of blueprints of one type (see Island.blueprints_needed)
## becomes a tower of that type in the inventory; that is the only way to get new towers.

signal changed

## Biomes whose stones can drop (one per faction).
const STONE_BIOMES: Array[Biome.Type] = [
	Biome.Type.FOREST, Biome.Type.MOUNTAIN, Biome.Type.PLAINS, Biome.Type.SWAMP, Biome.Type.LAKE,
]

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


## Adds a blueprint; with `needed` of them the set becomes a tower. Returns true then.
func add_blueprint(tower_type: StringName, needed: int) -> bool:
	blueprints[tower_type] = blueprints.get(tower_type, 0) + 1
	var built := blueprints[tower_type] >= needed
	if built:
		blueprints[tower_type] -= needed
		inventory.add(Inventory.tower_item(tower_type))
	changed.emit()
	return built
