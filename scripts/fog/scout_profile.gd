class_name ScoutProfile
extends RefCounted
## What a Scout tower does on its tile (GDD §6.7, "Scout in detail").
## Simplified for now: every scout keeps a circle around itself open; biomes only change
## the radius and how long the sky stays open after the scout stops seeing it.

var radius := 3
## Multiplier for how long revealed sky stays open before clouding over.
var hold_factor := 1.0
var energy_per_second := 1.0
var color := Color("6fb7ff")
