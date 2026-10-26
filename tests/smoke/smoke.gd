extends Node
## Smoke test: boots the main system scene, spawns one of every ship ID
## through DebugCommands and lets the game run. A healthy build prints
## nothing containing ERROR or WARNING. tools/check.py runs it with
## --quit-after 600 and fails on any such line.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().root.add_child(load("res://scenes/system.tscn").instantiate())
	await get_tree().physics_frame
	var count: int = 0
	for ship_id: String in DataRegistry.ids("ships"):
		count += DebugCommands.spawn_ships(ship_id, 1).size()
	print("smoke: spawned %d ships, running" % count)
