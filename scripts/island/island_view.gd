class_name IslandView
extends Node2D
## Draws an Island as flat coloured hexes, previews the active build tool and
## spawns scenes for towers. Placeholder visuals; swap for assets later without touching Island.

enum Tool { TOWER, TILE, BIOME }

@export var hex_size := 48.0
@export var starter_radius := 2
## Scene spawned for a tower. Its root must expose `tower_type` and `aim_angle` properties.
@export var placeable_scene: PackedScene
## Damage dealt by the debug key, until enemies exist.
@export var debug_damage := 25.0

const OUTLINE_COLOR := Color(0.25, 0.2, 0.15, 0.6)
const HQ_COLOR := Color("8c8f99")
const HOVER_OK_COLOR := Color(1, 1, 1, 0.9)
const HOVER_BLOCKED_COLOR := Color(0.9, 0.2, 0.2, 0.9)
const GHOST_ALPHA := 0.45
const WASTELAND_COLOR := Color("3d2b22")
## Interim tier display: biome colours get darker with every tier (light = 0, dark = 7).
const TIER_SHADE_PER_LEVEL := 0.06
const REPAIR_COLOR := Color("5fd068")
const HP_RING_SCALE := 0.84
const HP_RING_WIDTH := 4.0
const HP_LOW_COLOR := Color("e05545")
const HP_FULL_COLOR := Color("5fd068")
const SHIELD_COLOR := Color("1e7bff")
const ENERGY_COLOR := Color("ffd23f")
const ENERGY_EMPTY_COLOR := Color("c0392b")
const TRACK_COLOR := Color(0, 0, 0, 0.5)
## Gap (in hex sides) at both ends of each status arc.
const ARC_GAP := 0.08
const WALL_REACH_COLOR := Color("9fb4d8")
const ATTACK_REACH_COLOR := Color(1, 1, 1)

var island: Island
var tool := Tool.TOWER
var tool_biome := Biome.Type.FOREST
var hovered_coord := Vector2i.ZERO
## Map overlay shown on top of the tiles: &"energy", &"repair", &"hp", &"tier" or &"" (none).
var overlay: StringName = &""

var _objects: Dictionary[Vector2i, Node2D] = {}
var _hex_points: PackedVector2Array
var _font: Font


func _ready() -> void:
	island = Island.create_starter(starter_radius)
	island.tower_destroyed.connect(_free_tower_node)
	_hex_points = HexMath.corners(hex_size)
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	island.tick(delta)
	hovered_coord = world_to_hex(get_global_mouse_position())
	queue_redraw()


func set_tool(new_tool: Tool, biome: Biome.Type = tool_biome) -> void:
	tool = new_tool
	tool_biome = biome


func world_to_hex(world_position: Vector2) -> Vector2i:
	return HexMath.from_pixel(to_local(world_position), hex_size)


func hex_center_world(coord: Vector2i) -> Vector2:
	return to_global(HexMath.to_pixel(coord, hex_size))


## Turns the tower's turret toward `angle` (radians, world space).
func aim_tower(coord: Vector2i, angle: float) -> void:
	var node: Node2D = _objects.get(coord)
	if node:
		node.set(&"aim_angle", angle)


# --- Input ---------------------------------------------------------------

func handle_tap(world_position: Vector2) -> void:
	var coord := world_to_hex(world_position)
	match tool:
		Tool.TOWER:
			_tower_primary(coord)
		Tool.TILE:
			island.add_tile(coord)
		Tool.BIOME:
			if island.has_tile(coord):
				island.set_biome(coord, tool_biome)
			else:
				island.add_tile(coord, tool_biome)


func handle_secondary_tap(world_position: Vector2) -> void:
	var coord := world_to_hex(world_position)
	match tool:
		Tool.TOWER:
			if island.remove_tower(coord) != &"":
				_free_tower_node(coord)
		Tool.TILE:
			island.remove_tile(coord)
		Tool.BIOME:
			island.set_biome(coord, Biome.Type.NEUTRAL)


## Debug keys until enemies and merging exist: D damages, +/- change the tier.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_D:
			island.damage_tower(hovered_coord, debug_damage)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_shift_tier(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_shift_tier(-1)


func _shift_tier(step: int) -> void:
	var tile := island.get_tile(hovered_coord)
	if tile:
		island.set_tier(hovered_coord, tile.tier + step)


## Free tile: place the first tower type. Tower: cycle to the next type.
func _tower_primary(coord: Vector2i) -> void:
	var tile := island.get_tile(coord)
	if tile == null or tile.is_hq:
		return
	if tile.is_free():
		var type: StringName = TowerDefs.TYPES[0]
		if placeable_scene and island.place_tower(coord, type):
			var node := placeable_scene.instantiate() as Node2D
			node.set(&"tower_type", type)
			node.position = HexMath.to_pixel(coord, hex_size)
			add_child(node)
			_objects[coord] = node
	else:
		var next := (TowerDefs.TYPES.find(tile.tower.type) + 1) % TowerDefs.TYPES.size()
		if island.change_tower_type(coord, TowerDefs.TYPES[next]):
			_objects[coord].set(&"tower_type", TowerDefs.TYPES[next])


func _free_tower_node(coord: Vector2i) -> void:
	var node: Node2D = _objects.get(coord)
	if node:
		_objects.erase(coord)
		node.queue_free()


# --- Drawing -------------------------------------------------------------

func _draw() -> void:
	var inner := _scaled(_hex_points, 0.92)
	for coord in island.coords():
		var tile := island.get_tile(coord)
		var center := HexMath.to_pixel(coord, hex_size)
		draw_colored_polygon(_offset(inner, center), WASTELAND_COLOR if tile.destroyed else tile_color(tile))
		draw_polyline(_closed(_offset(inner, center)), OUTLINE_COLOR, 2.0, true)
		if tile.destroyed:
			_draw_wasteland(center)
		elif tile.is_hq:
			_draw_hq(center)
		elif tile.tier > 0:
			_draw_tier(center, tile)
		if tile.tower:
			_draw_status(coord, center, tile)
		elif tile.is_hq or (not tile.destroyed and tile.hp < island.tile_max_hp(coord)):
			# Ground HP all around the edge: always for the HQ, otherwise once damaged.
			var ratio := clampf(tile.hp / island.tile_max_hp(coord), 0.0, 1.0)
			_draw_arc(center, 0, 6, ratio, HP_LOW_COLOR.lerp(HP_FULL_COLOR, ratio), TRACK_COLOR)
	_draw_overlay()
	_draw_tower_reach()
	_draw_hover()


## Base colour of a tile: its biome, darkened per tier.
static func tile_color(tile: IslandTile) -> Color:
	return Biome.color_of(tile.biome).darkened(TIER_SHADE_PER_LEVEL * tile.tier)


## Tints every tile for the active overlay (chosen with the HUD's overlay icons).
func _draw_overlay() -> void:
	if overlay == &"":
		return
	var inner := _scaled(_hex_points, 0.92)
	for coord in island.coords():
		var tile := island.get_tile(coord)
		var center := HexMath.to_pixel(coord, hex_size)
		var hex := _offset(inner, center)
		match overlay:
			&"energy":
				_overlay_energy(coord, tile, hex, center)
			&"repair":
				_overlay_repair(coord, tile, hex)
			&"hp":
				_overlay_hp(coord, tile, hex)
			&"tier":
				_overlay_tier(tile, hex, center)


## Generators bright, storages saturated by their reserve (grey = empty, full yellow = full,
## red outline when empty), empty tiles by how much they let through.
func _overlay_energy(coord: Vector2i, tile: IslandTile, hex: PackedVector2Array, center: Vector2) -> void:
	if EnergyGrid.generator_at(island, coord):
		draw_colored_polygon(hex, Color(ENERGY_COLOR, 0.8))
		return
	var cap := EnergyGrid.capacity(tile)
	if cap > 0.0:
		var ratio := clampf(tile.energy / cap, 0.0, 1.0)
		var reserve := Color.from_hsv(ENERGY_COLOR.h, ENERGY_COLOR.s * ratio, 0.95, 0.75)
		draw_colored_polygon(hex, reserve)
		if ratio < 0.05:
			draw_polyline(_closed(hex), ENERGY_EMPTY_COLOR, 3.0, true)
		_draw_label(center + Vector2(0, hex_size * 0.5), "%d%%" % roundi(ratio * 100.0), Color(0.15, 0.1, 0.05))
		return
	var through := EnergyGrid.pass_through(tile)
	draw_colored_polygon(hex, Color(0.1, 0.1, 0.15, 0.55 * (1.0 - through) + 0.1))
	if not tile.is_hq:
		_draw_label(center, "%d%%" % roundi(through * 100.0), Color(1, 1, 1, 0.85))


## Tiles covered by Repair towers in green (stronger where more heal arrives);
## damaged buildings and ground outlined in red.
func _overlay_repair(coord: Vector2i, tile: IslandTile, hex: PackedVector2Array) -> void:
	var coverage := 0.0
	for source in HexMath.area(coord, TowerDefs.REPAIR_REACH_MAX):
		var other := island.get_tile(source)
		if other and other.tower and other.tower.type == &"repair":
			var profile := RepairProfiles.for_tile(island, source)
			var d := HexMath.distance(coord, source)
			if d <= profile.reach():
				coverage = maxf(coverage, profile.falloff[d])
	if coverage > 0.0:
		draw_colored_polygon(hex, Color(REPAIR_COLOR, 0.15 + 0.3 * coverage))
	if _health_ratio(coord, tile) < 0.999:
		draw_polyline(_closed(hex), HP_LOW_COLOR, 3.0, true)


## Tower HP where a tower stands, otherwise ground HP: green (full) to red (low).
func _overlay_hp(coord: Vector2i, tile: IslandTile, hex: PackedVector2Array) -> void:
	if tile.destroyed:
		draw_colored_polygon(hex, Color(0, 0, 0, 0.6))
		return
	var ratio := _health_ratio(coord, tile)
	draw_colored_polygon(hex, Color(HP_LOW_COLOR.lerp(HP_FULL_COLOR, ratio), 0.55))


## Tier as a light-to-dark ramp (Tier 0 light, Tier 7 dark) with the number on top.
func _overlay_tier(tile: IslandTile, hex: PackedVector2Array, center: Vector2) -> void:
	var shade := Color("f2efe6").darkened(tile.tier / 7.0 * 0.85)
	draw_colored_polygon(hex, Color(shade, 0.8))
	var text_color := Color.BLACK if tile.tier < 4 else Color.WHITE
	_draw_label(center + Vector2(0, -hex_size * 0.3), str(tile.tier), text_color, 18)


func _health_ratio(coord: Vector2i, tile: IslandTile) -> float:
	if tile.tower:
		return clampf(tile.tower.hp / island.tower_max_hp(coord), 0.0, 1.0)
	return clampf(tile.hp / island.tile_max_hp(coord), 0.0, 1.0)


func _draw_label(center: Vector2, text: String, color: Color, font_size := 13) -> void:
	var width := hex_size
	draw_string_outline(_font, center + Vector2(-width / 2.0, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 3, Color(0, 0, 0, 0.5))
	draw_string(_font, center + Vector2(-width / 2.0, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _draw_hover() -> void:
	var center := HexMath.to_pixel(hovered_coord, hex_size)
	var outline := _closed(_offset(_hex_points, center))
	var tile := island.get_tile(hovered_coord)
	if tile == null:
		# Empty hex: ghost preview where the tool can add a tile.
		if tool != Tool.TOWER and island.can_add_tile(hovered_coord):
			var biome := tool_biome if tool == Tool.BIOME else Biome.Type.NEUTRAL
			var color := Biome.color_of(biome)
			color.a = GHOST_ALPHA
			draw_colored_polygon(_offset(_scaled(_hex_points, 0.92), center), color)
			draw_polyline(outline, HOVER_OK_COLOR, 2.0, true)
		return
	# Tile tool: red where right click can't remove (HQ, towers, would split the island).
	var ok := island.can_remove_tile(hovered_coord) if tool == Tool.TILE else not tile.is_hq
	var color := HOVER_OK_COLOR if ok else HOVER_BLOCKED_COLOR
	if tool == Tool.BIOME and ok:
		color = Biome.color_of(tool_biome).lightened(0.3)
	draw_polyline(outline, color, 3.0, true)


## HP, shield and energy share the hex edge, each on its own arc of at least 2 sides.
## Perimeter corners clockwise: 0 top, 1 upper right, 2 lower right, 3 bottom, 4 lower left, 5 upper left.
## Shield: top → lower right. Energy: lower right → lower left. HP: the remaining sides.
func _draw_status(coord: Vector2i, center: Vector2, tile: IslandTile) -> void:
	var tower := tile.tower
	var max_shield := island.tower_max_shield(coord)
	var cap := EnergyGrid.capacity(tile)
	var hp_start := 4 if cap > 0.0 else 2
	var hp_edges := 6 - (2 if max_shield > 0.0 else 0) - (2 if cap > 0.0 else 0)
	var hp_ratio := clampf(tower.hp / island.tower_max_hp(coord), 0.0, 1.0)
	_draw_arc(center, hp_start, hp_edges, hp_ratio, HP_LOW_COLOR.lerp(HP_FULL_COLOR, hp_ratio), TRACK_COLOR)
	if max_shield > 0.0:
		var points := _arc(center, 0, 2, 1.0)
		draw_polyline(points, TRACK_COLOR, HP_RING_WIDTH, true)
		points = _arc(center, 0, 2, clampf(tower.shield / max_shield, 0.0, 1.0))
		for i in points.size() - 1:
			draw_dashed_line(points[i], points[i + 1], SHIELD_COLOR, HP_RING_WIDTH, 6.0)
	if cap > 0.0:
		var ratio := clampf(tile.energy / cap, 0.0, 1.0)
		var track := ENERGY_EMPTY_COLOR if ratio < 0.05 else TRACK_COLOR
		# Anchored at the lower left, so energy drains from right to left.
		_draw_arc(center, 2, 2, ratio, ENERGY_COLOR, track, true)


func _draw_arc(center: Vector2, start: int, edges: int, ratio: float, color: Color, track: Color, from_end := false) -> void:
	draw_polyline(_arc(center, start, edges, 1.0), track, HP_RING_WIDTH, true)
	if ratio > 0.0:
		draw_polyline(_arc(center, start, edges, ratio, from_end), color, HP_RING_WIDTH, true)


## Points along `edges` sides of the hex edge, clockwise from perimeter corner `start`,
## covering `ratio` of them — anchored at the start, or at the end with `from_end`.
## A small gap at both ends keeps neighbouring arcs apart.
func _arc(center: Vector2, start: int, edges: int, ratio: float, from_end := false) -> PackedVector2Array:
	var corners := _scaled(_hex_points, HP_RING_SCALE)
	var length := (edges - 2.0 * ARC_GAP) * ratio
	var from := edges - ARC_GAP - length if from_end else ARC_GAP
	var to := from + length
	var result := PackedVector2Array([_perimeter_point(corners, start, from) + center])
	for i in range(int(floor(from)) + 1, int(ceil(to))):
		result.append(_perimeter_point(corners, start, float(i)) + center)
	result.append(_perimeter_point(corners, start, to) + center)
	return result


## Point `distance` sides (fractional) clockwise from perimeter corner `start`.
static func _perimeter_point(corners: PackedVector2Array, start: int, distance: float) -> Vector2:
	var edge := int(floor(distance))
	var t := distance - edge
	# Perimeter corner i (0 = top, clockwise) is corners[(i + 5) % 6].
	var a := corners[(start + edge + 5) % 6]
	var b := corners[(start + edge + 6) % 6]
	return a.lerp(b, t)


## While hovering a tower (or the HQ), tint the tiles it affects:
## generators by how much energy arrives, walls their buffed neighbours, attack towers their range.
func _draw_tower_reach() -> void:
	var tile := island.get_tile(hovered_coord)
	if tile == null:
		return
	var shares := {}
	var color := ENERGY_COLOR
	var profile := EnergyGrid.generator_at(island, hovered_coord)
	if profile:
		shares = EnergyGrid.delivery_map(island, hovered_coord, profile)
	elif tile.tower and tile.tower.type == &"aura":
		var aura := AuraProfiles.for_tile(island, hovered_coord)
		color = aura.color
		for coord in HexMath.area(hovered_coord, aura.radius + (1 if aura.enemy_weaken > 0.0 else 0)):
			if island.has_tile(coord):
				shares[coord] = 1.0 if HexMath.distance(coord, hovered_coord) <= aura.radius else 0.4
	elif tile.tower and tile.tower.type == &"repair":
		color = REPAIR_COLOR
		var repair := RepairProfiles.for_tile(island, hovered_coord)
		for coord in HexMath.area(hovered_coord, repair.reach()):
			if island.has_tile(coord):
				shares[coord] = repair.falloff[HexMath.distance(coord, hovered_coord)]
	elif tile.tower and tile.tower.type == &"wall":
		color = WALL_REACH_COLOR
		for n in HexMath.neighbors(hovered_coord):
			if island.has_tile(n):
				shares[n] = 1.0
	elif tile.tower and tile.tower.type == &"attack":
		color = ATTACK_REACH_COLOR
		var reach := int(AttackProfiles.for_tile(island, hovered_coord).range_hexes)
		for coord in HexMath.area(hovered_coord, reach):
			if island.has_tile(coord) and coord != hovered_coord:
				shares[coord] = 0.6
	var inner := _scaled(_hex_points, 0.92)
	for coord in shares:
		draw_colored_polygon(_offset(inner, HexMath.to_pixel(coord, hex_size)), Color(color, 0.4 * shares[coord]))


func _draw_tier(center: Vector2, tile: IslandTile) -> void:
	var text := "T%d" % tile.tier
	# Left edge of the hex, where towers and health bars don't cover it.
	var pos := center + Vector2(-hex_size * 0.62, 5)
	var text_color := Color(0, 0, 0, 0.55) if tile.biome == Biome.Type.PLAINS else Color(1, 1, 1, 0.8)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)


## Charred cracks on a tile destroyed in battle.
func _draw_wasteland(center: Vector2) -> void:
	var crack := Color("1e1410")
	draw_polyline(PackedVector2Array([center + Vector2(-20, -14), center + Vector2(-4, -2), center + Vector2(-10, 14)]), crack, 2.0, true)
	draw_polyline(PackedVector2Array([center + Vector2(4, -2), center + Vector2(18, 6), center + Vector2(22, -10)]), crack, 2.0, true)
	draw_circle(center + Vector2(8, 16), 3.0, Color("e0602a", 0.6))


## Placeholder keep: grey hex with crenellated tower silhouette.
func _draw_hq(center: Vector2) -> void:
	draw_colored_polygon(_offset(_scaled(_hex_points, 0.7), center), HQ_COLOR)
	var w := hex_size * 0.5
	var h := hex_size * 0.45
	var body := Rect2(center + Vector2(-w / 2.0, -h / 2.0), Vector2(w, h))
	draw_rect(body, HQ_COLOR.darkened(0.35))
	var merlon := w / 5.0
	for i in 3:
		draw_rect(Rect2(body.position + Vector2(i * 2 * merlon, -merlon), Vector2(merlon, merlon)), HQ_COLOR.darkened(0.35))


static func _scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(p * factor)
	return result


static func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(p + by)
	return result


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result
