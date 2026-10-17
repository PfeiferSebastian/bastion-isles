class_name GameSession
extends RefCounted
## What the island scene was opened for, set by the main menu before switching scenes:
## editing, one of the numbered missions (world-mission, e.g. "2-3") or the endless mode.

## Worlds and missions per world in the mission select (1-1 … 3-5).
const WORLDS := 3
const MISSIONS_PER_WORLD := 5

## True: edit the island without enemies (main menu "Edit Island"); false: play.
static var edit_mode := false
## The chosen mission as Vector2i(world, mission), both from 1.
static var mission := Vector2i(1, 1)
## Endless mode: waves never stop and slowly get harder; there is no kill goal.
static var endless := false


## "2-3" for world 2, mission 3.
static func mission_name(which: Vector2i = mission) -> String:
	return "%d-%d" % [which.x, which.y]


## The mission after `which` in the mission select (1-5 is followed by 2-1), or
## Vector2i.ZERO after the last one.
static func next_mission(which: Vector2i = mission) -> Vector2i:
	if which.y < MISSIONS_PER_WORLD:
		return Vector2i(which.x, which.y + 1)
	if which.x < WORLDS:
		return Vector2i(which.x + 1, 1)
	return Vector2i.ZERO


## Placeholder difficulty of a mission (0 for 1-1, rising by one per mission):
## {kill_goal, strength (enemy HP and damage), count (enemies per wave)}.
static func mission_rules(which: Vector2i = mission) -> Dictionary:
	var step := (which.x - 1) * MISSIONS_PER_WORLD + (which.y - 1)
	return {kill_goal = 80 + 10 * step, strength = 1.0 + 0.1 * step, count = 1.0 + 0.05 * step}
