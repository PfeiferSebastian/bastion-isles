class_name AttackProfile
extends RefCounted
## What an Attack tower does on its tile: a projectile part, a beam part, or both
## (Plains can mix them). Built by AttackProfiles; placeholder numbers until playtesting.

# Projectile part
var damage := 0.0
var cooldown := 1.0
var range_hexes := 3.0
var projectile_speed := 420.0
var projectile_size := 4.0
var color := Color.WHITE
## Energy drawn from the tile per projectile.
var energy_per_shot := 1.0

# Beam part (Desert): continuous damage per second along a piercing line
var beam_dps := 0.0
var beam_count := 0
var beam_color := Color("ffe9a0")
## Energy per second per beam.
var beam_energy := 0.0

# On-hit effects
var thorn_dps := 0.0  # per stack
var thorn_max := 0
var weaken := 0.0  # 0..1
var poison := 0.0  # share of hit damage dealt again over time (Swamp tile aura)


func has_projectile() -> bool:
	return damage > 0.0 or thorn_dps > 0.0 or weaken > 0.0


func apply_hit(enemy: Enemy) -> void:
	enemy.take_damage(damage)
	if enemy.is_dead:
		return
	if thorn_dps > 0.0:
		enemy.add_thorns(thorn_dps, thorn_max)
	if weaken > 0.0:
		enemy.add_weaken(weaken)
	if poison > 0.0 and damage > 0.0:
		enemy.add_poison(damage * poison, 3.0)
