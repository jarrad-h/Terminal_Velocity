extends Node
## SV2, SV3: the menus end to end, headless. New pilot → land (autosave) →
## save by hand → main menu → Continue lands you back where you saved; an
## ironman pilot gets no Save or Load. Uses its own pilots folder.
## Run: "$GODOT_PATH" --headless --path . res://tests/smoke/menu_flow.tscn
## The driver steps out of the current scene so scene changes don't free it.

var _errors: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _menu_dialog() -> Dialog:
	return get_tree().current_scene.get("_dialog") if get_tree().current_scene != null else null


func _actions() -> PlayerActions:
	return get_tree().current_scene.get("actions") if get_tree().current_scene != null else null


func _run() -> void:
	get_tree().current_scene = null  # keep this driver through scene changes
	var pilots: Node = Pilots
	var game: Node = GameState
	pilots.root = "user://test_menu_flow"
	for entry: Dictionary in pilots.list_pilots():
		pilots.delete_pilot(entry["id"])
	var first: Node = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(first)
	get_tree().current_scene = first  # from here the game changes scenes itself
	await _frames(5)
	var menu: Dialog = _menu_dialog()
	_check(menu != null and menu.has_choice("new") and not menu.has_choice("continue"), "SV2: a fresh menu offers New pilot, no Continue")
	menu.choose("new")
	await _frames(2)
	menu = _menu_dialog()
	(menu._extras.get_child(0) as LineEdit).text = "Flow Tester"
	menu.choose("create")
	await _frames(10)
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "SystemScene", "SV2: creating a pilot starts the game (%s)" % (get_tree().current_scene.name if get_tree().current_scene else "none"))
	_check(pilots.list_slots("flow_tester").size() == 1, "SV2: a new pilot is on disk from the start")
	# Land, save by hand, then wander off.
	var port: SystemObjectDef = null
	for obj: SystemObjectDef in get_tree().current_scene.system.objects:
		if obj.landable and obj.type != "gate":
			port = obj
			break
	_actions().land_at(port)
	await _frames(2)
	var landed: Dialog = _actions().dialog
	_check(landed != null and landed.has_choice("save") and landed.has_choice("load") and landed.has_choice("menu"), "SV2: Save, Load and Main menu when landed")
	game.credits = 777
	# Mid-route, with an entity in transit (milestone 4's "done" condition).
	var here: String = game.travel.current_system
	var next: String = Hyperlanes.neighbours(DataRegistry.galaxy(), here)[0]
	game.travel.route = [next] as Array[String]
	var mara: EntityState = game.entities.states["mara_vell"]
	mara.location = ""
	mara.transit_from = here
	mara.transit_to = next
	mara.arrive_day = game.clock.day + 2
	landed.choose("save")
	await _frames(2)
	var save_dialog: Dialog = null
	for child: Node in get_tree().current_scene.get_children():
		if child is Dialog and child != landed:
			save_dialog = child
	_check(save_dialog != null and save_dialog.has_choice("new"), "SV2: the save screen opens")
	if save_dialog != null:
		(save_dialog._extras.get_child(0) as LineEdit).text = "At port"
		save_dialog.choose("new")
	await _frames(2)
	_check(pilots.manual_slots("flow_tester") == ["at_port"], "SV2: the named save is written")
	game.credits = 5
	landed.choose("menu")
	await _frames(10)
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu", "SV2: Main menu from the landed screen")
	menu = _menu_dialog()
	_check(menu != null and menu.has_choice("continue"), "SV2: Continue is offered")
	menu.choose("continue")
	await _frames(12)
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "SystemScene", "SV2: Continue loads the game")
	_check(game.credits == 777, "SV1: the saved credits are back (%d)" % game.credits)
	_check(game.travel.route == ([next] as Array[String]), "SV1: the route is back")
	var back: EntityState = game.entities.states["mara_vell"]
	_check(back.in_transit() and back.transit_to == next, "SV1: Mara Vell is still in transit to %s" % next)
	_check(_actions() != null and _actions().dialog != null and pilots.landed_at == port.id, "SV1: back on the landed screen at %s" % port.name)
	# SV3: an ironman pilot.
	pilots.quit_to_menu()
	await _frames(10)
	_menu_dialog().choose("new")
	await _frames(2)
	menu = _menu_dialog()
	(menu._extras.get_child(0) as LineEdit).text = "Iron Tester"
	(menu._extras.get_child(1) as CheckBox).button_pressed = true
	menu.choose("create")
	await _frames(10)
	_actions().land_at(port)
	await _frames(2)
	landed = _actions().dialog
	_check(landed != null and not landed.has_choice("save") and not landed.has_choice("load") and landed.has_choice("menu"), "SV3: ironman has no Save or Load")
	_check(FileAccess.file_exists(pilots.root.path_join("iron_tester/ironman.json")), "SV3: the ironman slot is written on landing")
	pilots.quit_to_menu()
	await _frames(5)
	for entry: Dictionary in pilots.list_pilots():
		pilots.delete_pilot(entry["id"])
	for e: String in _errors:
		print("FAIL ", e)
	print("menu flow: %d failures" % _errors.size())
	get_tree().quit(1 if _errors.size() > 0 else 0)
