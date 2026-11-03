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


## Jump straight to the target, no smoothing: after the player is placed and
## the game pauses at once (loading a save, landing, rescue), the camera would
## otherwise stay where it was (SV1: it sat on the star, glare and all).
func snap() -> void:
	if target == null:
		return
	global_position = target.global_position
	reset_smoothing()
	reset_physics_interpolation()  # don't blend from the old spot
	force_update_scroll()

