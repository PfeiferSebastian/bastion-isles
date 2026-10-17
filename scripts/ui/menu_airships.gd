extends Node2D
## Menu backdrop: small formations of enemy airships (the hull shapes of Enemy) crossing the
## sky from right to left behind the island, with faint smoke trails. Purely decorative.

## Formations in the sky at once.
const FORMATIONS := 3
const KINDS: Array[StringName] = [&"rammer", &"corsair", &"gunboat", &"bomber"]
const SMOKE := Color(0.95, 0.95, 1.0, 0.35)

## Each formation: {position, speed, kind, count, scale}.
var _formations: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for i in FORMATIONS:
		# Spread the first ones over the screen so the sky isn't empty at the start.
		_formations.append(_new_formation(_rng.randf_range(0.15, 1.0)))


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	for i in _formations.size():
		var f := _formations[i]
		f.position.x -= f.speed * delta
		if f.position.x < -120.0:
			_formations[i] = _new_formation(1.0)
	if view.x > 0.0:
		queue_redraw()


## A formation entering at `x_share` of the screen width (1 = just off the right edge).
func _new_formation(x_share: float) -> Dictionary:
	var view := get_viewport_rect().size
	var scale_by := _rng.randf_range(1.0, 1.5)
	return {
		position = Vector2(view.x * x_share + 80.0, _rng.randf_range(view.y * 0.2, view.y * 0.7)),
		speed = _rng.randf_range(28.0, 55.0) * scale_by,
		kind = KINDS[_rng.randi() % KINDS.size()],
		count = _rng.randi_range(2, 5),
		scale = scale_by,
	}


func _draw() -> void:
	for f in _formations:
		for i in f.count:
			# V formation behind the leader.
			var row: int = (i + 1) / 2
			var side := -1.0 if i % 2 == 1 else 1.0
			var at: Vector2 = f.position + Vector2(row * 26.0, side * row * 18.0) * f.scale
			var bob := sin(Time.get_ticks_msec() / 600.0 + i * 1.3) * 2.0
			at.y += bob
			draw_line(at + Vector2(10, 0) * f.scale, at + Vector2(46, 0) * f.scale, SMOKE, 3.0 * f.scale)
			draw_set_transform(at, PI, Vector2.ONE * f.scale)
			_draw_hull(f.kind)
			draw_set_transform(Vector2.ZERO)


## Same hulls as Enemy._draw, pointing along +x (turned to fly left).
func _draw_hull(kind: StringName) -> void:
	match kind:
		&"gunboat":
			draw_colored_polygon(PackedVector2Array([Vector2(12, -6), Vector2(12, 6), Vector2(-10, 9), Vector2(-10, -9)]), Color("5a3a3a"))
			draw_rect(Rect2(4, -2, 14, 4), Color("2a1a1a"))
			draw_circle(Vector2(-2, 0), 5.0, Color("7a4a3a"))
		&"corsair":
			draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(-8, -11), Vector2(-3, 0), Vector2(-8, 11)]), Color("c0502a"))
			draw_line(Vector2(-6, -10), Vector2(-12, -14), Color("2a0d0d"), 2.0)
			draw_line(Vector2(-6, 10), Vector2(-12, 14), Color("2a0d0d"), 2.0)
		&"bomber":
			draw_colored_polygon(PackedVector2Array([Vector2(14, 0), Vector2(6, -14), Vector2(-12, -12), Vector2(-14, 0), Vector2(-12, 12), Vector2(6, 14)]), Color("3a3a44"))
			draw_rect(Rect2(-6, -4, 10, 8), Color("1a1a1e"))
		_:
			var hull := PackedVector2Array([Vector2(14, 0), Vector2(-8, -9), Vector2(-4, 0), Vector2(-8, 9)])
			draw_colored_polygon(hull, Color("7a2a2a"))
			draw_polyline(hull + PackedVector2Array([hull[0]]), Color("2a0d0d"), 1.5, true)
