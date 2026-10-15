class_name ProgressTube
extends Control
## Thin brass tube filled with green liquid, with a short tick every 5%. Drawn in code.

## Fill from 0 to 1.
@export_range(0.0, 1.0) var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var tick_step := 0.05

const LIQUID := Color("5fd068")
const LIQUID_DARK := Color("2f7a35")
const GLASS := Color(0.08, 0.1, 0.09, 0.85)

var _time := 0.0
## Shown liquid level eases toward `value`, so gains slosh in instead of jumping.
var _shown := 0.0


func _process(delta: float) -> void:
	_time += delta
	_shown = lerpf(_shown, value, minf(1.0, delta * 4.0))
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var cap := h * 1.1
	var tube := Rect2(Vector2(cap * 0.6, 0), Vector2(size.x - cap * 1.2, h))
	# Brass casing with a highlight on top and a shadow below.
	draw_rect(tube.grow(1.5), MenuTheme.BRASS_DARK)
	draw_rect(tube, MenuTheme.BRASS)
	draw_line(tube.position + Vector2(0, 1.5), Vector2(tube.end.x, tube.position.y + 1.5), MenuTheme.BRASS_LIGHT, 1.0)
	# Glass and liquid.
	var glass := tube.grow(-2.5)
	draw_rect(glass, GLASS)
	if _shown > 0.001:
		var fill := Rect2(glass.position, Vector2(glass.size.x * _shown, glass.size.y))
		draw_rect(fill, LIQUID_DARK)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.55)), LIQUID)
		# Slow moving shine on the liquid surface.
		var shine_x := fmod(_time * 60.0, maxf(fill.size.x, 1.0))
		draw_rect(Rect2(fill.position + Vector2(shine_x, 1), Vector2(minf(18.0, fill.size.x - shine_x), 1.5)), Color(1, 1, 1, 0.35))
		# Meniscus at the front of the liquid.
		draw_line(Vector2(fill.end.x, fill.position.y), Vector2(fill.end.x, fill.end.y), Color("b7f0a0"), 1.5)
	# A short tick every 5%, longer every 25%.
	var steps := int(round(1.0 / tick_step))
	for i in range(1, steps):
		var x := glass.position.x + glass.size.x * i * tick_step
		var long := i % 5 == 0
		var tick_h := glass.size.y * (0.7 if long else 0.4)
		draw_line(Vector2(x, glass.position.y), Vector2(x, glass.position.y + tick_h), Color(MenuTheme.BRASS_LIGHT, 0.85 if long else 0.6), 1.0)
	# End caps like pipe flanges.
	for x in [cap * 0.3, size.x - cap * 0.3]:
		var flange := Rect2(Vector2(x - cap * 0.3, -2), Vector2(cap * 0.6, h + 4))
		draw_rect(flange, MenuTheme.BRASS_DARK)
		draw_rect(flange.grow(-1.5), MenuTheme.BRASS)
		draw_circle(flange.get_center(), 1.5, MenuTheme.BRASS_DARK)
