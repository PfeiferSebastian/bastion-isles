class_name InventoryBar
extends VBoxContainer
## Inventory at the bottom of the combat screen: a tab for terrain (tiles and biome stones)
## and one tab per tower type (stacks by level, buy button). Click a slot to select it for
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
		var owned := 0
		for level in inventory.tower_levels(type):
			owned += inventory.count(Inventory.tower_item(type, level))
		_tabs.set_tab_title(i + 1, "%s (%d)" % [String(type).capitalize(), owned])
		_tabs.set_tab_disabled(i + 1, not treasury.is_unlocked(type) and owned == 0)
		_tab_info[i + 1] = "%s: %d in the inventory%s" % [String(type).capitalize(), owned, "" if treasury.is_unlocked(type) else " · needs a blueprint to buy more"]
	for child in _slots.get_children():
		child.queue_free()
	if _tabs.current_tab == TERRAIN_TAB:
		_add_slot(&"tile", Inventory.tile_item())
		for biome in Treasury.STONE_BIOMES:
			_add_slot(STONE_KINDS[biome], Inventory.stone_item(biome))
	else:
		var type: StringName = TowerDefs.TYPES[_tabs.current_tab - 1]
		var levels := inventory.tower_levels(type)
		if levels.is_empty():
			levels = [1]
		for level in levels:
			_add_slot(type, Inventory.tower_item(type, level), "Lv%d" % level)


## A slot selects its item (click) or starts a drag. With none left but enough gold for a
## buyable item, pressing it buys one first.
func _add_slot(kind: StringName, item: Dictionary, badge := "") -> void:
	var treasury := view.island.treasury
	var amount := treasury.inventory.count(item)
	var price := Economy.buy_price(item, view.island)
	var can_buy := price >= 0 and treasury.gold >= price
	var slot := ToolIcon.new(kind, "×%d" % amount, "")
	slot.price = price
	slot.badge = badge
	slot.set_meta(&"item", item)
	slot.button_group = _group
	slot.modulate = Color.WHITE if amount > 0 or can_buy else Color(1, 1, 1, 0.4)
	slot.disabled = amount <= 0 and not can_buy
	slot.button_down.connect(func() -> void:
		if Economy.ensure_one(item, view.island):
			view.begin_drag(item))
	_slots.add_child(slot)


## Name, what it does (biome stones and tiles) and its price.
static func describe(item: Dictionary, island: Island = null) -> String:
	var text := Inventory.label_of(item)
	match item.kind:
		&"stone":
			text += " · only found as loot\n" + Biome.description_of(item.biome)
		&"tile":
			text += "\nNew neutral ground next to the island.\n" + Biome.description_of(Biome.Type.NEUTRAL)
	if island and Economy.price_of(item, island) >= 0:
		text += "\nPrice: %d gold (bought automatically when you have none)" % Economy.price_of(item, island)
	return text


## Hover text of the tab under the mouse, or "".
func hovered_tab_info() -> String:
	if not _tabs.get_global_rect().has_point(get_global_mouse_position()):
		return ""
	return _tab_info.get(_tabs.get_tab_idx_at_point(_tabs.get_local_mouse_position()), "")
