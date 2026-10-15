class_name FogLayer
extends Node2D
## Draws the fog of war as clouds over the sky and enemies, and ticks the fog model.
## Thick fog: dense clouds hide everything. Grey fog: light clouds with dark shadows where
## enemies are. V toggles the fog (debug).

@export var island_view_path: NodePath
@export var combat_path: NodePath

const THICK_COLOR := Color(0.94, 0.95, 0.99, 0.97)
const GREY_COLOR := Color(0.82, 0.86, 0.94, 0.82)
const PUFF_COLOR := Color(1, 1, 1, 0.35)
const SHADOW_COLOR := Color(0.12, 0.12, 0.2, 0.5)

var fog: FogOfWar
var enabled := true

var _view: IslandView
var _combat: Combat
var _hex: PackedVector2Array


func _ready() -> void:
	_view = get_node(island_view_path)
	_combat = get_node(combat_path)
	fog = FogOfWar.new(_view.island)
	_combat.fog = fog
	var corners := HexMath.corners(_view.hex_size * 1.03)
	_hex = corners


func _process(delta: float) -> void:
	if not enabled:
		return
	fog.tick(delta)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_V:
		enabled = not enabled
		_combat.fog = fog if enabled else null
		visible = enabled


func _draw() -> void:
	var shadows: Array[Vector2] = []
	for enemy in _combat.enemies():
		if fog.level_at(_view.world_to_hex(enemy.global_position)) == FogOfWar.Level.GREY:
			shadows.append(to_local(enemy.global_position))
	for cell in fog.cells():
		var level := fog.level_at(cell)
		if level == FogOfWar.Level.OPEN:
			continue
		var center := to_local(_view.hex_center_world(cell))
		var points := PackedVector2Array()
		for p in _hex:
			points.append(center + p)
		draw_colored_polygon(points, THICK_COLOR if level == FogOfWar.Level.THICK else GREY_COLOR)
		# A couple of puffs per hex so it reads as clouds, not tiles.
		var h := absi(cell.x * 73856093 ^ cell.y * 19349663)
		var size := _view.hex_size
		draw_circle(center + Vector2((h % 7 - 3) * 4.0, (h % 5 - 2) * 4.0), size * 0.45, PUFF_COLOR)
		draw_circle(center + Vector2(((h / 7) % 7 - 3) * 5.0, ((h / 5) % 5 - 2) * 5.0), size * 0.3, PUFF_COLOR)
	for shadow in shadows:
		draw_set_transform(shadow, 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, 14.0, SHADOW_COLOR)
		draw_set_transform(Vector2.ZERO)
