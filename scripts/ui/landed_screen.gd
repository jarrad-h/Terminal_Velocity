class_name LandedScreen
extends RefCounted
## S3: the landed screen — planet name and description, Repair (cost from
## game.json landing.repair_cost_per_point, free by default), Refuel where the
## port sells fuel (TR8) and Take off.
## Built on Dialog, so the world stays paused while landed.


static func open(parent: Node, port: SystemObjectDef, player: Ship, on_take_off: Callable, intro: String = "") -> Dialog:
	var dialog := Dialog.open(parent, port.name, "")
	_refresh(dialog, port, player, on_take_off, intro)
	return dialog


## PS7: recent off-screen events and announced movements, newest first.
static func news_text() -> String:
	var cfg: Dictionary = DataRegistry.settings["entities"]["news"]
	var start: String = DataRegistry.settings["calendar"]["start_date"]
	var lines: Array[String] = []
	for item: Dictionary in GameState.news.recent(GameState.clock.day, int(cfg["days"]), int(cfg["max_items"])):
		lines.append("%s  %s" % [Calendar.date_text(start, int(item["day"])), item["text"]])
	return "\n\nNews:\n" + ("\n".join(lines) if not lines.is_empty() else "Nothing of note.")


static func _refresh(dialog: Dialog, port: SystemObjectDef, player: Ship, on_take_off: Callable, intro: String) -> void:
	var per_point: float = float(DataRegistry.settings["landing"]["repair_cost_per_point"])
	var cost: int = PortRules.repair_cost(player.health.missing_points(), per_point)
	var gov: GovernmentDef = DataRegistry.get_government(port.government) if port.government != "" else null
	var text: String = (intro + "\n\n" if intro != "" else "") + port.description
	if gov != null:
		text += "\n\nGovernment: %s" % gov.name
	text += "\n\nShield %.0f / %.0f   Armour %.0f / %.0f   Credits %d" % [
		player.health.shield, player.health.max_shield, player.health.armor, player.health.max_armor, GameState.credits]
	text += "\n%s   Fuel %.0f / %.0f" % [GameState.date_text(), GameState.travel.fuel, player.def.fuel]
	text += news_text()
	dialog.set_body(text)
	dialog.clear_choices()
	var needs_repair: bool = player.health.missing_points() > 0.0
	var label: String = "Repair" if cost == 0 else "Repair (%d cr)" % cost
	dialog.add_choice("repair", label, func() -> void:
		GameState.add_credits(-cost)
		player.health.repair_full()
		player.set_tint(Color.WHITE)
		_refresh(dialog, port, player, on_take_off, "Repaired."), needs_repair and GameState.credits >= cost)
	if port.sells_fuel:
		var fill: Dictionary = PortRules.refuel(GameState.travel.fuel, player.def.fuel, port.refuel_price, GameState.credits)
		var fuel_label: String = "Refuel" if fill["cost"] == 0 else "Refuel (%d cr)" % fill["cost"]
		dialog.add_choice("refuel", fuel_label, func() -> void:
			GameState.add_credits(-fill["cost"])
			GameState.set_fuel(GameState.travel.fuel + fill["units"], player.def.fuel)
			_refresh(dialog, port, player, on_take_off, "Refuelled."), fill["units"] > 0.0)
	dialog.add_choice("take_off", "Take off", func() -> void:
		dialog.close()
		on_take_off.call())
