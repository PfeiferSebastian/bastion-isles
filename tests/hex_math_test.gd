extends SceneTree
## Run: godot --headless --path . -s tests/hex_math_test.gd

var _failures := 0


func _init() -> void:
	_test_pixel_roundtrip()
	_test_neighbors_and_distance()
	_test_area()
	_test_island_towers()
	_test_island_tiles()
	_test_biomes_and_auras()
	_test_health()
	_test_attack_profiles()
	_test_enemy_statuses()
	_test_energy()
	print("hex_math_test: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", label)


func _test_pixel_roundtrip() -> void:
	for hex in HexMath.area(Vector2i.ZERO, 4):
		var px := HexMath.to_pixel(hex, 48.0)
		_check(HexMath.from_pixel(px, 48.0) == hex, "roundtrip %s" % hex)
		# Points near (but inside) the hex still resolve to it.
		_check(HexMath.from_pixel(px + Vector2(20, 15), 48.0) == hex, "inner point %s" % hex)


func _test_neighbors_and_distance() -> void:
	for n in HexMath.neighbors(Vector2i(2, -1)):
		_check(HexMath.distance(n, Vector2i(2, -1)) == 1, "neighbor distance %s" % n)
	_check(HexMath.distance(Vector2i(0, 0), Vector2i(3, -3)) == 3, "distance 3")


func _test_area() -> void:
	_check(HexMath.area(Vector2i.ZERO, 0).size() == 1, "area r0")
	_check(HexMath.area(Vector2i.ZERO, 2).size() == 19, "area r2")


func _test_island_towers() -> void:
	var island := Island.create_starter(2)
	_check(island.tile_count() == 19, "starter tiles")
	_check(island.get_tile(Island.HQ_COORD).is_hq, "hq at centre")
	_check(not island.can_place(Island.HQ_COORD), "cannot build on hq")
	_check(island.place_tower(Vector2i(1, 0), &"attack") != null, "place tower")
	_check(not island.can_place(Vector2i(1, 0)), "occupied tile blocked")
	_check(island.change_tower_type(Vector2i(1, 0), &"wall"), "change tower type")
	_check(island.get_tower(Vector2i(1, 0)).hp == TowerDefs.base_hp(&"wall"), "type change keeps full health")
	_check(not island.change_tower_type(Vector2i(2, 0), &"wall"), "cannot change on empty tile")
	_check(island.remove_tower(Vector2i(1, 0)) == &"wall", "remove tower")


func _test_island_tiles() -> void:
	var island := Island.create_starter(1)
	_check(island.can_add_tile(Vector2i(2, 0)), "add adjacent tile")
	_check(not island.can_add_tile(Vector2i(3, 0)), "reject detached tile")
	_check(island.add_tile(Vector2i(2, 0)), "added tile")
	_check(island.add_tile(Vector2i(3, 0)), "chain tile")
	_check(not island.can_remove_tile(Vector2i(2, 0)), "removing bridge would split island")
	_check(island.remove_tile(Vector2i(3, 0)), "remove leaf tile")
	_check(not island.can_remove_tile(Island.HQ_COORD), "hq cannot be removed")
	island.place_tower(Vector2i(1, 0), &"attack")
	_check(not island.can_remove_tile(Vector2i(1, 0)), "occupied tile cannot be removed")


func _test_biomes_and_auras() -> void:
	var island := Island.create_starter(2)
	var c := Vector2i(1, 0)
	_check(island.set_biome(c, Biome.Type.MOUNTAIN), "biome stone on neutral tile")
	_check(island.get_tile(c).tier == 1, "biome tile starts at tier 1")
	_check(not island.set_biome(Island.HQ_COORD, Biome.Type.FOREST), "hq stays neutral")
	_check(island.add_tile(Vector2i(3, 0), Biome.Type.DESERT), "biome stone as new tile")
	_check(island.get_tile(Vector2i(3, 0)).tier == 1, "new biome tile is tier 1")
	# Mountain aura reaches the tile itself and its neighbours, scaled by tier.
	_check(is_equal_approx(island.aura_at(c).get(&"max_hp", 0.0), 0.05), "own mountain aura")
	_check(is_equal_approx(island.aura_at(Vector2i(2, 0)).get(&"max_hp", 0.0), 0.05), "neighbour mountain aura")
	_check(not island.aura_at(Vector2i(-1, 0)).has(&"max_hp"), "aura does not reach distance 2")
	island.set_tier(c, 3)
	_check(is_equal_approx(island.aura_at(Vector2i(2, 0)).get(&"max_hp", 0.0), 0.15), "aura scales with tier")
	island.set_biome(Vector2i(2, 0), Biome.Type.MOUNTAIN)
	_check(is_equal_approx(island.aura_at(Vector2i(2, 0)).get(&"max_hp", 0.0), 0.20), "auras stack")
	_check(island.set_biome(c, Biome.Type.NEUTRAL) and island.get_tile(c).tier == 0, "revert to neutral")


func _test_health() -> void:
	var island := Island.create_starter(2)
	var c := Vector2i(1, 0)
	island.set_biome(c, Biome.Type.MOUNTAIN)
	island.place_tower(c, &"attack")
	_check(is_equal_approx(island.tower_max_hp(c), 105.0), "mountain raises max hp")
	island.damage_tower(c, 30.0)
	_check(is_equal_approx(island.get_tower(c).hp, 75.0), "damage lowers hp")
	# Forest neighbour regenerates 1% of max hp per second.
	island.set_biome(Vector2i(2, 0), Biome.Type.FOREST)
	island.tick(10.0)
	_check(is_equal_approx(island.get_tower(c).hp, 75.0 + 10.5), "forest regen")
	# Desert spreads 10% per tier of incoming damage to neighbouring towers.
	var d := Vector2i(-1, 0)
	island.set_biome(d, Biome.Type.DESERT)
	island.place_tower(d, &"attack")
	island.place_tower(Vector2i(-2, 0), &"attack")
	island.damage_tower(d, 50.0)
	_check(is_equal_approx(island.get_tower(Vector2i(-2, 0)).hp, 95.0), "desert spread to neighbour")
	_check(is_equal_approx(island.get_tower(d).hp, 55.0), "desert keeps the rest")
	# Plains shield absorbs damage first.
	var p := Vector2i(0, 2)
	island.set_biome(p, Biome.Type.PLAINS)
	island.place_tower(p, &"attack")
	island.get_tower(p).shield = island.tower_max_shield(p)
	island.damage_tower(p, 10.0)
	_check(is_equal_approx(island.get_tower(p).hp, 93.0), "shield absorbs first")
	# Destroyed towers leave the tile.
	island.damage_tower(p, 1000.0)
	_check(island.get_tower(p) == null, "destroyed tower removed")
	# Resting walls regenerate after 10 s without damage.
	# Outside the HQ's reach and with an empty storage, so only the test controls its energy.
	var w := Vector2i(-3, 1)
	island.add_tile(w)
	island.place_tower(w, &"wall")
	island.damage_tower(w, 100.0)
	island.tick(5.0)
	_check(is_equal_approx(island.get_tower(w).hp, 300.0), "wall waits before resting")
	island.tick(6.0)
	_check(is_equal_approx(island.get_tower(w).hp, 300.0), "resting wall needs energy to regenerate")
	island.get_tile(w).energy = 20.0
	island.tick(1.0)
	_check(island.get_tower(w).hp > 300.0, "wall regenerates at rest from its tile energy")
	_check(island.get_tile(w).energy < 20.0, "wall regeneration costs energy")


func _test_attack_profiles() -> void:
	var island := Island.create_starter(2)
	var c := Vector2i(1, 0)
	var neutral := AttackProfiles.for_tile(island, c)
	_check(neutral.damage == 10.0 and neutral.beam_dps == 0.0, "neutral shoots plain projectiles")
	island.set_biome(c, Biome.Type.MOUNTAIN)
	var mountain := AttackProfiles.for_tile(island, c)
	_check(mountain.damage > neutral.damage and mountain.range_hexes > neutral.range_hexes, "mountain shells hit harder and further")
	island.set_tier(c, 3)
	_check(is_equal_approx(AttackProfiles.for_tile(island, c).damage, 45.0), "damage scales with tier")
	island.set_biome(c, Biome.Type.DESERT)
	var desert := AttackProfiles.for_tile(island, c)
	_check(desert.beam_dps > 0.0 and not desert.has_projectile(), "desert fires a laser")
	# Desert efficiency aura speeds up a neighbour's attack.
	_check(AttackProfiles.for_tile(island, Vector2i(2, 0)).cooldown < neutral.cooldown, "desert efficiency shortens cooldown")
	# Plains morph: 3 Desert + 1 Swamp neighbours -> 3 lasers plus a light weaken.
	var morph_island := Island.create_starter(2)
	var p := Vector2i(1, -1)
	morph_island.set_biome(p, Biome.Type.PLAINS)
	var ring := HexMath.neighbors(p)
	for i in 3:
		_paint(morph_island, ring[i], Biome.Type.DESERT)
	_paint(morph_island, ring[3], Biome.Type.SWAMP)
	var morph := AttackProfiles.morph(morph_island, p)
	_check(morph.beam_count == 3, "plains morph: one laser per desert neighbour")
	_check(is_equal_approx(morph.weaken, 0.1), "plains morph: swamp share of weaken")
	var lonely := Island.create_starter(2)
	lonely.set_biome(Vector2i(2, 0), Biome.Type.PLAINS)
	_check(AttackProfiles.morph(lonely, Vector2i(2, 0)).damage == 10.0, "plains without biome neighbours shoots like neutral")


## Biome stone on an existing tile, or a new biome tile if the hex is empty.
func _paint(island: Island, coord: Vector2i, biome: Biome.Type) -> void:
	if island.has_tile(coord):
		island.set_biome(coord, biome)
	else:
		island.add_tile(coord, biome)


func _test_enemy_statuses() -> void:
	var enemy := Enemy.new()
	enemy.take_damage(10.0)
	_check(is_equal_approx(enemy.hp, 50.0), "enemy takes damage")
	enemy.add_thorns(2.0, 3)
	enemy.add_thorns(2.0, 3)
	enemy.add_thorns(2.0, 3)
	enemy.add_thorns(2.0, 3)
	_check(enemy.thorn_stacks() == 3, "thorn stacks are capped")
	enemy.tick_statuses(1.0)
	_check(is_equal_approx(enemy.hp, 44.0), "thorn stacks deal damage over time")
	enemy.add_weaken(0.4)
	_check(is_equal_approx(enemy.damage_output(), enemy.dps * 0.6), "weaken lowers enemy damage")
	enemy.take_damage(10.0)
	_check(is_equal_approx(enemy.hp, 44.0 - 12.0), "weakened enemy takes extra damage")
	enemy.take_damage(1000.0)
	_check(enemy.is_dead, "enemy dies")


func _test_energy() -> void:
	var island := Island.create_starter(3)
	var c := Vector2i(1, 0)
	_check(EnergyGrid.capacity(island.get_tile(c)) == 0.0, "empty tile stores no energy")
	island.place_tower(c, &"attack")
	_check(EnergyGrid.capacity(island.get_tile(c)) == 20.0, "consumer tile gets a storage")
	island.set_biome(c, Biome.Type.MOUNTAIN)
	_check(EnergyGrid.capacity(island.get_tile(c)) == 30.0, "tier 1 storage is larger")
	island.change_tower_type(c, &"energy")
	_check(EnergyGrid.capacity(island.get_tile(c)) == 0.0, "generators store nothing")

	# Paths: an empty tile is a lossy conduit, a built tile passes energy on fully.
	var grid := Island.create_starter(3)
	var gen := Vector2i(1, 0)
	var mid := Vector2i(2, 0)
	var target := Vector2i(3, 0)
	grid.place_tower(gen, &"energy")
	grid.place_tower(target, &"attack")
	var profile := EnergyProfiles.for_tile(grid, gen)
	var shares := EnergyGrid.delivery_map(grid, gen, profile)
	_check(is_equal_approx(shares[target], 0.85 * 0.5), "neutral conduit loses 15% on top of falloff")
	grid.set_biome(mid, Biome.Type.PLAINS)
	_check(is_equal_approx(EnergyGrid.delivery_map(grid, gen, profile)[target], 0.97 * 0.5), "plains conducts better")
	grid.place_tower(mid, &"warehouse")
	_check(is_equal_approx(EnergyGrid.delivery_map(grid, gen, profile)[target], 0.5), "built tiles pass energy without loss")
	EnergyGrid.distribute(grid, gen, profile, 10.0)
	_check(is_equal_approx(grid.get_tile(target).energy, 5.0), "distribute delivers the arriving share")
	_check(EnergyProfiles.base(Biome.Type.MOUNTAIN).reach() == 3, "mountain reach 3")

	# Drawing energy.
	var draw := Island.create_starter(3)
	var t := Vector2i(-1, 0)
	draw.place_tower(t, &"attack")
	draw.get_tile(t).energy = 1.0
	_check(EnergyGrid.draw_energy(draw, t, 0.5) == 1.0, "paid from own tile")
	draw.get_tile(t).energy = 0.0
	_check(EnergyGrid.draw_energy(draw, t, 1.0) == 0.0, "empty neutral tile stops the tower")
	draw.set_biome(t, Biome.Type.FOREST)
	_check(EnergyGrid.draw_energy(draw, t, 1.0) == EnergyGrid.FOREST_SLOW_EFFICIENCY, "empty forest keeps working slower")
	draw.set_biome(t, Biome.Type.SWAMP)
	var n := t + Vector2i(-1, 0)
	draw.place_tower(n, &"attack")
	draw.get_tile(n).energy = 5.0
	_check(EnergyGrid.draw_energy(draw, t, 2.0) == 1.0, "swamp drains neighbours")
	_check(is_equal_approx(draw.get_tile(n).energy, 3.0), "drained from neighbour")

	# Forest tiles produce passively for their own tower.
	var forest := Island.create_starter(2)
	forest.set_biome(c, Biome.Type.FOREST)
	forest.place_tower(c, &"attack")
	EnergyGrid._forest_passive(forest, 1.0)
	_check(is_equal_approx(forest.get_tile(c).energy, EnergyGrid.FOREST_PASSIVE), "forest passive energy")

	# Plains conduit evens out storages in reach.
	var plains := Island.create_starter(2)
	plains.set_biome(c, Biome.Type.PLAINS)
	plains.place_tower(c, &"energy")
	plains.place_tower(Vector2i(2, 0), &"attack")
	plains.place_tower(Vector2i(1, 1), &"attack")
	plains.get_tile(Vector2i(2, 0)).energy = 20.0
	EnergyGrid._balance(plains, c, EnergyProfiles.for_tile(plains, c), 100.0)
	_check(plains.get_tile(Vector2i(2, 0)).energy < 20.0 and plains.get_tile(Vector2i(1, 1)).energy > 0.0, "conduit balances storage")

	# Walls buff the max HP of adjacent buildings, more on Mountain.
	var walls := Island.create_starter(2)
	walls.place_tower(Vector2i(1, 0), &"attack")
	walls.place_tower(Vector2i(2, 0), &"wall")
	_check(is_equal_approx(walls.tower_max_hp(Vector2i(1, 0)), 110.0), "wall buffs neighbour hp")
	_check(is_equal_approx(walls.tower_max_hp(Vector2i(2, 0)), 400.0), "wall does not buff itself")
	walls.set_biome(Vector2i(2, 0), Biome.Type.MOUNTAIN)
	_check(is_equal_approx(walls.tower_max_hp(Vector2i(1, 0)), 100.0 * (1.0 + 0.05 + 0.20)), "mountain wall buffs more")
