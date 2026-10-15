class_name Enemy
extends Node2D
## An enemy airship. Its type (EnemyDefs) sets stats, weapon and behaviour; Combat moves
## it. Keeps its own status effects (thorns, poison, weaken).

signal died(enemy: Enemy)

const THORN_DURATION := 4.0
const WEAKEN_DURATION := 4.0
## Weakened enemies take this much extra damage per point of weaken ("less armour").
const WEAKEN_ARMOUR_FACTOR := 0.5

var kind: StringName = &"rammer"
var behaviour: StringName = &"ram"
var max_hp := 60.0
var speed := 55.0
## Contact damage per second (rammers).
var dps := 6.0
var hp := max_hp
var is_dead := false

# Weapon (shooters and bombers)
var weapon_range_hexes := 0.0
var weapon_damage := 0.0
var weapon_cooldown := 1.0
var projectile_speed := 300.0
var cooldown_left := 0.0

# Movement state used by Combat
## Orbiters: +1 clockwise, -1 counter-clockwise.
var orbit_direction := 1.0
## Bombers: current flight direction.
var heading := Vector2.ZERO

var _thorn_stacks := 0
var _thorn_dps := 0.0
var _thorn_time := 0.0
var _poisons: Array[Vector2] = []  # x = damage per second, y = time left
var _weaken := 0.0
var _weaken_time := 0.0


## Applies the stats of `type_kind`, scaled by `factor` (wave growth).
func setup(type_kind: StringName, factor := 1.0) -> void:
	var def: Dictionary = EnemyDefs.TYPES[type_kind]
	kind = type_kind
	behaviour = def.behaviour
	max_hp = def.hp * factor
	hp = max_hp
	speed = def.speed * factor
	dps = def.get("contact_dps", 0.0) * factor
	weapon_range_hexes = def.get("range_hexes", 0.0)
	weapon_damage = def.get("damage", 0.0) * factor
	weapon_cooldown = def.get("cooldown", 1.0)
	projectile_speed = def.get("projectile_speed", 300.0)
	cooldown_left = randf() * weapon_cooldown
	orbit_direction = 1.0 if randf() < 0.5 else -1.0
	queue_redraw()


## Damage of one shot or bomb right now; weaken lowers it.
func shot_damage() -> float:
	return weapon_damage * (1.0 - _weaken)


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	hp -= amount * (1.0 + _weaken * WEAKEN_ARMOUR_FACTOR)
	queue_redraw()
	if hp <= 0.0:
		is_dead = true
		died.emit(self)
		queue_free()


func add_thorns(dps_per_stack: float, max_stacks: int) -> void:
	_thorn_dps = maxf(_thorn_dps, dps_per_stack)
	_thorn_stacks = mini(_thorn_stacks + 1, max_stacks)
	_thorn_time = THORN_DURATION


func add_poison(total: float, duration: float) -> void:
	_poisons.append(Vector2(total / duration, duration))


func add_weaken(strength: float) -> void:
	_weaken = maxf(_weaken, strength)
	_weaken_time = WEAKEN_DURATION


func thorn_stacks() -> int:
	return _thorn_stacks


## Damage per second this enemy deals right now; weaken lowers it.
func damage_output() -> float:
	return dps * (1.0 - _weaken)


## Advances status timers and applies damage over time.
func tick_statuses(delta: float) -> void:
	var dot := 0.0
	if _thorn_stacks > 0:
		dot += _thorn_stacks * _thorn_dps
		_thorn_time -= delta
		if _thorn_time <= 0.0:
			_thorn_stacks = 0
	for i in range(_poisons.size() - 1, -1, -1):
		dot += _poisons[i].x
		_poisons[i].y -= delta
		if _poisons[i].y <= 0.0:
			_poisons.remove_at(i)
	if _weaken_time > 0.0:
		_weaken_time -= delta
		if _weaken_time <= 0.0:
			_weaken = 0.0
	take_damage(dot * delta)


func face(angle: float) -> void:
	if not is_equal_approx(angle, rotation):
		rotation = angle
		# The upright health bar is drawn against the rotation, so it must be redrawn.
		queue_redraw()


func _draw() -> void:
	# Hull pointing along +x (rotation faces the movement or target).
	match kind:
		&"gunboat":
			var hull := PackedVector2Array([Vector2(12, -6), Vector2(12, 6), Vector2(-10, 9), Vector2(-10, -9)])
			draw_colored_polygon(hull, Color("5a3a3a"))
			draw_rect(Rect2(4, -2, 14, 4), Color("2a1a1a"))
			draw_circle(Vector2(-2, 0), 5.0, Color("7a4a3a"))
		&"corsair":
			var hull := PackedVector2Array([Vector2(16, 0), Vector2(-8, -11), Vector2(-3, 0), Vector2(-8, 11)])
			draw_colored_polygon(hull, Color("c0502a"))
			draw_line(Vector2(-6, -10), Vector2(-12, -14), Color("2a0d0d"), 2.0)
			draw_line(Vector2(-6, 10), Vector2(-12, 14), Color("2a0d0d"), 2.0)
		&"bomber":
			var hull := PackedVector2Array([Vector2(14, 0), Vector2(6, -14), Vector2(-12, -12), Vector2(-14, 0), Vector2(-12, 12), Vector2(6, 14)])
			draw_colored_polygon(hull, Color("3a3a44"))
			draw_rect(Rect2(-6, -4, 10, 8), Color("1a1a1e"))
		_:
			var hull := PackedVector2Array([Vector2(14, 0), Vector2(-8, -9), Vector2(-4, 0), Vector2(-8, 9)])
			draw_colored_polygon(hull, Color("7a2a2a"))
			draw_polyline(hull + PackedVector2Array([hull[0]]), Color("2a0d0d"), 1.5, true)
	if _weaken > 0.0:
		draw_arc(Vector2.ZERO, 17, 0, TAU, 24, Color("b07be0"), 2.0, true)
	# Health bar and thorn stacks stay upright regardless of rotation.
	draw_set_transform(Vector2.ZERO, -rotation)
	for i in _thorn_stacks:
		draw_circle(Vector2(-8 + i * 4, 16), 1.8, Color("5fd068"))
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-12, -20, 24, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-12, -20, 24 * ratio, 3), Color("e05545"))
	draw_set_transform(Vector2.ZERO)
