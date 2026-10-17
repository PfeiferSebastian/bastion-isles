class_name TowerArt
extends RefCounted
## Buildings drawn in code, seen from above: walls as ramparts with a round tower at the
## centre, plus a symbol per type (cannon turret, tesla coil, workshop gear, crystal
## obelisk, watchtower, storehouse). The material follows the biome below. Buildings of the
## same type on neighbouring tiles grow into one combined structure: a connecting wing runs
## to the shared hex side, and a joint building sits right on that side (see _segment and _joint).
## Both neighbours draw their half and the same joint, so the pieces meet seamlessly.
## Used by the map (tower nodes) and the inventory icons.

## Material per biome: main, light (tops and highlights), dark (edges), accent (glow, trim).
const MATERIALS := {
	Biome.Type.NEUTRAL: [Color("9a958c"), Color("cfc9bc"), Color("4f4b45"), Color("d8b25a")],
	Biome.Type.FOREST: [Color("7a5230"), Color("a8794c"), Color("3d2814"), Color("7cc35a")],
	Biome.Type.MOUNTAIN: [Color("6f7178"), Color("a3a5ab"), Color("2f3137"), Color("ff9d4a")],
	Biome.Type.PLAINS: [Color("e6e0cf"), Color("ffffff"), Color("8f8670"), Color("8fd3ff")],
	Biome.Type.SWAMP: [Color("4d3a5c"), Color("7a6190"), Color("21162b"), Color("9be05a")],
	Biome.Type.LAKE: [Color("4f7fa8"), Color("8db8d8"), Color("1f3a55"), Color("7fe8e0")],
}
const SHADOW := Color(0, 0, 0, 0.32)
const IRON := Color("2f2a26")
const COPPER := Color("b4643c")
## Bridges between the buildings of a combined building are this much wider than a wing.
const BRIDGE_WIDTH := 1.45


## Draws `type` centred on `c` with symbol radius `r`. `links`: per HexMath.DIRECTIONS
## whether that neighbour holds the same type; `link_length` is the distance from the centre
## to the shared hex edge (half the distance between tile centres).
static func draw(ci: CanvasItem, type: StringName, biome: Biome.Type, c: Vector2, r: float,
		links: Array[bool] = [], link_length := 0.0, aim := -PI / 2.0) -> void:
	var m: Array = MATERIALS.get(biome, MATERIALS[Biome.Type.NEUTRAL])
	var dirs := _link_dirs(links)
	for d in dirs:
		_segment(ci, type, c, d, 0.0, link_length, r, m, true)
	for d in dirs:
		_joint(ci, type, c + d * link_length, d, r, m)
	match type:
		&"wall":
			_wall_tower(ci, c, r, m)
		&"energy":
			_coil(ci, c, r, m)
		&"repair":
			_workshop(ci, c, r, m)
		&"aura":
			_obelisk(ci, c, r, m)
		&"scout":
			_watchtower(ci, c, r, m)
		&"warehouse":
			_storehouse(ci, c, r, m)
		_:
			_turret(ci, c, r, m, biome, aim)


## A combined building over several hexes (`art` from IslandView._group_art): a platform
## painted over the hex borders in the colour of each member's biome, then every member's
## building joined to its neighbours by a wide bridge with a joint building on the hex side.
static func draw_group(ci: CanvasItem, type: StringName, art: Dictionary, r: float, link_length: float, aim := -PI / 2.0) -> void:
	var biome: Biome.Type = art.biome
	var m: Array = MATERIALS.get(biome, MATERIALS[Biome.Type.NEUTRAL])
	var platform: PackedVector2Array = art.platform
	if platform.size() >= 3 and TerrainArt.available():
		# With tile art the ground shows through: only the platform's rim and rivets.
		ci.draw_polyline(platform + PackedVector2Array([platform[0]]), Color(m[2], 0.8), 2.0, true)
		for p in platform:
			SteamParts.rivet(ci, p + (art.center - p).normalized() * 5.0, 2.0)
	elif platform.size() >= 3:
		ci.draw_colored_polygon(_shifted(platform, Vector2(2, 3)), SHADOW)
		ci.draw_colored_polygon(platform, m[2])
		var floor_poly := GroupShape.inset(platform, 2.5)
		if floor_poly.size() >= 3:
			# Each member's part of the floor in its biome colour.
			var hex_size := link_length * 2.0 / HexMath.SQRT3
			for i in art.members.size():
				var hex := _shifted(HexMath.corners(hex_size), art.members[i])
				for part in Geometry2D.intersect_polygons(floor_poly, hex):
					ci.draw_colored_polygon(part, Biome.color_of(art.biomes[i]).darkened(0.08))
			var trim := GroupShape.inset(platform, 5.0)
			if trim.size() >= 3:
				ci.draw_polyline(trim + PackedVector2Array([trim[0]]), Color(m[2], 0.45), 1.0, true)
		for p in platform:
			SteamParts.rivet(ci, p + (art.center - p).normalized() * 5.0, 2.0)
	var members: Array = art.members
	for i in members.size():
		for d in _link_dirs(art.links[i]):
			_segment(ci, type, members[i], d, 0.0, link_length, r, m, true, BRIDGE_WIDTH)
	for i in members.size():
		for d in _link_dirs(art.links[i]):
			_joint(ci, type, members[i] + d * link_length, d, r, m)
	for i in members.size():
		if art.parts[i]:
			continue
		# A merged tower is one big building over its hexes.
		var size: int = art.sizes[i]
		draw(ci, type, biome, art.big_centers[i], r * (1.0 + 0.45 * (size - 1)), [], 0.0, aim)


static func _link_dirs(links: Array[bool]) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	for i in mini(links.size(), HexMath.DIRECTIONS.size()):
		if links[i]:
			dirs.append(HexMath.to_pixel(HexMath.DIRECTIONS[i], 1.0).normalized())
	return dirs


## Rotated rectangle from `a` to `b`, `width` wide.
static func _strip(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var n := (b - a).normalized().orthogonal() * width / 2.0
	return PackedVector2Array([a + n, b + n, b - n, a - n])


static func _shifted(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(p + by)
	return result


static func _ring(ci: CanvasItem, c: Vector2, radius: float, fill: Color, rim: Color, rim_width := 1.5) -> void:
	ci.draw_circle(c, radius, fill)
	ci.draw_arc(c, radius, 0, TAU, 28, rim, rim_width, true)


# --- Walls -----------------------------------------------------------------

## Round wall tower from above: shadow, wall ring with crenels, floor and a hatch. Ramparts
## to neighbouring walls come from _segment.
static func _wall_tower(ci: CanvasItem, c: Vector2, r: float, m: Array) -> void:
	var tower := r * 0.82
	ci.draw_circle(c + Vector2(2, 3), tower, SHADOW)
	_ring(ci, c, tower, m[0], m[2], 2.0)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		ci.draw_circle(c + Vector2.from_angle(a) * tower * 0.82, tower * 0.17, m[1])
	ci.draw_circle(c, tower * 0.58, (m[1] as Color).darkened(0.12))
	ci.draw_arc(c, tower * 0.58, 0, TAU, 24, m[2], 1.0, true)
	ci.draw_rect(Rect2(c - Vector2(tower, tower) * 0.18, Vector2(tower, tower) * 0.36), m[2])
	ci.draw_rect(Rect2(c - Vector2(tower, tower) * 0.18, Vector2(tower, tower) * 0.36), m[3], false, 1.0)


# --- Attack ----------------------------------------------------------------

## Turret: a round gun platform with a weapon that shows the biome's attack – cannon
## (neutral), thorn launcher (forest), heavy mortar (mountain), crystal laser (plains),
## poison sprayer (swamp). The weapon turns toward `aim`.
static func _turret(ci: CanvasItem, c: Vector2, r: float, m: Array, biome: Biome.Type, aim: float) -> void:
	ci.draw_circle(c + Vector2(2, 3), r, SHADOW)
	_ring(ci, c, r, m[0], m[2], 2.0)
	for i in 6:
		var a := TAU * i / 6.0
		ci.draw_circle(c + Vector2.from_angle(a) * r * 0.82, r * 0.08, m[2])
	var dir := Vector2.from_angle(aim)
	var side := dir.orthogonal()
	match biome:
		Biome.Type.MOUNTAIN:
			# Short, fat mortar tube.
			ci.draw_colored_polygon(_strip(c, c + dir * r * 0.95, r * 0.62), IRON)
			ci.draw_circle(c + dir * r * 0.95, r * 0.31, IRON)
			ci.draw_circle(c + dir * r * 0.95, r * 0.19, Color("120e0c"))
		Biome.Type.PLAINS:
			# Crystal emitter: a slim prism with a glowing tip.
			ci.draw_colored_polygon(PackedVector2Array([c + side * r * 0.22, c + dir * r * 1.15, c - side * r * 0.22]), m[3])
			ci.draw_line(c, c + dir * r * 1.1, Color.WHITE, 1.5, true)
			ci.draw_circle(c + dir * r * 1.12, r * 0.14, Color(1, 1, 1, 0.9))
		Biome.Type.FOREST:
			# Thorn launcher: a wooden arm with thorns along it.
			ci.draw_colored_polygon(_strip(c, c + dir * r * 1.1, r * 0.28), Color("4a3018"))
			for k in 3:
				var p := c + dir * r * (0.45 + k * 0.25)
				for s in [side, -side]:
					ci.draw_colored_polygon(PackedVector2Array([p + s * r * 0.12, p + s * r * 0.34 + dir * r * 0.1, p + dir * r * 0.12]), m[3])
		Biome.Type.SWAMP:
			# Poison sprayer: a nozzle fed from a bubbling tank.
			ci.draw_colored_polygon(_strip(c, c + dir * r * 1.05, r * 0.24), IRON)
			ci.draw_circle(c + dir * r * 1.05, r * 0.16, m[3])
		_:
			# Cannon barrel with a muzzle ring.
			ci.draw_colored_polygon(_strip(c, c + dir * r * 1.15, r * 0.3), IRON)
			ci.draw_colored_polygon(_strip(c + dir * r * 1.0, c + dir * r * 1.18, r * 0.42), IRON.lightened(0.15))
	# Turret cap on top.
	_ring(ci, c, r * 0.48, m[1], m[2], 1.5)
	if biome == Biome.Type.SWAMP:
		ci.draw_circle(c, r * 0.32, m[3].darkened(0.3))
		ci.draw_circle(c + Vector2(-r * 0.1, -r * 0.08), r * 0.1, m[3])
		ci.draw_circle(c + Vector2(r * 0.12, r * 0.06), r * 0.07, m[3].lightened(0.3))
	else:
		ci.draw_circle(c, r * 0.18, m[3])


# --- Energy ----------------------------------------------------------------

## Tesla coil from above: a base plate, copper windings and a glowing core with sparks.
static func _coil(ci: CanvasItem, c: Vector2, r: float, m: Array) -> void:
	var plate := PackedVector2Array()
	for p in HexMath.corners(r * 0.95):
		plate.append(c + p)
	ci.draw_colored_polygon(_shifted(plate, Vector2(2, 3)), SHADOW)
	ci.draw_colored_polygon(plate, m[0])
	ci.draw_polyline(plate + PackedVector2Array([plate[0]]), m[2], 1.5, true)
	for k in 3:
		ci.draw_arc(c, r * (0.66 - k * 0.14), 0, TAU, 24, COPPER.lightened(k * 0.15), 2.5, true)
	ci.draw_circle(c, r * 0.3, Color("ffd23f"))
	ci.draw_circle(c, r * 0.16, Color("fff6c8"))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var p1 := c + Vector2.from_angle(a) * r * 0.3
		var p2 := c + Vector2.from_angle(a + 0.25) * r * 0.55
		var p3 := c + Vector2.from_angle(a - 0.1) * r * 0.78
		ci.draw_polyline(PackedVector2Array([p1, p2, p3]), Color(1, 0.93, 0.5, 0.85), 1.2, true)


# --- Repair ----------------------------------------------------------------

## Workshop: a big cog with a wrench across it and a green cross in the middle.
static func _workshop(ci: CanvasItem, c: Vector2, r: float, m: Array) -> void:
	var points := PackedVector2Array()
	var teeth := 8
	for t in teeth:
		var a := t * TAU / teeth
		points.append(c + Vector2.from_angle(a - 0.2) * r * 0.78)
		points.append(c + Vector2.from_angle(a - 0.12) * r)
		points.append(c + Vector2.from_angle(a + 0.12) * r)
		points.append(c + Vector2.from_angle(a + 0.2) * r * 0.78)
	ci.draw_colored_polygon(_shifted(points, Vector2(2, 3)), SHADOW)
	ci.draw_colored_polygon(points, m[0])
	ci.draw_polyline(points + PackedVector2Array([points[0]]), m[2], 1.5, true)
	ci.draw_circle(c, r * 0.55, m[1].darkened(0.1))
	# Wrench across the cog.
	var d := Vector2.from_angle(-PI / 4.0)
	ci.draw_colored_polygon(_strip(c - d * r * 0.85, c + d * r * 0.6, r * 0.2), Color("c9ccd1"))
	ci.draw_circle(c + d * r * 0.72, r * 0.24, Color("c9ccd1"))
	ci.draw_circle(c + d * r * 0.86, r * 0.13, m[1].darkened(0.1))
	# Green cross.
	var g := Color("5fd068")
	ci.draw_rect(Rect2(c - Vector2(r * 0.09, r * 0.3), Vector2(r * 0.18, r * 0.6)), g)
	ci.draw_rect(Rect2(c - Vector2(r * 0.3, r * 0.09), Vector2(r * 0.6, r * 0.18)), g)


# --- Aura ------------------------------------------------------------------

## Obelisk from above: a square base turned 45° with a glowing crystal tip and a halo.
static func _obelisk(ci: CanvasItem, c: Vector2, r: float, m: Array) -> void:
	ci.draw_arc(c, r * 1.05, 0, TAU, 32, Color(m[3], 0.45), 2.0, true)
	var base := PackedVector2Array([c + Vector2(0, -r * 0.85), c + Vector2(r * 0.85, 0), c + Vector2(0, r * 0.85), c + Vector2(-r * 0.85, 0)])
	ci.draw_colored_polygon(_shifted(base, Vector2(2, 3)), SHADOW)
	ci.draw_colored_polygon(base, m[0])
	# Four sloped faces: lit from the top left.
	var tip := c
	for i in 4:
		var shade: Color = m[1] if i == 3 or i == 0 else m[2].lightened(0.25)
		ci.draw_colored_polygon(PackedVector2Array([base[i], base[(i + 1) % 4], tip]), shade if i != 1 else m[0])
	ci.draw_circle(c, r * 0.3, Color(m[3], 0.5))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.24), c + Vector2(r * 0.17, 0), c + Vector2(0, r * 0.24), c + Vector2(-r * 0.17, 0)]), m[3].lightened(0.35))


# --- Scout -----------------------------------------------------------------

## Watchtower from above: a round wooden platform with plank lines, a railing and a brass
## spyglass on a tripod.
static func _watchtower(ci: CanvasItem, c: Vector2, r: float, m: Array) -> void:
	var wood: Color = (m[1] as Color).lerp(Color("a8794c"), 0.5)
	ci.draw_circle(c + Vector2(2, 3), r * 0.9, SHADOW)
	_ring(ci, c, r * 0.9, wood, m[2], 2.0)
	for k in range(-2, 3):
		var y := k * r * 0.3
		var half := sqrt(maxf(0.0, (r * 0.85) * (r * 0.85) - y * y))
		ci.draw_line(c + Vector2(-half, y), c + Vector2(half, y), wood.darkened(0.25), 1.0, true)
	ci.draw_arc(c, r * 0.78, 0, TAU, 24, m[2], 1.5, true)
	# Spyglass pointing out, with a glinting lens.
	var d := Vector2.from_angle(-PI / 5.0)
	ci.draw_colored_polygon(_strip(c - d * r * 0.4, c + d * r * 0.75, r * 0.2), MenuTheme.BRASS)
	ci.draw_colored_polygon(_strip(c + d * r * 0.55, c + d * r * 0.8, r * 0.28), MenuTheme.BRASS_LIGHT)
	ci.draw_circle(c + d * r * 0.8, r * 0.12, m[3] if m[3] != Color("d8b25a") else Color("6fb7ff"))
	ci.draw_circle(c, r * 0.12, IRON)


# --- Warehouse -------------------------------------------------------------

## Storehouse roof from above: two slopes meeting at a ridge, with crates by the door.
## Halls toward neighbouring storehouses come from _segment.
static func _storehouse(ci: CanvasItem, c: Vector2, r: float, m: Array) -> void:
	var roof := _roof_colour(m)
	var w := r * 1.25
	ci.draw_rect(Rect2(c - Vector2(w, w * 0.8) / 2.0 + Vector2(2, 3), Vector2(w, w * 0.8)), SHADOW)
	# Ridge running left to right, north slope lit, south slope shaded.
	var rect := Rect2(c - Vector2(w, w * 0.8) / 2.0, Vector2(w, w * 0.8))
	ci.draw_rect(rect, roof.darkened(0.35))
	ci.draw_rect(Rect2(rect.position + Vector2(1.5, 1.5), Vector2(rect.size.x - 3, rect.size.y / 2.0 - 1.5)), roof.lightened(0.1))
	ci.draw_rect(Rect2(rect.position + Vector2(1.5, rect.size.y / 2.0), Vector2(rect.size.x - 3, rect.size.y / 2.0 - 1.5)), roof.darkened(0.12))
	for k in 4:
		var x := rect.position.x + rect.size.x * (k + 1) / 5.0
		ci.draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y - 2), roof.darkened(0.25), 1.0)
	ci.draw_line(Vector2(rect.position.x, c.y), Vector2(rect.end.x, c.y), roof.lightened(0.35), 1.5)
	for i in 2:
		var crate := Rect2(c + Vector2(r * (0.2 + i * 0.36), r * 0.5), Vector2(r * 0.32, r * 0.32))
		ci.draw_rect(crate, Color("b48a5a"))
		ci.draw_rect(crate, Color("5a3f26"), false, 1.0)
		ci.draw_line(crate.position, crate.end, Color("5a3f26"), 1.0)


static func _roof_colour(m: Array) -> Color:
	return Color("6f8fb0") if m[0] == MATERIALS[Biome.Type.PLAINS][0] else Color("8a4b32")


# --- Combined structures ---------------------------------------------------

## Connecting piece from a building at `c` toward the shared hex side in direction `d`,
## drawn from `from` to `to` px out (patterns are measured from `c`, so a partial piece
## lines up with the full one): wall rampart, storehouse hall, or a connecting wing.
static func _segment(ci: CanvasItem, type: StringName, c: Vector2, d: Vector2, from: float, to: float, r: float, m: Array, shadow: bool, wide := 1.0) -> void:
	var a := c + d * from
	var b := c + d * to
	var n := d.orthogonal()
	var w := r * (0.78 if type == &"wall" else 1.25 if type == &"warehouse" else 0.72) * wide
	if shadow:
		ci.draw_colored_polygon(_shifted(_strip(a, b, w), Vector2(2, 3)), SHADOW)
	if type == &"warehouse":
		# The hall's roof continues: ridge along the middle, one slope lit, one shaded.
		var roof := _roof_colour(m)
		ci.draw_colored_polygon(_strip(a, b, w), roof.darkened(0.35))
		ci.draw_colored_polygon(PackedVector2Array([a, b, b + n * (w / 2.0 - 1.5), a + n * (w / 2.0 - 1.5)]), roof.lightened(0.1))
		ci.draw_colored_polygon(PackedVector2Array([a, b, b - n * (w / 2.0 - 1.5), a - n * (w / 2.0 - 1.5)]), roof.darkened(0.12))
		ci.draw_line(a, b, roof.lightened(0.35), 1.5, true)
		return
	ci.draw_colored_polygon(_strip(a, b, w), m[2])
	match type:
		&"wall":
			# Rampart: walkway between two parapets with merlons and crenels.
			ci.draw_colored_polygon(_strip(a, b, w - 2.5), m[0])
			ci.draw_colored_polygon(_strip(a, b, w * 0.42), (m[1] as Color).darkened(0.08))
			_every(r * 0.9, r * 0.42, from, to, func(t: float) -> void:
				for side in [n, -n]:
					var p: Vector2 = c + d * t + side * (w / 2.0 - w * 0.13)
					ci.draw_colored_polygon(_strip(p - d * r * 0.12, p + d * r * 0.12, w * 0.22), m[1]))
		&"energy":
			# Insulated conduit housing with hazard stripes and a glowing power line.
			ci.draw_colored_polygon(_strip(a, b, w - 2.5), IRON.lightened(0.15))
			_every(r * 0.6, r * 0.3, from, to - r * 0.1, func(t: float) -> void:
				var p := c + d * t
				ci.draw_colored_polygon(_strip(p, p + d * r * 0.12, w - 2.5), Color("ffd23f").darkened(0.2)))
			ci.draw_line(a, b, Color("fff6c8"), 1.5, true)
		&"repair":
			# Workshop annex: a ribbed metal roof with a skylight strip.
			var metal := Color("8d939b")
			ci.draw_colored_polygon(_strip(a, b, w - 2.5), metal)
			ci.draw_colored_polygon(_strip(a, b, w * 0.3), Color("cfe8f0"))
			_every(r * 0.5, r * 0.22, from, to, func(t: float) -> void:
				var p := c + d * t
				ci.draw_line(p + n * (w / 2.0 - 1.5), p - n * (w / 2.0 - 1.5), metal.darkened(0.3), 1.0))
		&"aura":
			# Arcade of pale stone with a glowing channel in the floor.
			ci.draw_colored_polygon(_strip(a, b, w - 2.5), (m[1] as Color).darkened(0.05))
			ci.draw_line(a, b, Color(m[3], 0.5), w * 0.35, true)
			ci.draw_line(a, b, (m[3] as Color).lightened(0.4), 1.5, true)
			for side in [n, -n]:
				ci.draw_line(a + side * (w / 2.0 - 1.5), b + side * (w / 2.0 - 1.5), m[0], 2.0)
		&"scout":
			# Covered wooden walkway: planks with a railing on both sides.
			var wood := Color("a8794c")
			ci.draw_colored_polygon(_strip(a, b, w - 2.5), wood)
			_every(r * 0.5, r * 0.2, from, to, func(t: float) -> void:
				var p := c + d * t
				ci.draw_line(p + n * (w / 2.0 - 1.5), p - n * (w / 2.0 - 1.5), wood.darkened(0.3), 1.0))
			for side in [n, -n]:
				ci.draw_line(a + side * (w / 2.0 - 2.0), b + side * (w / 2.0 - 2.0), Color("5a3f26"), 1.5)
		_:
			# Gun deck between turrets: stone floor with low crenellated parapets.
			ci.draw_colored_polygon(_strip(a, b, w - 2.5), m[0])
			ci.draw_colored_polygon(_strip(a, b, w * 0.5), (m[1] as Color).darkened(0.1))
			_every(r * 1.0, r * 0.38, from, to - r * 0.2, func(t: float) -> void:
				for side in [n, -n]:
					var p: Vector2 = c + d * t + side * (w / 2.0 - w * 0.12)
					ci.draw_colored_polygon(_strip(p - d * r * 0.1, p + d * r * 0.1, w * 0.2), m[1]))


## Calls `piece` at start, start + step, … for every position between `from` and `to`.
static func _every(start: float, step: float, from: float, to: float, piece: Callable) -> void:
	var t := start
	while t < to:
		if t >= from:
			piece.call(t)
		t += step


## The building on the shared hex side where two neighbours meet; `d` points across it.
static func _joint(ci: CanvasItem, type: StringName, at: Vector2, d: Vector2, r: float, m: Array) -> void:
	var n := d.orthogonal()
	match type:
		&"wall":
			pass   # the rampart simply runs on into the neighbour's
		&"energy":
			# Transformer: a box with two copper coils and a spark between them.
			_box(ci, at, n, d, Vector2(r * 0.95, r * 0.6), IRON.lightened(0.2), m[2])
			for side in [n, -n]:
				var coil: Vector2 = at + side * r * 0.22
				ci.draw_circle(coil, r * 0.17, COPPER)
				ci.draw_arc(coil, r * 0.17, 0, TAU, 12, COPPER.darkened(0.4), 1.0, true)
				ci.draw_circle(coil, r * 0.07, COPPER.lightened(0.4))
			ci.draw_polyline(PackedVector2Array([at + n * r * 0.08, at + d * r * 0.06, at - d * r * 0.04, at - n * r * 0.08]), Color("fff6c8"), 1.2, true)
		&"repair":
			# Shared crane: a turntable with its jib along the hex side and a green lamp.
			ci.draw_circle(at + Vector2(1.5, 2), r * 0.36, SHADOW)
			ci.draw_circle(at, r * 0.36, m[0])
			ci.draw_arc(at, r * 0.36, 0, TAU, 16, m[2], 1.5, true)
			ci.draw_colored_polygon(_strip(at - n * r * 0.55, at + n * r * 0.55, r * 0.14), MenuTheme.BRASS)
			ci.draw_circle(at + n * r * 0.55, r * 0.09, IRON)
			ci.draw_circle(at, r * 0.14, Color("5fd068"))
		&"aura":
			# Crystal arch: a floating crystal with a halo over the hex side.
			ci.draw_arc(at, r * 0.42, 0, TAU, 20, Color(m[3], 0.55), 1.5, true)
			var crystal := PackedVector2Array([at - n * r * 0.3, at + d * r * 0.16, at + n * r * 0.3, at - d * r * 0.16])
			ci.draw_colored_polygon(_shifted(crystal, Vector2(1.5, 2)), SHADOW)
			ci.draw_colored_polygon(crystal, m[3])
			ci.draw_colored_polygon(PackedVector2Array([at - n * r * 0.3, at + d * r * 0.16, at]), (m[3] as Color).lightened(0.45))
		&"scout":
			# Lookout platform with a pennant.
			ci.draw_circle(at + Vector2(1.5, 2), r * 0.34, SHADOW)
			ci.draw_circle(at, r * 0.34, Color("a8794c"))
			ci.draw_arc(at, r * 0.34, 0, TAU, 16, Color("5a3f26"), 1.5, true)
			ci.draw_circle(at, r * 0.07, IRON)
			ci.draw_colored_polygon(PackedVector2Array([at, at + n * r * 0.42, at + n * r * 0.22 + d * r * 0.2]), Color("e05545"))
		&"warehouse":
			# Loading bay: crates stacked where the halls meet.
			for k in 2:
				var crate := Rect2(at + n * r * (k * 0.36 - 0.18) + - Vector2(r, r) * 0.16, Vector2(r, r) * 0.32)
				ci.draw_rect(crate, Color("b48a5a"))
				ci.draw_rect(crate, Color("5a3f26"), false, 1.0)
				ci.draw_line(crate.position, crate.end, Color("5a3f26"), 1.0)
		_:
			# Magazine: a small bunker with a pyramid of cannonballs.
			_box(ci, at, n, d, Vector2(r * 0.8, r * 0.62), m[0], m[2])
			for k in 3:
				ci.draw_circle(at + n * r * (k - 1) * 0.2 + d * r * 0.08, r * 0.1, IRON)
			for k in 2:
				ci.draw_circle(at + n * r * (k - 0.5) * 0.2 - d * r * 0.1, r * 0.1, IRON.lightened(0.2))


## Box `size` (x along `n`, y along `d`) centred on `at`, with shadow and rim.
static func _box(ci: CanvasItem, at: Vector2, n: Vector2, d: Vector2, size: Vector2, fill: Color, rim: Color) -> void:
	var hx := n * size.x / 2.0
	var hy := d * size.y / 2.0
	var box := PackedVector2Array([at - hx - hy, at + hx - hy, at + hx + hy, at - hx + hy])
	ci.draw_colored_polygon(_shifted(box, Vector2(1.5, 2)), SHADOW)
	ci.draw_colored_polygon(box, fill)
	ci.draw_polyline(box + PackedVector2Array([box[0]]), rim, 1.5, true)
