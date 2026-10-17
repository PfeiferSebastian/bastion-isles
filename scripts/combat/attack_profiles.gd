class_name AttackProfiles
extends RefCounted
## How the biome under an Attack tower shapes its attack (GDD §6.7, "Attack in detail").
## All on one normalised baseline for now (see base()); values are Tier 1 placeholders.

## Each tier above 1 adds this share to damage (Tier 3 = +50%).
const TIER_DAMAGE_STEP := 0.25
## Attack towers on neutral ground reach this many hexes further.
const NEUTRAL_RANGE_BONUS := 1.0


## Weapons follow trade-off rules from one baseline (BASE_DPS at BASE_RANGE for BASE_ENERGY
## per second), so every faction pays for its strengths:
## - range: DPS × BASE_RANGE / range, and energy × range / BASE_RANGE
## - fire rate: damage per shot = DPS × time between shots (DPS unchanged)
## - delivery: the faster damage lands, the more energy (DELIVERY factors)
## - extra effects cost DPS by their value (`effect_cost`)
## Neutral: single-barrel cannon · Mountain: machine cannon · Plains: laser · Forest: thorn
## launcher · Swamp: weakening sprayer · Lake: slowing water jet.
const BASE_DPS := 10.0
const BASE_ENERGY := 1.0
const BASE_RANGE := 5.0
const DELIVERY := {&"slow": 0.75, &"normal": 1.0, &"fast": 1.25, &"beam": 1.75}
const WATER_COLOR := Color("8fd8ff")
## Glow around the laser's white core (Plains towers and the Plains HQ).
const LASER_GLOW := Color("ffc98a")


static func base(biome: Biome.Type) -> AttackProfile:
	var p := AttackProfile.new()
	match biome:
		Biome.Type.MOUNTAIN:
			# Machine cannon: short range, a hail of small fast bullets, fast turret.
			_weapon(p, 4.0, 0.25, &"fast")
			p.turn_speed = 360.0
			p.style = &"tracer"
			p.color = Color("ffc24a")
			p.projectile_size = 3.0
			p.projectile_speed = 850.0
		Biome.Type.PLAINS:
			# Laser: long range, instant and continuous (hungry for energy), pierces armour,
			# slow precise turret.
			_beam(p, 6.5, &"beam", LASER_GLOW)
			p.style = &"laser"
			p.armor_pen = 0.3
			p.turn_speed = 90.0
		Biome.Type.FOREST:
			# Thorn launcher: slow shots, 30% direct damage and 70% as stacking thorns
			# (damage over time ticking every Enemy.DOT_TICK).
			_weapon(p, 5.0, 1.5, &"slow", 0.3)
			p.dot_duration = 4.5
			p.dot_dps = BASE_DPS * 0.7 * p.cooldown / p.dot_duration
			p.style = &"thorns"
			p.color = Color("8a5a2e")
			p.projectile_speed = 380.0
		Biome.Type.SWAMP:
			# Sprayer: short range, fast weak globs that weaken (−1% per hit, see
			# Enemy.add_weaken_stack); the weaken costs 40% of its damage.
			_weapon(p, 3.5, 0.25, &"slow", 1.0 - SWAMP_WEAKEN_COST)
			p.weaken_per_hit = 0.01
			p.effect_dps = BASE_DPS * BASE_RANGE / 3.5 * SWAMP_WEAKEN_COST
			p.turn_speed = 240.0
			p.style = &"slime"
			p.color = Color("9a5fd6")
			p.projectile_size = 4.5
			p.projectile_speed = 300.0
		Biome.Type.LAKE:
			# Water jet: very short, continuous, slows the target's attacks by 25% (costs 25%).
			_beam(p, 3.0, &"beam", WATER_COLOR, 1.0 - LAKE_SLOW)
			p.attack_slow = LAKE_SLOW
			p.effect_dps = BASE_DPS * BASE_RANGE / 3.0 * LAKE_SLOW
			p.style = &"water"
			p.turn_speed = 240.0
		_:
			# Single-barrel cannon: the baseline, with a little armour piercing.
			_weapon(p, BASE_RANGE, 1.0, &"normal")
			p.armor_pen = 0.1
			p.style = &"shell"
			p.color = Color("d9a441")
			p.projectile_speed = 550.0
	# Neutral ground's tile trait: one hex more range.
	if biome == Biome.Type.NEUTRAL:
		p.range_hexes += NEUTRAL_RANGE_BONUS
	return p


## Share of a sprayer's damage traded for its weaken, and the water jet's attack slow.
const SWAMP_WEAKEN_COST := 0.4
const LAKE_SLOW := 0.25


## Projectile weapon by the rules: core range, seconds between shots, delivery speed and the
## share of the DPS left as direct damage after paying for extra effects.
static func _weapon(p: AttackProfile, range_hexes: float, interval: float, delivery: StringName, damage_share := 1.0) -> void:
	var dps := BASE_DPS * BASE_RANGE / range_hexes * damage_share
	p.range_hexes = range_hexes
	p.cooldown = interval
	p.damage = dps * interval
	p.energy_per_shot = BASE_ENERGY * range_hexes / BASE_RANGE * DELIVERY[delivery] * interval


## Beam weapon by the same rules.
static func _beam(p: AttackProfile, range_hexes: float, delivery: StringName, color: Color, damage_share := 1.0) -> void:
	p.range_hexes = range_hexes
	p.beam_count = 1
	p.beam_dps = BASE_DPS * BASE_RANGE / range_hexes * damage_share
	p.beam_energy = BASE_ENERGY * range_hexes / BASE_RANGE * DELIVERY[delivery]
	p.beam_color = color


## The full profile for the Attack tower on `coord`: biome, tier, tile auras.
static func for_tile(island: Island, coord: Vector2i) -> AttackProfile:
	var tile := island.get_tile(coord)
	var p := base(tile.biome)
	_scale_by_tier(p, tile.tier)
	var aura := island.aura_at(coord)
	var efficiency: float = aura.get(&"efficiency", 0.0)
	var output: float = aura.get(&"output", 0.0)
	p.cooldown /= 1.0 + efficiency
	p.beam_dps *= (1.0 + efficiency) * (1.0 + output)
	p.damage *= 1.0 + output
	p.dot_dps *= 1.0 + output
	p.effect_dps *= 1.0 + output
	var merged := island.effect_bonus(coord)
	# Range grows slowly with level and tier, not with cluster or merge size.
	var tower := island.get_tower(coord)
	if tower:
		p.range_hexes *= tower.range_factor()
	p.damage *= merged
	p.beam_dps *= merged
	p.dot_dps *= merged
	p.effect_dps *= merged
	return p


static func _scale_by_tier(p: AttackProfile, tier: int) -> void:
	var steps := maxi(tier - 1, 0)
	var factor := 1.0 + TIER_DAMAGE_STEP * steps
	p.damage *= factor
	p.beam_dps *= factor
	p.dot_dps *= factor
	p.effect_dps *= factor
