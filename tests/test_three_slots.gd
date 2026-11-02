extends GutTest
## Three special slots: defaults and eligibility per fighter, set_skill swaps, snapshot round-trip, loadout in snapshots.

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


func test_every_rotation_fighter_has_three_distinct_specials_by_default() -> void:
	for c: CharacterData in characters.all():
		var pool: Array[SkillData] = SkillCatalog.shared().specials_for(c)
		if c.in_rotation:
			assert_gte(pool.size(), 3, "%s has 3 eligible specials" % c.id)
		var d: Array[SkillData] = Player.default_skills(c)
		assert_eq(d.size(), 3, c.id)
		assert_eq(d[0], SkillCatalog.shared().dash(), "%s: Dash first" % c.id)
		var second: SkillData = c.signature_skill if c.signature_skill != null else SkillCatalog.shared().get_skill(&"barrier")
		assert_eq(d[1], second, "%s: signature second (the list leads with Dash and Barrier, defaults are unchanged)" % c.id)
		assert_true(pool.has(second))
		if c.in_rotation:
			assert_eq(d.find(d[2]), 2, "%s: third is distinct" % c.id)


func test_set_skill_swaps_with_any_other_slot() -> void:
	var p: Player = _player(1, &"flicker")
	var first: SkillData = p.skills[0].data
	var third: SkillData = p.skills[2].data
	p.set_skill(0, third)
	assert_eq(p.skills[0].data, third)
	assert_eq(p.skills[2].data, first, "slot 2 swapped, no duplicate")
	var ids: Array = p.skills.map(func(s: CharacterSkill) -> StringName: return s.data.id)
	for id: StringName in ids:
		assert_eq(ids.count(id), 1)


func test_switching_character_keeps_usable_picks_without_duplicates() -> void:
	var p: Player = _player(1, &"flicker")
	p.set_skill(2, SkillCatalog.shared().get_skill(&"barrier"))
	p.set_character(characters.get_character(&"wukong"))
	assert_eq(p.skills[2].data.id, &"barrier", "generic pick kept in slot 2")
	var ids: Array = p.skills.map(func(s: CharacterSkill) -> StringName: return s.data.id)
	for id: StringName in ids:
		assert_eq(ids.count(id), 1)


func test_select_special_accepts_slot_two_only_in_range() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var me: Player = arena.add_player(1, 0, null)
	arena.select_special(me, 2, &"barrier")
	assert_eq(me.skills[2].data.id, &"barrier")
	var before: Array = me.skills.map(func(s: CharacterSkill) -> StringName: return s.data.id)
	arena.select_special(me, 3, &"dash")
	assert_eq(me.skills.map(func(s: CharacterSkill) -> StringName: return s.data.id), before, "slot 3 rejected")


func test_snapshot_round_trip_carries_all_three_slots() -> void:
	var a: Player = _player(1, &"flicker")
	var b: Player = _player(2, &"flicker")
	a.set_skill(2, SkillCatalog.shared().get_skill(&"barrier"))
	a.skills[2].cooldown_remaining = 2.5
	a.skills[2].active_remaining = 0.5
	a._prev_skills = [false, true, true]
	assert_true(b.apply_state(a.capture_state(), catalog, characters))
	for i: int in 3:
		assert_eq(b.skills[i].data.id, a.skills[i].data.id, "slot %d id" % i)
		assert_almost_eq(b.skills[i].cooldown_remaining, a.skills[i].cooldown_remaining, 0.0001)
		assert_almost_eq(b.skills[i].active_remaining, a.skills[i].active_remaining, 0.0001)
	assert_eq(b._prev_skills, a._prev_skills, "edge state of all three buttons")


func test_third_button_is_edge_triggered_and_unaffected_by_dead_hold() -> void:
	var p: Player = _player(1, &"flicker")
	p.set_skill(2, SkillCatalog.shared().get_skill(&"overdrive") if p.character.can_use_skill(SkillCatalog.shared().get_skill(&"overdrive")) else SkillCatalog.shared().get_skill(&"barrier"))
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
