class_name EnemyProjectile
extends Node2D
## Enemy shot: flies to the point it was aimed at (not homing) and calls `on_hit` there.

var target_position := Vector2.ZERO
var speed := 300.0
var on_hit: Callable


func _process(delta: float) -> void:
	var to := target_position - global_position
	var step := speed * delta
	if to.length() <= step:
		global_position = target_position
		on_hit.call()
		queue_free()
	else:
		global_position += to.normalized() * step
		rotation = to.angle()


func _draw() -> void:
	draw_line(Vector2(-6, 0), Vector2(3, 0), Color(1, 0.55, 0.2, 0.5), 5.0, true)
	draw_line(Vector2(-5, 0), Vector2(3, 0), Color("ffb070"), 2.0, true)
