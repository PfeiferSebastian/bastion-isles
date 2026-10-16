class_name Hud
extends CanvasLayer
## Combat screen UI in the steampunk theme: map overlay icons at the top left with find
## notices below them, the mission bar (start countdown, then Leave) at the top centre,
## compact wave controls and stats at the top right, and a brass console along
## the bottom holding the inventory, the gold plaque and the fixed info window (bottom right)
## that shows every hover text.

## Shown in the info window while nothing with a description is hovered.
const HELP := "Click a slot, then the island · or drag a slot onto it\nRight click: pick up / cancel\nDrag: pan · Wheel: zoom · Esc: menu\nP: waves on/off · W: spawn a wave · U: tier upgrade (level 100)\n\nDebug: D damage · +/- tier · F1–F4 enemies · V fog\nG +500 gold · R +5 stones and tiles · B +10 blueprints"

const OVERLAYS := [
	[&"energy", "Energy: generators bright, storages by fill (red = empty), empty tiles show how much they let through"],
	[&"repair", "Repair: tiles covered by Repair towers in green, damaged buildings and ground outlined in red"],
	[&"hp", "Hitpoints: tower HP where a tower stands, otherwise ground HP – green full, red low"],
	[&"tier", "Tiers: light = Tier 0, dark = Tier 7"],
	[&"merge", "Merge: n touching towers of tier n (same type) become one n-hex tower with n× the effect; it keeps its tier, starts again at level 0 and lifts its biome tiles to its tier. A merged tower grows with one more of its tier. Click a glowing tower to merge it"],
]

## The player chose to leave: after completing the mission, or "Done" in edit mode.
signal leave_requested

## Set by main; the HUD reads hover state and island data from it every frame.
var view: IslandView:
	set(value):
		view = value
		view.island.tower_levelled.connect(_on_tower_levelled)
		view.island.towers_merged.connect(func(hexes: Array[Vector2i]) -> void:
			var tower := view.island.get_tower(hexes[0])
			notify("%s merged: %d hexes, Tier %d" % [String(tower.type).capitalize(), hexes.size(), tower.tier]))
var combat: Combat:
	set(value):
		combat = value
		combat.item_found.connect(notify)
		combat.mission_completed.connect(func() -> void: notify("Mission complete! No more enemies are coming."))


## Announces level-ups of buildings (every few levels, and when their ground rises a tier).
func _on_tower_levelled(coord: Vector2i, level: int) -> void:
	var tower := view.island.get_tower(coord)
	if tower == null:
		return
	var text := "%s reached level %d" % [String(tower.type).capitalize(), level]
	if level >= Tower.MAX_LEVEL and tower.tier < Tower.MAX_TIER:
		text += " · hover it and press U for Tier %d" % (tower.tier + 1)
	notify(text)

## Find and level-up notices stack below the overlay icons; each stays NOTICE_TIME seconds,
## then fades out over NOTICE_FADE.
const NOTICE_TIME := 10.0
const NOTICE_FADE := 1.0
var _notices := VBoxContainer.new()

## Wave controls in the top right panel (icons; the symbol shows what a click does).
var _waves := OverlayIcon.new(&"pause", "")
var _spawn := OverlayIcon.new(&"spawn", "Spawn a wave now (W)")

## Editing the island from the main menu: no waves, the mission bar offers "Done".
var _edit_mode := false
var _flee: OverlayIcon

## Overlay locked on by clicking an icon; hovering another icon previews it temporarily.
var _locked_overlay: StringName = &""

@onready var _root: Control = $Root
@onready var _deck: ConsoleDeck = %ConsoleDeck
@onready var _overlay_panel: PanelContainer = %OverlayPanel
@onready var _inventory_panel: Control = %InventoryPanel
@onready var _info_panel: Control = %InfoPanel
@onready var _info: Label = %Info
@onready var _top_bar: PanelContainer = %TopBar
@onready var _wave_row: HBoxContainer = %Row
@onready var _stats: Label = %Stats
@onready var _mission_panel: Control = %MissionPanel
@onready var _mission_text: Label = %MissionText
@onready var _leave: Button = %Leave
@onready var _proceed: Button = %Proceed
@onready var _treasury_panel: Control = %Treasury
@onready var _treasury_row: TreasuryRow = %TreasuryRow
@onready var _mission_tube: ProgressTube = %MissionTube
@onready var _overlay_icons: HBoxContainer = %OverlayIcons
@onready var _inventory: InventoryBar = %Inventory


func _ready() -> void:
	_root.theme = MenuTheme.build_hud()
	_waves.toggle_mode = false
	_waves.pressed.connect(func() -> void:
		if combat:
			combat.waves_enabled = not combat.waves_enabled)
	_spawn.toggle_mode = false
	_spawn.pressed.connect(func() -> void:
		if combat:
			combat.spawn_wave())
	_wave_row.add_child(_waves)
	_wave_row.add_child(_spawn)
	_wave_row.move_child(_stats, -1)
	_leave.pressed.connect(leave_requested.emit)
	_proceed.pressed.connect(func() -> void:
		if combat:
			combat.proceed()
			notify("Round %d: enemies +%d%% stronger, %d%% more of them" % [combat.mission_round + 1,
				roundi((combat.strength_factor() - 1.0) * 100.0), roundi((combat.count_factor() - 1.0) * 100.0)]))
	# Flee: leave the island at once (it is saved, as with Leave).
	var flee := OverlayIcon.new(&"flee", "Flee: leave the island now and return to the menu (the island is saved)")
	flee.toggle_mode = false
	flee.pressed.connect(leave_requested.emit)
	_overlay_icons.get_parent().add_child(VSeparator.new())
	_overlay_icons.get_parent().add_child(flee)
	_flee = flee
	for entry in OVERLAYS:
		var icon := OverlayIcon.new(entry[0], entry[1])
		icon.preview_started.connect(_set_overlay)
		icon.preview_ended.connect(func() -> void: _set_overlay(_locked_overlay))
		icon.toggled.connect(_on_overlay_toggled.bind(icon))
		_overlay_icons.add_child(icon)
	# Compact overlay and wave panels: thinner margins than the other HUD panels.
	var panel := _root.theme.get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
	panel.content_margin_left = 7
	panel.content_margin_right = 7
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	_overlay_panel.add_theme_stylebox_override("panel", panel)
	_top_bar.add_theme_stylebox_override("panel", panel)
	_deck.windows = [_inventory_panel, _info_panel, _treasury_panel]
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notices.add_theme_constant_override("separation", 4)
	_root.add_child(_notices)


## Shows a notice below the overlay icons, e.g. a find or a level-up (newest at the bottom).
func notify(text: String) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.54))
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	panel.set_meta(&"left", NOTICE_TIME + NOTICE_FADE)
	_notices.add_child(panel)


func _update_notices(delta: float) -> void:
	for panel: Control in _notices.get_children():
		var left: float = panel.get_meta(&"left") - delta
		panel.set_meta(&"left", left)
		panel.modulate.a = clampf(left / NOTICE_FADE, 0.0, 1.0)
		if left <= 0.0:
			panel.queue_free()
	_notices.reset_size()


func _process(delta: float) -> void:
	_update_notices(delta)
	if combat:
		_waves.mode = &"pause" if combat.waves_enabled else &"play"
		_waves.set_meta(&"info", "Waves are on – click to pause them (P)" if combat.waves_enabled else "Waves are paused – click to resume them (P)")
		_stats.text = "Wave %d\nEnemies %d" % [combat.wave, combat.enemies().size()]
		_stats.set_meta(&"info", "Wave %d · enemies in the sky: %d · killed so far: %d" % [combat.wave, combat.enemies().size(), combat.kills])
		if not _edit_mode:
			_update_mission()
		_mission_tube.value = combat.mission_progress()
		_mission_tube.set_meta(&"info", "Mission progress: %d / %d kills (placeholder until zones)" % [mini(combat.kills, combat.mission_kill_goal), combat.mission_kill_goal])
	if view == null:
		return
	if _treasury_row.treasury != view.island.treasury:
		_treasury_row.treasury = view.island.treasury
	_treasury_panel.set_meta(&"info", _describe_treasury(view.island.treasury))
	_treasury_panel.reset_size()
	# Sits on the console rail at the left, above the inventory.
	_treasury_panel.position.x = _inventory_panel.position.x + 24.0
	_info.text = _hover_text()
	_overlay_panel.reset_size()
	_notices.position = _overlay_panel.position + Vector2(0, _overlay_panel.size.y + 8.0)


## Every hover text goes into the info window (no floating tooltips): an inventory slot,
## any control with an "info" meta, an inventory tab, the tile under the mouse, or the
## controls help when nothing is hovered.
func _hover_text() -> String:
	if not _inventory.hovered_item.is_empty():
		return InventoryBar.describe(_inventory.hovered_item, view.island)
	var hovered := get_viewport().gui_get_hovered_control()
	var control := hovered
	while control:
		if control.has_meta(&"info"):
			return control.get_meta(&"info")
		control = control.get_parent_control()
	var tab := _inventory.hovered_tab_info()
	if tab != "":
		return tab
	# Over the UI (e.g. the console) the map below doesn't count as hovered.
	var text := _describe_tile(view.hovered_coord) if hovered == null else ""
	return text if text != "" else HELP


## Edit mode: hides the wave controls and mission tube; the mission bar says what's going on
## and its button saves and returns to the menu.
func show_edit_mode() -> void:
	_edit_mode = true
	_top_bar.visible = false
	_mission_tube.visible = false
	_mission_panel.visible = true
	_mission_text.text = "Editing island"
	_leave.text = "Done"
	_leave.visible = true
	_leave.set_meta(&"info", "Save the island and return to the main menu")
	_proceed.visible = false
	_flee.visible = false
	_mission_panel.reset_size()
	_mission_panel.position.x = (_root.size.x - _mission_panel.size.x) / 2.0


## Top centre: countdown before the mission starts, then nothing, then "complete" with Leave
## and Proceed (a harder next round).
func _update_mission() -> void:
	_leave.visible = combat.mission_done
	_proceed.visible = combat.mission_done
	if combat.mission_done:
		_mission_text.text = "Round %d complete" % (combat.mission_round + 1) if combat.mission_round > 0 else "Mission complete"
	elif combat.mission_countdown > 0.0:
		_mission_text.text = ("Round %d starts in %d" % [combat.mission_round + 1, ceili(combat.mission_countdown)]) if combat.mission_round > 0 \
			else "Mission starts in %d" % ceili(combat.mission_countdown)
	_mission_panel.visible = combat.mission_done or combat.mission_countdown > 0.0
	_mission_panel.reset_size()
	_mission_panel.position.x = (_root.size.x - _mission_panel.size.x) / 2.0


func _set_overlay(mode: StringName) -> void:
	if view:
		view.overlay = mode


func _on_overlay_toggled(on: bool, icon: OverlayIcon) -> void:
	# Only one overlay can be locked; clicking another icon swaps it.
	for other in _overlay_icons.get_children():
		if other != icon:
			(other as Button).set_pressed_no_signal(false)
	_locked_overlay = icon.mode if on else &""
	_set_overlay(_locked_overlay)


## Hover text of the gold plaque: gold and every faction resource by name.
static func _describe_treasury(t: Treasury) -> String:
	var parts: PackedStringArray = ["Gold %d" % t.gold, "Blueprints %d (buy new towers and tiles)" % t.blueprints]
	for biome in Treasury.STONE_BIOMES:
		parts.append("%s %d (%s)" % [Biome.resource_name(biome), t.resources.get(biome, 0), Biome.name_of(biome)])
	return " · ".join(parts) + "\nFaction resources drop from enemies and pay for biome stones and tier upgrades."


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
	var price := _describe_price(coord)
	if price != "":
		lines.append(price)
	if tile.tower:
		lines.append_array(_describe_building(coord, tile))
	var what := "HQ" if tile.is_hq else "%s · Tier %d" % [Biome.name_of(tile.biome), tile.tier]
	if tile.destroyed:
		what += " · WASTELAND"
	lines.append("%s%s · Ground HP %d / %d" % ["Ground: " if tile.tower else "", what, ceili(tile.hp), roundi(view.island.tile_max_hp(coord))])
	if tile.tower == null and not tile.is_hq:
		lines.append("Conducts %d%% of passing energy" % roundi(EnergyGrid.pass_through(tile, view.island) * 100.0))
	if tile.is_hq:
		var cannon := AttackProfiles.hq()
		lines.append("Cannon: %.0f dmg every %.1fs · range %.1f hex · no energy" % [cannon.damage, cannon.cooldown, cannon.range_hexes])
	var generator := EnergyGrid.generator_at(view.island, coord)
	if generator:
		lines.append("Generator: %.1f/s · reach %d · %s" % [generator.output, generator.reach(), _describe_falloff(generator)])
	var effects := view.island.aura_at(coord)
	if not effects.is_empty():
		lines.append("Auras: " + Auras.describe(effects))
	return "
".join(lines)


## The building on `coord`: name, level and combined size; its (shared) pools; what it does
## right now; and where its effect bonus comes from.
func _describe_building(coord: Vector2i, tile: IslandTile) -> PackedStringArray:
	var island := view.island
	var tower := tile.tower
	var lines: PackedStringArray = []
	var level := tower.level()
	var head := "%s · %sLevel %d" % [String(tower.type).capitalize(), "Tier %d · " % tower.tier if tower.tier > 1 else "", level]
	if level < Tower.MAX_LEVEL:
		var from := Tower.xp_for_level(level)
		head += " (%d / %d XP)" % [floori(tower.xp - from), ceili(Tower.xp_for_level(level + 1) - from)]
	var root_tower := island.get_tower(island.merge_root_of(coord))
	if root_tower.size() >= 2:
		head += " · merged ×%d" % root_tower.size()
	var size := island.cluster_towers(coord)
	if size >= 2:
		head += " · cluster of %d" % size
	lines.append(head)
	var pools: PackedStringArray = []
	var hp := island.group_pool(coord, &"hp")
	pools.append("HP %d / %d" % [ceili(hp.x), roundi(hp.y)])
	var shield := island.group_pool(coord, &"shield")
	if shield.y > 0.0:
		pools.append("Shield %d / %d" % [ceili(shield.x), roundi(shield.y)])
	var energy := island.group_pool(coord, &"energy")
	if energy.y > 0.0:
		pools.append("Energy %.0f / %.0f" % [energy.x, energy.y])
	lines.append(" · ".join(pools))
	match tower.type:
		&"attack":
			lines.append(_describe_attack(AttackProfiles.for_tile(island, coord)))
		&"repair":
			lines.append(_describe_repair(RepairProfiles.for_tile(island, coord)))
		&"aura":
			lines.append(_describe_aura(AuraProfiles.for_tile(island, coord), tower.aura_power))
		&"scout":
			lines.append(_describe_scout(ScoutProfiles.for_tile(island, coord), tower.aura_power))
	var parts: PackedStringArray = ["level +%d%%" % roundi(tower.level_bonus() * 100.0)]
	if tower.tier > 1:
		parts.append("tiers +%d%%" % roundi(tower.tier_bonus() * 100.0))
	if size >= 2:
		parts.append("combined effect +%d%%" % roundi(Island.MERGE_BONUS * 100.0))
	if root_tower.size() >= 2:
		parts.append("merged effect ×%d" % root_tower.size())
	# Perk points are shared within a cluster.
	var perks := 0
	var counted := {}
	for member in island.group_of(coord):
		var root := island.merge_root_of(member)
		if not counted.has(root):
			counted[root] = true
			perks += island.get_tower(root).perk_points()
	lines.append("Stats +%d%% (%s) · perk points %d%s" % [roundi((tower.stat_factor() - 1.0) * 100.0), ", ".join(parts), perks, " (shared)" if size >= 2 else ""])
	if not island.merge_set(coord).is_empty():
		lines.append("Can merge – use the merge icon (top left) and click it")
	var cost := island.tier_up_cost(coord)
	if not cost.is_empty():
		lines.append("Ready for Tier %d – press U (%d gold, %d %s)" % [tower.tier + 1, cost.gold, cost.amount, Biome.resource_name(cost.resource)])
	return lines


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
