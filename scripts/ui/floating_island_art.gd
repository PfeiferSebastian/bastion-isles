extends Node2D
## Menu centerpiece: a gently bobbing floating island with a grassy top, rocky underside,
## hanging roots, a small brass-domed keep and a few drifting rock fragments. Drawn in code.

@export var width := 340.0
@export var depth := 190.0
@export var bob_height := 6.0

const GRASS := Color("4f9a3a")
const GRASS_LIGHT := Color("7cc35a")
const ROCK := Color("7a6a5c")
const ROCK_DARK := Color("4a3e34")
const ROOT := Color("5a4632")

var _time := 0.0
var _underside := PackedVector2Array()
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Jagged cone from the left rim down to the tip and back up to the right rim.
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		var x := lerpf(-width / 2.0, width / 2.0, t)
		var y := sin(t * PI) * depth * (1.0 - absf(t - 0.5) * 0.6)
		_underside.append(Vector2(x + rng.randf_range(-6, 6), y + rng.randf_range(-10, 10) * sin(t * PI)))


## Moves the island's resting point (it keeps bobbing around it).
func place(at: Vector2) -> void:
	position = at
	_base_y = at.y


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 0.9) * bob_height
	queue_redraw()


func _draw() -> void:
	_draw_fragments()
	# Rock underside with strata.
	var body := PackedVector2Array([Vector2(-width / 2.0, 0)])
	body.append_array(_underside)
	body.append(Vector2(width / 2.0, 0))
	draw_colored_polygon(body, ROCK)
	for k in range(1, 4):
		var line := PackedVector2Array()
		for p in _underside:
			line.append(Vector2(p.x * (1.0 - k * 0.18), p.y * k * 0.24))
		draw_polyline(line, ROCK_DARK, 2.0, true)
	# Hanging roots.
	for i in 7:
		var x := lerpf(-width * 0.35, width * 0.35, i / 6.0)
		var start := Vector2(x, _depth_at(x) - 4.0)
		var sway := sin(_time * 1.1 + i) * 4.0
		draw_polyline(PackedVector2Array([start, start + Vector2(sway * 0.5, 18), start + Vector2(sway, 26 + i % 3 * 6)]), ROOT, 2.0, true)
	# Grassy top.
	var top := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		top.append(Vector2(cos(a) * width / 2.0, sin(a) * 18.0))
	for i in 25:
		var a := PI * i / 24.0
		top.append(Vector2(cos(a) * width / 2.0, sin(a) * 10.0 + 2.0))
	draw_colored_polygon(top, GRASS)
	draw_polyline(top.slice(0, 25), GRASS_LIGHT, 3.0, true)
	_draw_keep(Vector2(10, -14))
	_draw_tree(Vector2(-110, -6), 16.0)
	_draw_tree(Vector2(-80, -10), 12.0)
	_draw_tree(Vector2(120, -6), 14.0)


func _depth_at(x: float) -> float:
	for i in _underside.size() - 1:
		var a := _underside[i]
		var b := _underside[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return 0.0


## Small keep with a brass dome and a pennant.
func _draw_keep(base: Vector2) -> void:
	var stone := Color("8c8f99")
	draw_rect(Rect2(base + Vector2(-34, -40), Vector2(68, 40)), stone)
	draw_rect(Rect2(base + Vector2(-14, -78), Vector2(28, 40)), stone.lightened(0.08))
	for i in 4:
		draw_rect(Rect2(base + Vector2(-34 + i * 20, -48), Vector2(10, 8)), stone)
	draw_circle(base + Vector2(0, -78), 16.0, MenuTheme.BRASS)
	draw_rect(Rect2(base + Vector2(-16, -78), Vector2(32, 6)), MenuTheme.BRASS_DARK)
	draw_line(base + Vector2(0, -94), base + Vector2(0, -116), MenuTheme.IRON, 2.0)
	var wave := sin(_time * 3.0) * 3.0
	draw_colored_polygon(PackedVector2Array([base + Vector2(0, -116), base + Vector2(22, -110 + wave), base + Vector2(0, -104)]), Color("a8322a"))
	draw_rect(Rect2(base + Vector2(-6, -16), Vector2(12, 16)), MenuTheme.IRON)
	draw_circle(base + Vector2(0, -62), 4.0, Color("ffd23f"))


func _draw_tree(at: Vector2, size: float) -> void:
	draw_line(at, at + Vector2(0, -size), ROOT, 3.0)
	draw_circle(at + Vector2(0, -size * 1.4), size * 0.8, GRASS.darkened(0.15))
	draw_circle(at + Vector2(-size * 0.3, -size * 1.6), size * 0.5, GRASS_LIGHT)


## Little rock fragments drifting around the island.
func _draw_fragments() -> void:
	var spots := [Vector2(-width * 0.75, 40), Vector2(width * 0.72, 70), Vector2(width * 0.62, -40)]
	for i in spots.size():
		var p: Vector2 = spots[i] + Vector2(0, sin(_time * 1.3 + i * 2.0) * 8.0)
		var s := 18.0 - i * 4.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(s, 0), p + Vector2(s * 0.3, s * 1.2), p + Vector2(-s * 0.4, s * 0.9)]), ROCK)
		draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), GRASS, 4.0)
