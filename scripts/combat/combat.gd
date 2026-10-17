class_name Combat
extends Node2D
## Combat: sends waves of enemies (EnemyDefs.wave_plan) at the island in formations, moves
## them by their behaviour, and lets the towers aim, fire and repair based on their tile.
## Keys: P toggles waves, W spawns the next wave right away, F1-F4 spawn one enemy of each type.
## Focus fire: clicking an enemy marks it with a scope (see focus_click).

@export var island_view_path: NodePath
## Seconds between waves; once the sky is clear the next wave comes after wave_gap_when_clear.
@export var wave_interval := 20.0
@export var wave_gap_when_clear := 4.0
@export var spawn_distance := 700.0
@export var max_enemies := 60
## Most ships in one formation; bigger groups split into several.
@export var formation_size := 6
## Formations break up and attack on their own this far (px) outside the island's edge.
@export var formation_break_distance := 320.0
## Enemies stop and attack at this distance from a tower's centre.
@export var contact_range := 38.0
## Enemies with nothing to attack hover at this distance from the HQ.
@export var idle_range := 90.0
## Buildings within this distance (px) are attacked before any ground.
@export var building_seek_range := 340.0
## Placeholder mission until zones exist: progress is kills out of this many.
@export var mission_kill_goal := 100
## Each further round ("Proceed" after a won mission): enemies this much stronger (HP and
## damage) and this many more of them, compounding.
const ROUND_STRENGTH := 1.2
const ROUND_COUNT := 1.1
## Endless mode: enemies get this much stronger with every wave.
const ENDLESS_STEP := 0.03
## Seconds before the first enemies come, so the player can look around and build.
@export var mission_start_delay := 10.0
## Seconds without enemies after which the fight counts as over and the ground is repaired.
@export var battle_end_delay := 5.0

## A rare drop was found (biome stone or blueprint), for the HUD notice.
signal item_found(text: String)
## The mission goal is reached: no more enemies spawn and the player may leave.
signal mission_completed
## The HQ fell: the mission is lost and half of all resources with it (`lost`, see
## Island.lose_resources).
signal mission_failed(lost: Dictionary)

var waves_enabled := true
var kills := 0
## Seconds until the mission starts (enemies spawn only after that).
var mission_countdown := 0.0
var mission_done := false
## The HQ was destroyed: the mission is lost.
var defeated := false
## Loot found this mission (fleeing keeps only Island.FLEE_KEEP of it):
## {gold, blueprints, resources = {Biome.Type: n}, stones = {Biome.Type: n}}.
var mission_loot := {gold = 0, blueprints = 0, resources = {}, stones = {}}
## Rounds proceeded past the first (0 = the first round).
var mission_round := 0
var _base_kill_goal := 0
## Fog of war; when set, towers only target enemies in open sky. Null = everything visible.
var fog: FogOfWar

var _view: IslandView
## Waves sent so far.
var wave := 0
## A turret fires once it points within this angle (radians) of its target.
const AIM_TOLERANCE := 0.12
## The wave being logged (see BattleLog), or {} before the first wave.
var _wave_log: Dictionary = {}
var _wave_timer := 0.0
var _quiet_time := 0.0
var _enemy_layer := Node2D.new()
var _projectile_layer := Node2D.new()
var _beams: Array[PackedVector2Array] = []
var _beam_colors: Array[Color] = []
## Beam look per entry of _beams (AttackProfile.style).
var _beam_styles: Array[StringName] = []
## Short-lived shot effects: muzzle flashes and impacts, {kind, style, position, angle,
## color, time, life}.
var _shot_effects: Array[Dictionary] = []
## Short-lived heal lines: {from, to, color, time}.
var _heal_flashes: Array[Dictionary] = []
## Bomb impacts: {position, time}.
var _bursts: Array[Dictionary] = []
## Floating loot texts: {position, text, color, time}.
var _popups: Array[Dictionary] = []
var _loot_rng := RandomNumberGenerator.new()
## Seconds until the HQ weapon may fire (or heal) again.
var _hq_cooldown := 0.0
## HQ Swamp siphon this frame: {from (enemy), to (HQ), heal_to (building) or null}.
var _siphons: Array[Dictionary] = []

const HEAL_FLASH_TIME := 0.35
const BURST_TIME := 0.4
const POPUP_TIME := 1.2
## Turret muzzles sit this share of the hex size out from the tower's centre (the barrel tip
## of TowerArt._turret).
const MUZZLE_REACH := 0.43
const MUZZLE_TIME := 0.09
const IMPACT_TIME := 0.3
const SMOKE_TIME := 0.7
## Solid shots that hit with a small fire blast and a smoke puff drifting on past the target.
const BLAST_STYLES: Array[StringName] = [&"ball", &"shell", &"tracer", &"rocket"]

## Focus fire on `focus`: at FOCUS_CORE towers that have it inside their core range shoot it
## first, at FOCUS_FULL every tower that reaches it at all. FOCUS_NONE = normal targeting.
enum { FOCUS_NONE, FOCUS_CORE, FOCUS_FULL }
## A click this close (px) to an enemy counts as clicking it.
const FOCUS_PICK_RADIUS := 22.0
const SCOPE_COLOR := Color("ff5a3c")
const SCOPE_FULL_COLOR := Color("ffd23f")
var focus: Enemy = null
var focus_level := FOCUS_NONE
## Draws the scope above the enemies.
var _scope_layer := Node2D.new()


func _ready() -> void:
	_view = get_node(island_view_path)
	add_child(_enemy_layer)
	add_child(_projectile_layer)
	_scope_layer.draw.connect(_draw_scope)
	add_child(_scope_layer)
	mission_countdown = mission_start_delay
	_apply_session()
	_base_kill_goal = mission_kill_goal


func _process(delta: float) -> void:
	if mission_countdown > 0.0:
		mission_countdown = maxf(mission_countdown - delta, 0.0)
	elif waves_enabled and not mission_done and not defeated:
		_wave_timer -= delta
		if enemies().is_empty():
			_wave_timer = minf(_wave_timer, wave_gap_when_clear)
		if _wave_timer <= 0.0:
			spawn_wave()
	_check_defeat()
	_drop_dead_focus()
	_beams.clear()
	_beam_colors.clear()
	_beam_styles.clear()
	_siphons.clear()
	for enemy in enemies():
		enemy.tick_statuses(delta)
		if not enemy.is_dead:
			_move_and_attack(enemy, delta)
	_towers_attack(delta)
	_hq_attack(delta)
	_towers_repair(delta)
	_aura_debuffs()
	_check_battle_end(delta)
	queue_redraw()
	_scope_layer.queue_redraw()


func _check_battle_end(delta: float) -> void:
	if not enemies().is_empty():
		_quiet_time = 0.0
		return
	_quiet_time += delta
	if _quiet_time >= battle_end_delay and _view.island.has_battle_damage():
		_view.island.restore_tiles()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P:
			waves_enabled = not waves_enabled
		KEY_W:
			spawn_wave()
		KEY_F1:
			spawn_enemy(&"rammer")
		KEY_F2:
			spawn_enemy(&"gunboat")
		KEY_F3:
			spawn_enemy(&"corsair")
		KEY_F4:
			spawn_enemy(&"bomber")


func enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for child in _enemy_layer.get_children():
		var enemy := child as Enemy
		if enemy and not enemy.is_dead:
			result.append(enemy)
	return result


## Sends the next wave right away (also ends the start countdown early). Each type flies in
## its own formations, coming from roughly the same side of the sky.
func spawn_wave() -> void:
	if mission_done:
		return
	mission_countdown = 0.0
	_wave_timer = wave_interval
	finish_wave_log()
	wave += 1
	_view.island.start_wave_stats()
	_wave_log = {started = Time.get_unix_time_from_system(), mission_round = mission_round + 1, wave = wave,
		strength = strength_factor(), enemies = {}, enemy_hp = 0.0, kills = {},
		loot = {gold = 0, blueprints = 0, stones = 0, resources = {}}}
	var groups: Array = []
	for kind in EnemyDefs.wave_plan(wave, count_factor()):
		if groups.is_empty() or groups[-1][0] != kind or groups[-1].size() >= formation_size:
			groups.append([kind])
		else:
			groups[-1].append(kind)
	var side := randf() * TAU
	for i in groups.size():
		var angle := side + (i - (groups.size() - 1) / 2.0) * 0.45 + randf_range(-0.1, 0.1)
		_spawn_formation(groups[i], angle)


## Ships of `kinds` in a V, the first one leading, coming in from `angle`.
func _spawn_formation(kinds: Array, angle: float) -> void:
	var leader: Enemy = null
	var inward := Vector2.from_angle(angle + PI)
	for i in kinds.size():
		# V shape: rows behind the leader, alternating left and right.
		var row := (i + 1) / 2
		var offset := Vector2(-row * 40.0, (1 if i % 2 == 1 else -1) * row * 34.0) if i > 0 else Vector2.ZERO
		var at := _view.global_position + Vector2.from_angle(angle) * spawn_distance + offset.rotated(inward.angle())
		var enemy := spawn_enemy(kinds[i], strength_factor(), at, 1.0)
		if enemy == null:
			return
		if kinds.size() > 1:
			enemy.in_formation = true
			enemy.formation_leader = leader
			enemy.formation_offset = offset
			enemy.face(inward.angle())
		if leader == null:
			leader = enemy


## Writes the wave being logged to the battle log: what came, what died, the loot, what each
## building type did (Island.wave_totals) and the island's make-up. Called when the next wave
## starts, the mission is won or the player leaves.
func finish_wave_log() -> void:
	if _wave_log.is_empty():
		return
	var island := _view.island
	var buildings := {}
	var tiles := {}
	for coord in island.coords():
		var tile := island.get_tile(coord)
		var biome := Biome.name_of(tile.biome)
		tiles[biome] = tiles.get(biome, 0) + 1
		if tile.tower and not tile.tower.is_part:
			var key := "%s T%d" % [tile.tower.type, tile.tower.tier]
			buildings[key] = buildings.get(key, 0) + 1
	var by_type := {}
	for type in island.wave_totals:
		var counters := {}
		for key in island.wave_totals[type]:
			counters[String(key)] = snappedf(island.wave_totals[type][key], 0.1)
		by_type[String(type)] = counters
	_wave_log.duration = snappedf(Time.get_unix_time_from_system() - _wave_log.started, 0.1)
	_wave_log.enemy_hp = roundi(_wave_log.enemy_hp)
	_wave_log.buildings = by_type
	_wave_log.island = {buildings = buildings, tiles = tiles}
	BattleLog.append(_wave_log)
	_wave_log = {}


## Spawns one enemy of `kind` (random mix if empty) on a ring around the island; none once
## the mission is done.
func spawn_enemy(kind: StringName = &"", factor := 1.0, at: Variant = null, speed_factor := -1.0) -> Enemy:
	if mission_done or defeated or enemies().size() >= max_enemies:
		return null
	var enemy := Enemy.new()
	enemy.setup(kind if kind != &"" else EnemyDefs.pick_random(), factor, speed_factor)
	enemy.died.connect(_on_enemy_died)
	if not _wave_log.is_empty():
		_wave_log.enemies[String(enemy.kind)] = _wave_log.enemies.get(String(enemy.kind), 0) + 1
		_wave_log.enemy_hp += enemy.max_hp
	_enemy_layer.add_child(enemy)
	enemy.global_position = at if at != null else _view.global_position + Vector2.from_angle(randf() * TAU) * spawn_distance
	return enemy


## Mission rules from the main menu's choice (GameSession): the mission's kill goal and
## enemy strength and numbers; in endless mode no goal at all.
var _mission_strength := 1.0
var _mission_count := 1.0


func _apply_session() -> void:
	if GameSession.endless:
		mission_kill_goal = 1 << 30
		return
	var rules := GameSession.mission_rules()
	mission_kill_goal = rules.kill_goal
	_mission_strength = rules.strength
	_mission_count = rules.count


## Enemy HP and damage multiplier: the mission's, the round's and in endless mode +ENDLESS_STEP
## per wave.
func strength_factor() -> float:
	var endless_growth := 1.0 + ENDLESS_STEP * maxi(wave - 1, 0) if GameSession.endless else 1.0
	return _mission_strength * pow(ROUND_STRENGTH, mission_round) * endless_growth


## Enemy count multiplier of the mission and the current round.
func count_factor() -> float:
	return _mission_count * pow(ROUND_COUNT, mission_round)


## Starts the next, harder round after a won mission: enemies 20% stronger, 10% more of them
## (more per wave and a higher kill goal), after the usual countdown. Towers gain XP again.
func proceed() -> void:
	if not mission_done:
		return
	mission_round += 1
	mission_done = false
	kills = 0
	wave = 0
	_wave_timer = 0.0
	mission_kill_goal = roundi(_base_kill_goal * count_factor())
	mission_countdown = mission_start_delay
	_view.island.gains_xp = not GameSession.edit_mode


## Mission progress from 0 to 1 (placeholder: kills toward mission_kill_goal).
func mission_progress() -> float:
	return clampf(float(kills) / maxf(mission_kill_goal, 1), 0.0, 1.0)


func is_enemy_visible(enemy: Enemy) -> bool:
	return fog == null or fog.is_visible(_view.world_to_hex(enemy.global_position))


## Firing gives an enemy's position away: its hex clears one fog level.
func _reveal_shooter(enemy: Enemy) -> void:
	if fog:
		fog.reveal_step(_view.world_to_hex(enemy.global_position))


func _on_enemy_died(enemy: Enemy) -> void:
	kills += 1
	var treasury := _view.island.treasury
	var loot := Economy.roll_loot(enemy, _loot_rng, treasury.pity)
	var at := enemy.global_position
	treasury.add_gold(loot.gold)
	mission_loot.gold += loot.gold
	if loot.blueprint:
		mission_loot.blueprints += 1
	if loot.resource >= 0:
		mission_loot.resources[loot.resource] = mission_loot.resources.get(loot.resource, 0) + 1
	if loot.stone >= 0:
		mission_loot.stones[loot.stone] = mission_loot.stones.get(loot.stone, 0) + 1
	if not _wave_log.is_empty():
		_wave_log.kills[String(enemy.kind)] = _wave_log.kills.get(String(enemy.kind), 0) + 1
		_wave_log.loot.gold += loot.gold
		_wave_log.loot.blueprints += 1 if loot.blueprint else 0
		_wave_log.loot.stones += 1 if loot.stone >= 0 else 0
		if loot.resource >= 0:
			var resource_name := Biome.resource_name(loot.resource)
			_wave_log.loot.resources[resource_name] = _wave_log.loot.resources.get(resource_name, 0) + 1
	popup(at, "+%d gold" % loot.gold, Color("ffd23f"))
	if loot.stone >= 0:
		var stone := Inventory.stone_item(loot.stone)
		treasury.inventory.add(stone)
		popup(at + Vector2(0, -16), "+1 " + Inventory.label_of(stone), Color("8fd3ff"))
		item_found.emit("Found: %s" % Inventory.label_of(stone))
	if loot.resource >= 0:
		treasury.add_resource(loot.resource)
		popup(at + Vector2(0, -48), "+1 " + Biome.resource_name(loot.resource), Biome.color_of(loot.resource).lightened(0.3))
	if loot.blueprint:
		_view.island.add_blueprint()
		popup(at + Vector2(0, -32), "+1 Blueprint", Color("8fc8ff"))
		item_found.emit("Blueprint found (%d)" % treasury.blueprints)
	else:
		# Bad luck protection: blueprints get a little likelier every kill without one, less
		# so the more the player owns and has found this mission.
		treasury.pity += Economy.pity_step(treasury.blueprints, mission_loot.blueprints)
	if not mission_done and kills >= mission_kill_goal:
		mission_done = true
		# The fight is won: towers stop gaining experience.
		_view.island.gains_xp = false
		_clear_sky()
		finish_wave_log()
		mission_completed.emit()


## Fleeing a running mission: only Island.FLEE_KEEP of this mission's loot is kept (the
## rest is taken away again), towers destroyed this mission are rebuilt at level 0 and
## wasteland biome tiles come back at Tier 1. Returns {lost (same shape as mission_loot),
## rebuilt}. Does nothing (returns {}) once the mission is won or lost, and in endless mode,
## where leaving is the only way out and keeps everything.
func flee() -> Dictionary:
	if mission_done or defeated or GameSession.endless:
		return {}
	finish_wave_log()
	var island := _view.island
	var treasury := island.treasury
	var keep := Island.FLEE_KEEP
	var lost := {gold = 0, blueprints = 0, resources = {}, stones = {}}
	lost.gold = mini(treasury.gold, mission_loot.gold - floori(mission_loot.gold * keep))
	treasury.gold -= lost.gold
	lost.blueprints = mini(treasury.blueprints, mission_loot.blueprints - floori(mission_loot.blueprints * keep))
	treasury.blueprints -= lost.blueprints
	for biome in mission_loot.resources:
		var amount := mini(treasury.resources.get(biome, 0), mission_loot.resources[biome] - floori(mission_loot.resources[biome] * keep))
		treasury.resources[biome] = treasury.resources.get(biome, 0) - amount
		lost.resources[biome] = amount
	for biome in mission_loot.stones:
		var stone := Inventory.stone_item(biome)
		var amount := mini(treasury.inventory.count(stone), mission_loot.stones[biome] - floori(mission_loot.stones[biome] * keep))
		if amount > 0:
			treasury.inventory.add(stone, -amount)
		lost.stones[biome] = amount
	treasury.changed.emit()
	if island.persist_blueprints:
		IslandSave.save_blueprints(island)
	return {lost = lost, rebuilt = island.rebuild_losses()}


## Ends the mission as lost once the HQ has no HP left: the enemies leave, towers stop
## gaining experience and half of all resources are lost.
func _check_defeat() -> void:
	if defeated or mission_done:
		return
	var hq := _view.island.get_tile(Island.HQ_COORD)
	if hq == null or hq.hp > 0.0:
		return
	defeated = true
	_view.island.gains_xp = false
	_clear_sky()
	if not _wave_log.is_empty():
		_wave_log.result = "defeat"
	finish_wave_log()
	mission_failed.emit(_view.island.lose_resources())


## Mission won: the remaining enemies vanish in a puff (no loot) and all shots in flight go.
func _clear_sky() -> void:
	for enemy in enemies():
		_bursts.append({position = enemy.global_position, time = BURST_TIME})
		enemy.is_dead = true
		enemy.queue_free()
	for shot in _projectile_layer.get_children():
		shot.queue_free()


## Short floating text in the world (loot, "not enough gold"…).
func popup(world_position: Vector2, text: String, color: Color) -> void:
	_popups.append({position = world_position, text = text, color = color, time = POPUP_TIME})


# --- Enemies -------------------------------------------------------------

func _move_and_attack(enemy: Enemy, delta: float) -> void:
	enemy.cooldown_left = maxf(enemy.cooldown_left - delta, 0.0)
	if enemy.is_rooted():
		# Enclosed in a bubble: it acts (aims, attacks) but stays where it is.
		var held := enemy.global_position
		_move_and_attack_free(enemy, delta)
		enemy.global_position = held
		return
	_move_and_attack_free(enemy, delta)


func _move_and_attack_free(enemy: Enemy, delta: float) -> void:
	if enemy.in_formation and _fly_in_formation(enemy, delta):
		return
	match enemy.behaviour:
		&"standoff":
			_standoff(enemy, delta)
		&"orbit":
			_orbit(enemy, delta)
		&"flyover":
			_flyover(enemy, delta)
		_:
			_ram(enemy, delta)


## Formation flight: the leader heads straight for the island, the others keep their place
## in the V. Near the island (or when the leader is gone) the formation breaks up and every
## ship follows its own behaviour. Returns false once `enemy` has left the formation.
func _fly_in_formation(enemy: Enemy, delta: float) -> bool:
	var center := _view.global_position
	var leader := enemy.formation_leader
	if enemy.formation_offset == Vector2.ZERO:   # the leader
		if enemy.global_position.distance_to(center) <= _island_radius_px() + formation_break_distance:
			enemy.in_formation = false
			return false
		_approach(enemy, center, 0.0, delta)
		return true
	if not is_instance_valid(leader) or leader.is_dead or not leader.in_formation:
		enemy.in_formation = false
		enemy.formation_leader = null
		return false
	var goal := leader.global_position + enemy.formation_offset.rotated(leader.rotation)
	var to := goal - enemy.global_position
	# Catch up a little faster than the leader flies, so the V stays tight.
	enemy.global_position += to.limit_length(enemy.speed * 1.25 * delta)
	enemy.face(leader.rotation)
	return true


## Target coord for `enemy` by its target priority (EnemyDefs `targets`): the first entry
## that finds something, the nearest of its kind. Buildings count within `building_range`,
## the HQ and ground within `ground_range` (default: building_seek_range and anywhere).
## Null if nothing fits, or when the list reaches strafe.
func _pick_target(enemy: Enemy, building_range := -1.0, ground_range := INF) -> Variant:
	if building_range < 0.0:
		building_range = building_seek_range
	var from := enemy.global_position
	for entry in enemy.target_priority:
		var found: Variant = null
		match entry:
			&"nearest":
				found = _nearest(from, true, building_range)
			&"ground":
				found = _nearest(from, false, ground_range)
			&"hq":
				var hq := _view.island.get_tile(Island.HQ_COORD)
				var hq_distance := from.distance_to(_view.hex_center_world(Island.HQ_COORD))
				if hq and not hq.destroyed and hq.hp > 0.0 and hq_distance <= ground_range:
					found = Island.HQ_COORD
			&"strafe":
				return null
			_:
				if entry in TowerDefs.TYPES:
					found = _nearest(from, true, building_range, entry)
		if found != null:
			return found
	return null


## Rammer: flies to its target and damages it on contact.
func _ram(enemy: Enemy, delta: float) -> void:
	var target: Variant = _pick_target(enemy)
	var goal := _view.global_position if target == null else _view.hex_center_world(target)
	var stop := idle_range if target == null else contact_range
	if _approach(enemy, goal, stop, delta) and target != null:
		_hit(target, enemy.damage_output() * delta)


## Gunboat: closes in until its target is in weapon range, then holds position and shoots.
func _standoff(enemy: Enemy, delta: float) -> void:
	var target: Variant = _pick_target(enemy)
	if target == null:
		_approach(enemy, _view.global_position, idle_range, delta)
		return
	var range_px := _weapon_range_px(enemy)
	if _approach(enemy, _view.hex_center_world(target), range_px * 0.85, delta):
		_shoot(enemy, target)


## Corsair: circles the island just inside weapon range of the outer buildings and shoots
## whatever is in range.
func _orbit(enemy: Enemy, delta: float) -> void:
	var center := _view.global_position
	var range_px := _weapon_range_px(enemy)
	var desired := _island_radius_px() + range_px * 0.6
	var offset := enemy.global_position - center
	var r := maxf(offset.length(), 0.01)
	var radial := offset / r
	var tangent := Vector2(-radial.y, radial.x) * enemy.orbit_direction
	var correction := clampf((desired - r) / 60.0, -1.0, 1.0)
	var velocity := (tangent + radial * correction).normalized() * enemy.speed
	enemy.global_position += velocity * delta
	enemy.face(velocity.angle())
	var target: Variant = _pick_target(enemy, range_px, range_px)
	if target != null:
		_shoot(enemy, target)


## Bomber: straight passes over the island, bombing the tile below; turns and comes back.
func _flyover(enemy: Enemy, delta: float) -> void:
	var center := _view.global_position
	var turn_radius := _island_radius_px() + 300.0
	var away := enemy.global_position - center
	if enemy.heading == Vector2.ZERO or (away.length() > turn_radius and away.dot(enemy.heading) > 0.0):
		# New pass: over the target its priority picks, or (strafe) slightly off-centre.
		var target: Variant = _pick_target(enemy, INF)
		var aim := center if target == null else _view.hex_center_world(target)
		aim += Vector2.from_angle(randf() * TAU) * randf() * _view.hex_size * (1.5 if target == null else 0.5)
		enemy.heading = (aim - enemy.global_position).normalized()
	enemy.global_position += enemy.heading * enemy.speed * delta
	enemy.face(enemy.heading.angle())
	var below := _view.world_to_hex(enemy.global_position)
	var tile := _view.island.get_tile(below)
	if tile and not tile.destroyed and enemy.cooldown_left <= 0.0:
		enemy.cooldown_left = enemy.reload_time()
		_reveal_shooter(enemy)
		_hit(below, enemy.shot_damage())
		_bursts.append({position = _view.hex_center_world(below), time = BURST_TIME})


## Moves toward `goal` until within `stop`; returns true once there.
func _approach(enemy: Enemy, goal: Vector2, stop: float, delta: float) -> bool:
	var to := goal - enemy.global_position
	var distance := to.length()
	if distance > 0.01:
		enemy.face(to.angle())
	if distance <= stop:
		return true
	enemy.global_position += to / distance * minf(enemy.speed * delta, distance - stop)
	return false


func _shoot(enemy: Enemy, target: Vector2i) -> void:
	if enemy.cooldown_left > 0.0:
		return
	enemy.cooldown_left = enemy.reload_time()
	_reveal_shooter(enemy)
	var shot := EnemyProjectile.new()
	shot.target_position = _view.hex_center_world(target) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	shot.speed = enemy.projectile_speed
	shot.on_hit = _shot_landed.bind(enemy.shot_damage())
	shot.blocks = _wall_at
	_projectile_layer.add_child(shot)
	shot.global_position = enemy.global_position


## An enemy shot hits whatever stands where it lands: a wall in its path, or the aim point.
func _shot_landed(world_position: Vector2, amount: float) -> void:
	_hit(_view.world_to_hex(world_position), amount)


## Walls block enemy shots flying over them.
func _wall_at(world_position: Vector2) -> bool:
	var tower := _view.island.get_tower(_view.world_to_hex(world_position))
	return tower != null and tower.type == &"wall"


## Damage lands on the building of `coord`, or on the ground if there is none.
func _hit(coord: Vector2i, amount: float) -> void:
	if _view.island.get_tower(coord) != null:
		_view.island.damage_tower(coord, amount)
	else:
		_view.island.damage_tile(coord, amount)


func _weapon_range_px(enemy: Enemy) -> float:
	return enemy.weapon_range_hexes * HexMath.SQRT3 * _view.hex_size


## Distance from the HQ to the outer edge of the island.
func _island_radius_px() -> float:
	var furthest := 0.0
	for coord in _view.island.coords():
		furthest = maxf(furthest, _view.hex_center_world(coord).distance_to(_view.global_position))
	return furthest + _view.hex_size


## Closest coord within `max_distance` px: a tower when `towers` (only of `type` if given),
## otherwise standing ground without a tower (including the HQ while it has HP). Null if none.
func _nearest(from: Vector2, towers: bool, max_distance: float, type := &"") -> Variant:
	var island := _view.island
	var best: Variant = null
	var best_distance := max_distance * max_distance
	for coord in island.coords():
		var tile := island.get_tile(coord)
		if towers:
			if tile.tower == null or (type != &"" and tile.tower.type != type):
				continue
		elif tile.tower != null or tile.destroyed or tile.hp <= 0.0:
			continue
		var d := from.distance_squared_to(_view.hex_center_world(coord))
		if d < best_distance:
			best_distance = d
			best = coord
	return best


# --- Focus fire ----------------------------------------------------------

## Visible enemy under `world_position` (the closest within FOCUS_PICK_RADIUS), or null.
func enemy_at(world_position: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance := FOCUS_PICK_RADIUS
	for enemy in enemies():
		var d := enemy.global_position.distance_to(world_position)
		if d <= best_distance and is_enemy_visible(enemy):
			best_distance = d
			best = enemy
	return best


## Left click: an enemy gets the scope (towers with it in their core range focus it); clicking
## the scoped enemy again widens the focus to every tower that reaches it. Returns true if
## the click hit an enemy (and is used up).
func focus_click(world_position: Vector2) -> bool:
	var enemy := enemy_at(world_position)
	if enemy == null:
		return false
	if enemy == focus:
		focus_level = FOCUS_FULL
	else:
		focus = enemy
		focus_level = FOCUS_CORE
	return true


## Right click on an enemy (the scoped one or any other) removes the scope. Returns true if
## the click was used up, i.e. there was a scope and the click hit an enemy.
func focus_secondary_click(world_position: Vector2) -> bool:
	if focus == null or enemy_at(world_position) == null:
		return false
	clear_focus()
	return true


func clear_focus() -> void:
	focus = null
	focus_level = FOCUS_NONE


## The scope goes when its enemy dies (or vanishes when the sky is cleared).
func _drop_dead_focus() -> void:
	if focus != null and (not is_instance_valid(focus) or focus.is_dead):
		clear_focus()


## Moves the focused enemy to the front of `targets` (sorted by the tower's own priority) if
## the focus applies to this tower: at FOCUS_CORE only within `core_px` of `origin`.
func _focus_first(targets: Array[Enemy], origin: Vector2, core_px: float) -> void:
	_drop_dead_focus()
	if focus == null:
		return
	var index := targets.find(focus)
	if index <= 0:
		return
	if focus_level == FOCUS_CORE and origin.distance_to(focus.global_position) > core_px:
		return
	targets.remove_at(index)
	targets.push_front(focus)


## Scope over the focused enemy: a ring with four gaps and inward ticks; the widened focus
## adds corner brackets and turns gold.
func _draw_scope() -> void:
	if focus == null or not is_instance_valid(focus):
		return
	var at := _scope_layer.to_local(focus.global_position)
	var full := focus_level == FOCUS_FULL
	var color := SCOPE_FULL_COLOR if full else SCOPE_COLOR
	var outline := Color(0, 0, 0, 0.7)
	var radius := 24.0
	var gap := 0.32
	for i in 4:
		var mid := i * TAU / 4.0 + PI / 4.0
		_scope_arc(at, radius, mid - PI / 4.0 + gap, mid + PI / 4.0 - gap, color, outline)
		var dir := Vector2.from_angle(i * TAU / 4.0)
		_scope_line(at + dir * (radius + 5.0), at + dir * (radius - 8.0), color, outline)
	_scope_dot(at, color, outline)
	if full:
		var r := radius + 9.0
		var arm := 7.0
		for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
			var tip: Vector2 = at + corner * r * 0.75
			_scope_line(tip, tip - Vector2(corner.x * arm, 0), color, outline)
			_scope_line(tip, tip - Vector2(0, corner.y * arm), color, outline)


func _scope_dot(at: Vector2, color: Color, outline: Color) -> void:
	_scope_layer.draw_circle(at, 2.6, outline)
	_scope_layer.draw_circle(at, 1.6, color)


func _scope_arc(at: Vector2, radius: float, from: float, to: float, color: Color, outline: Color) -> void:
	_scope_layer.draw_arc(at, radius, from, to, 12, outline, 4.5, true)
	_scope_layer.draw_arc(at, radius, from, to, 12, color, 2.0, true)


func _scope_line(a: Vector2, b: Vector2, color: Color, outline: Color) -> void:
	_scope_layer.draw_line(a, b, outline, 4.5, true)
	_scope_layer.draw_line(a, b, color, 2.0, true)


# --- Towers --------------------------------------------------------------

func _towers_attack(delta: float) -> void:
	var island := _view.island
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.type != &"attack" or tower.is_part:
			continue
		var profile := AttackProfiles.for_tile(island, coord)
		var origin := _view.hex_center_world(coord)
		var hex_px := HexMath.SQRT3 * _view.hex_size
		# Targets out to the furthest reach, those inside the core range first.
		var targets := _targets_in_range(origin, profile.max_reach() * hex_px)
		targets.sort_custom(func(a: Enemy, b: Enemy) -> bool:
			var a_in := origin.distance_to(a.global_position) <= profile.range_hexes * hex_px
			var b_in := origin.distance_to(b.global_position) <= profile.range_hexes * hex_px
			if a_in != b_in:
				return a_in
			return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
		_focus_first(targets, origin, profile.range_hexes * HexMath.SQRT3 * _view.hex_size)
		tower.attack_cooldown = maxf(tower.attack_cooldown - delta, 0.0)
		tower.overheat = maxf(tower.overheat - delta, 0.0)
		# Reloading after a shot counts as working.
		tower.did_work = tower.did_work or tower.attack_cooldown > 0.0
		if targets.is_empty():
			continue
		tower.saw_target = true
		# The turret turns toward the target and fires only once it points at it.
		var wanted := (targets[0].global_position - origin).angle()
		tower.aim = rotate_toward(tower.aim, wanted, deg_to_rad(profile.turn_speed) * delta)
		_view.aim_tower(coord, tower.aim)
		if absf(angle_difference(tower.aim, wanted)) > AIM_TOLERANCE:
			continue
		var beams := mini(profile.beam_count, targets.size())
		if beams > 0 and tower.overheat <= 0.0:
			var beam_power := EnergyGrid.draw_energy(island, coord, profile.beam_energy * beams * delta)
			# Out of energy: the beam overheats and stays locked for a while.
			if beam_power <= 0.0:
				tower.overheat = AttackProfile.OVERHEAT_TIME
			for i in beams:
				var distance := origin.distance_to(targets[i].global_position) / hex_px
				_fire_beam(origin, targets[i], profile, beam_power, delta, coord, profile.performance(distance), distance <= profile.range_hexes)
			if beam_power > 0.0:
				tower.did_work = true
			island.add_xp(coord, beam_power * delta)
		if profile.has_projectile() and tower.attack_cooldown <= 0.0:
			var power := EnergyGrid.draw_energy(island, coord, profile.energy_per_shot)
			if power > 0.0:
				# Below 1 (e.g. Forest without energy) the tower fires more slowly.
				tower.attack_cooldown = profile.cooldown / power
				var distance := origin.distance_to(targets[0].global_position) / hex_px
				_fire_projectile(origin, targets[0], profile, coord, profile.performance(distance), distance <= profile.range_hexes)
				tower.did_work = true
				island.add_xp(coord, 1.0)


## The HQ fights with the weapon of its biome (HqWeapons, Island.hq_biome) at the nearest
## visible enemy, or the scoped one; it needs no energy and has no reach past its range.
func _hq_attack(delta: float) -> void:
	var island := _view.island
	var hq := island.get_tile(Island.HQ_COORD)
	_hq_cooldown = maxf(_hq_cooldown - delta, 0.0)
	if hq == null or hq.hp <= 0.0:
		return
	var biome := island.hq_biome()
	var profile := HqWeapons.profile(biome)
	var origin := _view.hex_center_world(Island.HQ_COORD)
	if biome == Biome.Type.FOREST:
		_hq_heal(profile)
		return
	var targets := _targets_in_range(origin, profile.range_hexes * HexMath.SQRT3 * _view.hex_size)
	_focus_first(targets, origin, INF)
	if targets.is_empty():
		return
	match biome:
		Biome.Type.PLAINS:
			_fire_beam(origin, targets[0], profile, 1.0, delta, Island.HQ_COORD)
		Biome.Type.SWAMP:
			_hq_siphon(origin, targets[0], profile, delta)
		_:
			if _hq_cooldown > 0.0:
				return
			_hq_cooldown = profile.cooldown
			match biome:
				Biome.Type.MOUNTAIN:
					_launch(HqWeapons.Rocket.new(), origin, targets[0], profile, _credit.bind(Island.HQ_COORD))
				Biome.Type.LAKE:
					_hq_bubble(origin, targets, profile)
				_:
					# Twin cannon: both barrels at once, side by side across the line of fire.
					var side := (targets[0].global_position - origin).normalized().orthogonal() * HqWeapons.TWIN_SPREAD / 2.0
					for barrel in [side, -side]:
						_launch(Projectile.new(), origin + barrel, targets[0], profile, _credit.bind(Island.HQ_COORD))


## Forest: heals the weakest building or ground in range, one pulse per interval.
func _hq_heal(profile: AttackProfile) -> void:
	if _hq_cooldown > 0.0:
		return
	var island := _view.island
	var damaged := island.damaged_in_reach(Island.HQ_COORD, int(profile.range_hexes))
	if damaged.is_empty():
		return
	_hq_cooldown = profile.cooldown
	var target: Dictionary = damaged[0]
	island.track(Island.HQ_COORD, &"healed", island.heal(target.coord, target.tower, profile.damage))
	_flash(Island.HQ_COORD, target.coord, HqWeapons.HEAL_COLOR)


## Swamp: a channelled stream drains the target and heals the closest damaged building
## (the HQ itself counts, at distance 0) by the rest of the budget.
func _hq_siphon(origin: Vector2, target: Enemy, profile: AttackProfile, delta: float) -> void:
	var island := _view.island
	var before := target.hp
	target.take_damage(profile.beam_dps * delta)
	_credit(target, before, Island.HQ_COORD)
	var siphon := {from = target.global_position, to = origin, heal_to = null}
	var closest := {}
	for entry in island.damaged_in_reach(Island.HQ_COORD, int(profile.range_hexes)):
		if not entry.tower and entry.coord != Island.HQ_COORD:
			continue
		if closest.is_empty() or HexMath.distance(Island.HQ_COORD, entry.coord) < HexMath.distance(Island.HQ_COORD, closest.coord):
			closest = entry
	if not closest.is_empty():
		island.track(Island.HQ_COORD, &"healed", island.heal(closest.coord, closest.tower, profile.effect_dps * delta))
		siphon.heal_to = _view.hex_center_world(closest.coord)
	_siphons.append(siphon)


## Lake: a bubble for the nearest enemy not already enclosed; on arrival it roots it.
func _hq_bubble(origin: Vector2, targets: Array[Enemy], profile: AttackProfile) -> void:
	var target := targets[0]
	if target.is_rooted() and target != focus:
		for enemy in targets:
			if not enemy.is_rooted():
				target = enemy
				break
	var on_hit := func(enemy: Enemy, before: float) -> void:
		if not enemy.is_dead:
			enemy.root(profile.dot_duration)
		_credit(enemy, before, Island.HQ_COORD)
	_launch(HqWeapons.Bubble.new(), origin, target, profile, on_hit)


## Sends `projectile` (Projectile or a subclass) from `origin` at `target`.
func _launch(projectile: Projectile, origin: Vector2, target: Enemy, profile: AttackProfile, on_hit: Callable) -> void:
	projectile.target = target
	projectile.profile = profile
	projectile.on_hit = on_hit
	projectile.on_land = _impact.bind(profile)
	_projectile_layer.add_child(projectile)
	projectile.global_position = origin


## Visible enemies within range, nearest first.
func _targets_in_range(origin: Vector2, range_px: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy in enemies():
		if origin.distance_to(enemy.global_position) <= range_px and is_enemy_visible(enemy):
			result.append(enemy)
	result.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	return result


## The laser stops at its target and only damages that enemy.
func _fire_beam(origin: Vector2, target: Enemy, profile: AttackProfile, power: float, delta: float,
		source := Vector2i(9999, 9999), factor := 1.0, specials := true) -> void:
	if power <= 0.0:
		return
	var before := target.hp
	target.take_damage(profile.beam_dps * power * delta * factor, profile.armor_pen)
	if specials and profile.attack_slow > 0.0 and not target.is_dead:
		target.add_attack_slow(profile.attack_slow, profile.attack_slow_duration)
	_credit(target, before, source)
	_beams.append(PackedVector2Array([_muzzle(origin, target.global_position), target.global_position]))
	_beam_colors.append(profile.beam_color)
	_beam_styles.append(profile.style)


func _fire_projectile(origin: Vector2, target: Enemy, profile: AttackProfile, source := Island.HQ_COORD,
		factor := 1.0, specials := true) -> void:
	var projectile := Projectile.new()
	projectile.target = target
	projectile.profile = profile
	projectile.factor = factor
	projectile.specials = specials
	projectile.on_hit = _credit.bind(source)
	projectile.on_land = _impact.bind(profile)
	_projectile_layer.add_child(projectile)
	var muzzle := _muzzle(origin, target.global_position) if source != Island.HQ_COORD else origin
	projectile.global_position = muzzle
	if profile.style != &"ball" and source != Island.HQ_COORD:
		_shot_effects.append({kind = &"muzzle", style = profile.style, position = muzzle,
			angle = (target.global_position - origin).angle(), color = profile.color, time = MUZZLE_TIME, life = MUZZLE_TIME})


## Where a turret on `origin` aiming at `aim_at` fires from.
func _muzzle(origin: Vector2, aim_at: Vector2) -> Vector2:
	return origin + (aim_at - origin).normalized() * _view.hex_size * MUZZLE_REACH


## A shot of `profile` flying at `angle` lands at `world_position`: an impact in its style.
## Solid shots (BLAST_STYLES) burst in a small fire blast, and a smoke puff drifts on a little
## further along their flight.
func _impact(world_position: Vector2, angle: float, profile: AttackProfile) -> void:
	if profile.style == &"bubble":
		return
	var effect := {kind = &"impact", style = profile.style, position = world_position, angle = angle,
		color = profile.color, size = profile.projectile_size, time = IMPACT_TIME, life = IMPACT_TIME}
	if profile.style in BLAST_STYLES:
		effect.kind = &"blast"
		_shot_effects.append(effect.merged({kind = &"smoke", time = SMOKE_TIME, life = SMOKE_TIME}, true))
	_shot_effects.append(effect)


## Analysis: credits the damage a hit did (and a kill) to the building on `source`.
func _credit(target: Enemy, before: float, source: Vector2i) -> void:
	if source == Vector2i(9999, 9999):
		return
	_view.island.track(source, &"damage", before - maxf(target.hp, 0.0))
	if target.is_dead:
		_view.island.track(source, &"kills", 1.0)


## Swamp Aura towers weaken every enemy inside their radius.
func _aura_debuffs() -> void:
	var island := _view.island
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.type != &"aura" or tower.aura_power <= 0.0 or tower.is_part:
			continue
		var profile := AuraProfiles.for_tile(island, coord)
		if profile.enemy_weaken <= 0.0:
			continue
		var origin := _view.hex_center_world(coord)
		var range_px := (profile.radius + 0.5) * HexMath.SQRT3 * _view.hex_size
		for enemy in enemies():
			if origin.distance_to(enemy.global_position) <= range_px:
				enemy.add_weaken(profile.enemy_weaken * tower.aura_power)


# --- Repair --------------------------------------------------------------

func _towers_repair(delta: float) -> void:
	for list in [_heal_flashes, _bursts, _popups, _shot_effects]:
		for i in range(list.size() - 1, -1, -1):
			list[i].time -= delta
			if list[i].time <= 0.0:
				list.remove_at(i)
	var island := _view.island
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.type != &"repair" or tower.is_part:
			continue
		tower.attack_cooldown = maxf(tower.attack_cooldown - delta, 0.0)
		tower.did_work = tower.did_work or tower.attack_cooldown > 0.0
		if tower.attack_cooldown > 0.0:
			continue
		var profile := RepairProfiles.for_tile(island, coord)
		var damaged := island.damaged_in_reach(coord, profile.reach())
		if damaged.is_empty():
			continue
		tower.saw_target = true
		if profile.mode == &"over_time":
			# Heals over time don't stack: targets that already have one are passed over.
			for i in range(damaged.size() - 1, -1, -1):
				if island.has_heal_over_time(damaged[i].coord, damaged[i].tower):
					damaged.remove_at(i)
			if damaged.is_empty():
				continue
		# Only pay (and cool down) when the heal actually happens.
		if not _can_repair(coord, profile, damaged):
			continue
		var power := EnergyGrid.draw_energy(island, coord, profile.energy_per_heal)
		if power <= 0.0:
			continue
		tower.attack_cooldown = profile.cooldown / power
		tower.did_work = true
		island.add_xp(coord, 1.0)
		match profile.mode:
			&"redistribute":
				_redistribute(coord, profile, damaged)
			&"lifesteal":
				_lifesteal(coord, profile, damaged[0])
			_:
				for target in damaged.slice(0, profile.targets):
					var amount := profile.amount * profile.falloff[HexMath.distance(coord, target.coord)]
					if profile.mode == &"over_time":
						island.add_heal_over_time(target.coord, target.tower, amount, profile.duration)
						island.track(coord, &"healed", amount)
					else:
						island.track(coord, &"healed", island.heal(target.coord, target.tower, amount))
					_flash(coord, target.coord, profile.color)


func _can_repair(coord: Vector2i, profile: RepairProfile, damaged: Array[Dictionary]) -> bool:
	match profile.mode:
		&"redistribute":
			return _donor_for(coord, profile, damaged[0]) != {}
		&"lifesteal":
			return _nearest_enemy(_view.hex_center_world(coord), profile.reach()) != null
	return true


## Plains: moves HP from the healthiest building or ground in reach to the weakest one.
func _redistribute(coord: Vector2i, profile: RepairProfile, damaged: Array[Dictionary]) -> void:
	var island := _view.island
	var target: Dictionary = damaged[0]
	var donor := _donor_for(coord, profile, target)
	var wanted := profile.amount * profile.falloff[HexMath.distance(coord, target.coord)]
	var taken := island.drain(donor.coord, donor.tower, wanted)
	island.track(coord, &"healed", island.heal(target.coord, target.tower, taken))
	_flash(donor.coord, target.coord, profile.color)


## A donor must be clearly healthier than the target and stay above half HP.
func _donor_for(coord: Vector2i, profile: RepairProfile, target: Dictionary) -> Dictionary:
	var island := _view.island
	var best := {}
	var best_ratio := maxf(0.5, target.ratio + 0.2)
	for c in HexMath.area(coord, profile.reach()):
		var tile := island.get_tile(c)
		if tile == null:
			continue
		for is_tower in [true, false]:
			if is_tower and tile.tower == null:
				continue
			if c == target.coord and is_tower == target.tower:
				continue
			var ratio := island.health_ratio(c, is_tower)
			if ratio > best_ratio:
				best_ratio = ratio
				best = {coord = c, tower = is_tower, ratio = ratio}
	return best


## Swamp: drains the nearest enemy in reach and heals the weakest target with it.
func _lifesteal(coord: Vector2i, profile: RepairProfile, target: Dictionary) -> void:
	var origin := _view.hex_center_world(coord)
	var enemy := _nearest_enemy(origin, profile.reach())
	var before := enemy.hp
	enemy.take_damage(profile.amount)
	var stolen := before - maxf(enemy.hp, 0.0)
	var share := profile.falloff[HexMath.distance(coord, target.coord)]
	_view.island.track(coord, &"healed", _view.island.heal(target.coord, target.tower, stolen * share))
	_heal_flashes.append({from = enemy.global_position, to = origin, color = profile.color, time = HEAL_FLASH_TIME})
	_flash(coord, target.coord, profile.color)


func _nearest_enemy(origin: Vector2, reach_hexes: int) -> Enemy:
	var range_px := (reach_hexes + 0.5) * HexMath.SQRT3 * _view.hex_size
	var best: Enemy = null
	var best_distance := range_px
	for enemy in enemies():
		var d := origin.distance_to(enemy.global_position)
		if d <= best_distance and is_enemy_visible(enemy):
			best_distance = d
			best = enemy
	return best


func _flash(from: Vector2i, to: Vector2i, color: Color) -> void:
	_heal_flashes.append({from = _view.hex_center_world(from), to = _view.hex_center_world(to), color = color, time = HEAL_FLASH_TIME})


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for p in _popups:
		var t: float = p.time / POPUP_TIME
		var at := to_local(p.position) + Vector2(-60, -20 - (1.0 - t) * 24)
		var color: Color = p.color
		draw_string_outline(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 4, Color(0, 0, 0, 0.7 * t))
		draw_string(font, at, p.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(color, t))
	for burst in _bursts:
		var t: float = burst.time / BURST_TIME
		var at := to_local(burst.position)
		draw_circle(at, 22.0 * (1.0 - t) + 6.0, Color(1, 0.55, 0.15, 0.55 * t))
		draw_circle(at, 9.0 * t, Color(1, 0.9, 0.5, t))
	for flash in _heal_flashes:
		var alpha: float = flash.time / HEAL_FLASH_TIME
		var a := to_local(flash.from)
		var b := to_local(flash.to)
		var color: Color = flash.color
		draw_line(a, b, Color(color, 0.3 * alpha), 7.0, true)
		draw_line(a, b, Color(color, alpha), 2.0, true)
		draw_circle(b, 6.0 * alpha + 2.0, Color(color, 0.6 * alpha))
	for siphon in _siphons:
		_draw_siphon(siphon)
	for i in _beams.size():
		_draw_beam(to_local(_beams[i][0]), to_local(_beams[i][1]), _beam_colors[i], _beam_styles[i])
	for effect in _shot_effects:
		_draw_shot_effect(effect)
	_draw_overheat()


## Overheated beam towers: a red glow on the turret tip that fades as the lockout runs out.
func _draw_overheat() -> void:
	var island := _view.island
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.overheat <= 0.0:
			continue
		var t := tower.overheat / AttackProfile.OVERHEAT_TIME
		var tip := to_local(_view.hex_center_world(coord) + Vector2.from_angle(tower.aim) * _view.hex_size * MUZZLE_REACH)
		draw_circle(tip, 7.0, Color(1.0, 0.25, 0.1, 0.35 * t))
		draw_circle(tip, 3.5, Color(1.0, 0.45, 0.25, 0.9 * t))


## HQ siphon: a purple stream with motes flowing from the enemy into the HQ, and a green
## thread on to the building it heals.
func _draw_siphon(siphon: Dictionary) -> void:
	var a := to_local(siphon.from)
	var b := to_local(siphon.to)
	var color := HqWeapons.SIPHON_COLOR
	draw_line(a, b, Color(color, 0.25), 9.0, true)
	draw_line(a, b, Color(color, 0.8), 2.0, true)
	var phase := fmod(Time.get_ticks_msec() / 600.0, 1.0)
	for i in 5:
		var t := fmod(phase + i / 5.0, 1.0)
		draw_circle(a.lerp(b, t), 3.0, Color(color.lightened(0.4), 0.9))
	if siphon.heal_to != null:
		var c := to_local(siphon.heal_to)
		draw_line(b, c, Color(HqWeapons.HEAL_COLOR, 0.25), 6.0, true)
		draw_line(b, c, Color(HqWeapons.HEAL_COLOR, 0.8), 1.5, true)
		draw_circle(c, 4.0, Color(HqWeapons.HEAL_COLOR, 0.7))


## A beam from `a` to `b` (local) in its style: the laser shimmers with a white core and a
## sizzling hot spot, the water jet is a sagging, wavy stream that splashes on the target.
func _draw_beam(a: Vector2, b: Vector2, color: Color, style: StringName) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	match style:
		&"laser":
			var pulse := 0.5 + 0.5 * sin(t * 14.0)
			draw_line(a, b, Color(color, 0.18 + 0.12 * pulse), 9.0 + 3.0 * pulse, true)
			draw_line(a, b, Color(color, 0.6), 4.0, true)
			draw_line(a, b, Color(1, 1, 0.96), 1.6, true)
			# Muzzle glow and a turning flare at the crystal tip.
			draw_circle(a, 6.0 + 2.0 * pulse, Color(color, 0.35))
			draw_circle(a, 3.0, Color(1, 1, 0.95, 0.9))
			var flare := Vector2(7.0 + 3.0 * pulse, 0).rotated(t * 3.0)
			draw_line(a - flare, a + flare, Color(1, 0.95, 0.85, 0.7), 1.2, true)
			draw_line(a - flare.orthogonal(), a + flare.orthogonal(), Color(1, 0.95, 0.85, 0.7), 1.2, true)
			# Sizzling hot spot on the target.
			draw_circle(b, 4.0 + 1.5 * pulse, Color(color, 0.55))
			draw_circle(b, 2.0, Color(1, 1, 0.9))
			for k in 3:
				var spark := Vector2.from_angle(t * 23.0 + k * 2.1) * (5.0 + 4.0 * fmod(t * 5.0 + k * 0.37, 1.0))
				draw_circle(b + spark, 1.1, Color(1, 0.85, 0.55, 0.9))
		&"water":
			var length := a.distance_to(b)
			var dir := (b - a) / maxf(length, 0.01)
			var side := dir.orthogonal()
			var points := PackedVector2Array()
			var steps := maxi(int(length / 6.0), 2)
			for k in steps + 1:
				var u := float(k) / steps
				var wave := sin(u * 12.0 - t * 18.0) * 1.6 * sin(u * PI)
				var sag := Vector2(0, 6.0 * u * (1.0 - u) * length / 60.0)
				points.append(a.lerp(b, u) + side * wave + sag)
			draw_polyline(points, Color(color, 0.3), 7.0, true)
			draw_polyline(points, Color(color, 0.85), 3.0, true)
			draw_polyline(points, Color(1, 1, 1, 0.5), 1.0, true)
			# Droplets running along the stream.
			for k in 4:
				var u := fmod(t * 2.2 + k / 4.0, 1.0)
				draw_circle(points[int(u * steps)], 1.6, Color(1, 1, 1, 0.8))
			# Splash spray at the target.
			for k in 6:
				var phase := fmod(t * 3.0 + k / 6.0, 1.0)
				var spray := Vector2.from_angle(PI + dir.angle() + (k - 2.5) * 0.45) * (4.0 + 10.0 * phase)
				draw_circle(b + spray + Vector2(0, 6.0 * phase * phase), 1.8 * (1.0 - phase) + 0.6, Color(color.lightened(0.3), 1.0 - phase))
		_:
			draw_line(a, b, Color(color, 0.25), 8.0, true)
			draw_line(a, b, color, 2.5, true)


## Muzzle flashes and impacts of projectile shots, by the shot's style.
func _draw_shot_effect(effect: Dictionary) -> void:
	var at := to_local(effect.position)
	var left: float = effect.time / effect.life
	var age := 1.0 - left
	var color: Color = effect.color
	var dir := Vector2.from_angle(effect.angle)
	if effect.kind == &"muzzle":
		match effect.style:
			&"slime":
				draw_circle(at + dir * 3.0, 4.0 * left + 1.0, Color(color, 0.6 * left))
			&"thorns":
				draw_circle(at, 4.0 * left, Color("c8d27a", 0.6 * left))
			_:
				# Flash: flame tongues fanning out from the barrel tip in the firing direction
				# (narrow at the muzzle, wide in front), and a hot puff at the tip.
				var side := dir.orthogonal()
				for k in [-1, 0, 1]:
					var tongue := dir.rotated(k * 0.5) * (12.0 if k == 0 else 7.0) * (0.6 + 0.4 * left)
					var flame := PackedVector2Array([at + side * 1.2, at + tongue + tongue.orthogonal().normalized() * 2.5,
						at + tongue * 1.25, at + tongue - tongue.orthogonal().normalized() * 2.5, at - side * 1.2])
					draw_colored_polygon(flame, Color(1, 0.7, 0.25, 0.9 * left))
				draw_circle(at + dir * 2.0, 3.0 * left + 1.0, Color(1, 0.97, 0.8, left))
		return
	# Bigger shots make bigger blasts (the machine cannon's tracers stay small).
	var scale: float = clampf(effect.size / 4.5, 0.6, 1.4)
	if effect.kind == &"smoke":
		# Grey puffs drifting on past the target, growing and fading.
		var drift := dir * (6.0 + 16.0 * age) * scale + Vector2(0, -5.0 * age)
		for k in 3:
			var offset := Vector2.from_angle(effect.angle + (k - 1) * 1.3) * 3.5 * scale * (1.0 + age)
			draw_circle(at + drift + offset, (3.0 + 5.0 * age) * scale, Color(0.45, 0.43, 0.42, 0.45 * left))
		return
	if effect.kind == &"blast":
		# Small fire blast: a hot white-yellow core, an orange ball and flame tongues.
		var r := (3.0 + 7.0 * sqrt(age)) * scale
		draw_circle(at, r, Color(1, 0.45, 0.1, 0.7 * left))
		for k in 5:
			var d := Vector2.from_angle(effect.angle + k * TAU / 5.0 + 0.3)
			draw_circle(at + d * r * 0.8, r * 0.45, Color(1, 0.6, 0.15, 0.8 * left))
		draw_circle(at, r * 0.55, Color(1, 0.85, 0.35, left))
		draw_circle(at, r * 0.25 * left, Color(1, 1, 0.9, left))
		return
	match effect.style:
		&"thorns":
			# Splinters.
			for k in 3:
				var d := Vector2.from_angle(effect.angle + k * TAU / 3.0)
				draw_line(at + d * 2.0, at + d * (2.0 + 6.0 * age), Color(color, left), 1.4, true)
		&"slime":
			# Splat: a flattened blot and a few falling drops.
			draw_set_transform(at, 0.0, Vector2(1.4, 0.8))
			draw_circle(Vector2.ZERO, 3.0 + 5.0 * age, Color(color, 0.55 * left))
			draw_set_transform(Vector2.ZERO)
			for k in 4:
				var d := Vector2.from_angle(effect.angle + k * TAU / 4.0)
				draw_circle(at + d * (4.0 + 6.0 * age) + Vector2(0, 5.0 * age * age), 1.4, Color(color, left))
