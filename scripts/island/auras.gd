class_name Auras
extends RefCounted
## Neighbour auras (GDD §5.4): every biome tile buffs itself and its 6 neighbours,
## whatever their biome, scaled by its tier. Everything stacks.
## Values are shares (0.05 = +5%) per tier; placeholder numbers until playtesting.

## Forest has no neighbour aura: its tile trait is passive energy (EnergyGrid).
const PER_TIER := {
	Biome.Type.MOUNTAIN: {&"max_hp": 0.05},
	Biome.Type.PLAINS: {&"shield": 0.03},
	Biome.Type.SWAMP: {&"poison": 0.03},
}

## Effects that belong to the tile itself and are not shared with neighbours.
const SELF_PER_TIER := {
	# Redistribution (from the former Desert): passes part of incoming damage to neighbours.
	Biome.Type.PLAINS: {&"damage_spread": 0.10},
}

const LABELS := {
	&"max_hp": "Max HP",
	&"regen": "Regen/s",
	&"efficiency": "Efficiency",
	&"shield": "Shield",
	&"poison": "Poison",
	&"damage_spread": "Damage spread",
	&"output": "Output",
	&"armor": "Armor",
}


## Summed effects acting on the tile at `coord`: tile auras (boosted near Aura towers),
## wall HP buffs and Aura tower buffs.
static func collect(island: Island, coord: Vector2i) -> Dictionary:
	var result := {}
	var center := island.get_tile(coord)
	if center == null:
		return result
	var auras := active_aura_towers(island, coord, TowerDefs.AURA_RADIUS_MAX + 1)
	_add(result, PER_TIER, center, _tile_boost(auras, coord))
	_add(result, SELF_PER_TIER, center, 1.0)
	for n in HexMath.neighbors(coord):
		var tile := island.get_tile(n)
		if tile:
			_add(result, PER_TIER, tile, _tile_boost(auras, n))
			# Wall towers buff the HP of adjacent buildings (not their own tile).
			if tile.tower and tile.tower.type == &"wall":
				result[&"max_hp"] = result.get(&"max_hp", 0.0) + TowerDefs.WALL_NEIGHBOUR_HP.get(tile.biome, 0.1)
	# Aura towers buff everything in their radius. No chaining: an Aura tower only
	# receives its own buff, never another Aura tower's.
	var own_aura := center.tower != null and center.tower.type == &"aura"
	for source in auras:
		if own_aura and source != coord:
			continue
		var profile: AuraProfile = auras[source]
		if HexMath.distance(source, coord) > profile.radius:
			continue
		var power := island.get_tower(source).aura_power
		for key in profile.effects:
			result[key] = result.get(key, 0.0) + profile.effects[key] * power
	return result


## Powered Aura towers within `reach` of `coord`, as {coord: AuraProfile}.
static func active_aura_towers(island: Island, coord: Vector2i, reach: int) -> Dictionary:
	var result := {}
	for c in HexMath.area(coord, reach):
		var tile := island.get_tile(c)
		if tile and not tile.destroyed and tile.tower and tile.tower.type == &"aura" and tile.tower.aura_power > 0.0:
			result[c] = AuraProfiles.for_tile(island, c)
	return result


## Multiplier for the tile aura emitted by `source`: boosted by Aura towers covering it.
static func _tile_boost(auras: Dictionary, source: Vector2i) -> float:
	var boost := 1.0
	for c in auras:
		var profile: AuraProfile = auras[c]
		if HexMath.distance(c, source) <= profile.radius:
			boost += profile.tile_aura_boost
	return boost


static func describe(effects: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in effects:
		parts.append("%s +%d%%" % [LABELS.get(key, String(key)), roundi(effects[key] * 100.0)])
	return " · ".join(parts)


static func _add(result: Dictionary, table: Dictionary, tile: IslandTile, factor: float) -> void:
	if tile.destroyed:
		return
	var effects: Dictionary = table.get(tile.biome, {})
	for key in effects:
		result[key] = result.get(key, 0.0) + effects[key] * tile.tier * factor
