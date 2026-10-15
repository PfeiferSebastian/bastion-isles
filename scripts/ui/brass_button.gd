class_name BrassButton
extends Button
## Menu button with a riveted brass frame and a glossy light reflection on top of the theme's
## plate. A soft shine sweeps across while hovered.

const RIVET_SPACING := 34.0
const FRAME_INSET := 5.0

var _shine := -1.0


func _ready() -> void:
	mouse_entered.connect(func() -> void: _shine = 0.0)


func _process(delta: float) -> void:
	if _shine >= 0.0:
		_shine += delta * 1.6
		if _shine > 1.4:
			_shine = -1.0
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var inner := r.grow(-FRAME_INSET)
	var pressed := is_pressed() and button_pressed
	# Gloss: a bright band over the upper half, stronger near the top edge.
	var gloss_h := inner.size.y * 0.45
	for i in 6:
		var t := float(i) / 6.0
		draw_rect(Rect2(inner.position + Vector2(4, 2 + gloss_h * t), Vector2(inner.size.x - 8, gloss_h / 6.0)),
			Color(1, 1, 1, (0.16 if not pressed else 0.06) * (1.0 - t)))
	# Thin specular line just below the frame.
	draw_line(inner.position + Vector2(10, 3), Vector2(inner.end.x - 10, inner.position.y + 3), Color(1, 1, 1, 0.35), 1.0, true)
	# Thick brass frame: lit top edge, shaded bottom edge, dark inner line.
	var band := r.grow(-2.5)
	draw_rect(band, MenuTheme.BRASS, false, 5.0)
	draw_line(band.position + Vector2(3, -1.5), Vector2(band.end.x - 3, band.position.y - 1.5), MenuTheme.BRASS_LIGHT, 1.2)
	draw_line(Vector2(band.position.x + 3, band.end.y + 1.5), band.end + Vector2(-3, 1.5), MenuTheme.BRASS_DARK, 1.2)
	draw_rect(inner, Color(MenuTheme.BRASS_DARK, 0.9), false, 1.5)
	# Rivets along the frame.
	var count := maxi(2, int(inner.size.x / RIVET_SPACING))
	for i in count + 1:
		var x := lerpf(inner.position.x + 6, inner.end.x - 6, float(i) / count)
		_rivet(Vector2(x, r.position.y + 3.5))
		_rivet(Vector2(x, r.end.y - 3.5))
	_rivet(Vector2(r.position.x + 3.5, r.get_center().y))
	_rivet(Vector2(r.end.x - 3.5, r.get_center().y))
	# Hover shine: a slanted light streak sweeping across.
	if _shine >= 0.0:
		var x := lerpf(-40.0, size.x + 40.0, _shine)
		var streak := PackedVector2Array([Vector2(x, inner.position.y), Vector2(x + 14, inner.position.y),
			Vector2(x - 6, inner.end.y), Vector2(x - 20, inner.end.y)])
		var clipped := Geometry2D.intersect_polygons(streak, PackedVector2Array([inner.position,
			Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]))
		for part in clipped:
			draw_colored_polygon(part, Color(1, 1, 1, 0.22))


func _rivet(at: Vector2) -> void:
	draw_circle(at + Vector2(0.6, 0.8), 2.6, Color(0, 0, 0, 0.45))
	draw_circle(at, 2.4, MenuTheme.BRASS_DARK)
	draw_circle(at + Vector2(-0.6, -0.6), 1.5, MenuTheme.BRASS_LIGHT)
