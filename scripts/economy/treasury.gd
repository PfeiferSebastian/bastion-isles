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
	changed.emit()
	return built
