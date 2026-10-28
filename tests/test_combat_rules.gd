extends GutTest


func _weapon(damage: int, crit_chance: float, crit_mult: float = 2.0) -> WeaponData:
	var w := WeaponData.new()
	w.damage = damage
	w.crit_chance = crit_chance
	w.crit_multiplier = crit_mult
	return w


func _rng(s: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_normal_damage() -> void:
	assert_eq(CombatRules.damage_for(_weapon(12, 0.0), false), 12)


func test_crit_damage_uses_multiplier() -> void:
	assert_eq(CombatRules.damage_for(_weapon(12, 0.0, 2.0), true), 24)
	assert_eq(CombatRules.damage_for(_weapon(7, 0.0, 1.5), true), 11, "rounded")


func test_zero_crit_chance_never_crits() -> void:
	var w := _weapon(10, 0.0)
	var rng := _rng()
	for i: int in 200:
		assert_false(CombatRules.roll_crit(w, rng))


func test_full_crit_chance_always_crits() -> void:
	var w := _weapon(10, 1.0)
	var rng := _rng()
	for i: int in 200:
		assert_true(CombatRules.roll_crit(w, rng))


func test_crit_is_deterministic_for_seed() -> void:
	var w := _weapon(10, 0.3)
	var a := _rng(7)
	var b := _rng(7)
	for i: int in 50:
		assert_eq(CombatRules.roll_crit(w, a), CombatRules.roll_crit(w, b))


func test_single_pellet_no_spread_goes_straight() -> void:
	var w := WeaponData.new()
	var dirs := CombatRules.shot_directions(Vector2(3, 0), w, _rng())
	assert_eq(dirs.size(), 1)
	assert_almost_eq(dirs[0].x, 1.0, 0.0001)
	assert_almost_eq(dirs[0].y, 0.0, 0.0001)


func test_pellet_fan_is_even_and_symmetric() -> void:
	var w := WeaponData.new()
	w.pellets = 5
	w.pellet_spread_deg = 40.0
	var dirs := CombatRules.shot_directions(Vector2.RIGHT, w, _rng())
	assert_eq(dirs.size(), 5)
	assert_almost_eq(rad_to_deg(dirs[0].angle()), -20.0, 0.001)
	assert_almost_eq(rad_to_deg(dirs[2].angle()), 0.0, 0.001)
	assert_almost_eq(rad_to_deg(dirs[4].angle()), 20.0, 0.001)


func test_random_spread_stays_within_cone() -> void:
	var w := WeaponData.new()
	w.spread_deg = 10.0
	var rng := _rng()
	for i: int in 200:
		var d: Vector2 = CombatRules.shot_directions(Vector2.RIGHT, w, rng)[0]
		assert_true(absf(rad_to_deg(d.angle())) <= 5.0 + 0.001)


func test_shot_directions_deterministic_for_seed() -> void:
	var w := WeaponData.new()
	w.pellets = 6
	w.spread_deg = 8.0
	w.pellet_spread_deg = 26.0
	assert_eq(CombatRules.shot_directions(Vector2.UP, w, _rng(9)), CombatRules.shot_directions(Vector2.UP, w, _rng(9)))
