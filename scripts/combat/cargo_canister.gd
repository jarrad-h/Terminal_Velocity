class_name CargoCanister
extends Node2D
## EC8, EC6: jettisoned or spilled cargo. Drifts, and expires after
## game.json cargo.canister_life seconds. Any ship that can act, flying over
## it (within scoop_radius) slower than scoop_speed relative to it, takes what
## fits its hold; the rest stays. Pirates go after valuable ones (OF6 decoy).

const GROUP: StringName = &"canisters"

var velocity: Vector2 = Vector2.ZERO
## [{"commodity", "units"}]
var cargo: Array = []
var _life: float = 0.0
## The ship that dropped it can't scoop it straight back.
var _dropper: Ship = null
var _dropper_grace: float = 0.0


static func spawn(parent: Node, at: Vector2, base_velocity: Vector2, p_cargo: Array, dropper: Ship = null) -> CargoCanister:
	if p_cargo.is_empty():
		return null
	var cfg: Dictionary = DataRegistry.settings["cargo"]
	var can := CargoCanister.new()
	can.position = at
	can.velocity = base_velocity + Vector2.from_angle(randf() * TAU) * float(cfg["drift_speed"])
	can.cargo = p_cargo.duplicate(true)
	can._dropper = dropper
	can._life = float(cfg["canister_life"])
	can.add_to_group(GROUP)
	can._dropper_grace = float(cfg["dropper_grace"])
	parent.add_child(can)
	can.reset_physics_interpolation()
	return can


## Credits it would fetch at base prices (pirates weigh it up by this).
func value() -> float:
	var total: float = 0.0
	for item: Dictionary in cargo:
		var def: CommodityDef = DataRegistry.get_commodity(item["commodity"])
		total += float(item["units"]) * (def.base_price if def != null else 0.0)
	return total


func _init() -> void:
	material = LitSprite.unshaded_material()


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	_dropper_grace -= delta
	if _life <= 0.0:
		queue_free()
		return
	var cfg: Dictionary = DataRegistry.settings["cargo"]
	var radius: float = float(cfg["scoop_radius"])
	var max_speed: float = float(cfg["scoop_speed"])
	for node: Node in get_tree().get_nodes_in_group(&"ships"):
		var ship: Ship = node as Ship
		if ship == null or not ship.can_act() or ship.docked or ship.def.cargo <= 0.0:
			continue
		if ship == _dropper and _dropper_grace > 0.0:
			continue
		if ship.global_position.distance_to(global_position) > radius + ship.hit_radius:
			continue
		if (ship.get_velocity() - velocity).length() > max_speed:
			continue
		_scoop(ship)
		if cargo.is_empty():
			queue_free()
			return


func _scoop(ship: Ship) -> void:
	var result: Dictionary = Market.take_what_fits(cargo, Trading.free_tons(ship), Trading.masses())
	if (result["taken"] as Array).is_empty():
		return
	for item: Dictionary in result["taken"]:
		ship.cargo = Market.with_units(ship.cargo, item["commodity"], int(item["units"]))
	cargo = result["left"]
	if ship.is_player():
		var parts: Array[String] = []
		for item: Dictionary in result["taken"]:
			parts.append("%d %s" % [item["units"], DataRegistry.get_commodity(item["commodity"]).name])
		GameState.post_message("Scooped %s" % ", ".join(parts) + ("" if cargo.is_empty() else " (hold full)"))


func _draw() -> void:
	draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), Color(0.85, 0.7, 0.35))
	draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), Color(0.3, 0.22, 0.1), false, 2.0)
