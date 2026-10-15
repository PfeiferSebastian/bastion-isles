class_name Combat
extends Node2D
## Milestone 3 combat sandbox: spawns dummy enemies around the island, moves them
## to the nearest tower, and lets Attack towers aim and fire based on their tile.
## Keys: P toggles waves, W spawns a wave right away.

@export var island_view_path: NodePath
@export var spawn_interval := 3.0
@export var spawn_distance := 700.0
@export var wave_size := 5
@export var max_enemies := 30
## Enemies stop and attack at this distance from a tower's centre.
@export var contact_range := 38.0
## Enemies with nothing to attack hover at this distance from the HQ.
@export var idle_range := 90.0
## How close an enemy must be to a laser's line to get hit.
@export var beam_hit_radius := 12.0

var waves_enabled := true
var kills := 0

var _view: IslandView
var _spawn_timer := 0.0
var _enemy_layer := Node2D.new()
var _projectile_layer := Node2D.new()
var _beams: Array[PackedVector2Array] = []
var _beam_colors: Array[Color] = []


func _ready() -> void:
	_view = get_node(island_view_path)
	add_child(_enemy_layer)
	add_child(_projectile_layer)


func _process(delta: float) -> void:
	if waves_enabled:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_spawn_enemy()
	_beams.clear()
	_beam_colors.clear()
	for enemy in enemies():
		enemy.tick_statuses(delta)
		if not enemy.is_dead:
			_move_and_attack(enemy, delta)
	_towers_attack(delta)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P:
			waves_enabled = not waves_enabled
		KEY_W:
			spawn_wave()


func enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for child in _enemy_layer.get_children():
		var enemy := child as Enemy
		if enemy and not enemy.is_dead:
			result.append(enemy)
	return result


func spawn_wave() -> void:
	for i in wave_size:
		_spawn_enemy()


func _spawn_enemy() -> void:
	if enemies().size() >= max_enemies:
		return
	var enemy := Enemy.new()
	enemy.died.connect(_on_enemy_died)
	_enemy_layer.add_child(enemy)
	enemy.global_position = _view.global_position + Vector2.from_angle(randf() * TAU) * spawn_distance


func _on_enemy_died(enemy: Enemy) -> void:
	kills += 1
	EnergyGrid.notify_enemy_died(_view.island, _view.world_to_hex(enemy.global_position))


# --- Enemies -------------------------------------------------------------

func _move_and_attack(enemy: Enemy, delta: float) -> void:
	var target: Variant = _nearest_tower(enemy.global_position)
	var goal := _view.global_position
	var stop := idle_range
	if target != null:
		goal = _view.hex_center_world(target)
		stop = contact_range
	var to := goal - enemy.global_position
	var distance := to.length()
	if distance > 0.01:
		enemy.face(to.angle())
	if distance > stop:
		enemy.global_position += to / distance * minf(enemy.speed * delta, distance - stop)
	elif target != null:
		_view.island.damage_tower(target, enemy.damage_output() * delta)


## Coord of the tower closest to `from`, or null when the island has none.
func _nearest_tower(from: Vector2) -> Variant:
	var best: Variant = null
	var best_distance := INF
	for coord in _view.island.coords():
		if _view.island.get_tower(coord) == null:
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
				_fire_beam(origin, targets[i], range_px, profile, beam_power, delta)
		if profile.has_projectile() and tower.attack_cooldown <= 0.0:
			var power := EnergyGrid.draw_energy(island, coord, profile.energy_per_shot)
			if power > 0.0:
				# Below 1 (e.g. Forest without energy) the tower fires more slowly.
				tower.attack_cooldown = profile.cooldown / power
				_fire_projectile(origin, targets[0], profile)


## Enemies within range, nearest first.
func _targets_in_range(origin: Vector2, range_px: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy in enemies():
		if origin.distance_to(enemy.global_position) <= range_px:
			result.append(enemy)
	result.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	return result


## The laser pierces: it runs to full range and hits every enemy along the line.
func _fire_beam(origin: Vector2, target: Enemy, range_px: float, profile: AttackProfile, power: float, delta: float) -> void:
	if power <= 0.0:
		return
	var end := origin + (target.global_position - origin).normalized() * range_px
	for enemy in enemies():
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, origin, end)
		if closest.distance_to(enemy.global_position) <= beam_hit_radius:
			enemy.take_damage(profile.beam_dps * power * delta)
	_beams.append(PackedVector2Array([origin, end]))
	_beam_colors.append(profile.beam_color)


func _fire_projectile(origin: Vector2, target: Enemy, profile: AttackProfile) -> void:
	var projectile := Projectile.new()
	projectile.target = target
	projectile.profile = profile
	_projectile_layer.add_child(projectile)
	projectile.global_position = origin


func _draw() -> void:
	for i in _beams.size():
		var a := to_local(_beams[i][0])
		var b := to_local(_beams[i][1])
		var color := _beam_colors[i]
		draw_line(a, b, Color(color, 0.25), 8.0, true)
		draw_line(a, b, color, 2.5, true)
