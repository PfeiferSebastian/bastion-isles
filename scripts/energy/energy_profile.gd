class_name EnergyProfile
extends RefCounted
## What a generator (Energy tower or HQ) does: output and how much arrives per hex distance.

## Energy per second.
var output := 6.0
## Share that arrives at distance 0, 1, 2… The last entry sets the reach.
var falloff := PackedFloat32Array([1.0, 1.0, 0.5])
## Biome trait: &"roots" (Forest), &"conduit" (Plains), &"decay" (Swamp), &"solar" (Desert) or &"".
var special: StringName = &""


func reach() -> int:
	return falloff.size() - 1
