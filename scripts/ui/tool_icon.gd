class_name ToolIcon
extends Button
## Inventory slot: a coloured hexagon with a symbol for the item, plus a caption (e.g. "×3").
## Kinds: a tower type (&"attack", &"wall", …), &"tower" (generic), &"tile" or a biome
## (&"forest", &"mountain", &"plains", &"swamp", &"lake").

const SIZE := 58.0
const DARK := Color("2f2a26")
const LIGHT := Color("e8e2d0")

var kind: StringName
var caption := ""
## Small text in the top-left corner (e.g. a tower's level).
var badge := ""


func _init(icon_kind: StringName, caption_text: String, tooltip: String) -> void:
	kind = icon_kind
	caption = caption_text
	if tooltip != "":
		set_meta(&"info", tooltip)
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
		&"lake":
			_waves(c, r)
		&"plains":
			_horizon(c, r, hex)
		&"swamp":
			_pond(c, r)
		_:
			_tower_symbol(c, r)
	draw_polyline(hex + PackedVector2Array([hex[0]]), Color(0, 0, 0, 0.55), 1.5, true)
	if badge != "":
		var bfont := get_theme_default_font()
		draw_string_outline(bfont, Vector2(3, 13), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0, 0, 0, 0.85))
		draw_string(bfont, Vector2(3, 13), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MenuTheme.CREAM)
	if caption != "":
		var font := get_theme_default_font()
		var pos := Vector2(0, size.y - 4)
		draw_string_outline(font, pos, caption, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, 13, 4, Color(0, 0, 0, 0.85))
		draw_string(font, pos, caption, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, 13, MenuTheme.CREAM)


func _fill() -> Color:
	match kind:
		&"tile":
			return Biome.color_of(Biome.Type.NEUTRAL)
		&"forest":
			return Biome.color_of(Biome.Type.FOREST)
		&"mountain":
			return Biome.color_of(Biome.Type.MOUNTAIN)
		&"lake":
			return Biome.color_of(Biome.Type.LAKE)
		&"plains":
			return Color.WHITE
		&"swamp":
			return Biome.color_of(Biome.Type.SWAMP)
	return DARK


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


## Wave arcs on deep blue water.
func _waves(c: Vector2, r: float) -> void:
	for i in 3:
		var centre := c + Vector2(0, r * (0.55 - i * 0.38))
		draw_arc(centre, r * 0.42, PI * 1.15, PI * 1.85, 12, Color(1, 1, 1, 0.9 - i * 0.2), 2.5, true)


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


## The building itself as it looks on the map (neutral material), on the dark hexagon.
func _tower_symbol(c: Vector2, r: float) -> void:
	if kind == &"wall":
		# A stretch of rampart (left and right), so it reads as a wall rather than a tower.
		var links: Array[bool] = [true, false, false, true, false, false]
		TowerArt.draw(self, kind, Biome.Type.NEUTRAL, c, r * 0.6, links, r * 0.8)
	elif TowerDefs.TYPES.has(kind):
		TowerArt.draw(self, kind, Biome.Type.NEUTRAL, c + Vector2(0, -r * 0.05), r * 0.6)
	else:
		_tower(c, r)
