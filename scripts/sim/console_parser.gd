class_name ConsoleParser
extends RefCounted
## D10: pure parsing for the debug console. Words are split on whitespace;
## the command word is lower-cased.


static func tokenize(line: String) -> Array[String]:
	var words: Array[String] = []
	for word: String in line.strip_edges().split(" ", false):
		if word.strip_edges() != "":
			words.append(word.strip_edges())
	if not words.is_empty():
		words[0] = words[0].to_lower()
	return words


## 1 for on/true/yes/1, 0 for off/false/no/0, -1 for anything else.
static func parse_switch(word: String) -> int:
	match word.to_lower():
		"on", "true", "yes", "1":
			return 1
		"off", "false", "no", "0":
			return 0
	return -1


static func is_int(word: String) -> bool:
	return word.is_valid_int()


static func is_number(word: String) -> bool:
	return word.is_valid_float() or word.is_valid_int()


## Optional argument `index` as an int, or `default` when absent; null if malformed.
static func int_arg(words: Array[String], index: int, default: int) -> Variant:
	if words.size() <= index:
		return default
	return words[index].to_int() if is_int(words[index]) else null
