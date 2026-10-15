class_name AuraProfiles
extends RefCounted
## How the biome under an Aura tower shapes its buff (GDD §6.7, "Aura in detail").
## Design rule: a surrounded Aura tower is worth about 1.5 normal towers, hence +25% per
## buffed tower at Tier 0. Placeholder numbers until playtesting.
## Must not use Island.aura_at() – Auras.collect() calls into here.

const TIER_STRENGTH_STEP := 0.25


static func base(biome: Biome.Type) -> AuraProfile:
	var p := AuraProfile.new()
	match biome:
		Biome.Type.FOREST:
			# Healing over time for towers and ground.
			p.effects = {&"regen": 0.02}
			p.color = Color("5fd068")
		Biome.Type.MOUNTAIN:
			# Armour and more HP.
			p.effects = {&"max_hp": 0.20, &"armor": 0.10}
			p.color = Color("c9a24a")
		Biome.Type.PLAINS:
			# Energy shield, regenerating from each tower's own storage.
			p.effects = {&"shield": 0.25}
			p.color = Color("8fd3ff")
		Biome.Type.SWAMP:
			# Weakens enemies instead of buffing allies.
			p.tile_aura_boost = 0.0
			p.enemy_weaken = 0.25
			p.color = Color("b07be0")
		_:
			# Tier 0: a general output boost.
			p.effects = {&"output": 0.25}
	return p


static func for_tile(island: Island, coord: Vector2i) -> AuraProfile:
	var tile := island.get_tile(coord)
	var p := base(tile.biome)
	var factor := 1.0 + TIER_STRENGTH_STEP * maxi(tile.tier - 1, 0)
	for key in p.effects:
		p.effects[key] *= factor
	p.tile_aura_boost *= factor
	p.enemy_weaken = minf(0.8, p.enemy_weaken * factor)
	return p
