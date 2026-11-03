extends GutTest
## Three skill slots (2 picked + the fixed ultimate): defaults and eligibility per fighter, set_skill swaps, snapshot round-trip.

var characters: CharacterCatalog
var catalog: WeaponCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	catalog = WeaponCatalog.load_all()


func _player(id: int, who: StringName) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, catalog.resolve([&"pistol"] as Array[StringName]), null, null, 0, characters.get_character(who))
	add_child_autofree(p)
	return p


func test_slot_count_is_three() -> void:
	assert_eq(Constants.SKILL_SLOTS, 3)
	assert_eq(InputFrame.new().pressed_slots().size(), 3)
	assert_eq(_player(1, &"flicker").skills.size(), 3)


func test_every_rotation_fighter_has_two_distinct_picks_by_default() -> void:
	for c: CharacterData in characters.all():
		var pool: Array[SkillData] = SkillCatalog.shared().specials_for(c)
		var d: Array[SkillData] = Player.default_skills(c)
		assert_eq(d.size(), Constants.PICKED_SLOTS, c.id)
		assert_eq(d[0], SkillCatalog.shared().dash(), "%s: Dash first" % c.id)
		assert_true(pool.has(d[1]), "%s: second pick is pickable" % c.id)
		assert_ne(d[1], c.ultimate, "%s: never the ultimate" % c.id)
		if c.in_rotation:
			assert_ne(d[0], d[1], "%s: distinct" % c.id)
			assert_true(d[1].tags.has(c.id), "%s: the next own-tagged special" % c.id)


func test_ultimate_is_the_fixed_third_slot() -> void:
	for c: CharacterData in characters.all():
		var p: Player = _player(1, c.id)
		assert_eq(p.skills[Constants.ULT_SLOT].data, c.ultimate if c.ultimate != null else Player.NO_ULT, c.id)


func test_set_skill_swaps_with_the_other_pick() -> void:
	var p: Player = _player(1, &"flicker")
	var first: SkillData = p.skills[0].data
	var second: SkillData = p.skills[1].data
	p.set_skill(0, second)
	assert_eq(p.skills[0].data, second)
	assert_eq(p.skills[1].data, first, "swapped, no duplicate")


func test_switching_character_keeps_usable_picks_without_duplicates() -> void:
	var p: Player = _player(1, &"flicker")
	p.set_skill(1, SkillCatalog.shared().get_skill(&"barrier"))
	p.set_character(characters.get_character(&"wukong"))
	assert_eq(p.skills[1].data.id, &"barrier", "generic pick kept")
	assert_eq(p.skills[2].data.id, &"great_ape", "the ultimate follows the fighter")
	var ids: Array = p.skills.map(func(s: CharacterSkill) -> StringName: return s.data.id)
	for id: StringName in ids:
		assert_eq(ids.count(id), 1)


func test_select_special_accepts_only_the_picked_slots_and_no_ultimates() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var me: Player = arena.add_player(1, 0, null)
	arena.select_special(me, 1, &"barrier")
	assert_eq(me.skills[1].data.id, &"barrier")
	var before: Array = me.skills.map(func(s: CharacterSkill) -> StringName: return s.data.id)
	arena.select_special(me, 2, &"dash")
	assert_eq(me.skills.map(func(s: CharacterSkill) -> StringName: return s.data.id), before, "the ultimate slot is rejected")
	arena.select_special(me, 0, me.character.ultimate.id)
	assert_eq(me.skills.map(func(s: CharacterSkill) -> StringName: return s.data.id), before, "ultimates are not pickable")


func test_snapshot_round_trip_carries_all_three_slots() -> void:
	var a: Player = _player(1, &"flicker")
	var b: Player = _player(2, &"flicker")
	a.skills[2].cooldown_remaining = 2.5
	a.skills[2].active_remaining = 0.5
	a._prev_skills = [false, true, true]
	a.ult_charge = 0.4
	assert_true(b.apply_state(a.capture_state(), catalog, characters))
	for i: int in 3:
		assert_eq(b.skills[i].data.id, a.skills[i].data.id, "slot %d id" % i)
		assert_almost_eq(b.skills[i].cooldown_remaining, a.skills[i].cooldown_remaining, 0.0001)
		assert_almost_eq(b.skills[i].active_remaining, a.skills[i].active_remaining, 0.0001)
	assert_eq(b._prev_skills, a._prev_skills, "edge state of all three buttons")
	assert_almost_eq(b.ult_charge, 0.4, 0.0001, "charge is in the snapshot")


func test_third_button_is_edge_triggered_and_unaffected_by_dead_hold() -> void:
	var p: Player = _player(1, &"flicker")
	p.ult_charge = 1.0
	var f := InputFrame.new()
	f.seq = 1
	f.aim_vec = Vector2.RIGHT
	f.special2 = true
	p.dead = true
	p.simulate(f, 1.0 / 60.0)  # held while dead
	p.dead = false
	f.seq = 2
	p.simulate(f, 1.0 / 60.0)
	assert_false(p.skills[2].is_active(), "a hold through death doesn't fire on respawn")


func test_swapping_slots_keeps_each_specials_cooldown() -> void:
	var p: Player = _player(1, &"flicker")
	var second: SkillData = p.skills[1].data
	p.skills[1].cooldown_remaining = 4.0
	p.set_skill(0, second)
	assert_eq(p.skills[0].data, second)
	assert_eq(p.skills[0].cooldown_remaining, 4.0, "the special that was cooling down is still cooling down")
	assert_eq(p.skills[1].cooldown_remaining, 0.0)
