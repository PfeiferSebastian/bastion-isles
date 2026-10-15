class_name Island
extends RefCounted
## The player's floating island: a set of hex tiles around a neutral HQ.
## Pure game logic, no rendering (see docs/GDD.md §3–§6).

signal tile_added(coord: Vector2i)
signal tile_removed(coord: Vector2i)
signal tile_changed(coord: Vector2i)
signal tower_destroyed(coord: Vector2i)

const HQ_COORD := Vector2i.ZERO
## Share of a tower's max shield that refills per second.
const SHIELD_REGEN := 0.05
## Tile tiers come from merging later (milestone 4); until then they are capped here.
const MAX_MERGE_TIER := 6

var _tiles: Dictionary[Vector2i, IslandTile] = {}


## A fresh island: the HQ plus neutral tiles out to `radius`.
static func create_starter(radius: int) -> Island:
	var island := Island.new()
	for coord in HexMath.area(HQ_COORD, radius):
		var tile := IslandTile.new(coord)
		tile.is_hq = coord == HQ_COORD
		island._tiles[coord] = tile
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
	if tile == null or tile.is_hq or tile.biome == type:
		return false
	tile.set_biome(type)
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
	tile.tier = clamped
	tile_changed.emit(coord)
	return true


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
