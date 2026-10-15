class_name EnergyGrid
extends RefCounted
## Energy layer beneath the buildings (GDD §6.5).
## - Only tiles with an energy-consuming tower store energy; towers draw from their own tile.
## - Generators (Energy towers and the HQ) push energy along paths through the island.
##   Tiles with a building pass it on without loss; empty tiles are conduits that lose a
##   biome-dependent share. Blocked tiles (destroyed in battle, later) stop the flow.
## - On top, each generator has its own falloff by path length.
## Default refill priority (chips can change it later): best-connected first, then emptiest.

const BASE_CAPACITY := 20.0
const CAPACITY_PER_TIER := 10.0
## Storehouses work as batteries for now: they hold what a basic generator makes in 50 s
## (5 × 10 s), take only what generators have left over, and hand it out again to buildings
## in reach that run low, as fast as a basic generator.
const STORAGE_CAPACITY := 5.0 * 10.0 * 6.0
const STORAGE_OUTPUT := 6.0
## Share of energy an empty tile of this biome lets through (factions differ). Water and
## wood carry energy best, plain ground and rock poorly.
const CONDUIT_EFFICIENCY := {
	Biome.Type.NEUTRAL: 0.30,
	Biome.Type.FOREST: 0.60,
	Biome.Type.MOUNTAIN: 0.25,
	Biome.Type.PLAINS: 0.45,
	Biome.Type.SWAMP: 0.35,
	# Hydro power: water carries energy best (placeholder until the Seafolk are designed).
	Biome.Type.LAKE: 0.70,
}
## Each tier above 1 lets this much more through; water biomes gain twice as much.
const CONDUIT_PER_TIER := 0.03
const CONDUIT_PER_TIER_WATER := 0.06
const CONDUIT_MAX := 0.95
## Forest tiles produce this much per second and tier, feeding themselves and their neighbours.
const FOREST_PASSIVE := 0.3
## …and this many times more when connected to a Forest Energy tower (root network).
const ROOT_NETWORK_FACTOR := 3.0
## Plains conduit closes this share of the gap to the average fill per second.
const CONDUIT_RATE := 0.5
## Swamp decay: energy released when an enemy dies within DECAY_REACH hexes.
const DECAY_ENERGY := 8.0
const DECAY_REACH := 3
## Forest towers keep working without energy at this share of their speed.
const FOREST_SLOW_EFFICIENCY := 0.33


static func capacity(tile: IslandTile) -> float:
	if is_storage(tile):
		return STORAGE_CAPACITY
	if tile.tower == null or not TowerDefs.ENERGY_CONSUMERS.has(tile.tower.type):
		return 0.0
	return BASE_CAPACITY + CAPACITY_PER_TIER * tile.tier


## Storehouse tiles store energy for others (see STORAGE_CAPACITY).
static func is_storage(tile: IslandTile) -> bool:
	return tile.tower != null and tile.tower.type == &"warehouse"


static func fill(tile: IslandTile) -> float:
	var cap := capacity(tile)
	return tile.energy / cap if cap > 0.0 else 1.0


## Share of energy that passes through `tile` on its way somewhere else. Damaged ground
## passes less (by its HP share) when `island` is given.
static func pass_through(tile: IslandTile, island: Island = null) -> float:
	if tile.blocks_energy():
		return 0.0
	var share := 1.0
	if tile.tower == null and not tile.is_hq:
		var per_tier := CONDUIT_PER_TIER_WATER if tile.biome == Biome.Type.LAKE else CONDUIT_PER_TIER
		share = minf(CONDUIT_MAX, CONDUIT_EFFICIENCY.get(tile.biome, 0.3) + per_tier * maxi(tile.tier - 1, 0))
	if island:
		share *= clampf(tile.hp / maxf(island.tile_max_hp(tile.coord), 0.001), 0.0, 1.0)
	return share


## The generator profile for `coord`, or null if nothing there produces energy.
static func generator_at(island: Island, coord: Vector2i) -> EnergyProfile:
	var tile := island.get_tile(coord)
	if tile == null:
		return null
	if tile.is_hq:
		return EnergyProfiles.hq()
	if tile.tower and tile.tower.type == &"energy":
		return EnergyProfiles.for_tile(island, coord)
	return null


## For every tile the generator at `source` reaches: the share of energy that arrives
## (path losses × the generator's falloff by path length). The source itself is excluded.
static func delivery_map(island: Island, source: Vector2i, profile: EnergyProfile) -> Dictionary:
	var result := {}
	var frontier := {source: 1.0}
	for hops in range(1, profile.reach() + 1):
		var next := {}
		for coord in frontier:
			# Energy leaving an intermediate tile pays its pass-through loss.
			var leaving: float = frontier[coord] * (1.0 if coord == source else pass_through(island.get_tile(coord), island))
			if leaving <= 0.0:
				continue
			for n in HexMath.neighbors(coord):
				var tile := island.get_tile(n)
				if tile == null or n == source or tile.blocks_energy():
					continue
				if leaving > next.get(n, 0.0):
					next[n] = leaving
		for coord in next:
			var arrives: float = next[coord] * profile.falloff[hops]
			if arrives > result.get(coord, 0.0):
				result[coord] = arrives
		frontier = next
	return result


static func tick(island: Island, delta: float) -> void:
	for coord in island.coords():
		var tile := island.get_tile(coord)
		tile.energy = minf(tile.energy, capacity(tile))
	_forest_passive(island, delta)
	for coord in island.coords():
		var profile := generator_at(island, coord)
		if profile == null:
			continue
		distribute(island, coord, profile, profile.output * delta)
		if profile.special == &"conduit":
			_balance(island, coord, profile, delta)
	# Storehouses hand their energy on to buildings that run low (never to other storehouses).
	var storage_profile := EnergyProfile.new()
	for coord in island.coords():
		var tile := island.get_tile(coord)
		if is_storage(tile) and tile.energy > 0.0:
			var spend := minf(tile.energy, STORAGE_OUTPUT * delta)
			tile.energy -= spend - distribute(island, coord, storage_profile, spend, false)


## Sends `budget` energy from `source` to the storages it reaches: buildings first (best-
## connected, then emptiest), storehouses only with what is left – and none at all unless
## `to_storehouses`. Returns the unused budget.
static func distribute(island: Island, source: Vector2i, profile: EnergyProfile, budget: float, to_storehouses := true) -> float:
	var shares := delivery_map(island, source, profile)
	var targets: Array[Vector2i] = []
	for coord in shares:
		var target := island.get_tile(coord)
		if capacity(target) > 0.0 and (to_storehouses or not is_storage(target)):
			targets.append(coord)
	targets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_store := is_storage(island.get_tile(a))
		if a_store != is_storage(island.get_tile(b)):
			return not a_store
		if not is_equal_approx(shares[a], shares[b]):
			return shares[a] > shares[b]
		return fill(island.get_tile(a)) < fill(island.get_tile(b)))
	for coord in targets:
		if budget <= 0.0:
			break
		var tile := island.get_tile(coord)
		var missing := capacity(tile) - tile.energy
		if missing <= 0.0:
			continue
		var arrives: float = shares[coord]
		var give := minf(missing, budget * arrives)
		tile.energy += give
		budget -= give / arrives
	return budget


## Takes `amount` from the tile's storage. Returns the efficiency the tower may work at:
## 1 = paid; Swamp drains neighbours when empty; Forest keeps going slower for free; 0 = stopped.
static func draw_energy(island: Island, coord: Vector2i, amount: float) -> float:
	var tile := island.get_tile(coord)
	if tile == null:
		return 0.0
	if amount <= 0.0:
		return 1.0
	if tile.energy >= amount:
		tile.energy -= amount
		return 1.0
	# Combined buildings share their stored energy.
	if tile.tower and island.group_pool(coord, &"energy").x >= amount:
		island.pull_group_energy(coord, amount - tile.energy)
		tile.energy = 0.0
		return 1.0
	if tile.biome == Biome.Type.SWAMP and _drain_neighbours(island, coord, amount - tile.energy):
		tile.energy = 0.0
		return 1.0
	if tile.biome == Biome.Type.FOREST:
		return FOREST_SLOW_EFFICIENCY
	return 0.0


## Swamp decay generators within reach release energy when an enemy dies at `coord`.
static func notify_enemy_died(island: Island, coord: Vector2i) -> void:
	for source in island.coords():
		if HexMath.distance(source, coord) > DECAY_REACH:
			continue
		var profile := generator_at(island, source)
		if profile and profile.special == &"decay":
			distribute(island, source, profile, DECAY_ENERGY)


static func _drain_neighbours(island: Island, coord: Vector2i, needed: float) -> bool:
	var neighbours: Array[IslandTile] = []
	var available := 0.0
	for n in HexMath.neighbors(coord):
		var tile := island.get_tile(n)
		if tile and tile.energy > 0.0:
			neighbours.append(tile)
			available += tile.energy
	if available < needed:
		return false
	for tile in neighbours:
		tile.energy -= needed * tile.energy / available
	return true


## Forest tiles act as tiny generators: they fill their own storage (if they have one)
## and their direct neighbours.
static func _forest_passive(island: Island, delta: float) -> void:
	var rooted := _root_network(island)
	var profile := EnergyProfile.new()
	profile.falloff = PackedFloat32Array([1.0, 1.0])
	for coord in island.coords():
		var tile := island.get_tile(coord)
		if tile.biome != Biome.Type.FOREST:
			continue
		var budget := FOREST_PASSIVE * tile.tier * (ROOT_NETWORK_FACTOR if rooted.has(coord) else 1.0) * delta
		var own_missing := capacity(tile) - tile.energy
		var own := minf(own_missing, budget)
		tile.energy += own
		distribute(island, coord, profile, budget - own)


## Forest tiles connected (through Forest) to a Forest tile with an Energy tower.
static func _root_network(island: Island) -> Dictionary:
	var seen := {}
	var frontier: Array[Vector2i] = []
	for coord in island.coords():
		var tile := island.get_tile(coord)
		if tile.biome == Biome.Type.FOREST and tile.tower and tile.tower.type == &"energy":
			seen[coord] = true
			frontier.append(coord)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		for n in HexMath.neighbors(current):
			var tile := island.get_tile(n)
			if tile and tile.biome == Biome.Type.FOREST and not seen.has(n):
				seen[n] = true
				frontier.append(n)
	return seen


## Plains conduit: evens out the storages it reaches.
static func _balance(island: Island, center: Vector2i, profile: EnergyProfile, delta: float) -> void:
	var tiles: Array[IslandTile] = []
	var total := 0.0
	var total_capacity := 0.0
	for coord in delivery_map(island, center, profile):
		var tile := island.get_tile(coord)
		if capacity(tile) > 0.0:
			tiles.append(tile)
			total += tile.energy
			total_capacity += capacity(tile)
	if total_capacity <= 0.0:
		return
	var average := total / total_capacity
	var step := minf(1.0, CONDUIT_RATE * delta)
	for tile in tiles:
		tile.energy += (average * capacity(tile) - tile.energy) * step
