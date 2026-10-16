class_name InventoryBar
extends VBoxContainer
## Inventory at the bottom of the combat screen: a tab for terrain (tiles and biome stones)
## and one tab per tower type (stacks by level). Click a slot to select it for
## placing, or drag it onto the map. New towers (level 0, tier 1) and tiles are bought with
## blueprints by pressing their slot with none left; the price shows bottom left. Formerly:
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
		# In stock, plus how many the blueprints could buy ("Attack (1+2)").
		var buyable := view.island.affordable_count(type)
		_tabs.set_tab_title(i + 1, "%s (%d%s)" % [String(type).capitalize(), owned, "+%d" % buyable if buyable > 0 else ""])
		_tab_info[i + 1] = "%s: %d in the inventory, %d more affordable with your %d blueprints\n%s" % [
			String(type).capitalize(), owned, buyable, treasury.blueprints, TowerDefs.description_of(type)]
	for child in _slots.get_children():
		child.queue_free()
	if _tabs.current_tab == TERRAIN_TAB:
		_add_slot(&"tile", Inventory.tile_item())
		for biome in Treasury.STONE_BIOMES:
			_add_slot(STONE_KINDS[biome], Inventory.stone_item(biome))
	else:
		var type: StringName = TowerDefs.TYPES[_tabs.current_tab - 1]
		# The fresh level 0 stack always shows (it is the one bought with blueprints).
		var stacks := inventory.tower_stacks(type)
		if not stacks.has(Vector2i(0, 1)):
			stacks.push_front(Vector2i(0, 1))
		for stack in stacks:
			_add_slot(type, Inventory.tower_item(type, stack.x, stack.y), ("T%d " % stack.y if stack.y > 1 else "") + "Lv%d" % stack.x)


## A slot selects its item (click) or starts a drag. With none left, a buyable item is bought
## first (towers and tiles with blueprints, biome stones with their faction resource); its
## price shows bottom left, and while the player can't afford it a dark build wipe shows how
## much of the price they already have.
func _add_slot(kind: StringName, item: Dictionary, badge := "") -> void:
	var island := view.island
	var amount := island.treasury.inventory.count(item)
	var slot := ToolIcon.new(kind, "×%d" % amount, "")
	slot.badge = badge
	var price := island.price_of(item)
	if not price.is_empty():
		slot.cost = price.amount
		slot.cost_currency = price.currency
		slot.progress = clampf(float(island.funds(price.currency)) / price.amount, 0.0, 1.0)
	slot.set_meta(&"item", item)
	slot.button_group = _group
	slot.modulate = Color.WHITE if amount > 0 or not price.is_empty() else Color(1, 1, 1, 0.4)
	slot.disabled = not island.can_get(item)
	slot.button_down.connect(func() -> void:
		var shop := view.island
		var paid := shop.price_of(item)
		var bought := shop.treasury.inventory.count(item) <= 0
		if shop.ensure_item(item):
			view.begin_drag(item)
			# A right click before placing undoes the purchase.
			if bought:
				view.note_purchase(item, paid))
	_slots.add_child(slot)


## Name, what it does (biome stones and tiles), where it comes from and its level.
static func describe(item: Dictionary, island: Island = null) -> String:
	var text := Inventory.label_of(item)
	match item.kind:
		&"stone":
			text += "\n" + Biome.description_of(item.biome)
			if island:
				text += "\nCosts %d %s (you have %d) – each %s tile you own makes the next cost one more" % [
					island.biome_cost(item.biome), Biome.resource_name(item.biome), island.funds(item.biome), Biome.name_of(item.biome)]
		&"tile":
			text += "\nNew neutral ground next to the island (towers on an empty hex take one along).\n" + Biome.description_of(Biome.Type.NEUTRAL)
			if island:
				text += "\nCosts %d blueprints (you have %d)" % [island.blueprint_cost(&"tile"), island.treasury.blueprints]
		&"tower":
			text += "\n" + TowerDefs.description_of(item.type)
			var stored := Tower.new(item.type, 1.0)
			stored.tier = item.get("tier", 1)
			stored.xp = Tower.xp_for_level(item.level)
			if item.level > 0 or item.get("tier", 1) > 1:
				text += "\nKeeps its level and tier: stats +%d%%" % roundi((stored.stat_factor() - 1.0) * 100.0)
			elif island:
				text += "\nCosts %d blueprints (you have %d) – each one you own makes the next cost one more" % [
					island.blueprint_cost(item.type), island.treasury.blueprints]
	return text


## Hover text of the tab under the mouse, or "".
func hovered_tab_info() -> String:
	if not _tabs.get_global_rect().has_point(get_global_mouse_position()):
		return ""
	return _tab_info.get(_tabs.get_tab_idx_at_point(_tabs.get_local_mouse_position()), "")
