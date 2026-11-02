extends GutTest
## SV1–SV4: ship records, the pilot file, migrations and slot rules.


func test_ship_record_shape() -> void:
	var r: Dictionary = ShipRecord.make("freighter", 0.5, 0.25)
	assert_eq(ShipRecord.design_of(r), "freighter")
	for key: String in ["design", "name", "hull", "shield", "fitted", "cargo"]:
		assert_true(r.has(key), "SV1: a ship record has %s" % key)
	var old: Dictionary = ShipRecord.normalised({"ship": "brig", "hull": 0.3, "shield": 1.0})
	assert_true(old["design"] == "brig" and not old.has("ship") and old["cargo"] == [], "SV4: a milestone 3 record becomes a ship record")
	var wreck: Dictionary = ShipRecord.normalised({"ship": "brig", "armor_pct": 0.2, "days_left": 3})
	assert_true(is_equal_approx(wreck["hull"], 0.2) and wreck["days_left"] == 3, "wreck extras ride along; armor_pct becomes hull")


func test_v0_migrates_to_v1() -> void:
	var v0: Dictionary = {"credits": 50, "day": 12,
		"entities": {"states": {"mara": {"id": "mara", "ships": [{"ship": "freighter", "hull": 0.9, "shield": 1.0}]}}},
		"memory": {"values": {}, "wrecks": {"aster": [{"ship": "brig", "armor_pct": 0.1, "days_left": 2}]}}}
	var result: Dictionary = SaveMigrations.upgrade(v0)
	assert_true(result["ok"], "SV4: a version 0 state upgrades")
	var data: Dictionary = result["data"]
	assert_eq(int(data["version"]), SaveMigrations.VERSION, "to the current version")
	assert_eq(int(data["game"]["credits"]), 50, "the game state is kept")
	assert_eq(ShipRecord.design_of(data["game"]["entities"]["states"]["mara"]["ships"][0]), "freighter", "entity ships become ship records")
	assert_eq(ShipRecord.design_of(data["game"]["memory"]["wrecks"]["aster"][0]), "brig", "so do wrecks")
	assert_true(data.has("stats") and data.has("missions") and data.has("ratings"), "reserved blocks exist")


func test_newer_and_too_old_saves_are_refused() -> void:
	var newer: Dictionary = SaveMigrations.upgrade({"version": SaveMigrations.VERSION + 1})
	assert_false(newer["ok"], "SV4: a newer save is refused")
	assert_string_contains(newer["error"], "newer version")
	var older: Dictionary = SaveMigrations.upgrade({"version": SaveMigrations.OLDEST - 1})
	assert_false(older["ok"], "SV4: a save older than the oldest supported is refused")
	assert_string_contains(older["error"], "too old")


func test_build_has_everything() -> void:
	var pilot: Dictionary = PilotSave.new_pilot("Ada", false, {"escape_pod": true, "insured": false}, 3)
	var where: Dictionary = PilotSave.location("aster", "aster_prime", Vector2(1, 2), Vector2.ZERO, 0.5)
	var save: Dictionary = PilotSave.build("autosave", "2026-11-02 10:00", pilot, {"credits": 99, "day": 7}, ShipRecord.make("shuttle"), where)
	assert_eq(int(save["version"]), SaveMigrations.VERSION)
	assert_true(save["pilot"]["insured"] == false and save["pilot"]["escape_pod"] == true, "SV1: pod and insurance are pilot properties")
	assert_true(save["meta"]["system"] == "aster" and int(save["meta"]["day"]) == 7 and int(save["meta"]["credits"]) == 99, "menu summary")
	assert_eq(save["player"]["location"]["landed"], "aster_prime")


func test_check_against_loaded_data() -> void:
	var save: Dictionary = PilotSave.build("autosave", "", PilotSave.new_pilot("A", false, {}),
		{"entities": {"states": {"e": {"ships": [ShipRecord.make("gone_ship")]}}},
			"memory": {"wrecks": {"aster": [ShipRecord.make("gone_ship"), ShipRecord.make("brig")]}}},
		ShipRecord.make("gone_ship"), PilotSave.location("aster", "", Vector2.ZERO, Vector2.ZERO, 0.0))
	var ships: Dictionary = {"brig": true, "shuttle": true}
	var ok: Dictionary = PilotSave.check(save, ships, {"aster": true}, "shuttle")
	assert_true(ok["ok"], "missing designs don't stop the load")
	assert_eq(ShipRecord.design_of(ok["data"]["player"]["ship"]), "shuttle", "SV1: a missing player design becomes the uninsured hull")
	assert_eq(ShipRecord.design_of(ok["data"]["game"]["entities"]["states"]["e"]["ships"][0]), "shuttle", "...and an entity's")
	assert_eq(ok["data"]["game"]["memory"]["wrecks"]["aster"].size(), 1, "a wreck of a missing design is dropped")
	assert_eq(ok["warnings"].size(), 3, "each with a warning")
	var lost: Dictionary = PilotSave.check(save, ships, {"brink": true}, "shuttle")
	assert_false(lost["ok"], "SV1: a missing current system refuses the load")


func test_slot_rules() -> void:
	var normal: Dictionary = PilotSave.new_pilot("N", false, {})
	var iron: Dictionary = PilotSave.new_pilot("I", true, {})
	assert_true(PilotSave.can_create_pilot(4, 5) and not PilotSave.can_create_pilot(5, 5), "SV2: up to 5 pilots")
	var nine: Array = range(9).map(func(i: int) -> String: return "s%d" % i)
	assert_true(PilotSave.can_save_manual(normal, "new", nine, 10), "SV2: a tenth slot is fine")
	nine.append("s9")
	assert_false(PilotSave.can_save_manual(normal, "new", nine, 10), "...an eleventh isn't")
	assert_true(PilotSave.can_save_manual(normal, "s3", nine, 10), "...but a full set can be overwritten")
	assert_false(PilotSave.can_save_manual(normal, PilotSave.AUTOSAVE, [], 10), "the autosave isn't a manual slot")
	assert_false(PilotSave.can_save_manual(iron, "mine", [], 10), "SV3: ironman has no manual saves")
	assert_eq(PilotSave.autosave_slot(iron), PilotSave.IRONMAN, "SV3: ironman autosaves to its one slot")
	assert_eq(PilotSave.autosave_slot(normal), PilotSave.AUTOSAVE)
	assert_true(PilotSave.can_load(iron, PilotSave.IRONMAN) and not PilotSave.can_load(iron, "old"), "SV3: ironman loads only its slot")
	var dead: Dictionary = iron.duplicate()
	dead["dead"] = true
	assert_false(PilotSave.can_load(dead, PilotSave.IRONMAN), "SV3: a dead pilot is a memorial")


func test_slugs() -> void:
	assert_eq(PilotSave.slug("Captain Ada  Vell!"), "captain_ada_vell")
	assert_eq(PilotSave.slug("Ada", ["ada"]), "ada_2", "unique against existing ids")
	assert_eq(PilotSave.slug("!!!"), "pilot", "never empty")
