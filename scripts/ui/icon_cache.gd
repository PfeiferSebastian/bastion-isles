class_name IconCache
extends Node
## Small textures of the inventory icons (tower types, tiles, biomes), rendered once in
## off-screen viewports so text can show them inline (the info window uses them).

const SIZE := 32

var _textures: Dictionary = {}


func _ready() -> void:
	var kinds: Array[StringName] = TowerDefs.TYPES.duplicate()
	kinds.append_array([&"tile", &"forest", &"mountain", &"plains", &"swamp", &"lake"])
	for kind in kinds:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(SIZE, SIZE)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var icon := ToolIcon.new(kind, "", "")
		icon.custom_minimum_size = Vector2(SIZE, SIZE)
		icon.size = Vector2(SIZE, SIZE)
		icon.flat = true
		viewport.add_child(icon)
		add_child(viewport)
		_textures[kind] = viewport.get_texture()


## The icon for `kind` (a tower type, &"tile" or a biome name), or null.
func get_icon(kind: StringName) -> Texture2D:
	return _textures.get(kind)


## Icon kind of a biome (for biome tiles and their effects).
static func biome_kind(biome: Biome.Type) -> StringName:
	return &"tile" if biome == Biome.Type.NEUTRAL else StringName(Biome.name_of(biome).to_lower())
