class_name TowerDefs
extends RefCounted
## Static data for the base tower types (GDD §6.4). Placeholder numbers until playtesting.

## Clicking a tower cycles through the types in this order.
const TYPES: Array[StringName] = [
	&"attack", &"wall", &"energy", &"repair", &"aura", &"scout", &"warehouse",
]

const BASE_HP := {
	&"attack": 100.0,
	&"wall": 400.0,
	&"energy": 120.0,
	&"repair": 100.0,
	&"aura": 100.0,
	&"scout": 80.0,
	&"warehouse": 200.0,
}

## Wall (Tier 0): regenerates from its own energy after this long without damage.
const WALL_REST_DELAY := 10.0
## Share of max HP the resting wall regains per second.
const WALL_REST_REGEN := 0.02


static func base_hp(type: StringName) -> float:
	return BASE_HP.get(type, 100.0)
