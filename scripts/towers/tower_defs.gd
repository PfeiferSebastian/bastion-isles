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

## Towers that use energy and therefore get a storage on their tile (GDD §6.4).
const ENERGY_CONSUMERS: Array[StringName] = [&"attack", &"wall", &"repair", &"aura", &"scout"]

## Wall towers raise the max HP of adjacent buildings by this share, depending on the
## biome (faction) under the wall. Placeholder numbers.
const WALL_NEIGHBOUR_HP := {
	Biome.Type.NEUTRAL: 0.10,
	Biome.Type.FOREST: 0.10,
	Biome.Type.MOUNTAIN: 0.20,
	Biome.Type.PLAINS: 0.10,
	Biome.Type.SWAMP: 0.10,
	Biome.Type.LAKE: 0.10,
}

## Largest radius any Aura profile has.
const AURA_RADIUS_MAX := 1
## Energy per shield HP regenerated, paid from the tower's own storage.
const SHIELD_ENERGY_PER_HP := 0.05

## Largest reach any Repair profile has (used to look for nearby Repair towers).
const REPAIR_REACH_MAX := 3

## Wall (Tier 0): regenerates from its own energy after this long without damage.
const WALL_REST_DELAY := 10.0
## Share of max HP the resting wall regains per second.
const WALL_REST_REGEN := 0.02
## Energy per second the resting wall spends on regenerating.
const WALL_REST_ENERGY := 1.0


static func base_hp(type: StringName) -> float:
	return BASE_HP.get(type, 100.0)
