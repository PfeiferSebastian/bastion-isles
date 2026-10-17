class_name RepairProfile
extends RefCounted
## What a Repair tower does on its tile (GDD §6.7, "Repair in detail").

## &"direct" (instant heal), &"over_time" (heal spread over `duration`),
## &"redistribute" (moves HP from healthy to damaged), &"lifesteal" (drains enemies).
var mode: StringName = &"direct"
## HP per heal at full strength.
var amount := 15.0
var cooldown := 1.0
## How many of the weakest targets each heal reaches.
var targets := 1
## Share of the heal that arrives at hex distance 0, 1, 2…; the last entry sets the reach.
var falloff := PackedFloat32Array([1.0, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5])
var energy_per_heal := 3.0
## For &"over_time": seconds the heal is spread over.
var duration := 0.0
var color := Color("5fd068")


func reach() -> int:
	return falloff.size() - 1
