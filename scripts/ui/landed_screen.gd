class_name LandedScreen
extends RefCounted
## S3: the landed screen — planet name and description, Repair (cost from
## game.json landing.repair_cost_per_point, free by default) and Take off.
## Built on Dialog, so the world stays paused while landed.


static func open(parent: Node, port: SystemObjectDef, player: Ship, on_take_off: Callable, intro: String = "") -> Dialog:
	var dialog := Dialog.open(parent, port.name, "")
	_refresh(dialog, port, player, on_take_off, intro)
	return dialog


static func _refresh(dialog: Dialog, port: SystemObjectDef, player: Ship, on_take_off: Callable, intro: String) -> void:
	var per_point: float = float(DataRegistry.settings["landing"]["repair_cost_per_point"])
	var cost: int = PortRules.repair_cost(player.health.missing_points(), per_point)
	var gov: GovernmentDef = DataRegistry.get_government(port.government) if port.government != "" else null
	var text: String = (intro + "\n\n" if intro != "" else "") + port.description
	if gov != null:
		text += "\n\nGovernment: %s" % gov.name
	text += "\n\nShield %.0f / %.0f   Armour %.0f / %.0f   Credits %d" % [
		player.health.shield, player.health.max_shield, player.health.armor, player.health.max_armor, GameState.credits]
	dialog.set_body(text)
	dialog.clear_choices()
	var needs_repair: bool = player.health.missing_points() > 0.0
	var label: String = "Repair" if cost == 0 else "Repair (%d cr)" % cost
	dialog.add_choice("repair", label, func() -> void:
		GameState.add_credits(-cost)
		player.health.repair_full()
		player.visual.modulate = Color.WHITE
		_refresh(dialog, port, player, on_take_off, "Repaired."), needs_repair and GameState.credits >= cost)
	dialog.add_choice("take_off", "Take off", func() -> void:
		dialog.close()
		on_take_off.call())
