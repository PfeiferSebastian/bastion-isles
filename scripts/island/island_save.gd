class_name IslandSave
extends RefCounted
## Keeps the player's island (layout, towers, gold, blueprints, inventory) between missions
## in a JSON file. Saved when leaving or retreating from a mission and after editing.
##
## Blueprints are kept apart as well and saved the moment one is found, so they survive a
## mission that ends any other way (quitting the game, a crash). Towers completed from
## blueprints since the last island save are listed there too and handed out on the next load.

## Save files (tests point these elsewhere so they never touch the player's saves).
static var path := "user://island.json"
static var blueprint_path := "user://blueprints.json"


static func save(island: Island) -> void:
	_write(path, island.to_dict())
	# The island save now holds every completed tower.
	island.unsaved_towers.clear()
	save_blueprints(island)


## Blueprints and the towers and tiles bought with them since the last island save.
static func save_blueprints(island: Island) -> void:
	_write(blueprint_path, {blueprints = island.treasury.blueprints, unsaved_towers = island.unsaved_towers,
		pity = island.treasury.pity})


## The saved island (or a fresh one with `starter_radius`), with the separately kept
## blueprints applied. Towers completed while the island wasn't saved go into its inventory,
## and the island is saved again right away so they are kept.
static func load_island(starter_radius: int) -> Island:
	var data: Variant = _read(path)
	var island := Island.from_dict(data) if data is Dictionary else null
	if island == null:
		island = Island.create_starter(starter_radius)
	var kept: Variant = _read(blueprint_path)
	if kept is Dictionary:
		island.treasury.blueprints = Treasury.blueprints_from(kept.get("blueprints", 0))
		island.treasury.pity = float(kept.get("pity", 0.0))
		var towers: Array = kept.get("unsaved_towers", [])
		for kind in towers:
			island.treasury.inventory.add(Treasury.blueprint_item(StringName(kind)))
		if not towers.is_empty():
			save(island)
	return island


static func _write(file_path: String, data: Dictionary) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save %s: %s" % [file_path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data, "\t"))


static func _read(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if not data is Dictionary:
		push_warning("Ignoring an unreadable save at %s" % file_path)
		return null
	return data
