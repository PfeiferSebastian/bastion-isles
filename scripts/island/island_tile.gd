class_name IslandTile
extends RefCounted
## One hex of the island. Pure data — the view decides how it looks.

var coord: Vector2i
var biome: Biome.Type = Biome.Type.NEUTRAL
## 0 = neutral, 1 = fresh biome tile (GDD §5.1).
var tier := 0
var is_hq := false
## The tower standing on this tile, or null.
var tower: Tower = null
## Stored energy; capacity comes from EnergyGrid.capacity().
var energy := 0.0
## Seconds its building has sat without energy (raises its urgency, see EnergyGrid).
var starved := 0.0
## Part of `energy` a building holds for the buildings behind it (it passes only that on).
var transit := 0.0
## Structure of the ground itself; max comes from Island.tile_max_hp().
var hp := 0.0
## Wasteland: destroyed in battle, until the fight is over (GDD §4.6).
var destroyed := false


func _init(at: Vector2i, type: Biome.Type = Biome.Type.NEUTRAL) -> void:
	coord = at
	set_biome(type)


func set_biome(type: Biome.Type) -> void:
	biome = type
	tier = 0 if type == Biome.Type.NEUTRAL else 1


## Wasteland blocks the energy layer.
func blocks_energy() -> bool:
	return destroyed


func is_free() -> bool:
	return not is_hq and not destroyed and tower == null
