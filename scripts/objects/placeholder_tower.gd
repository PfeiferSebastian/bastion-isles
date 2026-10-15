extends Node2D
## Tower visual: a simple placeholder silhouette per type. Generated painted wall sprites
## (neutral, connecting to neighbouring walls) exist but are switched off (USE_WALL_ART).
## Pops in when spawned and again whenever its type changes.

@export var tower_type: StringName = &"attack":
	set(value):
		tower_type = value
		if is_inside_tree():
			_pop()
			queue_redraw()

@export var radius := 18.0
## Must match the island view, so sprites line up with the tile art.
@export var hex_size := 48.0

## The generated wall sprites don't match the look yet, so the plain wall is drawn instead.
const USE_WALL_ART := false
const ART_DIR := "res://assets/generated/towers/"
## Sprite canvas in art space (256 px = one tile wide); the tile centre sits at ART_ANCHOR.
const ART_SIZE := Vector2(256, 320)
const ART_ANCHOR := Vector2(128, 240)

## Biome of the tile below, set by the island view.
var biome: Biome.Type = Biome.Type.NEUTRAL:
	set(value):
		if value != biome:
			biome = value
			queue_redraw()
## For walls: which of the 6 neighbours (HexMath.DIRECTIONS order) also hold a wall.
var wall_links: Array[bool] = [false, false, false, false, false, false]:
	set(value):
		if value != wall_links:
			wall_links = value
			queue_redraw()

static var _art_cache := {}

## Turret direction in radians; 0 points right, -PI/2 (default) points up.
var aim_angle := -PI / 2.0:
	set(value):
		if not is_equal_approx(value, aim_angle):
			aim_angle = value
			queue_redraw()

const BASE := Color("4a4f5c")
const DARK := Color("2b2e36")
const ACCENTS := {
	&"attack": Color("d9d9d9"),
	&"wall": Color("a0a4ad"),
	&"energy": Color("ffd23f"),
	&"repair": Color("5fd068"),
	&"aura": Color("7fe0c2"),
	&"scout": Color("6fb7ff"),
	&"warehouse": Color("b48a5a"),
}


func _ready() -> void:
	_pop()


func _pop() -> void:
	scale = Vector2(0.3, 0.3)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if tower_type == &"wall" and _draw_wall_art():
		return
	var accent: Color = ACCENTS.get(tower_type, Color.WHITE)
	match tower_type:
		&"wall":
			draw_rect(Rect2(-radius * 1.4, -radius * 0.45 + 3, radius * 2.8, radius * 0.9), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(-radius * 1.4, -radius * 0.45, radius * 2.8, radius * 0.9), BASE)
			for i in 4:
				draw_rect(Rect2(-radius * 1.4 + i * radius * 0.8, -radius * 0.45 - 6, radius * 0.4, 6), accent)
		&"energy":
			_draw_base()
			draw_colored_polygon(PackedVector2Array([
				Vector2(3, -14), Vector2(-7, 2), Vector2(-1, 2), Vector2(-4, 14), Vector2(7, -3), Vector2(1, -3),
			]), accent)
		&"repair":
			_draw_base()
			draw_rect(Rect2(-3.5, -11, 7, 22), accent)
			draw_rect(Rect2(-11, -3.5, 22, 7), accent)
		&"aura":
			draw_arc(Vector2.ZERO, radius * 1.6, 0, TAU, 48, Color(accent, 0.5), 3.0, true)
			_draw_base()
			draw_circle(Vector2.ZERO, radius * 0.5, accent)
		&"scout":
			_draw_base()
			draw_circle(Vector2.ZERO, radius * 0.7, Color.WHITE)
			draw_circle(Vector2.ZERO, radius * 0.4, accent)
			draw_circle(Vector2.ZERO, radius * 0.18, DARK)
		&"warehouse":
			var box := Rect2(-radius, -radius * 0.8, radius * 2, radius * 1.6)
			draw_rect(Rect2(box.position + Vector2(0, 3), box.size), Color(0, 0, 0, 0.25))
			draw_rect(box, accent)
			draw_rect(box, accent.darkened(0.45), false, 2.0)
			draw_line(box.position, box.end, accent.darkened(0.45), 2.0)
			draw_line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), accent.darkened(0.45), 2.0)
		_:  # attack
			_draw_base()
			draw_set_transform(Vector2.ZERO, aim_angle + PI / 2.0)
			draw_rect(Rect2(-4, -radius - 10, 8, radius + 4), DARK)
			draw_set_transform(Vector2.ZERO)
			draw_circle(Vector2.ZERO, radius * 0.45, DARK)
			draw_circle(Vector2.ZERO, radius * 0.2, accent)


## Round base with a light rim, so towers read against painted terrain.
func _draw_base() -> void:
	draw_circle(Vector2(0, 4), radius + 2.0, Color(0, 0, 0, 0.45))
	draw_circle(Vector2.ZERO, radius + 2.0, Color("e8e2d0"))
	draw_circle(Vector2.ZERO, radius, BASE)


func has_art() -> bool:
	return USE_WALL_ART and tower_type == &"wall" and _art("wall_%s_post.png" % String(Biome.Type.find_key(biome)).to_lower()) != null


## Connected wall: segments toward neighbouring walls behind the post, the post, then the
## segments toward the front (so depth reads right). False if no art exists for the biome.
func _draw_wall_art() -> bool:
	if not USE_WALL_ART:
		return false
	var key := String(Biome.Type.find_key(biome)).to_lower()
	var post := _art("wall_%s_post.png" % key)
	if post == null:
		return false
	var rect := _art_rect()
	for i in 6:
		if wall_links[i] and HexMath.DIRECTIONS[i].y <= 0:
			draw_texture_rect(_art("wall_%s_%d.png" % [key, i]), rect, false)
	draw_texture_rect(post, rect, false)
	for i in 6:
		if wall_links[i] and HexMath.DIRECTIONS[i].y > 0:
			draw_texture_rect(_art("wall_%s_%d.png" % [key, i]), rect, false)
	return true


## Sprite rect in local space, stretched like the tile art (see TerrainArt.tile_rect).
func _art_rect() -> Rect2:
	var art_scale := Vector2(HexMath.SQRT3 * hex_size, 2.0 * hex_size) / 256.0
	return Rect2(-ART_ANCHOR * art_scale, ART_SIZE * art_scale)


static func _art(file: String) -> Texture2D:
	if not _art_cache.has(file):
		var path := ART_DIR + file
		_art_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return _art_cache[file]
