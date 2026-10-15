class_name EnergyProfiles
extends RefCounted
## How the biome under an Energy tower shapes it (GDD §6.7, "Energy in detail").
## Tier 1 placeholder numbers until playtesting.

const TIER_OUTPUT_STEP := 0.25
## The HQ bootstraps a fresh island as a weak neutral generator.
const HQ_OUTPUT := 3.0


static func base(biome: Biome.Type) -> EnergyProfile:
	var p := EnergyProfile.new()
	match biome:
		Biome.Type.MOUNTAIN:
			# Geothermal: highest output, 100% to neighbours, 40% at 2 hexes, 10% at 3.
			p.output = 10.0
			p.falloff = PackedFloat32Array([1.0, 1.0, 0.4, 0.1])
		Biome.Type.FOREST:
			# Root network: little output, boosts passive production of its connected forest.
			p.output = 2.0
			p.special = &"roots"
		Biome.Type.PLAINS:
			# Aether conduit: balances storage between tiles in reach.
			p.output = 3.0
			p.special = &"conduit"
		Biome.Type.SWAMP:
			# Decay: extra energy when enemies die nearby.
			p.output = 3.0
			p.special = &"decay"
	return p


static func for_tile(island: Island, coord: Vector2i) -> EnergyProfile:
	var tile := island.get_tile(coord)
	var p := base(tile.biome)
	p.output *= 1.0 + TIER_OUTPUT_STEP * maxi(tile.tier - 1, 0)
	var aura := island.aura_at(coord)
	p.output *= (1.0 + aura.get(&"efficiency", 0.0)) * (1.0 + aura.get(&"output", 0.0))
	return p


static func hq() -> EnergyProfile:
	var p := EnergyProfile.new()
	p.output = HQ_OUTPUT
	return p
