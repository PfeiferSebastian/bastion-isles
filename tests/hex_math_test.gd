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
	_test_ground_damage()
	_test_healing()
	_test_aura_towers()
	_test_enemy_types()
	_test_fog_of_war()
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
	_check(island.add_tile(Vector2i(3, 0), Biome.Type.LAKE), "biome stone as new tile")
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
	# Forest tiles give no healing aura (their trait is passive energy).
	island.set_biome(Vector2i(2, 0), Biome.Type.FOREST)
	island.tick(10.0)
	_check(is_equal_approx(island.get_tower(c).hp, 75.0), "forest tiles do not heal neighbours")
	# Plains spreads 10% per tier of incoming damage to neighbouring towers.
	var d := Vector2i(-1, 0)
	island.set_biome(d, Biome.Type.PLAINS)
	island.place_tower(d, &"attack")
	island.place_tower(Vector2i(-2, 0), &"attack")
	island.damage_tower(d, 50.0)
	_check(is_equal_approx(island.get_tower(Vector2i(-2, 0)).hp, 95.0), "plains spreads damage to neighbour")
	_check(is_equal_approx(island.get_tower(d).hp, 55.0), "plains keeps the rest")
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
	_check(neutral.damage == 11.0 and neutral.beam_dps == 0.0, "neutral shoots plain projectiles")
	island.set_biome(c, Biome.Type.MOUNTAIN)
	var mountain := AttackProfiles.for_tile(island, c)
	_check(mountain.damage > neutral.damage and mountain.range_hexes > neutral.range_hexes, "mountain shells hit harder and further")
	island.set_tier(c, 3)
	_check(is_equal_approx(AttackProfiles.for_tile(island, c).damage, 54.0), "damage scales with tier")
	island.set_biome(c, Biome.Type.PLAINS)
	var plains := AttackProfiles.for_tile(island, c)
	_check(plains.beam_dps > 0.0 and not plains.has_projectile(), "plains fires a laser")
	island.set_biome(c, Biome.Type.LAKE)
	_check(AttackProfiles.for_tile(island, c).damage == 11.0, "lake attack is a neutral placeholder")


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


func _test_ground_damage() -> void:
	var island := Island.create_starter(2)
	_check(island.get_tile(Island.HQ_COORD).hp == Island.HQ_MAX_HP, "hq starts with full hp")
	var c := Vector2i(2, 0)
	_check(island.get_tile(c).hp == Island.TILE_BASE_HP, "tier 0 tile has ground hp")
	island.set_biome(c, Biome.Type.MOUNTAIN)
	_check(island.tile_max_hp(c) == Island.TILE_BASE_HP + Island.TILE_HP_PER_TIER, "biome tiles are sturdier")
	island.damage_tile(c, 10000.0)
	var tile := island.get_tile(c)
	_check(tile.destroyed and tile.blocks_energy(), "tile at 0 hp becomes wasteland and blocks energy")
	_check(not island.can_place(c), "nothing can be built on wasteland")
	_check(not island.aura_at(Vector2i(1, 0)).has(&"max_hp"), "wasteland gives no aura")
	island.damage_tile(Island.HQ_COORD, 10000.0)
	_check(not island.get_tile(Island.HQ_COORD).destroyed, "hq never turns into wasteland")
	_check(island.has_battle_damage(), "battle damage is tracked")
	island.restore_tiles()
	_check(not tile.destroyed and tile.hp == island.tile_max_hp(c), "end of fight restores the ground")
	_check(not island.has_battle_damage(), "no damage left after restore")


func _test_healing() -> void:
	var island := Island.create_starter(2)
	var a := Vector2i(1, 0)
	var b := Vector2i(-1, 0)
	island.place_tower(a, &"attack")
	island.place_tower(b, &"attack")
	island.damage_tower(a, 30.0)
	island.damage_tower(b, 60.0)
	island.damage_tile(Vector2i(0, 1), 30.0)
	var damaged := island.damaged_in_reach(Island.HQ_COORD, 1)
	_check(damaged.size() == 3, "finds damaged towers and ground in reach")
	_check(damaged[0].coord == b and damaged[0].tower, "weakest target comes first")
	_check(is_equal_approx(island.heal(b, true, 25.0), 25.0), "heal restores hp")
	_check(is_equal_approx(island.heal(a, true, 1000.0), 30.0), "heal stops at max hp")
	# Heal over time spreads the amount.
	island.add_heal_over_time(b, true, 10.0, 2.0)
	island.tick(1.0)
	_check(is_equal_approx(island.get_tower(b).hp, 70.0), "heal over time half way")
	island.tick(5.0)
	_check(is_equal_approx(island.get_tower(b).hp, 75.0), "heal over time complete")
	# Drain never destroys.
	_check(is_equal_approx(island.drain(a, true, 1000.0), 99.0), "drain stops at 1 hp")
	# Repaired wasteland turns back into ground.
	var w := Vector2i(2, 0)
	island.damage_tile(w, 10000.0)
	island.heal(w, false, Island.TILE_BASE_HP * 0.4)
	_check(island.get_tile(w).destroyed, "partly repaired wasteland stays wasteland")
	island.heal(w, false, Island.TILE_BASE_HP * 0.2)
	_check(not island.get_tile(w).destroyed, "repaired wasteland becomes ground again")
	# Profiles.
	_check(RepairProfiles.base(Biome.Type.NEUTRAL).reach() == 2, "neutral repair reach 2")
	_check(RepairProfiles.base(Biome.Type.FOREST).mode == &"over_time", "forest heals over time")
	_check(RepairProfiles.base(Biome.Type.PLAINS).mode == &"redistribute", "plains redistributes")
	_check(RepairProfiles.base(Biome.Type.SWAMP).mode == &"lifesteal", "swamp drains enemies")


func _test_aura_towers() -> void:
	var island := Island.create_starter(2)
	var aura := Vector2i(1, 0)
	var neighbour := Vector2i(2, 0)
	var far := Vector2i(-2, 0)
	island.place_tower(aura, &"aura")
	island.place_tower(neighbour, &"attack")
	island.place_tower(far, &"attack")
	var plain_damage := AttackProfiles.for_tile(island, neighbour).damage
	_check(island.get_tower(aura).aura_power == 0.0, "aura starts unpowered")
	island.get_tile(aura).energy = 20.0
	island.tick(0.1)
	_check(island.get_tower(aura).aura_power == 1.0, "aura powered by its tile energy")
	_check(is_equal_approx(AttackProfiles.for_tile(island, neighbour).damage, plain_damage * 1.25), "neutral aura boosts neighbour output 25%")
	_check(is_equal_approx(AttackProfiles.for_tile(island, far).damage, plain_damage), "aura does not reach distance 2")
	# Tile auras inside the radius are boosted.
	island.set_biome(neighbour, Biome.Type.MOUNTAIN)
	_check(is_equal_approx(island.aura_at(neighbour).get(&"max_hp", 0.0), 0.05 * 1.25), "aura tower boosts tile auras in its radius")
	# No chaining: a second aura tower next to the first gets only its own buff.
	var second := Vector2i(1, -1)
	island.place_tower(second, &"aura")
	island.get_tile(second).energy = 20.0
	island.tick(0.1)
	_check(is_equal_approx(island.aura_at(second).get(&"output", 0.0), 0.25), "aura towers receive only their own buff")
	# Mountain aura: armour reduces damage.
	var armor := Island.create_starter(2)
	armor.set_biome(aura, Biome.Type.MOUNTAIN)
	armor.place_tower(aura, &"aura")
	armor.place_tower(neighbour, &"attack")
	armor.get_tile(aura).energy = 20.0
	armor.tick(0.1)
	var hp := armor.get_tower(neighbour).hp
	armor.damage_tower(neighbour, 10.0)
	_check(is_equal_approx(hp - armor.get_tower(neighbour).hp, 9.0), "mountain aura armour reduces damage 10%")
	# Swamp aura buffs no allies.
	var swamp := Island.create_starter(2)
	swamp.set_biome(aura, Biome.Type.SWAMP)
	swamp.place_tower(aura, &"aura")
	swamp.place_tower(neighbour, &"attack")
	swamp.get_tile(aura).energy = 20.0
	swamp.tick(0.1)
	_check(not swamp.aura_at(neighbour).has(&"output"), "swamp aura gives allies nothing")
	_check(AuraProfiles.for_tile(swamp, aura).enemy_weaken > 0.0, "swamp aura weakens enemies")
	# Forest Aura regen also mends the ground.
	var forest := Island.create_starter(2)
	forest.set_biome(Vector2i(1, 0), Biome.Type.FOREST)
	forest.place_tower(Vector2i(1, 0), &"aura")
	forest.get_tile(Vector2i(1, 0)).energy = 30.0
	forest.damage_tile(Vector2i(2, 0), 100.0)
	forest.tick(5.0)
	_check(forest.get_tile(Vector2i(2, 0)).hp > Island.TILE_BASE_HP - 100.0, "forest aura regen mends ground")


func _test_enemy_types() -> void:
	for kind in EnemyDefs.TYPES:
		var enemy := Enemy.new()
		enemy.setup(kind, 1.1)
		_check(enemy.kind == kind and is_equal_approx(enemy.max_hp, EnemyDefs.TYPES[kind].hp * 1.1), "%s setup scales hp" % kind)
		enemy.free()
	var gunboat := Enemy.new()
	gunboat.setup(&"gunboat")
	_check(gunboat.behaviour == &"standoff" and gunboat.weapon_range_hexes > 0.0, "gunboat shoots from range")
	gunboat.add_weaken(0.5)
	_check(is_equal_approx(gunboat.shot_damage(), EnemyDefs.TYPES[&"gunboat"].damage * 0.5), "weaken lowers shot damage")
	gunboat.free()
	var total := 0.0
	for kind in EnemyDefs.WAVE_MIX:
		total += EnemyDefs.WAVE_MIX[kind]
	_check(is_equal_approx(total, 1.0), "wave mix adds up to 100%")


func _test_fog_of_war() -> void:
	var island := Island.create_starter(2)
	var fog := FogOfWar.new(island)
	var outside := Vector2i(5, 0)
	_check(fog.level_at(outside) == FogOfWar.Level.THICK, "sky starts in thick fog")
	_check(fog.is_visible(Vector2i(1, 0)), "own island is always visible")
	_check(fog.is_visible(Vector2i(3, 0)), "hexes next to the island are always visible")
	_check(not fog.is_visible(Vector2i(4, 0)), "two hexes out is fogged")
	fog.reveal_step(outside)
	_check(fog.level_at(outside) == FogOfWar.Level.GREY, "first shot: thick to grey")
	fog.reveal_step(outside)
	_check(fog.level_at(outside) == FogOfWar.Level.OPEN, "second shot: grey to open")
	fog.tick(FogOfWar.OPEN_HOLD + 0.1)
	_check(fog.level_at(outside) == FogOfWar.Level.GREY, "open sky clouds over to grey")
	fog.tick(FogOfWar.GREY_HOLD + 0.1)
	_check(fog.level_at(outside) == FogOfWar.Level.THICK, "grey clouds over to thick")
	# Scouts keep a circle open while powered; biomes change the radius.
	var scout := Vector2i(2, 0)
	island.place_tower(scout, &"scout")
	island.get_tile(scout).energy = 20.0
	fog.tick(0.1)
	_check(fog.is_visible(Vector2i(5, 0)), "scout opens its radius")
	_check(fog.level_at(Vector2i(6, 0)) == FogOfWar.Level.THICK, "beyond scout radius stays thick")
	# Without energy the scout is blind.
	var blind := Island.create_starter(2)
	var blind_fog := FogOfWar.new(blind)
	blind.place_tower(scout, &"scout")
	blind_fog.tick(1.0)
	_check(blind_fog.level_at(Vector2i(4, 0)) == FogOfWar.Level.THICK, "unpowered scout reveals nothing")
	_check(ScoutProfiles.base(Biome.Type.MOUNTAIN).radius > ScoutProfiles.base(Biome.Type.NEUTRAL).radius, "mountain scout sees further")
	_check(ScoutProfiles.base(Biome.Type.FOREST).hold_factor > 1.0, "forest keeps the sky open longer")
