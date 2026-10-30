class_name EscapePod
extends Node2D
## C10: the player's escape pod — flies straight at high speed for a few
## seconds (game.json player.pod_speed / pod_time), then reports `finished`.

signal finished(pod: EscapePod)

var velocity: Vector2 = Vector2.ZERO
var _life: float = 0.0


static func launch(parent: Node, at: Vector2, direction: Vector2, base_velocity: Vector2) -> EscapePod:
	var settings: Dictionary = DataRegistry.settings["player"]
	var pod := EscapePod.new()
	pod.position = at
	pod.rotation = Aim.rotation_of(direction)
	pod.velocity = base_velocity + direction * float(settings["pod_speed"])
	pod._life = float(settings["pod_time"])
	pod.add_to_group(&"escape_pod")
	parent.add_child(pod)
	pod.reset_physics_interpolation()
	return pod


func _init() -> void:
	material = LitSprite.unshaded_material()  # V6: full brightness, not lit or darkened


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		set_physics_process(false)
		finished.emit(self)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.5))
	draw_line(Vector2(0.0, 5.0), Vector2(0.0, 14.0), Color(1.0, 0.6, 0.2, 0.7), 3.0)
