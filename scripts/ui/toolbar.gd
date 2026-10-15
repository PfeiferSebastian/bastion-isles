class_name Toolbar
extends HBoxContainer
## Build tool bar: Tower, Tile and one button per biome stone. Number keys 1–7 select.

signal tool_selected(tool: IslandView.Tool, biome: Biome.Type)

const BIOMES: Array[Biome.Type] = [
	Biome.Type.FOREST, Biome.Type.MOUNTAIN, Biome.Type.DESERT, Biome.Type.PLAINS, Biome.Type.SWAMP,
]

var _group := ButtonGroup.new()


func _ready() -> void:
	_add_button("Tower", KEY_1, IslandView.Tool.TOWER, Biome.Type.NEUTRAL, Color("4a4f5c"))
	_add_button("Tile", KEY_2, IslandView.Tool.TILE, Biome.Type.NEUTRAL, Biome.color_of(Biome.Type.NEUTRAL))
	for i in BIOMES.size():
		var biome := BIOMES[i]
		_add_button(Biome.name_of(biome), KEY_3 + i, IslandView.Tool.BIOME, biome, Biome.color_of(biome))
	(get_child(0) as Button).button_pressed = true


func _add_button(label: String, key: int, tool: IslandView.Tool, biome: Biome.Type, swatch: Color) -> void:
	var button := Button.new()
	button.text = "%d  %s" % [key - KEY_0, label]
	button.toggle_mode = true
	button.button_group = _group
	button.focus_mode = Control.FOCUS_NONE
	button.icon = _swatch(swatch)

	var shortcut_event := InputEventKey.new()
	shortcut_event.keycode = key
	button.shortcut = Shortcut.new()
	button.shortcut.events = [shortcut_event]

	button.toggled.connect(func(on: bool) -> void:
		if on:
			tool_selected.emit(tool, biome))
	add_child(button)


static func _swatch(color: Color) -> Texture2D:
	var image := Image.create_empty(14, 14, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
