extends Node2D
## Tower visual, drawn by TowerArt: a top-down building per type in the material of the
## biome below. Neighbouring towers of the same type form one combined building, drawn by
## the first of them (group_art). Pops in when spawned
## and again whenever its type changes.

@export var tower_type: StringName = &"attack":
	set(value):
		tower_type = value
		if is_inside_tree():
			_pop()
			queue_redraw()

@export var radius := 18.0
## Must match the island view, so links reach exactly to the shared hex edge.
@export var hex_size := 48.0

## Biome of the tile below, set by the island view.
var biome: Biome.Type = Biome.Type.NEUTRAL:
	set(value):
		if value != biome:
			biome = value
			queue_redraw()
## Which of the 6 neighbours (HexMath.DIRECTIONS order) hold a tower of the same type.
var links: Array[bool] = [false, false, false, false, false, false]:
	set(value):
		if value != links:
			links = value
			queue_redraw()

## Set on the first tower of a combined building (see IslandView._group_art): it then draws
## the whole building over all its hexes. Empty for single towers and walls.
var group_art: Dictionary = {}:
	set(value):
		if value != group_art:
			group_art = value
			queue_redraw()

## Turret direction in radians; 0 points right, -PI/2 (default) points up.
var aim_angle := -PI / 2.0:
	set(value):
		if not is_equal_approx(value, aim_angle):
			aim_angle = value
			queue_redraw()


func _ready() -> void:
	_pop()


func _pop() -> void:
	scale = Vector2(0.3, 0.3)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var link_length := HexMath.SQRT3 * hex_size / 2.0
	if group_art.is_empty():
		TowerArt.draw(self, tower_type, biome, Vector2.ZERO, radius, links, link_length, aim_angle)
	else:
		TowerArt.draw_group(self, tower_type, group_art, radius, link_length, aim_angle)
