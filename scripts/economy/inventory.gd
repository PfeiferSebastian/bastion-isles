class_name Inventory
extends RefCounted
## Stackable items the player can place: towers (stacked by type and level), neutral tiles
## and biome stones. Items are plain dictionaries, built with the helpers below:
##   {kind = &"tower", type = &"attack", level = 1}
##   {kind = &"tile"}
##   {kind = &"stone", biome = Biome.Type.FOREST}

signal changed

var towers: Dictionary[String, int] = {}   # "type:level" -> count
var tiles := 0
var stones: Dictionary[int, int] = {}      # Biome.Type -> count


static func tower_item(type: StringName, level := 0, tier := 1) -> Dictionary:
	return {kind = &"tower", type = type, level = level, tier = tier}


static func tile_item() -> Dictionary:
	return {kind = &"tile"}


static func stone_item(biome: Biome.Type) -> Dictionary:
	return {kind = &"stone", biome = biome}


static func label_of(item: Dictionary) -> String:
	match item.get("kind", &""):
		&"tower":
			var tier: int = item.get("tier", 1)
			return "%s (%sLv %d)" % [String(item.type).capitalize(), "T%d " % tier if tier > 1 else "", item.level]
		&"tile":
			return "Tile"
		&"stone":
			return "%s stone" % Biome.name_of(item.biome)
	return ""


func count(item: Dictionary) -> int:
	match item.get("kind", &""):
		&"tower":
			return towers.get(_key(item.type, item.level, item.get("tier", 1)), 0)
		&"tile":
			return tiles
		&"stone":
			return stones.get(item.biome, 0)
	return 0


func add(item: Dictionary, amount := 1) -> void:
	match item.kind:
		&"tower":
			var key := _key(item.type, item.level, item.get("tier", 1))
			towers[key] = towers.get(key, 0) + amount
		&"tile":
			tiles += amount
		&"stone":
			stones[item.biome] = stones.get(item.biome, 0) + amount
	changed.emit()


## Removes one item; false if there is none.
func take(item: Dictionary) -> bool:
	if count(item) <= 0:
		return false
	add(item, -1)
	return true


func to_dict() -> Dictionary:
	return {towers = towers, tiles = tiles, stones = stones}


## Replaces the contents with saved data (JSON turns the stone keys into strings).
func load_dict(data: Dictionary) -> void:
	towers.clear()
	stones.clear()
	var saved_towers: Dictionary = data.get("towers", {})
	for key in saved_towers:
		towers[String(key)] = int(saved_towers[key])
	tiles = int(data.get("tiles", 0))
	var saved_stones: Dictionary = data.get("stones", {})
	for key in saved_stones:
		stones[int(key)] = int(saved_stones[key])
	changed.emit()


## Stacks of `type` the player has at least one of, as Vector2i(level, tier), lowest tier
## and level first.
func tower_stacks(type: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in towers:
		var parts := key.split(":")
		if StringName(parts[0]) == type and towers[key] > 0:
			result.append(Vector2i(int(parts[1]), int(parts[2]) if parts.size() > 2 else 1))
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	return result


## Towers of `type` in the inventory, all stacks together.
func tower_count(type: StringName) -> int:
	var total := 0
	for stack in tower_stacks(type):
		total += count(tower_item(type, stack.x, stack.y))
	return total


## Tier 1 keys stay "type:level" so older saves still load.
static func _key(type: StringName, level: int, tier := 1) -> String:
	return "%s:%d" % [type, level] if tier <= 1 else "%s:%d:%d" % [type, level, tier]
