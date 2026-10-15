extends Node2D
## Prototype sandbox: wires camera input to the island and the island to the HUD.
## Esc returns to the main menu.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var _island_view: IslandView = $IslandView
@onready var _camera: CameraController = $Camera
@onready var _hud: Hud = $HUD
@onready var _combat: Combat = $Combat


func _ready() -> void:
	_camera.tapped.connect(_island_view.handle_tap)
	_camera.secondary_tapped.connect(_island_view.handle_secondary_tap)
	_hud.view = _island_view
	_hud.combat = _combat


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(MENU_SCENE)
