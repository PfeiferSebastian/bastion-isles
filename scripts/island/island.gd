class_name Island
extends RefCounted
## The player's floating island: a set of hex tiles around a neutral HQ.
## Pure game logic, no rendering (see docs/GDD.md §3–§6).

signal tile_added(coord: Vector2i)
signal tile_removed(coord: Vector2i)
signal tile_changed(coord: Vector2i)
signal tower_destroyed(coord: Vector2i)
signal tile_destroyed(coord: Vector2i)

const HQ_COORD := Vector2i.ZERO
## Share of a tower's max shield that refills per second.
const SHIELD_REGEN := 0.05
## Tile tiers come from merging later (milestone 4); until then they are capped here.
const MAX_MERGE_TIER := 6
## Ground structure: plenty, so tiles outlast buildings. Placeholder numbers.
const HQ_MAX_HP := 2000.0
const TILE_BASE_HP := 300.0
const TILE_HP_PER_TIER := 100.0

var _tiles: Dictionary[Vector2i, IslandTile] = {}
## Active heals over time: {coord, tower (bool), rate (HP/s), time (s left)}.
var _heals_over_time: Array[Dictionary] = []

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
		before = tile.tower.hp
		tile.tower.hp = minf(tower_max_hp(coord), tile.tower.hp + amount)
		return tile.tower.hp - before
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
		var taken := minf(amount, tile.tower.hp - 1.0)
		tile.tower.hp -= taken
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


func aura_at(coord: Vector2i) -> Dictionary:
	return Auras.collect(self, coord)


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


func place_tower(coord: Vector2i, type: StringName) -> Tower:
	if not can_place(coord):
		return null
	var tile := get_tile(coord)
	tile.tower = Tower.new(type, 1.0)
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
func remove_tower(coord: Vector2i) -> StringName:
	var tower := get_tower(coord)
	if tower == null:
		return &""
	get_tile(coord).tower = null
	tile_changed.emit(coord)
	return tower.type


func get_tower(coord: Vector2i) -> Tower:
	var tile := get_tile(coord)
	return tile.tower if tile else null


func tower_max_hp(coord: Vector2i) -> float:
	var tower := get_tower(coord)
	if tower == null:
		return 0.0
	return TowerDefs.base_hp(tower.type) * (1.0 + aura_at(coord).get(&"max_hp", 0.0))


func tower_max_shield(coord: Vector2i) -> float:
	return tower_max_hp(coord) * aura_at(coord).get(&"shield", 0.0)


## Damage hits the shield first. Desert tiles pass a share on to neighbouring towers.
func damage_tower(coord: Vector2i, amount: float) -> void:
	if get_tower(coord) == null:
		return
	var spread: float = minf(aura_at(coord).get(&"damage_spread", 0.0), 1.0)
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


func _apply_damage(coord: Vector2i, amount: float) -> void:
	var tower := get_tower(coord)
	if tower == null:
		return
	tower.time_since_damage = 0.0
	var absorbed := minf(tower.shield, amount)
	tower.shield -= absorbed
	tower.hp -= amount - absorbed
	if tower.hp <= 0.0:
		get_tile(coord).tower = null
		tower_destroyed.emit(coord)
		tile_changed.emit(coord)


## Advances energy, regeneration and shields. Called every frame by the view.
func tick(delta: float) -> void:
	EnergyGrid.tick(self, delta)
	_tick_heals_over_time(delta)
	for coord in _tiles:
		var tower := get_tower(coord)
		if tower == null:
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
		tower.shield = minf(max_shield, tower.shield + max_shield * SHIELD_REGEN * delta)
