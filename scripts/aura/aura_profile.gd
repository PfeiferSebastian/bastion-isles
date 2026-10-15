class_name AuraProfile
extends RefCounted
## What an Aura tower does on its tile (GDD §6.7, "Aura in detail").

## Hexes around the tower (including its own tile) that receive the buff.
var radius := 1
## Buff for towers (and, for regen, ground) in the radius, same keys as tile auras
## (e.g. {&"output": 0.25}). Empty for Swamp, which weakens enemies instead.
var effects := {}
## Extra share added to the tile auras emitted by tiles in the radius.
var tile_aura_boost := 0.25
## Swamp: weaken applied to enemies in the radius.
var enemy_weaken := 0.0
var energy_per_second := 1.0
var color := Color("7fe0c2")
