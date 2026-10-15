class_name Tower
extends RefCounted
## Runtime state of one tower standing on a tile. Max values come from the island
## (base HP × tile auras), so they are not stored here.

var type: StringName
var hp: float
var shield := 0.0
var time_since_damage := 0.0
## Seconds until an Attack tower may fire its next projectile.
var attack_cooldown := 0.0


func _init(tower_type: StringName, max_hp: float) -> void:
	type = tower_type
	hp = max_hp
