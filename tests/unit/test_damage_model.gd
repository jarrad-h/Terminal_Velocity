extends TvTest
## C5–C7: damage, recharge and disable threshold.


func test_shield_absorbs_first() -> void:
	assert_vec_near(DamageModel.apply(100.0, 50.0, 30.0, 40.0), Vector2(70.0, 50.0), "armour untouched while shields hold")


func test_armour_takes_damage_when_shields_down() -> void:
	assert_vec_near(DamageModel.apply(0.0, 50.0, 30.0, 20.0), Vector2(0.0, 30.0), "full armour damage")


func test_breaking_shot_carries_leftover_fraction() -> void:
	# 10 shield left, shot does 40 shield: 75% of the shot is unspent -> 75% of 20 armour damage.
	assert_vec_near(DamageModel.apply(10.0, 50.0, 40.0, 20.0), Vector2(0.0, 35.0), "leftover 75% hits armour")


func test_exact_shield_break_spends_whole_shot() -> void:
	assert_vec_near(DamageModel.apply(40.0, 50.0, 40.0, 20.0), Vector2(0.0, 50.0), "no bleed-through")


func test_no_shield_damage_means_no_effect_on_shields() -> void:
	assert_vec_near(DamageModel.apply(10.0, 50.0, 0.0, 99.0), Vector2(10.0, 50.0), "armour-only weapon blocked by shields")


func test_armour_never_negative() -> void:
	assert_vec_near(DamageModel.apply(0.0, 5.0, 0.0, 50.0), Vector2(0.0, 0.0), "clamped at zero")


func test_weights_differ_between_weapons() -> void:
	var anti_shield: Vector2 = DamageModel.apply(0.0, 100.0, 40.0, 5.0)
	var anti_armour: Vector2 = DamageModel.apply(0.0, 100.0, 5.0, 40.0)
	assert_true(anti_armour.y < anti_shield.y, "armour-weighted weapon hurts armour more")


func test_regen_caps_at_max() -> void:
	assert_near(DamageModel.regen(90.0, 100.0, 6.0, 1.0), 96.0, "regen per second")
	assert_near(DamageModel.regen(98.0, 100.0, 6.0, 1.0), 100.0, "capped")


func test_disable_threshold() -> void:
	assert_true(DamageModel.is_disabled(33.0, 100.0, 0.33), "at 33% disabled")
	assert_true(not DamageModel.is_disabled(34.0, 100.0, 0.33), "above threshold fine")
	assert_true(not DamageModel.is_disabled(0.0, 100.0, 0.33), "0 is destroyed, not disabled")
	assert_true(not DamageModel.is_disabled(5.0, 100.0, 0.0), "fraction 0 never disables (scenery)")


func test_regen_waits_for_delay() -> void:
	assert_true(not DamageModel.can_regen(2.9, 3.0), "inside the delay (C6)")
	assert_true(DamageModel.can_regen(3.0, 3.0), "delay over")
	assert_true(DamageModel.can_regen(0.0, 0.0), "no delay")


func test_falloff() -> void:
	assert_near(DamageModel.falloff(200.0, 1000.0, 30.0, 10.0), 1.0, "full damage before falloff starts (C12)")
	assert_near(DamageModel.falloff(300.0, 1000.0, 30.0, 10.0), 1.0, "at the start")
	assert_near(DamageModel.falloff(650.0, 1000.0, 30.0, 10.0), 0.55, "halfway down the slope")
	assert_near(DamageModel.falloff(1000.0, 1000.0, 30.0, 10.0), 0.1, "minimum at full range")
	assert_near(DamageModel.falloff(1500.0, 1000.0, 30.0, 10.0), 0.1, "beyond range stays at minimum")
	assert_near(DamageModel.falloff(900.0, 1000.0, 100.0, 10.0), 1.0, "start 100% = no falloff")


func test_falloff_edge_cases() -> void:
	assert_near(DamageModel.falloff(500.0, 0.0, 30.0, 10.0), 1.0, "no range: no falloff")
	assert_near(DamageModel.falloff(0.0, 1000.0, 0.0, 10.0), 1.0, "start 0: full at the muzzle")
	assert_near(DamageModel.falloff(500.0, 1000.0, 0.0, 10.0), 0.55, "start 0: linear from the muzzle")
