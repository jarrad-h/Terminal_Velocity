class_name DataErrorScreen
extends CanvasLayer
## Shown instead of the game when data files fail validation: lists every
## error with its file and field so it can be fixed before restarting.


func show_errors(errors: Array[String]) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "The game cannot start: %d data error(s). Fix these files and run again.\n\n%s" % [errors.size(), "\n".join(errors)]
	scroll.add_child(label)
