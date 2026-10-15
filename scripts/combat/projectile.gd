class_name Projectile
extends Node2D
## Homing projectile: flies to its target and applies the attack profile on arrival.

var target: Enemy
var profile: AttackProfile


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return
	var to := target.global_position - global_position
	var step := profile.projectile_speed * delta
	if to.length() <= step:
		profile.apply_hit(target)
		queue_free()
	else:
		global_position += to.normalized() * step


func _draw() -> void:
	draw_circle(Vector2.ZERO, profile.projectile_size + 1.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, profile.projectile_size, profile.color)
