extends TvTest
## Data loader: override rule, defaults, reference validation, error messages.

const BASE: String = "res://tests/fixtures/loader/base"
const MOD: String = "res://tests/fixtures/loader/mod"
const BROKEN: String = "res://tests/fixtures/loader/broken"


func _load(roots: Array[String]) -> DataSet:
	return DataLoader.load_roots(roots)


## True if one error mentions every fragment (file name, field, reason).
func _has_error(set: DataSet, fragments: Array[String]) -> bool:
	for e: String in set.errors:
		var all: bool = true
		for f: String in fragments:
			if not e.contains(f):
				all = false
				break
		if all:
			return true
	return false


func _expect_error(set: DataSet, fragments: Array[String]) -> void:
	assert_true(_has_error(set, fragments), "expected an error containing %s; got:\n    %s" % [fragments, "\n    ".join(set.errors)])


func test_valid_data_loads_without_errors() -> void:
	var set: DataSet = _load([BASE, MOD])
	assert_true(set.errors.is_empty(), "errors: %s" % [set.errors])
	assert_true(set.get_def("ships", "alpha") is ShipDef, "ship loads as ShipDef")
	assert_true(set.get_def("systems", "home") is SystemDef, "system loads as SystemDef")
	assert_true(set.get_def("scenery", "boulder") is SceneryDef, "scenery loads as SceneryDef")


func test_id_comes_from_file_name() -> void:
	var ship: ShipDef = _load([BASE]).get_def("ships", "alpha")
	assert_true(ship.id == "alpha", "id is the file name")
	assert_true(ship.file.ends_with("base/ships/alpha.json"), "file recorded")


func test_optional_fields_take_defaults() -> void:
	var set: DataSet = _load([BASE])
	var ship: ShipDef = set.get_def("ships", "alpha")
	assert_near(ship.hit_radius, 16.0, "hit_radius default")
	assert_near(ship.armor, 100.0, "armor default")
	var weapon: WeaponDef = set.get_def("weapons", "zap")
	assert_near(weapon.reload, 0.5, "reload default")
	var speck: SceneryDef = set.get_def("scenery", "speck")
	assert_true(speck.behaviour == "static" and not speck.solid, "scenery defaults")
	var home: SystemDef = set.get_def("systems", "home")
	assert_near(home.backdrop.parallax, 0.02, "backdrop parallax default")
	assert_true(home.local_space[0].region == "whole", "region default is whole system")


func test_typed_nested_values() -> void:
	var set: DataSet = _load([BASE])
	var ship: ShipDef = set.get_def("ships", "alpha")
	assert_true(ship.default_weapons[0]["weapon"] == "zap" and ship.default_weapons[0]["count"] == 2, "loadout parsed")
	var speck: SceneryDef = set.get_def("scenery", "speck")
	assert_vec_near(speck.depth, Vector2(0.9, 1.1), "depth range")
	var ring: LocalSpaceEntry = (set.get_def("systems", "home") as SystemDef).local_space[1]
	assert_true(ring.region == "ring", "ring region")
	assert_near(ring.inner_radius, 100.0, "ring inner radius")


func test_playtest_field_defaults() -> void:
	var data: DataSet = _load([BASE])
	var ship: ShipDef = data.get_def("ships", "alpha")
	assert_near(ship.shield_recharge_delay, 3.0, "C6 recharge delay default")
	var weapon: WeaponDef = data.get_def("weapons", "zap")
	assert_near(weapon.falloff_at(10000.0), 1.0, "C12 no falloff by default")
	var law: GovernmentDef = data.get_def("governments", "law")
	assert_near(law.tolerance_pct, 20.0, "A8 tolerance default")
	assert_near(law.forgiveness_pct_per_s, 4.0, "A8 forgiveness default")


func test_ai_pool_defaults_follow_role() -> void:
	var pool: AiPoolDef = _load([BASE]).get_def("ai_pools", "raiders")
	assert_true(pool.personalities.is_empty(), "no personalities listed -> neutral")
	assert_true(not pool.spawn_from_planets, "pirates arrive at the edge by default")
	assert_near(pool.sensor_range, 1500.0, "sensor_range default")


func test_mod_file_replaces_same_id() -> void:
	var set: DataSet = _load([BASE, MOD])
	var ship: ShipDef = set.get_def("ships", "alpha")
	assert_true(ship.name == "Alpha Mk2", "mod version wins")
	assert_near(ship.top_speed, 400.0, "mod values used")
	assert_true(ship.default_weapons.is_empty(), "replacement is whole-file, not a merge")
	assert_true(set.overrides.size() == 2, "both overrides reported: %s" % [set.overrides])


func test_mod_can_add_new_ids() -> void:
	var set: DataSet = _load([BASE, MOD])
	assert_true(set.get_def("ships", "beta") != null, "new ship from mods")
	assert_true(set.ids("ships") == ["alpha", "beta", "patched"], "ids sorted: %s" % [set.ids("ships")])


func test_replaced_file_references_are_not_checked() -> void:
	# base/ships/patched.json references a weapon that does not exist; the mod
	# replaces that file, so its broken reference no longer matters.
	_expect_error(_load([BASE]), ["patched.json", "weapon_only_in_base"])
	var with_mod: DataSet = _load([BASE, MOD])
	assert_true(with_mod.errors.is_empty(), "no errors after override: %s" % [with_mod.errors])


func test_order_matters_later_root_wins() -> void:
	var set: DataSet = _load([MOD, BASE])
	var ship: ShipDef = set.get_def("ships", "alpha")
	assert_true(ship.name == "Alpha", "base wins when loaded last")


func test_settings_merge_and_refs() -> void:
	var set: DataSet = _load([BASE])
	assert_true(set.settings["player_ship"] == "alpha", "game.json value")
	assert_true(set.settings.has("camera"), "missing settings take defaults")


func test_missing_reference_names_file_and_field() -> void:
	var set: DataSet = _load([BROKEN])
	_expect_error(set, ["bad_ref.json", "default_weapons[0].weapon", "missing_gun"])
	_expect_error(set, ["ghost_fleet.json", "'government'", "nobody"])
	_expect_error(set, ["ghost_fleet.json", "ships[0].ship", "ghost"])
	_expect_error(set, ["bad_fragment.json", "fragments[0].scenery", "nothing"])
	_expect_error(set, ["sys.json", "local_space[0].scenery", "unknown_rock"])
	_expect_error(set, ["game.json", "player_ship", "no_such_ship"])


func test_field_errors_name_file_and_field() -> void:
	var set: DataSet = _load([BROKEN])
	_expect_error(set, ["wrong_id.json", "'id'", "does not match the file name"])
	_expect_error(set, ["typo.json", "top_sped", "unknown field"])
	_expect_error(set, ["typo.json", "top_speed", "is required"])
	_expect_error(set, ["bad_type.json", "accel", "expected a number"])
	_expect_error(set, ["bad_json.json", "line 1", "invalid JSON"])
	_expect_error(set, ["bad_kind.json", "kind", "laser"])
	_expect_error(set, ["confused.json", "also listed in 'enemies'"])
	_expect_error(set, ["solid_dust.json", "depth", "solid"])
	_expect_error(set, ["ghost_fleet.json", "personalities[0].personality", "nobody_home"])
	_expect_error(set, ["bad_temper.json", "odds_factor", "at least 0"])
	_expect_error(set, ["bad_temper.json", "when_attacked", "sulk"])
	_expect_error(set, ["bad_temper.json", "starts_fights", "maybe"])
	_expect_error(set, ["nameless.json", "'name'", "is required"])
	_expect_error(set, ["zero_weight.json", "'ships'", "weights add up to 0"])
	_expect_error(set, ["zero_weight.json", "'stops'", "greater than max"])
	_expect_error(set, ["zero_weight.json", "fire_angle", "expected a number"])
	_expect_error(set, ["tiny.json", "edge_radius", "at least 100"])
	_expect_error(set, ["tiny.json", "respawn_delay", "greater than max"])
	_expect_error(set, ["game.json", "ai.thrust_angle", "expected a number"])
	_expect_error(set, ["game.json", "ai.roam_band", "greater than max"])
	_expect_error(set, ["game.json", "combat.friendly_fire_pct", "at least 0"])
	_expect_error(set, ["game.json", "player.credits", "expected a number"])
	_expect_error(set, ["bad_falloff.json", "falloff_start_pct", "at most 100"])
	_expect_error(set, ["bad_falloff.json", "falloff_min_pct", "at most 100"])
	_expect_error(set, ["bad_recharge.json", "shield_recharge_delay", "at least 0"])
	_expect_error(set, ["grumpy.json", "tolerance_pct", "at least 0"])
	_expect_error(set, ["grumpy.json", "forgiveness_pct_per_s", "expected a number"])
	_expect_error(set, ["hothead.json", "tolerance_factor", "at least 0"])
	_expect_error(set, ["double_pool.json", "traffic[1].pool", "already listed"])
	_expect_error(set, ["game.json", "ai.jump_out_factor", "at least 1"])
	_expect_error(set, ["game.json", "player.uninsured_ship", "no ship definition"])
	_expect_error(set, ["no_hardpoint.json", "default_weapons[0]", "no beam exit points"])
	_expect_error(set, ["bad_ring.json", "local_space[1].region.inner_radius", "smaller than radius"])


func test_invalid_files_are_not_registered() -> void:
	var set: DataSet = _load([BROKEN])
	assert_true(set.get_def("ships", "typo") == null, "invalid ship skipped")
	assert_true(set.get_def("ships", "wrong_id") == null, "mismatched id skipped")
	assert_true(set.get_def("ships", "something_else") == null, "not registered under the wrong id")


func test_real_game_data_is_valid() -> void:
	var set: DataSet = _load(["res://data", "res://mods"])
	assert_true(set.errors.is_empty(), "data/ has errors:\n    %s" % "\n    ".join(set.errors))
	assert_true(set.ids("ships").size() == 6, "5 prototype ships plus target_dummy")
	assert_true(set.ids("weapons").size() == 4, "4 weapons")
	assert_true(set.ids("governments").size() == 3, "3 governments")
	assert_true(set.ids("ai_pools").size() == 3, "3 AI pools")
	assert_true(set.ids("scenery").size() == 5, "5 scenery types")
	assert_true(set.ids("personalities").size() == 5, "5 personalities")
	assert_true(set.ids("systems") == ["test_graveyard", "test_nebula"], "2 test systems")
