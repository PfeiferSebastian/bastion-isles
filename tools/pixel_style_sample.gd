extends SceneTree
## Style test: a 16-bit shmup look drawn pixel by pixel – forest, river, coast and mountains
## far below, a floating hex tile with a turret, enemy airships with ground shadows, glowing
## shots and an explosion. Limited palettes with ordered dithering, 1-pixel dark outlines,
## light from the top left.

const W := 320
const H := 200
const SCALE := 3
## Run: godot --headless --path . -s tools/pixel_style_sample.gd (writes into the user data folder).
const OUT := "user://pixel_style_sample.png"

const FOREST := ["06120a", "0c1f10", "143018", "1d4320", "2a5a29", "3f7536"]
const WATER := ["060f20", "0a1830", "102340", "183156", "24446f", "4f78a8"]
const ROCK := ["1c1511", "2e241c", "443528", "5e4a37", "7a6449", "9a8466", "d6d0c4"]
const SHORE := ["5a4d38", "7d6c4f", "a08e6a"]
const METAL := ["1a1c22", "343944", "555c6b", "7d8697", "aeb6c4", "e2e6ee"]
const HULL := ["2a1410", "53261b", "7e3f2a", "a85d3c", "d08a5c", "f0c08e"]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var img: Image
var height := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var ridge := FastNoiseLite.new()


func _initialize() -> void:
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	height.seed = 7
	height.frequency = 0.008
	height.fractal_octaves = 4
	detail.seed = 21
	detail.frequency = 0.32
	ridge.seed = 3
	ridge.frequency = 0.03
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 3
	_terrain()
	_shadows()
	_island(Vector2i(150, 128))
	_shots(Vector2i(150, 116))
	_airship(Vector2i(95, 34), 0)
	_airship(Vector2i(150, 22), 0)
	_airship(Vector2i(205, 34), 0)
	_airship(Vector2i(262, 70), 1)
	_explosion(Vector2i(150, 44))
	img.resize(W * SCALE, H * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(OUT)
	print("Saved ", ProjectSettings.globalize_path(OUT))
	quit()


# --- helpers ---------------------------------------------------------------

## Palette colour for a value 0..1 with ordered dithering between neighbouring entries.
func _dither(palette: Array, value: float, x: int, y: int) -> Color:
	var scaled := clampf(value, 0.0, 0.9999) * (palette.size() - 1)
	var index := int(scaled)
	var threshold: float = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
	if scaled - index > threshold:
		index = mini(index + 1, palette.size() - 1)
	return Color(palette[index])


func _put(x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, color)


func _blend(x: int, y: int, color: Color, alpha: float) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(color, alpha))


func _h(x: float, y: float) -> float:
	var river := absf(x - (W * 0.42 + sin(y * 0.035) * 38.0 + sin(y * 0.013 + 1.0) * 26.0)) - (10.0 + sin(y * 0.05) * 3.0)
	var base := height.get_noise_2d(x, y) + 0.2
	return minf(base, river * 0.02 - 0.05)


# --- terrain ---------------------------------------------------------------

func _terrain() -> void:
	for y in H:
		for x in W:
			var h := _h(x, y)
			if h < -0.06:
				# Water: darker the deeper, a few glints.
				var depth := clampf(-h * 2.2, 0.0, 1.0)
				var glint := detail.get_noise_2d(x * 1.7, y * 0.6) > 0.62
				_put(x, y, Color(WATER[5]) if glint else _dither(WATER, 0.75 - depth * 0.7 + detail.get_noise_2d(x, y) * 0.08, x, y))
			elif h < -0.02:
				# Shore with foam right at the water.
				_put(x, y, Color(WATER[5]).lightened(0.3) if h < -0.052 and (x + y) % 3 == 0 else _dither(SHORE, (h + 0.06) * 18.0 + detail.get_noise_2d(x, y) * 0.3, x, y))
			elif h > 0.33:
				# Mountains: ridges lit from the top left, snow on the high sunny sides.
				var r := ridge.get_noise_2d(x, y)
				var slope := (ridge.get_noise_2d(x - 1, y - 1) - ridge.get_noise_2d(x + 1, y + 1)) * 5.0
				var value := 0.3 + slope * 0.55 + r * 0.25 + (h - 0.33) * 0.5
				if h > 0.48 and slope > 0.12 and r > 0.45:
					value = 1.0
				_put(x, y, _dither(ROCK, value, x, y))
			else:
				_put(x, y, _canopy(x, y, h))


## Forest seen from high above: round tree crowns on a jittered grid, each lit on its top
## left and dark at its bottom right, with dark gaps between them.
func _canopy(x: int, y: int, h: float) -> Color:
	var cell := 4
	var best := 99.0
	var best_offset := Vector2.ZERO
	var cx := x / cell
	var cy := y / cell
	for gy in range(cy - 1, cy + 2):
		for gx in range(cx - 1, cx + 2):
			var seed_value := absi(gx * 73856093 ^ gy * 19349663)
			var center := Vector2(gx * cell + seed_value % cell, gy * cell + (seed_value / 7) % cell)
			var offset := Vector2(x, y) - center
			var radius := 2.2 + (seed_value % 3) * 0.5
			var d := offset.length() / radius
			if d < best:
				best = d
				best_offset = offset / radius
	if best > 1.0:
		return _dither(FOREST, 0.12 + h * 0.3, x, y)
	var light := -(best_offset.x + best_offset.y) * 0.25
	return _dither(FOREST, 0.45 + light + (1.0 - best) * 0.2 + (h - 0.1) * 0.5, x, y)


## Dark silhouettes of the airships on the ground below them (offset down and right).
func _shadows() -> void:
	for at in [Vector2i(95, 34), Vector2i(150, 22), Vector2i(205, 34), Vector2i(262, 70)]:
		var center: Vector2i = at + Vector2i(14, 40)
		for y in range(-9, 10):
			for x in range(-6, 7):
				if (x * x) / 36.0 + (y * y) / 81.0 <= 1.0 or (absi(y) < 2 and absi(x) < 10):
					_blend(center.x + x, center.y + y, Color(0, 0, 0), 0.55)


# --- floating hex tile with a turret ---------------------------------------

func _island(center: Vector2i) -> void:
	var r := 26.0
	var corners := []
	for i in 6:
		var a := deg_to_rad(60.0 * i - 30.0)
		corners.append(Vector2(cos(a), sin(a) * 0.62) * r)
	var top := PackedVector2Array(corners)
	# Underside: rocky wedge below the tile.
	for y in range(0, 22):
		var half := int(r * HexMath.SQRT3 / 2.0 * (1.0 - y / 22.0))
		for x in range(-half, half + 1):
			var value := 0.5 - y / 30.0 + (0.15 if x < -half / 3 else (-0.12 if x > half / 3 else 0.0))
			_put(center.x + x, center.y + int(r * 0.5) + y, _dither(ROCK, value, center.x + x, center.y + y))
	# Top face: paving stones with seams, lit from the top left.
	for y in range(-20, 21):
		for x in range(-26, 27):
			var p := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(p, top):
				var seam := (x + 40) % 8 == 0 or (y + 40) % 6 == 0
				var value := 0.62 - (x + y) * 0.006 + detail.get_noise_2d(x * 3.0, y * 3.0) * 0.1
				_put(center.x + x, center.y + y, Color(ROCK[2]) if seam else _dither(ROCK, value, center.x + x, center.y + y))
	# Rim: dark outline and a lit top-left edge.
	for i in 6:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 6]
		for t in 40:
			var p := a.lerp(b, t / 39.0)
			_put(center.x + roundi(p.x), center.y + roundi(p.y), Color(ROCK[0]))
			if i >= 3:
				_put(center.x + roundi(p.x * 0.94), center.y + roundi(p.y * 0.94), Color(ROCK[5]))
	_turret(center)


func _turret(c: Vector2i) -> void:
	# Base ring with outline, shaded metal, rivets, barrel pointing up.
	for y in range(-11, 12):
		for x in range(-11, 12):
			var d := sqrt(x * x + y * y)
			if d <= 10.5:
				var value := 0.55 - (x + y) * 0.025
				var color := _dither(METAL, value, c.x + x, c.y + y)
				if d > 9.3:
					color = Color(METAL[0])
				elif d < 5.0:
					color = _dither(METAL, 0.75 - (x + y) * 0.04, c.x + x, c.y + y)
				_put(c.x + x, c.y + y, color)
	for i in 6:
		var a := TAU * i / 6.0
		_put(c.x + roundi(cos(a) * 7.5), c.y + roundi(sin(a) * 7.5), Color(METAL[5]))
	for y in range(-20, -3):
		for x in range(-2, 3):
			var color := Color(METAL[0]) if absi(x) == 2 else (Color(METAL[4]) if x == -1 else Color(METAL[2]))
			_put(c.x + x, c.y + y, color)
	_put(c.x - 1, c.y - 20, Color(METAL[5]))
	_put(c.x, c.y, Color("ffd27a"))


# --- shots, airships, explosion --------------------------------------------

func _shots(from: Vector2i) -> void:
	for offset in [Vector2i(0, -14), Vector2i(-7, -32), Vector2i(7, -32), Vector2i(0, -52)]:
		var c: Vector2i = from + offset
		for y in range(-6, 7):
			for x in range(-2, 3):
				var edge := absi(x) == 2 or absi(y) == 6
				var core := absi(x) == 0 and absi(y) < 5
				if edge and (absi(x) == 2 and absi(y) > 3):
					continue
				_put(c.x + x, c.y + y, Color("ffffff") if core else (Color("2e6fd8") if edge else Color("8fc8ff")))


## Enemy airship from above: pointed hull with a dark outline, lit plating, a cockpit,
## stubby wings and engine glow at the back. `style` 1 = grey gunship.
func _airship(c: Vector2i, style: int) -> void:
	var palette := HULL if style == 0 else METAL
	for y in range(-12, 13):
		var half := int(5.0 * (1.0 - absf(y + 2) / 14.0) + 2.0) if y < 8 else 3
		var wing := 9 if y > -2 and y < 4 else 0
		for x in range(-maxi(half, wing), maxi(half, wing) + 1):
			var is_wing := absi(x) > half
			var outline := absi(x) == maxi(half, wing) or y == -12 or y == 12 or (is_wing and (y == -1 or y == 3))
			var value := 0.6 - x * 0.06 - y * 0.012
			var color := Color(palette[0]) if outline else _dither(palette, value - (0.2 if is_wing else 0.0), c.x + x, c.y + y)
			_put(c.x + x, c.y - y, color)
	# Cockpit and engines.
	_put(c.x, c.y + 6, Color("8fe0ff"))
	_put(c.x, c.y + 7, Color("3a8ac8"))
	for x in [-2, 2]:
		_put(c.x + x, c.y - 12, Color("ffb040"))
		_put(c.x + x, c.y - 13, Color("ff6020"))


func _explosion(c: Vector2i) -> void:
	var fire := ["5a1408", "a8300c", "e0601a", "f8a030", "ffe070", "ffffe0"]
	for y in range(-13, 14):
		for x in range(-13, 14):
			var d := sqrt(x * x + y * y) + detail.get_noise_2d(x * 4.0 + 50.0, y * 4.0) * 5.0
			if d < 12.0:
				_put(c.x + x, c.y + y, _dither(fire, 1.0 - d / 12.0, c.x + x, c.y + y))
