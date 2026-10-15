class_name IslandSave
extends RefCounted
## Keeps the player's island (layout, towers, gold, blueprints, inventory) between missions
## in a JSON file. Saved when leaving or retreating from a mission and after editing.

const PATH := "user://island.json"


static func save(island: Island) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the island: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(island.to_dict(), "\t"))


## The saved island, or null if there is none (or it can't be read).
static func load_island() -> Island:
	if not FileAccess.file_exists(PATH):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		push_warning("Ignoring an unreadable island save at %s" % PATH)
		return null
	return Island.from_dict(data)
