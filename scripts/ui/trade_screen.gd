class_name TradeScreen
extends RefCounted
## EC3: the trade screen, opened from the landed screen. One row per commodity
## the port trades: price (tier), held, buy 1 / 10 / max, sell 1 / 10 / all,
## with live credits and hold space. Illegal goods (EC4) and active price
## events (EC2) are marked.


static func open(parent: Node, system_id: String, port: SystemObjectDef, player: Ship) -> Dialog:
	var dialog := Dialog.open(parent, "%s — Trade" % port.name, "")
	dialog.use_shared_theme(false)
	refresh(dialog, system_id, port, player)
	dialog.add_choice("done", "Done", func() -> void: dialog.close())
	return dialog


static func refresh(dialog: Dialog, system_id: String, port: SystemObjectDef, player: Ship) -> void:
	var body: String = "Credits %d     Hold %.0f / %.0f tons" % [GameState.credits, Trading.used_tons(player), player.def.cargo]
	for event: PriceEventDef in GameState.events.at_port(DataRegistry.price_events(), system_id, port.id, port.government):
		if port.market.has(event.commodity):
			body += "\n%s: %s %+d%%" % [event.name, DataRegistry.get_commodity(event.commodity).name, roundi((event.factor - 1.0) * 100.0)]
	dialog.set_body(body)
	dialog.clear_extras()
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 10)
	for title: String in ["Commodity", "Buy", "Sell", "Held", "", "", "", "", ""]:
		var label := Label.new()
		label.text = title
		grid.add_child(label)
	var ids: Array = port.market.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return DataRegistry.get_commodity(a).base_price < DataRegistry.get_commodity(b).base_price)
	for id: String in ids:
		var q: Dictionary = Trading.quote(system_id, port, id)
		if q.is_empty():
			continue
		var name: String = DataRegistry.get_commodity(id).name
		if q["illegal"]:
			name += "  (illegal)"
		if not is_equal_approx(float(q["event"]), 1.0):
			name += "  (%s)" % ("shortage" if float(q["event"]) > 1.0 else "glut")
		var held: int = Market.held(player.cargo, id)
		for text: String in [name, "%d (%s)" % [q["buy"], q["tier"]], str(q["sell"]), str(held)]:
			var cell := Label.new()
			cell.text = text
			grid.add_child(cell)
		for spec: Array in [["Buy 1", 1, true], ["Buy 10", 10, true], ["Buy max", 1000000, true],
				["Sell 1", 1, false], ["Sell all", 1000000, false]]:
			var button := Button.new()
			button.text = spec[0]
			button.focus_mode = Control.FOCUS_NONE
			var units: int = spec[1]
			var buying: bool = spec[2]
			button.disabled = (held <= 0) if not buying else (Market.max_buy(GameState.credits, q["buy"], Trading.free_tons(player), DataRegistry.get_commodity(id).mass) <= 0)
			button.pressed.connect(func() -> void:
				if buying:
					Trading.buy(system_id, port, player, id, units)
				else:
					Trading.sell(system_id, port, player, id, units)
				refresh(dialog, system_id, port, player))
			grid.add_child(button)
	dialog.add_control(grid)
