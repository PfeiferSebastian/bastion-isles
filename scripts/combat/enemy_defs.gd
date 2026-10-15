class_name EnemyDefs
extends RefCounted
## Enemy types and their behaviour patterns (GDD §8.7). Placeholder numbers until playtesting.
##
## Behaviours:
## - &"ram":      flies to its target and damages it on contact
## - &"standoff": flies until its target is in weapon range, then holds position and shoots
## - &"orbit":    circles the island just inside weapon range of the outer buildings, shooting
## - &"flyover":  crosses the island in straight passes, bombing the tile below; turns and repeats

const TYPES := {
	&"rammer": {
		behaviour = &"ram", hp = 60.0, speed = 55.0, contact_dps = 6.0,
	},
	&"gunboat": {
		behaviour = &"standoff", hp = 80.0, speed = 42.0,
		range_hexes = 3.0, damage = 8.0, cooldown = 1.6, projectile_speed = 260.0,
	},
	&"corsair": {
		behaviour = &"orbit", hp = 40.0, speed = 85.0,
		range_hexes = 2.5, damage = 4.0, cooldown = 0.8, projectile_speed = 320.0,
	},
	&"bomber": {
		behaviour = &"flyover", hp = 120.0, speed = 58.0,
		damage = 15.0, cooldown = 0.7,
	},
}

## Share of each type in a mixed wave.
const WAVE_MIX := {&"rammer": 0.4, &"gunboat": 0.25, &"corsair": 0.2, &"bomber": 0.15}


static func pick_random() -> StringName:
	var roll := randf()
	for kind in WAVE_MIX:
		roll -= WAVE_MIX[kind]
		if roll <= 0.0:
			return kind
	return &"rammer"
