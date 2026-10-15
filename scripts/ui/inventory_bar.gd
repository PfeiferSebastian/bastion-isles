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

var _tabs := TabBar.new()
var _slots := HBoxContainer.new()
var _group := ButtonGroup.new()


func _ready() -> void:
	_tabs.add_tab("Terrain")
	for type in TowerDefs.TYPES:
		_tabs.add_tab(String(type).capitalize())
	_tabs.focus_mode = Control.FOCUS_NONE
	_tabs.tab_changed.connect(func(_i: int) -> void: _rebuild())
	_slots.add_theme_constant_override("separation", 6)
	add_child(_tabs)
	add_child(_slots)


func _process(_delta: float) -> void:
	# Keep the pressed slot in sync with what the island view is holding.
	if view == null:
		return
	for child in _slots.get_children():
		var slot := child as ToolIcon
		if slot and slot.has_meta(&"item"):
			slot.set_pressed_no_signal(slot.get_meta(&"item") == view.held)


func _rebuild() -> void:
	if view == null:
		return
	var treasury := view.island.treasury
	for i in TowerDefs.TYPES.size():
		var type: StringName = TowerDefs.TYPES[i]
		var usable := treasury.is_unlocked(type) or not treasury.inventory.tower_levels(type).is_empty()
		_tabs.set_tab_disabled(i + 1, not usable)
		_tabs.set_tab_tooltip(i + 1, "" if treasury.is_unlocked(type) else "Needs a blueprint to buy more")
	for child in _slots.get_children():
		child.queue_free()
	if _tabs.current_tab == TERRAIN_TAB:
		_add_slot(&"tile", Inventory.tile_item())
		_add_buy("Buy tile\n%d gold" % Economy.tile_cost(view.island), Inventory.tile_item(), Economy.tile_cost(view.island))
		for biome in Treasury.STONE_BIOMES:
			_add_slot(STONE_KINDS[biome], Inventory.stone_item(biome))
	else:
		var type: StringName = TowerDefs.TYPES[_tabs.current_tab - 1]
		var levels := treasury.inventory.tower_levels(type)
		if levels.is_empty():
			levels = [1]
		for level in levels:
			_add_slot(type, Inventory.tower_item(type, level), "Lv%d " % level)
		if treasury.is_unlocked(type):
			_add_buy("Buy %s\n%d gold" % [String(type).capitalize(), Economy.tower_cost(type)], Inventory.tower_item(type), Economy.tower_cost(type))


func _add_slot(kind: StringName, item: Dictionary, prefix := "") -> void:
	var amount := view.island.treasury.inventory.count(item)
	var slot := ToolIcon.new(kind, "%s×%d" % [prefix, amount], Inventory.label_of(item) + "\nClick to select, or drag onto the island")
	slot.set_meta(&"item", item)
	slot.button_group = _group
	slot.modulate = Color.WHITE if amount > 0 else Color(1, 1, 1, 0.4)
	slot.disabled = amount <= 0
	slot.button_down.connect(func() -> void: view.begin_drag(item))
	_slots.add_child(slot)


func _add_buy(text: String, item: Dictionary, price: int) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = view.island.treasury.gold < price
	button.pressed.connect(func() -> void: view.island.treasury.buy(item, price))
	_slots.add_child(button)
