class_name TreasuryRow
extends Control
## The gold plaque's content: a gold coin with the amount on the left, the blueprints next to
## it, then every faction resource as a small gem in its biome's colour (greyed while 0).

const FONT_SIZE := 17
const GAP := 14.0
const ICON := 7.0

var treasury: Treasury:
	set(value):
		treasury = value
		treasury.changed.connect(_refresh)
		_refresh()


func _refresh() -> void:
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	if treasury == null:
		return Vector2(80, 22)
	var font := get_theme_default_font()
	var width := 0.0
	for entry in _entries():
		width += ICON * 2.0 + 5.0 + font.get_string_size(str(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + GAP
	return Vector2(width - GAP, 22)


## [biome, or -1 for gold and -2 for blueprints, amount] for everything shown.
func _entries() -> Array:
	var list: Array = [[-1, treasury.gold], [-2, treasury.blueprints]]
	for biome in Treasury.STONE_BIOMES:
		list.append([biome, treasury.resources.get(biome, 0)])
	return list


func _draw() -> void:
	if treasury == null:
		return
	var font := get_theme_default_font()
	var x := 0.0
	var mid := size.y / 2.0
	for entry in _entries():
		var icon := Vector2(x + ICON, mid)
		var amount: int = entry[1]
		if entry[0] == -2:
			ToolIcon.draw_blueprint_icon(self, icon, ICON)
		elif entry[0] < 0:
			draw_circle(icon + Vector2(0.5, 1), ICON, Color(0, 0, 0, 0.5))
			draw_circle(icon, ICON, Color("8a6414"))
			draw_circle(icon, ICON - 1.5, Color("f2c94c"))
			draw_circle(icon + Vector2(-2, -2), 2.0, Color("fff3c4"))
		else:
			ToolIcon.draw_resource_icon(self, icon, ICON, entry[0], amount > 0)
		var text := str(amount)
		var pos := Vector2(x + ICON * 2.0 + 5.0, mid + FONT_SIZE * 0.35)
		var tint := MenuTheme.CREAM if amount > 0 or entry[0] < 0 else Color(MenuTheme.CREAM, 0.4)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color(0, 0, 0, 0.7))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, tint)
		x += ICON * 2.0 + 5.0 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		x += GAP + (6.0 if entry[0] < 0 else 0.0)
