class_name Combat
extends Node2D
## Combat: sends waves of enemies (EnemyDefs.wave_plan) at the island in formations, moves
## them by their behaviour, and lets the towers aim, fire and repair based on their tile.
## Keys: P toggles waves, W spawns the next wave right away, F1-F4 spawn one enemy of each type.

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
## Seconds before the first enemies come, so the player can look around and build.
@export var mission_start_delay := 10.0
## Seconds without enemies after which the fight counts as over and the ground is repaired.
@export var battle_end_delay := 5.0

## A rare drop was found (biome stone or blueprint), for the HUD notice.
signal item_found(text: String)
## The mission goal is reached: no more enemies spawn and the player may leave.
signal mission_completed

var waves_enabled := true
var kills := 0
## Seconds until the mission starts (enemies spawn only after that).
var mission_countdown := 0.0
var mission_done := false
## Rounds proceeded past the first (0 = the first round).
var mission_round := 0
var _base_kill_goal := 0
## Fog of war; when set, towers only target enemies in open sky. Null = everything visible.
var fog: FogOfWar

var _view: IslandView
## Waves sent so far.
var wave := 0
var _wave_timer := 0.0
var _quiet_time := 0.0
var _enemy_layer := Node2D.new()
var _projectile_layer := Node2D.new()
var _beams: Array[PackedVector2Array] = []
var _beam_colors: Array[Color] = []
## Short-lived heal lines: {from, to, color, time}.
var _heal_flashes: Array[Dictionary] = []
## Bomb impacts: {position, time}.
var _bursts: Array[Dictionary] = []
## Floating loot texts: {position, text, color, time}.
var _popups: Array[Dictionary] = []
var _loot_rng := RandomNumberGenerator.new()
## Seconds until the HQ cannon may fire again.
var _hq_cooldown := 0.0

const HEAL_FLASH_TIME := 0.35
const BURST_TIME := 0.4
const POPUP_TIME := 1.2


func _ready() -> void:
	_view = get_node(island_view_path)
	add_child(_enemy_layer)
	add_child(_projectile_layer)
	mission_countdown = mission_start_delay
	_base_kill_goal = mission_kill_goal


func _process(delta: float) -> void:
	if mission_countdown > 0.0:
		mission_countdown = maxf(mission_countdown - delta, 0.0)
	elif waves_enabled and not mission_done:
		_wave_timer -= delta
		if enemies().is_empty():
			_wave_timer = minf(_wave_timer, wave_gap_when_clear)
		if _wave_timer <= 0.0:
			spawn_wave()
	_beams.clear()
	_beam_colors.clear()
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
	wave += 1
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


## Spawns one enemy of `kind` (random mix if empty) on a ring around the island; none once
## the mission is done.
func spawn_enemy(kind: StringName = &"", factor := 1.0, at: Variant = null, speed_factor := -1.0) -> Enemy:
	if mission_done or enemies().size() >= max_enemies:
		return null
	var enemy := Enemy.new()
	enemy.setup(kind if kind != &"" else EnemyDefs.pick_random(), factor, speed_factor)
	enemy.died.connect(_on_enemy_died)
	_enemy_layer.add_child(enemy)
	enemy.global_position = at if at != null else _view.global_position + Vector2.from_angle(randf() * TAU) * spawn_distance
	return enemy


## Enemy HP and damage multiplier of the current round.
func strength_factor() -> float:
	return pow(ROUND_STRENGTH, mission_round)


## Enemy count multiplier of the current round.
func count_factor() -> float:
	return pow(ROUND_COUNT, mission_round)


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
	EnergyGrid.notify_enemy_died(_view.island, _view.world_to_hex(enemy.global_position))
	var treasury := _view.island.treasury
	var loot := Economy.roll_loot(enemy, _loot_rng, _view.island.missing_blueprint_kinds())
	var at := enemy.global_position
	treasury.add_gold(loot.gold)
	popup(at, "+%d gold" % loot.gold, Color("ffd23f"))
	if loot.stone >= 0:
		var stone := Inventory.stone_item(loot.stone)
		treasury.inventory.add(stone)
		popup(at + Vector2(0, -16), "+1 " + Inventory.label_of(stone), Color("8fd3ff"))
		item_found.emit("Found: %s" % Inventory.label_of(stone))
	if loot.blueprint != &"":
		var name := String(loot.blueprint).capitalize()
		var built := _view.island.add_blueprint(loot.blueprint)
		popup(at + Vector2(0, -32), "Blueprint: " + name, Color("f0d28a"))
		if built:
			item_found.emit("Blueprints complete: +1 %s" % (name if loot.blueprint == &"tile" else name + " tower"))
		else:
			item_found.emit("Blueprint found: %s (%d/%d)" % [name, treasury.blueprints[loot.blueprint], _view.island.blueprints_needed(loot.blueprint)])
	if not mission_done and kills >= mission_kill_goal:
		mission_done = true
		# The fight is won: towers stop gaining experience.
		_view.island.gains_xp = false
		_clear_sky()
		mission_completed.emit()


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


## Target for an enemy at `from`: a building within seek reach, otherwise the nearest ground.
func _pick_target(from: Vector2) -> Variant:
	var tower: Variant = _nearest(from, true, building_seek_range)
	# Ground (tiles, HQ) has lots of HP but is only attacked when no building is in reach.
	return tower if tower != null else _nearest(from, false, INF)


## Rammer: flies to its target and damages it on contact.
func _ram(enemy: Enemy, delta: float) -> void:
	var target: Variant = _pick_target(enemy.global_position)
	var goal := _view.global_position if target == null else _view.hex_center_world(target)
	var stop := idle_range if target == null else contact_range
	if _approach(enemy, goal, stop, delta) and target != null:
		_hit(target, enemy.damage_output() * delta)


## Gunboat: closes in until its target is in weapon range, then holds position and shoots.
func _standoff(enemy: Enemy, delta: float) -> void:
	var target: Variant = _pick_target(enemy.global_position)
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
	var target: Variant = _nearest(enemy.global_position, true, range_px)
	if target == null:
		target = _nearest(enemy.global_position, false, range_px)
	if target != null:
		_shoot(enemy, target)


## Bomber: straight passes over the island, bombing the tile below; turns and comes back.
func _flyover(enemy: Enemy, delta: float) -> void:
	var center := _view.global_position
	var turn_radius := _island_radius_px() + 300.0
	var away := enemy.global_position - center
	if enemy.heading == Vector2.ZERO or (away.length() > turn_radius and away.dot(enemy.heading) > 0.0):
		# New pass through the island, slightly off-centre.
		var aim := center + Vector2.from_angle(randf() * TAU) * randf() * _view.hex_size * 1.5
		enemy.heading = (aim - enemy.global_position).normalized()
	enemy.global_position += enemy.heading * enemy.speed * delta
	enemy.face(enemy.heading.angle())
	var below := _view.world_to_hex(enemy.global_position)
	var tile := _view.island.get_tile(below)
	if tile and not tile.destroyed and enemy.cooldown_left <= 0.0:
		enemy.cooldown_left = enemy.weapon_cooldown
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
	enemy.cooldown_left = enemy.weapon_cooldown
	_reveal_shooter(enemy)
	var shot := EnemyProjectile.new()
	shot.target_position = _view.hex_center_world(target) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	shot.speed = enemy.projectile_speed
	shot.on_hit = _hit.bind(target, enemy.shot_damage())
	_projectile_layer.add_child(shot)
	shot.global_position = enemy.global_position


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


## Closest coord within `max_distance` px: a tower when `towers`, otherwise standing ground
## without a tower (including the HQ while it has HP). Null if there is none.
func _nearest(from: Vector2, towers: bool, max_distance: float) -> Variant:
	var island := _view.island
	var best: Variant = null
	var best_distance := max_distance * max_distance
	for coord in island.coords():
		var tile := island.get_tile(coord)
		if towers:
			if tile.tower == null:
				continue
		elif tile.tower != null or tile.destroyed or tile.hp <= 0.0:
			continue
		var d := from.distance_squared_to(_view.hex_center_world(coord))
		if d < best_distance:
			best_distance = d
			best = coord
	return best


# --- Towers --------------------------------------------------------------

func _towers_attack(delta: float) -> void:
	var island := _view.island
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.type != &"attack":
			continue
		var profile := AttackProfiles.for_tile(island, coord)
		var origin := _view.hex_center_world(coord)
		var range_px := profile.range_hexes * HexMath.SQRT3 * _view.hex_size
		var targets := _targets_in_range(origin, range_px)
		tower.attack_cooldown = maxf(tower.attack_cooldown - delta, 0.0)
		if targets.is_empty():
			continue
		_view.aim_tower(coord, (targets[0].global_position - origin).angle())
		var beams := mini(profile.beam_count, targets.size())
		if beams > 0:
			var beam_power := EnergyGrid.draw_energy(island, coord, profile.beam_energy * beams * delta)
			for i in beams:
				_fire_beam(origin, targets[i], profile, beam_power, delta)
			island.add_xp(coord, beam_power * delta)
		if profile.has_projectile() and tower.attack_cooldown <= 0.0:
			var power := EnergyGrid.draw_energy(island, coord, profile.energy_per_shot)
			if power > 0.0:
				# Below 1 (e.g. Forest without energy) the tower fires more slowly.
				tower.attack_cooldown = profile.cooldown / power
				_fire_projectile(origin, targets[0], profile)
				island.add_xp(coord, 1.0)


## The HQ fires its own cannon at the nearest visible enemy (needs no energy).
func _hq_attack(delta: float) -> void:
	var hq := _view.island.get_tile(Island.HQ_COORD)
	_hq_cooldown = maxf(_hq_cooldown - delta, 0.0)
	if hq == null or hq.hp <= 0.0 or _hq_cooldown > 0.0:
		return
	var profile := AttackProfiles.hq()
	var origin := _view.hex_center_world(Island.HQ_COORD)
	var targets := _targets_in_range(origin, profile.range_hexes * HexMath.SQRT3 * _view.hex_size)
	if targets.is_empty():
		return
	_hq_cooldown = profile.cooldown
	_fire_projectile(origin, targets[0], profile)


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
func _fire_beam(origin: Vector2, target: Enemy, profile: AttackProfile, power: float, delta: float) -> void:
	if power <= 0.0:
		return
	target.take_damage(profile.beam_dps * power * delta)
	_beams.append(PackedVector2Array([origin, target.global_position]))
	_beam_colors.append(profile.beam_color)


func _fire_projectile(origin: Vector2, target: Enemy, profile: AttackProfile) -> void:
	var projectile := Projectile.new()
	projectile.target = target
	projectile.profile = profile
	_projectile_layer.add_child(projectile)
	projectile.global_position = origin


## Swamp Aura towers weaken every enemy inside their radius.
func _aura_debuffs() -> void:
	var island := _view.island
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.type != &"aura" or tower.aura_power <= 0.0:
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
	for list in [_heal_flashes, _bursts, _popups]:
		for i in range(list.size() - 1, -1, -1):
			list[i].time -= delta
			if list[i].time <= 0.0:
				list.remove_at(i)
	var island := _view.island
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.type != &"repair":
			continue
		tower.attack_cooldown = maxf(tower.attack_cooldown - delta, 0.0)
		if tower.attack_cooldown > 0.0:
			continue
		var profile := RepairProfiles.for_tile(island, coord)
		var damaged := island.damaged_in_reach(coord, profile.reach())
		if damaged.is_empty():
			continue
		# Only pay (and cool down) when the heal actually happens.
		if not _can_repair(coord, profile, damaged):
			continue
		var power := EnergyGrid.draw_energy(island, coord, profile.energy_per_heal)
		if power <= 0.0:
			continue
		tower.attack_cooldown = profile.cooldown / power
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
					else:
						island.heal(target.coord, target.tower, amount)
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
	island.heal(target.coord, target.tower, taken)
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
	_view.island.heal(target.coord, target.tower, stolen * share)
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
	for i in _beams.size():
		var a := to_local(_beams[i][0])
		var b := to_local(_beams[i][1])
		var color := _beam_colors[i]
		draw_line(a, b, Color(color, 0.25), 8.0, true)
		draw_line(a, b, color, 2.5, true)
