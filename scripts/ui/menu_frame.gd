extends Control
## Decorative steampunk frame for the main menu, drawn in code: brass border with rivets,
## copper pipes with a pressure gauge, turning corner gears, hanging moss at the top and
## a grassy rock ledge growing over the bottom edge.

const BRASS := MenuTheme.BRASS
const BRASS_LIGHT := MenuTheme.BRASS_LIGHT
const BRASS_DARK := MenuTheme.BRASS_DARK
const COPPER := MenuTheme.COPPER
const IRON := MenuTheme.IRON
const ROCK := Color("6b5d52")
const ROCK_DARK := Color("43392f")
const GRASS := Color("4f9a3a")
const GRASS_LIGHT := Color("7cc35a")

const INSET := 12.0
const BAR := 14.0
const GEAR_RADIUS := 44.0

var _time := 0.0
var _rocks := PackedVector2Array()
var _blades: Array[PackedFloat32Array] = []  # x, height, lean per blade
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build_ledge)
	_build_ledge()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_pipes()
	_draw_border()
	_draw_moss()
	_draw_ledge()
	_draw_gears()


# --- Pieces --------------------------------------------------------------

func _draw_border() -> void:
	var rect := Rect2(Vector2(INSET, INSET), size - Vector2(INSET, INSET) * 2.0)
	draw_rect(rect.grow(BAR * 0.5), BRASS_DARK, false, 3.0)
	draw_rect(rect, BRASS, false, BAR)
	draw_rect(rect.grow(-BAR * 0.5 + 2.0), BRASS_LIGHT, false, 1.5)
	draw_rect(rect.grow(-BAR * 0.5 - 1.0), Color(0, 0, 0, 0.5), false, 2.0)
	# Rivets along the bar.
	var step := 56.0
	var x := rect.position.x + step
	while x < rect.end.x - step * 0.5:
		_rivet(Vector2(x, rect.position.y))
		x += step
	var y := rect.position.y + step
	while y < rect.end.y - step * 0.5:
		_rivet(Vector2(rect.position.x, y))
		_rivet(Vector2(rect.end.x, y))
		y += step


func _rivet(at: Vector2) -> void:
	draw_circle(at, 3.6, BRASS_DARK)
	draw_circle(at + Vector2(-0.8, -0.8), 2.4, BRASS_LIGHT)


## Copper pipes down both sides, with joint rings and a pressure gauge on the left.
func _draw_pipes() -> void:
	for side in [INSET + 30.0, size.x - INSET - 30.0]:
		var top := INSET + 70.0
		var bottom := size.y - 120.0
		draw_line(Vector2(side, top), Vector2(side, bottom), COPPER.darkened(0.35), 12.0)
		draw_line(Vector2(side, top), Vector2(side, bottom), COPPER, 8.0)
		draw_line(Vector2(side - 2, top), Vector2(side - 2, bottom), COPPER.lightened(0.35), 2.0)
		var y := top + 40.0
		while y < bottom:
			draw_rect(Rect2(side - 9, y - 4, 18, 8), BRASS)
			draw_rect(Rect2(side - 9, y - 4, 18, 8), BRASS_DARK, false, 1.5)
			y += 90.0
	var gauge := Vector2(INSET + 30.0, size.y * 0.42)
	draw_circle(gauge, 22.0, BRASS_DARK)
	draw_circle(gauge, 19.0, Color("efe4c8"))
	for i in 7:
		var a := deg_to_rad(150.0 + i * 40.0)
		draw_line(gauge + Vector2.from_angle(a) * 13.0, gauge + Vector2.from_angle(a) * 17.0, IRON, 1.5)
	var needle := deg_to_rad(210.0 + 70.0 * (0.5 + 0.5 * sin(_time * 1.3)) + 6.0 * sin(_time * 9.0))
	draw_line(gauge, gauge + Vector2.from_angle(needle) * 15.0, Color("a8322a"), 2.0, true)
	draw_circle(gauge, 3.0, IRON)


## Moss and vines hanging from the top bar.
func _draw_moss() -> void:
	_rng.seed = 7
	var x := INSET + 80.0
	while x < size.x - INSET - 80.0:
		var length := _rng.randf_range(14.0, 46.0)
		var sway := sin(_time * 0.8 + x * 0.05) * 3.0
		var top := Vector2(x, INSET + BAR * 0.5)
		var tip := top + Vector2(sway, length)
		draw_line(top, tip, GRASS.darkened(0.2), 2.0, true)
		for k in int(length / 10.0):
			var p := top.lerp(tip, (k + 1) * 10.0 / length)
			draw_circle(p + Vector2(3 if k % 2 == 0 else -3, 0), 2.6, GRASS_LIGHT if k % 2 == 0 else GRASS)
		x += _rng.randf_range(26.0, 70.0)


## Rocky ledge with a grassy top, overgrowing the bottom of the frame.
func _build_ledge() -> void:
	_rng.seed = 42
	_rocks.clear()
	_blades.clear()
	var base := size.y + 4.0
	_rocks.append(Vector2(-4, base))
	var x := -4.0
	while x < size.x + 40.0:
		_rocks.append(Vector2(x, size.y - _rng.randf_range(34.0, 62.0)))
		x += _rng.randf_range(30.0, 70.0)
	_rocks.append(Vector2(size.x + 4, base))
	for i in range(0, int(size.x), 5):
		_blades.append(PackedFloat32Array([float(i) + _rng.randf_range(-2, 2), _rng.randf_range(6, 16), _rng.randf_range(-0.4, 0.4)]))


func _ledge_height_at(x: float) -> float:
	for i in range(1, _rocks.size() - 2):
		var a := _rocks[i]
		var b := _rocks[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return size.y - 40.0


func _draw_ledge() -> void:
	if _rocks.size() < 4:
		return
	draw_colored_polygon(_rocks, ROCK)
	# Strata and cracks.
	for i in range(1, _rocks.size() - 2):
		var a := _rocks[i]
		draw_line(a + Vector2(0, 10), a + Vector2(18, 28), ROCK_DARK, 2.0, true)
		draw_line(a + Vector2(8, 22), Vector2(a.x + 40, size.y - 6), Color(ROCK_DARK, 0.5), 1.5, true)
	# Grass mat along the top edge, then individual blades swaying.
	var top := PackedVector2Array()
	for i in range(1, _rocks.size() - 1):
		top.append(_rocks[i])
	draw_polyline(top, GRASS.darkened(0.15), 9.0, true)
	draw_polyline(top, GRASS, 5.0, true)
	for blade in _blades:
		var bx := blade[0]
		var root := Vector2(bx, _ledge_height_at(bx) + 2.0)
		var lean := blade[2] + sin(_time * 1.5 + bx * 0.03) * 0.15
		var tip := root + Vector2(lean * blade[1], -blade[1])
		draw_line(root, tip, GRASS_LIGHT if int(bx) % 3 == 0 else GRASS, 2.0, true)


func _draw_gears() -> void:
	var r := GEAR_RADIUS
	var spots := [
		Vector2(INSET + r * 0.55, INSET + r * 0.55),
		Vector2(size.x - INSET - r * 0.55, INSET + r * 0.55),
	]
	for i in spots.size():
		var direction := 1.0 if i % 2 == 0 else -1.0
		_gear(spots[i], r, 12, _time * 0.4 * direction, BRASS)
		# Small gear meshing with the big one.
		var small_at: Vector2 = spots[i] + Vector2(r * 1.25 * (1.0 if i == 0 else -1.0), r * 0.55)
		_gear(small_at, r * 0.45, 8, -_time * 0.4 * direction * 12.0 / 8.0, COPPER)


func _gear(center: Vector2, radius: float, teeth: int, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	var tooth := TAU / teeth
	for t in teeth:
		var a := angle + t * tooth
		points.append(center + Vector2.from_angle(a) * radius * 0.82)
		points.append(center + Vector2.from_angle(a + tooth * 0.15) * radius)
		points.append(center + Vector2.from_angle(a + tooth * 0.45) * radius)
		points.append(center + Vector2.from_angle(a + tooth * 0.6) * radius * 0.82)
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), color.darkened(0.45), 2.0, true)
	draw_circle(center, radius * 0.6, color.darkened(0.15))
	for s in 4:
		var a := angle + s * TAU / 4.0
		draw_line(center, center + Vector2.from_angle(a) * radius * 0.6, color.darkened(0.45), radius * 0.12, true)
	draw_circle(center, radius * 0.2, color.lightened(0.2))
	draw_circle(center, radius * 0.08, IRON)
