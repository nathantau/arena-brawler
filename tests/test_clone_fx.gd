extends GutTest
## Shade's clones are drawn as characters on their rings (both Shadow Clones and Shadow Army), and a Shadow Army
## clone visibly throws: its weapon points along its shot, which leaves its hand.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var skills: SkillCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	skills = SkillCatalog.shared()


func _shade() -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	pool.authoritative = true
	world.add_child(pool)
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3, characters.get_character(&"flicker"))
	world.add_child(p)
	p.global_position = Vector2(100, 300)
	pool.targets.append(p)
	p.set_skill(1, skills.get_skill(&"shadow_clones"))
	return [p, pool]


func _frame(p: Player, seq: int, fire: bool = false, special: bool = false, ult: bool = false) -> void:
	var f := InputFrame.new()
	f.seq = seq
	f.aim_vec = Vector2.RIGHT
	f.fire = fire
	f.special = special
	f.special2 = ult
	p.simulate(f, DT)


func _run(p: Player, ult: bool) -> void:
	p.ult_charge = 1.0
	_frame(p, 1, false, not ult, ult)
	for i: int in 25:
		_frame(p, 2 + i)
	p._special_fx.sync(p)


func _check_drawn_as_characters(p: Player) -> void:
	var fx: SpecialFx = p._special_fx
	var points: PackedVector2Array = p.clone_points()
	assert_eq(points.size(), 4)
	var shown: int = 0
	for i: int in fx._clones.size():
		var c: AnimatedSprite2D = fx._clones[i]
		if not c.visible:
			continue
		shown += 1
		assert_not_null(c.sprite_frames, "clone %d has its sprite" % i)
		assert_gt(c.modulate.a, 0.0, "clone %d is opaque" % i)
		assert_true(c.global_position.is_equal_approx(points[i]), "sprite %d stands on its clone point" % i)
		# the ring paints at the clone's feet: block-local position + the block's origin = world feet
		var ring: Vector2 = fx._clone_ring_at(fx._clone_blocks[i], i)
		assert_true((ring + fx._clone_blocks[i].global_position).is_equal_approx(points[i] + Vector2(0.0, Player.FOOT_RING_Y)))
	assert_eq(shown, points.size(), "one drawn character per clone point")


func test_shadow_clones_ability_draws_characters_on_its_rings() -> void:
	var w: Array = _shade()
	await wait_physics_frames(2)
	_run(w[0], false)
	_check_drawn_as_characters(w[0])


func test_shadow_army_draws_characters_on_its_rings() -> void:
	var w: Array = _shade()
	await wait_physics_frames(2)
	_run(w[0], true)
	_check_drawn_as_characters(w[0])


func test_army_clone_shots_leave_the_drawn_hand_and_the_weapon_aims_along_them() -> void:
	var w: Array = _shade()
	var p: Player = w[0]
	var foe := Player.new()
	foe.setup(2, 1, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, w[1], 3, characters.get_character(&"flicker"))
	p.get_parent().add_child(foe)
	foe.global_position = Vector2(500, 420)
	w[1].targets.append(foe)
	await wait_physics_frames(2)
	_run(p, true)
	var shots: Array = []
	p.shot_fired.connect(func(_s: Player, seq: int, origin: Vector2, facing: Vector2, _id: StringName) -> void:
		shots.append([seq, origin, facing]))
	_frame(p, 500, true)
	var points: PackedVector2Array = p.clone_points()
	p._special_fx.sync(p)
	var clone_shots: int = 0
	for s: Array in shots:
		if s[0] < Player.CLONE_SEQ_OFFSET:
			continue
		clone_shots += 1
		var k: int = s[0] / Player.CLONE_SEQ_OFFSET - 1
		assert_true(s[1].is_equal_approx(points[k] + Player.hand_offset(s[2])), "clone %d fires from its hand" % k)
		assert_true(p._special_fx.clone_weapon_dir(k).is_equal_approx(s[2]), "clone %d's weapon aims along its shot" % k)
		p._special_fx._throw_age[k] = SpecialFx.CLONE_THROW_TIME  # relaxed
		assert_true(p._special_fx.clone_weapon_dir(k).is_equal_approx(Vector2.RIGHT) or p._special_fx.clone_weapon_dir(k).is_equal_approx(Vector2.LEFT))
	assert_eq(clone_shots, 4)
