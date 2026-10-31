extends GutTest
## Skills (shared dash, specials: barrier / dual wield / Great Ape) and movement integration.

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
	assert_eq(characters.ordered.size(), 6)
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
	for id: StringName in [&"dash", &"barrier", &"dual_wield", &"great_ape", &"blink", &"smoke_bomb",
			&"fan_of_blades", &"shadow_clones"]:
		var sk: SkillData = skills.get_skill(id)
		assert_not_null(sk, String(id))
		assert_not_null(sk.icon, String(id))
		assert_true(sk.cooldown > 0.0 and sk.duration > 0.0, String(id))
		kinds.append(sk.kind)
	for kind: int in SkillData.Kind.values():
		assert_true(kinds.has(kind), "no skill of kind %d" % kind)


func test_dash_is_everyones_and_not_a_special() -> void:
	var dash: SkillData = skills.dash()
	assert_false(dash.special)
	for c: CharacterData in characters.ordered:
		assert_true(c.can_use_skill(dash), String(c.id))
		assert_false(skills.specials_for(c).has(dash), String(c.id))


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


func test_dual_wield_window() -> void:
	var dual: SkillData = skills.get_skill(&"dual_wield")
	var skill := CharacterSkill.new(dual)
	assert_true(skill.try_activate(Vector2.RIGHT, Vector2.ZERO, PlayerStats.new()))
	assert_true(skill.is_dual_wielding())
	skill.tick(dual.duration + 0.01)
	assert_false(skill.is_dual_wielding())


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
	assert_eq(p.special.data.id, &"barrier", "Warden's Barrier is kept: Twinshot can use it")


# --- specials on a player ------------------------------------------------------

func _player(c: CharacterData) -> Player:
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, null, 0, c)
	add_child_autofree(p)
	return p


func test_great_ape_halves_damage_and_swaps_to_fists() -> void:
	var p: Player = _player(characters.get_character(&"wukong"))
	var ape: SkillData = skills.get_skill(&"great_ape")
	assert_eq(p.special.data, ape, "Wukong's signature special")
	assert_ne(p.held_weapon().data.id, &"ape_fists")
	assert_true(p.special.try_activate(Vector2.RIGHT, Vector2.ZERO, p.stats))
	assert_eq(p.held_weapon().data.id, &"ape_fists")
	assert_eq(ape.form_frames().get_frame_count(&"attack"), Constants.SPRITE_ATTACK_FRAMES, "fists swing")
	assert_false(p.character.sprite_frames().has_animation(&"attack"), "no attack strip on plain sheets")
	var before: int = p.stats.hp + p.stats.armor
	p.take_hit(40, false, Vector2.ZERO, 2)
	assert_eq(before - (p.stats.hp + p.stats.armor), roundi(40 * ape.form_damage_scale))
	p.special.tick(ape.duration + 0.01)
	assert_false(p.special.is_transformed())
	assert_ne(p.held_weapon().data.id, &"ape_fists", "back to the loadout")


func test_switching_character_keeps_a_usable_special() -> void:
	var p: Player = _player(twinshot)
	p.set_special(skills.get_skill(&"barrier"))
	p.set_character(warden)
	assert_eq(p.special.data.id, &"barrier", "Warden can use Barrier too")
	p.set_character(flicker)
	assert_eq(p.special.data, skills.specials_for(flicker)[0], "Flicker can't: falls back to a default")



# --- Flicker's ninja specials ------------------------------------------------------

func _wall(world: Node2D, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	world.add_child(body)


func _flicker_in(world: Node2D, special: StringName, pool: ProjectilePool = null) -> Player:
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3, flicker)
	world.add_child(p)
	p.set_special(skills.get_skill(special))
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
	for id: StringName in [&"blink", &"smoke_bomb", &"fan_of_blades", &"dual_wield"]:
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
	p.special.reset()
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
	p.special.active_remaining -= 2.0  # two seconds in
	var points: PackedVector2Array = p.clone_points()
	assert_eq(points.size(), skills.get_skill(&"shadow_clones").clone_count)
	for c: Vector2 in points:
		assert_lt(c.x, 300.0, "clones don't run through walls")
		assert_gt(c.distance_to(Vector2(150, 200)), 50.0, "clones moved away")
	assert_eq(p.clone_points(), points, "deterministic: same state, same clones")


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
	assert_true(p.special.try_activate(Vector2.RIGHT, Vector2.ZERO, p.stats))
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



func test_weapon_base_stays_below_the_face_at_every_aim() -> void:
	for deg: int in range(-180, 180, 5):
		var a: float = deg_to_rad(deg)
		var flip: float = -1.0 if cos(a) < 0.0 else 1.0
		var base_back: Vector2 = Vector2(Player.WEAPON_BASE.position.x, Player.WEAPON_BASE.position.y * flip)
		var base_top: float = Player.hand_y(a) + (base_back * Constants.SPRITE_SCALE).rotated(a).y
		assert_gte(base_top, Player.FACE_BOTTOM_Y - 0.01, "aim %d deg" % deg)
	# Aiming straight up the weapon hides behind the body, so it can sit at the face's edge.
	assert_almost_eq(Player.hand_y(-PI / 2.0), Player.FACE_BOTTOM_Y, 0.01)
