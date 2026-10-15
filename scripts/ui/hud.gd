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
var combat: Combat:
	set(value):
		combat = value
		combat.item_found.connect(notify)

## How long a find notice stays, and queued notices still to show.
const NOTICE_TIME := 3.0
var _notices: PackedStringArray = []
var _notice_left := 0.0

## Overlay locked on by clicking an icon; hovering another icon previews it temporarily.
var _locked_overlay: StringName = &""

@onready var _root: Control = $Root
@onready var _info_panel: Control = %InfoPanel
@onready var _info: Label = %Info
@onready var _waves: Button = %Waves
@onready var _spawn: Button = %Spawn
@onready var _stats: Label = %Stats
@onready var _treasury_panel: Control = %Treasury
@onready var _treasury_text: Label = %TreasuryText
@onready var _notice: Control = %Notice
@onready var _notice_text: Label = %NoticeText
@onready var _mission_tube: ProgressTube = %MissionTube
@onready var _legend: Label = %Legend
@onready var _overlay_icons: HBoxContainer = %OverlayIcons
@onready var _inventory: InventoryBar = %Inventory


func _ready() -> void:
	_root.theme = MenuTheme.build_hud()
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


## Shows a short notice above the gold display (finds queue up and show one after another).
func notify(text: String) -> void:
	_notices.append(text)


func _update_notice(delta: float) -> void:
	_notice_left -= delta
	if _notice_left <= 0.0:
		if _notices.is_empty():
			_notice.visible = false
			return
		_notice_text.text = _notices[0]
		_notices.remove_at(0)
		_notice_left = NOTICE_TIME
		_notice.visible = true
	_notice.reset_size()
	_notice.position.x = (_root.size.x - _notice.size.x) / 2.0
	# Fade out over the last half second.
	_notice.modulate.a = clampf(_notice_left / 0.5, 0.0, 1.0)


func _process(delta: float) -> void:
	_update_notice(delta)
	if combat:
		_waves.set_pressed_no_signal(combat.waves_enabled)
		_waves.text = "Waves: on" if combat.waves_enabled else "Waves: off"
		_stats.text = "Enemies %d · Killed %d" % [combat.enemies().size(), combat.kills]
		_mission_tube.value = combat.mission_progress()
		_mission_tube.tooltip_text = "Mission progress: %d / %d kills (placeholder until zones)" % [mini(combat.kills, combat.mission_kill_goal), combat.mission_kill_goal]
	if view == null:
		return
	_treasury_text.text = _describe_treasury(view.island.treasury)
	_treasury_panel.reset_size()
	_treasury_panel.position.x = (_root.size.x - _treasury_panel.size.x) / 2.0
	_info.text = _describe_tile(view.hovered_coord)
	_info_panel.visible = _info.text != ""
	_info_panel.reset_size()


func _set_overlay(mode: StringName) -> void:
	if view:
		view.overlay = mode
	_legend.text = "Map\noverlays" if mode == &"" else _legend_for(mode)


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


static func _describe_treasury(t: Treasury) -> String:
	var blueprints := 0
	for type in t.blueprints:
		blueprints += t.blueprints[type]
	return "Gold %d · Blueprints %d" % [t.gold, blueprints]


## What a click with the held inventory item would do here.
func _describe_price(_coord: Vector2i) -> String:
	if view.held.is_empty():
		return ""
	return "Placing: %s (%d left) · right click to cancel" % [Inventory.label_of(view.held), view.island.treasury.inventory.count(view.held)]


func _describe_tile(coord: Vector2i) -> String:
	var tile := view.island.get_tile(coord)
	if tile == null:
		return _describe_price(coord)
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
	if tile.is_hq:
		var cannon := AttackProfiles.hq()
		lines.append("HQ cannon: %.0f dmg every %.1fs · range %.1f hex · no energy" % [cannon.damage, cannon.cooldown, cannon.range_hexes])
	var tower := tile.tower
	if tower:
		var line := "%s · HP %d / %d" % [String(tower.type).capitalize(), ceili(tower.hp), roundi(view.island.tower_max_hp(coord))]
		if view.island.tower_max_shield(coord) > 0.0:
			line += " · Shield %d / %d" % [ceili(tower.shield), roundi(view.island.tower_max_shield(coord))]
		lines.append(line)
	if tower and tower.type == &"attack":
		lines.append("Attack: " + _describe_attack(AttackProfiles.for_tile(view.island, coord)))
	var price := _describe_price(coord)
	if price != "":
		lines.append(price)
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
