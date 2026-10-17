class_name OverlayIcon
extends Button
## Small brass icon button for a map overlay (energy, repair, hp, tier) or a wave control
## (play, pause, spawn, edit). For overlays, hovering previews it and clicking locks it on.

signal preview_started(mode: StringName)
signal preview_ended

var mode: StringName:
	set(value):
		mode = value
		queue_redraw()

## Button size; the symbols are drawn for 48 px and scaled to it.
const SIZE := 29.0


func _init(overlay_mode: StringName, tooltip: String) -> void:
	mode = overlay_mode
	# Shown in the HUD info panel while hovered (no floating tooltip).
	set_meta(&"info", tooltip)
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_entered.connect(func() -> void: preview_started.emit(mode))
	mouse_exited.connect(func() -> void: preview_ended.emit())


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * size.x / 48.0)
	var c := Vector2(24, 24)
	match mode:
		&"energy":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(4, -15), c + Vector2(-8, 2), c + Vector2(-1, 2),
				c + Vector2(-5, 15), c + Vector2(8, -3), c + Vector2(1, -3),
			]), Color("ffd23f"))
		&"repair":
			# Wrench: handle plus an open jaw.
			var dir := Vector2.from_angle(deg_to_rad(-45))
			draw_line(c - dir * 12, c + dir * 6, MenuTheme.BRASS_LIGHT, 5.0, true)
			draw_circle(c + dir * 9, 7.0, MenuTheme.BRASS_LIGHT)
			draw_circle(c + dir * 12, 3.5, MenuTheme.PANEL)
			draw_circle(c - dir * 12, 3.0, MenuTheme.BRASS_LIGHT)
		&"hp":
			draw_circle(c + Vector2(-5, -3), 6.5, Color("e05545"))
			draw_circle(c + Vector2(5, -3), 6.5, Color("e05545"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-11, 0), c + Vector2(11, 0), c + Vector2(0, 13)]), Color("e05545"))
		&"tier":
			# Stacked bars, light (Tier 0) to dark (Tier 7).
			for i in 4:
				var shade := Color("e8e2d0").darkened(i * 0.22)
				draw_rect(Rect2(c + Vector2(-12 + i * 2, 8 - i * 7), Vector2(24 - i * 4, 5)), shade)
		&"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -12), c + Vector2(12, 0), c + Vector2(-8, 12)]), Color("7cc35a"))
		&"pause":
			draw_rect(Rect2(c + Vector2(-10, -12), Vector2(7, 24)), MenuTheme.BRASS_LIGHT)
			draw_rect(Rect2(c + Vector2(3, -12), Vector2(7, 24)), MenuTheme.BRASS_LIGHT)
		&"merge":
			# Two arrows pointing at each other.
			var gold := MenuTheme.BRASS_LIGHT
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 0), c + Vector2(-11, -9), c + Vector2(-11, -3), c + Vector2(-18, -3), c + Vector2(-18, 3), c + Vector2(-11, 3), c + Vector2(-11, 9)]), gold)
			draw_colored_polygon(PackedVector2Array([c + Vector2(2, 0), c + Vector2(11, -9), c + Vector2(11, -3), c + Vector2(18, -3), c + Vector2(18, 3), c + Vector2(11, 3), c + Vector2(11, 9)]), gold)
		&"flee":
			# Open door with an arrow running out of it.
			draw_rect(Rect2(c + Vector2(-14, -14), Vector2(14, 28)), Color("6b4a2e"))
			draw_rect(Rect2(c + Vector2(-14, -14), Vector2(14, 28)), MenuTheme.BRASS_DARK, false, 2.0)
			draw_circle(c + Vector2(-4, 1), 1.8, MenuTheme.BRASS_LIGHT)
			draw_line(c + Vector2(-2, 0), c + Vector2(13, 0), Color("e05545"), 4.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(17, 0), c + Vector2(8, -8), c + Vector2(8, 8)]), Color("e05545"))
		&"edit":
			# Hammer: wooden handle, brass head.
			var dir := Vector2.from_angle(deg_to_rad(-45))
			draw_line(c - dir * 14, c + dir * 8, Color("8a5a32"), 5.0, true)
			var side := dir.orthogonal()
			var head := c + dir * 9
			draw_colored_polygon(PackedVector2Array([head - side * 11 - dir * 4, head + side * 9 - dir * 4,
				head + side * 9 + dir * 4, head - side * 11 + dir * 4]), MenuTheme.BRASS_LIGHT)
		&"spawn":
			# Enemy airship: balloon over a small hull, with a red plus.
			draw_circle(c + Vector2(-3, -5), 10.0, Color("8a8f98"))
			draw_rect(Rect2(c + Vector2(-13, -6), Vector2(20, 2)), Color("5d626b"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 7), c + Vector2(6, 7), c + Vector2(2, 13), c + Vector2(-8, 13)]), Color("6b4a2e"))
			draw_line(c + Vector2(-8, 4), c + Vector2(-9, 7), Color("2f2a26"), 1.5)
			draw_line(c + Vector2(2, 4), c + Vector2(3, 7), Color("2f2a26"), 1.5)
			draw_rect(Rect2(c + Vector2(9, -14), Vector2(10, 3)), Color("e05545"))
			draw_rect(Rect2(c + Vector2(12.5, -17.5), Vector2(3, 10)), Color("e05545"))
