class_name CameraController
extends Camera2D
## Pan by dragging, zoom with mouse wheel or pinch. A press-and-release without
## dragging counts as a tap, so the same input works with mouse and touch.

signal tapped(world_position: Vector2)
signal secondary_tapped(world_position: Vector2)

@export var min_zoom := 0.5
@export var max_zoom := 2.5
@export var wheel_zoom_step := 1.1
## Pointer travel (screen pixels) before a press becomes a drag instead of a tap.
@export var drag_threshold := 12.0
## Max distance the camera may wander from the island centre.
@export var pan_limit := 1200.0

var _pressing := false
var _dragging := false
var _press_position := Vector2.ZERO
var _touches: Dictionary[int, Vector2] = {}
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_screen_touch(event)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)


func _on_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)
	if _touches.size() == 2:
		# Second finger: this is a pinch, not a tap or a pan.
		_pressing = false
		var points := _touches.values()
		_pinch_start_distance = points[0].distance_to(points[1])
		_pinch_start_zoom = zoom.x


func _on_screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() == 2 and _pinch_start_distance > 0.0:
		var points := _touches.values()
		var center: Vector2 = (points[0] + points[1]) / 2.0
		var target: float = _pinch_start_zoom * points[0].distance_to(points[1]) / _pinch_start_distance
		_zoom_at(center, target / zoom.x)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressing = true
				_dragging = false
				_press_position = event.position
			else:
				if _pressing and not _dragging:
					tapped.emit(get_canvas_transform().affine_inverse() * event.position)
				_pressing = false
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				secondary_tapped.emit(get_canvas_transform().affine_inverse() * event.position)
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_at(event.position, wheel_zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_at(event.position, 1.0 / wheel_zoom_step)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _pressing or _touches.size() >= 2:
		return
	if not _dragging and event.position.distance_to(_press_position) > drag_threshold:
		_dragging = true
	if _dragging:
		_move_to(position - event.relative / zoom)


## Zooms by `factor` while keeping the world point under `screen_position` fixed.
func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var new_zoom := clampf(zoom.x * factor, min_zoom, max_zoom)
	var from_center := screen_position - get_viewport_rect().size / 2.0
	var world_under_pointer := position + from_center / zoom.x
	zoom = Vector2(new_zoom, new_zoom)
	_move_to(world_under_pointer - from_center / new_zoom)


func _move_to(target: Vector2) -> void:
	position = target.limit_length(pan_limit)
