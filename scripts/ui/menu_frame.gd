extends Control
## Decorative steampunk frame for the main menu, drawn in code: brass border with rivets,
## copper pipes with a pressure gauge and a valve, hanging moss at the top and
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
## Room kept at the top of the side pipes, where their junction boxes sit.
const CORNER_SPACE := 44.0

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


## Copper pipes down both sides: each comes out of a riveted junction box near the top,
## is fed by an elbow from the frame, runs down past a gauge (left) or a valve wheel (right)
## and disappears into the rocky ledge at the bottom.
func _draw_pipes() -> void:
	var width := 11.0
	for i in 2:
		var left := i == 0
		var x := INSET + 34.0 if left else size.x - INSET - 34.0
		var box_y := INSET + CORNER_SPACE * 1.75
		var bottom := size.y - 30.0   # hidden by the ledge drawn afterwards
		# Feed from the frame bar into the box: a short horizontal run and an elbow.
		var frame_x := INSET + BAR * 0.5 if left else size.x - INSET - BAR * 0.5
		var dir := 1.0 if left else -1.0
		var elbow_r := 14.0
		_pipe(Vector2(frame_x, box_y - 30.0), Vector2(x - dir * elbow_r, box_y - 30.0), width)
		_elbow(Vector2(x - dir * elbow_r, box_y - 30.0 + elbow_r), elbow_r, -PI / 2.0 if left else -PI / 2.0, 0.0 if left else -PI, width)
		_flange(Vector2(frame_x + dir * 6.0, box_y - 30.0), width, false)
		# Main run down into the rocks.
		_pipe(Vector2(x, box_y), Vector2(x, bottom), width)
		var y := box_y + 70.0
		while y < bottom - 60.0:
			_flange(Vector2(x, y), width, true)
			y += 110.0
		_junction_box(Vector2(x, box_y))
		if left:
			# T-branch to a pressure gauge.
			var gauge := Vector2(x + 40.0, size.y * 0.44)
			_pipe(Vector2(x, gauge.y), gauge - Vector2(16, 0), 7.0)
			_flange(Vector2(x, gauge.y), width, true)
			_gauge(gauge)
		else:
			_valve(Vector2(x, size.y * 0.5))


## Straight pipe from `a` to `b` with a dark outline, highlight and shadow side.
func _pipe(a: Vector2, b: Vector2, width: float) -> void:
	SteamParts.pipe(self, a, b, width)


## Quarter bend around `center` from angle `from` to `to`.
func _elbow(center: Vector2, radius: float, from: float, to: float, width: float) -> void:
	SteamParts.elbow(self, center, radius, from, to, width)


## Bolted ring around a pipe.
func _flange(at: Vector2, width: float, vertical_pipe: bool) -> void:
	SteamParts.flange(self, at, width, vertical_pipe)


## Riveted brass box the pipe comes out of.
func _junction_box(top_center: Vector2) -> void:
	var r := Rect2(top_center + Vector2(-19, -22), Vector2(38, 28))
	draw_rect(r.grow(2.0), BRASS_DARK)
	draw_rect(r, BRASS)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 6)), BRASS_LIGHT.darkened(0.05))
	draw_line(Vector2(r.position.x + 3, r.end.y - 2), Vector2(r.end.x - 3, r.end.y - 2), BRASS_DARK, 1.5)
	for p in [r.position + Vector2(4, 4), Vector2(r.end.x - 4, r.position.y + 4),
			Vector2(r.position.x + 4, r.end.y - 4), r.end - Vector2(4, 4)]:
		_rivet_small(p)


func _rivet_small(at: Vector2) -> void:
	draw_circle(at, 2.2, BRASS_DARK)
	draw_circle(at + Vector2(-0.5, -0.5), 1.3, BRASS_LIGHT)


func _gauge(center: Vector2) -> void:
	draw_circle(center + Vector2(1.5, 2), 22.0, Color(0, 0, 0, 0.35))
	draw_circle(center, 22.0, BRASS_DARK)
	draw_circle(center, 20.0, BRASS)
	draw_circle(center, 16.5, Color("efe4c8"))
	for i in 7:
		var a := deg_to_rad(150.0 + i * 40.0)
		draw_line(center + Vector2.from_angle(a) * 11.0, center + Vector2.from_angle(a) * 15.0, IRON, 1.5)
	var needle := deg_to_rad(210.0 + 70.0 * (0.5 + 0.5 * sin(_time * 1.3)) + 6.0 * sin(_time * 9.0))
	draw_line(center, center + Vector2.from_angle(needle) * 13.0, Color("a8322a"), 2.0, true)
	draw_circle(center, 2.5, IRON)
	# Glass reflection.
	draw_arc(center, 13.0, deg_to_rad(200), deg_to_rad(250), 8, Color(1, 1, 1, 0.55), 2.0, true)


## Hand wheel valve sitting on the pipe; turns slowly now and then.
func _valve(center: Vector2) -> void:
	_flange(center, 11.0, true)
	var angle := sin(_time * 0.5) * 0.6
	draw_circle(center + Vector2(1.5, 2), 17.0, Color(0, 0, 0, 0.3))
	draw_arc(center, 15.0, 0, TAU, 24, Color("8a2a20").darkened(0.3), 5.0, true)
	draw_arc(center, 15.0, 0, TAU, 24, Color("a8322a"), 3.0, true)
	for k in 4:
		var a := angle + k * PI / 2.0
		draw_line(center, center + Vector2.from_angle(a) * 14.0, Color("8a2a20"), 3.0, true)
	draw_circle(center, 4.5, BRASS_DARK)
	draw_circle(center + Vector2(-1, -1), 2.5, BRASS_LIGHT)


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
