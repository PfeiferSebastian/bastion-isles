class_name Toolbar
extends HBoxContainer
## Build bar: hexagon symbol buttons for Tower, Tile and each biome stone. Number keys 1–7 select.

signal tool_selected(tool: IslandView.Tool, biome: Biome.Type)

const BIOMES: Array[Biome.Type] = [
	Biome.Type.FOREST, Biome.Type.MOUNTAIN, Biome.Type.PLAINS, Biome.Type.SWAMP, Biome.Type.LAKE,
]

var _group := ButtonGroup.new()


func _ready() -> void:
	_add_button(&"tower", "Tower", 1, IslandView.Tool.TOWER, Biome.Type.NEUTRAL)
	_add_button(&"tile", "Tile", 2, IslandView.Tool.TILE, Biome.Type.NEUTRAL)
	for i in BIOMES.size():
		var biome := BIOMES[i]
		var name := Biome.name_of(biome)
		_add_button(StringName(name.to_lower()), name + " stone", 3 + i, IslandView.Tool.BIOME, biome)
	(get_child(0) as Button).button_pressed = true


func _add_button(kind: StringName, label: String, number: int, tool: IslandView.Tool, biome: Biome.Type) -> void:
	var button := ToolIcon.new(kind, number, label)
	button.button_group = _group

	var shortcut_event := InputEventKey.new()
	shortcut_event.keycode = KEY_0 + number
	button.shortcut = Shortcut.new()
	button.shortcut.events = [shortcut_event]

	button.toggled.connect(func(on: bool) -> void:
		if on:
			tool_selected.emit(tool, biome))
	add_child(button)
