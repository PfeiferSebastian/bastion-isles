extends Node2D
## Island scene: wires camera input to the island and the island to the HUD. Plays a mission,
## or in edit mode (GameSession.edit_mode) just lets the player build without enemies.
## Esc drops the selected item, otherwise flees to the main menu (see _flee); leaving or
## fleeing saves the island (IslandSave).
## During a mission E (or the HUD's hammer icon) toggles the battle edit mode: the fight is
## paused (scene tree paused; only the island view, camera and HUD keep running) and the
## player adds towers, tiles and biome stones (nothing can be removed in a mission); what is
## built stays under construction for a while once the fight resumes
## (Island.start_construction).

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var _island_view: IslandView = $IslandView
@onready var _camera: CameraController = $Camera
@onready var _hud: Hud = $HUD
@onready var _combat: Combat = $Combat

## The battle is paused for editing (see set_editing).
var editing := false
## The retreat report is open; the battle stays paused until Return.
var retreating := false

## Seconds of fighting between saves of the towers' XP (IslandSave.save_tower_xp), so closing
## the game or a crash loses at most this much.
const XP_SAVE_INTERVAL := 15.0
var _xp_save_time := 0.0


func _ready() -> void:
	# Pausing the tree freezes the fight; the view, camera and HUD keep working for editing.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for frozen: Node in [_combat, $FogLayer, $SkyBackground]:
		frozen.process_mode = Node.PROCESS_MODE_PAUSABLE
	_camera.tapped.connect(_on_tapped)
	_camera.secondary_tapped.connect(_on_secondary_tapped)
	_hud.view = _island_view
	_hud.combat = _combat
	_hud.leave_requested.connect(_leave)
	_hud.flee_requested.connect(_flee)
	_hud.edit_requested.connect(func() -> void: set_editing(not editing))
	_hud.return_requested.connect(_leave)
	if GameSession.edit_mode:
		_island_view.island.gains_xp = false
		_combat.set_process(false)
		_combat.set_process_unhandled_key_input(false)
		_hud.show_edit_mode()
	else:
		_island_view.island.builds_take_time = true
	_hud.get_node("%Inventory").set(&"view", _island_view)
	_island_view.message.connect(func(at: Vector2, text: String) -> void: _combat.popup(at, text, Color("ffb070")))


func _process(delta: float) -> void:
	if GameSession.edit_mode or get_tree().paused:
		return
	_xp_save_time += delta
	if _xp_save_time >= XP_SAVE_INTERVAL:
		_xp_save_time = 0.0
		IslandSave.save_tower_xp(_island_view.island)


## Closing the window: Edit Island saves everything; a mission keeps its towers' XP, while its
## loot stays as if the player had never left the menu.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if GameSession.edit_mode:
		IslandSave.save(_island_view.island)
	else:
		IslandSave.save_tower_xp(_island_view.island)


## Clicks on enemies set the focus fire scope (Combat.focus_click); with an inventory item
## held, or off the enemies, they go to the island as usual.
func _on_tapped(world_position: Vector2) -> void:
	if _island_view.held.is_empty() and not editing and _combat.focus_click(world_position):
		return
	_island_view.handle_tap(world_position)


func _on_secondary_tapped(world_position: Vector2) -> void:
	if _island_view.held.is_empty() and not editing and _combat.focus_secondary_click(world_position):
		return
	_island_view.handle_secondary_tap(world_position)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if retreating:
		# The retreat report is open: Esc or Enter returns like its button.
		if key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			_leave()
		return
	if key.keycode == KEY_E:
		set_editing(not editing)
	elif key.keycode == KEY_ESCAPE:
		# Esc first drops a selected inventory item, then leaves edit mode, otherwise returns
		# to the menu.
		if not _island_view.held.is_empty():
			_island_view.release_hold()
		elif editing:
			set_editing(false)
		else:
			_flee()


## Pauses the mission for editing (`on`) or resumes it exactly where it was. Not in the main
## menu's Edit Island, which has no fight.
func set_editing(on: bool) -> void:
	if GameSession.edit_mode or retreating or on == editing:
		return
	editing = on
	get_tree().paused = on
	_hud.show_battle_edit(on)


## Leaves a running mission as a flight (Combat.flee: most of this mission's loot is lost,
## lost towers come back at level 0, nothing is lost in endless mode): the battle pauses and
## a report of the loot found, lost and kept opens; its Return leaves. After a win, a defeat
## or in edit mode it's a plain leave.
func _flee() -> void:
	if retreating:
		return
	if GameSession.edit_mode or _combat.mission_done or _combat.defeated:
		_leave()
		return
	var result := _combat.flee()
	retreating = true
	get_tree().paused = true
	_hud.show_retreat_report(_combat.mission_loot, result)


## Saves the island (repaired, as after any fight) and returns to the main menu.
func _leave() -> void:
	get_tree().paused = false
	if not GameSession.edit_mode:
		_combat.finish_wave_log()
	_island_view.island.restore_tiles()
	IslandSave.save(_island_view.island)
	get_tree().change_scene_to_file(MENU_SCENE)
