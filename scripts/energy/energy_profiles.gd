class_name EnergyProfiles
extends RefCounted
## Energy towers (GDD §6.5). Every biome follows the Neutral rules for now; the biome traits
## (geothermal, conduit, decay, roots) come back with the faction rounds.

const BASE_OUTPUT := 6.0
const TIER_OUTPUT_STEP := 0.25


static func for_tile(island: Island, coord: Vector2i) -> EnergyProfile:
	var tile := island.get_tile(coord)
	var p := EnergyProfile.new()
	p.output = BASE_OUTPUT * (1.0 + TIER_OUTPUT_STEP * maxi(tile.tier - 1, 0))
	var aura := island.aura_at(coord)
	p.output *= (1.0 + aura.get(&"efficiency", 0.0)) * (1.0 + aura.get(&"output", 0.0))
	p.output *= island.effect_bonus(coord)
	p.pipes = EnergyGrid.feeds(island, coord)
	return p
