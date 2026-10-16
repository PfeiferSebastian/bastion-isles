class_name BattleLog
extends RefCounted
## Battle log for analysis: one JSON line per finished wave (enemies, kills, loot, what each
## building type did, buildings lost, the island's make-up), keeping the last MAX_WAVES waves.
## About 1–2 KB per wave, so the whole file stays around 100–200 KB.

const MAX_WAVES := 100

## Log file (tests point it elsewhere).
static var path := "user://battle_log.jsonl"


## Appends one wave entry and drops the oldest beyond MAX_WAVES.
static func append(entry: Dictionary) -> void:
	var lines := _lines()
	lines.append(JSON.stringify(entry))
	while lines.size() > MAX_WAVES:
		lines.remove_at(0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the battle log: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string("\n".join(lines) + "\n")


## The logged waves, oldest first.
static func entries() -> Array:
	var result: Array = []
	for line in _lines():
		var entry: Variant = JSON.parse_string(line)
		if entry is Dictionary:
			result.append(entry)
	return result


static func count() -> int:
	return _lines().size()


static func size_bytes() -> int:
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file else 0


static func _lines() -> PackedStringArray:
	var result: PackedStringArray = []
	if not FileAccess.file_exists(path):
		return result
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges() != "":
			result.append(line)
	return result
