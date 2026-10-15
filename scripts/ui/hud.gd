class_name Hud
extends CanvasLayer
## Combat screen UI in the steampunk theme: wave controls and stats at the top, info about
## the hovered tile at the top left, map overlay icons at the bottom left, build bar at the
## bottom middle.

const OVERLAYS := [
	[&"energy", "Energy: generators bright, storages by fill (red = empty), empty tiles show how much they let through"],
	[&"repair", "Repair: tiles covered by Repair towers in green, damaged buildings and ground outlined in red"],
	[&"hp", "Hitpoints: tower HP where a tower stands, otherwise ground HP – green full, red low"],
	[&"tier", "Tiers: light = Tier 0, dark = Tier 7"],
]

## Set by main; the HUD reads hover state and island data from it every frame.
var view: IslandView
var combat: Combat

## Overlay locked on by clicking an icon; hovering another icon previews it temporarily.
var _locked_overlay: StringName = &""

@onready var _root: Control = $Root
@onready var _info_panel: Control = %InfoPanel
@onready var _info: Label = %Info
@onready var _waves: Button = %Waves
@onready var _spawn: Button = %Spawn
@onready var _stats: Label = %Stats
@onready var _legend: Label = %Legend
@onready var _overlay_icons: HBoxContainer = %OverlayIcons
@onready var _toolbar: Toolbar = %Toolbar


func _ready() -> void:
	_root.theme = MenuTheme.build_hud()
	_toolbar.tool_selected.connect(func(tool: IslandView.Tool, biome: Biome.Type) -> void:
		if view:
			view.set_tool(tool, biome))
	_waves.toggled.connect(func(on: bool) -> void:
		if combat:
			combat.waves_enabled = on)
	_spawn.pressed.connect(func() -> void:
		if combat:
			combat.spawn_wave())
	for entry in OVERLAYS:
		var icon := OverlayIcon.new(entry[0], entry[1])
		icon.preview_started.connect(_set_overlay)
		icon.preview_ended.connect(func() -> void: _set_overlay(_locked_overlay))
		icon.toggled.connect(_on_overlay_toggled.bind(icon))
		_overlay_icons.add_child(icon)


func _process(_delta: float) -> void:
	if combat:
		_waves.set_pressed_no_signal(combat.waves_enabled)
		_waves.text = "Waves: on" if combat.waves_enabled else "Waves: off"
		_stats.text = "Enemies %d · Killed %d" % [combat.enemies().size(), combat.kills]
	if view == null:
		return
	_info.text = _describe_tile(view.hovered_coord)
	_info_panel.visible = _info.text != ""
	_info_panel.reset_size()


func _set_overlay(mode: StringName) -> void:
	if view:
		view.overlay = mode
	_legend.text = "Map overlays" if mode == &"" else _legend_for(mode)


func _on_overlay_toggled(on: bool, icon: OverlayIcon) -> void:
	# Only one overlay can be locked; clicking another icon swaps it.
	for other in _overlay_icons.get_children():
		if other != icon:
			(other as Button).set_pressed_no_signal(false)
	_locked_overlay = icon.mode if on else &""
	_set_overlay(_locked_overlay)


static func _legend_for(mode: StringName) -> String:
	for entry in OVERLAYS:
		if entry[0] == mode:
			return String(entry[1]).get_slice(":", 0)
	return ""


func _describe_tile(coord: Vector2i) -> String:
	var tile := view.island.get_tile(coord)
	if tile == null:
		return ""
	var lines: PackedStringArray = []
	var what := "HQ" if tile.is_hq else "%s · Tier %d" % [Biome.name_of(tile.biome), tile.tier]
	if tile.destroyed:
		what += " · WASTELAND"
	lines.append("%s · Ground HP %d / %d" % [what, ceili(tile.hp), roundi(view.island.tile_max_hp(coord))])
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
	if tower:
		var line := "%s · HP %d / %d" % [String(tower.type).capitalize(), ceili(tower.hp), roundi(view.island.tower_max_hp(coord))]
		if view.island.tower_max_shield(coord) > 0.0:
			line += " · Shield %d / %d" % [ceili(tower.shield), roundi(view.island.tower_max_shield(coord))]
		lines.append(line)
	if tower and tower.type == &"attack":
		lines.append("Attack: " + _describe_attack(AttackProfiles.for_tile(view.island, coord)))
	if tower and tower.type == &"aura":
		lines.append("Aura: " + _describe_aura(AuraProfiles.for_tile(view.island, coord), tower.aura_power))
	if tower and tower.type == &"scout":
		lines.append("Scout: " + _describe_scout(ScoutProfiles.for_tile(view.island, coord), tower.aura_power))
	if tower and tower.type == &"repair":
		lines.append("Repair: " + _describe_repair(RepairProfiles.for_tile(view.island, coord)))
	return "\n".join(lines)


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


static func _describe_repair(p: RepairProfile) -> String:
	var what := ""
	match p.mode:
		&"over_time":
			what = "%.0f HP over %.0fs" % [p.amount, p.duration]
		&"redistribute":
			what = "moves %.0f HP from healthy to damaged" % p.amount
		&"lifesteal":
			what = "drains %.0f HP from enemies" % p.amount
		_:
			what = "%.0f HP" % p.amount
	if p.targets > 1:
		what += " × %d targets" % p.targets
	return "%s every %.1fs (%.1f energy) · reach %d" % [what, p.cooldown, p.energy_per_heal, p.reach()]


static func _describe_aura(p: AuraProfile, power: float) -> String:
	var parts: PackedStringArray = []
	if not p.effects.is_empty():
		parts.append(Auras.describe(p.effects))
	if p.enemy_weaken > 0.0:
		parts.append("weakens enemies %d%%" % roundi(p.enemy_weaken * 100.0))
	if p.tile_aura_boost > 0.0:
		parts.append("tile auras +%d%%" % roundi(p.tile_aura_boost * 100.0))
	var state := "no energy – off" if power <= 0.0 else ("%d%% power" % roundi(power * 100.0))
	return "%s · radius %d · %.1f energy/s · %s" % [" · ".join(parts), p.radius, p.energy_per_second, state]


static func _describe_scout(p: ScoutProfile, power: float) -> String:
	var state := "no energy – blind" if power <= 0.0 else ("%d%% power" % roundi(power * 100.0))
	return "keeps radius %d open · sky stays open ×%.1f after · %.1f energy/s · %s" % [p.radius, p.hold_factor, p.energy_per_second, state]
