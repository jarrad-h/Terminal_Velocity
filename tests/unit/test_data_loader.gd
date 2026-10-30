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
	assert_vec_near(ship.hit_size, Vector2(32, 32), "hit_size default")
	assert_vec_near(ship.hit_offset, Vector2.ZERO, "hit_offset default")
	assert_true(ship.engines.is_empty(), "no engines by default")
	assert_near(ship.engine_size, 6.0, "engine glow size default")
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
	assert_true(ship.hardpoints.size() == 2 and ship.hardpoints[1].id == "T1", "hardpoints parsed")
	var turret: HardpointDef = ship.hardpoint("T1")
	assert_true(turret.size == "small" and turret.mount == "turret" and turret.role == "point_defence", "hardpoint fields")
	assert_vec_near(turret.pos, Vector2(0, 4), "hardpoint position")
	assert_near(turret.arc_degrees(set.settings), 270.0, "per-hardpoint arc override")
	assert_near(ship.hardpoint("G1").arc_degrees(set.settings), 0.0, "fixed mounts have no arc")
	assert_near(turret.traverse_degrees(set.settings), 360.0, "turret traverse from game.json default")
	assert_true(ship.loadout.size() == 2 and ship.loadout[1].weapon == "zap" and ship.loadout[1].mount == "turret", "loadout parsed")
	var zap: WeaponDef = set.get_def("weapons", "zap")
	assert_true(zap.kind == "projectile" and zap.size == "small" and zap.mounts == ["fixed", "turret"], "weapon size and mounts")
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
	assert_near(law.tolerance_pct, 10.0, "A8 tolerance default")
	assert_near(law.forgiveness_pct_per_s, 0.5, "A8 forgiveness default")


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
	assert_true(ship.loadout.is_empty() and ship.hardpoints.is_empty(), "replacement is whole-file, not a merge")
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
	_expect_error(set, ["bad_ref.json", "loadout[0].weapon", "missing_gun"])
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
	_expect_error(set, ["game.json", "player.rescue_fee_pct", "at most 100"])
	_expect_error(set, ["game.json", "player.rescue_days", "greater than max"])
	_expect_error(set, ["game.json", "boarding.time", "more than 0"])
	_expect_error(set, ["game.json", "boarding.assist_armor_pct", "at most 100"])
	_expect_error(set, ["game.json", "landing.max_speed", "at least 0"])
	_expect_error(set, ["bad_loot.json", "board_credits", "greater than max"])
	_expect_error(set, ["broke.json", "wealth_factor", "at least 0"])
	_expect_error(set, ["stingy.json", "assist_reward", "at least 0"])
	_expect_error(set, ["misfit.json", "loadout[0]", "no hardpoint 'X9'"])
	_expect_error(set, ["misfit.json", "loadout[1]", "small weapon doesn't fit a medium hardpoint"])
	_expect_error(set, ["misfit.json", "loadout[2]", "doesn't come in a turret mount"])
	_expect_error(set, ["misfit.json", "loadout[3]", "doesn't come in a pivot mount"])
	_expect_error(set, ["misfit.json", "loadout[5]", "'G1' already has a weapon"])
	_expect_error(set, ["bad_hull.json", "hit_size", "more than length"])
	_expect_error(set, ["bad_hull.json", "hardpoints[0].size", "tiny"])
	_expect_error(set, ["bad_hull.json", "hardpoints[1].id", "already used"])
	_expect_error(set, ["bad_hull.json", "hardpoints[1].role", "needs a turret mount"])
	_expect_error(set, ["bad_hull.json", "hardpoints[2].arc", "at most 360"])
	_expect_error(set, ["bad_hull.json", "engines[1]", "expected [x, y]"])
	_expect_error(set, ["bad_mounts.json", "size", "huge"])
	_expect_error(set, ["bad_mounts.json", "mounts[0]", "launcher mount, and only"])
	_expect_error(set, ["bad_mounts.json", "mounts[1]", "gimbal"])
	_expect_error(set, ["no_mounts.json", "mounts", "is required"])
	_expect_error(set, ["game.json", "art_scale", "more than 0"])
	_expect_error(set, ["too_friendly.json", "friendly_record", "above crime_threshold"])
	_expect_error(set, ["bad_hull.json", "hardpoints[3].arc", "no effect on a fixed mount"])
	_expect_error(set, ["bad_launcher.json", "hardpoints[0].traverse", "no effect on a launcher mount"])
	_expect_error(set, ["misfit.json", "sprite", "no image at"])
	_expect_error(set, ["game.json", "mounts.turret_sprites.small", "no image at"])
	_expect_error(set, ["game.json", "engine_glow.idle", "at most 1"])
	_expect_error(set, ["game.json", "messages.max_lines", "at least 1"])
	_expect_error(set, ["game.json", "hud.colours.shield", "expected a colour"])
	_expect_error(set, ["game.json", "mounts.arc.pivot", "at most 360"])
	_expect_error(set, ["game.json", "mounts.traverse.turret", "at least 0"])
	_expect_error(set, ["bad_ring.json", "local_space[1].region.inner_radius", "smaller than radius"])


## TR1, TR7: galaxy validation; TR2, TR8, TM2: travel fields on systems, stellars, ships, game.json.
func test_travel_errors_name_file_and_field() -> void:
	var set: DataSet = _load([BROKEN])
	_expect_error(set, ["tangled.json", "start_system", "starts hidden"])
	_expect_error(set, ["tangled.json", "systems[2].system", "no system definition with id 'nowhere'"])
	_expect_error(set, ["tangled.json", "hyperlanes[1]", "already listed"])
	_expect_error(set, ["tangled.json", "hyperlanes[2]", "two different systems"])
	_expect_error(set, ["tangled.json", "hyperlanes[3]", "'elsewhere' is not in this galaxy"])
	_expect_error(set, ["lost.json", "systems[0].map_state", "lost"])
	_expect_error(set, ["lost.json", "systems[1].system", "listed twice"])
	_expect_error(set, ["stray.json", "start_system", "not in this galaxy"])
	_expect_error(set, ["no_drive.json", "jump_speed", "more than 0"])
	_expect_error(set, ["no_drive.json", "fuel", "at least 0"])
	_expect_error(set, ["tiny.json", "jump_radius", "at least 100"])
	_expect_error(set, ["sys.json", "objects[0].landing_days", "at least 0"])
	_expect_error(set, ["sys.json", "objects[0].refuel_price", "expected a number"])
	_expect_error(set, ["game.json", "galaxy", "no galaxy definition with id 'no_such_galaxy'"])
	_expect_error(set, ["game.json", "calendar.start_date", "expected a date"])
	_expect_error(set, ["game.json", "hyperspace.engage_speed_factor", "more than 1"])
	_expect_error(set, ["game.json", "hyperspace.overdrive_accel_factor", "more than 0"])
	_expect_error(set, ["game.json", "hyperspace.arrival_speed_fraction", "at most 1"])


## TR5, TR6: gate fields, one gate per system, links between gates, and
## gates faster than the hyperlane route.
func test_gate_errors() -> void:
	var set: DataSet = _load(["res://tests/fixtures/loader/gates"])
	_expect_error(set, ["ring.json", "gate_links[0]", "'b' has no gate"])
	_expect_error(set, ["ring.json", "gate_links[1].days", "no faster than the 2-day hyperlane route"])
	_expect_error(set, ["ring.json", "gate_links[2]", "two different systems"])
	_expect_error(set, ["zero.json", "gate_links[0].days", "at least 1"])
	_expect_error(set, ["twogates.json", "at most one gate"])
	_expect_error(set, ["badgate.json", "objects[0].fee", "only gates"])
	_expect_error(set, ["badgate.json", "objects[1].open_condition", "flag_name"])
	var galaxy: GalaxyDef = _load([BASE]).get_def("galaxy", "tiny")
	assert_true(galaxy.gate_links.is_empty(), "gate_links default to none")


func test_travel_defaults() -> void:
	var set: DataSet = _load([BASE])
	var ship: ShipDef = set.get_def("ships", "alpha")
	assert_near(ship.fuel, 300.0, "fuel default")
	assert_near(ship.jump_fuel, 100.0, "jump_fuel default")
	assert_near(ship.jump_countdown, 3.0, "jump_countdown default")
	assert_near(ship.jump_speed, 150.0, "jump_speed default")
	var home: SystemDef = set.get_def("systems", "home")
	assert_near(home.jump_radius, 8000.0, "jump_radius default")
	var galaxy: GalaxyDef = set.get_def("galaxy", "tiny")
	assert_true(galaxy.start_states["away"] == "unexplored", "map_state default")
	assert_true(set.settings["calendar"]["start_date"] == "3200-01-01", "calendar default")


func test_invalid_files_are_not_registered() -> void:
	var set: DataSet = _load([BROKEN])
	assert_true(set.get_def("ships", "typo") == null, "invalid ship skipped")
	assert_true(set.get_def("ships", "wrong_id") == null, "mismatched id skipped")
	assert_true(set.get_def("ships", "something_else") == null, "not registered under the wrong id")


func test_real_game_data_is_valid() -> void:
	var set: DataSet = _load(["res://data", "res://mods"])
	assert_true(set.errors.is_empty(), "data/ has errors:\n    %s" % "\n    ".join(set.errors))
	assert_true(set.ids("ships").size() == 6, "5 prototype ships plus target_dummy")
	assert_true(set.ids("weapons").size() == 6, "3 laser sizes, flak, missile, beam")
	assert_true(set.ids("governments").size() == 3, "3 governments")
	assert_true(set.ids("ai_pools").size() == 3, "3 AI pools")
	assert_true(set.ids("scenery").size() == 5, "5 scenery types")
	assert_true(set.ids("personalities").size() == 5, "5 personalities")
	assert_true(set.ids("systems").size() == 10, "the 10-system test cluster")
	var galaxy: GalaxyDef = set.get_def("galaxy", "test_cluster")
	assert_true(galaxy != null and galaxy.system_ids.size() == 10, "every test system is on the map")
	assert_true(galaxy.lanes.size() == 12, "12 hyperlanes")


## V3: the art-led loadouts (docs/art/hardpoints.md, decisions 2026-10-29).
func test_real_ships_follow_the_art() -> void:
	var set: DataSet = _load(["res://data", "res://mods"])
	var courier: ShipDef = set.get_def("ships", "courier")
	assert_true(courier.loadout.is_empty() and courier.hardpoints.is_empty(), "courier is unarmed (C-B Booster)")
	assert_true(set.settings["player_ship"] == "shuttle", "player starts in the shuttle")
	var patrol: ShipDef = set.get_def("ships", "patrol_corvette")
	var mounts: Array[String] = []
	for e: LoadoutEntry in patrol.loadout:
		mounts.append(e.mount)
	assert_true(mounts == ["turret", "turret", "launcher"], "patrol: 2 turrets + launcher (P-B): %s" % [mounts])
	var raider: ShipDef = set.get_def("ships", "pirate_raider")
	assert_vec_near(raider.hardpoint("G2").pos, Vector2(14.9, -29.7), "raider keeps its asymmetric gun")
	assert_vec_near((set.get_def("ships", "freighter") as ShipDef).hit_offset, Vector2(-14, 0), "freighter hitbox on the hull body")


## A8 regression (M7 review): with the real data, sustained fire from the
## player's start ship turns any non-pirate pool ship hostile within 40 s at
## 50% hits, while five stray hits are forgiven. Guards against tuning health
## or damage without tuning tolerance and forgiveness.
func test_real_grievance_tuning_still_bites() -> void:
	var set: DataSet = _load(["res://data", "res://mods"])
	var start: ShipDef = set.get_def("ships", set.settings["player_ship"])
	var per_second: float = 0.0
	var per_hit: float = 0.0
	for entry: LoadoutEntry in start.loadout:
		var w: WeaponDef = set.get_def("weapons", entry.weapon)
		if w.kind == "projectile":
			per_second += w.damage_shield / maxf(w.reload, 1.0 / 60.0) * 0.5
			per_hit = maxf(per_hit, w.damage_shield)
	assert_true(per_second > 0.0, "start ship is armed")
	for pool_id: String in set.ids("ai_pools"):
		var pool: AiPoolDef = set.get_def("ai_pools", pool_id)
		var gov: GovernmentDef = set.get_def("governments", pool.government)
		if gov == null or gov.crime_threshold > 0.0:
			continue  # pirates start hostile
		for pick: Dictionary in pool.ships:
			var ship: ShipDef = set.get_def("ships", pick["ship"])
			var total: float = ship.shield + ship.armor
			var grievance: float = 0.0
			var t: float = 0.0
			while t < 40.0 and not Grievance.exceeded(grievance, Grievance.tolerance(gov.tolerance_pct, 1.0)):
				grievance = Grievance.decay(Grievance.add(grievance, per_second * 0.1, total), gov.forgiveness_pct_per_s, 0.1)
				t += 0.1
			assert_true(t < 40.0, "%s/%s: sustained fire turns it hostile (%.0f s)" % [pool_id, ship.id, t])
			assert_true(not Grievance.exceeded(per_hit * 5.0 / total * 100.0, gov.tolerance_pct), "%s/%s: five stray hits forgiven" % [pool_id, ship.id])
