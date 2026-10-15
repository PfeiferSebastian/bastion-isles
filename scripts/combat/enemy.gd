class_name Enemy
extends Node2D
## Dummy enemy for milestone 3: a small airship that flies at the nearest tower and
## damages it on contact. Keeps its own status effects (thorns, poison, weaken).

signal died(enemy: Enemy)

const THORN_DURATION := 4.0
const WEAKEN_DURATION := 4.0
## Weakened enemies take this much extra damage per point of weaken ("less armour").
const WEAKEN_ARMOUR_FACTOR := 0.5

var max_hp := 60.0
var speed := 55.0
var dps := 6.0
var hp := max_hp
var is_dead := false

var _thorn_stacks := 0
var _thorn_dps := 0.0
var _thorn_time := 0.0
var _poisons: Array[Vector2] = []  # x = damage per second, y = time left
var _weaken := 0.0
var _weaken_time := 0.0


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
	# Hull pointing along +x (rotation faces the target).
	var hull := PackedVector2Array([Vector2(14, 0), Vector2(-8, -9), Vector2(-4, 0), Vector2(-8, 9)])
	draw_colored_polygon(hull, Color("7a2a2a"))
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color("2a0d0d"), 1.5, true)
	if _weaken > 0.0:
		draw_arc(Vector2.ZERO, 15, 0, TAU, 24, Color("b07be0"), 2.0, true)
	# Health bar and thorn stacks stay upright regardless of rotation.
	draw_set_transform(Vector2.ZERO, -rotation)
	for i in _thorn_stacks:
		draw_circle(Vector2(-8 + i * 4, 14), 1.8, Color("5fd068"))
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-12, -18, 24, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-12, -18, 24 * ratio, 3), Color("e05545"))
	draw_set_transform(Vector2.ZERO)
