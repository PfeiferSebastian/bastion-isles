class_name AttackProfile
extends RefCounted
## What an Attack tower does on its tile: a projectile or a beam, how fast its turret turns,
## how much armour it pierces, and its extra effect (damage over time, weaken, attack-speed
## slow). Built by AttackProfiles; placeholder numbers until playtesting.
##
## Towers also shoot past their core range, losing FALLOFF_PER_HEX of their damage per hex
## beyond it, at most MAX_EXTRA_HEXES further. Extra effects don't apply out there, and the
## damage never drops below MIN_EFFECT of the tower's full worth (direct damage, stacked damage
## over time and the DPS traded for its extra effect), so towers with extra effects and thus
## less direct damage keep the same share as plain ones.

const FALLOFF_PER_HEX := 0.25
const MIN_EFFECT := 0.05
const MAX_EXTRA_HEXES := 4.0

# Projectile part
var damage := 0.0
var cooldown := 1.0
## Core range in hexes: full damage and extra effects inside it.
var range_hexes := 5.0
var projectile_speed := 420.0
var projectile_size := 4.0
var color := Color.WHITE
## How the shot (or beam) looks, see Projectile._draw and Combat._draw_beam: &"ball", &"shell"
## (Neutral), &"tracer" (Mountain), &"thorns" (Forest), &"slime" (Swamp), &"laser" (Plains),
## &"water" (Lake); the HQ adds &"rocket" and &"bubble".
var style: StringName = &"ball"
## Energy drawn from the tile per projectile.
var energy_per_shot := 1.0

# Beam part (Plains, Lake): continuous damage per second on the target
var beam_dps := 0.0
var beam_count := 0
var beam_color := Color("ffe9a0")
## Energy per second per beam.
var beam_energy := 0.0

## Degrees per second the turret turns; it fires only once it points at its target.
var turn_speed := 180.0
## Share of enemy armour ignored (0..1).
var armor_pen := 0.0

# Extra effects (only inside the core range)
## Damage over time per hit, stacking: dps per stack for dot_duration seconds (Forest thorns).
var dot_dps := 0.0
var dot_duration := 0.0
## Weaken added per hit (Swamp): enemies deal less and take more, see Enemy.add_weaken_stack.
var weaken_per_hit := 0.0
## Attack-speed slow on the target (Lake): its attacks come this much slower for the duration.
var attack_slow := 0.0
var attack_slow_duration := 2.0
## DPS traded away for the extra effect (counts toward the tower's full worth).
var effect_dps := 0.0


func has_projectile() -> bool:
	return damage > 0.0


func has_special() -> bool:
	return dot_dps > 0.0 or weaken_per_hit > 0.0 or attack_slow > 0.0


## Share of direct damage at `distance` hexes: 1 inside the core range, then falling off per
## hex down to min_factor().
func performance(distance: float) -> float:
	if distance <= range_hexes:
		return 1.0
	return maxf(min_factor(), 1.0 - FALLOFF_PER_HEX * (distance - range_hexes))


## Lowest share of direct damage far out: MIN_EFFECT of the full worth, as a share of the
## direct DPS.
func min_factor() -> float:
	var direct := beam_dps * beam_count + (damage / maxf(cooldown, 0.001) if has_projectile() else 0.0)
	if direct <= 0.0:
		return MIN_EFFECT
	return minf(1.0, MIN_EFFECT * (sustained_dps() + effect_dps) / direct)


## Furthest distance in hexes the tower shoots at all.
func max_reach() -> float:
	return range_hexes + MAX_EXTRA_HEXES


## Damage per second while the target stays in the core range (direct plus fully stacked
## damage over time).
func sustained_dps() -> float:
	var dps := beam_dps * beam_count
	if has_projectile():
		dps += damage / maxf(cooldown, 0.001)
		if dot_dps > 0.0:
			dps += dot_dps * dot_duration / maxf(cooldown, 0.001)
	return dps


## A projectile hit: damage scaled by `factor` (range falloff); extra effects only when
## `specials` (inside the core range).
func apply_hit(enemy: Enemy, factor := 1.0, specials := true) -> void:
	enemy.take_damage(damage * factor, armor_pen)
	if enemy.is_dead or not specials:
		return
	if dot_dps > 0.0:
		enemy.add_dot(dot_dps, dot_duration)
	if weaken_per_hit > 0.0:
		enemy.add_weaken_stack(weaken_per_hit)
	if attack_slow > 0.0:
		enemy.add_attack_slow(attack_slow, attack_slow_duration)
