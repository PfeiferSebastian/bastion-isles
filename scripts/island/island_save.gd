class_name IslandSave
extends RefCounted
## Keeps the player's island (layout, towers, gold, blueprints, inventory) between missions
## in a JSON file. Saved when leaving or retreating from a mission and after editing.
##
## Blueprints are kept apart as well and saved the moment one is found, so they survive a
## mission that ends any other way (quitting the game, a crash). Towers completed from
## blueprints since the last island save are listed there too and handed out on the next load.
## Tower XP from a running mission is kept apart too (save_tower_xp, every few seconds and when
## the window closes): only XP, so closing the game never keeps the loot a retreat would cost.

## Save files (tests point these elsewhere so they never touch the player's saves).
static var path := "user://island.json"
static var blueprint_path := "user://blueprints.json"
static var xp_path := "user://tower_xp.json"


static func save(island: Island) -> void:
	_write(path, island.to_dict())
	# The island save holds the latest XP now.
	if FileAccess.file_exists(xp_path):
		DirAccess.remove_absolute(xp_path)
	# The island save now holds every completed tower.
	island.unsaved_towers.clear()
	save_blueprints(island)


## Blueprints and the towers and tiles bought with them since the last island save.
static func save_blueprints(island: Island) -> void:
	_write(blueprint_path, {blueprints = island.treasury.blueprints, unsaved_towers = island.unsaved_towers,
		pity = island.treasury.pity})


## Every tower's XP as it is now: {towers = [{q, r, type, tier, xp}]}.
static func save_tower_xp(island: Island) -> void:
	var towers: Array = []
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower:
			towers.append({q = coord.x, r = coord.y, type = String(tower.type), tier = tower.tier, xp = tower.xp})
	_write(xp_path, {towers = towers})


## Gives towers the XP from save_tower_xp where the same type and tier still stands on the hex
## and the kept XP is higher.
static func _apply_tower_xp(island: Island) -> void:
	var data: Variant = _read(xp_path)
	if not data is Dictionary:
		return
	for entry: Dictionary in data.get("towers", []):
		var tower := island.get_tower(Vector2i(int(entry.q), int(entry.r)))
		if tower and String(tower.type) == String(entry.type) and tower.tier == int(entry.tier) and float(entry.xp) > tower.xp:
			tower.xp = float(entry.xp)
			tower.level_seen = tower.level()


## The saved island (or a fresh one with `starter_radius`), with the separately kept
## blueprints and tower XP applied. Towers completed while the island wasn't saved go into its inventory,
## and the island is saved again right away so they are kept.
static func load_island(starter_radius: int) -> Island:
	var data: Variant = _read(path)
	var island := Island.from_dict(data) if data is Dictionary else null
	if island == null:
		island = Island.create_starter(starter_radius)
	else:
		_apply_tower_xp(island)
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
