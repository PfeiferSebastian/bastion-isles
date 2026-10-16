class_name FogLayer
extends Node2D
## Draws the fog of war as clouds over the sky and enemies, and ticks the fog model.
## Thick fog: dense clouds hide everything. Grey fog: light clouds with dark shadows where
## enemies are. V toggles the fog (debug).
## Each fog level is drawn opaque into its own CanvasGroup, which then fades the whole group
## at once: overlapping hexes and puffs blend into one cloud bank without a visible grid.

@export var island_view_path: NodePath
@export var combat_path: NodePath

const THICK_COLOR := Color(0.92, 0.93, 0.98)
const THICK_ALPHA := 0.97
const GREY_COLOR := Color(0.82, 0.86, 0.94)
const GREY_ALPHA := 0.82
const PUFF_COLOR := Color(1, 1, 1)
const SHADOW_COLOR := Color(0.12, 0.12, 0.2, 0.5)

var fog: FogOfWar
var enabled := true

var _view: IslandView
var _combat: Combat
var _hex: PackedVector2Array
var _thick := Node2D.new()
var _grey := Node2D.new()
var _shadows := Node2D.new()


func _ready() -> void:
	_view = get_node(island_view_path)
	_combat = get_node(combat_path)
	fog = FogOfWar.new(_view.island)
	_combat.fog = fog
	_hex = HexMath.corners(_view.hex_size * 1.08)
	for layer in [[_thick, THICK_ALPHA, FogOfWar.Level.THICK, THICK_COLOR], [_grey, GREY_ALPHA, FogOfWar.Level.GREY, GREY_COLOR]]:
		var group := CanvasGroup.new()
		group.self_modulate = Color(1, 1, 1, layer[1])
		group.add_child(layer[0])
		add_child(group)
		layer[0].draw.connect(_draw_level.bind(layer[0], layer[2], layer[3]))
	_shadows.draw.connect(_draw_shadows)
	add_child(_shadows)


func _process(delta: float) -> void:
	if not enabled:
		return
	fog.tick(delta)
	_thick.queue_redraw()
	_grey.queue_redraw()
	_shadows.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_V:
		enabled = not enabled
		_combat.fog = fog if enabled else null
		visible = enabled


## One fog level, opaque (its CanvasGroup fades it): a hex per cell plus a few cloud puffs
## that spill over the edges so the bank looks round, not tiled.
func _draw_level(canvas: Node2D, level: FogOfWar.Level, color: Color) -> void:
	var size := _view.hex_size
	for cell in fog.cells():
		if fog.level_at(cell) != level:
			continue
		var center := to_local(_view.hex_center_world(cell))
		var points := PackedVector2Array()
		for p in _hex:
			points.append(center + p)
		canvas.draw_colored_polygon(points, color)
		var h := absi(cell.x * 73856093 ^ cell.y * 19349663)
		canvas.draw_circle(center + Vector2((h % 7 - 3) * 4.0, (h % 5 - 2) * 4.0), size * 0.7, color)
		canvas.draw_circle(center + Vector2(((h / 7) % 7 - 3) * 5.0, ((h / 5) % 5 - 2) * 5.0), size * 0.35, color.lerp(PUFF_COLOR, 0.15))


## Dark shadows of enemies under grey fog.
func _draw_shadows() -> void:
	for enemy in _combat.enemies():
		if fog.level_at(_view.world_to_hex(enemy.global_position)) == FogOfWar.Level.GREY:
			_shadows.draw_set_transform(to_local(enemy.global_position), 0.0, Vector2(1.0, 0.6))
			_shadows.draw_circle(Vector2.ZERO, 14.0, SHADOW_COLOR)
	_shadows.draw_set_transform(Vector2.ZERO)
