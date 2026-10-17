extends Node2D
## Menu centerpiece: the player's kind of island as it looks in the game – the pixel-art hex
## tiles (TerrainArt) around the castle HQ with its biome pennant, a few towers (TowerArt),
## the rocky underside with a hanging rock cone and roots below, drifting rock fragments.
## Bobs gently. The layout is fixed (it is a picture, not the saved island).

@export var hex_size := 38.0
## Depth of the rock cone below the tiles.
@export var depth := 150.0
@export var bob_height := 6.0

const ROCK := Color("7a6a5c")
const ROCK_DARK := Color("4a3e34")
const ROOT := Color("5a4632")
const GRASS := Color("4f9a3a")

## Biome per hex of the radius-2 island (missing = neutral ground): faction patches like a
## real mid-game island.
const BIOMES := {
	Vector2i(1, -1): Biome.Type.MOUNTAIN, Vector2i(0, -1): Biome.Type.MOUNTAIN,
	Vector2i(1, -2): Biome.Type.MOUNTAIN, Vector2i(0, -2): Biome.Type.MOUNTAIN, Vector2i(2, -2): Biome.Type.MOUNTAIN,
	Vector2i(-1, 0): Biome.Type.FOREST, Vector2i(-2, 0): Biome.Type.FOREST, Vector2i(-1, -1): Biome.Type.FOREST,
	Vector2i(-2, 1): Biome.Type.FOREST,
	Vector2i(1, 0): Biome.Type.LAKE, Vector2i(2, -1): Biome.Type.LAKE, Vector2i(2, 0): Biome.Type.LAKE,
	Vector2i(-1, 1): Biome.Type.SWAMP, Vector2i(-1, 2): Biome.Type.SWAMP,
	Vector2i(0, 1): Biome.Type.PLAINS, Vector2i(1, 1): Biome.Type.PLAINS, Vector2i(0, 2): Biome.Type.PLAINS,
}
## Towers standing on the island: hex -> type.
const TOWERS := {
	Vector2i(1, -1): &"attack", Vector2i(-1, 0): &"attack", Vector2i(0, 1): &"attack",
	Vector2i(2, 0): &"energy", Vector2i(-1, 1): &"repair", Vector2i(0, -2): &"wall", Vector2i(-2, 1): &"scout",
}
## The HQ's biome: the island's most common one, as in the game (Island.hq_biome).
var _hq_biome := Biome.Type.NEUTRAL

var _time := 0.0
var _cone := PackedVector2Array()
var _base_y := 0.0
var _tiles: Array[IslandTile] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_y = position.y
	for coord in HexMath.area(Island.HQ_COORD, 2):
		var tile := IslandTile.new(coord, BIOMES.get(coord, Biome.Type.NEUTRAL))
		tile.is_hq = coord == Island.HQ_COORD
		_tiles.append(tile)
	_hq_biome = _dominant_biome()
	# Back rows first, so peaks and trees overlap the row behind them.
	_tiles.sort_custom(func(a: IslandTile, b: IslandTile) -> bool:
		return a.coord.y < b.coord.y if a.coord.y != b.coord.y else a.coord.x < b.coord.x)
	# Jagged rock cone hanging below the island's lower edge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var half := HexMath.SQRT3 * hex_size * 1.9
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		var y := sin(t * PI) * depth * (1.0 - absf(t - 0.5) * 0.6)
		_cone.append(Vector2(lerpf(-half, half, t) + rng.randf_range(-6, 6), y + rng.randf_range(-10, 10) * sin(t * PI)))


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
	_draw_cone()
	var art := TerrainArt.available()
	for tile in _tiles:
		var c := HexMath.to_pixel(tile.coord, hex_size)
		if art:
			draw_texture_rect(TerrainArt.underside(tile.coord), TerrainArt.underside_rect(c, hex_size), false)
	for tile in _tiles:
		var c := HexMath.to_pixel(tile.coord, hex_size)
		if art:
			draw_texture_rect(TerrainArt.for_tile(tile, _hq_biome), TerrainArt.tile_rect(c, hex_size), false)
		else:
			draw_colored_polygon(_hex(c, 0.96), Biome.color_of(tile.biome))
	for tile in _tiles:
		if TOWERS.has(tile.coord):
			# Turrets sweep slowly, as if watching the sky.
			var aim := -PI / 2.0 + sin(_time * 0.6 + tile.coord.x * 1.7) * 0.9
			TowerArt.draw(self, TOWERS[tile.coord], tile.biome, HexMath.to_pixel(tile.coord, hex_size), hex_size * 0.375, [], 0.0, aim)
	_draw_pennant(HexMath.to_pixel(Island.HQ_COORD, hex_size))


## Rock cone with strata and swaying roots, below the tiles' own underside.
func _draw_cone() -> void:
	var top := hex_size * 3.1
	var body := PackedVector2Array([_cone[0] + Vector2(0, top)])
	for p in _cone:
		body.append(p + Vector2(0, top))
	draw_colored_polygon(body, ROCK)
	for k in range(1, 4):
		var line := PackedVector2Array()
		for p in _cone:
			line.append(Vector2(p.x * (1.0 - k * 0.18), top + p.y * k * 0.24))
		draw_polyline(line, ROCK_DARK, 2.0, true)
	for i in 7:
		var x := lerpf(_cone[2].x, _cone[-3].x, i / 6.0)
		var start := Vector2(x, top + _depth_at(x) - 4.0)
		var sway := sin(_time * 1.1 + i) * 4.0
		draw_polyline(PackedVector2Array([start, start + Vector2(sway * 0.5, 18), start + Vector2(sway, 26 + i % 3 * 6)]), ROOT, 2.0, true)


func _depth_at(x: float) -> float:
	for i in _cone.size() - 1:
		var a := _cone[i]
		var b := _cone[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return 0.0


## The HQ's pennant in its biome colour, waving.
func _draw_pennant(center: Vector2) -> void:
	var foot := center + Vector2(hex_size * 0.32, -hex_size * 0.35)
	var top := foot + Vector2(0, -hex_size * 0.75)
	var dark := Color(0.12, 0.09, 0.07)
	var wave := sin(_time * 3.0) * hex_size * 0.05
	draw_line(foot, top, dark, 2.5, true)
	var flag := PackedVector2Array([top, top + Vector2(hex_size * 0.42, hex_size * 0.13 + wave), top + Vector2(0, hex_size * 0.26)])
	draw_colored_polygon(flag, Biome.color_of(_hq_biome))
	draw_polyline(flag + PackedVector2Array([flag[0]]), dark, 1.5, true)


## Most tiles wins (the HQ itself doesn't count); on a tie a faction biome beats neutral.
func _dominant_biome() -> Biome.Type:
	var counts := {}
	for tile in _tiles:
		if not tile.is_hq:
			counts[tile.biome] = counts.get(tile.biome, 0) + 1
	var best := Biome.Type.NEUTRAL
	for biome in counts:
		var rank := [counts[biome], 0 if biome == Biome.Type.NEUTRAL else 1]
		if not counts.has(best) or rank > [counts[best], 0 if best == Biome.Type.NEUTRAL else 1]:
			best = biome
	return best


func _hex(center: Vector2, scale_by: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner in HexMath.corners(hex_size * scale_by):
		points.append(corner + center)
	return points


## Little rock fragments with a grassy top drifting around the island.
func _draw_fragments() -> void:
	var w := HexMath.SQRT3 * hex_size * 5.0
	var spots := [Vector2(-w * 0.68, 70), Vector2(w * 0.66, 100), Vector2(w * 0.6, -50), Vector2(-w * 0.55, -70)]
	for i in spots.size():
		var p: Vector2 = spots[i] + Vector2(0, sin(_time * 1.3 + i * 2.0) * 8.0)
		var s := 18.0 - i * 3.5
		draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(s, 0), p + Vector2(s * 0.3, s * 1.2), p + Vector2(-s * 0.4, s * 0.9)]), ROCK)
		draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), GRASS, 4.0)
