class_name HexMath
extends RefCounted
## Axial hex coordinate helpers, pointy-top orientation.
## Coordinates are Vector2i(q, r). Reference: https://www.redblobgames.com/grids/hexagons/
##
## Pure math, no rendering — the island model and any future view (2D, iso, 3D) share this.

const SQRT3 := 1.7320508075688772

## Neighbour offsets, counter-clockwise starting east.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func to_pixel(hex: Vector2i, size: float) -> Vector2:
	return Vector2(
		size * (SQRT3 * hex.x + SQRT3 / 2.0 * hex.y),
		size * 1.5 * hex.y
	)


static func from_pixel(point: Vector2, size: float) -> Vector2i:
	var q := (SQRT3 / 3.0 * point.x - point.y / 3.0) / size
	var r := (2.0 / 3.0 * point.y) / size
	return axial_round(Vector2(q, r))


## Rounds fractional axial coordinates to the nearest hex (via cube coordinates).
static func axial_round(frac: Vector2) -> Vector2i:
	var x := frac.x
	var z := frac.y
	var y := -x - z
	var rx := roundf(x)
	var ry := roundf(y)
	var rz := roundf(z)
	var dx := absf(rx - x)
	var dy := absf(ry - y)
	var dz := absf(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


static func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRECTIONS:
		result.append(hex + dir)
	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


## All hexes within `radius` of `center`, including the center.
static func area(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			result.append(center + Vector2i(q, r))
	return result


## Corner points of a hex centred on the origin.
static func corners(size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(Vector2(cos(angle), sin(angle)) * size)
	return points
