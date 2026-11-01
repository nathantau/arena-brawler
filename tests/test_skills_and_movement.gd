extends GutTest
## Skills (shared dash, specials: barrier / Great Ape / ...) and movement integration.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var flicker: CharacterData
var warden: CharacterData
var twinshot: CharacterData
var skills: SkillCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	flicker = characters.get_character(&"flicker")
	warden = characters.get_character(&"warden")
	twinshot = characters.get_character(&"twinshot")
	skills = SkillCatalog.shared()


func test_catalog_and_skills() -> void:
	assert_eq(characters.ordered.size(), 7, "Gunnar and Warden are benched")
	assert_not_null(characters.get_character(&"warden"), "benched characters still load by id")
	for c: CharacterData in characters.ordered:
		assert_not_null(c.sprite_sheet, c.id)
		var cells: int = Constants.SPRITE_IDLE_FRAMES + Constants.SPRITE_HIT_FRAMES + Constants.SPRITE_WALK_FRAMES \
			+ Constants.SPRITE_DIE_FRAMES
		assert_eq(c.sprite_sheet.get_width(), cells * Constants.SPRITE_CELL_SIZE, "%s sheet has a death strip" % c.id)
		assert_eq(c.sprite_frames().get_frame_count(&"die"), Constants.SPRITE_DIE_FRAMES)
		assert_eq(c.portrait().get_size(), Constants.SPRITE_PORTRAIT_RECT.size)
		assert_true(c.max_hp > 0 and c.move_speed > 0.0, c.id)
		assert_ne(c.display_name, "")
		assert_false(skills.specials_for(c).is_empty(), "%s has a special" % c.id)
	assert_eq(characters.default_character(), flicker)
	assert_eq(characters.next_after(characters.ordered.back().id), characters.ordered[0], "wraps")
	var kinds: Array = []
	for id: StringName in [&"dash", &"barrier", &"great_ape", &"smoke_bomb",
			&"fan_of_blades", &"shadow_clones", &"blossom_ward", &"grapple_kunai", &"vine_swing", &"eruption", &"blossom_snare", &"staff_whirl", &"blaze_run", &"petal_drift", &"sky_pillar", &"flare_burst", &"cherry_sapling", &"storm_cloud", &"overdrive",
			&"shadow_step", &"gloom_hound", &"shadow_bind", &"bark_skin", &"verdant_bloom", &"leaf_gust", &"lightning_beam", &"thunder_strike"]:
		var sk: SkillData = skills.get_skill(id)
		assert_not_null(sk, String(id))
		assert_not_null(sk.icon, String(id))
		assert_true(sk.cooldown > 0.0 and sk.duration > 0.0, String(id))
		kinds.append(sk.kind)
	for kind: int in SkillData.Kind.values():
		assert_true(kinds.has(kind), "no skill of kind %d" % kind)


func test_dash_and_barrier_are_generic_specials() -> void:
	for id: StringName in [&"dash", &"barrier"]:
		var sk: SkillData = skills.get_skill(id)
		assert_true(sk.special, String(id))
		for c: CharacterData in characters.ordered:
			assert_true(skills.specials_for(c).has(sk), "%s for %s" % [id, c.id])


func test_signature_special_comes_first_and_is_exclusive() -> void:
	for c: CharacterData in characters.ordered:
		if c.signature_skill == null:
			continue
		assert_eq(skills.specials_for(c)[0], c.signature_skill, String(c.id))
	var ape: SkillData = skills.get_skill(&"great_ape")
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(ape), c.id == &"wukong", String(c.id))


func test_dash_grants_iframes_and_cooldown() -> void:
	var stats := PlayerStats.new()
	var skill := CharacterSkill.new(skills.dash())
	assert_true(skill.try_activate(Vector2(0, 2), Vector2.ZERO, stats))
	assert_true(skill.is_dashing())
	assert_eq(skill.direction, Vector2(0, 1))
	assert_true(stats.is_invulnerable())
	assert_almost_eq(stats.invulnerable_time, skills.dash().dash_iframes, 0.0001)


func test_skill_blocked_during_cooldown() -> void:
	var stats := PlayerStats.new()
	var dash: SkillData = skills.dash()
	var skill := CharacterSkill.new(dash)
	skill.try_activate(Vector2.RIGHT, Vector2.ZERO, stats)
	skill.tick(dash.duration + 0.01)
	assert_false(skill.is_active())
	assert_false(skill.try_activate(Vector2.RIGHT, Vector2.ZERO, stats))
	skill.tick(dash.cooldown)
	assert_true(skill.try_activate(Vector2.RIGHT, Vector2.ZERO, stats))


func test_skill_needs_direction() -> void:
	var skill := CharacterSkill.new(skills.dash())
	assert_false(skill.try_activate(Vector2.ZERO, Vector2.ZERO, PlayerStats.new()))


func test_barrier_is_placed_in_front_and_expires() -> void:
	var stats := PlayerStats.new()
	var barrier: SkillData = skills.get_skill(&"barrier")
	var skill := CharacterSkill.new(barrier)
	assert_true(skill.try_activate(Vector2.UP, Vector2(100, 100), stats))
	assert_true(skill.is_shielding())
	assert_false(skill.is_dashing())
	assert_false(stats.is_invulnerable(), "barrier gives no i-frames")
	assert_eq(skill.anchor, Vector2(100, 100) + Vector2.UP * barrier.shield_distance)
	skill.tick(barrier.duration + 0.01)
	assert_false(skill.is_shielding())


func test_dash_velocity_overrides_input() -> void:
	var skill := CharacterSkill.new(skills.dash())
	skill.try_activate(Vector2.LEFT, Vector2.ZERO, PlayerStats.new())
	var v: Vector2 = MovementSim.step_velocity(Vector2.ZERO, Vector2.RIGHT, skill, flicker.move_speed, DT)
	assert_eq(v, Vector2.LEFT * skills.dash().dash_speed)


func test_movement_accelerates_to_character_speed() -> void:
	for c: CharacterData in characters.ordered:
		var skill := CharacterSkill.new(skills.dash())
		var v := Vector2.ZERO
		for i: int in 120:
			v = MovementSim.step_velocity(v, Vector2.RIGHT, skill, c.move_speed, DT)
		assert_almost_eq(v.length(), c.move_speed, 0.001, c.id)


func test_move_input_is_clamped_to_unit_length() -> void:
	var skill := CharacterSkill.new(skills.dash())
	var v := Vector2.ZERO
	for i: int in 120:
		v = MovementSim.step_velocity(v, Vector2(5, 5), skill, flicker.move_speed, DT)
	assert_almost_eq(v.length(), flicker.move_speed, 0.001)


func test_movement_stops_without_input() -> void:
	var skill := CharacterSkill.new(skills.dash())
	var v := Vector2(flicker.move_speed, 0)
	for i: int in 60:
		v = MovementSim.step_velocity(v, Vector2.ZERO, skill, flicker.move_speed, DT)
	assert_eq(v, Vector2.ZERO)


func test_deadzone_ignored() -> void:
	var skill := CharacterSkill.new(skills.dash())
	var v: Vector2 = MovementSim.step_velocity(Vector2.ZERO, Vector2(Constants.INPUT_DEADZONE * 0.5, 0), skill,
		flicker.move_speed, DT)
	assert_eq(v, Vector2.ZERO)


func test_short_push_is_full_speed() -> void:
	var skill := CharacterSkill.new(skills.dash())
	var small := Vector2.ZERO
	var full := Vector2.ZERO
	for i: int in 60:
		small = MovementSim.step_velocity(small, Vector2(0, Constants.INPUT_DEADZONE * 1.5), skill, flicker.move_speed, DT)
		full = MovementSim.step_velocity(full, Vector2(0, 1), skill, flicker.move_speed, DT)
	assert_almost_eq(small.length(), flicker.move_speed, 0.01)
	assert_almost_eq(small, full, Vector2(0.01, 0.01))


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
	assert_eq(p.skills[1].data.id, &"barrier", "Warden's Barrier is kept")


# --- specials on a player ------------------------------------------------------

func _player(c: CharacterData) -> Player:
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, null, 0, c)
	add_child_autofree(p)
	return p


func test_great_ape_halves_damage_and_swaps_to_fists() -> void:
	var p: Player = _player(characters.get_character(&"wukong"))
	var ape: SkillData = skills.get_skill(&"great_ape")
	assert_eq(p.skills[1].data, ape, "Wukong's signature special")
	assert_ne(p.held_weapon().data.id, &"ape_fists")
	assert_true(p.skills[1].try_activate(Vector2.RIGHT, Vector2.ZERO, p.stats))
	assert_eq(p.held_weapon().data.id, &"ape_fists")
	assert_eq(ape.form_frames().get_frame_count(&"attack"), Constants.SPRITE_ATTACK_FRAMES, "fists swing")
	assert_false(p.character.sprite_frames().has_animation(&"attack"), "no attack strip on plain sheets")
	var before: int = p.stats.hp + p.stats.armor
	p.take_hit(40, false, Vector2.ZERO, 2)
	assert_eq(before - (p.stats.hp + p.stats.armor), roundi(40 * ape.form_damage_scale))
	p.skills[1].tick(ape.duration + 0.01)
	assert_false(p.skills[1].is_transformed())
	assert_ne(p.held_weapon().data.id, &"ape_fists", "back to the loadout")


func test_switching_character_keeps_usable_specials() -> void:
	var p: Player = _player(flicker)
	assert_eq(p.skills[0].data, skills.dash(), "Dash on the skill button by default")
	assert_eq(p.skills[1].data.id, &"shadow_clones", "signature on the special button")
	p.set_skill(0, skills.get_skill(&"barrier"))
	p.set_character(characters.get_character(&"wukong"))
	assert_eq(p.skills[0].data.id, &"barrier", "generic: kept")
	assert_eq(p.skills[1].data.id, &"great_ape", "Flicker-only: replaced by the default")


func test_set_skill_swaps_instead_of_doubling() -> void:
	var p: Player = _player(flicker)
	p.set_skill(0, p.skills[1].data)
	assert_eq(p.skills[0].data.id, &"shadow_clones")
	assert_eq(p.skills[1].data, skills.dash())



# --- Flicker's ninja specials ------------------------------------------------------

## A wall as the arena builds one: the wall itself plus its players-only copy shifted to the feet.
func _wall(world: Node2D, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.add_child(Arena.feet_strip([Rect2(-size * 0.5, size)] as Array[Rect2]))
	body.position = center
	world.add_child(body)


func _flicker_in(world: Node2D, special: StringName, pool: ProjectilePool = null) -> Player:
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3, flicker)
	world.add_child(p)
	p.set_skill(1, skills.get_skill(special))
	return p


func _press_special(p: Player, aim: Vector2, move: Vector2 = Vector2.ZERO) -> void:
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = aim
	f.move_vec = move
	f.special = true
	p.simulate(f, DT)


func test_flicker_can_pick_all_ninja_specials() -> void:
	var ids: Array[StringName] = []
	for sk: SkillData in skills.specials_for(flicker):
		ids.append(sk.id)
	assert_eq(ids[0], &"shadow_clones", "signature first")
	for id: StringName in [&"smoke_bomb", &"fan_of_blades", &"grapple_kunai"]:
		assert_has(ids, id)
	assert_false(ids.has(&"blink"), "Blink was cut from her kit")
	for c: CharacterData in [warden, twinshot]:
		assert_false(c.can_use_skill(skills.get_skill(&"smoke_bomb")), String(c.id))


func test_smoke_hides_only_inside_the_cloud() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var p: Player = _flicker_in(world, &"smoke_bomb")
	p.global_position = Vector2(200, 200)
	assert_false(p.is_hidden())
	_press_special(p, Vector2.RIGHT)
	assert_true(p.is_hidden())
	p.global_position += Vector2(skills.get_skill(&"smoke_bomb").smoke_radius + 5.0, 0)
	assert_false(p.is_hidden(), "stepped out of the smoke")


func test_shadow_clones_run_out_and_stop_at_walls() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	_wall(world, Vector2(300, 200), Vector2(20, 600))
	var p: Player = _flicker_in(world, &"shadow_clones")
	p.global_position = Vector2(150, 200)
	await wait_physics_frames(2)
	assert_eq(p.clone_points().size(), 0)
	_press_special(p, Vector2.RIGHT)
	p.skills[1].active_remaining -= 2.0  # two seconds in
	var points: PackedVector2Array = p.clone_points()
	assert_eq(points.size(), skills.get_skill(&"shadow_clones").clone_count)
	for c: Vector2 in points:
		assert_lt(c.x, 300.0, "clones don't run through walls")
		assert_gt(c.distance_to(Vector2(150, 200)), 50.0, "clones moved away")
	assert_eq(p.clone_points(), points, "deterministic: same state, same clones")


func test_shadow_clones_stay_in_when_cast_from_under_a_wall() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	_wall(world, Vector2(300, 0), Vector2(800, 48))  # like the arena's top border: spans y -24..24
	var p: Player = _flicker_in(world, &"shadow_clones")
	p.global_position = Vector2(300, 400)
	await wait_physics_frames(2)
	for i: int in 120:  # walk up until pressed against it: the centre ends up inside the wall
		p.velocity = Vector2(0, -400)
		p.move_and_slide()
	assert_lt(p.global_position.y, 24.0, "feet-based collision lets the centre into the wall")
	_press_special(p, Vector2.UP)
	p.skills[1].active_remaining -= 2.0
	for c: Vector2 in p.clone_points():
		assert_gt(c.y, p.global_position.y - 1.0, "clones don't run up through the wall: %s" % c)


## Runs idle frames until the grapple pull is over (or `limit` frames pass).
func _until_pulled(p: Player, limit: int = 120) -> void:
	var idle := InputFrame.new()
	for i: int in limit:
		if not p.skills[1].is_active():
			return
		idle.seq = 11 + i
		p.simulate(idle, DT)


func test_grapple_zips_to_a_wall_and_stops_short() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	_wall(world, Vector2(500, 300), Vector2(20, 400))  # left face at x 490, inside the 420 range from x 200
	var p: Player = _flicker_in(world, &"grapple_kunai")
	p.global_position = Vector2(200, 300)
	await wait_physics_frames(2)
	var sk: SkillData = skills.get_skill(&"grapple_kunai")
	_press_special(p, Vector2.RIGHT)
	assert_true(p.skills[1].is_active(), "bit the wall")
	assert_almost_eq(p.skills[1].cooldown_remaining, sk.cooldown, 0.001, "a bite charges the full cooldown")
	assert_eq(p.global_position, Vector2(200, 300), "held still while the kunai bites")
	_until_pulled(p)
	assert_false(p.skills[1].is_active(), "the pull ends on arrival")
	var stop: float = 490.0 - Constants.PLAYER_RADIUS - Constants.GRAPPLE_STANDOFF
	assert_almost_eq(p.global_position.x, stop, 1.0, "stops just short of the wall")
	assert_almost_eq(p.global_position.y, 300.0, 0.01, "straight along the aim")
	assert_eq(p.velocity, Vector2.ZERO, "no slide after the pull")


func test_grapple_miss_does_not_move_and_charges_short_cooldown() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	_wall(world, Vector2(700, 300), Vector2(20, 400))  # 490 px away: out of range
	var p: Player = _flicker_in(world, &"grapple_kunai")
	p.global_position = Vector2(200, 300)
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	assert_false(p.skills[1].is_active())
	assert_almost_eq(p.skills[1].cooldown_remaining, skills.get_skill(&"grapple_kunai").grapple_miss_cooldown, 0.001)
	_until_pulled(p, 30)
	assert_eq(p.global_position, Vector2(200, 300), "didn't move")


func test_grapple_wall_on_the_way_stops_the_pull() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	_wall(world, Vector2(500, 300), Vector2(20, 400))
	# A crate the aim line passes beside, but her body clips: its feet strip spans y 310..330.
	_wall(world, Vector2(350, 342), Vector2(40, 20))
	var p: Player = _flicker_in(world, &"grapple_kunai")
	p.global_position = Vector2(200, 300)
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	assert_true(p.skills[1].is_active(), "the kunai flew past the crate and bit the wall")
	_until_pulled(p)
	assert_false(p.skills[1].is_active())
	assert_between(p.global_position.x, 250.0, 335.0, "stopped at the crate")


func test_grapple_never_ends_inside_walls_or_outside_the_arena() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	# A 400 px box like the arena border (inside: 100..500), with a crate in the middle of one side.
	_wall(world, Vector2(300, 80), Vector2(480, 40))
	_wall(world, Vector2(300, 520), Vector2(480, 40))
	_wall(world, Vector2(80, 300), Vector2(40, 480))
	_wall(world, Vector2(520, 300), Vector2(40, 480))
	_wall(world, Vector2(420, 300), Vector2(48, 48))
	var p: Player = _flicker_in(world, &"grapple_kunai")
	await wait_physics_frames(2)
	var circle := CircleShape2D.new()
	circle.radius = Constants.PLAYER_RADIUS - 0.5
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = circle
	q.collision_mask = Constants.LAYER_WALL_FEET
	for start: Vector2 in [Vector2(300, 300), Vector2(150, 150), Vector2(330, 460)]:
		for k: int in 16:
			p.global_position = start
			p.skills[1].reset()
			var aim: Vector2 = Vector2.RIGHT.rotated(TAU * k / 16.0)
			_press_special(p, aim)
			_until_pulled(p)
			q.transform = Transform2D(0.0, p.global_position)
			var where: String = "from %s aiming %s: ended at %s" % [start, aim, p.global_position]
			assert_eq(world.get_world_2d().direct_space_state.intersect_shape(q).size(), 0, "not in a wall " + where)
			assert_true(Rect2(100, 100 - Constants.WALL_FEET_STRIP, 400, 400).has_point(p.global_position),
				"inside the arena " + where)


func test_fan_of_blades_fires_a_ring() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p: Player = _flicker_in(world, &"fan_of_blades", pool)
	p.global_position = Vector2(500, 500)
	await wait_physics_frames(1)
	_press_special(p, Vector2.RIGHT)
	assert_eq(pool.active_count(), skills.get_skill(&"fan_of_blades").volley_weapon.pellets)
	var spread := Rect2(p.global_position, Vector2.ZERO)
	for sl: ProjectilePool.Slot in pool.debug_slots():
		if sl.active:
			spread = spread.expand(sl.pos + sl.vel)
	assert_true(spread.size.x > 400.0 and spread.size.y > 400.0, "blades fly every way")


func test_ape_slam_lands_after_its_windup() -> void:
	var p: Player = _player(characters.get_character(&"wukong"))
	p.projectiles = ProjectilePool.new()
	add_child_autofree(p.projectiles)
	assert_true(p.skills[1].try_activate(Vector2.RIGHT, Vector2.ZERO, p.stats))
	watch_signals(p)
	var fire := InputFrame.new()
	fire.fire = true
	var windup: float = p.held_weapon().data.windup
	assert_gt(windup, 0.0)
	p.simulate(fire, Constants.PHYSICS_DT)
	assert_signal_not_emitted(p, "shot_fired", "fists still going up")
	var idle := InputFrame.new()
	for i: int in ceili(windup / Constants.PHYSICS_DT) + 1:  # +1: float steps may leave a sliver
		p.simulate(idle, Constants.PHYSICS_DT)
	assert_signal_emit_count(p, "shot_fired", 1, "lands when the fists come down")



func test_flint_inferno_fires_beams() -> void:
	var flint: CharacterData = characters.get_character(&"flint")
	var inferno: SkillData = flint.signature_skill
	assert_eq(inferno.kind, SkillData.Kind.TRANSFORM)
	assert_eq(inferno.form_weapon.kind, WeaponData.Kind.BEAM)
	assert_lt(inferno.form_weapon.muzzle_distance(), 8.0, "the beam starts at his fist, not out in the air")
	assert_not_null(inferno.form_frames(), "Inferno sheet loads")
	assert_true(flint.can_use_skill(skills.get_skill(&"supernova")), "Supernova stays pickable")


func test_blossom_ward_is_sakuras_and_expires() -> void:
	var ward: SkillData = skills.get_skill(&"blossom_ward")
	var sakura: CharacterData = characters.get_character(&"sakura")
	assert_eq(ward.kind, SkillData.Kind.WARD)
	assert_true(skills.specials_for(sakura).has(ward))
	assert_false(flicker.can_use_skill(ward))
	var stats := PlayerStats.new()
	var skill := CharacterSkill.new(ward)
	assert_true(skill.try_activate(Vector2.RIGHT, Vector2.ZERO, stats))
	assert_true(skill.is_warding())
	assert_false(stats.is_invulnerable(), "no i-frames")
	skill.tick(ward.duration + 0.01)
	assert_false(skill.is_warding(), "expired")
	assert_false(skill.try_activate(Vector2.RIGHT, Vector2.ZERO, stats), "on cooldown")


# --- Apex's Vine Swing ------------------------------------------------------

const SWING_FROM: Vector2 = Vector2(150, 300)


func _swinger(world: Node2D) -> Player:
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, null, 3,
		characters.get_character(&"wukong"))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(&"vine_swing"))
	p.global_position = SWING_FROM
	return p


func _swing_world() -> Node2D:
	var world := Node2D.new()
	add_child_autofree(world)
	return world


## Press, then hold still until the swing is over; returns where it was headed.
func _swing(p: Player, aim: Vector2) -> Vector2:
	_press_special(p, aim)
	var landing: Vector2 = p.skills[1].anchor + p.skills[1].direction
	var idle := InputFrame.new()
	idle.aim_vec = aim
	for i: int in ceili(p.skills[1].data.duration / DT) + 1:
		p.simulate(idle, DT)
	return landing


func _fits(p: Player, at: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Constants.PLAYER_RADIUS
	q.shape = circle
	q.collision_mask = Constants.LAYER_WALL_FEET
	q.transform = Transform2D(0.0, at)
	return p.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func test_vine_swing_is_apex_only() -> void:
	var sw: SkillData = skills.get_skill(&"vine_swing")
	assert_eq(sw.kind, SkillData.Kind.SWING)
	assert_eq(int(SkillData.Kind.SWING), 7)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(sw), c.id == &"wukong", String(c.id))


func test_vine_swing_lands_past_a_wall_that_blocks_walking() -> void:
	var world: Node2D = _swing_world()
	_wall(world, Vector2(300, 300), Vector2(24, 800))
	var walker: Player = _swinger(world)
	await wait_physics_frames(2)
	for i: int in 120:
		walker.velocity = Vector2(400, 0)
		walker.move_and_slide()
	assert_lt(walker.global_position.x, 300.0, "walking is blocked")
	walker.global_position = SWING_FROM
	var sw: SkillData = walker.skills[1].data
	var landing: Vector2 = _swing(walker, Vector2.RIGHT)
	assert_almost_eq(landing.x, SWING_FROM.x + sw.swing_range, 0.01, "nothing in the way at full range")
	assert_eq(walker.global_position, landing, "landed exactly on the spot")
	assert_gt(walker.global_position.x, 300.0 + Constants.PLAYER_RADIUS, "over the wall")
	assert_false(walker.skills[1].is_active())
	assert_gt(walker.skills[1].cooldown_remaining, 0.0)
	assert_eq(walker.velocity, Vector2.ZERO)


func test_vine_swing_goes_up_and_over_mid_flight() -> void:
	var world: Node2D = _swing_world()
	var p: Player = _swinger(world)
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	assert_true(p.stats.is_invulnerable(), "i-frames at takeoff")
	var idle := InputFrame.new()
	for i: int in 20:
		p.simulate(idle, DT)
	assert_false(p.stats.is_invulnerable(), "hittable in the air")
	assert_true(p.skills[1].is_active())
	var x: float = p.global_position.x
	assert_true(x > SWING_FROM.x + 40.0 and x < SWING_FROM.x + 320.0, "partway: %s" % x)


func test_vine_swing_never_lands_in_walls_or_crates() -> void:
	var world: Node2D = _swing_world()
	_wall(world, Vector2(480, 300), Vector2(200, 200))  # covers the full-range spot (510)
	var crate := Crate.new()
	crate.setup(0, Vector2(150, 660), Constants.TILE_SIZE)  # straight down, at the full-range spot
	world.add_child(crate)
	var p: Player = _swinger(world)
	await wait_physics_frames(2)
	var landing: Vector2 = _swing(p, Vector2.RIGHT)
	assert_lt(landing.x, 380.0 - Constants.PLAYER_RADIUS + 0.01, "short of the wall")
	assert_gt(landing.x, SWING_FROM.x + 150.0, "as far as it fits")
	assert_true(_fits(p, landing))
	p.skills[1].reset()
	p.global_position = SWING_FROM
	landing = _swing(p, Vector2.DOWN)
	assert_true(_fits(p, landing), "not in the crate: %s" % landing)
	assert_lt(landing.y, 660.0, "stopped short of the crate")
	assert_gt(landing.y, SWING_FROM.y + 200.0)


func test_vine_swing_stays_inside_the_arena() -> void:
	var world: Node2D = _swing_world()
	var p: Player = _swinger(world)
	p.arena_bounds = Rect2(48, 48, 352, 504)  # right border wall starts at x 400
	await wait_physics_frames(2)
	var landing: Vector2 = _swing(p, Vector2(1, -0.2))
	assert_true(p.arena_bounds.grow(-Constants.PLAYER_RADIUS + 0.01).has_point(landing), "inside: %s" % landing)
	assert_gt(landing.x, 300.0, "still swung as far as the border allows")


func test_vine_swing_without_a_landing_does_nothing() -> void:
	var world: Node2D = _swing_world()
	_wall(world, Vector2(380, 300), Vector2(360, 800))  # x 200..560: every spot from 80 to 360 px out is inside it
	var p: Player = _swinger(world)
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	assert_false(p.skills[1].is_active(), "no swing")
	assert_eq(p.skills[1].cooldown_remaining, 0.0, "no cooldown spent")
	assert_false(p.stats.is_invulnerable())
	assert_eq(p.global_position, SWING_FROM)


func test_vine_swing_replay_from_captured_state_matches() -> void:
	var world: Node2D = _swing_world()
	_wall(world, Vector2(300, 300), Vector2(24, 800))
	_wall(world, Vector2(480, 300), Vector2(60, 60))
	var a: Player = _swinger(world)
	var b: Player = _swinger(world)
	b.player_id = 2
	await wait_physics_frames(2)
	var catalog := WeaponCatalog.load_all()
	var inputs: Array[InputFrame] = []
	for i: int in 60:
		var f := InputFrame.new()
		f.seq = i + 1
		f.aim_vec = Vector2(1, 0.3)
		f.move_vec = Vector2(0, 1) if i > 45 else Vector2.ZERO
		f.special = i >= 5 and i < 8
		inputs.append(f)
	# From before the press (b recomputes the landing) and from mid-swing (b takes it from the snapshot).
	for cut: int in [2, 15]:
		a.global_position = SWING_FROM
		a.skills[1].reset()
		var snapshot: Array = []
		for i: int in inputs.size():
			a.simulate(inputs[i], DT)
			if i == cut:
				snapshot = a.capture_state()
		assert_true(b.apply_state(snapshot, catalog, characters))
		for i: int in range(cut + 1, inputs.size()):
			b.simulate(inputs[i], DT, true)
		assert_gt(a.global_position.x, 300.0, "a swung over the wall")
		assert_almost_eq(b.global_position, a.global_position, Vector2(0.01, 0.01), "cut %d" % cut)
		assert_eq(b.skills[1].anchor, a.skills[1].anchor)
		assert_eq(b.skills[1].direction, a.skills[1].direction)
		assert_almost_eq(b.skills[1].cooldown_remaining, a.skills[1].cooldown_remaining, 0.0001)


# --- Flint's Eruption --------------------------------------------------------------

func _flint_erupter(world: Node2D, pool: ProjectilePool, id: int = 1) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"flint"))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(&"eruption"))
	return p


func _idle(p: Player, frames: int, replay: bool = false) -> void:
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 100 + i
		p.simulate(f, DT, replay)


func _hits(pool: ProjectilePool) -> Array:
	var hits: Array = []
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, victim: int, dmg: int, _c: bool, _a: Vector2) -> void:
		hits.append([victim, dmg]))
	return hits


func test_eruption_is_flints_own() -> void:
	var eruption: SkillData = skills.get_skill(&"eruption")
	assert_eq(eruption.kind, SkillData.Kind.ERUPTION)
	assert_true(eruption.eruption_blast.blast)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(eruption), c.id == &"flint", String(c.id))


func test_eruption_spot_is_ahead_and_stops_at_walls() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var p: Player = _flint_erupter(world, null)
	var d: SkillData = skills.get_skill(&"eruption")
	p.global_position = Vector2(100, 300)
	await wait_physics_frames(2)
	var feet := Vector2(100, 300 + Constants.WALL_FEET_STRIP)
	assert_almost_eq(p.eruption_spot(Vector2.RIGHT, d), feet + Vector2(d.eruption_distance, 0), Vector2(0.01, 0.01))
	_wall(world, Vector2(250, 300), Vector2(20, 400))
	await wait_physics_frames(2)
	var spot: Vector2 = p.eruption_spot(Vector2.RIGHT, d)
	assert_almost_eq(spot.x, 240.0 - d.eruption_wall_margin, 0.5, "pulled back off the wall")
	assert_eq(p.eruption_spot(Vector2.RIGHT, d), spot, "deterministic")


func test_eruption_spot_stays_in_when_cast_from_under_a_wall() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	_wall(world, Vector2(300, 0), Vector2(800, 48))  # spans y -24..24
	var p: Player = _flint_erupter(world, null)
	p.global_position = Vector2(300, 400)
	await wait_physics_frames(2)
	for i: int in 120:
		p.velocity = Vector2(0, -400)
		p.move_and_slide()
	assert_lt(p.global_position.y, 24.0, "centre inside the wall")
	var spot: Vector2 = p.eruption_spot(Vector2.UP, skills.get_skill(&"eruption"))
	assert_gt(spot.y, 24.0, "not beyond the wall: %s" % spot)


func test_eruption_lands_only_after_the_telegraph() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p: Player = _flint_erupter(world, pool)
	p.global_position = Vector2(100, 300)
	var d: SkillData = skills.get_skill(&"eruption")
	var target: Player = _flint_erupter(world, pool, 2)
	target.global_position = Vector2(100 + d.eruption_distance, 300)
	await wait_physics_frames(2)
	var hits: Array = _hits(pool)
	_press_special(p, Vector2.RIGHT)
	assert_true(p.skills[1].is_active(), "telegraph showing")
	_idle(p, floori(d.duration / DT) - 2)
	assert_eq(hits.size(), 0, "nothing before the delay")
	_idle(p, 4)
	assert_eq(hits.size(), 1, "erupts once")
	assert_eq(hits[0][0], 2)
	assert_gt(hits[0][1], d.eruption_blast.damage * 0.9, "dead centre: near full damage")
	assert_lt(target.velocity.y, 0.0, "knocked up")
	assert_eq(p.stats.hp, p.stats.max_hp)


func test_eruption_falls_off_walls_block_it_and_spares_the_caster() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var blast: WeaponData = skills.get_skill(&"eruption").eruption_blast
	var caster: Player = _flint_erupter(world, pool, 1)
	caster.global_position = Vector2(500, 300)
	var near: Player = _flint_erupter(world, pool, 2)
	near.global_position = Vector2(510, 300)
	var far: Player = _flint_erupter(world, pool, 3)
	far.global_position = Vector2(500 - blast.splash_radius * 0.8, 300)
	var hidden: Player = _flint_erupter(world, pool, 4)
	hidden.global_position = Vector2(500, 300 + blast.splash_radius * 0.7)
	_wall(world, Vector2(500, 300 + blast.splash_radius * 0.4), Vector2(200, 12))
	await wait_physics_frames(2)
	var dmg: Dictionary = {}
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, victim: int, d: int, _c: bool, _a: Vector2) -> void:
		dmg[victim] = d)
	pool.fire_shot(1, 7, caster.global_position, Vector2.RIGHT, blast, 3)
	assert_false(dmg.has(1), "no self-damage")
	assert_true(dmg.has(2) and dmg.has(3))
	assert_gt(dmg[2], dmg[3], "falloff")
	assert_false(dmg.has(4), "the wall blocks it")
	assert_eq(pool.active_count(), 0, "a blast leaves nothing flying")


func test_eruption_replay_matches_and_spawns_nothing() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	_wall(world, Vector2(250, 300), Vector2(20, 400))
	var a: Player = _flint_erupter(world, pool, 1)
	var b: Player = _flint_erupter(world, pool, 2)
	a.global_position = Vector2(100, 300)
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	var booms: Array = []
	pool.exploded.connect(func(at: Vector2, _r: float, _c: Color, _s: bool, _art: bool) -> void: booms.append(at))
	_press_special(a, Vector2.RIGHT)
	_idle(a, 60)
	assert_eq(booms.size(), 1, "the server's eruption")
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	b.simulate(f, DT, true)
	assert_eq(b.skills[1].anchor, a.skills[1].anchor, "same spot")
	_idle(b, 60, true)
	assert_eq(booms.size(), 1, "replay spawns nothing")
	assert_almost_eq(b.skills[1].cooldown_remaining, a.skills[1].cooldown_remaining, 0.0001)
	assert_lt(booms[0].x, 250.0, "erupted short of the wall")


# --- Sakura's Blossom Snare --------------------------------------------------------

func _sakura(world: Node2D, pool: ProjectilePool, id: int, at: Vector2) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"sakura"))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(&"blossom_snare"))
	p.global_position = at
	return p


func _run(p: Player, frames: int, move: Vector2) -> float:
	var x0: float = p.global_position.x
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 200 + i
		f.move_vec = move
		p.simulate(f, DT)
	return p.global_position.x - x0


func test_blossom_snare_is_sakuras_own() -> void:
	var d: SkillData = skills.get_skill(&"blossom_snare")
	assert_eq(d.kind, SkillData.Kind.SNARE)
	assert_eq(int(d.kind), 13)
	assert_gt(d.volley_weapon.snare_time, 0.0)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(d), c.id == &"sakura", String(c.id))


func test_blossom_snare_hit_damages_and_slows() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var a: Player = _sakura(world, pool, 1, Vector2(100, 300))
	var b: Player = _sakura(world, pool, 2, Vector2(400, 300))
	await wait_physics_frames(2)
	var base: float = _run(b, 30, Vector2.RIGHT)
	b.global_position = Vector2(400, 300)
	b.velocity = Vector2.ZERO
	b.skills[1].reset()
	var hp: int = b.stats.hp + b.stats.armor
	_press_special(a, Vector2.RIGHT)
	var w: WeaponData = skills.get_skill(&"blossom_snare").volley_weapon
	for i: int in 90:
		await wait_physics_frames(1)
		if b.stats.slow_remaining > 0.0:
			break
	assert_gt(b.stats.slow_remaining, 0.0, "the blossom landed")
	assert_eq(hp - (b.stats.hp + b.stats.armor), w.damage)
	assert_eq(b.stats.slow_factor, w.snare_factor)
	b.global_position = Vector2(400, 300)
	b.velocity = Vector2.ZERO
	var slowed: float = _run(b, 30, Vector2.RIGHT)
	assert_lt(slowed, base * 0.75, "slowed %.1f vs %.1f" % [slowed, base])
	assert_eq(a.stats.slow_remaining, 0.0, "not herself")


func test_snare_expires_refreshes_and_clears_on_respawn() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var p: Player = _sakura(world, null, 1, Vector2(100, 300))
	await wait_physics_frames(2)
	p.stats.apply_slow(0.5, 0.45)
	assert_almost_eq(p.stats.speed_scale(), 0.45, 0.0001)
	_idle(p, 20)
	p.stats.apply_slow(0.5, 0.45)
	assert_almost_eq(p.stats.slow_remaining, 0.5, 0.0001, "refreshed, not stacked")
	_idle(p, 31)
	assert_eq(p.stats.slow_remaining, 0.0)
	assert_eq(p.stats.speed_scale(), 1.0, "expired")
	p.stats.apply_slow(5.0, 0.45)
	p.respawn(Vector2(100, 300))
	assert_eq(p.stats.speed_scale(), 1.0, "respawn clears it")


func test_own_snare_shot_does_not_snare_the_caster() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var a: Player = _sakura(world, pool, 1, Vector2(100, 300))
	await wait_physics_frames(2)
	pool.fire_shot(1, 5, a.global_position, Vector2.RIGHT, skills.get_skill(&"blossom_snare").volley_weapon, 3)
	await wait_physics_frames(10)
	assert_eq(a.stats.slow_remaining, 0.0)
	assert_eq(a.stats.hp, a.stats.max_hp)


# --- Apex's Staff Whirl -----------------------------------------------------

func _whirler(world: Node2D, pool: ProjectilePool, id: int = 1, at: Vector2 = Vector2(300, 300)) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"wukong"))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(&"staff_whirl"))
	p.global_position = at
	return p


func _whirl_world() -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	return [world, pool]


func test_staff_whirl_is_apexs_own() -> void:
	var d: SkillData = skills.get_skill(&"staff_whirl")
	assert_eq(d.kind, SkillData.Kind.WHIRL)
	assert_eq(int(SkillData.Kind.WHIRL), 11)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(d), c.id == &"wukong", String(c.id))


func test_staff_whirl_damages_in_range_on_ticks_only() -> void:
	var w: Array = _whirl_world()
	var d: SkillData = skills.get_skill(&"staff_whirl")
	var p: Player = _whirler(w[0], w[1])
	var near: Player = _whirler(w[0], w[1], 2, Vector2(300 + d.whirl_radius * 0.6, 300))
	var far: Player = _whirler(w[0], w[1], 3, Vector2(300 + d.whirl_radius + 60.0, 300))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press_special(p, Vector2.RIGHT)
	assert_eq(hits.size(), 1, "first tick on the press")
	assert_eq(hits[0], [2, d.whirl_damage])
	assert_gt(near.velocity.x, 0.0, "pushed outward")
	_idle(p, 5)
	assert_eq(hits.size(), 1, "nothing between ticks")
	_idle(p, ceili(d.whirl_interval / DT))
	assert_eq(hits.size(), 2, "next tick")
	assert_eq(far.stats.hp, far.stats.max_hp, "out of range")
	assert_eq(p.stats.hp, p.stats.max_hp, "not himself")
	assert_eq(p.stats.armor, p.stats.max_armor)


func test_staff_whirl_reflects_enemy_projectiles() -> void:
	var w: Array = _whirl_world()
	var pool: ProjectilePool = w[1]
	var p: Player = _whirler(w[0], pool)
	await wait_physics_frames(2)
	var blaster: WeaponData = WeaponCatalog.load_all().get_weapon(&"pistol")
	pool.fire_shot(2, 5, Vector2(300 + 150, 300), Vector2.LEFT, blaster, 3)
	var slot: ProjectilePool.Slot = null
	for s: ProjectilePool.Slot in pool.debug_slots():
		if s.active:
			slot = s
	assert_not_null(slot)
	slot.pos = Vector2(300 + 40, 300)  # inside the spin
	assert_lt(slot.vel.x, 0.0)
	_press_special(p, Vector2.RIGHT)
	assert_gt(slot.vel.x, 0.0, "sent back")
	assert_eq(slot.attacker_id, 1, "now his")


func test_staff_whirl_slows_blocks_firing_and_expires() -> void:
	var w: Array = _whirl_world()
	var d: SkillData = skills.get_skill(&"staff_whirl")
	var p: Player = _whirler(w[0], w[1])
	var q: Player = _whirler(w[0], w[1], 2, Vector2(300, 600))
	await wait_physics_frames(2)
	var go := InputFrame.new()
	go.move_vec = Vector2.RIGHT
	for i: int in 30:  # q walks normally
		q.simulate(go, DT)
	var normal: float = q.velocity.x
	watch_signals(p)
	var f := InputFrame.new()
	f.seq = 10
	f.special = true
	f.fire = true
	f.move_vec = Vector2.RIGHT
	f.aim_vec = Vector2.RIGHT
	p.simulate(f, DT)
	f.special = false
	for i: int in 30:
		p.simulate(f, DT)
	assert_almost_eq(p.velocity.x, normal * d.whirl_speed_scale, 1.0, "slower")
	assert_signal_not_emitted(p, "shot_fired", "no shots while spinning")
	for i: int in ceili(d.duration / DT) + 2:
		p.simulate(go, DT)
	assert_false(p.skills[1].is_active(), "ran out")
	assert_gt(p.skills[1].cooldown_remaining, 0.0)
	for i: int in ceili(p.held_weapon().data.windup / DT) + 2:  # the staff's stab winds up first
		p.simulate(f, DT)
	assert_signal_emitted(p, "shot_fired", "can fire again")


func test_staff_whirl_replay_matches_and_hurts_nobody() -> void:
	var w: Array = _whirl_world()
	var a: Player = _whirler(w[0], w[1])
	var b: Player = _whirler(w[0], w[1], 2, Vector2(100, 100))
	var victim: Player = _whirler(w[0], w[1], 3, Vector2(330, 300))
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	var f := InputFrame.new()
	f.seq = 10
	f.special = true
	f.move_vec = Vector2.RIGHT
	a.simulate(f, DT)
	var health: int = victim.stats.hp + victim.stats.armor
	assert_lt(health, victim.stats.max_hp + victim.stats.max_armor, "a hurt him")
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	b.simulate(f, DT, true)
	f.special = false
	for i: int in 40:
		b.simulate(f, DT, true)
	assert_eq(victim.stats.hp + victim.stats.armor, health, "replay damages nobody")
	for i: int in 40:
		a.simulate(f, DT)
	assert_almost_eq(b.global_position, a.global_position, Vector2(0.01, 0.01))
	assert_almost_eq(b.skills[1].active_remaining, a.skills[1].active_remaining, 0.0001)
	assert_almost_eq(b.skills[1].cooldown_remaining, a.skills[1].cooldown_remaining, 0.0001)


# --- Flint's Blaze Run --------------------------------------------------------------

func _blaze_runner(world: Node2D, pool: ProjectilePool, id: int = 1) -> Player:
	var p: Player = _flint_erupter(world, pool, id)
	p.set_skill(1, skills.get_skill(&"blaze_run"))
	return p


func _blaze_setup(walls: bool = false) -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	if walls:
		_wall(world, Vector2(250, 300), Vector2(20, 400))
	var p: Player = _blaze_runner(world, pool, 1)
	p.global_position = Vector2(100, 300)
	var foe: Player = _blaze_runner(world, pool, 2)
	foe.global_position = Vector2(200, 700)
	pool.targets.append(p)
	pool.targets.append(foe)
	return [world, pool, p, foe]


func test_blaze_run_is_flints_own_trail() -> void:
	var d: SkillData = skills.get_skill(&"blaze_run")
	assert_eq(d.kind, SkillData.Kind.TRAIL)
	assert_eq(int(d.kind), 12)
	assert_gt(d.duration, d.trail_dash_time, "the trail outlives the dash")
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(d), c.id == &"flint", String(c.id))


func test_blaze_run_dashes_and_trail_follows_the_path() -> void:
	var s: Array = _blaze_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"blaze_run")
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	var slot: CharacterSkill = p.skills[1]
	assert_eq(slot.anchor, Vector2(100, 300))
	assert_almost_eq(slot.direction, Vector2(d.trail_distance, 0), Vector2(0.1, 0.1))
	_idle(p, floori(d.trail_dash_time / DT) + 2)
	assert_almost_eq(p.global_position, Vector2(100 + d.trail_distance, 300), Vector2(0.5, 0.5))
	assert_true(slot.is_active(), "the trail is still burning")


func test_blaze_run_stops_at_walls_and_trail_ends_there() -> void:
	var s: Array = _blaze_setup(true)
	var p: Player = s[2]
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	var slot: CharacterSkill = p.skills[1]
	var end: Vector2 = slot.anchor + slot.direction
	assert_lt(end.x, 250.0, "short of the wall")
	assert_lt(slot.direction.length(), 300.0)
	_idle(p, 30)
	assert_almost_eq(p.global_position, end, Vector2(0.5, 0.5), "he stops where the trail stops")


func test_blaze_run_burns_enemies_in_the_trail_on_ticks_not_outside_or_the_caster() -> void:
	var s: Array = _blaze_setup()
	var pool: ProjectilePool = s[1]
	var p: Player = s[2]
	var foe: Player = s[3]
	var d: SkillData = skills.get_skill(&"blaze_run")
	foe.global_position = Vector2(220, 300 + d.trail_radius - 2.0)  # on the edge of the line
	var safe: Player = _blaze_runner(s[0], pool, 3)
	safe.global_position = Vector2(220, 300 + d.trail_radius + 6.0)  # just outside
	pool.targets.append(safe)
	await wait_physics_frames(2)
	var hits: Array = _hits(pool)
	_press_special(p, Vector2.RIGHT)
	var hp0: int = foe.stats.hp + foe.stats.armor
	_idle(p, floori(d.trail_tick / DT) - 3)
	assert_eq(hits.size(), 0, "no damage before the first tick")
	_idle(p, 6)
	assert_eq(hits.size(), 1, "one tick")
	assert_eq(hits[0], [2, d.trail_damage])
	_idle(p, floori(d.trail_tick / DT))
	assert_eq(hits.size(), 2, "and another")
	assert_eq(hp0 - (foe.stats.hp + foe.stats.armor), 2 * d.trail_damage)
	assert_eq(p.stats.hp, p.stats.max_hp, "no self-damage")
	assert_eq(safe.stats.hp, safe.stats.max_hp, "outside the trail")


func test_blaze_run_trail_expires() -> void:
	var s: Array = _blaze_setup()
	var p: Player = s[2]
	var foe: Player = s[3]
	var d: SkillData = skills.get_skill(&"blaze_run")
	foe.stats.hp = 5000  # must outlast the whole trail
	foe.global_position = Vector2(200, 300)
	await wait_physics_frames(2)
	var hits: Array = _hits(s[1])
	_press_special(p, Vector2.RIGHT)
	_idle(p, floori(d.duration / DT) + 5)
	assert_false(p.skills[1].is_active())
	var n: int = hits.size()
	assert_between(n, int(d.duration / d.trail_tick) - 1, int(d.duration / d.trail_tick) + 1, "about one hit per tick")
	_idle(p, 60)
	assert_eq(hits.size(), n, "nothing once it is out")


func test_blaze_run_replay_matches_and_damages_nothing() -> void:
	var s: Array = _blaze_setup(true)
	var pool: ProjectilePool = s[1]
	var a: Player = s[2]
	var foe: Player = s[3]
	foe.global_position = Vector2(150, 300)
	var b: Player = _blaze_runner(s[0], pool, 5)
	b.global_position = Vector2(100, 300)
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	var hits: Array = _hits(pool)
	_press_special(a, Vector2.RIGHT)
	_idle(a, 60)
	var served: int = hits.size()
	assert_gt(served, 0)
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	b.simulate(f, DT, true)
	assert_eq(b.skills[1].anchor, a.skills[1].anchor)
	assert_eq(b.skills[1].direction, a.skills[1].direction, "same trail")
	_idle(b, 60, true)
	assert_eq(hits.size(), served, "replay damages nothing")
	assert_almost_eq(b.global_position, a.global_position, Vector2(0.01, 0.01))
	assert_almost_eq(b.skills[1].active_remaining, a.skills[1].active_remaining, 0.0001)


# --- Sakura's Petal Drift ---------------------------------------------------

func _drifter(world: Node2D, pool: ProjectilePool, id: int = 1, at: Vector2 = Vector2(100, 300)) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"sakura"))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(&"petal_drift"))
	p.global_position = at
	return p


func _drift_world(walls: bool = false) -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	if walls:
		_wall(world, Vector2(250, 300), Vector2(20, 400))
	return [world, pool, _drifter(world, pool)]


func test_petal_drift_is_sakuras_own() -> void:
	var d: SkillData = skills.get_skill(&"petal_drift")
	assert_eq(d.kind, SkillData.Kind.DRIFT)
	assert_eq(int(d.kind), 15)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(d), c.id == &"sakura", String(c.id))


func test_petal_drift_is_untouchable_for_exactly_its_duration() -> void:
	var s: Array = _drift_world()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"petal_drift")
	await wait_physics_frames(2)
	assert_true(p.can_be_hit())
	_press_special(p, Vector2.RIGHT)
	assert_true(p.is_hidden(), "auto-aim and bots skip her")
	for i: int in floori(d.duration / DT) - 2:
		_idle(p, 1)
		assert_false(p.can_be_hit(), "no hits while petals")
		assert_true(p.is_hidden())
	_idle(p, 6)
	assert_false(p.skills[1].is_active())
	assert_true(p.can_be_hit(), "back in the world")
	assert_false(p.is_hidden())
	assert_gt(p.skills[1].cooldown_remaining, 0.0)


func test_petal_drift_is_faster_and_steerable() -> void:
	var s: Array = _drift_world()
	var p: Player = s[2]
	var walker: Player = _drifter(s[0], s[1], 2, Vector2(100, 700))
	var d: SkillData = skills.get_skill(&"petal_drift")
	await wait_physics_frames(2)
	var go := InputFrame.new()
	go.move_vec = Vector2.RIGHT
	for i: int in 30:
		walker.simulate(go, DT)
	var normal: float = walker.velocity.x
	_press_special(p, Vector2.RIGHT, Vector2.RIGHT)
	for i: int in 30:
		p.simulate(go, DT)
	assert_almost_eq(p.velocity.x, normal * d.drift_speed_scale, 1.0, "faster")
	var up := InputFrame.new()
	up.move_vec = Vector2.UP
	for i: int in 12:  # 42 frames in, still drifting (0.8 s = 48)
		p.simulate(up, DT)
	assert_true(p.skills[1].is_active())
	assert_lt(p.velocity.y, -normal, "the stick steers her")
	assert_lt(p.velocity.x, normal * 0.5)


func test_petal_drift_glides_on_without_input() -> void:
	var s: Array = _drift_world()
	var p: Player = s[2]
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)  # no stick: along the aim
	_idle(p, 20)
	assert_gt(p.global_position.x, 150.0)
	assert_almost_eq(p.global_position.y, 300.0, 0.01)


func test_petal_drift_stops_at_walls() -> void:
	var s: Array = _drift_world(true)
	var p: Player = s[2]
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT, Vector2.RIGHT)
	var go := InputFrame.new()
	go.move_vec = Vector2.RIGHT
	for i: int in 45:
		p.simulate(go, DT)
	assert_lt(p.global_position.x, 250.0, "the wall holds her")


func test_petal_drift_cannot_fire() -> void:
	var s: Array = _drift_world()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"petal_drift")
	await wait_physics_frames(2)
	watch_signals(p)
	var f := InputFrame.new()
	f.seq = 10
	f.special = true
	f.fire = true
	f.aim_vec = Vector2.RIGHT
	p.simulate(f, DT)
	f.special = false
	for i: int in floori(d.duration / DT) - 2:
		p.simulate(f, DT)
	assert_signal_not_emitted(p, "shot_fired", "no shots while petals")
	for i: int in 10:
		p.simulate(f, DT)
	assert_signal_emitted(p, "shot_fired", "fires again once she reforms")


func test_petal_drift_replay_matches() -> void:
	var s: Array = _drift_world(true)
	var a: Player = s[2]
	var b: Player = _drifter(s[0], s[1], 2, Vector2(300, 100))
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	var f := InputFrame.new()
	f.seq = 10
	f.special = true
	f.move_vec = Vector2(1, -0.3)
	f.aim_vec = Vector2.RIGHT
	a.simulate(f, DT)
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	b.simulate(f, DT, true)
	f.special = false
	for i: int in 70:
		a.simulate(f, DT)
		b.simulate(f, DT, true)
	assert_almost_eq(b.global_position, a.global_position, Vector2(0.01, 0.01))
	assert_almost_eq(b.skills[1].active_remaining, a.skills[1].active_remaining, 0.0001)
	assert_almost_eq(b.skills[1].cooldown_remaining, a.skills[1].cooldown_remaining, 0.0001)
	assert_almost_eq(b.stats.invulnerable_time, a.stats.invulnerable_time, 0.0001)


# --- Apex's Sky Pillar --------------------------------------------------------------

func _pillar_player(world: Node2D, pool: ProjectilePool, id: int, at: Vector2) -> Player:
	var p: Player = _whirler(world, pool, id, at)
	p.set_skill(1, skills.get_skill(&"sky_pillar"))
	pool.targets.append(p)
	return p


func _pillar_setup(walls: bool = false) -> Array:
	var w: Array = _whirl_world()
	if walls:
		_wall(w[0], Vector2(250, 300), Vector2(20, 400))
	return [w[0], w[1], _pillar_player(w[0], w[1], 1, Vector2(100, 300))]


func test_sky_pillar_is_apexs_own() -> void:
	var d: SkillData = skills.get_skill(&"sky_pillar")
	assert_eq(d.kind, SkillData.Kind.PILLAR)
	assert_eq(int(d.kind), 14)
	assert_gt(d.duration, d.pillar_windup)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(d), c.id == &"wukong", String(c.id))


func test_sky_pillar_hits_the_line_not_beside_it_or_the_caster_after_the_windup() -> void:
	var s: Array = _pillar_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"sky_pillar")
	_pillar_player(s[0], s[1], 2, Vector2(300, 300 + d.pillar_width * 0.25))
	_pillar_player(s[0], s[1], 3, Vector2(100 + d.pillar_length - 10.0, 300))
	var beside: Player = _pillar_player(s[0], s[1], 4, Vector2(300, 300 + d.pillar_width * 0.5 + 12.0))
	var past: Player = _pillar_player(s[0], s[1], 5, Vector2(100 + d.pillar_length + 60.0, 300))
	await wait_physics_frames(2)
	var hits: Array = _hits(s[1])
	_press_special(p, Vector2.RIGHT)
	var slot: CharacterSkill = p.skills[1]
	assert_eq(slot.anchor, Vector2(100, 300))
	assert_almost_eq(slot.direction, Vector2(d.pillar_length, 0), Vector2(0.1, 0.1))
	var windup: int = floori(d.pillar_windup / DT)
	_idle(p, windup - 3)
	assert_eq(hits.size(), 0, "nothing before the slam")
	_idle(p, 6)
	assert_eq(hits.size(), 2, "the two on the line")
	assert_true(hits.has([2, d.pillar_damage]) and hits.has([3, d.pillar_damage]))
	assert_eq(beside.stats.hp, beside.stats.max_hp, "beside the line")
	assert_eq(past.stats.hp, past.stats.max_hp, "past its end")
	assert_eq(p.stats.hp, p.stats.max_hp, "not the caster")
	_idle(p, 30)
	assert_eq(hits.size(), 2, "one slam only")


func test_sky_pillar_throws_the_hit_sideways() -> void:
	var s: Array = _pillar_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"sky_pillar")
	var foe: Player = _pillar_player(s[0], s[1], 2, Vector2(250, 300 + 10.0))
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	_idle(p, ceili(d.pillar_windup / DT) + 2)
	assert_gt(foe.velocity.y, 0.0, "pushed away from the line (down)")
	assert_lt(absf(foe.velocity.x), 1.0, "not along it")


func test_sky_pillar_roots_him_during_the_windup() -> void:
	var s: Array = _pillar_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"sky_pillar")
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT, Vector2.DOWN)
	var f := InputFrame.new()
	f.move_vec = Vector2.DOWN
	for i: int in floori(d.pillar_windup / DT) - 3:
		f.seq = 100 + i
		p.simulate(f, DT)
	assert_eq(p.global_position, Vector2(100, 300), "can't move while planting")
	for i: int in 40:
		f.seq = 200 + i
		p.simulate(f, DT)
	assert_gt(p.global_position.y, 300.0, "free again afterwards")


func test_sky_pillar_stops_at_walls() -> void:
	var s: Array = _pillar_setup(true)
	var p: Player = s[2]
	var behind: Player = _pillar_player(s[0], s[1], 2, Vector2(400, 300))
	var before: Player = _pillar_player(s[0], s[1], 3, Vector2(200, 300))
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	var slot: CharacterSkill = p.skills[1]
	assert_almost_eq(slot.direction.x, 140.0, 0.5, "ends at the wall face (x = 240)")
	_idle(p, 30)
	assert_lt(before.stats.hp + before.stats.armor, before.stats.max_hp + before.stats.max_armor, "in front of the wall")
	assert_eq(behind.stats.hp + behind.stats.armor, behind.stats.max_hp + behind.stats.max_armor, "behind the wall")


func test_sky_pillar_damages_crates_on_the_line() -> void:
	var s: Array = _pillar_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"sky_pillar")
	var on_line := Crate.new()
	on_line.setup(0, Vector2(250, 300), Constants.TILE_SIZE)
	s[0].add_child(on_line)
	var beside := Crate.new()
	beside.setup(0, Vector2(250, 300 + Constants.TILE_SIZE * 2.0), Constants.TILE_SIZE)
	s[0].add_child(beside)
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	assert_lt(p.skills[1].direction.x, 150.0, "the crate stops the line")
	_idle(p, ceili(d.pillar_windup / DT) + 2)
	assert_eq(on_line.hp, Constants.CRATE_HP - d.pillar_damage)
	assert_eq(beside.hp, Constants.CRATE_HP)


func test_sky_pillar_cooldown_and_replay_match() -> void:
	var s: Array = _pillar_setup(true)
	var a: Player = s[2]
	var foe: Player = _pillar_player(s[0], s[1], 2, Vector2(200, 300))
	var b: Player = _pillar_player(s[0], s[1], 5, Vector2(100, 300))
	s[1].targets.erase(b)
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	var hits: Array = _hits(s[1])
	_press_special(a, Vector2.RIGHT)
	_idle(a, 60)
	var served: int = hits.size()
	assert_eq(served, 1)
	assert_gt(a.skills[1].cooldown_remaining, 0.0)
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	b.simulate(f, DT, true)
	assert_eq(b.skills[1].anchor, a.skills[1].anchor)
	assert_eq(b.skills[1].direction, a.skills[1].direction, "same line")
	_idle(b, 60, true)
	assert_eq(hits.size(), served, "replay damages nothing")
	assert_eq(foe.stats.hp + foe.stats.armor, foe.stats.max_hp + foe.stats.max_armor - skills.get_skill(&"sky_pillar").pillar_damage)
	assert_almost_eq(b.skills[1].cooldown_remaining, a.skills[1].cooldown_remaining, 0.0001)


# --- Flint's Flare Burst -------------------------------------------------------------

func _flare_setup() -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p: Player = _flint_erupter(world, pool)
	p.set_skill(1, skills.get_skill(&"flare_burst"))
	p.global_position = Vector2(300, 300)
	return [world, pool, p]


func test_flare_burst_is_flints_own() -> void:
	var d: SkillData = skills.get_skill(&"flare_burst")
	assert_eq(d.kind, SkillData.Kind.NOVA)
	assert_true(d.nova_blast.blast and d.nova_blast.destroys_shots)
	assert_gt(d.duration, d.nova_charge)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(d), c.id == &"flint", String(c.id))


func test_flare_burst_waits_for_the_charge_and_roots_him() -> void:
	var s: Array = _flare_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"flare_burst")
	var foe: Player = _flint_erupter(s[0], s[1], 2)
	foe.global_position = Vector2(350, 300)
	await wait_physics_frames(2)
	var hits: Array = _hits(s[1])
	_press_special(p, Vector2.RIGHT)
	var start: Vector2 = p.global_position
	for i: int in floori(d.nova_charge / DT) - 3:
		var f := InputFrame.new()
		f.seq = 100 + i
		f.move_vec = Vector2.LEFT
		f.fire = true
		p.simulate(f, DT)
		assert_eq(p.global_position, start, "rooted while charging")
	assert_eq(hits.size(), 0, "no damage before the charge ends")
	_idle(p, 6)
	assert_eq(hits.size(), 1, "bursts once")
	assert_eq(hits[0][0], 2)
	assert_between(hits[0][1], roundi(d.nova_blast.damage * d.nova_blast.splash_edge_scale), d.nova_blast.damage, "falls off toward the edge")
	_idle(p, 60)
	assert_eq(hits.size(), 1)


func test_flare_burst_hits_and_throws_those_in_range_only() -> void:
	var s: Array = _flare_setup()
	var p: Player = s[2]
	var blast: WeaponData = skills.get_skill(&"flare_burst").nova_blast
	var near: Player = _flint_erupter(s[0], s[1], 2)
	near.global_position = Vector2(300 + blast.splash_radius * 0.9, 300)
	var far: Player = _flint_erupter(s[0], s[1], 3)
	far.global_position = Vector2(300, 300 - blast.splash_radius - 40.0)
	var behind_wall: Player = _flint_erupter(s[0], s[1], 4)
	behind_wall.global_position = Vector2(300 - blast.splash_radius * 0.8, 300)
	_wall(s[0], Vector2(300 - blast.splash_radius * 0.4, 300), Vector2(12, 200))
	await wait_physics_frames(2)
	var hits: Array = _hits(s[1])
	_press_special(p, Vector2.RIGHT)
	_idle(p, 40)
	assert_eq(hits.size(), 1, "only the one in range with sight")
	assert_eq(hits[0][0], 2)
	assert_between(hits[0][1], roundi(blast.damage * blast.splash_edge_scale), blast.damage)
	assert_gt(near.velocity.x, blast.knockback * 0.5, "thrown away from him")
	assert_eq(far.velocity, Vector2.ZERO)
	assert_eq(p.stats.hp, p.stats.max_hp, "not himself")


func test_flare_burst_destroys_enemy_projectiles_in_range() -> void:
	var s: Array = _flare_setup()
	var p: Player = s[2]
	var blast: WeaponData = skills.get_skill(&"flare_burst").nova_blast
	var gun: WeaponData = WeaponCatalog.load_all().get_weapon(&"pistol")
	await wait_physics_frames(2)
	s[1].fire_shot(2, 1, Vector2(300 + blast.splash_radius * 0.5, 340), Vector2.RIGHT, gun, 3)  # inside
	s[1].fire_shot(2, 2, Vector2(300 + blast.splash_radius + 80.0, 340), Vector2.RIGHT, gun, 3)  # outside
	s[1].fire_shot(1, 3, Vector2(300 + blast.splash_radius * 0.5, 260), Vector2.RIGHT, gun, 3)  # his own
	var before: int = s[1].active_count()
	assert_eq(before, 3)
	_press_special(p, Vector2.RIGHT)
	_idle(p, 18)
	assert_eq(s[1].active_count(), before - 1, "the enemy's inside the ring is gone, the others stay")


func test_flare_burst_cooldown_and_replay_match() -> void:
	var s: Array = _flare_setup()
	var a: Player = s[2]
	var b: Player = _flint_erupter(s[0], s[1], 5)
	b.set_skill(1, skills.get_skill(&"flare_burst"))
	var foe: Player = _flint_erupter(s[0], s[1], 2)
	foe.global_position = Vector2(350, 300)
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	var hits: Array = _hits(s[1])
	_press_special(a, Vector2.RIGHT)
	_idle(a, 40)
	assert_eq(hits.size(), 1)
	assert_almost_eq(a.skills[1].cooldown_remaining, skills.get_skill(&"flare_burst").cooldown - 40 * DT, 0.01)
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	b.simulate(f, DT, true)
	_idle(b, 40, true)
	assert_eq(hits.size(), 1, "replay damages nothing")
	assert_almost_eq(b.skills[1].cooldown_remaining, a.skills[1].cooldown_remaining, 0.0001)
	assert_eq(b.global_position, a.global_position)


# --- Sakura's Cherry Sapling --------------------------------------------------------

func _sapling_setup(foes: Array[Vector2], walls: bool = false) -> Array:
	var w: Array = _whirl_world()
	if walls:
		_wall(w[0], Vector2(250, 300), Vector2(20, 400))
	var p: Player = _whirler(w[0], w[1], 1, Vector2(100, 300))
	p.set_skill(1, skills.get_skill(&"cherry_sapling"))
	var shots: Array = []  # [seq, direction]
	p.shot_fired.connect(func(_who: Player, seq: int, _o: Vector2, dir: Vector2, _id: StringName) -> void:
		shots.append([seq, dir]))
	var foe_list: Array[Player] = []
	for i: int in foes.size():
		var f: Player = _whirler(w[0], w[1], 2 + i, foes[i])
		w[1].targets.append(f)
		foe_list.append(f)
	w[1].targets.append(p)
	return [w[0], w[1], p, shots, foe_list]


func test_cherry_sapling_is_sakuras_own() -> void:
	var d: SkillData = skills.get_skill(&"cherry_sapling")
	assert_eq(d.kind, SkillData.Kind.SAPLING)
	assert_eq(int(d.kind), 18)
	assert_lte(d.blurb.length(), 20)
	assert_gt(d.sapling_weapon.damage, 0)
	assert_lt(Player.SAPLING_SEQ_OFFSET, Player.VOLLEY_SEQ_OFFSET)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(d), c.id == &"sakura", String(c.id))


func test_cherry_sapling_shoots_the_nearest_visible_enemy_on_schedule() -> void:
	var s: Array = _sapling_setup([Vector2(100, 560), Vector2(300, 300), Vector2(700, 300)])
	var p: Player = s[2]
	var shots: Array = s[3]
	var d: SkillData = skills.get_skill(&"cherry_sapling")
	await wait_physics_frames(2)
	_press_special(p, Vector2.LEFT)
	assert_eq(p.skills[1].anchor, Vector2(100, 300 + Player.FOOT_RING_Y), "planted at her feet")
	assert_eq(shots.size(), 0, "nothing on the press")
	_idle(p, floori(d.sapling_interval / DT) - 3)
	assert_eq(shots.size(), 0, "not before the first interval")
	_idle(p, 6)
	assert_eq(shots.size(), 1)
	var dir: Vector2 = shots[0][1]
	var muzzle := Vector2(100, 300 + Player.FOOT_RING_Y - d.sapling_muzzle_height)
	assert_almost_eq(dir, (Vector2(300, 300) - muzzle).normalized(), Vector2(0.05, 0.05), "at the near one, not her or the far ones")
	assert_gte(int(shots[0][0]), Player.SAPLING_SEQ_OFFSET)
	assert_lt(int(shots[0][0]), Player.VOLLEY_SEQ_OFFSET)
	assert_eq(s[1].active_count(), 1, "a petal is in the air")
	assert_eq(p.stats.hp, p.stats.max_hp, "never hurts her")


func test_cherry_sapling_ignores_walled_off_and_out_of_range_enemies() -> void:
	var s: Array = _sapling_setup([Vector2(400, 300), Vector2(100 + 500, 300 - 300)], true)
	var p: Player = s[2]
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	_idle(p, 90)
	assert_eq(s[3].size(), 0, "one is behind the wall, one is out of range")


func test_cherry_sapling_keeps_shooting_until_it_expires() -> void:
	var s: Array = _sapling_setup([Vector2(300, 300)])
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"cherry_sapling")
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	_idle(p, ceili(d.duration / DT) + 5)
	var n: int = s[3].size()
	assert_eq(n, floori(d.duration / d.sapling_interval), "one per interval over its life")
	assert_false(p.skills[1].is_active(), "the tree is gone")
	assert_gt(p.skills[1].cooldown_remaining, 0.0, "cooldown outlasts it")
	_idle(p, 60)
	assert_eq(s[3].size(), n, "no more shots")


func test_cherry_sapling_is_removed_when_she_dies() -> void:
	var s: Array = _sapling_setup([Vector2(300, 300)])
	var p: Player = s[2]
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	_idle(p, 40)
	var n: int = s[3].size()
	assert_gt(n, 0)
	p.take_hit(9999, false, Vector2.ZERO, 2)
	assert_true(p.dead)
	assert_false(p.skills[1].is_active(), "the tree goes with her")
	_idle(p, 90)
	assert_eq(s[3].size(), n, "and stops shooting")


func test_cherry_sapling_replay_fires_nothing_and_matches() -> void:
	var s: Array = _sapling_setup([Vector2(300, 300)])
	var p: Player = s[2]
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	_idle(p, 90)
	var served: int = s[3].size()
	assert_gt(served, 0)
	var b: Player = _whirler(s[0], s[1], 9, Vector2(100, 300))
	b.set_skill(1, skills.get_skill(&"cherry_sapling"))
	var again: Array = []
	b.shot_fired.connect(func(_who: Player, seq: int, _o: Vector2, _d: Vector2, _id: StringName) -> void: again.append(seq))
	_press_special(b, Vector2.RIGHT)
	_idle(b, 90, true)
	assert_eq(again.size(), 0, "replay fires nothing")
	assert_almost_eq(b.skills[1].active_remaining, p.skills[1].active_remaining, 0.0001)
	assert_eq(b.skills[1].anchor, p.skills[1].anchor)


# --- Apex's Storm Cloud -------------------------------------------------------------

func _storm_player(world: Node2D, pool: ProjectilePool, id: int, at: Vector2) -> Player:
	var p: Player = _whirler(world, pool, id, at)
	p.set_skill(1, skills.get_skill(&"storm_cloud"))
	pool.targets.append(p)
	return p


func _storm_setup(wall_x: float = -1.0) -> Array:
	var w: Array = _whirl_world()
	if wall_x >= 0.0:
		_wall(w[0], Vector2(wall_x, 300), Vector2(20, 400))
	return [w[0], w[1], _storm_player(w[0], w[1], 1, Vector2(100, 300))]


func test_storm_cloud_is_apexs_own() -> void:
	var d: SkillData = skills.get_skill(&"storm_cloud")
	assert_eq(d.kind, SkillData.Kind.STORM)
	assert_eq(int(SkillData.Kind.STORM), 16)
	assert_lte(d.blurb.length(), 20)
	assert_gt(d.duration, d.storm_interval * 4)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(d), c.id == &"wukong", String(c.id))


func test_storm_cloud_spot_is_ahead_and_stops_at_walls() -> void:
	var s: Array = _storm_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"storm_cloud")
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT)
	var feet := Vector2(100, 300 + Constants.WALL_FEET_STRIP)
	assert_almost_eq(p.skills[1].anchor, feet + Vector2(d.storm_distance, 0), Vector2(0.01, 0.01))
	var walled: Array = _storm_setup(250.0)
	await wait_physics_frames(2)
	_press_special(walled[2], Vector2.RIGHT)
	assert_almost_eq(walled[2].skills[1].anchor.x, 240.0 - d.storm_wall_margin, 0.5, "short of the wall")


func test_storm_cloud_strikes_only_enemies_in_range_with_sight_on_each_tick() -> void:
	var s: Array = _storm_setup(150.0)
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"storm_cloud")
	# The wall stops the spot at x = 132 (feet y = 322): `near` is in reach and in sight, `hidden` is in reach behind
	# the wall, `far` is out of reach, and the caster stands in the circle herself.
	var near: Player = _storm_player(s[0], s[1], 2, Vector2(100, 322))
	var hidden: Player = _storm_player(s[0], s[1], 3, Vector2(190, 322))
	var far: Player = _storm_player(s[0], s[1], 4, Vector2(100, 322 + d.storm_radius + 40.0))
	await wait_physics_frames(2)
	var hits: Array = _hits(s[1])
	_press_special(p, Vector2.RIGHT)
	_idle(p, floori(d.storm_interval / DT) - 3)
	assert_eq(hits.size(), 0, "nothing before the first interval")
	_idle(p, 6)
	assert_eq(hits.size(), 1, "first bolt")
	assert_eq(hits[0], [2, d.storm_damage])
	assert_lt(near.velocity.x, 0.0, "pushed away from the spot")
	_idle(p, floori(d.storm_interval / DT))
	assert_eq(hits.size(), 2, "a bolt every interval, one victim each")
	_idle(p, floori(d.duration / DT))
	assert_eq(hits.size(), 6, "six strikes over the cloud's life")
	assert_eq(hidden.stats.hp, hidden.stats.max_hp, "no sight from the spot")
	assert_eq(far.stats.hp, far.stats.max_hp, "out of reach")
	assert_eq(p.stats.hp, p.stats.max_hp, "not herself")
	assert_eq(p.stats.armor, p.stats.max_armor)


func test_storm_cloud_expires_and_cools_down() -> void:
	var s: Array = _storm_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"storm_cloud")
	var foe: Player = _storm_player(s[0], s[1], 2, Vector2(100 + d.storm_distance, 322))
	await wait_physics_frames(2)
	var hits: Array = _hits(s[1])
	_press_special(p, Vector2.RIGHT)
	_idle(p, ceili(d.duration / DT) + 5)
	assert_false(p.skills[1].is_active())
	var served: int = hits.size()
	assert_eq(served, 6)
	_idle(p, 120)
	assert_eq(hits.size(), served, "no strikes once it's gone")
	assert_gt(p.skills[1].cooldown_remaining, 0.0)
	assert_lt(foe.stats.hp + foe.stats.armor, foe.stats.max_hp + foe.stats.max_armor)


func test_storm_cloud_replay_matches_and_hurts_nobody() -> void:
	var s: Array = _storm_setup(150.0)
	var a: Player = s[2]
	var foe: Player = _storm_player(s[0], s[1], 2, Vector2(100, 322))
	var b: Player = _storm_player(s[0], s[1], 5, Vector2(100, 300))
	s[1].targets.erase(b)
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	var hits: Array = _hits(s[1])
	_press_special(a, Vector2.RIGHT)
	_idle(a, 60)
	var served: int = hits.size()
	assert_eq(served, 1)
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	b.simulate(f, DT, true)
	_idle(b, 60, true)
	assert_eq(hits.size(), served, "replay damages nobody")
	assert_eq(b.skills[1].anchor, a.skills[1].anchor)
	assert_almost_eq(b.skills[1].active_remaining, a.skills[1].active_remaining, 0.0001)
	assert_almost_eq(b.skills[1].cooldown_remaining, a.skills[1].cooldown_remaining, 0.0001)
	assert_lt(foe.stats.hp + foe.stats.armor, foe.stats.max_hp + foe.stats.max_armor)


# --- Bolt's Overdrive ---------------------------------------------------------

func _bolt(world: Node2D, pool: ProjectilePool, id: int = 1, at: Vector2 = Vector2(100, 300)) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"bolt"))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(&"overdrive"))
	p.global_position = at
	return p


func test_overdrive_is_bolts_own() -> void:
	var d: SkillData = skills.get_skill(&"overdrive")
	assert_eq(d.kind, SkillData.Kind.OVERDRIVE)
	assert_eq(int(d.kind), 19)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(d), c.id == &"bolt", String(c.id))
	assert_eq(characters.get_character(&"bolt").signature_skill, d)
	assert_eq(characters.get_character(&"bolt").signature_weapon.id, &"bolt_zapper")


func test_overdrive_is_faster_for_its_duration_and_still_fires() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p: Player = _bolt(world, pool)
	var walker: Player = _bolt(world, pool, 2, Vector2(100, 700))
	var d: SkillData = skills.get_skill(&"overdrive")
	await wait_physics_frames(2)
	var go := InputFrame.new()
	go.move_vec = Vector2.RIGHT
	for i: int in 30:
		walker.simulate(go, DT)
	var normal: float = walker.velocity.x
	assert_almost_eq(normal, 290.0, 1.0)
	_press_special(p, Vector2.RIGHT, Vector2.RIGHT)
	for i: int in 30:
		p.simulate(go, DT)
	assert_almost_eq(p.velocity.x, normal * d.overdrive_speed_scale, 1.0, "super speed")
	assert_true(p.can_be_hit(), "no i-frames: speed is the defence")
	var fire := InputFrame.new()
	fire.move_vec = Vector2.RIGHT
	fire.fire = true
	fire.seq = 40
	watch_signals(p)
	p.simulate(fire, DT)
	assert_signal_emitted(p, "shot_fired", "unlike Drift he can still shoot")
	for i: int in floori(d.duration / DT):
		p.simulate(go, DT)
	assert_false(p.skills[1].is_active())
	for i: int in 40:
		p.simulate(go, DT)
	assert_almost_eq(p.velocity.x, normal, 1.0, "back to normal speed")
	assert_gt(p.skills[1].cooldown_remaining, 0.0)


func test_overdrive_is_steerable() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var p: Player = _bolt(world, null)
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT, Vector2.RIGHT)
	var up := InputFrame.new()
	up.move_vec = Vector2.UP
	for i: int in 40:
		p.simulate(up, DT)
	assert_lt(p.velocity.y, -500.0)
	assert_lt(absf(p.velocity.x), 20.0)


func test_overdrive_replay_matches() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var a: Player = _bolt(world, null)
	var b: Player = _bolt(world, null, 2, Vector2(300, 100))
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	var f := InputFrame.new()
	f.seq = 10
	f.special = true
	f.move_vec = Vector2(1, -0.3)
	f.aim_vec = Vector2.RIGHT
	a.simulate(f, DT)
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	b.simulate(f, DT, true)
	f.special = false
	for i: int in 200:
		a.simulate(f, DT)
		b.simulate(f, DT, true)
	assert_almost_eq(b.global_position, a.global_position, Vector2(0.01, 0.01))
	assert_almost_eq(b.skills[1].active_remaining, a.skills[1].active_remaining, 0.0001)


# --- Balance pass: purposes for Smoke Bomb, Grapple Kunai, Overdrive ------------

func test_overdrive_ticks_the_weapon_faster_only_while_active() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var p: Player = _bolt(world, null)
	var d: SkillData = skills.get_skill(&"overdrive")
	await wait_physics_frames(2)
	var idle := InputFrame.new()
	p.weapon.cooldown = 1.0
	p.simulate(idle, DT)
	assert_almost_eq(p.weapon.cooldown, 1.0 - DT, 0.0001, "normal tick")
	_press_special(p, Vector2.RIGHT, Vector2.RIGHT)
	p.weapon.cooldown = 1.0
	p.simulate(idle, DT)
	assert_almost_eq(p.weapon.cooldown, 1.0 - DT * d.overdrive_fire_scale, 0.0001, "faster while overdriving")
	assert_gt(d.overdrive_fire_scale, 1.0)


func test_smoke_speeds_you_up_only_inside_the_cloud() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var p: Player = _flicker_in(world, &"smoke_bomb")
	var d: SkillData = skills.get_skill(&"smoke_bomb")
	p.global_position = Vector2(200, 400)
	await wait_physics_frames(2)
	var go := InputFrame.new()
	go.move_vec = Vector2.RIGHT
	for i: int in 30:
		p.simulate(go, DT)
	var normal: float = p.velocity.x
	p.global_position = Vector2(200, 400)
	_press_special(p, Vector2.RIGHT)
	p.simulate(go, DT)
	for i: int in 10:
		p.simulate(go, DT)
	assert_true(p.is_hidden())
	assert_almost_eq(p.velocity.x, normal * d.smoke_speed_scale, 1.0, "hurried inside the cloud")
	assert_gt(d.smoke_speed_scale, 1.0)


func test_grapple_bite_grants_iframes_but_a_miss_does_not() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	_wall(world, Vector2(500, 300), Vector2(20, 400))
	var p: Player = _flicker_in(world, &"grapple_kunai")
	p.global_position = Vector2(200, 300)
	await wait_physics_frames(2)
	var sk: SkillData = skills.get_skill(&"grapple_kunai")
	_press_special(p, Vector2.RIGHT)
	assert_almost_eq(p.stats.invulnerable_time, sk.grapple_iframes, 0.001, "bite = i-frames")
	var q: Player = _flicker_in(world, &"grapple_kunai")
	q.global_position = Vector2(200, 700)
	await wait_physics_frames(2)
	_press_special(q, Vector2.LEFT)  # nothing within range that way
	assert_almost_eq(q.stats.invulnerable_time, 0.0, 0.001, "a miss grants nothing")


# --- Eden: Bark Skin, Verdant Bloom, Leaf Gust ---------------------------------------

func _eden(world: Node2D, pool: ProjectilePool, special: StringName, id: int = 1, at: Vector2 = Vector2(300, 300)) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"eden"))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(special))
	p.global_position = at
	if pool != null:
		pool.targets.append(p)
	return p


func test_eden_specials_are_hers_and_numbers_sane() -> void:
	var eden: CharacterData = characters.get_character(&"eden")
	assert_true(characters.ordered.has(eden))
	assert_eq(eden.signature_skill.id, &"bark_skin")
	assert_eq(eden.signature_weapon.id, &"eden_sling")
	assert_gt(eden.signature_weapon.splash_radius, 0.0, "a splash weapon")
	assert_not_null(eden.signature_weapon.burst_art)
	var ids: Array[StringName] = []
	for sk: SkillData in skills.specials_for(eden):
		ids.append(sk.id)
	for id: StringName in [&"bark_skin", &"verdant_bloom", &"leaf_gust"]:
		assert_has(ids, id)
		var d: SkillData = skills.get_skill(id)
		assert_lte(d.blurb.length(), 20)
		for c: CharacterData in characters.ordered:
			assert_eq(c.can_use_skill(d), c.id == &"eden", "%s / %s" % [id, c.id])
	assert_eq(int(SkillData.Kind.BARK_SKIN), 20)
	assert_eq(int(SkillData.Kind.BLOOM), 21)
	assert_eq(int(SkillData.Kind.GUST), 22)


func test_bark_skin_scales_incoming_damage_and_refills_armor_only_while_on() -> void:
	var w: Array = _whirl_world()
	var d: SkillData = skills.get_skill(&"bark_skin")
	var p: Player = _eden(w[0], w[1], &"bark_skin")
	await wait_physics_frames(2)
	p.stats.armor = 0
	assert_eq(p.take_hit(40, false, Vector2.ZERO, 2), 40, "full damage before the bark")
	assert_eq(p.stats.hp, p.stats.max_hp - 40)
	p.stats.hp = p.stats.max_hp
	p.stats.armor = 0
	_press_special(p, Vector2.RIGHT)
	assert_true(p.skills[1].is_barked())
	assert_eq(p.stats.armor, p.stats.max_armor, "armor refilled on the press")
	p.stats.armor = 0
	assert_eq(p.take_hit(40, false, Vector2.ZERO, 2), roundi(40 * d.bark_damage_scale), "scaled while it lasts")
	assert_eq(p.take_hit(1, false, Vector2.ZERO, 2), 1, "never rounds to nothing")
	_idle(p, ceili(d.duration / DT) + 5)
	assert_false(p.skills[1].is_active())
	p.stats.hp = p.stats.max_hp
	p.stats.armor = 0
	assert_eq(p.take_hit(40, false, Vector2.ZERO, 2), 40, "full damage again")
	assert_gt(d.cooldown, d.duration)


func _bloom_setup() -> Array:
	var w: Array = _whirl_world()
	var d: SkillData = skills.get_skill(&"verdant_bloom")
	var p: Player = _eden(w[0], w[1], &"verdant_bloom", 1, Vector2(300, 300))
	var other: Player = _eden(w[0], w[1], &"verdant_bloom", 2, Vector2(300, 300))  # stands in the patch too
	return [w[0], w[1], p, other, d]


func test_verdant_bloom_heals_only_its_owner_and_only_inside() -> void:
	var s: Array = _bloom_setup()
	var p: Player = s[2]
	var other: Player = s[3]
	var d: SkillData = s[4]
	await wait_physics_frames(2)
	p.stats.hp = 50
	other.stats.hp = 50
	_press_special(p, Vector2.RIGHT)
	assert_eq(p.skills[1].anchor, Vector2(300, 300 + Player.FOOT_RING_Y), "patch at her feet")
	_idle(p, floori(d.bloom_interval / DT) - 3)
	assert_eq(p.stats.hp, 50, "nothing before the first interval")
	_idle(p, 6)
	assert_eq(p.stats.hp, 50 + d.bloom_heal, "first heal")
	assert_eq(other.stats.hp, 50, "the other one standing in it gets nothing")
	_idle(p, floori(d.bloom_interval / DT))
	assert_eq(p.stats.hp, 50 + 2 * d.bloom_heal, "one heal per interval")
	# stepping out: no more healing while she is outside the radius
	p.global_position += Vector2(d.bloom_radius + 40.0, 0.0)
	var hp_out: int = p.stats.hp
	_idle(p, floori(d.bloom_interval / DT) * 3)
	assert_eq(p.stats.hp, hp_out, "outside the patch")
	# back in; healing is capped at max hp and ends with the patch
	p.global_position = Vector2(300, 300)
	p.stats.hp = p.stats.max_hp - 1
	_idle(p, floori(d.bloom_interval / DT) + 2)
	assert_eq(p.stats.hp, p.stats.max_hp, "never past the max")
	_idle(p, ceili(d.duration / DT) + 5)
	assert_false(p.skills[1].is_active())
	p.stats.hp = 10
	_idle(p, 120)
	assert_eq(p.stats.hp, 10, "the patch is gone")


func test_verdant_bloom_is_server_side_only_and_not_for_the_dead() -> void:
	var s: Array = _bloom_setup()
	var p: Player = s[2]
	var pool: ProjectilePool = s[1]
	var d: SkillData = s[4]
	await wait_physics_frames(2)
	pool.authoritative = false
	p.stats.hp = 50
	_press_special(p, Vector2.RIGHT)
	_idle(p, floori(d.bloom_interval / DT) + 3)
	assert_eq(p.stats.hp, 50, "a client's pool heals nobody")
	assert_eq(p.stats.heal(5), 0 if p.stats.is_dead() else 5)
	p.stats.hp = 0
	assert_eq(p.stats.heal(5), 0, "no healing the dead")


func _gust_setup() -> Array:
	var w: Array = _whirl_world()
	var d: SkillData = skills.get_skill(&"leaf_gust")
	var p: Player = _eden(w[0], w[1], &"leaf_gust")
	var inside: Player = _eden(w[0], w[1], &"leaf_gust", 2, Vector2(300 + d.gust_range * 0.6, 300))
	var beside: Player = _eden(w[0], w[1], &"leaf_gust", 3, Vector2(300 + 20, 300 + d.gust_range * 0.8))  # outside the angle
	var far: Player = _eden(w[0], w[1], &"leaf_gust", 4, Vector2(300 + d.gust_range + 60.0, 300))
	return [w[0], w[1], p, inside, beside, far, d]


func test_leaf_gust_pushes_and_hurts_only_enemies_in_the_cone() -> void:
	var s: Array = _gust_setup()
	var p: Player = s[2]
	var d: SkillData = s[6]
	await wait_physics_frames(2)
	var hits: Array = _hits(s[1])
	for q: Player in [s[3], s[4], s[5]]:
		q.stats.armor = 0
	_press_special(p, Vector2.RIGHT)
	assert_eq(hits, [[2, d.gust_damage]], "one victim, once")
	assert_gt(s[3].velocity.x, d.gust_knockback * 0.9, "thrown away from her, hard")
	assert_eq(s[4].stats.hp, s[4].stats.max_hp, "outside the angle")
	assert_eq(s[5].stats.hp, s[5].stats.max_hp, "out of range")
	assert_eq(p.stats.hp, p.stats.max_hp, "not herself")
	_idle(p, 20)
	assert_eq(hits.size(), 1, "the hit lands on the press only")


func test_leaf_gust_on_a_remote_copy_clears_shots_from_its_process() -> void:
	var s: Array = _gust_setup()
	var p: Player = s[2]
	var pool: ProjectilePool = s[1]
	await wait_physics_frames(2)
	pool.authoritative = false
	_press_special(p, Vector2.RIGHT)  # state as a snapshot would leave it; no more simulate() calls follow
	var gun: WeaponData = WeaponCatalog.load_all().get_weapon(&"pistol")
	pool.fire_shot(2, 5, Vector2(300 + 90, 300), Vector2.LEFT, gun, 3)  # an enemy shot flies into the cone
	pool.fire_shot(2, 6, Vector2(300 + 90, 300 + 120), Vector2.LEFT, gun, 3)  # outside it
	assert_eq(pool.active_count(), 2)
	p._process(DT)  # a remote copy has no controller, so only _process runs
	assert_eq(pool.active_count(), 1, "the cone cleared the shot on this peer too")
	assert_eq(s[3].stats.hp, s[3].stats.max_hp, "and a client's gust hurts nobody")


func test_leaf_gust_destroys_enemy_shots_in_the_cone_but_not_her_own() -> void:
	var s: Array = _gust_setup()
	var p: Player = s[2]
	var pool: ProjectilePool = s[1]
	await wait_physics_frames(2)
	var gun: WeaponData = WeaponCatalog.load_all().get_weapon(&"pistol")
	pool.fire_shot(2, 5, Vector2(300 + 90, 300), Vector2.LEFT, gun, 3)  # an enemy shot inside the cone
	pool.fire_shot(2, 6, Vector2(300 + 90, 300 + 120), Vector2.LEFT, gun, 3)  # outside the cone
	pool.fire_shot(1, 7, Vector2(300 + 90, 300), Vector2.RIGHT, gun, 3)  # hers
	assert_eq(pool.active_count(), 3)
	_press_special(p, Vector2.RIGHT)
	assert_eq(pool.active_count(), 2, "only the enemy shot in the cone is gone")
	for slot: ProjectilePool.Slot in pool.debug_slots():
		if slot.active:
			assert_ne(slot.shot_seq, 5)
	# a shot flying into the cone while it lasts dies too
	pool.fire_shot(2, 8, Vector2(300 + 120, 300), Vector2.LEFT, gun, 3)
	var before: int = pool.active_count()
	_idle(p, 3)
	assert_lt(pool.active_count(), before, "shots that enter the cone are destroyed")
	assert_true(skills.get_skill(&"leaf_gust").cooldown > 0.0)


func test_bots_only_cast_edens_specials_when_they_help() -> void:
	var w: Array = _whirl_world()
	var bot := BotBrain.new(null, 1)
	var gust: Player = _eden(w[0], w[1], &"leaf_gust")
	assert_true(bot.special_useful(gust, 100.0))
	assert_false(bot.special_useful(gust, 400.0), "out of the cone's reach")
	var bloom: Player = _eden(w[0], w[1], &"verdant_bloom", 2)
	assert_false(bot.special_useful(bloom, 100.0), "unhurt")
	bloom.stats.hp = 40
	assert_true(bot.special_useful(bloom, 100.0))
	var bark: Player = _eden(w[0], w[1], &"bark_skin", 3)
	assert_true(bot.special_useful(bark, 200.0))
	assert_false(bot.special_useful(bark, 900.0), "no fight yet")


func test_bloom_heal_is_announced_from_the_synced_hp_inside_the_moss() -> void:
	var s: Array = _bloom_setup()
	var p: Player = s[2]
	await wait_physics_frames(2)
	var got: Array[int] = []
	p.healed.connect(func(_u: Player, amount: int) -> void: got.append(amount))
	p.stats.hp = 50
	_press_special(p, Vector2.RIGHT)
	_idle(p, 2)
	p._special_fx.sync(p)  # a sync inside the moss...
	p.stats.hp = 53  # ...then the server's heal arrives
	p._special_fx.sync(p)
	assert_eq(got, [3], "a +3 for the 3 hp it healed")
	p.stats.hp = 40  # damage is not a heal
	p._special_fx.sync(p)
	assert_eq(got.size(), 1)
