class_name AttackProfiles
extends RefCounted
## How the biome under an Attack tower shapes its attack (GDD §6.7, "Attack in detail").
## Tier 0 / neutral = plain projectiles. Values are Tier 1 placeholders.

## Each tier above 1 adds this share to damage (Tier 3 = +50%).
const TIER_DAMAGE_STEP := 0.25


## Tier 1 values, tuned so every biome lands near 12 sustained damage per second on a
## single target and ~0.1 energy per damage; they differ in how they get there.
static func base(biome: Biome.Type) -> AttackProfile:
	var p := AttackProfile.new()
	match biome:
		Biome.Type.MOUNTAIN:
			# Heavy shells: strong, slow, longest range.
			p.damage = 36.0
			p.cooldown = 3.0
			p.range_hexes = 6.0
			p.projectile_speed = 300.0
			p.projectile_size = 7.0
			p.color = Color("3b2f2a")
			p.energy_per_shot = 3.6
		Biome.Type.PLAINS:
			# Continuous laser (from the former Desert) that stops at its target. The neighbour morph is parked until Plains weapons are redesigned.
			p.beam_dps = 10.0
			p.beam_count = 1
			p.beam_energy = 1.2
			p.beam_color = Color("dff3ff")
		Biome.Type.FOREST:
			# Thorns: little direct damage, stacking damage over time (full at 5 stacks).
			p.damage = 4.0
			p.cooldown = 0.8
			p.thorn_dps = 1.5
			p.thorn_max = 5
			p.color = Color("2f7a35")
			p.energy_per_shot = 0.9
		Biome.Type.SWAMP:
			# Support: little damage, strong weaken (enemies deal less, take more from all).
			p.damage = 5.0
			p.cooldown = 1.0
			p.weaken = 0.4
			p.color = Color("7b4bb0")
			p.energy_per_shot = 0.6
		_:
			p.damage = 11.0
			p.cooldown = 0.9
			p.energy_per_shot = 1.1
	return p


## The HQ's own cannon: solid damage and range from the start, free of energy.
static func hq() -> AttackProfile:
	var p := AttackProfile.new()
	p.damage = 20.0
	p.cooldown = 1.0
	p.range_hexes = 5.0
	p.projectile_speed = 460.0
	p.projectile_size = 5.5
	p.color = Color("f0d28a")
	p.energy_per_shot = 0.0
	return p


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
	p.thorn_dps *= 1.0 + output
	p.poison = aura.get(&"poison", 0.0)
	var merged := island.effect_bonus(coord)
	p.damage *= merged
	p.beam_dps *= merged
	p.thorn_dps *= merged
	return p


static func _scale_by_tier(p: AttackProfile, tier: int) -> void:
	var steps := maxi(tier - 1, 0)
	var factor := 1.0 + TIER_DAMAGE_STEP * steps
	p.damage *= factor
	p.beam_dps *= factor
	p.thorn_dps *= factor
	if p.thorn_max > 0:
		p.thorn_max += steps
	if p.weaken > 0.0:
		p.weaken = minf(0.8, p.weaken + 0.05 * steps)
