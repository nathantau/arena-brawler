extends GutTest

var stats: PlayerStats


func before_each() -> void:
	stats = PlayerStats.new(100, 50, 200)


func test_starts_full() -> void:
	assert_eq(stats.hp, 100)
	assert_eq(stats.armor, 50)
	assert_eq(stats.energy, 200)


func test_armor_absorbs_damage_first() -> void:
	var dealt: int = stats.apply_damage(30)
	assert_eq(dealt, 30)
	assert_eq(stats.armor, 20)
	assert_eq(stats.hp, 100)


func test_damage_overflows_armor_into_hp() -> void:
	stats.apply_damage(70)
	assert_eq(stats.armor, 0)
	assert_eq(stats.hp, 80)


func test_lethal_damage_kills_and_clamps() -> void:
	var dealt: int = stats.apply_damage(500)
	assert_eq(dealt, 150, "only actual remaining armor+hp counts as dealt")
	assert_eq(stats.hp, 0)
	assert_true(stats.is_dead())
	assert_eq(stats.apply_damage(10), 0, "no damage to the dead")


func test_non_positive_damage_ignored() -> void:
	assert_eq(stats.apply_damage(0), 0)
	assert_eq(stats.apply_damage(-5), 0)
	assert_eq(stats.armor, 50)


func test_invulnerable_blocks_damage() -> void:
	stats.invulnerable_time = 0.2
	assert_eq(stats.apply_damage(40), 0)
	assert_eq(stats.armor, 50)
	stats.tick(0.25)
	assert_false(stats.is_invulnerable())
	assert_eq(stats.apply_damage(40), 40)


func test_armor_does_not_regen_before_delay() -> void:
	stats.apply_damage(40)
	stats.tick(Constants.ARMOR_REGEN_DELAY - 0.1)
	assert_eq(stats.armor, 10)


func test_armor_regens_after_delay() -> void:
	stats.apply_damage(40)
	stats.tick(Constants.ARMOR_REGEN_DELAY)
	stats.tick(1.0)
	assert_eq(stats.armor, 10 + int(Constants.ARMOR_REGEN_PER_SEC * 1.0))


func test_armor_regen_caps_at_max() -> void:
	stats.apply_damage(10)
	stats.tick(Constants.ARMOR_REGEN_DELAY)
	stats.tick(100.0)
	assert_eq(stats.armor, 50)


func test_taking_damage_resets_regen_delay() -> void:
	stats.apply_damage(40)
	stats.tick(Constants.ARMOR_REGEN_DELAY - 0.5)
	stats.apply_damage(5)
	stats.tick(Constants.ARMOR_REGEN_DELAY - 0.5)
	assert_eq(stats.armor, 5)


func test_hp_never_regenerates() -> void:
	stats.apply_damage(80)
	assert_eq(stats.hp, 70)
	for i: int in 20:
		stats.tick(1.0)
	assert_eq(stats.hp, 70)
	assert_eq(stats.armor, 50)


func test_spend_energy() -> void:
	assert_true(stats.try_spend_energy(30))
	assert_eq(stats.energy, 170)


func test_spend_energy_fails_when_insufficient() -> void:
	stats.energy = 3
	assert_false(stats.try_spend_energy(4))
	assert_eq(stats.energy, 3, "failed spend must not consume")


func test_zero_cost_always_affordable() -> void:
	stats.energy = 0
	assert_true(stats.try_spend_energy(0))


func test_add_energy_clamps() -> void:
	stats.energy = 190
	stats.add_energy(50)
	assert_eq(stats.energy, 200)


func test_reset_restores_everything() -> void:
	stats.apply_damage(120)
	stats.energy = 0
	stats.reset()
	assert_eq(stats.hp, 100)
	assert_eq(stats.armor, 50)
	assert_eq(stats.energy, 200)


func test_regen_counts_only_time_past_delay_within_one_tick() -> void:
	stats.apply_damage(40)
	stats.tick(Constants.ARMOR_REGEN_DELAY + 0.5)
	assert_eq(stats.armor, 10 + int(Constants.ARMOR_REGEN_PER_SEC * 0.5))


func test_energy_refills_over_time_up_to_max() -> void:
	var s := PlayerStats.new(100, 50, 200)
	s.energy = 0
	s.tick(0.5)
	assert_eq(s.energy, int(Constants.ENERGY_REGEN_PER_SEC * 0.5))
	for i: int in 600:
		s.tick(Constants.PHYSICS_DT)
	assert_eq(s.energy, 200)
	assert_eq(s.energy_accum, 0.0)
