class_name GateScreen
extends RefCounted
## TR5, TR6: the gate's destination list. Docking (L at a gate) opens it; each
## linked gate shows its days and this gate's fee, and is unavailable while
## closed or unaffordable. Built on Dialog with the shared theme (H5).


## `on_travel(system_id, days)` runs when a destination is picked.
static func open(parent: Node, gate: SystemObjectDef, system_id: String, on_travel: Callable) -> Dialog:
	var dialog := Dialog.open(parent, gate.name, "")
	dialog.use_shared_theme()
	var gov: GovernmentDef = DataRegistry.get_government(gate.government) if gate.government != "" else null
	var lines: Array[String] = [gate.description]
	if gov != null:
		lines.append("Operated by %s." % gov.name)
	lines.append("Fee %d cr   Credits %d   %s" % [gate.fee, GameState.credits, GameState.date_text()])
	var destinations: Array[Dictionary] = DataRegistry.galaxy().gate_destinations(system_id)
	if destinations.is_empty():
		lines.append("\nThis gate has no open links.")
	dialog.set_body("\n".join(lines))
	for link: Dictionary in destinations:
		var system: SystemDef = DataRegistry.get_system(link["system"])
		var target: SystemObjectDef = system.gate() if system != null else null
		if target == null:
			continue
		var problem: String = GateRules.travel_problem(GateRules.is_open(target.open_condition, GameState.flags), GameState.credits, gate.fee)
		var days: int = link["days"]
		var text: String = "%s  ·  %d day%s  ·  %d cr" % [system.name, days, "" if days == 1 else "s", gate.fee]
		match problem:
			GateRules.CLOSED:
				text += "  (closed)"
			GateRules.CREDITS:
				text += "  (can't afford)"
		dialog.add_choice(link["system"], text, func() -> void: on_travel.call(link["system"], days), problem == "")
	dialog.add_choice("leave", "Leave", func() -> void: dialog.close())
	return dialog
