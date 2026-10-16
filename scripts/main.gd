extends Node2D
## Island scene: wires camera input to the island and the island to the HUD. Plays a mission,
## or in edit mode (GameSession.edit_mode) just lets the player build without enemies.
## Esc drops the selected item, otherwise flees to the main menu (see _flee); leaving or
## fleeing saves the island (IslandSave).

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
	_hud.leave_requested.connect(_leave)
	_hud.flee_requested.connect(_flee)
	if GameSession.edit_mode:
		_island_view.island.gains_xp = false
		_combat.set_process(false)
		_combat.set_process_unhandled_key_input(false)
		_hud.show_edit_mode()
	_hud.get_node("%Inventory").set(&"view", _island_view)
	_island_view.message.connect(func(at: Vector2, text: String) -> void: _combat.popup(at, text, Color("ffb070")))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		# Esc first drops a selected inventory item, otherwise returns to the menu.
		if not _island_view.held.is_empty():
			_island_view.release_hold()
		else:
			_flee()


## Leaves a running mission as a flight (Combat.flee: most of this mission's loot is lost,
## lost towers come back at level 0); after a win, a defeat or in edit mode it's a plain leave.
func _flee() -> void:
	if not GameSession.edit_mode:
		_combat.flee()
	_leave()


## Saves the island (repaired, as after any fight) and returns to the main menu.
func _leave() -> void:
	if not GameSession.edit_mode:
		_combat.finish_wave_log()
	_island_view.island.restore_tiles()
	IslandSave.save(_island_view.island)
	get_tree().change_scene_to_file(MENU_SCENE)
