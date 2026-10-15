extends Node2D
## Placeholder tower with a distinct silhouette per base tower type (GDD §6.4).
## Pops in when spawned and again whenever its type changes.

@export var tower_type: StringName = &"attack":
	set(value):
		tower_type = value
		if is_inside_tree():
			_pop()
			queue_redraw()

@export var radius := 18.0

const BASE := Color("4a4f5c")
const DARK := Color("2b2e36")
const ACCENTS := {
	&"attack": Color("d9d9d9"),
	&"wall": Color("a0a4ad"),
	&"energy": Color("ffd23f"),
	&"repair": Color("5fd068"),
	&"aura": Color("7fe0c2"),
	&"scout": Color("6fb7ff"),
	&"warehouse": Color("b48a5a"),
}


func _ready() -> void:
	_pop()


func _pop() -> void:
	scale = Vector2(0.3, 0.3)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var accent: Color = ACCENTS.get(tower_type, Color.WHITE)
	match tower_type:
		&"wall":
			draw_rect(Rect2(-radius * 1.4, -radius * 0.45 + 3, radius * 2.8, radius * 0.9), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(-radius * 1.4, -radius * 0.45, radius * 2.8, radius * 0.9), BASE)
			for i in 4:
				draw_rect(Rect2(-radius * 1.4 + i * radius * 0.8, -radius * 0.45 - 6, radius * 0.4, 6), accent)
		&"energy":
			_draw_base()
			draw_colored_polygon(PackedVector2Array([
				Vector2(3, -14), Vector2(-7, 2), Vector2(-1, 2), Vector2(-4, 14), Vector2(7, -3), Vector2(1, -3),
			]), accent)
		&"repair":
			_draw_base()
			draw_rect(Rect2(-3.5, -11, 7, 22), accent)
			draw_rect(Rect2(-11, -3.5, 22, 7), accent)
		&"aura":
			draw_arc(Vector2.ZERO, radius * 1.6, 0, TAU, 48, Color(accent, 0.5), 3.0, true)
			_draw_base()
			draw_circle(Vector2.ZERO, radius * 0.5, accent)
		&"scout":
			_draw_base()
			draw_circle(Vector2.ZERO, radius * 0.7, Color.WHITE)
			draw_circle(Vector2.ZERO, radius * 0.4, accent)
			draw_circle(Vector2.ZERO, radius * 0.18, DARK)
		&"warehouse":
			var box := Rect2(-radius, -radius * 0.8, radius * 2, radius * 1.6)
			draw_rect(Rect2(box.position + Vector2(0, 3), box.size), Color(0, 0, 0, 0.25))
			draw_rect(box, accent)
			draw_rect(box, accent.darkened(0.45), false, 2.0)
			draw_line(box.position, box.end, accent.darkened(0.45), 2.0)
			draw_line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), accent.darkened(0.45), 2.0)
		_:  # attack
			_draw_base()
			draw_rect(Rect2(-4, -radius - 10, 8, radius + 4), DARK)
			draw_circle(Vector2.ZERO, radius * 0.45, DARK)
			draw_circle(Vector2.ZERO, radius * 0.2, accent)


func _draw_base() -> void:
	draw_circle(Vector2(0, 3), radius, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, radius, BASE)
