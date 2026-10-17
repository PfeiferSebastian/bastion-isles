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
	_test_economy()
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
	# Biome auras only buff their own tile, scaled by its tier.
	_check(is_equal_approx(island.aura_at(c).get(&"max_hp", 0.0), 0.05), "own mountain aura")
	_check(not island.aura_at(Vector2i(2, 0)).has(&"max_hp"), "biome auras no longer reach neighbours")
	_check(not island.aura_at(Vector2i(-1, 0)).has(&"max_hp"), "aura does not reach distance 2")
	island.set_tier(c, 3)
	_check(is_equal_approx(island.aura_at(c).get(&"max_hp", 0.0), 0.15), "aura scales with tier")
	island.set_biome(Vector2i(2, 0), Biome.Type.MOUNTAIN)
	_check(is_equal_approx(island.aura_at(Vector2i(2, 0)).get(&"max_hp", 0.0), 0.05), "each tile gets only its own aura")
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
	# A different type next door, so the two don't form one combined building.
	island.place_tower(Vector2i(-2, 0), &"warehouse")
	var neighbour_max := island.tower_max_hp(Vector2i(-2, 0))
	island.damage_tower(d, 50.0)
	_check(is_equal_approx(island.get_tower(Vector2i(-2, 0)).hp, neighbour_max - 5.0), "plains spreads damage to neighbour")
	_check(is_equal_approx(island.get_tower(d).hp, 55.0), "plains keeps the rest")
	# Neighbouring towers of one type share one HP pool and fall together.
	var group_island := Island.create_starter(2)
	group_island.place_tower(Vector2i(1, 0), &"attack")
	group_island.place_tower(Vector2i(2, 0), &"attack")
	group_island.damage_tower(Vector2i(1, 0), 50.0)
	_check(is_equal_approx(group_island.get_tower(Vector2i(2, 0)).hp, 75.0), "combined buildings share damage")
	group_island.damage_tower(Vector2i(2, 0), 149.0)
	_check(group_island.get_tower(Vector2i(1, 0)) != null, "combined building stands while the pool lasts")
	group_island.damage_tower(Vector2i(1, 0), 2.0)
	_check(group_island.get_tower(Vector2i(1, 0)) == null and group_island.get_tower(Vector2i(2, 0)) == null, "combined building falls together")
	# Combined buildings work 30% better per tower.
	group_island.place_tower(Vector2i(1, 0), &"attack")
	var alone := AttackProfiles.for_tile(group_island, Vector2i(1, 0)).damage
	group_island.place_tower(Vector2i(2, 0), &"attack")
	_check(is_equal_approx(AttackProfiles.for_tile(group_island, Vector2i(1, 0)).damage, alone * 1.3), "combined buildings deal 30% more")
	# Walls: at most 3 in one section; one more next to it stays on its own.
	var walls := Island.create_starter(3)
	for x in [1, 2, 3]:
		walls.place_tower(Vector2i(x, 0), &"wall")
	_check(walls.get_tower(Vector2i(3, 0)) != null, "three walls in a row")
	var extra_wall := walls.place_tower(Vector2i(3, -1), &"wall")
	_check(extra_wall != null and extra_wall.solo and walls.cluster_towers(Vector2i(1, 0)) == 3, "a fourth wall next to a section stays a single wall")
	_check(walls.place_tower(Vector2i(-2, 0), &"wall") != null, "a separate wall section is fine")
	# No XP once the mission is won (combat switches it off), nor while editing.
	walls.gains_xp = false
	walls.add_xp(Vector2i(1, 0), 500.0)
	_check(walls.get_tower(Vector2i(1, 0)).xp == 0.0, "no xp while switched off")
	# Experience: exponential levels, +1% per level, shared in combined buildings.
	_check(Tower.level_for_xp(0.0) == 0 and Tower.level_for_xp(Tower.xp_for_level(10)) == 10, "xp levels round trip")
	_check(Tower.xp_for_level(10) > 200.0 and Tower.xp_for_level(10) < 400.0, "level 10 takes hundreds of xp")
	_check(Tower.xp_for_level(50) > 2000.0, "level 50 takes thousands of xp")
	_check(Tower.level_for_xp(1.0e9) == Tower.MAX_LEVEL, "max level 100")
	var xp_island := Island.create_starter(2)
	var xc := Vector2i(1, 0)
	xp_island.set_biome(xc, Biome.Type.FOREST)
	xp_island.place_tower(xc, &"attack")
	xp_island.add_xp(xc, Tower.xp_for_level(11))
	xp_island.tick(0.01)
	_check(xp_island.get_tower(xc).level() == 11, "xp raises the level")
	_check(is_equal_approx(xp_island.effect_bonus(xc), 1.11), "level 11 gives +11% stats")
	var veteran := Tower.new(&"attack", 100.0)
	veteran.xp = Tower.xp_for_level(100)
	_check(is_equal_approx(veteran.stat_factor(), 2.0) and veteran.perk_points() == 10, "level 100: +100% stats and 10 perk points")
	var up_island := Island.create_starter(2)
	var up := Vector2i(1, 0)
	up_island.set_biome(up, Biome.Type.MOUNTAIN)
	up_island.place_tower(up, &"attack", 100)
	var cost := up_island.tier_up_cost(up)
	_check(cost.resource == Biome.Type.MOUNTAIN and cost.gold > 0 and cost.amount > 0, "tier upgrade costs gold and the biome's resource")
	_check(not up_island.upgrade_tower(up), "no upgrade without resources")
	up_island.treasury.add_gold(cost.gold)
	up_island.treasury.add_resource(Biome.Type.MOUNTAIN, cost.amount)
	_check(up_island.upgrade_tower(up), "upgrade when paid")
	var upgraded := up_island.get_tower(up)
	_check(upgraded.tier == 2 and upgraded.level() == 0 and is_equal_approx(upgraded.stat_factor(), 2.5), "tier 2 keeps +100% and adds +50%")
	_check(upgraded.perk_points() == 10, "perk points are kept through the tier jump")
	# Merging: n touching towers of tier n become one n-hex tower.
	var m_island := Island.create_starter(2)
	var ma := Vector2i(1, 0)
	var mb := Vector2i(2, 0)
	var mc := Vector2i(2, -1)
	for hex in [ma, mb, mc]:
		m_island.set_biome(hex, Biome.Type.MOUNTAIN)
	m_island.place_tower(ma, &"attack", 0, 1)
	m_island.place_tower(mb, &"attack", 0, 1)
	_check(m_island.merge_set(ma).is_empty(), "tier 1 towers can't merge")
	m_island.get_tower(ma).tier = 2
	m_island.get_tower(mb).tier = 2
	m_island.get_tower(mb).xp = 500.0
	var single_damage := AttackProfiles.for_tile(m_island, ma).damage
	_check(m_island.merge_set(ma).size() == 2 and m_island.merge(ma), "two tier 2 towers merge")
	_check(m_island.get_tower(ma).size() == 2 and m_island.get_tower(mb).is_part, "one 2-hex tower")
	_check(m_island.get_tower(ma).level() == 0 and m_island.get_tower(ma).tier == 2, "merged tower keeps its tier, level 0")
	_check(m_island.get_tile(ma).tier == 2 and m_island.get_tile(mb).tier == 2, "merged tower lifts its tiles to its tier")
	_check(not m_island.acts(mb) and m_island.acts(ma), "only the root acts")
	_check(AttackProfiles.for_tile(m_island, ma).damage > single_damage * 2.0 * 0.99, "a 2-hex tower has twice the effect")
	m_island.get_tower(ma).tier = 3
	m_island.get_tower(mb).tier = 3
	m_island.place_tower(mc, &"attack", 0, 3)
	_check(m_island.merge(mc) and m_island.get_tower(ma).size() == 3, "a merged tower grows with one more of its tier")
	_check(m_island.cluster_towers(ma) == 1, "a merged tower counts as one in its cluster")
	var m_loaded := Island.from_dict(JSON.parse_string(JSON.stringify(m_island.to_dict())))
	_check(m_loaded.get_tower(ma).size() == 3 and m_loaded.get_tower(mc).is_part, "merged towers survive saving")
	# Clusters: at most 3 towers of one type together.
	var c_island := Island.create_starter(3)
	for x in [1, 2, 3]:
		c_island.place_tower(Vector2i(x, 0), &"energy")
	var fourth := c_island.place_tower(Vector2i(3, -1), &"energy")
	_check(fourth != null and fourth.solo, "a fourth tower next to a full cluster stays a single unit")
	_check(c_island.cluster_towers(Vector2i(1, 0)) == 3 and c_island.group_of(Vector2i(3, -1)).size() == 1, "the full cluster doesn't grow")
	var c_loaded := Island.from_dict(JSON.parse_string(JSON.stringify(c_island.to_dict())))
	_check(c_loaded.get_tower(Vector2i(3, -1)).solo and c_loaded.cluster_towers(Vector2i(1, 0)) == 3, "solo towers survive saving")
	c_island.remove_tower(Vector2i(1, 0))
	_check(not fourth.solo and c_island.cluster_towers(Vector2i(3, 0)) == 3, "a solo tower joins once the cluster has room")
	# Range: +0.1% per level.
	var ranger := Tower.new(&"attack", 100.0)
	ranger.xp = Tower.xp_for_level(100)
	_check(is_equal_approx(ranger.range_factor(), 1.1), "range +10% at level 100")
	# Blueprints are a currency: towers and tiles are bought with them.
	var shop := Island.create_starter(1)
	shop.treasury.add_blueprint(3)
	_check(shop.blueprint_cost(&"aura") == 0 and shop.blueprint_cost(&"repair") == 1, "price grows with the towers owned")
	_check(shop.affordable_count(&"aura") == 3 and shop.affordable_count(&"repair") == 2, "3 blueprints buy 3 auras (0+1+2) or 2 repairs (1+2)")
	_check(shop.ensure_item(Inventory.tower_item(&"aura")) and shop.treasury.blueprints == 3, "the first aura tower is free")
	_check(shop.blueprint_cost(&"aura") == 1, "the next aura costs 1")
	_check(not shop.ensure_item(Inventory.tower_item(&"repair", 5)), "levelled towers can't be bought")
	_check(shop.ensure_item(Inventory.tower_item(&"aura")), "an aura in stock needs no purchase")
	_check(not shop.can_get(Inventory.stone_item(Biome.Type.FOREST)), "biome stones can't be bought")
	# Defeat: half of gold, blueprints and faction resources are lost (rounded up).
	var loser := Island.create_starter(1)
	loser.treasury.gold = 101
	loser.treasury.blueprints = 5
	loser.treasury.add_resource(Biome.Type.FOREST, 4)
	var lost := loser.lose_resources()
	_check(lost.gold == 51 and loser.treasury.gold == 50, "defeat costs half the gold")
	_check(lost.blueprints == 3 and loser.treasury.blueprints == 2, "defeat costs half the blueprints")
	_check(lost.resources[Biome.Type.FOREST] == 2 and loser.treasury.resources[Biome.Type.FOREST] == 2, "defeat costs half of every resource")
	# Fleeing rebuilds what this mission destroyed: towers at level 0, biome tiles at Tier 1.
	var fled := Island.create_starter(2)
	fled.set_biome(Vector2i(1, 0), Biome.Type.MOUNTAIN)
	fled.set_tier(Vector2i(1, 0), 3)
	fled.place_tower(Vector2i(1, 0), &"attack", 40, 2)
	fled.damage_tower(Vector2i(1, 0), 100000.0)
	fled.damage_tile(Vector2i(1, 0), 100000.0)
	_check(fled.get_tower(Vector2i(1, 0)) == null and fled.get_tile(Vector2i(1, 0)).destroyed, "tower and ground destroyed")
	_check(fled.rebuild_losses() == 1, "one tower rebuilt")
	var back := fled.get_tower(Vector2i(1, 0))
	_check(back != null and back.tier == 2 and back.level() == 0, "rebuilt at its tier, level 0")
	_check(not fled.get_tile(Vector2i(1, 0)).destroyed and fled.get_tile(Vector2i(1, 0)).tier == 1 and fled.get_tile(Vector2i(1, 0)).biome == Biome.Type.MOUNTAIN, "wasteland biome back at Tier 1")
	# Analysis counters and the battle log.
	var track_island := Island.create_starter(1)
	track_island.place_tower(Vector2i(1, 0), &"attack")
	track_island.track(Vector2i(1, 0), &"damage", 12.0)
	_check(track_island.get_tower(Vector2i(1, 0)).wave_stats[&"damage"] == 12.0 and track_island.wave_totals[&"attack"][&"damage"] == 12.0, "damage is tracked per tower and type")
	track_island.start_wave_stats()
	_check(track_island.get_tower(Vector2i(1, 0)).wave_stats.is_empty() and track_island.get_tower(Vector2i(1, 0)).mission_stats[&"damage"] == 12.0, "a new wave resets only the wave counters")
	BattleLog.path = "user://test_battle_log.jsonl"
	for i in BattleLog.MAX_WAVES + 5:
		BattleLog.append({wave = i})
	_check(BattleLog.count() == BattleLog.MAX_WAVES and int(BattleLog.entries()[0].wave) == 5, "the battle log keeps the last 100 waves")
	DirAccess.remove_absolute(BattleLog.path)
	BattleLog.path = "user://battle_log.jsonl"
	# Bad luck protection: only for blueprints, resets when one drops.
	var luck := Treasury.new()
	luck.pity = 0.5
	luck.add_blueprint()
	_check(luck.pity == 0.0 and luck.blueprints == 1, "a found blueprint resets the protection")
	var luck_enemy := Enemy.new()
	luck_enemy.setup(&"rammer")
	_check(Economy.blueprint_chance(luck_enemy, 0.1) > Economy.blueprint_chance(luck_enemy), "the protection raises the blueprint chance")
	_check(is_equal_approx(Economy.stone_chance(luck_enemy), Economy.STONE_DROP_CHANCE * EnemyDefs.DROP_FACTOR[&"rammer"]), "rare drops get no protection")
	luck_enemy.free()
	_check(xp_island.get_tile(xc).tier == 1, "levels no longer raise the ground")
	xp_island.place_tower(Vector2i(2, 0), &"attack")
	xp_island.tick(0.01)
	_check(is_equal_approx(xp_island.get_tower(Vector2i(2, 0)).xp, xp_island.get_tower(xc).xp), "combined buildings split their xp")
	# Lake shield absorbs damage first.
	var p := Vector2i(0, 2)
	island.set_biome(p, Biome.Type.LAKE)
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
	_check(neutral.damage == 10.0 and neutral.cooldown == 1.0 and neutral.energy_per_shot == 1.0 and neutral.beam_dps == 0.0, "neutral cannon: the normalised baseline")
	island.set_biome(c, Biome.Type.MOUNTAIN)
	var mountain := AttackProfiles.for_tile(island, c)
	_check(mountain.range_hexes == 4.0 and mountain.cooldown == 0.25 and is_equal_approx(mountain.sustained_dps(), 12.5), "machine cannon: range 4, 4 shots/s, 12.5 dps")
	_check(is_equal_approx(mountain.energy_per_shot / mountain.cooldown, 1.0), "machine cannon energy: shorter range × fast bullets")
	_check(neutral.range_hexes == AttackProfiles.BASE_RANGE + 1.0, "neutral ground adds a hex of range")
	island.set_tier(c, 3)
	_check(is_equal_approx(AttackProfiles.for_tile(island, c).damage, mountain.damage * 1.5), "damage scales with tier")
	island.set_biome(c, Biome.Type.PLAINS)
	var plains := AttackProfiles.for_tile(island, c)
	_check(plains.beam_dps > 0.0 and not plains.has_projectile(), "plains fires a laser")
	island.set_biome(c, Biome.Type.LAKE)
	var lake := AttackProfiles.for_tile(island, c)
	_check(lake.beam_dps > 0.0 and lake.attack_slow > 0.0 and lake.range_hexes == 3.0, "lake: short slowing water jet")
	_check(plains.range_hexes == 6.5 and plains.beam_energy > 2.0 and plains.armor_pen > 0.0, "plains: long range, energy-hungry, armour piercing")
	var forest_p := AttackProfiles.base(Biome.Type.FOREST)
	_check(is_equal_approx(forest_p.damage / forest_p.cooldown, 3.0) and is_equal_approx(forest_p.sustained_dps(), 10.0), "forest: 30% direct, 70% thorns")
	# Shooting past the core range loses 25% per hex, down to a floor.
	_check(neutral.performance(neutral.range_hexes) == 1.0 and is_equal_approx(neutral.performance(neutral.range_hexes + 2.0), 0.5), "falloff 25% per hex")
	_check(is_equal_approx(neutral.performance(neutral.range_hexes + 4.0), AttackProfile.MIN_EFFECT), "plain towers keep 5%")
	var far := forest_p.performance(forest_p.range_hexes + 4.0) * forest_p.damage / forest_p.cooldown
	_check(is_equal_approx(far, 0.05 * forest_p.sustained_dps()), "towers with extra effects keep 5% of their full worth")


func _test_enemy_statuses() -> void:
	var enemy := Enemy.new()
	enemy.take_damage(10.0)
	_check(is_equal_approx(enemy.hp, 50.0), "enemy takes damage")
	enemy.add_dot(2.0, 3.0)
	enemy.add_dot(1.0, 3.0)
	_check(enemy.dot_stacks() == 2, "damage over time stacks")
	enemy.tick_statuses(1.0)
	_check(is_equal_approx(enemy.hp, 47.0), "stacks tick every 0.2 s, ignoring armour")
	var armoured := Enemy.new()
	armoured.setup(&"bomber")
	armoured.take_damage(10.0)
	armoured.take_damage(10.0, 0.3)
	_check(is_equal_approx(armoured.hp, armoured.max_hp - 7.0 - 10.0), "armour shrugs off damage, piercing ignores it")
	for i in 100:
		armoured.add_weaken_stack(0.01)
	_check(armoured.weaken() > 0.5 and armoured.weaken() < Enemy.WEAKEN_MAX, "weaken stacks, slowing down past 50%, capped at 75%")
	armoured.add_attack_slow(0.25, 2.0)
	_check(is_equal_approx(armoured.reload_time(), armoured.weapon_cooldown / 0.75), "attack slow lengthens reloads")
	armoured.free()
	enemy.hp = 44.0
	enemy.add_weaken(0.4)
	_check(is_equal_approx(enemy.damage_output(), enemy.dps * 0.6), "weaken lowers enemy damage")
	enemy.take_damage(10.0)
	_check(is_equal_approx(enemy.hp, 44.0 - 12.0), "weakened enemy takes extra damage")
	enemy.take_damage(1000.0)
	_check(enemy.is_dead, "enemy dies")


func _test_energy() -> void:
	var island := Island.create_starter(3)
	var c := Vector2i(1, 0)
	_check(is_equal_approx(EnergyGrid.capacity(island.get_tile(c)), 18.0), "every tile stores pipe rate × 3")
	_check(is_equal_approx(EnergyGrid.pipe_rate(island.get_tile(c)), 12.0), "empty ground is a power line (twice the rate)")
	island.place_tower(c, &"attack")
	_check(is_equal_approx(EnergyGrid.pipe_rate(island.get_tile(c)), 6.0), "built tiles pass 6/s per pipe")
	island.set_biome(c, Biome.Type.MOUNTAIN)
	island.get_tile(c).tier = 3
	_check(is_equal_approx(EnergyGrid.capacity(island.get_tile(c)), 21.0), "higher tiers store and pass more")
	_check(EnergyGrid.entry_pipes(island, c) == 3, "buildings take energy in through one pipe per tier")
	_check(EnergyGrid.upkeep(&"attack") == EnergyGrid.UPKEEP and EnergyGrid.upkeep(&"energy") == 0.0, "every building but generators pays upkeep")

	# A generator feeds a turret through an empty tile: nothing lost, one pipe at Tier 0–1.
	var line := Island.create_starter(3)
	var gen := Vector2i(1, 0)
	var mid := Vector2i(2, 0)
	var target := Vector2i(3, 0)
	line.place_tower(gen, &"energy")
	line.place_tower(target, &"attack")
	_check(is_equal_approx(EnergyGrid.generator_at(line, gen).output, 6.0), "neutral generator makes 6/s")
	_check(EnergyGrid.generator_at(line, Island.HQ_COORD) == null, "the HQ is a hub and makes nothing")
	for i in 30:
		EnergyGrid.step(line, EnergyGrid.TICK)
	_check(line.get_tile(target).energy > 0.0, "energy reaches the turret along the road")
	_check(line.get_tile(mid).energy <= EnergyGrid.capacity(line.get_tile(mid)), "road tile stays within its store")
	# Fixed ticks: one long frame and many short ones move the same energy.
	var a := Island.create_starter(2)
	var b := Island.create_starter(2)
	for isl in [a, b]:
		isl.place_tower(Vector2i(1, 0), &"energy")
		isl.place_tower(Vector2i(2, 0), &"attack")
	EnergyGrid.tick(a, 0.5)
	for i in 50:
		EnergyGrid.tick(b, 0.01)
	_check(is_equal_approx(a.get_tile(Vector2i(2, 0)).energy, b.get_tile(Vector2i(2, 0)).energy), "grid runs in fixed ticks")
	# Urgency: the emptier, hungrier building is served first.
	var fork := Island.create_starter(2)
	fork.place_tower(Vector2i(0, 1), &"energy")
	fork.place_tower(Vector2i(1, 1), &"attack")
	fork.place_tower(Vector2i(-1, 2), &"scout")
	fork.get_tile(Vector2i(1, 1)).energy = 0.0
	fork.get_tile(Vector2i(-1, 2)).energy = 0.0
	# The generator's single pipe takes turns by demand: the turret (weight 2) gets more turns.
	for i in 9:
		EnergyGrid.step(fork, EnergyGrid.TICK)
	_check(fork.get_tile(Vector2i(1, 1)).energy > fork.get_tile(Vector2i(-1, 2)).energy * 1.5, "turret outranks scout")
	_check(fork.get_tile(Vector2i(-1, 2)).energy > 0.0, "scout still gets its turns")
	# A full building on the road passes energy through to the one behind it without giving
	# up its own store.
	var chain := Island.create_starter(3)
	chain.place_tower(Vector2i(1, 0), &"energy")
	chain.place_tower(Vector2i(2, 0), &"wall")
	chain.place_tower(Vector2i(3, 0), &"attack")
	var wall := chain.get_tile(Vector2i(2, 0))
	wall.energy = EnergyGrid.capacity(wall)
	chain.get_tile(Vector2i(3, 0)).energy = 0.0
	for i in 10:
		EnergyGrid.step(chain, EnergyGrid.TICK)
	_check(chain.get_tile(Vector2i(3, 0)).energy > 0.0, "energy passes through a full building")
	_check(wall.energy >= EnergyGrid.capacity(wall) - EnergyGrid.UPKEEP * 1.0 - 0.01, "the building keeps its own store")
	# Overflow: a generator with no one to feed fills its store, spills to side tiles, then wastes.
	var full := Island.create_starter(1)
	full.place_tower(Vector2i(1, 0), &"energy")
	for i in 200:
		EnergyGrid.step(full, EnergyGrid.TICK)
	var side := full.get_tile(Vector2i(1, -1))
	_check(side.energy > 0.0, "spill fills side tiles")
	_check(full.get_tower(Vector2i(1, 0)).wave_stats.get(&"wasted", 0.0) > 0.0, "spill past full stores is wasted")
	# Storehouses hand their energy to buildings next to them.
	var store_island := Island.create_starter(2)
	var store := Vector2i(1, 0)
	var user := Vector2i(2, 0)
	store_island.place_tower(store, &"warehouse")
	_check(is_equal_approx(EnergyGrid.capacity(store_island.get_tile(store)), EnergyGrid.STORAGE_CAPACITY), "storehouse is a capacitor")
	store_island.get_tile(store).energy = EnergyGrid.STORAGE_CAPACITY
	store_island.place_tower(user, &"attack")
	store_island.get_tile(user).energy = 0.0
	EnergyGrid.step(store_island, EnergyGrid.TICK)
	_check(store_island.get_tile(user).energy > 0.0, "storehouse hands energy to buildings that need it")
	# Upkeep drains an unconnected building.
	var lonely := Island.create_starter(2)
	lonely.place_tower(c, &"wall")
	lonely.get_tile(c).energy = 5.0
	EnergyGrid.tick(lonely, 1.0)
	_check(is_equal_approx(lonely.get_tile(c).energy, 5.0 - EnergyGrid.UPKEEP), "upkeep is paid every second")

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

	# Swamp tiles produce passively for their own tower.
	var marsh := Island.create_starter(2)
	marsh.set_biome(c, Biome.Type.SWAMP)
	marsh.place_tower(c, &"attack")
	EnergyGrid._swamp_passive(marsh, 1.0)
	_check(is_equal_approx(marsh.get_tile(c).energy, EnergyGrid.SWAMP_PASSIVE), "swamp passive energy")
	# Forest tiles make repairs on them stronger, neutral attack towers reach further.
	var grove := Island.create_starter(2)
	grove.set_biome(c, Biome.Type.FOREST)
	grove.place_tower(c, &"attack")
	grove.damage_tower(c, 50.0)
	_check(is_equal_approx(grove.heal(c, true, 20.0), 21.0), "forest gives +5% healing received")
	_check(is_equal_approx(AttackProfiles.base(Biome.Type.NEUTRAL).range_hexes, AttackProfiles.BASE_RANGE + 1.0), "neutral attack reaches 1 hex further")

	# Walls buff the max HP of adjacent buildings, more on Mountain.
	var walls := Island.create_starter(2)
	walls.place_tower(Vector2i(1, 0), &"attack")
	walls.place_tower(Vector2i(2, 0), &"wall")
	_check(is_equal_approx(walls.tower_max_hp(Vector2i(1, 0)), 110.0), "wall buffs neighbour hp")
	_check(is_equal_approx(walls.tower_max_hp(Vector2i(2, 0)), 400.0), "wall does not buff itself")
	walls.set_biome(Vector2i(2, 0), Biome.Type.MOUNTAIN)
	_check(is_equal_approx(walls.tower_max_hp(Vector2i(1, 0)), 100.0 * (1.0 + 0.20)), "mountain wall buffs more")


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
	# The HQ takes the most common biome; ties go to faction biomes, then tiers, then the current one.
	var hq_island := Island.create_starter(1)
	_check(hq_island.hq_biome() == Biome.Type.NEUTRAL, "a fresh island's HQ is neutral")
	for c in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		hq_island.set_biome(c, Biome.Type.SWAMP)
	_check(hq_island.hq_biome() == Biome.Type.SWAMP, "3 swamp vs 3 neutral: the faction biome wins")
	hq_island.set_biome(Vector2i(0, -1), Biome.Type.FOREST)
	hq_island.set_biome(Vector2i(1, -1), Biome.Type.FOREST)
	hq_island.set_biome(Vector2i(-1, 1), Biome.Type.FOREST)
	_check(hq_island.hq_biome() == Biome.Type.SWAMP, "3 swamp vs 3 forest: the HQ keeps its biome")
	hq_island.set_tier(Vector2i(0, -1), 2)
	_check(hq_island.hq_biome() == Biome.Type.FOREST, "on a tie the higher tiers win")
	_check(hq_island.get_tile(Island.HQ_COORD).biome == Biome.Type.NEUTRAL, "the HQ tile stays neutral ground")
	# Heal over time spreads the amount.
	island.add_heal_over_time(b, true, 10.0, 2.0)
	_check(island.has_heal_over_time(b, true) and not island.has_heal_over_time(b, false) and not island.has_heal_over_time(a, true), "heal over time is known per target")
	island.tick(1.0)
	_check(is_equal_approx(island.get_tower(b).hp, 70.0), "heal over time half way")
	island.tick(5.0)
	_check(is_equal_approx(island.get_tower(b).hp, 75.0), "heal over time complete")
	_check(not island.has_heal_over_time(b, true), "a finished heal over time frees the target")
	# Drain never destroys.
	_check(is_equal_approx(island.drain(a, true, 1000.0), 99.0), "drain stops at 1 hp")
	# Repaired wasteland turns back into ground.
	var w := Vector2i(2, 0)
	island.damage_tile(w, 10000.0)
	island.heal(w, false, Island.TILE_BASE_HP * 0.4)
	_check(island.get_tile(w).destroyed, "partly repaired wasteland stays wasteland")
	island.heal(w, false, Island.TILE_BASE_HP * 0.2)
	_check(not island.get_tile(w).destroyed, "repaired wasteland becomes ground again")
	# Edit mode: everything full, heals over time dropped.
	var edit := Island.create_starter(2)
	var t := Vector2i(1, 0)
	edit.place_tower(t, &"attack")
	edit.damage_tower(t, 40.0)
	edit.damage_tile(Vector2i(-1, 0), 10000.0)
	edit.damage_tile(Island.HQ_COORD, 500.0)
	edit.get_tile(t).energy = 0.0
	edit.add_heal_over_time(t, true, 10.0, 2.0)
	edit.fill_up()
	_check(is_equal_approx(edit.health_ratio(t, true), 1.0) and is_equal_approx(edit.health_ratio(Island.HQ_COORD, false), 1.0), "edit mode repairs towers and the HQ")
	_check(not edit.get_tile(Vector2i(-1, 0)).destroyed and is_equal_approx(edit.health_ratio(Vector2i(-1, 0), false), 1.0), "edit mode restores wasteland")
	_check(is_equal_approx(edit.get_tile(t).energy, EnergyGrid.capacity(edit.get_tile(t))), "edit mode fills every storage")
	_check(not edit.has_heal_over_time(t, true), "edit mode drops heals over time")
	# Profiles.
	_check(RepairProfiles.base(Biome.Type.NEUTRAL).reach() == 6 and is_equal_approx(RepairProfiles.base(Biome.Type.NEUTRAL).falloff[6], 0.5), "repair reach 6, half the heal at the edge")
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
	_check(is_equal_approx(AttackProfiles.for_tile(island, far).damage, plain_damage), "aura does not reach distance 3")
	# Tile auras inside the radius are boosted.
	island.set_biome(neighbour, Biome.Type.MOUNTAIN)
	_check(is_equal_approx(island.aura_at(neighbour).get(&"max_hp", 0.0), 0.05 * 1.2), "aura tower boosts tile auras in its radius by 20%")
	# No chaining: a second aura tower next to the first gets only its own buff.
	var second := Vector2i(1, -1)
	island.place_tower(second, &"aura")
	island.get_tile(second).energy = 20.0
	island.tick(0.1)
	# The two touch, so they form a combined building (+30%), but still don't stack.
	_check(is_equal_approx(island.aura_at(second).get(&"output", 0.0), 0.25 * (1.0 + Island.MERGE_BONUS)), "aura towers receive only their own buff")
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


func _test_economy() -> void:
	var t := Treasury.new(100)
	_check(t.spend_gold(60) and t.gold == 40, "spend gold")
	_check(not t.spend_gold(50) and t.gold == 40, "cannot overspend gold")
	# Blueprints are a currency; found ones are saved at once, as are towers bought with them.
	var bp_island := Island.create_starter(1)
	IslandSave.path = "user://test_island.json"
	IslandSave.blueprint_path = "user://test_blueprints.json"
	bp_island.persist_blueprints = true
	bp_island.add_blueprint()
	bp_island.add_blueprint()
	_check(bp_island.ensure_item(Inventory.tower_item(&"scout")) and bp_island.treasury.blueprints == 2, "the first scout is free")
	bp_island.place_tower(Vector2i(1, 0), &"warehouse")
	_check(bp_island.ensure_item(Inventory.tower_item(&"warehouse")) and bp_island.treasury.blueprints == 1, "buy a second warehouse for 1 blueprint")
	var reloaded := IslandSave.load_island(1)
	_check(reloaded.treasury.blueprints == 1, "blueprints survive without an island save")
	_check(reloaded.treasury.inventory.count(Inventory.tower_item(&"scout")) == 1, "towers bought with blueprints survive without an island save")
	_check(IslandSave.load_island(1).treasury.inventory.count(Inventory.tower_item(&"scout")) == 1, "and are handed out only once")
	# Tower XP from a mission survives closing the game without an island save.
	IslandSave.xp_path = "user://test_tower_xp.json"
	var xp_island := IslandSave.load_island(1)
	xp_island.place_tower(Vector2i(0, 1), &"attack")
	IslandSave.save(xp_island)
	xp_island.get_tower(Vector2i(0, 1)).xp = 500.0
	IslandSave.save_tower_xp(xp_island)
	_check(is_equal_approx(IslandSave.load_island(1).get_tower(Vector2i(0, 1)).xp, 500.0), "tower XP survives closing the game")
	IslandSave.save(xp_island)
	_check(not FileAccess.file_exists(IslandSave.xp_path), "an island save replaces the kept XP")
	DirAccess.remove_absolute(IslandSave.path)
	DirAccess.remove_absolute(IslandSave.blueprint_path)
	IslandSave.path = "user://island.json"
	IslandSave.blueprint_path = "user://blueprints.json"
	IslandSave.xp_path = "user://tower_xp.json"
	var inv := Inventory.new()
	inv.add(Inventory.tower_item(&"wall", 1), 2)
	inv.add(Inventory.tower_item(&"wall", 3))
	_check(inv.tower_stacks(&"wall") == [Vector2i(1, 1), Vector2i(3, 1)], "towers stack per level")
	inv.add(Inventory.tower_item(&"wall", 5, 2))
	_check(inv.tower_stacks(&"wall").back() == Vector2i(5, 2) and inv.tower_count(&"wall") == 4, "tiers stack apart")
	_check(inv.take(Inventory.tower_item(&"wall", 1)) and inv.count(Inventory.tower_item(&"wall", 1)) == 1, "take one from a stack")
	_check(not inv.take(Inventory.stone_item(Biome.Type.FOREST)), "no forest stone yet")
	var island := Island.create_starter(2)
	_check(island.treasury.gold == Economy.STARTING_GOLD, "island starts with gold")
	for type in [&"attack", &"wall", &"energy", &"repair"]:
		_check(island.treasury.inventory.count(Inventory.tower_item(type)) == 1, "island starts with one %s" % type)
	for biome in Biome.Type.values():
		var hq_weapon := HqWeapons.profile(biome)
		_check(hq_weapon.range_hexes == 10.0 and hq_weapon.energy_per_shot == 0.0 and hq_weapon.beam_energy == 0.0, "hq weapon %d: 10 hexes, no energy" % biome)
		# Damage plus healing and effects (the siphon's heal is its effect) add up to one budget.
		_check(is_equal_approx(HqWeapons.dps(biome) + hq_weapon.effect_dps + (hq_weapon.damage / hq_weapon.cooldown if biome == Biome.Type.FOREST else 0.0), HqWeapons.BUDGET), "hq weapon %d keeps the budget" % biome)
	# Loot: always gold; stronger enemies drop biome stones more often.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var weak := Enemy.new()
	weak.setup(&"rammer")
	var strong := Enemy.new()
	strong.setup(&"bomber", 6.0)
	_check(Economy.roll_loot(weak, rng).gold == 1, "light enemy gives 1 gold")
	_check(is_equal_approx(Economy.stone_chance(weak), 0.001 * EnemyDefs.DROP_FACTOR[&"rammer"]), "biome stones are very rare")
	# Biome stones cost their faction resource: 1 for the first tile of that biome, then 2, 3 …
	var biomes := Island.create_starter(1)
	var forest := Inventory.stone_item(Biome.Type.FOREST)
	_check(biomes.biome_cost(Biome.Type.FOREST) == 1 and not biomes.can_get(forest), "the first forest costs 1 wood")
	biomes.treasury.add_resource(Biome.Type.FOREST, 3)
	_check(biomes.ensure_item(forest) and biomes.treasury.resources[Biome.Type.FOREST] == 2, "buy a forest stone for 1 wood")
	biomes.set_biome(Vector2i(1, 0), Biome.Type.FOREST)
	biomes.treasury.inventory.take(forest)
	_check(biomes.biome_cost(Biome.Type.FOREST) == 2, "the second forest costs 2")
	_check(Economy.kill_gold(strong) == 5, "heavy enemy gives 5 gold")
	_check(Economy.kill_gold(strong) > Economy.kill_gold(weak), "stronger enemies give more gold")
	_check(Economy.stone_chance(strong) > Economy.stone_chance(weak), "big ships drop a little more often")
	var swarmer := Enemy.new()
	swarmer.setup(&"corsair")
	_check(Economy.blueprint_chance(swarmer, false) < Economy.blueprint_chance(weak, false), "swarmers drop less")
	swarmer.free()
	weak.free()
	strong.free()
