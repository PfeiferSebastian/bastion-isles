class_name Tower
extends RefCounted
## Runtime state of one tower standing on a tile. Max values come from the island
## (base HP × tile auras), so they are not stored here.
##
## Towers gain experience by working (see Island.add_xp) and level up to MAX_LEVEL; each
## level takes XP_GROWTH times longer than the one before. Every level above 1 makes the
## tower LEVEL_BONUS more effective.

const MAX_LEVEL := 100
## XP from level 1 to 2; each further level needs XP_GROWTH times more. With these, level 10
## takes ~250 XP, level 50 ~4200 and level 100 ~52000.
const XP_BASE := 20.0
const XP_GROWTH := 1.05
const LEVEL_BONUS := 0.01

var type: StringName
var hp: float
var shield := 0.0
var time_since_damage := 0.0
## Seconds until the tower may act again (Attack: next projectile, Repair: next heal).
var attack_cooldown := 0.0
## Aura and Scout towers: how strongly they work right now (0 = no energy, 1 = full).
var aura_power := 0.0
var xp := 0.0
## Biome tier-ups this tower already gave its tile (one per 10 levels).
var tier_ups := 0
## Highest level already announced.
var level_seen := 1


func _init(tower_type: StringName, max_hp: float) -> void:
	type = tower_type
	hp = max_hp


func level() -> int:
	return level_for_xp(xp)


## Effect multiplier from the level: +1% per level above 1.
func level_bonus() -> float:
	return 1.0 + LEVEL_BONUS * (level() - 1)


## Total XP needed to reach `level` from level 1.
static func xp_for_level(level: int) -> float:
	return XP_BASE * (pow(XP_GROWTH, clampi(level, 1, MAX_LEVEL) - 1) - 1.0) / (XP_GROWTH - 1.0)


static func level_for_xp(amount: float) -> int:
	var level := int(floor(log(1.0 + maxf(amount, 0.0) * (XP_GROWTH - 1.0) / XP_BASE) / log(XP_GROWTH) + 0.000001)) + 1
	return clampi(level, 1, MAX_LEVEL)
