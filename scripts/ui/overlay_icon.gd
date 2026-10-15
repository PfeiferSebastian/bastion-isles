class_name OverlayIcon
extends Button
## Round brass icon button for a map overlay (energy, repair, hp, tier).
## Hovering previews the overlay; clicking locks it on until clicked again.

signal preview_started(mode: StringName)
signal preview_ended

var mode: StringName


func _init(overlay_mode: StringName, tooltip: String) -> void:
	mode = overlay_mode
	tooltip_text = tooltip
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(48, 48)
	mouse_entered.connect(func() -> void: preview_started.emit(mode))
	mouse_exited.connect(func() -> void: preview_ended.emit())


func _draw() -> void:
	var c := size / 2.0
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
