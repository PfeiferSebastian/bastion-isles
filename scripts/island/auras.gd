class_name Auras
extends RefCounted
## Neighbour auras (GDD §5.4): every biome tile buffs itself and its 6 neighbours,
## whatever their biome, scaled by its tier. Everything stacks.
## Values are shares (0.05 = +5%) per tier; placeholder numbers until playtesting.

const PER_TIER := {
	Biome.Type.FOREST: {&"regen": 0.01},
	Biome.Type.MOUNTAIN: {&"max_hp": 0.05},
	# Efficiency = general output (fire rate, energy, healing…), like the Desert Aura tower.
	Biome.Type.DESERT: {&"efficiency": 0.05},
	Biome.Type.PLAINS: {&"shield": 0.03},
	Biome.Type.SWAMP: {&"poison": 0.03},
}

## Effects that belong to the tile itself and are not shared with neighbours.
const SELF_PER_TIER := {
	Biome.Type.DESERT: {&"damage_spread": 0.10},
}

const LABELS := {
	&"max_hp": "Max HP",
	&"regen": "Regen/s",
	&"efficiency": "Efficiency",
	&"shield": "Shield",
	&"poison": "Poison",
	&"damage_spread": "Damage spread",
}


## Summed effects acting on the tile at `coord`.
static func collect(island: Island, coord: Vector2i) -> Dictionary:
	var result := {}
	var center := island.get_tile(coord)
	if center == null:
		return result
	_add(result, PER_TIER, center)
	_add(result, SELF_PER_TIER, center)
	for n in HexMath.neighbors(coord):
		var tile := island.get_tile(n)
		if tile:
			_add(result, PER_TIER, tile)
	return result


static func describe(effects: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in effects:
		parts.append("%s +%d%%" % [LABELS.get(key, String(key)), roundi(effects[key] * 100.0)])
	return " · ".join(parts)


static func _add(result: Dictionary, table: Dictionary, tile: IslandTile) -> void:
	var effects: Dictionary = table.get(tile.biome, {})
	for key in effects:
		result[key] = result.get(key, 0.0) + effects[key] * tile.tier
