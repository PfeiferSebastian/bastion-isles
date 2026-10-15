class_name AttackProfiles
extends RefCounted
## How the biome under an Attack tower shapes its attack (GDD §6.7, "Attack in detail").
## Tier 0 / neutral = plain projectiles. Values are Tier 1 placeholders.

## Each tier above 1 adds this share to damage (Tier 3 = +50%).
const TIER_DAMAGE_STEP := 0.25


static func base(biome: Biome.Type) -> AttackProfile:
	var p := AttackProfile.new()
	match biome:
		Biome.Type.MOUNTAIN:
			# Heavy shells: strong, slow, long range.
			p.damage = 30.0
			p.cooldown = 2.5
			p.range_hexes = 4.5
			p.projectile_speed = 300.0
			p.projectile_size = 7.0
			p.color = Color("3b2f2a")
			p.energy_per_shot = 3.0
		Biome.Type.DESERT:
			# Continuous piercing laser.
			p.beam_dps = 14.0
			p.beam_count = 1
			p.beam_energy = 2.0
		Biome.Type.FOREST:
			# Thorns: little direct damage, stacking damage over time.
			p.damage = 4.0
			p.cooldown = 0.8
			p.thorn_dps = 2.5
			p.thorn_max = 5
			p.color = Color("2f7a35")
			p.energy_per_shot = 0.5
		Biome.Type.SWAMP:
			# Strong debuff, little damage of its own.
			p.damage = 3.0
			p.cooldown = 1.2
			p.weaken = 0.4
			p.color = Color("7b4bb0")
			p.energy_per_shot = 0.5
		_:
			p.damage = 10.0
			p.cooldown = 1.0
	return p


## The full profile for the Attack tower on `coord`: biome (or Plains morph), tier, tile auras.
static func for_tile(island: Island, coord: Vector2i) -> AttackProfile:
	var tile := island.get_tile(coord)
	var p := morph(island, coord) if tile.biome == Biome.Type.PLAINS else base(tile.biome)
	_scale_by_tier(p, tile.tier)
	var aura := island.aura_at(coord)
	var efficiency: float = aura.get(&"efficiency", 0.0)
	var output: float = aura.get(&"output", 0.0)
	p.cooldown /= 1.0 + efficiency
	p.beam_dps *= (1.0 + efficiency) * (1.0 + output)
	p.damage *= 1.0 + output
	p.thorn_dps *= 1.0 + output
	p.poison = aura.get(&"poison", 0.0)
	return p


## Plains: copies the attack traits of its biome neighbours, each neighbour an equal share.
## Neutral and Plains neighbours don't count. One beam per Desert neighbour, sharing the beam damage.
static func morph(island: Island, coord: Vector2i) -> AttackProfile:
	var counts := {}
	var total := 0
	for n in HexMath.neighbors(coord):
		var tile := island.get_tile(n)
		if tile and tile.biome != Biome.Type.NEUTRAL and tile.biome != Biome.Type.PLAINS:
			counts[tile.biome] = counts.get(tile.biome, 0) + 1
			total += 1
	if total == 0:
		return base(Biome.Type.NEUTRAL)

	var p := AttackProfile.new()
	p.cooldown = 0.0
	p.range_hexes = 0.0
	p.projectile_speed = 0.0
	p.energy_per_shot = 0.0
	p.color = Color("c9b8ff")
	var projectile_share := 0.0
	for biome in counts:
		var share := float(counts[biome]) / total
		var b := base(biome)
		p.damage += b.damage * share
		p.thorn_dps += b.thorn_dps * share
		p.thorn_max = maxi(p.thorn_max, b.thorn_max)
		p.weaken += b.weaken * share
		p.range_hexes += b.range_hexes * share
		if b.beam_dps > 0.0:
			p.beam_count = counts[biome]
			p.beam_dps += b.beam_dps * share / counts[biome]
			p.beam_energy += b.beam_energy * share / counts[biome]
		if b.has_projectile():
			p.cooldown += b.cooldown * share
			p.projectile_speed += b.projectile_speed * share
			p.energy_per_shot += b.energy_per_shot * share
			projectile_share += share
	if projectile_share > 0.0:
		p.cooldown /= projectile_share
		p.projectile_speed /= projectile_share
		p.energy_per_shot /= projectile_share
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
