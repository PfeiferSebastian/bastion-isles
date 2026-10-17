class_name Enemy
extends Node2D
## An enemy airship. Its type (EnemyDefs) sets stats, armour, weapon and behaviour; Combat
## moves it. Keeps its own status effects: damage-over-time stacks, weaken, attack slow.

signal died(enemy: Enemy)

## Damage over time lands in ticks of this many seconds.
const DOT_TICK := 0.2
const WEAKEN_DURATION := 4.0
## Weaken from hits stacks freely up to WEAKEN_SOFT_CAP, then each hit adds less and less
## until WEAKEN_MAX.
const WEAKEN_SOFT_CAP := 0.5
const WEAKEN_MAX := 0.75
## Weakened enemies take this much extra damage per point of weaken ("less armour").
const WEAKEN_ARMOUR_FACTOR := 0.5

var kind: StringName = &"rammer"
var behaviour: StringName = &"ram"
## What it attacks first, in order (see EnemyDefs `targets`).
var target_priority: Array[StringName] = [&"nearest", &"ground"]
var max_hp := 60.0
var speed := 55.0
## Contact damage per second (rammers).
var dps := 6.0
var hp := max_hp
var is_dead := false
## Share of direct hit damage shrugged off (see EnemyDefs).
var armor := 0.0

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
## Formation flight (see Combat._fly_in_formation): the ship in front has no offset; the
## others keep `formation_offset` (x forward, y sideways) from `formation_leader`.
var in_formation := false
var formation_leader: Enemy = null
var formation_offset := Vector2.ZERO

var _dots: Array[Vector2] = []  # x = damage per second, y = time left
var _dot_tick := 0.0
var _weaken := 0.0
var _weaken_time := 0.0
var _attack_slow := 0.0
var _attack_slow_time := 0.0


## Applies the stats of `type_kind`, HP and damage scaled by `factor`, speed by `speed_factor`
## (the same as `factor` when left out, e.g. for the balance simulation's wave growth).
func setup(type_kind: StringName, factor := 1.0, speed_factor := -1.0) -> void:
	var def: Dictionary = EnemyDefs.TYPES[type_kind]
	kind = type_kind
	behaviour = def.behaviour
	target_priority.assign(def.get("targets", [&"nearest", &"ground"]))
	max_hp = def.hp * factor
	hp = max_hp
	speed = def.speed * (factor if speed_factor < 0.0 else speed_factor)
	dps = def.get("contact_dps", 0.0) * factor
	weapon_range_hexes = def.get("range_hexes", 0.0)
	weapon_damage = def.get("damage", 0.0) * factor
	weapon_cooldown = def.get("cooldown", 1.0)
	projectile_speed = def.get("projectile_speed", 300.0)
	armor = def.get("armor", 0.0)
	cooldown_left = randf() * weapon_cooldown
	orbit_direction = 1.0 if randf() < 0.5 else -1.0
	queue_redraw()


## Damage of one shot or bomb right now; weaken lowers it.
func shot_damage() -> float:
	return weapon_damage * (1.0 - _weaken)


## Seconds until the next shot after firing: longer while the attack slow is on.
func reload_time() -> float:
	return weapon_cooldown / (1.0 - _attack_slow)


## Takes a hit: armour (less the attacker's `armor_pen`) shrugs off part of it, weaken makes
## it hurt more. Damage over time passes `ignore_armor`.
func take_damage(amount: float, armor_pen := 0.0, ignore_armor := false) -> void:
	if is_dead or amount <= 0.0:
		return
	if not ignore_armor:
		amount *= 1.0 - maxf(armor - armor_pen, 0.0)
	hp -= amount * (1.0 + _weaken * WEAKEN_ARMOUR_FACTOR)
	queue_redraw()
	if hp <= 0.0:
		is_dead = true
		died.emit(self)
		queue_free()


## A stack of damage over time: `dps` for `duration` seconds (stacks add up).
func add_dot(dps_per_stack: float, duration: float) -> void:
	_dots.append(Vector2(dps_per_stack, duration))


## Weaken from a hit: +`amount` up to WEAKEN_SOFT_CAP, then shrinking steps toward WEAKEN_MAX.
func add_weaken_stack(amount: float) -> void:
	if _weaken >= WEAKEN_SOFT_CAP:
		amount *= 1.0 - (_weaken - WEAKEN_SOFT_CAP) / (WEAKEN_MAX - WEAKEN_SOFT_CAP)
	_weaken = minf(_weaken + amount, WEAKEN_MAX)
	_weaken_time = WEAKEN_DURATION


## Weaken of at least `strength` (Swamp obelisks).
func add_weaken(strength: float) -> void:
	_weaken = maxf(_weaken, strength)
	_weaken_time = WEAKEN_DURATION


## Slows this enemy's attacks by `share` for `duration` seconds (the strongest slow counts).
func add_attack_slow(share: float, duration: float) -> void:
	_attack_slow = maxf(_attack_slow, share)
	_attack_slow_time = maxf(_attack_slow_time, duration)


func dot_stacks() -> int:
	return _dots.size()


func weaken() -> float:
	return _weaken


## Damage per second this enemy deals right now; weaken and attack slow lower it.
func damage_output() -> float:
	return dps * (1.0 - _weaken) * (1.0 - _attack_slow)


## Advances status timers and applies damage over time in ticks of DOT_TICK.
func tick_statuses(delta: float) -> void:
	_dot_tick += delta
	while _dot_tick >= DOT_TICK and not is_dead:
		_dot_tick -= DOT_TICK
		var dot := 0.0
		for i in range(_dots.size() - 1, -1, -1):
			dot += _dots[i].x * DOT_TICK
			_dots[i].y -= DOT_TICK
			if _dots[i].y <= 0.0:
				_dots.remove_at(i)
		take_damage(dot, 0.0, true)
	if _weaken_time > 0.0:
		_weaken_time -= delta
		if _weaken_time <= 0.0:
			_weaken = 0.0
	if _attack_slow_time > 0.0:
		_attack_slow_time -= delta
		if _attack_slow_time <= 0.0:
			_attack_slow = 0.0


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
		draw_arc(Vector2.ZERO, 17, 0, TAU * _weaken / WEAKEN_MAX, 24, Color("b07be0"), 2.0, true)
	if _attack_slow > 0.0:
		draw_arc(Vector2.ZERO, 20, 0, TAU, 24, Color(AttackProfiles.WATER_COLOR, 0.8), 1.5, true)
	# Health bar and thorn stacks stay upright regardless of rotation.
	draw_set_transform(Vector2.ZERO, -rotation)
	for i in mini(_dots.size(), 6):
		draw_circle(Vector2(-10 + i * 4, 16), 1.8, Color("5fd068"))
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-12, -20, 24, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-12, -20, 24 * ratio, 3), Color("e05545"))
	draw_set_transform(Vector2.ZERO)
