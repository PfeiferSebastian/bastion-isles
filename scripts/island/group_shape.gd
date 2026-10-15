class_name GroupShape
extends RefCounted
## Geometry of a building group (neighbouring towers of one type, see Island.group_of): its
## outer outline, insets of it, and pieces of that outline by length. Used for the shared
## status bars and the combined building art.


## Outer outline of the hexes in `group` (pixel space, hex `size`), clockwise on screen and
## starting at its topmost corner. Inner holes of ring-shaped groups are left out.
static func outline(group: Array[Vector2i], size: float) -> PackedVector2Array:
	var members := {}
	for coord in group:
		members[coord] = true
	var corners := HexMath.corners(size)
	# Edge i runs from corner i to corner i + 1; its neighbour lies at angle 60° * i.
	var next := {}
	for coord in group:
		var center := HexMath.to_pixel(coord, size)
		for dir in HexMath.DIRECTIONS:
			if members.has(coord + dir):
				continue
			var i := posmod(roundi(HexMath.to_pixel(dir, 1.0).angle() / (PI / 3.0)), 6)
			var a := center + corners[i]
			var b := center + corners[(i + 1) % 6]
			next[_key(a)] = b
	if next.is_empty():
		return PackedVector2Array()
	# Walk every loop and keep the longest one (the outside).
	var best := PackedVector2Array()
	var used := {}
	for start_key in next:
		if used.has(start_key):
			continue
		var loop := PackedVector2Array()
		var key: String = start_key
		var guard := 0
		while not used.has(key) and guard < 10000:
			used[key] = true
			var point: Vector2 = next[key]
			loop.append(point)
			key = _key(point)
			guard += 1
		if loop.size() > best.size():
			best = loop
	# Start at the topmost corner (leftmost on ties), like a single hex's top corner.
	var top := 0
	for i in best.size():
		if best[i].y < best[top].y - 0.01 or (absf(best[i].y - best[top].y) <= 0.01 and best[i].x < best[top].x):
			top = i
	return best.slice(top) + best.slice(0, top)


## `loop` moved inward by `delta` px, keeping its start near the top.
static func inset(loop: PackedVector2Array, delta: float) -> PackedVector2Array:
	var shrunk := Geometry2D.offset_polygon(loop, -delta, Geometry2D.JOIN_MITER)
	var best := PackedVector2Array()
	for poly in shrunk:
		if poly.size() > best.size():
			best = poly
	if best.is_empty():
		return best
	# Keep the original winding and start (offset_polygon may change both).
	if Geometry2D.is_polygon_clockwise(best) != Geometry2D.is_polygon_clockwise(loop):
		best.reverse()
	var start := 0
	for i in best.size():
		if best[i].distance_squared_to(loop[0]) < best[start].distance_squared_to(loop[0]):
			start = i
	return best.slice(start) + best.slice(0, start)


static func length(loop: PackedVector2Array) -> float:
	var total := 0.0
	for i in loop.size():
		total += loop[i].distance_to(loop[(i + 1) % loop.size()])
	return total


## The piece of the closed `loop` from `from` to `to` px along it (wraps around past the end).
static func slice(loop: PackedVector2Array, from: float, to: float) -> PackedVector2Array:
	var total := length(loop)
	var result := PackedVector2Array()
	if total <= 0.0 or to <= from:
		return result
	result.append(point_at(loop, from))
	var walked := 0.0
	# Corners crossed between from and to (possibly over two laps).
	for lap in 2:
		walked = lap * total
		for i in loop.size():
			walked += loop[i].distance_to(loop[(i + 1) % loop.size()])
			if walked > from and walked < to:
				result.append(loop[(i + 1) % loop.size()])
	result.append(point_at(loop, to))
	return result


static func point_at(loop: PackedVector2Array, distance: float) -> Vector2:
	var total := length(loop)
	var d := fposmod(distance, total) if total > 0.0 else 0.0
	for i in loop.size():
		var a := loop[i]
		var b := loop[(i + 1) % loop.size()]
		var step := a.distance_to(b)
		if d <= step:
			return a.lerp(b, d / maxf(step, 0.001))
		d -= step
	return loop[0]


static func _key(p: Vector2) -> String:
	return "%d,%d" % [roundi(p.x * 10.0), roundi(p.y * 10.0)]
