extends GutTest
## Character skills (dash / barrier / dual wield) and movement integration.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var flicker: CharacterData
var warden: CharacterData
var twinshot: CharacterData


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	flicker = characters.get_character(&"flicker")
	warden = characters.get_character(&"warden")
	twinshot = characters.get_character(&"twinshot")


func test_catalog_covers_every_skill_kind() -> void:
	assert_eq(characters.ordered.size(), 4)
	var kinds: Array = []
	for c: CharacterData in characters.ordered:
		kinds.append(c.skill)
		assert_not_null(c.sprite_sheet, c.id)
		assert_true(c.max_hp > 0 and c.move_speed > 0.0 and c.skill_cooldown > 0.0 and c.skill_duration > 0.0, c.id)
		assert_ne(c.display_name, "")
	assert_eq(characters.default_character(), flicker)
	for kind: int in CharacterData.SkillKind.values():
		assert_true(kinds.has(kind), "no character has skill %d" % kind)
	assert_eq(characters.next_after(characters.ordered.back().id), characters.ordered[0], "wraps")


func test_dash_grants_iframes_and_cooldown() -> void:
	var stats := PlayerStats.new()
	var skill := CharacterSkill.new(flicker)
	assert_true(skill.try_activate(Vector2(0, 2), Vector2.ZERO, stats))
	assert_true(skill.is_dashing())
	assert_eq(skill.direction, Vector2(0, 1))
	assert_true(stats.is_invulnerable())
	assert_almost_eq(stats.invulnerable_time, flicker.dash_iframes, 0.0001)


func test_skill_blocked_during_cooldown() -> void:
	var stats := PlayerStats.new()
	var skill := CharacterSkill.new(flicker)
	skill.try_activate(Vector2.RIGHT, Vector2.ZERO, stats)
	skill.tick(flicker.skill_duration + 0.01)
	assert_false(skill.is_active())
	assert_false(skill.try_activate(Vector2.RIGHT, Vector2.ZERO, stats))
	skill.tick(flicker.skill_cooldown)
	assert_true(skill.try_activate(Vector2.RIGHT, Vector2.ZERO, stats))


func test_skill_needs_direction() -> void:
	var skill := CharacterSkill.new(flicker)
	assert_false(skill.try_activate(Vector2.ZERO, Vector2.ZERO, PlayerStats.new()))


func test_barrier_is_placed_in_front_and_expires() -> void:
	var stats := PlayerStats.new()
	var skill := CharacterSkill.new(warden)
	assert_true(skill.try_activate(Vector2.UP, Vector2(100, 100), stats))
	assert_true(skill.is_shielding())
	assert_false(skill.is_dashing())
	assert_false(stats.is_invulnerable(), "barrier gives no i-frames")
	assert_eq(skill.anchor, Vector2(100, 100) + Vector2.UP * warden.shield_distance)
	skill.tick(warden.skill_duration + 0.01)
	assert_false(skill.is_shielding())


func test_dual_wield_window() -> void:
	var skill := CharacterSkill.new(twinshot)
	assert_true(skill.try_activate(Vector2.RIGHT, Vector2.ZERO, PlayerStats.new()))
	assert_true(skill.is_dual_wielding())
	skill.tick(twinshot.skill_duration + 0.01)
	assert_false(skill.is_dual_wielding())


func test_dash_velocity_overrides_input() -> void:
	var skill := CharacterSkill.new(flicker)
	skill.try_activate(Vector2.LEFT, Vector2.ZERO, PlayerStats.new())
	var v: Vector2 = MovementSim.step_velocity(Vector2.ZERO, Vector2.RIGHT, skill, flicker.move_speed, DT)
	assert_eq(v, Vector2.LEFT * flicker.dash_speed)


func test_movement_accelerates_to_character_speed() -> void:
	for c: CharacterData in characters.ordered:
		var skill := CharacterSkill.new(c)
		var v := Vector2.ZERO
		for i: int in 120:
			v = MovementSim.step_velocity(v, Vector2.RIGHT, skill, c.move_speed, DT)
		assert_almost_eq(v.length(), c.move_speed, 0.001, c.id)


func test_move_input_is_clamped_to_unit_length() -> void:
	var skill := CharacterSkill.new(flicker)
	var v := Vector2.ZERO
	for i: int in 120:
		v = MovementSim.step_velocity(v, Vector2(5, 5), skill, flicker.move_speed, DT)
	assert_almost_eq(v.length(), flicker.move_speed, 0.001)


func test_movement_stops_without_input() -> void:
	var skill := CharacterSkill.new(flicker)
	var v := Vector2(flicker.move_speed, 0)
	for i: int in 60:
		v = MovementSim.step_velocity(v, Vector2.ZERO, skill, flicker.move_speed, DT)
	assert_eq(v, Vector2.ZERO)


func test_deadzone_ignored() -> void:
	var skill := CharacterSkill.new(flicker)
	var v: Vector2 = MovementSim.step_velocity(Vector2.ZERO, Vector2(Constants.INPUT_DEADZONE * 0.5, 0), skill,
		flicker.move_speed, DT)
	assert_eq(v, Vector2.ZERO)


func test_character_sets_stat_maxes() -> void:
	var p := Player.new()
	var weapons: Array[WeaponData] = WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName])
	p.setup(1, 0, Color.WHITE, weapons, null, null, 0, warden)
	add_child_autofree(p)
	assert_eq(p.stats.max_hp, warden.max_hp)
	assert_eq(p.stats.hp, warden.max_hp)
	assert_eq(p.stats.max_energy, warden.max_energy)
	p.set_character(twinshot)
	assert_eq(p.stats.max_hp, twinshot.max_hp)
	assert_eq(p.skill.data, twinshot)
