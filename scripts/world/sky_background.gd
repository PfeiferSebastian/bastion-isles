extends Node2D
## Endless auto-scrolling cloud layers that sell the island's flight (GDD §8.1).
## Builds its Parallax2D layers from generated noise, so no art assets are needed yet.

## Direction and speed the island flies, in pixels per second. Clouds move the opposite way.
@export var flight_velocity := Vector2(0, -40)

## [texture size, scroll_scale, speed multiplier, opacity] per layer, back to front.
const LAYERS := [
	[1024, 0.3, 0.5, 0.35],
	[1024, 0.6, 1.0, 0.55],
]


func _ready() -> void:
	for i in LAYERS.size():
		var spec: Array = LAYERS[i]
		add_child(_make_layer(spec[0], spec[1], spec[2], spec[3], i))


func _make_layer(size: int, scroll: float, speed: float, opacity: float, seed_offset: int) -> Parallax2D:
	var parallax := Parallax2D.new()
	parallax.scroll_scale = Vector2(scroll, scroll)
	parallax.repeat_size = Vector2(size, size)
	parallax.repeat_times = 3
	parallax.autoscroll = -flight_velocity * speed

	var noise := FastNoiseLite.new()
	noise.seed = 1337 + seed_offset
	noise.frequency = 0.004
	noise.fractal_octaves = 4

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, opacity))
	ramp.set_offset(0, 0.5)

	var texture := NoiseTexture2D.new()
	texture.width = size
	texture.height = size
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	parallax.add_child(sprite)
	return parallax
