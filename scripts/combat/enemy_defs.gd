class_name EnemyDefs
extends RefCounted
## Enemy types and their behaviour patterns (GDD §8.7). Placeholder numbers until playtesting.
##
## Behaviours:
## - &"ram":      flies to its target and damages it on contact
## - &"standoff": flies until its target is in weapon range, then holds position and shoots
## - &"orbit":    circles the island just inside weapon range of the outer buildings, shooting
## - &"flyover":  crosses the island in straight passes, bombing the tile below; turns and repeats
##
## `targets` is the enemy's target priority (GDD §8.7): the first entry that finds something
## wins, the nearest of its kind. Each enemy keeps its own copy (Enemy.target_priority), so
## chips can change it later. Entries:
## - &"nearest":  the nearest building of any type
## - a tower type (&"wall", &"attack", &"energy", &"repair", &"aura", &"scout", &"warehouse")
## - &"hq":       the main building, at any distance
## - &"ground":   the nearest standing tile without a building (the HQ counts), at any distance
## - &"strafe":   bombers only: a pass over a random spot near the island centre
## Buildings are only sought within Combat.building_seek_range (orbiters: weapon range).

const TYPES := {
	&"rammer": {
		behaviour = &"ram", hp = 60.0, speed = 55.0, contact_dps = 6.0,
		targets = [&"nearest", &"ground"],
	},
	&"gunboat": {
		behaviour = &"standoff", hp = 80.0, speed = 42.0,
		range_hexes = 3.0, damage = 8.0, cooldown = 1.6, projectile_speed = 260.0,
		targets = [&"attack", &"nearest", &"ground"],
	},
	&"corsair": {
		behaviour = &"orbit", hp = 40.0, speed = 85.0,
		range_hexes = 2.5, damage = 4.0, cooldown = 0.8, projectile_speed = 320.0,
		targets = [&"energy", &"warehouse", &"nearest", &"ground"],
	},
	&"bomber": {
		behaviour = &"flyover", hp = 120.0, speed = 58.0,
		damage = 15.0, cooldown = 0.7,
		targets = [&"strafe"],
	},
}

## Loot multiplier per type (blueprints and biome stones): swarmers drop less, big ships a
## little more. Fixed per type, so stronger rounds don't change it.
const DROP_FACTOR := {&"corsair": 0.5, &"rammer": 0.8, &"gunboat": 1.1, &"bomber": 1.2}

## Light enemies make up the early waves; mediums are sprinkled in from MEDIUM_FROM_WAVE,
## heavies (bombers) from HEAVY_FROM_WAVE. Waves only grow in size, never in strength.
const LIGHT: Array[StringName] = [&"corsair", &"rammer"]
const MEDIUM: Array[StringName] = [&"gunboat"]
const HEAVY: Array[StringName] = [&"bomber"]
const FIRST_WAVE_SIZE := 3
const MEDIUM_FROM_WAVE := 3
const HEAVY_FROM_WAVE := 6


## Enemy types of wave `wave` (1-based), grouped by type so each group can fly as one
## formation: e.g. wave 1 = 3 light, wave 3 = 4 light + 1 medium, wave 6 = 6 light, 1-2
## medium, 1 heavy.
## `count_factor` scales the wave size (higher rounds bring more enemies).
static func wave_plan(wave: int, count_factor := 1.0) -> Array[StringName]:
	var size := maxi(1, roundi((FIRST_WAVE_SIZE + (wave - 1)) * count_factor))
	var mediums := 0
	var heavies := 0
	if wave >= MEDIUM_FROM_WAVE:
		mediums = maxi(1, int(size * minf(0.1 + 0.04 * (wave - MEDIUM_FROM_WAVE), 0.35)))
	if wave >= HEAVY_FROM_WAVE:
		heavies = maxi(1, int(size * minf(0.08 + 0.03 * (wave - HEAVY_FROM_WAVE), 0.2)))
	var lights := size - mediums - heavies
	var plan: Array[StringName] = []
	# Light enemies come as one type per wave early on, both types mixed later.
	for i in lights:
		plan.append(LIGHT[(wave + (i * 2 / maxi(lights, 1) if wave >= MEDIUM_FROM_WAVE else 0)) % LIGHT.size()])
	for i in mediums:
		plan.append(MEDIUM[i % MEDIUM.size()])
	for i in heavies:
		plan.append(HEAVY[i % HEAVY.size()])
	plan.sort()
	return plan


## Share of each type in a mixed random pick (debug keys, balance simulation).
const WAVE_MIX := {&"rammer": 0.4, &"gunboat": 0.25, &"corsair": 0.2, &"bomber": 0.15}


static func pick_random() -> StringName:
	var roll := randf()
	for kind in WAVE_MIX:
		roll -= WAVE_MIX[kind]
		if roll <= 0.0:
			return kind
	return &"rammer"
