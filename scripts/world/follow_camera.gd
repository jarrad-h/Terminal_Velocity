class_name FollowCamera
extends Camera2D
## Follows a target node each physics frame (F4). Values from game.json "camera".

var target: Node2D = null


func configure(settings: Dictionary) -> void:
	zoom = Vector2.ONE * float(settings["zoom"])
	var smoothing: float = float(settings["smoothing_speed"])
	position_smoothing_enabled = smoothing > 0.0
	position_smoothing_speed = smoothing


func _physics_process(_delta: float) -> void:
	if target != null:
		global_position = target.global_position
