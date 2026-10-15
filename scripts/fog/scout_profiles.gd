class_name ScoutProfiles
extends RefCounted
## How the biome under a Scout tower shapes its reveal (GDD §6.7, "Scout in detail").
## Simplified for now (cone, beam and flash come back later): radius and open time only.
## Placeholder numbers until playtesting.


static func base(biome: Biome.Type) -> ScoutProfile:
	var p := ScoutProfile.new()
	match biome:
		Biome.Type.FOREST:
			# Birds: the sky stays open much longer.
			p.hold_factor = 2.5
			p.color = Color("5fd068")
		Biome.Type.MOUNTAIN:
			# Watchtower: sees furthest.
			p.radius = 5
			p.color = Color("c9a24a")
		Biome.Type.SWAMP:
			p.radius = 4
			p.color = Color("b07be0")
	return p


## Each tier above 1 adds one hex of radius.
static func for_tile(island: Island, coord: Vector2i) -> ScoutProfile:
	var tile := island.get_tile(coord)
	var p := base(tile.biome)
	p.radius += maxi(tile.tier - 1, 0)
	# Combined watchtowers keep the sky open longer.
	p.hold_factor *= island.effect_bonus(coord)
	return p
