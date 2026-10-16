class_name SteamParts
extends RefCounted
## Steampunk pieces drawn in code onto any CanvasItem: copper pipes and elbows, bolted
## flanges and rivets. Shared by the main menu frame
## and the in-game console.

const BRASS := MenuTheme.BRASS
const BRASS_LIGHT := MenuTheme.BRASS_LIGHT
const BRASS_DARK := MenuTheme.BRASS_DARK
const COPPER := MenuTheme.COPPER
const IRON := MenuTheme.IRON


## Straight pipe from `a` to `b` with a dark outline, highlight and shadow side.
static func pipe(ci: CanvasItem, a: Vector2, b: Vector2, width: float, color := COPPER) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	if n.x + n.y < 0.0:
		n = -n   # shading side: right / bottom
	ci.draw_line(a, b, color.darkened(0.55), width + 3.0)
	ci.draw_line(a, b, color, width)
	ci.draw_line(a + n * width * 0.28, b + n * width * 0.28, color.darkened(0.3), width * 0.35)
	ci.draw_line(a - n * width * 0.22, b - n * width * 0.22, color.lightened(0.45), maxf(1.5, width * 0.18))


## Bend around `center` from angle `from` to `to`.
static func elbow(ci: CanvasItem, center: Vector2, radius: float, from: float, to: float, width: float, color := COPPER) -> void:
	ci.draw_arc(center, radius, from, to, 12, color.darkened(0.55), width + 3.0, true)
	ci.draw_arc(center, radius, from, to, 12, color, width, true)
	ci.draw_arc(center, radius - width * 0.22, from, to, 12, color.lightened(0.45), maxf(1.5, width * 0.18), true)


## Bolted ring around a pipe.
static func flange(ci: CanvasItem, at: Vector2, width: float, vertical_pipe: bool) -> void:
	var size_v := Vector2(width + 10.0, 7.0) if vertical_pipe else Vector2(7.0, width + 10.0)
	var r := Rect2(at - size_v / 2.0, size_v)
	ci.draw_rect(r.grow(1.0), BRASS_DARK)
	ci.draw_rect(r, BRASS)
	ci.draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), BRASS_LIGHT, 1.0)
	for b in [r.position + Vector2(2.5, 2.5), r.end - Vector2(2.5, 2.5)]:
		ci.draw_circle(b, 1.4, IRON)


static func rivet(ci: CanvasItem, at: Vector2, radius := 3.6) -> void:
	ci.draw_circle(at + Vector2(0.6, 0.9), radius, Color(0, 0, 0, 0.35))
	ci.draw_circle(at, radius, BRASS_DARK)
	ci.draw_circle(at + Vector2(-0.22, -0.22) * radius, radius * 0.66, BRASS_LIGHT)
