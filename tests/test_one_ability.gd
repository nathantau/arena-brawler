extends GutTest
## One ability at a time: while one equipped special is in a phase that changes the player (CharacterSkill.blocks_other),
## the other slot's press is ignored (no cooldown charged); lingering world objects never block.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var skills: SkillCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	skills = SkillCatalog.shared()


func _player(slot0: StringName, slot1: StringName, who: StringName = &"flicker") -> Player:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(who))
	world.add_child(p)
	p.global_position = Vector2(300, 300)
	p.skills[0] = CharacterSkill.new(skills.get_skill(slot0))
	p.skills[1] = CharacterSkill.new(skills.get_skill(slot1))
	return p


func _step(p: Player, press_slot: int = -1, seq: int = 1) -> void:
	var f := InputFrame.new()
	f.seq = seq
	f.aim_vec = Vector2.RIGHT
	f.move_vec = Vector2.RIGHT
	f.skill = press_slot == 0
	f.special = press_slot == 1
	p.simulate(f, DT)


func _run(p: Player, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		_step(p)


func test_blocking_kinds_lock_the_other_slot() -> void:
	for id: StringName in [&"dash", &"great_ape", &"vine_swing", &"grapple_kunai", &"staff_whirl", &"petal_drift", &"sky_pillar",
			&"flare_burst", &"overdrive", &"bark_skin", &"leaf_gust", &"shadow_step", &"blaze_run"]:
		var p: Player = _player(id, &"smoke_bomb")
		_step(p, 0)
		if not p.skills[0].is_active():
			continue  # e.g. a swing or grapple with nowhere to go: nothing happened, nothing to block
		assert_true(p.skill_locked(1), "%s locks slot 1" % id)
		_step(p, 1, 2)
		assert_false(p.skills[1].is_active(), "%s: second press ignored" % id)
		assert_eq(p.skills[1].cooldown_remaining, 0.0, "%s: no cooldown charged" % id)


func test_allowed_after_first_ends() -> void:
	var p: Player = _player(&"overdrive", &"smoke_bomb")
	_step(p, 0)
	assert_true(p.skill_locked(1))
	_run(p, 3.1)
	assert_false(p.skills[0].is_active())
	assert_false(p.skill_locked(1))
	_step(p, 1, 500)
	assert_true(p.skills[1].is_active(), "second special works once the first is over")


func test_either_order_and_same_frame() -> void:
	var p: Player = _player(&"dash", &"overdrive")
	_step(p, 1)
	_step(p, 0, 2)
	assert_eq(p.skills[0].cooldown_remaining, 0.0, "dash blocked by overdrive")
	var q: Player = _player(&"dash", &"overdrive")
	var f := InputFrame.new()
	f.seq = 1
	f.aim_vec = Vector2.RIGHT
	f.skill = true
	f.special = true
	q.simulate(f, DT)
	assert_true(q.skills[0].is_active() != q.skills[1].is_active(), "pressed together: exactly one fires")


func test_lingering_objects_do_not_block() -> void:
	for id: StringName in [&"smoke_bomb", &"shadow_clones", &"cherry_sapling", &"storm_cloud", &"verdant_bloom", &"gloom_hound",
			&"shadow_bind", &"barrier", &"blossom_ward", &"eruption", &"fan_of_blades"]:
		var p: Player = _player(id, &"overdrive")
		_step(p, 0)
		assert_true(p.skills[0].is_active() or id == &"fan_of_blades", "%s started" % id)
		assert_false(p.skill_locked(1), "%s does not lock" % id)
		_step(p, 1, 2)
		assert_true(p.skills[1].is_active(), "%s: other special fires" % id)


func test_trail_blocks_only_while_dashing() -> void:
	var p: Player = _player(&"blaze_run", &"overdrive", &"flint")
	_step(p, 0)
	assert_true(p.skills[0].is_active())
	assert_true(p.skill_locked(1), "dashing along the trail")
	_run(p, p.skills[0].data.trail_dash_time + 0.1)
	assert_true(p.skills[0].is_active(), "trail still burns")
	assert_false(p.skill_locked(1), "burning floor doesn't lock")


func test_death_ends_every_ability() -> void:
	var p: Player = _player(&"storm_cloud", &"overdrive")
	_step(p, 0)
	_step(p, 1, 2)
	p.take_hit(10000, false, Vector2.ZERO, 2)
	for s: CharacterSkill in p.skills:
		assert_false(s.is_active())


func test_freeze_ends_abilities_and_lands_a_swing() -> void:
	var p: Player = _player(&"vine_swing", &"overdrive", &"sakura")
	p.global_position = Vector2(300, 300)
	_step(p, 0)
	if not p.skills[0].is_active():
		return
	var landing: Vector2 = p.skills[0].anchor + p.skills[0].direction
	_run(p, 0.1)
	p.frozen = true
	_step(p, -1, 99)
	assert_false(p.skills[0].is_active() or p.skills[1].is_active(), "the freeze ends everything")
	assert_eq(p.global_position, landing, "a swing lands rather than hanging in mid-air")


func test_sitting_out_ends_abilities() -> void:
	var p: Player = _player(&"smoke_bomb", &"overdrive")
	_step(p, 0)
	_step(p, 1, 2)
	p.sit_out()
	assert_false(p.skills[0].is_active() or p.skills[1].is_active())
