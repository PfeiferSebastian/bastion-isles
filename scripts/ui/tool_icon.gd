class_name ToolIcon
extends Button
## Build bar button: a coloured hexagon with a symbol for what it builds, plus its hotkey.
## Kinds: &"tower", &"tile" or a biome (&"forest", &"mountain", &"desert", &"plains", &"swamp").

const SIZE := 58.0
const DARK := Color("2f2a26")
const LIGHT := Color("e8e2d0")

var kind: StringName
var hotkey := 0


func _init(icon_kind: StringName, key_number: int, tooltip: String) -> void:
	kind = icon_kind
	hotkey = key_number
	tooltip_text = "%s (%d)" % [tooltip, key_number]
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SIZE, SIZE)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.46
	var hex := _hex(c, r)
	draw_colored_polygon(hex, _fill())
	match kind:
		&"tower":
			_tower(c, r)
		&"tile":
			_plus(c, r)
		&"forest":
			_tree(c, r)
		&"mountain":
			_mountain(c, r)
		&"desert":
			_dunes(c, r)
		&"plains":
			_horizon(c, r, hex)
		&"swamp":
			_pond(c, r)
	draw_polyline(hex + PackedVector2Array([hex[0]]), Color(0, 0, 0, 0.55), 1.5, true)
	var font := get_theme_default_font()
	draw_string_outline(font, Vector2(4, 14), str(hotkey), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(4, 14), str(hotkey), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MenuTheme.CREAM)


func _fill() -> Color:
	match kind:
		&"tower":
			return DARK
		&"tile":
			return Biome.color_of(Biome.Type.NEUTRAL)
		&"forest":
			return Biome.color_of(Biome.Type.FOREST)
		&"mountain":
			return Biome.color_of(Biome.Type.MOUNTAIN)
		&"desert":
			return Biome.color_of(Biome.Type.DESERT)
		&"plains":
			return Color.WHITE
		&"swamp":
			return Biome.color_of(Biome.Type.SWAMP)
	return Color.GRAY


static func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in HexMath.corners(r):
		points.append(c + p)
	return points


## Light tower silhouette on dark ground.
func _tower(c: Vector2, r: float) -> void:
	var w := r * 0.55
	var body := Rect2(c + Vector2(-w / 2.0, -r * 0.35), Vector2(w, r * 0.95))
	draw_rect(body, LIGHT)
	for i in 3:
		draw_rect(Rect2(body.position + Vector2(i * w / 2.5, -r * 0.18), Vector2(w / 5.0, r * 0.18)), LIGHT)
	draw_rect(Rect2(c + Vector2(-r * 0.09, r * 0.3), Vector2(r * 0.18, r * 0.3)), DARK)


## Neutral tile: a plus to add ground.
func _plus(c: Vector2, r: float) -> void:
	var color := Color("8a7a55")
	draw_rect(Rect2(c + Vector2(-r * 0.1, -r * 0.45), Vector2(r * 0.2, r * 0.9)), color)
	draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.1), Vector2(r * 0.9, r * 0.2)), color)


## Dark green fir tree.
func _tree(c: Vector2, r: float) -> void:
	var green := Color("1f5a24")
	for i in 3:
		var top := c + Vector2(0, -r * 0.62 + i * r * 0.3)
		var half := r * (0.3 + i * 0.12)
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(half, r * 0.42), top + Vector2(-half, r * 0.42)]), green)
	draw_rect(Rect2(c + Vector2(-r * 0.07, r * 0.42), Vector2(r * 0.14, r * 0.2)), Color("4a3622"))


## Grey mountain with a snowy peak.
func _mountain(c: Vector2, r: float) -> void:
	var base_y := r * 0.5
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, base_y), c + Vector2(-r * 0.05, -r * 0.55), c + Vector2(r * 0.65, base_y)]), Color("8d8d93"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.05, base_y), c + Vector2(r * 0.4, -r * 0.1), c + Vector2(r * 0.72, base_y)]), Color("6e6e75"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.24, -r * 0.27), c + Vector2(-r * 0.05, -r * 0.55), c + Vector2(r * 0.14, -r * 0.27)]), Color("f2f2f2"))


## Two sand dunes with a shaded side.
func _dunes(c: Vector2, r: float) -> void:
	var light := Color("f6cf8a")
	var shade := Color("c97a2a")
	draw_colored_polygon(_dune(c + Vector2(-r * 0.15, r * 0.2), r * 0.6, r * 0.45), light)
	draw_colored_polygon(_dune(c + Vector2(r * 0.25, r * 0.45), r * 0.55, r * 0.35), light.darkened(0.08))
	draw_line(c + Vector2(-r * 0.15, -r * 0.25), c + Vector2(r * 0.2, r * 0.2), shade, 2.0, true)


static func _dune(base: Vector2, half_width: float, height: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		points.append(base + Vector2(lerpf(-half_width, half_width, t), -sin(t * PI) * height * (1.0 - t * 0.35)))
	return points


## Horizon: light beige land below, white sky above.
func _horizon(c: Vector2, r: float, hex: PackedVector2Array) -> void:
	var below := PackedVector2Array([c + Vector2(-r * 2, r * 0.1), c + Vector2(r * 2, r * 0.1), c + Vector2(r * 2, r * 2), c + Vector2(-r * 2, r * 2)])
	for part in Geometry2D.intersect_polygons(hex, below):
		draw_colored_polygon(part, Color("e9dcb8"))
	draw_line(c + Vector2(-r * 0.86, r * 0.1), c + Vector2(r * 0.86, r * 0.1), Color("b9a77a"), 1.5, true)


## Murky pond with reeds.
func _pond(c: Vector2, r: float) -> void:
	var water := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		water.append(c + Vector2(cos(a) * r * 0.6, sin(a) * r * 0.28 + r * 0.25))
	draw_colored_polygon(water, Color("2c3f3a"))
	draw_arc(c + Vector2(0, r * 0.25), r * 0.35, PI * 1.1, PI * 1.6, 8, Color("5f7d72"), 1.5, true)
	for x in [-0.45, -0.3, 0.38]:
		var root := c + Vector2(r * x, r * 0.15)
		draw_line(root, root + Vector2(r * 0.05, -r * 0.55), Color("3d5a2a"), 2.0, true)
		draw_rect(Rect2(root + Vector2(r * 0.02, -r * 0.55), Vector2(r * 0.09, r * 0.2)), Color("5a3f26"))
