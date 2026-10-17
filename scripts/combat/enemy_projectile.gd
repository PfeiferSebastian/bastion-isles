class_name EnemyProjectile
extends Node2D
## Enemy shot: flies to the point it was aimed at (not homing). `blocks(world_position)` is
## checked along the way; the shot stops at the first point it returns true for (a wall) and
## calls `on_hit(world_position)` there, otherwise at the aim point.

## Distance in px between the points checked against `blocks`, so fast shots can't skip a wall.
const CHECK_STEP := 6.0

var target_position := Vector2.ZERO
var speed := 300.0
var on_hit: Callable
var blocks: Callable


func _process(delta: float) -> void:
	var to := target_position - global_position
	var step := minf(speed * delta, to.length())
	if to.length() > 0.01:
		rotation = to.angle()
	var direction := to.normalized()
	var travelled := 0.0
	while travelled < step:
		travelled = minf(travelled + CHECK_STEP, step)
		var point := global_position + direction * travelled
		if blocks.is_valid() and blocks.call(point):
			_land(point)
			return
	if step >= to.length():
		_land(target_position)
	else:
		global_position += direction * step


func _land(point: Vector2) -> void:
	global_position = point
	on_hit.call(point)
	queue_free()


func _draw() -> void:
	draw_line(Vector2(-6, 0), Vector2(3, 0), Color(1, 0.55, 0.2, 0.5), 5.0, true)
	draw_line(Vector2(-5, 0), Vector2(3, 0), Color("ffb070"), 2.0, true)
