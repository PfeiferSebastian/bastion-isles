class_name Hud
extends CanvasLayer
## Prototype HUD: controls hint, build tool bar and info about the hovered tile.

## Set by main; the HUD reads hover state and island data from it every frame.
var view: IslandView
var combat: Combat

@onready var _info: Label = %Info
@onready var _combat_info: Label = %CombatInfo
@onready var _toolbar: Toolbar = %Toolbar


func _ready() -> void:
	_toolbar.tool_selected.connect(func(tool: IslandView.Tool, biome: Biome.Type) -> void:
		if view:
			view.set_tool(tool, biome))


func _process(_delta: float) -> void:
	if combat:
		_combat_info.text = "Waves %s (P) · Enemies %d · Killed %d · W: spawn wave" % [
			"on" if combat.waves_enabled else "off", combat.enemies().size(), combat.kills]
	if view == null:
		return
	var coord := view.hovered_coord
	var tile := view.island.get_tile(coord)
	if tile == null:
		_info.text = ""
		return
	var lines: PackedStringArray = []
	var what := "HQ" if tile.is_hq else "%s · Tier %d" % [Biome.name_of(tile.biome), tile.tier]
	lines.append("Tile (%d, %d) — %s" % [coord.x, coord.y, what])
	var cap := EnergyGrid.capacity(tile)
	if cap > 0.0:
		lines.append("Energy %.1f / %.0f" % [tile.energy, cap])
	elif tile.tower == null and not tile.is_hq:
		lines.append("Energy conduit: lets %d%% through" % roundi(EnergyGrid.pass_through(tile) * 100.0))
	var generator := EnergyGrid.generator_at(view.island, coord)
	if generator:
		lines.append("Generator: %.1f/s · reach %d · %s" % [generator.output, generator.reach(), _describe_falloff(generator)])
	var effects := view.island.aura_at(coord)
	if not effects.is_empty():
		lines.append("Auras: " + Auras.describe(effects))
	var tower := tile.tower
	if tower and tower.type == &"attack":
		lines.append("Attack: " + _describe_attack(AttackProfiles.for_tile(view.island, coord)))
	if tower:
		var line := "%s · HP %d / %d" % [String(tower.type).capitalize(), ceili(tower.hp), roundi(view.island.tower_max_hp(coord))]
		if view.island.tower_max_shield(coord) > 0.0:
			line += " · Shield %d / %d" % [ceili(tower.shield), roundi(view.island.tower_max_shield(coord))]
		lines.append(line)
	_info.text = "\n".join(lines)


static func _describe_attack(p: AttackProfile) -> String:
	var parts: PackedStringArray = []
	if p.has_projectile():
		parts.append("%.0f dmg every %.1fs (%.1f energy)" % [p.damage, p.cooldown, p.energy_per_shot])
	if p.beam_dps > 0.0:
		parts.append("%d laser × %.1f dps (%.1f energy/s)" % [p.beam_count, p.beam_dps, p.beam_energy * p.beam_count])
	if p.thorn_dps > 0.0:
		parts.append("thorns %.1f dps × %d" % [p.thorn_dps, p.thorn_max])
	if p.weaken > 0.0:
		parts.append("weaken %d%%" % roundi(p.weaken * 100.0))
	if p.poison > 0.0:
		parts.append("poison %d%%" % roundi(p.poison * 100.0))
	parts.append("range %.1f hex" % p.range_hexes)
	return " · ".join(parts)


static func _describe_falloff(p: EnergyProfile) -> String:
	var parts: PackedStringArray = []
	for share in p.falloff:
		parts.append("%d%%" % roundi(share * 100.0))
	var text := "/".join(parts)
	if p.special != &"":
		text += " · " + String(p.special)
	return text
