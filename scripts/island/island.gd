class_name Island
extends RefCounted
## The player's floating island: a set of hex tiles around a neutral HQ.
## Pure game logic, no rendering (see docs/GDD.md §3–§6).

signal tile_added(coord: Vector2i)
signal tile_removed(coord: Vector2i)
signal tile_changed(coord: Vector2i)
signal tower_destroyed(coord: Vector2i)
signal tile_destroyed(coord: Vector2i)
## A building (group) reached a level worth announcing; `tier_up` if its ground rose a tier.
signal tower_levelled(coord: Vector2i, level: int)
## Towers merged into one tower covering `hexes`.
signal towers_merged(hexes: Array[Vector2i])

const HQ_COORD := Vector2i.ZERO
## Share of a tower's max shield that refills per second.
const SHIELD_REGEN := 0.05
## Tile tiers come from merging later (milestone 4); until then they are capped here.
const MAX_MERGE_TIER := 6
## Ground structure: plenty, so tiles outlast buildings. Placeholder numbers.
const HQ_MAX_HP := 2000.0
const TILE_BASE_HP := 300.0
const TILE_HP_PER_TIER := 100.0
## Every tower in a combined building (2+ neighbouring towers of one type) works this much
## better: two towers count as 2.6, three as 3.9 and so on.
const MERGE_BONUS := 0.3
## Blueprint price of a new tower: this many, plus one for every tower of that type already
## owned (tiles: plus one for every unused tile in the inventory).
const BLUEPRINTS_BASE := 1
## Currency id of blueprints in price_of() (faction resources use their Biome.Type).
const CURRENCY_BLUEPRINTS := -2
## Tier upgrade cost per tower: gold × the new tier, and faction resource × the new tier
## (the resource of the tile's biome; neutral ground takes whichever the player has most of).
const TIER_UP_GOLD := 100
const TIER_UP_RESOURCE := 10
## Most towers of one type in a cluster (neighbours that combine); a merged tower counts once.
const MAX_CLUSTER := 3
## Highest biome tile tier; merged towers lift their tiles to their own tier.
const MAX_TIER := 7
## Level-ups are announced every this many levels (and at level 100).
const ANNOUNCE_EVERY := 5
## XP sources: walls per point of damage taken; time-based towers per second of work.
const WALL_XP_PER_DAMAGE := 0.1
const XP_PER_SECOND := {&"energy": 1.0, &"aura": 1.0, &"scout": 1.0, &"warehouse": 0.5}

var _tiles: Dictionary[Vector2i, IslandTile] = {}
## Active heals over time: {coord, tower (bool), rate (HP/s), time (s left)}.
var _heals_over_time: Array[Dictionary] = []
## Gold, rare resources and blueprints of this island's player.
var treasury := Treasury.new(Economy.STARTING_GOLD)
## aura_at() results, cleared every tick and whenever a tile or tower changes.
var _aura_cache: Dictionary = {}
## group_of() results (coord -> its building group), cleared whenever a tile or tower changes.
var _group_cache: Dictionary = {}
## Towers only gain experience while this is on (off when editing the island).
var gains_xp := true
## Analysis: totals of the current wave per building type (&"hq" for the HQ), e.g.
## {&"attack": {&"damage": 120.0, &"lost": 1}}; the battle log reads and resets them.
var wave_totals: Dictionary = {}
## Seconds the uptime averages span (roughly the last minute).
const UPTIME_SPAN := 60.0
## Save found blueprints right away (IslandSave); only the player's island in the game does.
var persist_blueprints := false
## Towers and tiles bought with blueprints since the island was last saved.
var unsaved_towers: Array[String] = []


func _init() -> void:
	# Bound methods, not lambdas: a lambda would keep this RefCounted alive forever.
	for change in [tile_added, tile_removed, tile_changed, tower_destroyed, tile_destroyed]:
		change.connect(_on_tiles_changed)


func _on_tiles_changed(_coord: Vector2i) -> void:
	_aura_cache.clear()
	_group_cache.clear()

## Wasteland turns back into usable ground once repaired to this share of its HP.
const WASTELAND_RESTORE_SHARE := 0.5


## A fresh island: the HQ plus neutral tiles out to `radius`.
static func create_starter(radius: int) -> Island:
	var island := Island.new()
	for coord in HexMath.area(HQ_COORD, radius):
		var tile := IslandTile.new(coord)
		tile.is_hq = coord == HQ_COORD
		island._tiles[coord] = tile
		tile.hp = island.tile_max_hp(coord)
	for type in Economy.STARTING_TOWERS:
		island.treasury.inventory.add(Inventory.tower_item(type))
	island.treasury.inventory.add(Inventory.tile_item(), Economy.STARTING_TILES)
	return island


## Layout and treasury as plain data (for IslandSave): tiles with biome, tier and tower.
## Battle state (HP, wasteland, energy) is not kept; a loaded island starts repaired.
func to_dict() -> Dictionary:
	var tiles: Array = []
	for coord in _tiles:
		var tile := _tiles[coord]
		tiles.append({q = coord.x, r = coord.y, biome = int(tile.biome), tier = tile.tier,
			hq = tile.is_hq, tower = String(tile.tower.type) if tile.tower else "",
			xp = tile.tower.xp if tile.tower else 0.0,
			tower_tier = tile.tower.tier if tile.tower else 1,
			part_of = [tile.tower.merge_root.x, tile.tower.merge_root.y] if tile.tower and tile.tower.is_part else []})
	return {tiles = tiles, treasury = treasury.to_dict()}


## Island rebuilt from to_dict() data, or null if the data has no HQ.
static func from_dict(data: Dictionary) -> Island:
	var island := Island.new()
	for entry: Dictionary in data.get("tiles", []):
		var coord := Vector2i(int(entry.q), int(entry.r))
		var tile := IslandTile.new(coord, int(entry.biome) as Biome.Type)
		tile.tier = int(entry.tier)
		tile.is_hq = bool(entry.hq)
		island._tiles[coord] = tile
	if not island.has_tile(HQ_COORD) or not island.get_tile(HQ_COORD).is_hq:
		return null
	# Towers and HP after all tiles exist, since neighbours change max HP.
	for entry: Dictionary in data.get("tiles", []):
		if String(entry.tower) != "":
			var tower := island.place_tower(Vector2i(int(entry.q), int(entry.r)), StringName(entry.tower))
			if tower:
				tower.tier = int(entry.get("tower_tier", 1))
				var part_of: Array = entry.get("part_of", [])
				if part_of.size() == 2:
					tower.is_part = true
					tower.merge_root = Vector2i(int(part_of[0]), int(part_of[1]))
				tower.xp = float(entry.get("xp", 0.0))
				tower.level_seen = tower.level()
	# Rebuild the hex lists of merged towers from their parts.
	for coord in island._tiles:
		var part := island.get_tower(coord)
		if part and part.is_part and island.get_tower(part.merge_root):
			var root_tower := island.get_tower(part.merge_root)
			if root_tower.merge_hexes.is_empty():
				root_tower.merge_hexes.append(part.merge_root)
			root_tower.merge_hexes.append(coord)
			root_tower.merge_hexes.sort()
	for coord in island._tiles:
		island._tiles[coord].hp = island.tile_max_hp(coord)
	island.treasury.load_dict(data.get("treasury", {}))
	return island


func has_tile(coord: Vector2i) -> bool:
	return _tiles.has(coord)


func get_tile(coord: Vector2i) -> IslandTile:
	return _tiles.get(coord)


func coords() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_tiles.keys())
	return result


func tile_count() -> int:
	return _tiles.size()


# --- Tiles ---------------------------------------------------------------

## New tiles must touch the island.
func can_add_tile(coord: Vector2i) -> bool:
	if has_tile(coord):
		return false
	for n in HexMath.neighbors(coord):
		if has_tile(n):
			return true
	return false


## Adds a neutral tile, or a Tier 1 biome tile when placed straight from a biome stone.
func add_tile(coord: Vector2i, type: Biome.Type = Biome.Type.NEUTRAL) -> bool:
	if not can_add_tile(coord):
		return false
	_tiles[coord] = IslandTile.new(coord, type)
	_tiles[coord].hp = tile_max_hp(coord)
	tile_added.emit(coord)
	return true


## Only empty tiles can be removed, never the HQ, and the island must stay in one piece.
func can_remove_tile(coord: Vector2i) -> bool:
	var tile := get_tile(coord)
	if tile == null or not tile.is_free():
		return false
	return _stays_connected_without(coord)


func remove_tile(coord: Vector2i) -> bool:
	if not can_remove_tile(coord):
		return false
	_tiles.erase(coord)
	tile_removed.emit(coord)
	return true


## Biome stone on an existing tile; NEUTRAL turns it back. Resets the tier.
func set_biome(coord: Vector2i, type: Biome.Type) -> bool:
	var tile := get_tile(coord)
	if tile == null or tile.is_hq or tile.destroyed or tile.biome == type:
		return false
	var ratio := tile.hp / tile_max_hp(coord)
	tile.set_biome(type)
	tile.hp = ratio * tile_max_hp(coord)
	tile_changed.emit(coord)
	return true


## Debug stand-in for merging (milestone 4): sets a biome tile's tier directly.
func set_tier(coord: Vector2i, tier: int) -> bool:
	var tile := get_tile(coord)
	if tile == null or tile.biome == Biome.Type.NEUTRAL:
		return false
	var clamped := clampi(tier, 1, MAX_MERGE_TIER)
	if clamped == tile.tier:
		return false
	var ratio := tile.hp / tile_max_hp(coord)
	tile.tier = clamped
	tile.hp = ratio * tile_max_hp(coord)
	tile_changed.emit(coord)
	return true


func tile_max_hp(coord: Vector2i) -> float:
	var tile := get_tile(coord)
	if tile == null:
		return 0.0
	return HQ_MAX_HP if tile.is_hq else TILE_BASE_HP + TILE_HP_PER_TIER * tile.tier


## Damages the ground. A tile at 0 HP turns into Wasteland; the HQ just stays at 0 for now.
func damage_tile(coord: Vector2i, amount: float) -> void:
	var tile := get_tile(coord)
	if tile == null or tile.destroyed:
		return
	tile.hp = maxf(tile.hp - amount, 0.0)
	if tile.hp <= 0.0 and not tile.is_hq:
		tile.destroyed = true
		tile.energy = 0.0
		tile_destroyed.emit(coord)
	tile_changed.emit(coord)


func has_battle_damage() -> bool:
	for coord in _tiles:
		if _tiles[coord].destroyed or _tiles[coord].hp < tile_max_hp(coord):
			return true
	return false


## End of a fight: Wasteland turns back and all ground is repaired.
func restore_tiles() -> void:
	for coord in _tiles:
		var tile := _tiles[coord]
		tile.destroyed = false
		tile.hp = tile_max_hp(coord)
		tile_changed.emit(coord)


# --- Healing -------------------------------------------------------------

## HP share of the tower (`tower` true) or the ground of `coord`.
func health_ratio(coord: Vector2i, tower: bool) -> float:
	var tile := get_tile(coord)
	if tile == null:
		return 1.0
	if tower:
		return tile.tower.hp / tower_max_hp(coord) if tile.tower else 1.0
	return tile.hp / tile_max_hp(coord)


## Damaged towers and ground within `reach` of `center`, weakest (lowest HP share) first.
## Each entry: {coord, tower (bool), ratio}.
func damaged_in_reach(center: Vector2i, reach: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for coord in HexMath.area(center, reach):
		var tile := get_tile(coord)
		if tile == null:
			continue
		if tile.tower and health_ratio(coord, true) < 0.999:
			result.append({coord = coord, tower = true, ratio = health_ratio(coord, true)})
		if health_ratio(coord, false) < 0.999:
			result.append({coord = coord, tower = false, ratio = health_ratio(coord, false)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ratio < b.ratio)
	return result


## Heals a tower or the ground; returns the HP actually restored.
## Repaired Wasteland turns back into ground at WASTELAND_RESTORE_SHARE.
func heal(coord: Vector2i, tower: bool, amount: float) -> float:
	var tile := get_tile(coord)
	if tile == null or amount <= 0.0:
		return 0.0
	var before: float
	if tower:
		if tile.tower == null:
			return 0.0
		# Repairs go into the group's shared HP pool.
		var pool := group_pool(coord, &"hp")
		var gained := minf(amount, pool.y - pool.x)
		_set_group_pool(group_of(coord), &"hp", pool.x + gained)
		return gained
	before = tile.hp
	tile.hp = minf(tile_max_hp(coord), tile.hp + amount)
	if tile.destroyed and tile.hp >= tile_max_hp(coord) * WASTELAND_RESTORE_SHARE:
		tile.destroyed = false
		tile_changed.emit(coord)
	return tile.hp - before


## Takes HP from a tower or the ground (no destruction below 1 HP); returns the HP taken.
func drain(coord: Vector2i, tower: bool, amount: float) -> float:
	var tile := get_tile(coord)
	if tile == null:
		return 0.0
	if tower:
		if tile.tower == null:
			return 0.0
		var pool := group_pool(coord, &"hp")
		var taken := clampf(amount, 0.0, pool.x - 1.0)
		_set_group_pool(group_of(coord), &"hp", pool.x - taken)
		return maxf(taken, 0.0)
	var taken_ground := minf(amount, tile.hp - 1.0)
	tile.hp -= taken_ground
	return maxf(taken_ground, 0.0)


func add_heal_over_time(coord: Vector2i, tower: bool, total: float, duration: float) -> void:
	_heals_over_time.append({coord = coord, tower = tower, rate = total / duration, time = duration})


func _tick_heals_over_time(delta: float) -> void:
	for i in range(_heals_over_time.size() - 1, -1, -1):
		var hot := _heals_over_time[i]
		var step := minf(delta, hot.time)
		heal(hot.coord, hot.tower, hot.rate * step)
		hot.time -= delta
		if hot.time <= 0.0:
			_heals_over_time.remove_at(i)


## Summed effects on `coord` (read-only; shared with the cache).
func aura_at(coord: Vector2i) -> Dictionary:
	if not _aura_cache.has(coord):
		_aura_cache[coord] = Auras.collect(self, coord)
	return _aura_cache[coord]


func _stays_connected_without(removed: Vector2i) -> bool:
	var seen := {HQ_COORD: true}
	var frontier: Array[Vector2i] = [HQ_COORD]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		for n in HexMath.neighbors(current):
			if n != removed and has_tile(n) and not seen.has(n):
				seen[n] = true
				frontier.append(n)
	return seen.size() == tile_count() - 1


# --- Towers --------------------------------------------------------------

func can_place(coord: Vector2i) -> bool:
	var tile := get_tile(coord)
	return tile != null and tile.is_free()


## Places a new tower of `type` at `level` (towers keep their level in the inventory). Its
## tier-ups for those levels are counted as given, so moving it doesn't raise a new tile.
func place_tower(coord: Vector2i, type: StringName, level := 0, tier := 1) -> Tower:
	if not can_place_tower(coord, type):
		return null
	var tile := get_tile(coord)
	tile.tower = Tower.new(type, 1.0)
	tile.tower.tier = tier
	tile.tower.xp = Tower.xp_for_level(level)
	tile.tower.level_seen = level
	tile.tower.hp = tower_max_hp(coord)
	tile_changed.emit(coord)
	return tile.tower


## Swaps the type of an existing tower, keeping its health share.
func change_tower_type(coord: Vector2i, type: StringName) -> bool:
	var tower := get_tower(coord)
	if tower == null:
		return false
	var ratio := tower.hp / tower_max_hp(coord)
	tower.type = type
	tower.hp = ratio * tower_max_hp(coord)
	tile_changed.emit(coord)
	return true


## Returns the type of the removed tower, or &"" if the tile was empty.
## Takes the tower on `coord` off the island (a merged tower with all its hexes).
func remove_tower(coord: Vector2i) -> StringName:
	var tower := get_tower(coord)
	if tower == null:
		return &""
	for hex in merge_hexes_of(coord):
		get_tile(hex).tower = null
		tile_changed.emit(hex)
	return tower.type


func get_tower(coord: Vector2i) -> Tower:
	var tile := get_tile(coord)
	return tile.tower if tile else null


func tower_max_hp(coord: Vector2i) -> float:
	var tower := get_tower(coord)
	if tower == null:
		return 0.0
	return TowerDefs.base_hp(tower.type) * (1.0 + aura_at(coord).get(&"max_hp", 0.0)) * tower.stat_factor()


func tower_max_shield(coord: Vector2i) -> float:
	return tower_max_hp(coord) * aura_at(coord).get(&"shield", 0.0)


## Damage hits the shield first. Desert tiles pass a share on to neighbouring towers.
func damage_tower(coord: Vector2i, amount: float) -> void:
	if get_tower(coord) == null:
		return
	var aura := aura_at(coord)
	# Armour (Mountain Aura) reduces incoming damage, capped at 80%.
	amount *= 1.0 - minf(aura.get(&"armor", 0.0), 0.8)
	var spread: float = minf(aura.get(&"damage_spread", 0.0), 1.0)
	var receivers: Array[Vector2i] = []
	for n in HexMath.neighbors(coord):
		if get_tower(n) != null:
			receivers.append(n)
	if spread > 0.0 and not receivers.is_empty():
		var share := amount * spread
		amount -= share
		for n in receivers:
			_apply_damage(n, share / receivers.size())
	_apply_damage(coord, amount)


## Damage goes into the building group's shared pools: shield first, then HP. The whole
## group falls together when the pool is empty.
func _apply_damage(coord: Vector2i, amount: float) -> void:
	if get_tower(coord) == null:
		return
	track(coord, &"taken", amount)
	var group := group_of(coord)
	if get_tower(coord).type == &"wall":
		add_xp(coord, amount * WALL_XP_PER_DAMAGE)
	var shield := 0.0
	var hp := 0.0
	for member in group:
		var tower := get_tower(member)
		tower.time_since_damage = 0.0
		shield += tower.shield
		hp += tower.hp
	var absorbed := minf(shield, amount)
	hp -= amount - absorbed
	if hp <= 0.0:
		var lost_type := get_tower(coord).type
		if not wave_totals.has(lost_type):
			wave_totals[lost_type] = {}
		wave_totals[lost_type][&"lost"] = wave_totals[lost_type].get(&"lost", 0.0) + cluster_towers(coord)
		for member in group:
			get_tile(member).tower = null
		for member in group:
			tower_destroyed.emit(member)
			tile_changed.emit(member)
		return
	_set_group_pool(group, &"shield", shield - absorbed)
	_set_group_pool(group, &"hp", hp)


# --- Building groups -------------------------------------------------------

## Towers of the same type on neighbouring tiles form one combined building: they share
## one pool each of HP, shield and stored energy (spread by each member's maximum).
func group_of(coord: Vector2i) -> Array[Vector2i]:
	if _group_cache.has(coord):
		return _group_cache[coord]
	var group: Array[Vector2i] = []
	var tower := get_tower(coord)
	if tower == null:
		return group
	var open: Array[Vector2i] = [coord]
	var seen := {coord: true}
	while not open.is_empty():
		var current: Vector2i = open.pop_back()
		group.append(current)
		for n in HexMath.neighbors(current):
			if not seen.has(n) and get_tower(n) != null and get_tower(n).type == tower.type:
				seen[n] = true
				open.append(n)
	group.sort()
	for member in group:
		_group_cache[member] = group
	return group


## Total effect multiplier of the tower on `coord`: cluster bonus × level and tier × the
## size of a merged tower (a 2-hex tower works twice as hard). Walls' neighbour buff leaves
## the size out (`with_size`), since every part of a merged wall buffs on its own.
func effect_bonus(coord: Vector2i, with_size := true) -> float:
	var tower := get_tower(coord)
	if tower == null:
		return 1.0
	var size := get_tower(merge_root_of(coord)).size() if with_size else 1
	return merge_bonus(coord) * tower.stat_factor() * size


## What a tier upgrade of the building on `coord` costs (for its whole combined building):
## {gold, resource (Biome.Type), amount}, or {} if it can't go up a tier yet.
func tier_up_cost(coord: Vector2i) -> Dictionary:
	var tower := get_tower(coord)
	if tower == null or not tower.can_tier_up():
		return {}
	var size := group_of(coord).size()
	var biome := get_tile(coord).biome
	if biome == Biome.Type.NEUTRAL:
		biome = Treasury.STONE_BIOMES[0]
		for b in Treasury.STONE_BIOMES:
			if treasury.resources.get(b, 0) > treasury.resources.get(biome, 0):
				biome = b
	var next := tower.tier + 1
	return {gold = TIER_UP_GOLD * next * size, resource = biome, amount = TIER_UP_RESOURCE * next * size}


## Raises the building on `coord` (with its whole combined building) one tier if it is at
## level 100 and the player can pay. Returns true on success.
func upgrade_tower(coord: Vector2i) -> bool:
	var cost := tier_up_cost(coord)
	if cost.is_empty() or not treasury.spend(cost.gold, cost.resource, cost.amount):
		return false
	for member in group_of(coord):
		var tower := get_tower(member)
		var ratio := tower.hp / tower_max_hp(member)
		tower.tier += 1
		tower.xp = 0.0
		tower.level_seen = 0
		tower.hp = ratio * tower_max_hp(member)
		tile_changed.emit(member)
	for member in group_of(coord):
		_lift_merged_tiles(member)
	return true


## Experience for the tower on `coord` (shared with its combined building at the next even-out).
func add_xp(coord: Vector2i, amount: float) -> void:
	var tower := get_tower(coord)
	if tower and gains_xp and amount > 0.0:
		var before := tower.xp
		tower.xp = minf(tower.xp + amount, Tower.xp_for_level(Tower.MAX_LEVEL))
		tower.xp_this_tick += tower.xp - before


## Analysis: adds `amount` to counter `key` of the building on `coord` (wave and mission) and
## to the wave totals of its type.
func track(coord: Vector2i, key: StringName, amount: float) -> void:
	if amount <= 0.0:
		return
	var tower := get_tower(coord)
	var type: StringName = &"hq" if coord == HQ_COORD else (tower.type if tower else &"")
	if type == &"":
		return
	if tower:
		tower.wave_stats[key] = tower.wave_stats.get(key, 0.0) + amount
		tower.mission_stats[key] = tower.mission_stats.get(key, 0.0) + amount
	if not wave_totals.has(type):
		wave_totals[type] = {}
	wave_totals[type][key] = wave_totals[type].get(key, 0.0) + amount


## A new wave starts: per-tower wave counters and the wave totals begin at zero.
func start_wave_stats() -> void:
	wave_totals.clear()
	for coord in _tiles:
		var tower := get_tower(coord)
		if tower:
			tower.wave_stats.clear()


## Updates the uptime and XP-rate averages of every acting tower and clears the flags.
func _update_analysis(delta: float) -> void:
	var k := clampf(delta / UPTIME_SPAN, 0.0, 1.0)
	for coord in _tiles:
		var tower := get_tower(coord)
		if tower == null or tower.is_part:
			continue
		var powered := EnergyGrid.capacity(get_tile(coord)) <= 0.0 or group_pool(coord, &"energy").x > 0.01
		if tower.type == &"aura" or tower.type == &"scout":
			powered = tower.aura_power > 0.0
			tower.saw_target = true
			tower.did_work = powered
		tower.uptime_powered = lerpf(tower.uptime_powered, 1.0 if powered else 0.0, k)
		tower.uptime_target = lerpf(tower.uptime_target, 1.0 if tower.saw_target else 0.0, k)
		tower.uptime_working = lerpf(tower.uptime_working, 1.0 if tower.did_work else 0.0, k)
		if delta > 0.0:
			tower.xp_per_minute = lerpf(tower.xp_per_minute, tower.xp_this_tick / delta * 60.0, k)
		tower.saw_target = false
		tower.did_work = false
		tower.xp_this_tick = 0.0


## Announces new levels every few levels and at level 100.
func _check_levels() -> void:
	for group in groups():
		var level := get_tower(group[0]).level()
		var seen := 0
		for member in group:
			seen = maxi(seen, get_tower(member).level_seen)
		if level <= seen:
			continue
		for member in group:
			get_tower(member).level_seen = level
		if level / ANNOUNCE_EVERY > seen / ANNOUNCE_EVERY or level >= Tower.MAX_LEVEL:
			tower_levelled.emit(group[0], level)


# --- Merging ---------------------------------------------------------------

## The root hex of the (possibly merged) tower on `coord`.
func merge_root_of(coord: Vector2i) -> Vector2i:
	var tower := get_tower(coord)
	return tower.merge_root if tower and tower.is_part else coord


## All hexes of the (possibly merged) tower on `coord`.
func merge_hexes_of(coord: Vector2i) -> Array[Vector2i]:
	var root := merge_root_of(coord)
	var tower := get_tower(root)
	var result: Array[Vector2i] = []
	if tower == null:
		return result
	if tower.merge_hexes.is_empty():
		result.append(root)
		return result
	return tower.merge_hexes


## Whether the tower on `coord` acts (shoots, repairs, buffs, generates): single towers and
## the roots of merged towers do, the other hexes of a merged tower don't.
func acts(coord: Vector2i) -> bool:
	var tower := get_tower(coord)
	return tower != null and not tower.is_part


## Towers that would merge with the one on `coord`, as their root hexes (the tower's own root
## first), or [] if it can't merge: n towers of tier n – touching, same type and tier – whose
## hexes add up to exactly n become one n-hex tower. A merged tower grows the same way: a
## 2-hex Tier 3 tower plus one more Tier 3 tower makes a 3-hex tower.
func merge_set(coord: Vector2i) -> Array[Vector2i]:
	var root := merge_root_of(coord)
	var tower := get_tower(root)
	var none: Array[Vector2i] = []
	if tower == null or tower.tier < 2:
		return none
	var chosen: Array[Vector2i] = [root]
	var hexes := tower.size()
	while hexes < tower.tier:
		var next := _merge_candidate(chosen, tower, tower.tier - hexes)
		if next == Vector2i(9999, 9999):
			return none
		chosen.append(next)
		hexes += get_tower(next).size()
	return chosen if hexes == tower.tier and chosen.size() >= 2 else none


## A touching tower (root hex) of the same type and tier with at most `room` hexes, or
## Vector2i(9999, 9999) if there is none.
func _merge_candidate(chosen: Array[Vector2i], like: Tower, room: int) -> Vector2i:
	var best := Vector2i(9999, 9999)
	for member in chosen:
		for hex in merge_hexes_of(member):
			for n in HexMath.neighbors(hex):
				var other := get_tower(n)
				if other == null or other.type != like.type or other.tier != like.tier:
					continue
				var other_root := merge_root_of(n)
				if chosen.has(other_root) or get_tower(other_root).size() > room:
					continue
				if best == Vector2i(9999, 9999) or get_tower(other_root).size() > get_tower(best).size():
					best = other_root
	return best


## Merges the tower on `coord` with its merge set into one tower. It keeps its tier (and so
## its tier bonus and perk points), starts again at level 0 and lifts its tiles to its tier.
func merge(coord: Vector2i) -> bool:
	var set := merge_set(coord)
	if set.is_empty():
		return false
	var hexes: Array[Vector2i] = []
	for member in set:
		hexes.append_array(merge_hexes_of(member))
	hexes.sort()
	var group := group_of(coord)
	var hp_share := group_pool(coord, &"hp")
	var ratio := hp_share.x / maxf(hp_share.y, 0.001)
	for hex in hexes:
		var tower := get_tower(hex)
		tower.xp = 0.0
		tower.level_seen = 0
		tower.is_part = hex != hexes[0]
		tower.merge_root = hexes[0]
		tower.merge_hexes.clear()
		if hex == hexes[0]:
			tower.merge_hexes.assign(hexes)
	_group_cache.clear()
	_aura_cache.clear()
	_set_group_pool(group, &"hp", ratio * group_pool(coord, &"hp").y)
	_lift_merged_tiles(hexes[0])
	for hex in hexes:
		tile_changed.emit(hex)
	towers_merged.emit(hexes)
	return true


## Merged towers lift the biome tiles under them to their own tier (neutral ground stays 0).
func _lift_merged_tiles(coord: Vector2i) -> void:
	var root := merge_root_of(coord)
	var tower := get_tower(root)
	if tower == null or tower.size() < 2:
		return
	for hex in tower.merge_hexes:
		var tile := get_tile(hex)
		var target := mini(tower.tier, MAX_TIER)
		if tile.biome == Biome.Type.NEUTRAL or tile.tier >= target:
			continue
		var ratio := tile.hp / tile_max_hp(hex)
		tile.tier = target
		tile.hp = ratio * tile_max_hp(hex)
		tile_changed.emit(hex)


## Effect multiplier of the tower on `coord`: 1 + MERGE_BONUS in a combined building.
func merge_bonus(coord: Vector2i) -> float:
	return 1.0 + MERGE_BONUS if group_of(coord).size() >= 2 else 1.0


## Towers in the cluster on `coord` (a merged tower counts once).
func cluster_towers(coord: Vector2i) -> int:
	var roots := {}
	for member in group_of(coord):
		roots[merge_root_of(member)] = true
	return roots.size()


## Towers in the cluster a new tower of `type` on `coord` would join (itself included).
func cluster_with(coord: Vector2i, type: StringName) -> int:
	var roots := {}
	for n in HexMath.neighbors(coord):
		var tower := get_tower(n)
		if tower == null or tower.type != type:
			continue
		for member in group_of(n):
			roots[merge_root_of(member)] = true
	return roots.size() + 1


## Whether a tower of `type` may go on `coord`: a free tile, and at most MAX_CLUSTER towers of
## one type clustering together.
func can_place_tower(coord: Vector2i, type: StringName) -> bool:
	return can_place(coord) and cluster_with(coord, type) <= MAX_CLUSTER


## Towers of `type` the player owns: standing on the island plus in the inventory.
func towers_owned(type: StringName) -> int:
	var owned := 0
	for coord in _tiles:
		var tower := get_tower(coord)
		if tower and tower.type == type:
			owned += 1
	owned += treasury.inventory.tower_count(type)
	return owned


## How many of a blueprint kind the player has: towers of that type, or unused tiles.
func owned_of(kind: StringName) -> int:
	return treasury.inventory.tiles if kind == &"tile" else towers_owned(kind)


## Blueprints a new `kind` (tower type or &"tile") costs: more the more of them the player owns.
func blueprint_cost(kind: StringName) -> int:
	return BLUEPRINTS_BASE + owned_of(kind)


## The blueprint kind an inventory item is bought as, or &"" if blueprints can't buy it
## (biome stones, and towers above level 0 / tier 1).
static func purchase_kind(item: Dictionary) -> StringName:
	match item.get("kind", &""):
		&"tile":
			return &"tile"
		&"tower":
			if item.level == 0 and item.get("tier", 1) == 1:
				return item.type
	return &""


## Price of buying one `item`: {currency, amount}, where currency is CURRENCY_BLUEPRINTS for
## towers and tiles or a Biome.Type for biome stones (paid in that faction's resource), or {}
## if it can't be bought.
func price_of(item: Dictionary) -> Dictionary:
	if item.get("kind", &"") == &"stone":
		return {currency = int(item.biome), amount = biome_cost(item.biome)}
	var kind := purchase_kind(item)
	if kind == &"":
		return {}
	return {currency = CURRENCY_BLUEPRINTS, amount = blueprint_cost(kind)}


## How many more of `kind` the player's blueprints could buy, each one costing one more
## than the last (only this kind; all blueprints spent on it).
func affordable_count(kind: StringName) -> int:
	var left := treasury.blueprints
	var cost := blueprint_cost(kind)
	var count := 0
	while left >= cost:
		left -= cost
		cost += 1
		count += 1
	return count


## How much of a price's currency the player has.
func funds(currency: int) -> int:
	return treasury.blueprints if currency == CURRENCY_BLUEPRINTS else treasury.resources.get(currency, 0)


## Faction resource a biome stone costs: 1 for the first tile of that biome, 2 for the second
## and so on (biome tiles on the island plus stones of it in the inventory).
func biome_cost(biome: int) -> int:
	var owned := treasury.inventory.count(Inventory.stone_item(biome))
	for coord in _tiles:
		if _tiles[coord].biome == biome:
			owned += 1
	return 1 + owned


## True if the player has `item` or can pay for one.
func can_get(item: Dictionary) -> bool:
	if treasury.inventory.count(item) > 0:
		return true
	var price := price_of(item)
	return not price.is_empty() and funds(price.currency) >= price.amount


## Makes sure one `item` is in the inventory, buying it if none is left.
func ensure_item(item: Dictionary) -> bool:
	if treasury.inventory.count(item) > 0:
		return true
	var price := price_of(item)
	if price.is_empty():
		return false
	if price.currency == CURRENCY_BLUEPRINTS:
		if not treasury.spend_blueprints(price.amount):
			return false
		treasury.inventory.add(Treasury.blueprint_item(purchase_kind(item)))
		# Kept even if the mission ends without a save (see IslandSave).
		unsaved_towers.append(String(purchase_kind(item)))
		if persist_blueprints:
			IslandSave.save_blueprints(self)
		return true
	if not treasury.spend(0, price.currency, price.amount):
		return false
	treasury.inventory.add(item)
	return true


## Undoes a purchase that wasn't placed: takes `item` back out of the inventory and refunds
## `price` (from price_of at the time of buying).
func refund(item: Dictionary, price: Dictionary) -> void:
	if price.is_empty() or not treasury.inventory.take(item):
		return
	if price.currency == CURRENCY_BLUEPRINTS:
		treasury.blueprints += price.amount
		var kind := String(purchase_kind(item))
		var at := unsaved_towers.rfind(kind)
		if at >= 0:
			unsaved_towers.remove_at(at)
		if persist_blueprints:
			IslandSave.save_blueprints(self)
	else:
		treasury.resources[price.currency] = treasury.resources.get(price.currency, 0) + price.amount
	treasury.changed.emit()


## Share of gold, blueprints and faction resources lost when the HQ falls.
const DEFEAT_LOSS := 0.5


## The HQ fell: loses DEFEAT_LOSS of gold, blueprints and every faction resource (rounded up)
## and returns what was lost: {gold, blueprints, resources = {Biome.Type: amount}}.
func lose_resources() -> Dictionary:
	var lost := {gold = ceili(treasury.gold * DEFEAT_LOSS), blueprints = ceili(treasury.blueprints * DEFEAT_LOSS), resources = {}}
	treasury.gold -= lost.gold
	treasury.blueprints -= lost.blueprints
	for biome in treasury.resources:
		var amount := ceili(treasury.resources[biome] * DEFEAT_LOSS)
		treasury.resources[biome] -= amount
		if amount > 0:
			lost.resources[biome] = amount
	treasury.changed.emit()
	if persist_blueprints:
		IslandSave.save_blueprints(self)
	return lost


## Adds a found blueprint (saved right away).
func add_blueprint() -> void:
	treasury.add_blueprint()
	if persist_blueprints:
		IslandSave.save_blueprints(self)


## Every building group on the island (single towers are groups of one).
func groups() -> Array:
	var result: Array = []
	var done := {}
	for coord in _tiles:
		if get_tower(coord) != null and not done.has(coord):
			var group := group_of(coord)
			for member in group:
				done[member] = true
			result.append(group)
	return result


## Current and maximum of a group pool: &"hp", &"shield" or &"energy".
func group_pool(coord: Vector2i, pool: StringName) -> Vector2:
	var total := Vector2.ZERO
	for member in group_of(coord):
		total += _member_pool(member, pool)
	return total


func _member_pool(coord: Vector2i, pool: StringName) -> Vector2:
	var tile := get_tile(coord)
	match pool:
		&"hp":
			return Vector2(tile.tower.hp, tower_max_hp(coord))
		&"shield":
			return Vector2(tile.tower.shield, tower_max_shield(coord))
	return Vector2(tile.energy, EnergyGrid.capacity(tile))


## Spreads `amount` of a pool over the group, each member filled to the same share.
func _set_group_pool(group: Array[Vector2i], pool: StringName, amount: float) -> void:
	var total_max := 0.0
	for member in group:
		total_max += _member_pool(member, pool).y
	var share := clampf(amount / total_max, 0.0, 1.0) if total_max > 0.0 else 0.0
	for member in group:
		var tile := get_tile(member)
		var cap := _member_pool(member, pool).y
		match pool:
			&"hp":
				tile.tower.hp = cap * share
			&"shield":
				tile.tower.shield = cap * share
			_:
				tile.energy = cap * share


## Evens out every group's pools (after regeneration, repairs and energy flow).
func _even_out_groups() -> void:
	for group in groups():
		if group.size() < 2:
			continue
		for pool in [&"hp", &"shield", &"energy"]:
			var total := 0.0
			for member in group:
				total += _member_pool(member, pool).x
			_set_group_pool(group, pool, total)
		# One big tower: the members split their experience, so they share one level.
		var xp := 0.0
		for member in group:
			xp += get_tower(member).xp
		for member in group:
			get_tower(member).xp = xp / group.size()


## Takes up to `amount` energy from the other members of `coord`'s group; returns how much.
func pull_group_energy(coord: Vector2i, amount: float) -> float:
	var taken := 0.0
	for member in group_of(coord):
		if member == coord or taken >= amount:
			continue
		var tile := get_tile(member)
		var part := minf(tile.energy, amount - taken)
		tile.energy -= part
		taken += part
	return taken


## Advances energy, regeneration and shields. Called every frame by the view.
func tick(delta: float) -> void:
	_aura_cache.clear()
	EnergyGrid.tick(self, delta)
	_tick_heals_over_time(delta)
	_power_auras(delta)
	# Aura power may have changed.
	_aura_cache.clear()
	for coord in _tiles:
		var tower := get_tower(coord)
		if tower == null:
			_regen_ground(coord, delta)
			continue
		var aura := aura_at(coord)
		var max_hp := tower_max_hp(coord)
		tower.time_since_damage += delta
		var regen: float = aura.get(&"regen", 0.0)
		if tower.type == &"wall" and tower.time_since_damage >= TowerDefs.WALL_REST_DELAY and tower.hp < max_hp:
			# The resting wall pays for its own repairs from its tile's energy.
			var power := EnergyGrid.draw_energy(self, coord, TowerDefs.WALL_REST_ENERGY * delta)
			regen += TowerDefs.WALL_REST_REGEN * power
		tower.hp = minf(max_hp, tower.hp + regen * max_hp * delta)
		var max_shield: float = max_hp * aura.get(&"shield", 0.0)
		if tower.shield < max_shield:
			# Shields regenerate from the tower's own storage where it has one.
			var gain := minf(max_shield - tower.shield, max_shield * SHIELD_REGEN * delta)
			var power := 1.0
			if EnergyGrid.capacity(get_tile(coord)) > 0.0:
				power = EnergyGrid.draw_energy(self, coord, gain * TowerDefs.SHIELD_ENERGY_PER_HP)
			tower.shield += gain * power
		tower.shield = minf(tower.shield, max_shield)
		var xp_rate: float = XP_PER_SECOND.get(tower.type, 0.0) if not tower.is_part else 0.0
		if tower.type == &"aura" or tower.type == &"scout":
			xp_rate *= tower.aura_power
		add_xp(coord, xp_rate * delta)
	_even_out_groups()
	_check_levels()
	_update_analysis(delta)


## Aura towers pay their energy every frame; their power scales the buff (0 = off).
func _power_auras(delta: float) -> void:
	for coord in _tiles:
		var tower := get_tower(coord)
		if tower and tower.type == &"aura" and not tower.is_part:
			var energy := AuraProfiles.for_tile(self, coord).energy_per_second * delta
			tower.aura_power = EnergyGrid.draw_energy(self, coord, energy)


## Regeneration auras (Forest tiles, Forest Aura towers) also mend the ground.
func _regen_ground(coord: Vector2i, delta: float) -> void:
	var tile := get_tile(coord)
	var max_hp := tile_max_hp(coord)
	if tile.destroyed or tile.hp >= max_hp:
		return
	var regen: float = aura_at(coord).get(&"regen", 0.0)
	if regen > 0.0:
		tile.hp = minf(max_hp, tile.hp + regen * max_hp * delta)
