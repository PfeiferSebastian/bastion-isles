class_name RepairProfiles
extends RefCounted
## How the biome under a Repair tower shapes its healing (GDD §6.7, "Repair in detail").
## Tier 0 / neutral heals the weakest target in reach and uses a lot of energy.
## Tier 1 placeholder numbers until playtesting.

const TIER_AMOUNT_STEP := 0.25


static func base(biome: Biome.Type) -> RepairProfile:
	var p := RepairProfile.new()
	match biome:
		Biome.Type.FOREST:
			# Healing over time: cheap, slow, high total.
			p.mode = &"over_time"
			p.amount = 50.0
			p.duration = 8.0
			p.cooldown = 4.0
			p.energy_per_heal = 2.0
		Biome.Type.MOUNTAIN:
			# Rebuild: big chunks with a long cooldown.
			p.amount = 70.0
			p.cooldown = 5.0
			p.energy_per_heal = 6.0
			p.color = Color("c9a24a")
		Biome.Type.PLAINS:
			# Redistribution: moves HP from healthy to damaged, very cheap.
			p.mode = &"redistribute"
			p.amount = 12.0
			p.cooldown = 1.0
			p.energy_per_heal = 0.5
			p.color = Color("c9b8ff")
		Biome.Type.SWAMP:
			# Lifesteal: drains enemies in reach to heal.
			p.mode = &"lifesteal"
			p.amount = 10.0
			p.cooldown = 1.0
			p.energy_per_heal = 1.0
			p.color = Color("b07be0")
	return p


static func for_tile(island: Island, coord: Vector2i) -> RepairProfile:
	var tile := island.get_tile(coord)
	var p := base(tile.biome)
	p.amount *= 1.0 + TIER_AMOUNT_STEP * maxi(tile.tier - 1, 0)
	var aura := island.aura_at(coord)
	p.amount *= 1.0 + aura.get(&"output", 0.0)
	p.cooldown /= 1.0 + aura.get(&"efficiency", 0.0)
	p.amount *= island.effect_bonus(coord)
	return p
