extends Control
## Main menu: title at the top, Start / Edit Island / Options / Exit at the bottom middle,
## steampunk frame and a floating island over the cloud sky.

const GAME_SCENE := "res://main.tscn"

@onready var _island: Node2D = $Island
@onready var _buttons: Control = $Buttons
@onready var _start: Button = %Start
@onready var _edit_island: Button = %EditIsland
@onready var _options: Button = %Options
@onready var _exit: Button = %Exit
@onready var _options_panel: Control = %OptionsPanel
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _volume: HSlider = %Volume
@onready var _back: Button = %Back


func _ready() -> void:
	theme = MenuTheme.build()
	_start.pressed.connect(_open_island.bind(false))
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


func _layout() -> void:
	_island.call(&"place", Vector2(size.x / 2.0, size.y * 0.38))


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
