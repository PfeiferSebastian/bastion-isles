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


static func tower_item(type: StringName, level := 1) -> Dictionary:
	return {kind = &"tower", type = type, level = level}


static func tile_item() -> Dictionary:
	return {kind = &"tile"}


static func stone_item(biome: Biome.Type) -> Dictionary:
	return {kind = &"stone", biome = biome}


static func label_of(item: Dictionary) -> String:
	match item.get("kind", &""):
		&"tower":
			return "%s (Lv %d)" % [String(item.type).capitalize(), item.level]
		&"tile":
			return "Tile"
		&"stone":
			return "%s stone" % Biome.name_of(item.biome)
	return ""


func count(item: Dictionary) -> int:
	match item.get("kind", &""):
		&"tower":
			return towers.get(_key(item.type, item.level), 0)
		&"tile":
			return tiles
		&"stone":
			return stones.get(item.biome, 0)
	return 0


func add(item: Dictionary, amount := 1) -> void:
	match item.kind:
		&"tower":
			var key := _key(item.type, item.level)
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


## Levels of `type` the player has at least one of, ascending.
func tower_levels(type: StringName) -> Array[int]:
	var result: Array[int] = []
	for key in towers:
		var parts := key.split(":")
		if StringName(parts[0]) == type and towers[key] > 0:
			result.append(int(parts[1]))
	result.sort()
	return result


static func _key(type: StringName, level: int) -> String:
	return "%s:%d" % [type, level]
