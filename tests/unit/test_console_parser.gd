extends TvTest
## D10: console parsing.


func test_tokenize() -> void:
	assert_true(ConsoleParser.tokenize("  SPAWN pirate_raider   3 ") == ["spawn", "pirate_raider", "3"], "split, trim, lower-case the command")
	assert_true(ConsoleParser.tokenize("") == [], "empty line")
	assert_true(ConsoleParser.tokenize("record Pirates 50")[1] == "Pirates", "arguments keep their case")


func test_switches() -> void:
	assert_true(ConsoleParser.parse_switch("on") == 1 and ConsoleParser.parse_switch("TRUE") == 1, "on")
	assert_true(ConsoleParser.parse_switch("off") == 0 and ConsoleParser.parse_switch("0") == 0, "off")
	assert_true(ConsoleParser.parse_switch("maybe") == -1, "invalid")


func test_numbers() -> void:
	assert_true(ConsoleParser.is_int("3") and not ConsoleParser.is_int("3.5"), "ints")
	assert_true(ConsoleParser.is_number("0.25") and ConsoleParser.is_number("-50"), "numbers")
	var words: Array[String] = ["spawn", "x", "4"]
	assert_true(ConsoleParser.int_arg(words, 2, 1) == 4, "given")
	assert_true(ConsoleParser.int_arg(words, 3, 1) == 1, "default when absent")
	var bad: Array[String] = ["spawn", "x", "lots"]
	assert_true(ConsoleParser.int_arg(bad, 2, 1) == null, "malformed")
