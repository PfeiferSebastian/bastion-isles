extends Control
## Main menu: the title at the top, Start / Edit Island / Options / Exit in a column
## on the left, the island (in the game's own tile art) floating on the right while enemy
## airship formations cross the cloud sky, all inside the steampunk frame. Start opens the mission select:
## numbered missions (1-1, 1-2 … 2-1 …), the endless mode below them and Back at the bottom.

const GAME_SCENE := "res://main.tscn"

@onready var _island: Node2D = $Island
@onready var _airships: Node2D = $Airships
@onready var _buttons: Control = $Buttons
@onready var _start: Button = %Start
@onready var _edit_island: Button = %EditIsland
@onready var _options: Button = %Options
@onready var _exit: Button = %Exit
@onready var _options_panel: Control = %OptionsPanel
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _volume: HSlider = %Volume
@onready var _back: Button = %Back
var _missions_panel := PanelContainer.new()


func _ready() -> void:
	theme = MenuTheme.build()
	_build_mission_select()
	_start.pressed.connect(_show_missions.bind(true))
	_edit_island.pressed.connect(_open_island.bind(true))
	_options.pressed.connect(_show_options.bind(true))
	_exit.pressed.connect(get_tree().quit)
	_back.pressed.connect(_show_options.bind(false))
	_fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_volume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	_volume.value_changed.connect(_on_volume_changed)
	resized.connect(_layout)
	_layout()
	_show_options(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _options_panel.visible:
		_show_options(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _missions_panel.visible:
		_show_missions(false)
		get_viewport().set_input_as_handled()


## The mission select overlay: a heading, one row of mission buttons per world, the endless
## mode centred below and Back at the very bottom of the frame.
func _build_mission_select() -> void:
	_missions_panel.set_anchors_preset(Control.PRESET_CENTER)
	_missions_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_missions_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_missions_panel.add_child(content)
	var heading := Label.new()
	heading.text = "Choose a mission"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	content.add_child(heading)
	var grid := GridContainer.new()
	# A "World n" label before each row of missions.
	grid.columns = GameSession.MISSIONS_PER_WORLD + 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for world in range(1, GameSession.WORLDS + 1):
		var label := Label.new()
		label.text = "World %d" % world
		label.add_theme_color_override("font_color", MenuTheme.BRASS_LIGHT)
		label.add_theme_font_size_override("font_size", 22)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(label)
		for number in range(1, GameSession.MISSIONS_PER_WORLD + 1):
			var which := Vector2i(world, number)
			var rules := GameSession.mission_rules(which)
			# Mission number with its kill goal below.
			var button := _menu_button("%s
%d kills" % [GameSession.mission_name(which), rules.kill_goal], Vector2(96, 58))
			button.add_theme_font_size_override("font_size", 18)
			button.tooltip_text = "%d kills · enemies %d%% stronger, %d%% more of them" % [rules.kill_goal,
				roundi((rules.strength - 1.0) * 100.0), roundi((rules.count - 1.0) * 100.0)]
			button.pressed.connect(_start_mission.bind(which, false))
			grid.add_child(button)
	var endless := _menu_button("Endless mode", Vector2(260, 52))
	endless.tooltip_text = "Waves without end that slowly get harder – leave whenever you like"
	endless.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	endless.pressed.connect(_start_mission.bind(Vector2i(1, 1), true))
	content.add_child(endless)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	content.add_child(spacer)
	var back := _menu_button("Back", Vector2(200, 46))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_missions.bind(false))
	content.add_child(back)
	_missions_panel.visible = false
	add_child(_missions_panel)


static func _menu_button(text: String, min_size: Vector2) -> Button:
	var button := BrassButton.new()
	button.text = text
	button.custom_minimum_size = min_size
	return button


func _show_missions(open: bool) -> void:
	_missions_panel.visible = open
	_buttons.visible = not open
	_island.visible = not open
	_airships.visible = not open
	if open:
		_missions_panel.reset_size()
		_missions_panel.position = (size - _missions_panel.size) / 2.0 + Vector2(0, 40)
	else:
		_start.grab_focus()


func _start_mission(which: Vector2i, endless: bool) -> void:
	GameSession.mission = which
	GameSession.endless = endless
	_open_island(false)


func _layout() -> void:
	# Right of the button column, a little below the title.
	_island.call(&"place", Vector2(size.x * 0.64, size.y * 0.5))


## Opens the island scene for a mission, or for editing without enemies.
func _open_island(edit: bool) -> void:
	GameSession.edit_mode = edit
	get_tree().change_scene_to_file(GAME_SCENE)


func _show_options(open: bool) -> void:
	_options_panel.visible = open
	_buttons.visible = not open
	(_back if open else _start).grab_focus()


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value / 100.0, 0.0001)))
