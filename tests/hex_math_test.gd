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
	var w := Vector2i(0, -2)
	island.place_tower(w, &"wall")
	island.damage_tower(w, 100.0)
	island.tick(5.0)
	_check(is_equal_approx(island.get_tower(w).hp, 300.0), "wall waits before resting")
	island.tick(6.0)
	_check(island.get_tower(w).hp > 300.0, "wall regenerates at rest")
