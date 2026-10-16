class_name FogOfWar
extends RefCounted
## Fog of war around the island (GDD §8.6), on the island's hex grid.
## Three levels: THICK (dense clouds, nothing visible), GREY (light clouds: something is
## there, but not what) and OPEN (clear sky). The island and the ring of hexes right
## around it are always open.
## Scout towers keep a circle around themselves open; revealed sky clouds over again
## after a while. Enemy fire gives its position away one level per shot.

enum Level { OPEN, GREY, THICK }

## Hexes from the HQ that the fog covers.
const RADIUS := 13
## Seconds an opened hex stays open, and a greyed hex stays grey, before clouding over.
const OPEN_HOLD := 15.0
const GREY_HOLD := 20.0

var island: Island

var _level: Dictionary[Vector2i, int] = {}
var _hold: Dictionary[Vector2i, float] = {}


func _init(for_island: Island) -> void:
	island = for_island
	for cell in HexMath.area(Island.HQ_COORD, RADIUS):
		_level[cell] = Level.THICK


func level_at(cell: Vector2i) -> int:
	if always_open(cell):
		return Level.OPEN
	return _level.get(cell, Level.THICK)


## The island's tiles and their direct neighbours are never fogged.
func always_open(cell: Vector2i) -> bool:
	if island.has_tile(cell):
		return true
	for n in HexMath.neighbors(cell):
		if island.has_tile(n):
			return true
	return false


func is_visible(cell: Vector2i) -> bool:
	return level_at(cell) == Level.OPEN


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_level.keys())
	return result


## Lifts the fog of `cell` to `to_level` (never thickens it) and keeps it there for `hold` s.
func reveal(cell: Vector2i, to_level: int, hold: float) -> void:
	if always_open(cell) or not _level.has(cell):
		return
	if to_level < _level[cell]:
		_level[cell] = to_level
		_hold[cell] = hold
	elif to_level == _level[cell]:
		_hold[cell] = maxf(_hold.get(cell, 0.0), hold)


## One level clearer: thick → grey → open (enemy fire uses this).
func reveal_step(cell: Vector2i) -> void:
	match level_at(cell):
		Level.THICK:
			reveal(cell, Level.GREY, GREY_HOLD)
		_:
			reveal(cell, Level.OPEN, OPEN_HOLD)


## Advances clouding over and all Scout towers.
func tick(delta: float) -> void:
	for cell in _hold.keys():
		_hold[cell] -= delta
		if _hold[cell] <= 0.0:
			if _level[cell] == Level.OPEN:
				_level[cell] = Level.GREY
				_hold[cell] = GREY_HOLD
			else:
				_level[cell] = Level.THICK
				_hold.erase(cell)
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.type != &"scout" or tower.is_part:
			continue
		var profile := ScoutProfiles.for_tile(island, coord)
		tower.aura_power = EnergyGrid.draw_energy(island, coord, profile.energy_per_second * delta)
		if tower.aura_power > 0.0:
			for cell in scout_area(coord, profile):
				reveal(cell, Level.OPEN, OPEN_HOLD * profile.hold_factor)


## The hexes a Scout tower keeps open.
func scout_area(coord: Vector2i, profile: ScoutProfile) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in HexMath.area(coord, profile.radius):
		if cell != coord:
			result.append(cell)
	return result
