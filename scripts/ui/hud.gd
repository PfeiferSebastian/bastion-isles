class_name Hud
extends CanvasLayer
## Prototype HUD: controls hint, build tool bar and info about the hovered tile.

## Set by main; the HUD reads hover state and island data from it every frame.
var view: IslandView

@onready var _info: Label = %Info
@onready var _toolbar: Toolbar = %Toolbar


func _ready() -> void:
	_toolbar.tool_selected.connect(func(tool: IslandView.Tool, biome: Biome.Type) -> void:
		if view:
			view.set_tool(tool, biome))


func _process(_delta: float) -> void:
	if view == null:
		return
	var coord := view.hovered_coord
	var tile := view.island.get_tile(coord)
	if tile == null:
		_info.text = ""
		return
	var lines: PackedStringArray = []
	var what := "HQ" if tile.is_hq else "%s · Tier %d" % [Biome.name_of(tile.biome), tile.tier]
	lines.append("Tile (%d, %d) — %s" % [coord.x, coord.y, what])
	var effects := view.island.aura_at(coord)
	if not effects.is_empty():
		lines.append("Auras: " + Auras.describe(effects))
	var tower := tile.tower
	if tower:
		var line := "%s · HP %d / %d" % [String(tower.type).capitalize(), ceili(tower.hp), roundi(view.island.tower_max_hp(coord))]
		if view.island.tower_max_shield(coord) > 0.0:
			line += " · Shield %d / %d" % [ceili(tower.shield), roundi(view.island.tower_max_shield(coord))]
		lines.append(line)
	_info.text = "\n".join(lines)
