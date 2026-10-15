extends Node2D
## Prototype sandbox: wires camera input to the island and the island to the HUD.

@onready var _island_view: IslandView = $IslandView
@onready var _camera: CameraController = $Camera
@onready var _hud: Hud = $HUD


func _ready() -> void:
	_camera.tapped.connect(_island_view.handle_tap)
	_camera.secondary_tapped.connect(_island_view.handle_secondary_tap)
	_hud.view = _island_view
