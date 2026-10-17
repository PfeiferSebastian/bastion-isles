class_name EnergyGrid
extends RefCounted
## Energy grid v2 – energy roads (GDD §6.5). Every faction follows the Neutral rules for now.
## - Every tile stores a little energy and passes it on through pipes to its neighbours. A pipe
##   carries at most the tile's pipe rate per second (empty tiles are power lines with twice
##   the rate); nothing is lost on the way.
## - Energy flows outward from the generators (by hop distance) toward tiles whose buildings –
##   or the buildings behind them – need it, split by urgency. That makes the roads.
## - A tile feeds at most FEEDS pipes at once (generators one per tier) and takes energy in
##   through a limited number of pipes (buildings: one per tier).
## - What a generator can't send fills its store; past that it spills to side tiles (on no
##   road), which hand it back to buildings and roads that need it. The rest is wasted.
## - Every building except generators pays an upkeep; urgency rises the longer a building
##   sits empty.
## Runs in fixed ticks (TICK) independent of the frame rate.

const TICK := 0.1
## Most ticks one frame may catch up on (after a hitch the grid falls behind instead).
const MAX_STEPS := 10
## Energy per second one pipe carries out of a tile with a building; more per tier above 1.
const PIPE_RATE := 6.0
const PIPE_RATE_PER_TIER := 0.5
## Empty tiles (and the HQ hub) are power lines.
const POWER_LINE_FACTOR := 2.0
## A tile stores its pipe rate × this (power lines don't store more).
const STORAGE_SECONDS := 3.0
## Pipes a tile has; it feeds FEEDS of them at once and takes energy in through the rest.
const CONNECTORS := 4
const FEEDS := 2
## Storehouses are capacitors: they catch what generators can't send and hand it to the
## buildings next to them that need it.
const STORAGE_CAPACITY := 75.0
## Every building but generators pays this per second; Aura and Scout pay their 1/s instead.
const UPKEEP := 0.5
const SELF_PAID: Array[StringName] = [&"aura", &"scout"]
## How urgently each type wants energy (scaled by how empty it is), and how much the urgency
## grows per second it sits empty.
const URGENCY_WEIGHT := {&"attack": 2.0, &"repair": 2.0, &"wall": 1.5, &"aura": 1.0, &"scout": 1.0}
## Storehouses' urgency: tiny, so they mostly fill once the buildings are full.
const STORAGE_URGENCY := 0.02
## A building's pass-through buffer holds this many seconds of its pipe rate.
const TRANSIT_SECONDS := 1.0
const STARVE_URGENCY := 0.2
## Below this share of its store a building counts as empty.
const EMPTY_SHARE := 0.05
## Side tiles even out with side neighbours by this share of the fill difference per tick.
const SIDE_SPREAD := 0.25
## Swamp tiles produce this much per second and tier, for their own tile and neighbours.
const SWAMP_PASSIVE := 0.3
## Forest towers keep working without energy at this share of their speed.
const FOREST_SLOW_EFFICIENCY := 0.33


static func capacity(tile: IslandTile) -> float:
	if tile.blocks_energy():
		return 0.0
	if is_storage(tile):
		return STORAGE_CAPACITY * tile.tower.stat_factor()
	var cap := _base_rate(tile) * STORAGE_SECONDS
	if tile.tower:
		cap *= tile.tower.stat_factor()
	return cap


## Storehouse tiles are capacitors (see STORAGE_CAPACITY).
static func is_storage(tile: IslandTile) -> bool:
	return tile.tower != null and tile.tower.type == &"warehouse"


## Generator hexes (merged ones too) push energy out and take none in.
static func is_producer(tile: IslandTile) -> bool:
	return tile.tower != null and tile.tower.type == &"energy"


static func fill(tile: IslandTile) -> float:
	var cap := capacity(tile)
	return tile.energy / cap if cap > 0.0 else 1.0


static func _base_rate(tile: IslandTile) -> float:
	return PIPE_RATE + PIPE_RATE_PER_TIER * maxi(tile.tier - 1, 0)


## Energy per second one pipe carries out of `tile`: power lines (empty ground, the HQ hub)
## twice as much. Damaged ground passes less (by its HP share) when `island` is given.
static func pipe_rate(tile: IslandTile, island: Island = null) -> float:
	if tile.blocks_energy():
		return 0.0
	var rate := _base_rate(tile)
	if tile.tower == null:
		rate *= POWER_LINE_FACTOR
	if island:
		rate *= clampf(tile.hp / maxf(island.tile_max_hp(tile.coord), 0.001), 0.0, 1.0)
	return rate


## Pipes `coord` feeds at once: generators one per tier, everything else FEEDS.
static func feeds(island: Island, coord: Vector2i) -> int:
	var tile := island.get_tile(coord)
	return maxi(1, tile.tier) if is_producer(tile) else FEEDS


## Pipes `coord` takes energy in through: buildings one per tier, other tiles the
## connectors they don't feed with.
static func entry_pipes(island: Island, coord: Vector2i) -> int:
	var tile := island.get_tile(coord)
	if tile.tower:
		return mini(maxi(1, tile.tier), CONNECTORS)
	return CONNECTORS - FEEDS


## Upkeep per second of a building of `type` (on top of what its work costs).
static func upkeep(type: StringName) -> float:
	if type == &"energy" or SELF_PAID.has(type):
		return 0.0
	return UPKEEP


## The generator profile for `coord` (the root of a generator), or null.
static func generator_at(island: Island, coord: Vector2i) -> EnergyProfile:
	var tile := island.get_tile(coord)
	if tile == null or not is_producer(tile) or tile.tower.is_part:
		return null
	return EnergyProfiles.for_tile(island, coord)


static func tick(island: Island, delta: float) -> void:
	island.energy_clock += delta
	var steps := 0
	while island.energy_clock >= TICK - 0.000001 and steps < MAX_STEPS:
		island.energy_clock -= TICK
		step(island, TICK)
		steps += 1
	if steps == MAX_STEPS:
		island.energy_clock = 0.0


## One fixed tick of the grid.
static func step(island: Island, dt: float) -> void:
	var coords := island.coords()
	for coord in coords:
		var tile := island.get_tile(coord)
		tile.energy = minf(tile.energy, capacity(tile))
		if tile.blocks_energy():
			tile.transit = 0.0
	_pay_upkeep(island, dt)
	_swamp_passive(island, dt)
	var dist := distances(island)
	var urgency := {}
	for coord in coords:
		urgency[coord] = _urgency(island, coord, dt)
	var demand := _demand(island, dist, urgency)
	_settle_transit(island, demand, urgency)
	var spill := _produce(island, dt)
	island.energy_flows.clear()
	_flow(island, dist, demand, urgency, dt)
	_spill(island, spill, demand)
	_hand_back(island, demand, urgency, dt)


## Hop distance from the nearest generator for every tile energy can reach.
static func distances(island: Island) -> Dictionary:
	var dist := {}
	var frontier: Array[Vector2i] = []
	for coord in island.coords():
		if is_producer(island.get_tile(coord)) and not island.get_tile(coord).blocks_energy():
			dist[coord] = 0
			frontier.append(coord)
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for coord in frontier:
			for n in HexMath.neighbors(coord):
				var tile := island.get_tile(n)
				if tile == null or dist.has(n) or tile.blocks_energy():
					continue
				dist[n] = dist[coord] + 1
				next.append(n)
		frontier = next
	return dist


## How urgently the building on `coord` wants energy (0 = full or no building). Also counts
## how long it has been empty.
static func _urgency(island: Island, coord: Vector2i, dt: float) -> float:
	var tile := island.get_tile(coord)
	if tile.tower == null or is_producer(tile):
		return 0.0
	var cap := capacity(tile)
	if cap <= 0.0:
		return 0.0
	var missing := cap - tile.energy
	# Storehouses take only what the buildings leave and never grow impatient.
	if is_storage(tile):
		return STORAGE_URGENCY * missing / cap if missing > 0.001 else 0.0
	tile.starved = tile.starved + dt if tile.energy < cap * EMPTY_SHARE else 0.0
	if missing <= 0.001:
		return 0.0
	return URGENCY_WEIGHT.get(tile.tower.type, 1.0) * (missing / cap + STARVE_URGENCY * tile.starved)


## A tile's own urgency plus that of every tile further out it could pass energy on to.
## Tiles with demand > 0 are on a road.
static func _demand(island: Island, dist: Dictionary, urgency: Dictionary) -> Dictionary:
	var order := dist.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return dist[a] > dist[b])
	var demand := {}
	for coord in island.coords():
		demand[coord] = urgency[coord]
	for coord in order:
		if is_producer(island.get_tile(coord)):
			continue
		for n in HexMath.neighbors(coord):
			if dist.get(n, -1) == dist[coord] + 1:
				demand[coord] += demand[n]
	return demand


## Generators fill their stores; returns what didn't fit, by generator root.
static func _produce(island: Island, dt: float) -> Dictionary:
	var spill := {}
	for coord in island.coords():
		var profile := generator_at(island, coord)
		if profile == null:
			continue
		var tile := island.get_tile(coord)
		var made := profile.output * dt
		var stored := minf(made, maxf(capacity(tile) - tile.energy, 0.0))
		tile.energy += stored
		spill[coord] = made - stored
	return spill


## Main flow: outward along roads, by demand, within pipe rates and entry pipes. Only what a
## tile held at the start of the tick moves on (one hop per tick).
static func _flow(island: Island, dist: Dictionary, demand: Dictionary, urgency: Dictionary, dt: float) -> void:
	var senders := dist.keys()
	senders.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return dist[a] < dist[b])
	# Buildings pass on only their pass-through buffer; empty ground and generators all they hold.
	var start := {}
	for coord in senders:
		start[coord] = _passable(island.get_tile(coord))
	# Parents each tile took energy from this tick (limited by its entry pipes).
	var parents := {}
	for source in senders:
		var tile := island.get_tile(source)
		var available: float = minf(start[source], _passable(tile))
		if available <= 0.0:
			continue
		var kids: Array[Vector2i] = []
		for n in HexMath.neighbors(source):
			if dist.get(n, -1) != dist[source] + 1 or demand[n] <= 0.0 or _room(island.get_tile(n)) <= 0.001:
				continue
			var taken: Array = parents.get(n, [])
			if not taken.has(source) and taken.size() >= entry_pipes(island, n):
				continue
			kids.append(n)
		if kids.is_empty():
			continue
		kids = _take_turns(island, source, kids, demand, feeds(island, source))
		var sent := _send(island, source, kids, demand, urgency, available, dt)
		for n in kids:
			if not parents.has(n):
				parents[n] = []
			if not parents[n].has(source):
				parents[n].append(source)
		if is_producer(tile) and sent > 0.0:
			var root := island.merge_root_of(source)
			island.track(root, &"delivered", sent)
			island.get_tower(root).saw_target = true
			island.get_tower(root).did_work = true


## With more candidates than pipes it can feed at once, a tile gives its pipes turns in
## proportion to the demand behind them: every candidate earns credit by its share, the ones
## with the most credit get this tick and pay one turn for it (90/10 demand → 9 ticks to 1).
static func _take_turns(island: Island, source: Vector2i, kids: Array[Vector2i], demand: Dictionary, pipes: int) -> Array[Vector2i]:
	if kids.size() <= pipes:
		return kids
	var total := 0.0
	for n in kids:
		total += demand[n]
	var credit := {}
	for n in kids:
		var key := Vector4i(source.x, source.y, n.x, n.y)
		credit[n] = island.energy_credits.get(key, 0.0) + pipes * demand[n] / total
	kids.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return credit[a] > credit[b])
	for i in kids.size():
		var key := Vector4i(source.x, source.y, kids[i].x, kids[i].y)
		island.energy_credits[key] = credit[kids[i]] - (1.0 if i < pipes else 0.0)
	kids.resize(pipes)
	return kids


## Sends up to `available` from `source` to `targets`, split by `weight`, each within the
## pipe's rate and the target's room. A building keeps its own share (by its urgency) and
## holds the rest in its pass-through buffer for the buildings behind it. Buildings send from
## their pass-through buffer unless `own_store`. Returns what was sent.
static func _send(island: Island, source: Vector2i, targets: Array[Vector2i], weight: Dictionary, urgency: Dictionary, available: float, dt: float, own_store := false) -> float:
	var tile := island.get_tile(source)
	var from_transit := _keeps_own(tile) and not own_store
	var sent := 0.0
	var open := targets.duplicate()
	# Two rounds: what a full or narrow pipe couldn't take goes to the others.
	for _pass in 2:
		var total := 0.0
		for n in open:
			total += weight[n]
		if total <= 0.0 or available - sent <= 0.001:
			break
		var budget := available - sent
		var still_open: Array[Vector2i] = []
		for n in open:
			var target := island.get_tile(n)
			var rate := pipe_rate(target, island)
			if not is_producer(tile):
				rate = minf(rate, pipe_rate(tile, island))
			var key := Vector4i(source.x, source.y, n.x, n.y)
			var moved: float = island.energy_flows.get(key, 0.0) * dt
			var share := minf(budget * weight[n] / total, rate * dt - moved)
			var own := share
			var passing := 0.0
			if _keeps_own(target):
				var keep := clampf(urgency[n] / weight[n], 0.0, 1.0) if weight[n] > 0.0 else 1.0
				own = share * keep
				passing = minf(share - own, transit_capacity(target, island) - target.transit)
			own = minf(own, capacity(target) - target.energy)
			var amount := maxf(own, 0.0) + maxf(passing, 0.0)
			if amount <= 0.0:
				continue
			if from_transit:
				tile.transit -= amount
			else:
				tile.energy -= amount
			target.energy += maxf(own, 0.0)
			target.transit += maxf(passing, 0.0)
			sent += amount
			island.energy_flows[key] = (moved + amount) / dt
			if amount >= budget * weight[n] / total - 0.0001:
				still_open.append(n)
		open = still_open
	return sent


## Buildings (not generators) keep what they receive for themselves and pass energy for
## others through a separate buffer.
static func _keeps_own(tile: IslandTile) -> bool:
	return tile.tower != null and not is_producer(tile)


## A building's pass-through buffer: one second of its pipe rate.
static func transit_capacity(tile: IslandTile, island: Island = null) -> float:
	return pipe_rate(tile, island) * TRANSIT_SECONDS if _keeps_own(tile) else 0.0


## What `tile` may pass on in the main flow.
static func _passable(tile: IslandTile) -> float:
	return tile.transit if _keeps_own(tile) else tile.energy


## Room left for energy arriving at `tile` (own store plus pass-through buffer).
static func _room(tile: IslandTile) -> float:
	return capacity(tile) - tile.energy + transit_capacity(tile) - tile.transit


## Pass-through energy with nobody left behind it to go to sinks into the building's own store.
static func _settle_transit(island: Island, demand: Dictionary, urgency: Dictionary) -> void:
	for coord in island.coords():
		var tile := island.get_tile(coord)
		if tile.transit <= 0.0 or demand[coord] - urgency[coord] > 0.001:
			continue
		var amount := minf(tile.transit, maxf(capacity(tile) - tile.energy, 0.0))
		tile.energy += amount
		tile.transit -= amount


## A generator that can't store any more fills the storehouses next to it (its capacitors),
## then spills to side tiles (on no road); what they can't take is wasted.
static func _spill(island: Island, spill: Dictionary, demand: Dictionary) -> void:
	for coord in spill:
		var left: float = spill[coord]
		if left <= 0.0:
			continue
		var stores: Array[Vector2i] = []
		var sides: Array[Vector2i] = []
		for member in island.group_of(coord):
			for n in HexMath.neighbors(member):
				var tile := island.get_tile(n)
				if tile == null or is_producer(tile) or capacity(tile) - tile.energy <= 0.001 or stores.has(n) or sides.has(n):
					continue
				if is_storage(tile):
					stores.append(n)
				elif demand.get(n, 0.0) <= 0.0:
					sides.append(n)
		for targets in [stores, sides]:
			for n in targets:
				var tile := island.get_tile(n)
				var amount := minf(left / targets.size(), capacity(tile) - tile.energy)
				tile.energy += amount
				left -= amount
		island.track(coord, &"delivered", spill[coord] - left)
		island.track(coord, &"wasted", left)


## Side tiles hand their energy to neighbours on a road (or that need it themselves) and even
## out with other side tiles; storehouses hand theirs to the buildings next to them that need
## it. Lowest priority, after the main flow.
static func _hand_back(island: Island, demand: Dictionary, urgency: Dictionary, dt: float) -> void:
	var start := {}
	for coord in island.coords():
		start[coord] = island.get_tile(coord).energy
	for coord in island.coords():
		var tile := island.get_tile(coord)
		var store := is_storage(tile)
		var side: bool = not store and tile.tower == null and demand[coord] <= 0.0
		if not (store or side) or start[coord] <= 0.0:
			continue
		var targets: Array[Vector2i] = []
		var spread: Array[Vector2i] = []
		for n in HexMath.neighbors(coord):
			var other := island.get_tile(n)
			if other == null or is_producer(other) or is_storage(other) or _room(other) <= 0.001:
				continue
			if urgency[n] > 0.0 or (side and demand[n] > 0.0):
				targets.append(n)
			elif side and other.tower == null and demand[n] <= 0.0 and fill(other) < fill(tile):
				spread.append(n)
		var available: float = minf(start[coord], tile.energy)
		if not targets.is_empty():
			available -= _send(island, coord, targets, demand, urgency, available, dt, true)
		for n in spread:
			var other := island.get_tile(n)
			var amount := minf(available, (fill(tile) - fill(other)) * capacity(other) * SIDE_SPREAD)
			amount = minf(amount, pipe_rate(tile, island) * dt)
			if amount <= 0.0:
				continue
			tile.energy -= amount
			other.energy += amount
			available -= amount


## Every building except generators pays its upkeep from its store.
static func _pay_upkeep(island: Island, dt: float) -> void:
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.is_part:
			continue
		var cost := upkeep(tower.type) * dt
		if cost > 0.0:
			draw_energy(island, coord, cost)


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
		island.track(coord, &"energy_used", amount)
		return 1.0
	# Combined buildings share their stored energy.
	if tile.tower and island.group_pool(coord, &"energy").x >= amount:
		island.pull_group_energy(coord, amount - tile.energy)
		tile.energy = 0.0
		island.track(coord, &"energy_used", amount)
		return 1.0
	if tile.biome == Biome.Type.SWAMP and _drain_neighbours(island, coord, amount - tile.energy):
		tile.energy = 0.0
		island.track(coord, &"energy_used", amount)
		return 1.0
	if tile.biome == Biome.Type.FOREST:
		return FOREST_SLOW_EFFICIENCY
	return 0.0


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


## Swamp tiles produce a little energy of their own (more per tier) for their own tile; what
## doesn't fit goes to their neighbours.
static func _swamp_passive(island: Island, delta: float) -> void:
	for coord in island.coords():
		var tile := island.get_tile(coord)
		if tile.biome != Biome.Type.SWAMP or tile.destroyed:
			continue
		var left := SWAMP_PASSIVE * tile.tier * delta
		var own := minf(left, maxf(capacity(tile) - tile.energy, 0.0))
		tile.energy += own
		left -= own
		for n in HexMath.neighbors(coord):
			var other := island.get_tile(n)
			if other == null or left <= 0.0:
				continue
			var amount := minf(left, maxf(capacity(other) - other.energy, 0.0))
			other.energy += amount
			left -= amount


## Tiles the generator on `coord` (all its hexes) sent energy to in the last tick, following
## the flows outward: 1.0 for its neighbours, less with every hop.
static func fed_by(island: Island, coord: Vector2i) -> Dictionary:
	var result := {}
	var frontier: Array[Vector2i] = []
	for member in island.group_of(coord):
		if is_producer(island.get_tile(member)):
			frontier.append(member)
	var share := 1.0
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for key: Vector4i in island.energy_flows:
			var from := Vector2i(key.x, key.y)
			var to := Vector2i(key.z, key.w)
			if frontier.has(from) and not result.has(to) and not is_producer(island.get_tile(to)):
				result[to] = share
				next.append(to)
		frontier = next
		share = maxf(share * 0.7, 0.2)
	return result
