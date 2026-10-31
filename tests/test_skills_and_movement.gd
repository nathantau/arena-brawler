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
	assert_eq(characters.ordered.size(), 4, "Gunnar and Warden are benched")
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
	for id: StringName in [&"dash", &"barrier", &"great_ape", &"blink", &"smoke_bomb",
			&"fan_of_blades", &"shadow_clones", &"blossom_ward", &"grapple_kunai", &"vine_swing", &"eruption"]:
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
	for id: StringName in [&"blink", &"smoke_bomb", &"fan_of_blades", &"grapple_kunai"]:
		assert_has(ids, id)
	for c: CharacterData in [warden, twinshot]:
		assert_false(c.can_use_skill(skills.get_skill(&"blink")), String(c.id))


func test_blink_hops_and_walls_stop_it() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	_wall(world, Vector2(400, 300), Vector2(20, 400))
	var p: Player = _flicker_in(world, &"blink")
	p.global_position = Vector2(100, 300)
	await wait_physics_frames(2)
	_press_special(p, Vector2.RIGHT, Vector2.RIGHT)
	assert_gt(p.global_position.x, 100.0 + skills.get_skill(&"blink").blink_distance * 0.9, "hopped forward")
	assert_true(p.stats.is_invulnerable())
	p.skills[1].reset()
	_press_special(p, Vector2.RIGHT, Vector2.RIGHT)
	assert_lt(p.global_position.x, 400.0 - 10.0, "stopped at the wall")


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
	for i: int in 15:
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
