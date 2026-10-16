class_name ConsoleDeck
extends Control
## Brass and iron console along the bottom of the combat screen, drawn in code behind the
## inventory, the gold plaque and the info window. It follows those windows: a low deck
## under the inventory that steps up into a raised cabinet for the info window on the
## right. Bevelled window frames with rivets and a brass rail along the top edge give it a 3D
## steampunk look. Static: it only redraws when a window moves.
## Blocks clicks to the map inside its outline.

const IRON := Color("3a2e24")
const IRON_LIGHT := Color("54432f")
const IRON_DARK := Color("1f1813")
const RAIL := 12.0
## Gap between a window and the console edge.
const MARGIN := 16.0
const STEP := 26.0

## Windows sitting on the console: [inventory, info window, gold plaque].
var windows: Array[Control] = []:
	set(value):
		windows = value
		for window in windows:
			window.item_rect_changed.connect(queue_redraw)
		queue_redraw()

var _outline := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _has_point(point: Vector2) -> bool:
	return _outline.size() > 2 and Geometry2D.is_point_in_polygon(point, _outline)


func _draw() -> void:
	if windows.size() < 2:
		return
	var low := windows[0].get_rect().grow(MARGIN)
	var high := windows[1].get_rect().grow(MARGIN)
	var step_x := minf(high.position.x, size.x)
	_outline = PackedVector2Array([
		Vector2(0, size.y), Vector2(0, low.position.y),
		Vector2(step_x - STEP, low.position.y), Vector2(step_x, low.position.y - STEP),
		Vector2(step_x, high.position.y + STEP), Vector2(step_x + STEP, high.position.y),
		Vector2(size.x, high.position.y), Vector2(size.x, size.y),
	])
	_draw_body(low.position.y)
	_draw_rail()
	for i in windows.size():
		_draw_window_frame(windows[i].get_rect(), i == 2)


## Iron plates with a soft top light, seams and rivets.
func _draw_body(top: float) -> void:
	draw_colored_polygon(_outline, IRON)
	# Light falls from above: a lighter band under the rail, darker towards the bottom.
	var lit := Geometry2D.intersect_polygons(_outline, PackedVector2Array([
		Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, top + 26.0), Vector2(0, top + 26.0)]))
	for poly in lit:
		draw_colored_polygon(poly, IRON_LIGHT)
	draw_rect(Rect2(0, size.y - 22.0, size.x, 22.0), Color(IRON_DARK, 0.7))
	# Vertical plate seams with rivets.
	var x := 140.0
	while x < size.x:
		var y_top := _top_at(x) + RAIL
		draw_line(Vector2(x, y_top), Vector2(x, size.y), IRON_DARK, 2.0)
		draw_line(Vector2(x + 2, y_top), Vector2(x + 2, size.y), Color(IRON_LIGHT, 0.6), 1.0)
		x += 260.0


## Brass rail along the top edge of the console, with flanges and rivets.
func _draw_rail() -> void:
	var top := _outline.slice(1, _outline.size() - 1)
	draw_polyline(top, Color(0, 0, 0, 0.35), RAIL + 10.0, true)
	draw_polyline(top, MenuTheme.BRASS_DARK, RAIL + 3.0, true)
	draw_polyline(top, MenuTheme.BRASS, RAIL, true)
	var shine := PackedVector2Array()
	for p in top:
		shine.append(p + Vector2(0, -RAIL * 0.22))
	draw_polyline(shine, MenuTheme.BRASS_LIGHT, 2.0, true)
	for i in top.size() - 1:
		var a := top[i]
		var b := top[i + 1]
		var steps := int(a.distance_to(b) / 90.0)
		for k in range(1, steps + 1):
			SteamParts.rivet(self, a.lerp(b, float(k) / (steps + 1)), 3.0)


## Bevelled brass frame around a window: light top-left, dark bottom-right, sunken edge
## inside, rivets in the corners. The gold plaque gets bolts at its ends instead.
func _draw_window_frame(r: Rect2, plaque: bool) -> void:
	var frame := r.grow(7.0)
	draw_rect(frame.grow(3.0), Color(0, 0, 0, 0.45))
	draw_rect(frame, MenuTheme.BRASS_DARK)
	# Outer bevel.
	draw_polyline(PackedVector2Array([Vector2(frame.position.x, frame.end.y), frame.position, Vector2(frame.end.x, frame.position.y)]), MenuTheme.BRASS_LIGHT, 3.0)
	draw_polyline(PackedVector2Array([Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]), MenuTheme.BRASS_DARK.darkened(0.35), 3.0)
	draw_rect(frame.grow(-3.0), MenuTheme.BRASS)
	# Sunken inner edge: shadow on top-left.
	var inner := r.grow(2.0)
	draw_rect(inner, IRON_DARK)
	draw_polyline(PackedVector2Array([Vector2(inner.end.x, inner.position.y), Vector2(inner.end.x, inner.end.y), Vector2(inner.position.x, inner.end.y)]), MenuTheme.BRASS_LIGHT, 1.5)
	if plaque:
		for p in [Vector2(frame.position.x - 6, frame.get_center().y), Vector2(frame.end.x + 6, frame.get_center().y)]:
			draw_circle(p, 6.0, MenuTheme.BRASS_DARK)
			draw_circle(p, 4.5, MenuTheme.BRASS)
			draw_line(p - Vector2(3, 0), p + Vector2(3, 0), MenuTheme.IRON, 1.5)
		return
	for p in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
		SteamParts.rivet(self, p + (frame.get_center() - p).sign() * 4.5, 2.6)


## Height of the console's top edge at `x`.
func _top_at(x: float) -> float:
	for i in range(1, _outline.size() - 2):
		var a := _outline[i]
		var b := _outline[i + 1]
		if x >= a.x and x <= b.x and b.x > a.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return _outline[1].y
