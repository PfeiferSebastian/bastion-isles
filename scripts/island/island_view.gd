class_name IslandView
extends Node2D
## Draws the island with painted tiles, spawns scenes for towers and places inventory items
## (click to select and place, or drag from the inventory onto the map).

## Short feedback for the player at a world position (e.g. "Need 50 gold").
signal message(world_position: Vector2, text: String)
## The player wants to build while the island isn't editable (picked an inventory slot during
## a running mission); main switches to the battle edit mode.
signal edit_requested

@export var hex_size := 48.0
## Rings of tiles around the HQ at the start (1 = the HQ plus one ring).
@export var starter_radius := 1
## Start from the saved island (IslandSave) when there is one; the balance sim leaves it off.
@export var load_saved := false
## Scene spawned for a tower. Its root must expose `tower_type` and `aim_angle` properties.
@export var placeable_scene: PackedScene
## Damage dealt by the debug key, until enemies exist.
@export var debug_damage := 25.0

const HOVER_OK_COLOR := Color(1, 1, 1, 0.9)
const HOVER_BLOCKED_COLOR := Color(0.9, 0.2, 0.2, 0.9)
const GHOST_ALPHA := 0.45
## Tint for the art of a tile destroyed in battle.
const WASTELAND_TINT := Color(0.38, 0.28, 0.22)
## Interim tier display for the plain coloured hexes: darker with every tier (light = 0, dark = 7).
const TIER_SHADE_PER_LEVEL := 0.06
## Tile art only darkens slightly with every tier above 1 (the tier label shows the rest).
const ART_TIER_SHADE := 0.02
const REPAIR_COLOR := Color("5fd068")
const HP_RING_SCALE := 0.84
const HP_RING_WIDTH := 3.0
const HP_LOW_COLOR := Color("e05545")
const HP_FULL_COLOR := Color("5fd068")
const SHIELD_COLOR := Color("1e7bff")
const ENERGY_COLOR := Color("ffd23f")
const ENERGY_EMPTY_COLOR := Color("c0392b")
const TRACK_COLOR := Color(0, 0, 0, 0.55)
## Bars only appear when they matter (see _draw_group_status): energy below this share.
const ENERGY_SHOWN_BELOW := 0.5
## Gap (in hex sides) at both ends of each status arc.
const ARC_GAP := 0.08
const WALL_REACH_COLOR := Color("9fb4d8")
const MERGE_COLOR := Color("ffd27a")
const ATTACK_REACH_COLOR := Color(1, 1, 1)
## Outline of hexes under construction (Island.construction).
const CONSTRUCTION_COLOR := Color("ffb347")

var island: Island
## Whether clicks may change the island (place, merge, tier up, pick up). Off during a running
## mission outside the battle edit mode, so map clicks there only aim focus fire.
var editable := true
## Inventory item selected for placing (see Inventory), or empty.
var held: Dictionary = {}
var hovered_coord := Vector2i.ZERO
## Map overlay shown on top of the tiles: &"energy", &"repair", &"hp", &"tier" or &"" (none).
var overlay: StringName = &""

var _objects: Dictionary[Vector2i, Node2D] = {}
## Members of combined buildings: coord -> {lead (the node drawing the group), index (in its
## group art)}, so a turret's aim reaches the drawing that shows it.
var _group_members: Dictionary[Vector2i, Dictionary] = {}
## Layer above the towers for status rings, overlays and hover; helpers draw onto _canvas.
var _top := Node2D.new()
## Container for tower nodes, sorted by depth (back rows first).
var _towers := Node2D.new()
var _canvas: CanvasItem = self
var _hex_points: PackedVector2Array
var _font: Font
var _dragging := false
## A slot purchase not placed yet: {item, price} (see note_purchase), or {}.
var _pending_purchase: Dictionary = {}
var _drag_start := Vector2.ZERO

const DRAG_THRESHOLD := 10.0


func _ready() -> void:
	if load_saved:
		island = IslandSave.load_island(starter_radius)
		island.persist_blueprints = true
	else:
		island = Island.create_starter(starter_radius)
	island.tower_destroyed.connect(_free_tower_node)
	island.tile_changed.connect(_on_tile_changed)
	island.tile_removed.connect(_on_tile_changed)
	# Towers are sorted by depth inside their own container; the top layer stays above them.
	_towers.y_sort_enabled = true
	add_child(_towers)
	_top.z_index = 1
	_top.draw.connect(_draw_top)
	add_child(_top)
	_hex_points = HexMath.corners(hex_size)
	_font = ThemeDB.fallback_font
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower:
			_spawn_tower_node(coord, tower.type)


func _process(delta: float) -> void:
	# The view keeps running while the battle is paused (edit mode), the island doesn't; in
	# the edit mode it just stays full.
	if island.editing:
		island.fill_up()
	elif not get_tree().paused:
		island.tick(delta)
	hovered_coord = world_to_hex(get_global_mouse_position())
	queue_redraw()
	_top.queue_redraw()


func world_to_hex(world_position: Vector2) -> Vector2i:
	return HexMath.from_pixel(to_local(world_position), hex_size)


func hex_center_world(coord: Vector2i) -> Vector2:
	return to_global(HexMath.to_pixel(coord, hex_size))


## Turns the tower's turret toward `angle` (radians, world space).
func aim_tower(coord: Vector2i, angle: float) -> void:
	var node: Node2D = _objects.get(coord)
	if node:
		node.set(&"aim_angle", angle)
	var member: Dictionary = _group_members.get(coord, {})
	if not member.is_empty() and is_instance_valid(member.lead):
		member.lead.group_art.aims[member.index] = angle
		member.lead.queue_redraw()


# --- Input ---------------------------------------------------------------

func handle_tap(world_position: Vector2) -> void:
	if not editable:
		return
	if not held.is_empty():
		place_item(world_to_hex(world_position), held, world_position)
		_keep_or_release()
	elif overlay == &"merge":
		var coord := world_to_hex(world_position)
		if island.merge(coord):
			message.emit(world_position, "Merged into a %d-hex tower" % island.get_tower(island.merge_root_of(coord)).size())
		elif island.get_tower(coord):
			message.emit(world_position, "Needs touching towers of this type and tier: %d hexes in all" % island.get_tower(coord).tier)


## Right click: drops the held item, otherwise picks up the top layer of the tile
## (tower, then biome stone, then the tile itself) back into the inventory. Does nothing while
## the island isn't editable.
func handle_secondary_tap(world_position: Vector2) -> void:
	if not held.is_empty():
		release_hold()
		return
	if editable:
		pick_up(world_to_hex(world_position), world_position)


## Puts `item` from the inventory onto `coord`. Towers and biome stones on an empty hex next
## to the island take a tile from the inventory along. Returns true if it was placed.
func place_item(coord: Vector2i, item: Dictionary, world_position: Vector2) -> bool:
	var inventory := island.treasury.inventory
	if not _can_place(coord, item):
		return false
	if not island.ensure_item(item):
		var kind := Island.purchase_kind(item)
		message.emit(world_position, "No %s left" % Inventory.label_of(item) if kind == &"" else "Needs %d blueprints" % island.blueprint_cost(kind))
		return false
	var tile := island.get_tile(coord)
	match item.kind:
		&"tower":
			if not placeable_scene:
				return false
			if tile == null:
				# Empty ground next to the island: a tile from the inventory goes down first.
				if not island.ensure_item(Inventory.tile_item()):
					message.emit(world_position, "Needs a tile too")
					return false
				inventory.take(Inventory.tile_item())
				island.add_tile(coord)
			if island.place_tower(coord, item.type, item.level, item.get("tier", 1)) == null:
				return false
			inventory.take(item)
			_spawn_tower_node(coord, item.type)
			if island.get_tower(coord).solo:
				message.emit(world_position, "Stays a single %s: at most %d combine" % [String(item.type).capitalize(), Island.MAX_CLUSTER])
		&"tile":
			if not island.can_add_tile(coord):
				return false
			inventory.take(item)
			island.add_tile(coord)
		&"stone":
			if tile == null:
				# A stone on an empty hex needs a tile to go with it.
				if not island.can_add_tile(coord):
					return false
				if inventory.count(Inventory.tile_item()) <= 0:
					message.emit(world_position, "Needs a tile too")
					return false
				inventory.take(Inventory.tile_item())
				inventory.take(item)
				island.add_tile(coord, item.biome)
			else:
				if tile.is_hq or tile.destroyed or tile.biome == item.biome:
					return false
				# Replacing a biome gives the old stone back.
				if tile.biome != Biome.Type.NEUTRAL:
					inventory.add(Inventory.stone_item(tile.biome))
				inventory.take(item)
				island.set_biome(coord, item.biome)
	# During missions whatever was built stays under construction for a while.
	island.start_construction(coord)
	_pending_purchase = {}
	return true


## Not during missions: there the player can only add (removing is for Edit Island).
func pick_up(coord: Vector2i, world_position: Vector2) -> void:
	var inventory := island.treasury.inventory
	var tile := island.get_tile(coord)
	if tile == null or tile.is_hq:
		return
	if island.builds_take_time:
		message.emit(world_position, "Removing only in Edit Island (main menu)")
		return
	if tile.tower:
		# A merged tower comes apart into its towers (at its tier, level 0 like after a merge).
		var hexes := island.merge_hexes_of(coord)
		var root_tower := island.get_tower(island.merge_root_of(coord))
		var level := root_tower.level()
		var tier := root_tower.tier
		var type := island.remove_tower(coord)
		for hex in hexes:
			_free_tower_node(hex)
		inventory.add(Inventory.tower_item(type, level, tier), hexes.size())
		message.emit(world_position, "%s back to inventory%s" % [String(type).capitalize(), " (×%d)" % hexes.size() if hexes.size() > 1 else ""])
	elif tile.biome != Biome.Type.NEUTRAL and not tile.destroyed:
		var biome := tile.biome
		island.set_biome(coord, Biome.Type.NEUTRAL)
		inventory.add(Inventory.stone_item(biome))
	elif island.remove_tile(coord):
		inventory.add(Inventory.tile_item())


## Selects an inventory item to place with clicks (stays selected while the stack lasts or
## the player picks something else).
func hold(item: Dictionary) -> void:
	held = item


## Drops the held item. If it was bought by pressing its slot and not placed yet, the
## purchase is undone (item back, price refunded).
func release_hold() -> void:
	if not _pending_purchase.is_empty() and _pending_purchase.item == held:
		island.refund(_pending_purchase.item, _pending_purchase.price)
	_pending_purchase = {}
	held = {}
	_dragging = false


## Remembers a purchase made by pressing a slot, so cancelling before placing refunds it.
func note_purchase(item: Dictionary, price: Dictionary) -> void:
	_pending_purchase = {item = item, price = price}


## Starts dragging `item` from the inventory; releasing over the map places it once.
## Releasing without moving keeps it selected for click placement instead.
func begin_drag(item: Dictionary) -> void:
	held = item
	_dragging = true
	_drag_start = get_viewport().get_mouse_position()


func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if not _dragging or button == null or button.button_index != MOUSE_BUTTON_LEFT or button.pressed:
		return
	_dragging = false
	var moved := button.position.distance_to(_drag_start) > DRAG_THRESHOLD
	if moved and editable and get_viewport().gui_get_hovered_control() == null:
		var world := get_global_mouse_position()
		place_item(world_to_hex(world), held, world)
		_keep_or_release()


## The held item stays selected while there are more in the inventory.
func _keep_or_release() -> void:
	if not held.is_empty() and not island.can_get(held):
		release_hold()


## U upgrades the hovered tower one tier (at level 100, if affordable).
## Debug keys: D damages, +/- change the tier, G gives gold, R biome stones and tiles,
## B +10 blueprints.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_U:
			if not editable:
				message.emit(hex_center_world(hovered_coord), "Tier upgrades in edit mode (E)")
				return
			var cost := island.tier_up_cost(hovered_coord)
			var at := hex_center_world(hovered_coord)
			if cost.is_empty():
				message.emit(at, "Tier upgrades need level %d" % Tower.MAX_LEVEL)
			elif island.upgrade_tower(hovered_coord):
				message.emit(at, "Tier %d!" % island.get_tower(hovered_coord).tier)
			else:
				message.emit(at, "Needs %d gold and %d %s" % [cost.gold, cost.amount, Biome.resource_name(cost.resource)])
		KEY_D:
			island.damage_tower(hovered_coord, debug_damage)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_shift_tier(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_shift_tier(-1)
		KEY_G:
			island.treasury.add_gold(500)
		KEY_R:
			for biome in Treasury.STONE_BIOMES:
				island.treasury.inventory.add(Inventory.stone_item(biome), 5)
			island.treasury.inventory.add(Inventory.tile_item(), 5)
		KEY_B:
			island.treasury.add_blueprint(10)


func _shift_tier(step: int) -> void:
	var tile := island.get_tile(hovered_coord)
	if tile:
		island.set_tier(hovered_coord, tile.tier + step)


func _spawn_tower_node(coord: Vector2i, type: StringName) -> void:
	var node := placeable_scene.instantiate() as Node2D
	node.set(&"tower_type", type)
	node.position = HexMath.to_pixel(coord, hex_size)
	_towers.add_child(node)
	_objects[coord] = node
	_refresh_tower_nodes()


func _free_tower_node(coord: Vector2i) -> void:
	var node: Node2D = _objects.get(coord)
	if node:
		_objects.erase(coord)
		node.queue_free()
	_refresh_tower_nodes()


func _on_tile_changed(_coord: Vector2i) -> void:
	_refresh_tower_nodes()


## Tells every tower node its biome and its same-type neighbours. A combined building
## (2+ towers of one type, except walls, which stay ramparts) is drawn by its first node over
## all its hexes; the other members' nodes hide.
func _refresh_tower_nodes() -> void:
	_group_members.clear()
	for group in island.groups():
		var lead: Node2D = _objects.get(group[0])
		var combined: bool = group.size() > 1 and (island.get_tower(group[0]).type != &"wall" or island.cluster_towers(group[0]) < group.size())
		for coord in group:
			var node: Node2D = _objects.get(coord)
			if node == null:
				continue
			var tile := island.get_tile(coord)
			node.set(&"biome", tile.biome)
			var links: Array[bool] = []
			for dir in HexMath.DIRECTIONS:
				links.append(group.has(coord + dir))
			node.set(&"links", links)
			node.visible = not combined or node == lead
		if lead:
			lead.set(&"group_art", _group_art(group, lead.position) if combined else {})
			if combined:
				for i in group.size():
					_group_members[group[i]] = {lead = lead, index = i}


## What the lead node needs to draw a combined building, in its local space: the platform
## outline, every member's centre, links (none between hexes of one merged tower) and biome,
## the main biome, for merged towers where their one big building sits and its size, and
## every member's turret angle (kept up to date by aim_tower).
func _group_art(group: Array[Vector2i], origin: Vector2) -> Dictionary:
	var platform := GroupShape.inset(GroupShape.outline(group, hex_size), hex_size * 0.07)
	var members: Array[Vector2] = []
	var member_links: Array = []
	var member_biomes: Array = []
	var parts: Array = []
	var sizes: Array = []
	var big_centers: Array = []
	var aims: Array = []
	var biomes := {}
	var center := Vector2.ZERO
	for coord in group:
		var c := HexMath.to_pixel(coord, hex_size) - origin
		members.append(c)
		center += c
		var links: Array[bool] = []
		var own := island.merge_hexes_of(coord)
		for dir in HexMath.DIRECTIONS:
			links.append(group.has(coord + dir) and not own.has(coord + dir))
		member_links.append(links)
		var tower := island.get_tower(coord)
		aims.append(tower.aim)
		if tower.is_part:
			parts.append(true)
			sizes.append(1)
			big_centers.append(c)
		else:
			parts.append(false)
			sizes.append(tower.size())
			var mid := Vector2.ZERO
			for hex in own:
				mid += HexMath.to_pixel(hex, hex_size) - origin
			big_centers.append(mid / own.size())
		var biome := island.get_tile(coord).biome
		member_biomes.append(biome)
		biomes[biome] = biomes.get(biome, 0) + 1
	var main_biome: Biome.Type = biomes.keys()[0]
	for biome in biomes:
		if biomes[biome] > biomes[main_biome]:
			main_biome = biome
	return {
		platform = _offset(platform, -origin), members = members, links = member_links,
		biomes = member_biomes, biome = main_biome, center = center / group.size(),
		parts = parts, sizes = sizes, big_centers = big_centers, aims = aims,
	}


# --- Drawing -------------------------------------------------------------

func _draw() -> void:
	_canvas = self
	# Back rows first, so mountains and trees overlap the row behind them.
	var ordered := island.coords()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var art := TerrainArt.available()
	# Rocky underside first: only the island's lower edge stays visible below the tiles.
	for coord in ordered:
		var c := HexMath.to_pixel(coord, hex_size)
		if art:
			_canvas.draw_texture_rect(TerrainArt.underside(coord), TerrainArt.underside_rect(c, hex_size), false)
		else:
			_draw_plain_underside(c)
	for coord in ordered:
		var tile := island.get_tile(coord)
		var center := HexMath.to_pixel(coord, hex_size)
		var shade := WASTELAND_TINT if tile.destroyed else tile_shade(tile)
		if art:
			_canvas.draw_texture_rect(TerrainArt.for_tile(tile, island.hq_biome()), TerrainArt.tile_rect(center, hex_size), false, shade)
		else:
			_draw_plain_tile(tile, center, shade)
		if tile.destroyed:
			_draw_wasteland(center)
		elif tile.tier > 1:
			_draw_tier(center, tile)



## Drawn on the top layer: status rings, overlays, reach and hover above every tower.
func _draw_top() -> void:
	_canvas = _top
	for coord in island.coords():
		var tile := island.get_tile(coord)
		var center := HexMath.to_pixel(coord, hex_size)
		if tile.tower:
			continue   # buildings: see _draw_group_status
		elif tile.is_hq or (not tile.destroyed and tile.hp < island.tile_max_hp(coord)):
			# Ground HP all around the edge: always for the HQ, otherwise once damaged.
			var ratio := clampf(tile.hp / island.tile_max_hp(coord), 0.0, 1.0)
			_draw_arc(center, 0, 6, ratio, HP_LOW_COLOR.lerp(HP_FULL_COLOR, ratio), TRACK_COLOR)
		if tile.is_hq:
			_draw_hq_pennant(center)
	for group in island.groups():
		_draw_group_status(group)
	for coord in island.construction:
		_draw_construction(HexMath.to_pixel(coord, hex_size), island.construction_left(coord))
	_draw_tier_arrows()
	_draw_overlay()
	_draw_tower_reach()
	_draw_hover()
	_canvas = self


## Fallback without the tile art: a flat coloured hex (and a drawn keep for the HQ).
func _draw_plain_tile(tile: IslandTile, center: Vector2, shade: Color) -> void:
	var hex := _offset(_scaled(_hex_points, 0.96), center)
	var color := Biome.color_of(tile.biome) * (shade if tile.destroyed else Color.WHITE.darkened(TIER_SHADE_PER_LEVEL * tile.tier))
	_canvas.draw_colored_polygon(hex, color)
	_canvas.draw_polyline(_closed(hex), Color(0.2, 0.16, 0.12, 0.7), 2.0, true)
	if tile.is_hq:
		var keep := Color("8c8f99")
		_canvas.draw_colored_polygon(_offset(_scaled(_hex_points, 0.7), center), keep)
		var w := hex_size * 0.5
		var body := Rect2(center + Vector2(-w / 2.0, -hex_size * 0.22), Vector2(w, hex_size * 0.45))
		_canvas.draw_rect(body, keep.darkened(0.35))
		for i in 3:
			_canvas.draw_rect(Rect2(body.position + Vector2(i * 2 * w / 5.0, -w / 5.0), Vector2(w / 5.0, w / 5.0)), keep.darkened(0.35))


## Fallback underside: a dark earthy band below the hex's lower edges.
func _draw_plain_underside(center: Vector2) -> void:
	var h := hex_size * 0.55
	var p := _offset(_hex_points, center)
	# _hex_points: index 0 upper right … 1 lower right, 2 bottom, 3 lower left.
	var band := PackedVector2Array([p[1], p[2], p[3], p[3] + Vector2(0, h), p[2] + Vector2(0, h), p[1] + Vector2(0, h)])
	_canvas.draw_colored_polygon(band, Color("4a3a2c"))
	_canvas.draw_polyline(PackedVector2Array([p[3] + Vector2(0, h * 0.5), p[2] + Vector2(0, h * 0.5), p[1] + Vector2(0, h * 0.5)]), Color("3a2d22"), 2.0, true)


## Tint for a tile's art: full brightness at Tier 1, a little darker with every tier above.
static func tile_shade(tile: IslandTile) -> Color:
	return Color.WHITE.darkened(ART_TIER_SHADE * (tile.tier - 1))


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
			&"merge":
				_overlay_merge(coord, tile, hex)
	if overlay == &"energy":
		_overlay_energy_flows()


## Merge mode: towers that can merge glow gold together with the towers they would merge
## with; every other building is greyed out.
func _overlay_merge(coord: Vector2i, tile: IslandTile, hex: PackedVector2Array) -> void:
	if tile.tower == null:
		return
	var mergeable := false
	for other in island.coords():
		if island.get_tower(other) == null or island.get_tower(other).type != tile.tower.type:
			continue
		var set := island.merge_set(other)
		if set.has(island.merge_root_of(coord)):
			mergeable = true
			break
	if mergeable:
		_canvas.draw_colored_polygon(hex, Color(MERGE_COLOR, 0.35))
		_canvas.draw_polyline(_closed(hex), MERGE_COLOR, 3.0, true)
	else:
		_canvas.draw_colored_polygon(hex, Color(0.15, 0.15, 0.15, 0.55))


## A gold up arrow over buildings at level 100 that can go up a tier.
func _draw_tier_arrows() -> void:
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.is_part or not tower.can_tier_up():
			continue
		var at := Vector2.ZERO
		for hex in island.merge_hexes_of(coord):
			at += HexMath.to_pixel(hex, hex_size)
		at = at / island.merge_hexes_of(coord).size() + Vector2(0, -hex_size * 0.55)
		var bob := sin(Time.get_ticks_msec() / 250.0) * 2.0
		var arrow := PackedVector2Array([Vector2(0, -9), Vector2(8, 0), Vector2(3, 0), Vector2(3, 8), Vector2(-3, 8), Vector2(-3, 0), Vector2(-8, 0)])
		var shifted := _offset(arrow, at + Vector2(0, bob))
		_canvas.draw_colored_polygon(_offset(shifted, Vector2(1, 2)), Color(0, 0, 0, 0.4))
		_canvas.draw_colored_polygon(shifted, MenuTheme.BRASS_LIGHT)
		_canvas.draw_polyline(_closed(shifted), MenuTheme.BRASS_DARK, 1.5, true)


## Generators bright, storages saturated by their reserve (grey = empty, full yellow = full,
## red outline when a building is empty); empty ground and the HQ fainter.
func _overlay_energy(coord: Vector2i, tile: IslandTile, hex: PackedVector2Array, center: Vector2) -> void:
	if EnergyGrid.is_producer(tile):
		_canvas.draw_colored_polygon(hex, Color(ENERGY_COLOR, 0.8))
		return
	var cap := EnergyGrid.capacity(tile)
	if cap <= 0.0:
		_canvas.draw_colored_polygon(hex, Color(0.1, 0.1, 0.15, 0.65))
		return
	var ratio := clampf(tile.energy / cap, 0.0, 1.0)
	var alpha := 0.75 if tile.tower else 0.4
	_canvas.draw_colored_polygon(hex, Color.from_hsv(ENERGY_COLOR.h, ENERGY_COLOR.s * ratio, 0.95, alpha))
	if tile.tower and ratio < EnergyGrid.EMPTY_SHARE:
		_canvas.draw_polyline(_closed(hex), ENERGY_EMPTY_COLOR, 3.0, true)
	_draw_label(center + Vector2(0, hex_size * 0.5), "%d%%" % roundi(ratio * 100.0), Color(0.15, 0.1, 0.05) if tile.tower else Color(1, 1, 1, 0.85))


## Energy moving through pipes in the last tick: a line from tile to tile, thicker the more
## flows, with a dot near the receiving end for the direction.
func _overlay_energy_flows() -> void:
	for key: Vector4i in island.energy_flows:
		var rate: float = island.energy_flows[key]
		if rate <= 0.01:
			continue
		var from := HexMath.to_pixel(Vector2i(key.x, key.y), hex_size)
		var to := HexMath.to_pixel(Vector2i(key.z, key.w), hex_size)
		var width := clampf(1.5 + rate * 0.8, 1.5, 8.0)
		_canvas.draw_line(from.lerp(to, 0.2), from.lerp(to, 0.8), Color(ENERGY_COLOR, 0.9), width, true)
		_canvas.draw_circle(from.lerp(to, 0.8), width * 0.8, ENERGY_COLOR)


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
		_canvas.draw_colored_polygon(hex, Color(REPAIR_COLOR, 0.15 + 0.3 * coverage))
	if _health_ratio(coord, tile) < 0.999:
		_canvas.draw_polyline(_closed(hex), HP_LOW_COLOR, 3.0, true)


## Tower HP where a tower stands, otherwise ground HP: green (full) to red (low).
func _overlay_hp(coord: Vector2i, tile: IslandTile, hex: PackedVector2Array) -> void:
	if tile.destroyed:
		_canvas.draw_colored_polygon(hex, Color(0, 0, 0, 0.6))
		return
	var ratio := _health_ratio(coord, tile)
	_canvas.draw_colored_polygon(hex, Color(HP_LOW_COLOR.lerp(HP_FULL_COLOR, ratio), 0.55))


## Tier as a light-to-dark ramp (Tier 0 light, Tier 7 dark) with the number on top.
func _overlay_tier(tile: IslandTile, hex: PackedVector2Array, center: Vector2) -> void:
	var shade := Color("f2efe6").darkened(tile.tier / 7.0 * 0.85)
	_canvas.draw_colored_polygon(hex, Color(shade, 0.8))
	var text_color := Color.BLACK if tile.tier < 4 else Color.WHITE
	_draw_label(center + Vector2(0, -hex_size * 0.3), str(tile.tier), text_color, 18)


func _health_ratio(coord: Vector2i, tile: IslandTile) -> float:
	if tile.tower:
		return clampf(tile.tower.hp / island.tower_max_hp(coord), 0.0, 1.0)
	return clampf(tile.hp / island.tile_max_hp(coord), 0.0, 1.0)


func _draw_label(center: Vector2, text: String, color: Color, font_size := 13) -> void:
	var width := hex_size
	_canvas.draw_string_outline(_font, center + Vector2(-width / 2.0, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 3, Color(0, 0, 0, 0.5))
	_canvas.draw_string(_font, center + Vector2(-width / 2.0, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _draw_hover() -> void:
	var center := HexMath.to_pixel(hovered_coord, hex_size)
	var outline := _closed(_offset(_hex_points, center))
	var tile := island.get_tile(hovered_coord)
	if held.is_empty():
		if tile and not tile.is_hq:
			_canvas.draw_polyline(outline, HOVER_OK_COLOR, 2.0, true)
		return
	var ok := _can_place(hovered_coord, held)
	# Ghost preview of tiles and biome stones on valid spots.
	if ok and held.kind != &"tower":
		var biome: Biome.Type = held.biome if held.kind == &"stone" else Biome.Type.NEUTRAL
		if TerrainArt.available():
			_canvas.draw_texture_rect(TerrainArt.preview(biome, hovered_coord), TerrainArt.tile_rect(center, hex_size), false, Color(1, 1, 1, GHOST_ALPHA))
		else:
			_canvas.draw_colored_polygon(_offset(_scaled(_hex_points, 0.96), center), Color(Biome.color_of(biome), GHOST_ALPHA))
	elif ok:
		_canvas.draw_circle(center, hex_size * 0.4, Color(0, 0, 0, 0.35))
	_canvas.draw_polyline(outline, HOVER_OK_COLOR if ok else HOVER_BLOCKED_COLOR, 3.0, true)


## Whether `item` could go onto `coord` right now (ignoring stack size).
func _can_place(coord: Vector2i, item: Dictionary) -> bool:
	var tile := island.get_tile(coord)
	match item.kind:
		&"tower":
			if tile == null:
				return island.can_add_tile(coord) and island.treasury.inventory.count(Inventory.tile_item()) > 0
			return island.can_place_tower(coord, item.type)
		&"tile":
			return island.can_add_tile(coord)
		&"stone":
			if tile == null:
				return island.can_add_tile(coord)
			return not tile.is_hq and not tile.destroyed and tile.biome != item.biome
	return false



## HP, shield and energy of a building group run along its outer edge (a combined building
## shares one pool of each). Measured in sixths of that edge, clockwise from the top corner
## like a single hex: shield top → lower right (2/6), energy lower right → lower left (2/6),
## HP the rest. To keep the map calm, a bar only shows while it matters – HP when damaged,
## shield when not full, energy when running low – and all of them while hovered.
func _draw_group_status(group: Array[Vector2i]) -> void:
	var ring := GroupShape.inset(GroupShape.outline(group, hex_size), HexMath.SQRT3 / 2.0 * hex_size * (1.0 - HP_RING_SCALE))
	if ring.size() < 3:
		return
	var sixth := GroupShape.length(ring) / 6.0
	var coord := group[0]
	var hp := island.group_pool(coord, &"hp")
	var shield := island.group_pool(coord, &"shield")
	# Generators pass their store straight on, so it shows no bar.
	var energy := Vector2.ZERO if EnergyGrid.is_producer(island.get_tile(coord)) else island.group_pool(coord, &"energy")
	var hp_start := 4 if energy.y > 0.0 else 2
	var hp_edges := 6 - (2 if shield.y > 0.0 else 0) - (2 if energy.y > 0.0 else 0)
	var hp_ratio := clampf(hp.x / maxf(hp.y, 0.001), 0.0, 1.0)
	var hovered := group.has(hovered_coord)
	if hovered or hp_ratio < 0.995:
		_draw_ring_bar(ring, sixth, hp_start, hp_edges, hp_ratio, HP_LOW_COLOR.lerp(HP_FULL_COLOR, hp_ratio), TRACK_COLOR)
	if shield.y > 0.0 and (hovered or shield.x < shield.y * 0.995):
		_canvas.draw_polyline(_ring_piece(ring, sixth, 0, 2, 1.0), TRACK_COLOR, HP_RING_WIDTH + 2.0, true)
		var points := _ring_piece(ring, sixth, 0, 2, clampf(shield.x / shield.y, 0.0, 1.0))
		for i in points.size() - 1:
			_canvas.draw_dashed_line(points[i], points[i + 1], SHIELD_COLOR, HP_RING_WIDTH, 6.0)
	if energy.y > 0.0 and (hovered or energy.x < energy.y * ENERGY_SHOWN_BELOW):
		var ratio := clampf(energy.x / energy.y, 0.0, 1.0)
		var track := ENERGY_EMPTY_COLOR if ratio < 0.05 else TRACK_COLOR
		# Anchored at the lower left, so energy drains from right to left.
		_draw_ring_bar(ring, sixth, 2, 2, ratio, ENERGY_COLOR, track, true)


func _draw_ring_bar(ring: PackedVector2Array, sixth: float, start: int, edges: int, ratio: float, color: Color, track: Color, from_end := false) -> void:
	_canvas.draw_polyline(_ring_piece(ring, sixth, start, edges, 1.0), track, HP_RING_WIDTH + 2.0, true)
	var piece := _ring_piece(ring, sixth, start, edges, ratio, from_end) if ratio > 0.0 else PackedVector2Array()
	if piece.size() >= 2:
		_canvas.draw_polyline(piece, color, HP_RING_WIDTH, true)


## Like _arc, but along a group's ring: `edges` sixths from sixth `start`, covering `ratio`.
static func _ring_piece(ring: PackedVector2Array, sixth: float, start: int, edges: int, ratio: float, from_end := false) -> PackedVector2Array:
	var length := (edges - 2.0 * ARC_GAP) * ratio
	var from := edges - ARC_GAP - length if from_end else ARC_GAP
	return GroupShape.slice(ring, (start + from) * sixth, (start + from + length) * sixth)


func _draw_arc(center: Vector2, start: int, edges: int, ratio: float, color: Color, track: Color, from_end := false) -> void:
	# The dark track is wider than the bar, so the bar keeps an outline on busy terrain.
	_canvas.draw_polyline(_arc(center, start, edges, 1.0), track, HP_RING_WIDTH + 2.0, true)
	if ratio > 0.0:
		_canvas.draw_polyline(_arc(center, start, edges, ratio, from_end), color, HP_RING_WIDTH, true)


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
## generators the tiles their energy reaches (fainter further on), walls their buffed neighbours, attack towers their range.
func _draw_tower_reach() -> void:
	var tile := island.get_tile(hovered_coord)
	if tile == null:
		return
	var shares := {}
	var color := ENERGY_COLOR
	if EnergyGrid.is_producer(tile):
		shares = EnergyGrid.fed_by(island, hovered_coord)
	elif tile.tower and tile.tower.type == &"aura":
		var aura := AuraProfiles.for_tile(island, hovered_coord)
		color = aura.color
		for coord in HexMath.area(hovered_coord, aura.radius + (1 if aura.enemy_weaken > 0.0 else 0)):
			if island.has_tile(coord):
				shares[coord] = 1.0 if HexMath.distance(coord, hovered_coord) <= aura.radius else 0.4
	elif tile.tower and tile.tower.type == &"scout":
		var scout := ScoutProfiles.for_tile(island, hovered_coord)
		color = scout.color
		for coord in HexMath.area(hovered_coord, scout.radius):
			if coord != hovered_coord:
				shares[coord] = 0.6
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
		_canvas.draw_colored_polygon(_offset(inner, HexMath.to_pixel(coord, hex_size)), Color(color, 0.4 * shares[coord]))


## A pennant in the colour of the HQ's biome (Island.hq_biome) above the castle.
func _draw_hq_pennant(center: Vector2) -> void:
	var foot := center + Vector2(hex_size * 0.32, -hex_size * 0.35)
	var top := foot + Vector2(0, -hex_size * 0.75)
	var dark := Color(0.12, 0.09, 0.07)
	_canvas.draw_line(foot, top, dark, 2.5, true)
	var flag := PackedVector2Array([top, top + Vector2(hex_size * 0.42, hex_size * 0.13), top + Vector2(0, hex_size * 0.26)])
	_canvas.draw_colored_polygon(flag, Biome.color_of(island.hq_biome()))
	_canvas.draw_polyline(_closed(flag), dark, 1.5, true)


func _draw_tier(center: Vector2, tile: IslandTile) -> void:
	var text := "T%d" % tile.tier
	# Left edge of the hex, where towers and health bars don't cover it.
	var pos := center + Vector2(-hex_size * 0.62, 5)
	_canvas.draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.6))
	_canvas.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## Hex under construction: a dashed amber outline and the seconds left.
func _draw_construction(center: Vector2, left: float) -> void:
	var hex := _offset(_scaled(_hex_points, 0.66), center)
	for i in hex.size():
		var a := hex[i]
		var b := hex[(i + 1) % hex.size()]
		_canvas.draw_line(a, b, TRACK_COLOR, 4.5)
		_canvas.draw_dashed_line(a, b, CONSTRUCTION_COLOR, 2.5, 5.0)
	_draw_label(center + Vector2(0, hex_size * 0.42), "%ds" % ceili(left), CONSTRUCTION_COLOR, 12)


## Charred cracks on a tile destroyed in battle.
func _draw_wasteland(center: Vector2) -> void:
	var crack := Color("1e1410")
	_canvas.draw_polyline(PackedVector2Array([center + Vector2(-20, -14), center + Vector2(-4, -2), center + Vector2(-10, 14)]), crack, 2.0, true)
	_canvas.draw_polyline(PackedVector2Array([center + Vector2(4, -2), center + Vector2(18, 6), center + Vector2(22, -10)]), crack, 2.0, true)
	_canvas.draw_circle(center + Vector2(8, 16), 3.0, Color("e0602a", 0.6))


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
