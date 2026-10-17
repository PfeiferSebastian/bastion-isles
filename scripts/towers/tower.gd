class_name Tower
extends RefCounted
## Runtime state of one tower standing on a tile. Max values come from the island
## (base HP × tile auras), so they are not stored here.
##
## Towers gain experience by working (see Island.add_xp) and level up to MAX_LEVEL; each
## level takes XP_GROWTH times longer than the one before. Every level adds LEVEL_BONUS to
## the tower's stats (towers start at level 0, so level 100 = +100%) and every 10 levels
## give a perk point. At level 100 the tower can go up a tier (Island.upgrade_tower): it keeps
## the +100%, gains TIER_BONUS on top and starts again at level 0.

const MAX_LEVEL := 100
## XP from level 0 to 1; each further level needs XP_GROWTH times more. With these, level 10
## takes ~250 XP, level 50 ~4200 and level 100 ~52000.
const XP_BASE := 20.0
const XP_GROWTH := 1.05
const LEVEL_BONUS := 0.01
const MAX_TIER := 7
## Extra stats per tier jump, on top of the kept level bonus (placeholder for balancing).
const TIER_BONUS := 0.5
const LEVELS_PER_PERK := 10
const RANGE_PER_LEVEL := 0.001

var type: StringName
var hp: float
var shield := 0.0
var time_since_damage := 0.0
## Seconds until the tower may act again (Attack: next projectile, Repair: next heal).
var attack_cooldown := 0.0
## Aura and Scout towers: how strongly they work right now (0 = no energy, 1 = full).
var aura_power := 0.0
## Attack towers: where the turret points (radians, world space); it turns at the profile's
## turn speed and fires only once it points at its target.
var aim := -PI / 2.0
## Beam towers: seconds left before the beam may fire again after it ran out of energy.
var overheat := 0.0
var xp := 0.0
## Tower tier (1–MAX_TIER), raised at level 100.
var tier := 1
## Highest level already announced.
var level_seen := 0
## Merged towers (Island.merge) cover several hexes: the first hex is the root and lists them
## all in `merge_hexes`; the others are parts that only carry HP and energy and point to it.
var merge_hexes: Array[Vector2i] = []
var is_part := false
var merge_root := Vector2i.ZERO
## Placed next to a full cluster of its type (Island.MAX_CLUSTER): stays a single unit that
## doesn't combine with its neighbours (and can't merge) until there is room again.
var solo := false

# --- Analysis (see Island.track and the HUD's analysis view) ---
## Counters for the current wave and the whole mission: &"damage", &"kills", &"taken",
## &"healed", &"energy_used", &"delivered", &"wasted".
var wave_stats: Dictionary = {}
var mission_stats: Dictionary = {}
## Shares of roughly the last minute (moving averages): had energy, had something to work
## on, actually worked.
var uptime_powered := 1.0
var uptime_target := 0.0
var uptime_working := 0.0
## Set during a tick by whoever notices, read and cleared by Island.tick.
var saw_target := false
var did_work := false
## XP per minute (moving average) and the XP gained since the last tick.
var xp_per_minute := 0.0
var xp_this_tick := 0.0


func _init(tower_type: StringName, max_hp: float) -> void:
	type = tower_type
	hp = max_hp


func level() -> int:
	return level_for_xp(xp)


## Stat bonus of the current level: +1% per level (+100% at level 100).
func level_bonus() -> float:
	return LEVEL_BONUS * level()


## Bonus kept from earlier tiers: each one ended at level 100 and added TIER_BONUS.
func tier_bonus() -> float:
	return (tier - 1) * (LEVEL_BONUS * MAX_LEVEL + TIER_BONUS)


## Multiplier on the tower's stats (damage, energy pool, buffs, repairs, HP).
func stat_factor() -> float:
	return 1.0 + level_bonus() + tier_bonus()


## Range grows much more slowly: RANGE_PER_LEVEL per level, counting the 100 levels of every
## earlier tier (the tier jump bonus doesn't apply).
func range_factor() -> float:
	return 1.0 + RANGE_PER_LEVEL * (level() + (tier - 1) * MAX_LEVEL)


## Hexes the tower covers (1 unless merged).
func size() -> int:
	return maxi(1, merge_hexes.size())


## Perk points earned so far: one per 10 levels, kept through tier jumps.
func perk_points() -> int:
	return (tier - 1) * (MAX_LEVEL / LEVELS_PER_PERK) + level() / LEVELS_PER_PERK


func can_tier_up() -> bool:
	return level() >= MAX_LEVEL and tier < MAX_TIER


## Total XP needed to reach `level` from level 0.
static func xp_for_level(level: int) -> float:
	return XP_BASE * (pow(XP_GROWTH, clampi(level, 0, MAX_LEVEL)) - 1.0) / (XP_GROWTH - 1.0)


static func level_for_xp(amount: float) -> int:
	var level := int(floor(log(1.0 + maxf(amount, 0.0) * (XP_GROWTH - 1.0) / XP_BASE) / log(XP_GROWTH) + 0.000001))
	return clampi(level, 0, MAX_LEVEL)
