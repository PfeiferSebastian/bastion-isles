extends SceneTree
## Headless check of the battle edit mode: the fight freezes while editing, edits made then
## are under construction once it resumes (double damage) and nothing can be picked up in a
## mission. Also: a destroyed Scout's sky clouds over at once, and the blueprint bad luck
## protection step shrinks with blueprints owned and found; fleeing opens the retreat report.
## Nothing is saved (persist_blueprints is switched off, the scene is never left).
##
## Run: godot --headless --path . -s tests/battle_edit_check.gd

var _failures := 0


func _initialize() -> void:
	GameSession.edit_mode = false
	GameSession.endless = false
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var view: IslandView = main.get_node("IslandView")
	var combat: Combat = main.get_node("Combat")
	var island := view.island
	island.persist_blueprints = false
	combat.mission_countdown = 0.0
	for i in 3:
		combat.spawn_enemy(&"rammer")
	await _frames(10)

	main.set_editing(true)
	_check(paused, "tree paused in edit mode")
	var positions := combat.enemies().map(func(e: Enemy) -> Vector2: return e.global_position)
	var energy := _total_energy(island)
	await _frames(30)
	_check(combat.enemies().map(func(e: Enemy) -> Vector2: return e.global_position) == positions, "enemies frozen")
	_check(is_equal_approx(_total_energy(island), energy), "energy frozen")

	# Edit while paused: a tower on a free tile.
	var free := Vector2i(999, 999)
	for coord in island.coords():
		if island.can_place_tower(coord, &"wall"):
			free = coord
			break
	_check(free != Vector2i(999, 999), "found a free tile")
	island.treasury.inventory.add(Inventory.tower_item(&"wall"), 1)
	_check(view.place_item(free, Inventory.tower_item(&"wall"), view.hex_center_world(free)), "tower placed while paused")
	_check(is_equal_approx(island.construction_left(free), Island.CONSTRUCTION_TIME), "under construction, clock stopped")
	await _frames(20)
	_check(is_equal_approx(island.construction_left(free), Island.CONSTRUCTION_TIME), "construction clock stays stopped while paused")

	# Double damage while under construction.
	var before := island.group_pool(free, &"hp").x + island.group_pool(free, &"shield").x
	island.damage_tower(free, 10.0)
	var after := island.group_pool(free, &"hp").x + island.group_pool(free, &"shield").x
	var left := island.construction_left(free)
	island.construction.erase(free)
	island.damage_tower(free, 10.0)
	var normal := after - (island.group_pool(free, &"hp").x + island.group_pool(free, &"shield").x)
	island.construction[free] = left
	_check(is_equal_approx(before - after, 2.0 * normal), "200%% damage under construction (%.1f vs %.1f)" % [before - after, normal])

	# In a mission nothing can be removed, paused or not.
	view.pick_up(free, view.hex_center_world(free))
	_check(island.get_tower(free) != null, "no picking up in a mission")

	main.set_editing(false)
	_check(not paused, "resumed")
	await _frames(30)
	_check(combat.enemies().is_empty() or combat.enemies().map(func(e: Enemy) -> Vector2: return e.global_position) != positions, "enemies move again")
	_check(island.construction_left(free) < Island.CONSTRUCTION_TIME, "construction clock runs in the fight")

	# A destroyed Scout's sky turns back into thick clouds at once.
	var fog: FogOfWar = main.get_node("FogLayer").fog
	var spot := Vector2i(999, 999)
	for coord in island.coords():
		if island.can_place_tower(coord, &"scout"):
			spot = coord
			break
	island.place_tower(spot, &"scout")
	await _frames(2)
	var outer: Array = fog._scouts.get(spot, []).filter(func(cell: Vector2i) -> bool: return not fog.always_open(cell))
	_check(not outer.is_empty(), "scout reveals sky beyond the island")
	for cell in outer:
		fog.reveal(cell, FogOfWar.Level.OPEN, 99.0)
	island.damage_tower(spot, 1e9)
	_check(island.get_tower(spot) == null, "scout destroyed")
	_check(outer.all(func(cell: Vector2i) -> bool: return fog.level_at(cell) == FogOfWar.Level.THICK), "its sky is thick clouds again")

	# Retreating: the battle pauses and the report window opens (Return isn't pressed, so
	# nothing is saved).
	combat.mission_loot.gold = 40
	main.call(&"_flee")
	_check(paused and main.retreating, "retreat pauses and opens the report")
	_check(combat.mission_loot.gold == 40 and island.treasury.gold >= 0, "loot found stays listed")
	await _frames(2)

	# The HQ castle is dressed in the island's dominant biome.
	var castle := TerrainArt.for_tile(island.get_tile(Island.HQ_COORD), island.hq_biome())
	_check(castle != null and castle == TerrainArt.hq(island.hq_biome()), "HQ castle art follows its biome")
	_check(TerrainArt.hq(Biome.Type.LAKE) != TerrainArt.hq(Biome.Type.NEUTRAL), "biome castles differ")

	# Bad luck protection: smaller with more blueprints owned and found this mission.
	_check(Economy.pity_step(0, 0) == Economy.PITY_STEP, "full pity step with no blueprints")
	_check(Economy.pity_step(10, 0) < Economy.PITY_STEP and Economy.pity_step(10, 4) < Economy.pity_step(10, 0), "pity step shrinks with owned and found")
	print("battle_edit_check: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _total_energy(island: Island) -> float:
	var total := 0.0
	for coord in island.coords():
		total += island.get_tile(coord).energy
	return total


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", what])
