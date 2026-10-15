class_name MenuTheme
extends RefCounted
## Steampunk UI theme built in code: brass-framed buttons and panels, serif lettering.
## Placeholder until real UI art exists; reuse it for in-game menus too.

const BRASS := Color("c9a24a")
const BRASS_LIGHT := Color("f0d28a")
const BRASS_DARK := Color("6e5019")
const COPPER := Color("b4643c")
const IRON := Color("2f2a26")
const PANEL := Color("2b231d")
const CREAM := Color("f3e6c4")


static func serif(weight := 600) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cinzel", "Book Antiqua", "Palatino Linotype", "Georgia", "Times New Roman", "serif"])
	font.font_weight = weight
	return font


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = serif()
	theme.default_font_size = 24

	theme.set_stylebox("normal", "Button", _plate(PANEL, BRASS))
	theme.set_stylebox("hover", "Button", _plate(PANEL.lightened(0.12), BRASS_LIGHT))
	theme.set_stylebox("pressed", "Button", _plate(IRON, BRASS_DARK, 2))
	theme.set_stylebox("focus", "Button", _plate(Color(0, 0, 0, 0), BRASS_LIGHT, 0, 2))
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", BRASS_LIGHT)
	theme.set_color("font_pressed_color", "Button", BRASS)
	theme.set_color("font_focus_color", "Button", CREAM)
	theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.7))
	theme.set_constant("outline_size", "Button", 4)

	theme.set_stylebox("panel", "PanelContainer", _plate(Color(PANEL, 0.96), BRASS, 0, 4))
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	theme.set_constant("outline_size", "Label", 4)
	theme.set_color("font_color", "CheckButton", CREAM)
	theme.set_color("font_hover_color", "CheckButton", BRASS_LIGHT)

	# Big engraved title.
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", serif(800))
	theme.set_font_size("font_size", "TitleLabel", 88)
	theme.set_color("font_color", "TitleLabel", BRASS_LIGHT)
	theme.set_color("font_outline_color", "TitleLabel", Color("3a2408"))
	theme.set_constant("outline_size", "TitleLabel", 14)
	theme.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.45))
	theme.set_constant("shadow_offset_x", "TitleLabel", 4)
	theme.set_constant("shadow_offset_y", "TitleLabel", 6)
	return theme


## Brass-rimmed plate: dark fill, metal border, rounded corners, soft drop shadow.
static func _plate(fill: Color, rim: Color, shift_down := 0, border := 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(border)
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 10 + shift_down
	box.content_margin_bottom = 10 - shift_down
	return box
