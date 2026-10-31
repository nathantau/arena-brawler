extends GutTest

const WEAPON_DIR: String = "res://data/weapons/"


func _weapon(cost: int, interval: float) -> WeaponData:
	var w := WeaponData.new()
	w.energy_cost = cost
	w.fire_interval = interval
	return w


func test_fire_consumes_energy_and_starts_cooldown() -> void:
	var stats := PlayerStats.new(100, 50, 10)
	var ws := WeaponState.new(_weapon(4, 0.5))
	assert_true(ws.try_fire(stats))
	assert_eq(stats.energy, 6)
	assert_false(ws.is_ready())
	assert_false(ws.try_fire(stats), "blocked by cooldown")
	assert_eq(stats.energy, 6, "blocked shot costs nothing")
	ws.tick(0.5)
	assert_true(ws.try_fire(stats))
	assert_eq(stats.energy, 2)


func test_cannot_fire_without_energy() -> void:
	var stats := PlayerStats.new(100, 50, 3)
	var ws := WeaponState.new(_weapon(4, 0.5))
	assert_false(ws.try_fire(stats))
	assert_eq(stats.energy, 3)
	assert_true(ws.is_ready(), "failed shot must not start cooldown")


func test_free_weapon_fires_at_zero_energy() -> void:
	var stats := PlayerStats.new(100, 50, 200)
	stats.energy = 0
	var ws := WeaponState.new(_weapon(0, 0.2))
	assert_true(ws.try_fire(stats))


func test_all_weapon_resources_valid() -> void:
	var dir := DirAccess.open(WEAPON_DIR)
	assert_not_null(dir)
	var count: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var w := load(WEAPON_DIR + file) as WeaponData
		assert_not_null(w, file)
		assert_ne(w.id, &"", file + " id")
		assert_true(w.damage > 0, file + " damage")
		assert_true(w.fire_interval > 0.0, file + " fire_interval")
		assert_true(w.projectile_speed > 0.0, file + " speed")
		assert_true(w.energy_cost >= 0, file + " cost")
		assert_true(w.pellets >= 1, file + " pellets")
		count += 1
	assert_true(count >= 3, "M1 needs at least 3 weapons")


## Energy is the only limit on a fighter's one weapon: every carried weapon costs some (form and volley weapons don't).
func test_carried_weapons_cost_energy() -> void:
	var catalog := WeaponCatalog.load_all()
	for c: CharacterData in CharacterCatalog.load_all().ordered:
		for id: StringName in catalog.pickup_ids() + [c.signature_weapon.id]:
			assert_gt(catalog.get_weapon(id).energy_cost, 0, String(id))
