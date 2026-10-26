class_name Def
extends Resource
## Base for every data definition. `id` matches the file name; `file` is the
## path the definition was loaded from (data/ or mods/).

var id: String = ""
var file: String = ""


## Checks that need other definitions (beyond plain reference resolution).
## `defs` is type folder -> {id -> Def}.
func validate(_defs: Dictionary, _errors: Array[String]) -> void:
	pass
