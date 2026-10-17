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
	# Never touch the player's kept XP.
	IslandSave.xp_path = "user://test_tower_xp.json"
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

	# Outside the edit mode the island can't be changed: map clicks only aim focus fire.
	_check(not view.editable, "island locked during the fight")
	var some_tower := Vector2i(999, 999)
	for coord in island.coords():
		if island.get_tower(coord):
			some_tower = coord
			break
	if some_tower != Vector2i(999, 999):
		view.handle_secondary_tap(view.hex_center_world(some_tower))
		_check(island.get_tower(some_tower) != null, "right click outside edit mode removes nothing")

	main.set_editing(true)
	_check(paused, "tree paused in edit mode")
	_check(view.editable, "island editable in edit mode")
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

	# A destroyed Scout's sky turns back into thick clouds at once (on a fresh starter island,
	# so Scouts of the saved island don't cover it).
	var fresh := Island.create_starter(1)
	var fog := FogOfWar.new(fresh)
	var spot := Vector2i(999, 999)
	for coord in fresh.coords():
		if fresh.can_place_tower(coord, &"scout"):
			spot = coord
			break
	fresh.place_tower(spot, &"scout")
	fog.tick(0.01)
	var outer: Array = fog._scouts.get(spot, []).filter(func(cell: Vector2i) -> bool: return not fog.always_open(cell))
	_check(not outer.is_empty(), "scout reveals sky beyond the island")
	for cell in outer:
		fog.reveal(cell, FogOfWar.Level.OPEN, 99.0)
	fresh.damage_tower(spot, 1e9)
	_check(fresh.get_tower(spot) == null, "scout destroyed")
	_check(outer.all(func(cell: Vector2i) -> bool: return fog.level_at(cell) == FogOfWar.Level.THICK), "its sky is thick clouds again")

	# Lasers overheat: a beam that gets no energy stays locked for OVERHEAT_TIME (towers are
	# driven by hand here, with the battle paused).
	main.set_editing(true)
	var laser := _free_tile(island, &"attack")
	island.set_biome(laser, Biome.Type.PLAINS)
	var laser_tower := island.place_tower(laser, &"attack")
	var target := combat.spawn_enemy(&"rammer", 1.0, view.hex_center_world(laser) + Vector2(70, 0))
	_check(laser_tower != null and target != null, "laser and target set up")
	if laser_tower and target:
		for member in island.group_of(laser):
			island.get_tile(member).energy = 0.0
		laser_tower.aim = 0.0
		combat._towers_attack(0.05)
		_check(is_equal_approx(laser_tower.overheat, AttackProfile.OVERHEAT_TIME), "beam without energy overheats")
		island.get_tile(laser).energy = 50.0
		combat._towers_attack(0.5)
		_check(is_equal_approx(island.get_tile(laser).energy, 50.0), "overheated beam doesn't fire even with energy back")
		combat._towers_attack(1.6)
		_check(laser_tower.overheat == 0.0 and island.get_tile(laser).energy < 50.0, "beam fires again after the lockout")
		target.is_dead = true
		target.queue_free()

		# Target lock: a shooter keeps its target, picks again at most once a second and
		# doesn't fire meanwhile; a scope click lifts the wait.
		combat._tick_locks(Combat.RETARGET_TIME)
		var first := combat.spawn_enemy(&"rammer", 1.0, view.hex_center_world(laser) + Vector2(60, 0))
		var second := combat.spawn_enemy(&"rammer", 1.0, view.hex_center_world(laser) + Vector2(90, 0))
		combat._towers_attack(0.05)
		_check(combat._locks[laser].target == first, "picks the nearest")
		second.global_position = view.hex_center_world(laser) + Vector2(40, 0)
		combat._tick_locks(Combat.RETARGET_TIME)
		combat._towers_attack(0.05)
		_check(combat._locks[laser].target == first, "keeps its target when another comes closer")
		first.is_dead = true
		combat._tick_locks(0.1)
		combat._towers_attack(0.05)
		_check(combat._locks[laser].target == second, "picks again at once when the last pick is over a second old")
		second.is_dead = true
		combat._tick_locks(0.1)
		var third := combat.spawn_enemy(&"rammer", 1.0, view.hex_center_world(laser) + Vector2(50, 0))
		var hp := third.hp
		combat._towers_attack(0.05)
		_check(combat._locks[laser].target == null and third.hp == hp, "no new target and no fire within a second of the last pick")
		combat._tick_locks(Combat.RETARGET_TIME)
		combat._towers_attack(0.05)
		_check(combat._locks[laser].target == third and third.hp < hp, "picks again after the second")
		var scoped := combat.spawn_enemy(&"rammer", 1.0, view.hex_center_world(laser) + Vector2(0, 70))
		combat.focus_click(scoped.global_position)
		combat._towers_attack(0.05)
		_check(combat._locks[laser].target == scoped, "a scope click switches at once")
		combat.clear_focus()

		# The HQ siphon drains in ticks of SIPHON_TICK, a pulse per tick (no damage in between).
		combat._siphon_clock = 0.0
		var drained := scoped.hp
		var hits := 0
		for i in 20:
			var was := scoped.hp
			combat._hq_siphon(Vector2.ZERO, scoped, HqWeapons.profile(Biome.Type.SWAMP), 0.05)
			hits += 1 if scoped.hp < was else 0
		# (Its armour takes a share of the 2 damage per tick.)
		_check(hits == 5 and drained > scoped.hp, "siphon drains in 5 ticks per phase (%d hits, %.1f damage)" % [hits, drained - scoped.hp])
		combat._siphon_clock = 0.0
		combat._hq_siphon(Vector2(5, 5), scoped, HqWeapons.profile(Biome.Type.SWAMP), 0.05)
		var stream: Dictionary = combat._siphons[-1]
		_check(stream.from == scoped.global_position and stream.to == Vector2(5, 5) and stream.pulse > 0.0, "the drain pulse runs from the enemy towards the HQ")
		for enemy: Enemy in [first, second, third, scoped]:
			enemy.is_dead = true
			enemy.queue_free()

	# Under construction a tower only takes damage: no work, energy, repairs, auras or clusters.
	var site := _free_tile(island, &"attack")
	island.treasury.inventory.add(Inventory.tower_item(&"attack"), 1)
	_check(view.place_item(site, Inventory.tower_item(&"attack"), view.hex_center_world(site)), "turret placed in edit mode")
	var site_tower := island.get_tower(site)
	var bait := combat.spawn_enemy(&"rammer", 1.0, view.hex_center_world(site) + Vector2(70, 0))
	if site_tower and bait:
		island.get_tile(site).energy = 30.0
		island.tick(0.2)
		_check(island.get_tile(site).energy == 0.0 and EnergyGrid.capacity(island.get_tile(site)) == 0.0, "no energy stored under construction")
		_check(EnergyGrid.pipe_rate(island.get_tile(site)) == 0.0, "no energy passes through it")
		_check(island.aura_at(site).is_empty(), "no auras under construction")
		site_tower.aim = 0.0
		combat._towers_attack(0.5)
		_check(not site_tower.saw_target and site_tower.attack_cooldown == 0.0, "turret under construction doesn't act")
		island.damage_tower(site, 20.0)
		_check(island.heal(site, true, 10.0) == 0.0, "no repairs under construction")
		_check(island.damaged_in_reach(site, 0).is_empty(), "repair towers pass it over")
		island.finish_construction(site)
		_check(island.heal(site, true, 10.0) > 0.0, "repairs work once built")
		bait.queue_free()

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


## A free tile where a tower of `type` may go (not the HQ).
func _free_tile(island: Island, type: StringName) -> Vector2i:
	for coord in island.coords():
		if island.can_place_tower(coord, type) and not island.get_tile(coord).is_hq:
			return coord
	return Vector2i(999, 999)


func _total_energy(island: Island) -> float:
	var total := 0.0
	for coord in island.coords():
		total += island.get_tile(coord).energy
	return total


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", what])
