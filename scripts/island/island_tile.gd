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


func _init(at: Vector2i, type: Biome.Type = Biome.Type.NEUTRAL) -> void:
	coord = at
	set_biome(type)


func set_biome(type: Biome.Type) -> void:
	biome = type
	tier = 0 if type == Biome.Type.NEUTRAL else 1


## Destroyed tiles will block the energy layer once tile damage exists (milestone 5).
func blocks_energy() -> bool:
	return false


func is_free() -> bool:
	return not is_hq and tower == null
