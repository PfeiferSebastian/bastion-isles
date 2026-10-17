class_name Projectile
extends Node2D
## Homing projectile: flies to its target and applies the attack profile on arrival. Its look
## follows the profile's `style` (see _draw).

var target: Enemy
var profile: AttackProfile
## Called after the hit with (target, its HP before), for the analysis counters.
var on_hit: Callable
## Called with the world position where the shot lands and its flight angle (impact effects).
var on_land: Callable
## Range falloff (see AttackProfile.performance) and whether extra effects apply.
var factor := 1.0
var specials := true
## Seconds in flight (wobble of slime globs).
var _age := 0.0

const SHELL_DARK := Color("6b4a1e")
const THORN_DARK := Color("3a2414")
## Thorn twig: this many pieces, each bending by THORN_BEND (radians) the other way after
## the thorn at its joint.
const THORN_SEGMENTS := 4
const THORN_BEND := 0.3


func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return
	_age += delta
	var to := target.global_position - global_position
	if to.length() > 0.01:
		rotation = to.angle()
	if profile.style == &"slime":
		queue_redraw()
	var step := profile.projectile_speed * delta
	if to.length() <= step:
		var before := target.hp
		profile.apply_hit(target, factor, specials)
		if on_hit.is_valid():
			on_hit.call(target, before)
		if on_land.is_valid():
			on_land.call(target.global_position, rotation)
		queue_free()
	else:
		global_position += to.normalized() * step


## Drawn along +x, the direction of flight.
func _draw() -> void:
	var s := profile.projectile_size
	match profile.style:
		&"shell":
			# Brass shell: a faint streak behind, a body with a darker base and a pointed nose.
			draw_line(Vector2(-s * 4.0, 0), Vector2(-s, 0), Color(profile.color, 0.3), s * 0.9, true)
			draw_rect(Rect2(-s * 1.2, -s * 0.55, s * 1.8, s * 1.1), profile.color)
			draw_rect(Rect2(-s * 1.2, -s * 0.55, s * 0.45, s * 1.1), SHELL_DARK)
			draw_colored_polygon(PackedVector2Array([Vector2(s * 0.6, -s * 0.55), Vector2(s * 1.4, 0), Vector2(s * 0.6, s * 0.55)]), profile.color.lightened(0.25))
		&"tracer":
			# Glowing tracer: a long soft glow with a hot white-yellow core.
			draw_line(Vector2(-s * 5.0, 0), Vector2(s, 0), Color(profile.color, 0.35), s * 1.6, true)
			draw_line(Vector2(-s * 3.5, 0), Vector2(s, 0), profile.color.lightened(0.5), s * 0.6, true)
		&"thorns":
			# Crooked brown twig: after each thorn the twig kinks a little the other way.
			var points := PackedVector2Array([Vector2(-s * 2.4, 0)])
			var angle := THORN_BEND / 2.0
			for k in THORN_SEGMENTS:
				points.append(points[k] + Vector2.from_angle(angle) * s * 1.2)
				angle -= THORN_BEND * (1 if k % 2 == 0 else -1)
			draw_polyline(points, THORN_DARK, 2.6, true)
			draw_polyline(points, profile.color, 1.4, true)
			# Thorns at the joints, on alternating sides, leaning back like rose thorns.
			for k in range(1, THORN_SEGMENTS):
				var along := (points[k + 1] - points[k - 1]).normalized()
				var out := along.orthogonal() * (1 if k % 2 == 0 else -1)
				draw_colored_polygon(PackedVector2Array([points[k] - along * s * 0.35, points[k] + out * s * 0.75 - along * s * 0.2,
					points[k] + along * s * 0.25]), THORN_DARK)
		&"slime":
			# Wobbly slime glob: squashes and stretches, a lighter shine and a drip trailing behind.
			var wobble := sin(_age * 18.0) * 0.18
			var trail := Color(profile.color, 0.45)
			draw_circle(Vector2(-s * 1.7, sin(_age * 11.0) * s * 0.3), s * 0.35, trail)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + wobble, 1.0 - wobble))
			draw_circle(Vector2.ZERO, s + 0.8, Color(profile.color.darkened(0.5), 0.6))
			draw_circle(Vector2.ZERO, s, profile.color)
			draw_circle(Vector2(s * 0.3, -s * 0.35), s * 0.3, Color(1, 1, 1, 0.55))
			draw_set_transform(Vector2.ZERO)
		_:
			draw_circle(Vector2.ZERO, s + 1.0, Color(0, 0, 0, 0.35))
			draw_circle(Vector2.ZERO, s, profile.color)
