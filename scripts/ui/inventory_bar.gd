class_name InventoryBar
extends VBoxContainer
## Inventory at the bottom of the combat screen: a tab for terrain (tiles and biome stones)
## and one tab per tower type (stacks by level). Click a slot to select it for
## placing, or drag it onto the map. Locked tower types need a blueprint to be bought, but
## towers already in the inventory (e.g. the starting Repair) can always be placed.

const TERRAIN_TAB := 0
const STONE_KINDS := {
	Biome.Type.FOREST: &"forest", Biome.Type.MOUNTAIN: &"mountain", Biome.Type.PLAINS: &"plains",
	Biome.Type.SWAMP: &"swamp", Biome.Type.LAKE: &"lake",
}

var view: IslandView:
	set(value):
		view = value
		view.island.treasury.changed.connect(_rebuild)
		_rebuild()

## Item under the mouse (empty if none); the HUD shows its description in the info panel.
var hovered_item: Dictionary = {}
## Hover text per tab index, shown in the HUD info panel.
var _tab_info: Dictionary[int, String] = {}

var _tabs := TabBar.new()
var _slots := HBoxContainer.new()
var _group := ButtonGroup.new()


func _ready() -> void:
	_tabs.add_tab("Terrain")
	for type in TowerDefs.TYPES:
		_tabs.add_tab(String(type).capitalize())
	_tabs.focus_mode = Control.FOCUS_NONE
	_tabs.add_theme_font_size_override("font_size", 13)
	_tabs.tab_changed.connect(func(_i: int) -> void: _rebuild())
	_slots.add_theme_constant_override("separation", 6)
	add_child(_tabs)
	add_child(_slots)


func _process(_delta: float) -> void:
	# Keep the pressed slot in sync with what the island view is holding.
	if view == null:
		return
	# Slots are rebuilt whenever gold or items change, so the hover is found by position
	# every frame (enter/exit signals would drop it on each rebuild).
	hovered_item = {}
	var mouse := get_global_mouse_position()
	for child in _slots.get_children():
		var slot := child as ToolIcon
		if slot and slot.has_meta(&"item") and not slot.is_queued_for_deletion():
			slot.set_pressed_no_signal(slot.get_meta(&"item") == view.held)
			if slot.get_global_rect().has_point(mouse):
				hovered_item = slot.get_meta(&"item")


func _rebuild() -> void:
	if view == null:
		return
	var treasury := view.island.treasury
	var inventory := treasury.inventory
	var terrain := inventory.tiles
	for biome in Treasury.STONE_BIOMES:
		terrain += inventory.count(Inventory.stone_item(biome))
	_tabs.set_tab_title(TERRAIN_TAB, "Terrain (%d)" % terrain)
	_tab_info[TERRAIN_TAB] = "Terrain: %d tiles and biome stones in the inventory" % terrain
	for i in TowerDefs.TYPES.size():
		var type: StringName = TowerDefs.TYPES[i]
		var owned := inventory.tower_count(type)
		_tabs.set_tab_title(i + 1, "%s (%d)" % [String(type).capitalize(), owned])
		_tab_info[i + 1] = "%s (%d in the inventory)\n%s" % [String(type).capitalize(), owned, TowerDefs.description_of(type)]
	for child in _slots.get_children():
		child.queue_free()
	if _tabs.current_tab == TERRAIN_TAB:
		_add_slot(&"tile", Inventory.tile_item())
		for biome in Treasury.STONE_BIOMES:
			_add_slot(STONE_KINDS[biome], Inventory.stone_item(biome))
	else:
		var type: StringName = TowerDefs.TYPES[_tabs.current_tab - 1]
		# The fresh level 0 stack always shows (it carries the blueprint progress).
		var stacks := inventory.tower_stacks(type)
		if not stacks.has(Vector2i(0, 1)):
			stacks.push_front(Vector2i(0, 1))
		for stack in stacks:
			_add_slot(type, Inventory.tower_item(type, stack.x, stack.y), ("T%d " % stack.y if stack.y > 1 else "") + "Lv%d" % stack.x)


## A slot selects its item (click) or starts a drag; empty stacks are greyed out.
func _add_slot(kind: StringName, item: Dictionary, badge := "") -> void:
	var amount := view.island.treasury.inventory.count(item)
	var slot := ToolIcon.new(kind, "×%d" % amount, "")
	slot.badge = badge
	var fresh_tower: bool = item.kind == &"tower" and item.level == 0 and item.get("tier", 1) == 1
	var blueprint_kind: StringName = &"tile" if item.kind == &"tile" else (item.type if fresh_tower else &"")
	if blueprint_kind != &"":
		# Blueprints toward the next one: "have/need" in the corner, plus the build wipe when empty.
		var have: int = view.island.treasury.blueprints.get(blueprint_kind, 0)
		var need := view.island.blueprints_needed(blueprint_kind)
		slot.progress = float(have) / need
		slot.corner_text = "%d/%d" % [have, need]
	slot.set_meta(&"item", item)
	slot.button_group = _group
	# Towers and tiles show their blueprint progress (a dark build wipe while none are in
	# stock), so only other empty stacks are faded.
	var has_progress: bool = blueprint_kind != &""
	slot.modulate = Color.WHITE if amount > 0 or has_progress else Color(1, 1, 1, 0.4)
	slot.disabled = amount <= 0
	slot.button_down.connect(func() -> void:
		if view.island.treasury.inventory.count(item) > 0:
			view.begin_drag(item))
	_slots.add_child(slot)


## Name, what it does (biome stones and tiles), where it comes from and its level.
static func describe(item: Dictionary, island: Island = null) -> String:
	var text := Inventory.label_of(item)
	match item.kind:
		&"stone":
			text += " · only found as loot\n" + Biome.description_of(item.biome)
		&"tile":
			text += "\nNew neutral ground next to the island (towers on an empty hex take one along).\n" + Biome.description_of(Biome.Type.NEUTRAL)
		&"tower":
			text += "\n" + TowerDefs.description_of(item.type)
			var stored := Tower.new(item.type, 1.0)
			stored.tier = item.get("tier", 1)
			stored.xp = Tower.xp_for_level(item.level)
			text += "\nKeeps its level and tier: stats +%d%%" % roundi((stored.stat_factor() - 1.0) * 100.0)
	return text


## Hover text of the tab under the mouse, or "".
func hovered_tab_info() -> String:
	if not _tabs.get_global_rect().has_point(get_global_mouse_position()):
		return ""
	return _tab_info.get(_tabs.get_tab_idx_at_point(_tabs.get_local_mouse_position()), "")
