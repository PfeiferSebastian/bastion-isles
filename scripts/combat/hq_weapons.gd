class_name HqWeapons
extends RefCounted
## The HQ's own weapon, set by its biome (Island.hq_biome, the biome most present on the
## island). Free of energy and without reach past its range (GDD §9.1, "HQ weapons").
##
## Numbers follow the attack tower trade-off rules (AttackProfiles) from the HQ's own
## baseline, the old HQ cannon's 20 DPS at 5 hexes: at RANGE hexes that is BUDGET DPS. The HQ
## needs no energy, so delivery speed costs nothing; healing counts like damage (1 HP = 1
## damage) and is paid for out of the same budget.

const RANGE := 10.0
const BUDGET := 20.0 * 5.0 / RANGE

## Mountain rocket: one heavy, very fast homing shot every ROCKET_INTERVAL.
const ROCKET_INTERVAL := 2.5
## Neutral twin cannon: both barrels fire together every TWIN_INTERVAL, half the damage each.
const TWIN_INTERVAL := 1.0
## Pixels between the twin cannon's barrels.
const TWIN_SPREAD := 12.0
## Forest: heals the weakest building or ground in range, one pulse every HEAL_INTERVAL.
const HEAL_INTERVAL := 1.0
## Swamp siphon: alternates SIPHON_PHASE seconds draining the nearest enemy (damage only)
## with SIPHON_PHASE seconds healing the closest damaged building (the HQ counts, at distance
## 0), each phase at the full budget rate, so on average half damage and half healing.
const SIPHON_PHASE := 1.0
## The siphon drains and heals in ticks of this many seconds (like damage over time), one
## pulse running along the stream per tick; five ticks make a phase.
const SIPHON_TICK := Enemy.DOT_TICK
## Lake bubble: drifts to its target at BUBBLE_SPEED, encloses it and roots it in place
## (no movement; it still shoots) while dealing the interval's damage over BUBBLE_DURATION;
## a new bubble every BUBBLE_DURATION.
const BUBBLE_DURATION := 3.0
const BUBBLE_SPEED := 170.0
## Share of the bubble's damage traded for rooting its target.
const ROOT_COST := 0.25

const HEAL_COLOR := Color("6fdc7a")
const SIPHON_COLOR := Color("b07be0")
const BUBBLE_COLOR := Color("8fd8ff")

const NAMES := {
	Biome.Type.NEUTRAL: "Twin cannon",
	Biome.Type.MOUNTAIN: "Rocket",
	Biome.Type.PLAINS: "Laser",
	Biome.Type.FOREST: "Healing",
	Biome.Type.SWAMP: "Siphon essence",
	Biome.Type.LAKE: "Bubble",
}


static func name_of(biome: Biome.Type) -> String:
	return NAMES.get(biome, NAMES[Biome.Type.NEUTRAL])


## The weapon's numbers as an AttackProfile (Forest's heal: `damage` is the HP per pulse,
## the siphon's heal per second is heal_per_second()).
static func profile(biome: Biome.Type) -> AttackProfile:
	var p := AttackProfile.new()
	p.range_hexes = RANGE
	p.energy_per_shot = 0.0
	match biome:
		Biome.Type.MOUNTAIN:
			p.cooldown = ROCKET_INTERVAL
			p.damage = BUDGET * ROCKET_INTERVAL
			p.projectile_speed = 950.0
			p.projectile_size = 4.0
			p.color = Color("ff9a3c")
			p.style = &"rocket"
		Biome.Type.PLAINS:
			p.beam_count = 1
			p.beam_dps = BUDGET
			p.beam_color = AttackProfiles.LASER_GLOW
			p.style = &"laser"
			p.armor_pen = 0.3
		Biome.Type.FOREST:
			p.cooldown = HEAL_INTERVAL
			p.damage = BUDGET * HEAL_INTERVAL
			p.color = HEAL_COLOR
		Biome.Type.SWAMP:
			p.beam_count = 1
			# beam_dps: while draining; effect_dps: the average healing (HP/s while healing is
			# siphon_heal_rate()).
			p.beam_dps = BUDGET
			p.beam_color = SIPHON_COLOR
			p.effect_dps = BUDGET / 2.0
		Biome.Type.LAKE:
			p.cooldown = BUBBLE_DURATION
			p.dot_duration = BUBBLE_DURATION
			p.dot_dps = BUDGET * (1.0 - ROOT_COST)
			p.effect_dps = BUDGET * ROOT_COST
			p.projectile_speed = BUBBLE_SPEED
			p.projectile_size = 7.0
			p.color = BUBBLE_COLOR
			p.style = &"bubble"
		_:
			p.cooldown = TWIN_INTERVAL
			p.damage = BUDGET * TWIN_INTERVAL / 2.0
			p.projectile_speed = 460.0
			p.projectile_size = 4.5
			p.color = Color("f0d28a")
			p.armor_pen = 0.1
	return p


## Siphon only: average HP per second sent to the closest damaged building.
static func heal_per_second(biome: Biome.Type) -> float:
	return profile(biome).effect_dps if biome == Biome.Type.SWAMP else 0.0


## Siphon only: HP per second while in its healing phase.
static func siphon_heal_rate() -> float:
	return BUDGET


## Siphon only: true while it drains (the first half of every two phases), false while it heals.
static func siphon_draining(clock: float) -> bool:
	return fmod(clock, 2.0 * SIPHON_PHASE) < SIPHON_PHASE


## Damage per second against one target in range (0 for Forest's heal).
static func dps(biome: Biome.Type) -> float:
	var p := profile(biome)
	match biome:
		Biome.Type.FOREST:
			return 0.0
		Biome.Type.LAKE:
			return p.dot_dps
		Biome.Type.NEUTRAL:
			return p.damage * 2.0 / p.cooldown
		Biome.Type.SWAMP:
			# Drains only every other phase.
			return p.beam_dps / 2.0
	return p.sustained_dps()


## Info lines for the HQ's tooltip.
static func describe(biome: Biome.Type) -> PackedStringArray:
	var p := profile(biome)
	var lines: PackedStringArray = ["Weapon (%s biome): %s, range %.0f hexes, no energy" % [Biome.name_of(biome), name_of(biome), RANGE]]
	match biome:
		Biome.Type.MOUNTAIN:
			lines.append("Fast homing rocket: %.0f damage every %.1f s (%.0f dps)" % [p.damage, p.cooldown, dps(biome)])
		Biome.Type.PLAINS:
			lines.append("Continuous beam: %.0f dps, ignores %d%% armour" % [p.beam_dps, roundi(p.armor_pen * 100.0)])
		Biome.Type.FOREST:
			lines.append("Heals the weakest building or ground in range: %.0f HP every %.1f s" % [p.damage, p.cooldown])
		Biome.Type.SWAMP:
			lines.append("Channelled stream in pulses of %.1f s, alternating every %.0f s: drains the nearest enemy at %.0f dps, then heals the closest damaged building (or the HQ) at %.0f HP/s (on average %.0f dps and %.0f HP/s)" % [
				SIPHON_TICK, SIPHON_PHASE, p.beam_dps, siphon_heal_rate(), dps(biome), p.effect_dps])
		Biome.Type.LAKE:
			lines.append("Slow bubble encloses its target and roots it in place for %.0f s, dealing %.1f damage meanwhile; a new bubble every %.0f s" % [p.dot_duration, p.dot_dps * p.dot_duration, p.cooldown])
		_:
			lines.append("Two barrels: 2 × %.0f damage every %.1f s (%.0f dps), ignores %d%% armour" % [p.damage, p.cooldown, dps(biome), roundi(p.armor_pen * 100.0)])
	return lines


## Mountain rocket: points along its flight (Projectile turns it) and trails smoke and flame.
class Rocket extends Projectile:
	func _draw() -> void:
		draw_line(Vector2(-26, 0), Vector2(-8, 0), Color(0.85, 0.85, 0.85, 0.3), 5.0, true)
		draw_circle(Vector2(-8, 0), 3.5, Color("ffd36b"))
		draw_rect(Rect2(-7, -2.5, 13, 5), Color("4a3d36"))
		draw_colored_polygon(PackedVector2Array([Vector2(6, -2.5), Vector2(11, 0), Vector2(6, 2.5)]), profile.color)


## Lake bubble: a wobbling, see-through sphere drifting to its target.
class Bubble extends Projectile:
	func _process(delta: float) -> void:
		queue_redraw()
		super(delta)

	func _draw() -> void:
		# The shine stays on top however the bubble flies.
		draw_set_transform(Vector2.ZERO, -rotation)
		var r := profile.projectile_size * (1.0 + 0.08 * sin(_age * 9.0))
		draw_circle(Vector2.ZERO, r, Color(profile.color, 0.3))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(profile.color, 0.9), 1.5, true)
		draw_arc(Vector2.ZERO, r * 0.65, PI * 1.1, PI * 1.5, 6, Color(1, 1, 1, 0.8), 1.5, true)
