class_name Starfield
extends Node2D
## Parallax starfield (F4): one repeating Parallax2D layer per entry in
## game.json "starfield.layers"; slower layers read as further away.


func configure(settings: Dictionary) -> void:
	for child: Node in get_children():
		child.queue_free()
	var tile: float = float(settings["tile_size"])
	var layers: Array = settings["layers"]
	for i: int in layers.size():
		var layer: Dictionary = layers[i]
		var parallax := Parallax2D.new()
		parallax.scroll_scale = Vector2.ONE * float(layer["scroll_scale"])
		parallax.repeat_size = Vector2(tile, tile)
		parallax.repeat_times = 3
		var stars := StarLayer.new()
		stars.tile_size = tile
		stars.count = int(layer["count"])
		stars.star_size = float(layer["size"])
		stars.brightness = float(layer["brightness"])
		stars.seed_value = int(settings["seed"]) + i
		parallax.add_child(stars)
		add_child(parallax)


class StarLayer:
	extends Node2D

	var tile_size: float = 0.0
	var count: int = 0
	var star_size: float = 0.0
	var brightness: float = 0.0
	var seed_value: int = 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var colour := Color(brightness, brightness, brightness)
		for i: int in count:
			var pos := Vector2(rng.randf() * tile_size, rng.randf() * tile_size)
			draw_rect(Rect2(pos, Vector2(star_size, star_size)), colour)
