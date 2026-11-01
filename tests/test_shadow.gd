extends GutTest
## Shadow's kit: Shadow Step (untargetable puddle, strike on emerging), Gloom Hound (summon that chases and bites), Shadow Bind
## (a line of shadow that stuns the first enemy it reaches) and the stun status itself.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var skills: SkillCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	skills = SkillCatalog.shared()


func _world() -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	return [world, pool]


func _shadow(world: Node2D, pool: ProjectilePool, special: StringName, id: int = 1, at: Vector2 = Vector2(100, 300),
		who: StringName = &"shadow") -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(who))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(special))
	p.global_position = at
	if pool != null:
		pool.targets.append(p)
	return p


func _foe(world: Node2D, pool: ProjectilePool, id: int, at: Vector2) -> Player:
	return _shadow(world, pool, &"dash", id, at, &"flicker")


func _press(p: Player, aim: Vector2, move: Vector2 = Vector2.ZERO, seq: int = 10) -> void:
	var f := InputFrame.new()
	f.seq = seq
	f.aim_vec = aim
	f.move_vec = move
	f.special = true
	p.simulate(f, DT)


func _run(p: Player, frames: int, move: Vector2 = Vector2.ZERO, fire: bool = false, replay: bool = false) -> void:
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 100 + i
		f.move_vec = move
		f.fire = fire
		p.simulate(f, DT, replay)


func _hits(pool: ProjectilePool) -> Array:
	var hits: Array = []
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, victim: int, dmg: int, _c: bool, _a: Vector2) -> void:
		hits.append([victim, dmg]))
	return hits


func _hp(p: Player) -> int:
	return p.stats.hp + p.stats.armor


# --- the kit ---------------------------------------------------------------------------------------------------------

func test_the_kit_is_shadows_own() -> void:
	var shadow: CharacterData = characters.get_character(&"shadow")
	assert_not_null(shadow)
	assert_eq(shadow.display_name, "Shadow")
	assert_true(shadow.in_rotation)
	assert_eq(shadow.signature_weapon.id, &"shadow_shuriken")
	assert_eq(shadow.signature_skill.id, &"shadow_step")
	var expect: Dictionary = {&"shadow_step": SkillData.Kind.STEP, &"gloom_hound": SkillData.Kind.HOUND,
		&"shadow_bind": SkillData.Kind.BIND}
	for id: StringName in expect:
		var d: SkillData = skills.get_skill(id)
		assert_eq(d.kind, expect[id], String(id))
		assert_true(d.kind >= 30, "kinds start at 30")
		assert_not_null(d.icon, String(id))
		assert_lte(d.blurb.length(), 20, String(id))
		assert_true(d.special and d.tags.has(&"shadow"))
		for c: CharacterData in characters.ordered:
			assert_eq(c.can_use_skill(d), c.id == &"shadow", "%s for %s" % [id, c.id])
		assert_true(skills.specials_for(shadow).has(d))
	assert_eq(int(SkillData.Kind.STEP), 30)
	assert_eq(int(SkillData.Kind.HOUND), 31)
	assert_eq(int(SkillData.Kind.BIND), 32)
	for k: int in [30, 31, 32]:
		assert_ne(Sfx.skill_sound(k), &"dash", "kind %d has its own sound" % k)
		assert_true(Sfx.RECIPES.has(Sfx.skill_sound(k)))


# --- Shadow Step -----------------------------------------------------------------------------------------------------

func test_step_is_untargetable_fast_and_cannot_fire() -> void:
	var w: Array = _world()
	var p: Player = _shadow(w[0], w[1], &"shadow_step")
	var walker: Player = _shadow(w[0], w[1], &"dash", 2, Vector2(100, 700))
	var d: SkillData = skills.get_skill(&"shadow_step")
	await wait_physics_frames(2)
	_run(walker, 30, Vector2.RIGHT)
	var normal: float = walker.velocity.x
	assert_true(p.can_be_hit())
	_press(p, Vector2.RIGHT, Vector2.RIGHT)
	assert_false(p.can_be_hit(), "unhittable as a puddle")
	assert_true(p.is_hidden(), "enemy auto-aim and bots skip him")
	assert_not_null(p.active_skill(SkillData.Kind.STEP))
	var foe: Player = _foe(w[0], w[1], 3, Vector2(100, 200))
	assert_eq(p.take_hit(30, false, Vector2.ZERO, 3), 0, "bullets do nothing to him")
	assert_eq(_hp(p), p.stats.max_hp + p.stats.max_armor)
	watch_signals(p)
	_run(p, 30, Vector2.RIGHT, true)
	assert_signal_not_emitted(p, "shot_fired", "a puddle cannot fire")
	assert_almost_eq(p.velocity.x, normal * d.step_speed_scale, 1.0, "faster than walking")
	assert_gt(d.step_speed_scale, 1.0)
	# ...and out again: hit again and can fire
	_run(p, ceili(d.duration / DT), Vector2.RIGHT)
	assert_false(p.skills[1].is_active())
	assert_true(p.can_be_hit(), "visible and hittable again")
	assert_false(p.is_hidden())
	assert_gt(p.skills[1].cooldown_remaining, 0.0)
	assert_eq(foe.stats.hp, foe.stats.max_hp)


func test_step_keeps_gliding_and_slides_under_walls_then_surfaces_clear() -> void:
	var w: Array = _world()
	var world: Node2D = w[0]
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 400)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.add_child(Arena.feet_strip([Rect2(-shape.size * 0.5, shape.size)] as Array[Rect2]))
	body.position = Vector2(400, 300)
	world.add_child(body)
	var p: Player = _shadow(world, w[1], &"shadow_step")
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)  # no stick: it glides along the aim
	_run(p, 60)
	assert_gt(p.global_position.x, 200.0, "glides on its own")
	_run(p, 90)
	assert_gt(p.global_position.x, 410.0, "the puddle slides under the wall")
	var feet := PhysicsShapeQueryParameters2D.new()
	feet.collision_mask = Constants.LAYER_WALL_FEET
	var circle := CircleShape2D.new()
	circle.radius = Constants.PLAYER_RADIUS
	feet.shape = circle
	feet.transform = Transform2D(0.0, p.global_position)
	assert_true(p.get_world_2d().direct_space_state.intersect_shape(feet, 1).is_empty(), "and comes up on free floor")
	assert_eq(p.collision_mask, Constants.LAYER_WALL_FEET, "walls solid again")


func test_freezing_mid_step_surfaces_him_out_of_the_wall() -> void:
	# The round ends (results / countdown freeze) while he is a puddle under a wall: no stuck-in-the-wall body.
	var w: Array = _world()
	var world: Node2D = w[0]
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120, 400)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.add_child(Arena.feet_strip([Rect2(-shape.size * 0.5, shape.size)] as Array[Rect2]))
	body.position = Vector2(400, 300)
	world.add_child(body)
	var p: Player = _shadow(world, w[1], &"shadow_step")
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	var guard: int = 0
	while p.global_position.x < 400.0 and guard < 200:  # glide until he is in the middle of the wall
		_run(p, 1)
		guard += 1
	assert_not_null(p.active_skill(SkillData.Kind.STEP), "still a puddle")
	p.frozen = true
	_run(p, 1)
	assert_null(p.active_skill(SkillData.Kind.STEP), "the freeze ends the step")
	var feet := PhysicsShapeQueryParameters2D.new()
	feet.collision_mask = Constants.LAYER_WALL_FEET
	var circle := CircleShape2D.new()
	circle.radius = Constants.PLAYER_RADIUS
	feet.shape = circle
	feet.transform = Transform2D(0.0, p.global_position)
	assert_true(p.get_world_2d().direct_space_state.intersect_shape(feet, 1).is_empty(), "on free floor, not inside the wall")


## Steps from (100, 300) to the end of the puddle, with a wall block of `width` centred on `wall_x` (none if < 0) and a foe at
## `foe_at` (none if INF). Returns [where he ends up, the foe's hp + armor].
func _step_to_the_end(wall_x: float, width: float, foe_at: Vector2) -> Array:
	var w: Array = _world()
	var world: Node2D = w[0]
	if wall_x >= 0.0:
		var body := StaticBody2D.new()
		body.collision_layer = Constants.LAYER_WALLS
		var shape := RectangleShape2D.new()
		shape.size = Vector2(width, 400)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		body.add_child(cs)
		body.add_child(Arena.feet_strip([Rect2(-shape.size * 0.5, shape.size)] as Array[Rect2]))
		body.position = Vector2(wall_x, 300)
		world.add_child(body)
	var p: Player = _shadow(world, w[1], &"shadow_step")
	var foe: Player = _foe(world, w[1], 2, foe_at) if foe_at != Vector2.INF else null
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	_run(p, 90)
	return [p.global_position, _hp(foe) if foe != null else 0]


func test_step_strike_lands_where_he_surfaces_not_inside_the_wall() -> void:
	var open: Array = await _step_to_the_end(-1.0, 0.0, Vector2.INF)
	var end_x: float = open[0].x
	# A wall block centred on where the puddle ends: he comes up on its far side, about 100 px from where the glide stopped.
	var empty: Array = await _step_to_the_end(end_x, 200.0, Vector2.INF)
	var up: Vector2 = empty[0]
	assert_gt(up.distance_to(open[0]), 90.0, "he surfaced well away from where the glide ended")
	var d: SkillData = skills.get_skill(&"shadow_step")
	var full: int = characters.get_character(&"flicker").max_hp + characters.get_character(&"flicker").max_armor
	var hit: Array = await _step_to_the_end(end_x, 200.0, up + Vector2(0, -30))
	assert_eq(hit[1], full - d.step_damage, "the foe next to where he came up is struck")


func test_step_strikes_where_he_emerges_only() -> void:
	var w: Array = _world()
	var p: Player = _shadow(w[0], w[1], &"shadow_step")
	var d: SkillData = skills.get_skill(&"shadow_step")
	var near: Player = _foe(w[0], w[1], 2, Vector2(2000, 2000))
	var far: Player = _foe(w[0], w[1], 3, Vector2(2000, 2000))
	var along: Player = _foe(w[0], w[1], 4, Vector2(2000, 2000))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p, Vector2.RIGHT, Vector2.RIGHT)
	_run(p, 40, Vector2.RIGHT)
	along.global_position = p.global_position  # he passes through as a puddle: no damage on the way
	_run(p, 10, Vector2.RIGHT)
	assert_eq(hits.size(), 0, "nothing while he travels")
	assert_eq(along.stats.hp, along.stats.max_hp)
	along.global_position = Vector2(2000, 2000)
	while p.skills[1].active_remaining > 1.5 * DT:
		_run(p, 1, Vector2.RIGHT)
	near.global_position = p.global_position + Vector2(d.step_radius * 0.5, 0.0)
	far.global_position = p.global_position + Vector2(0.0, d.step_radius + 80.0)
	_run(p, 3, Vector2.RIGHT)
	assert_false(p.skills[1].is_active())
	assert_eq(hits.size(), 1, "one strike, one victim")
	assert_eq(hits[0], [2, d.step_damage])
	assert_eq(far.stats.hp, far.stats.max_hp, "out of reach")
	assert_eq(p.stats.hp, p.stats.max_hp, "not himself")
	assert_gt(near.velocity.length(), 0.0, "thrown back")


func test_step_replay_matches_and_hurts_nobody() -> void:
	var w: Array = _world()
	var a: Player = _shadow(w[0], w[1], &"shadow_step")
	var b: Player = _shadow(w[0], w[1], &"shadow_step", 5, Vector2(100, 300))
	w[1].targets.erase(b)
	var foe: Player = _foe(w[0], w[1], 2, Vector2(2000, 2000))
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	var hits: Array = _hits(w[1])
	_press(a, Vector2.RIGHT, Vector2.RIGHT)
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.move_vec = Vector2.RIGHT
	f.special = true
	b.simulate(f, DT, true)
	f.special = false
	for i: int in 100:
		a.simulate(f, DT)
		b.simulate(f, DT, true)
	foe.global_position = b.global_position  # (the real one's strike already went off elsewhere)
	assert_almost_eq(b.global_position, a.global_position, Vector2(0.01, 0.01))
	assert_almost_eq(b.skills[1].active_remaining, a.skills[1].active_remaining, 0.0001)
	assert_eq(hits.size(), 0, "nobody was near the real strike; the replay hurt nobody")


# --- Gloom Hound -----------------------------------------------------------------------------------------------------

func test_hound_rises_ahead_chases_the_nearest_enemy_and_bites() -> void:
	var w: Array = _world()
	var p: Player = _shadow(w[0], w[1], &"gloom_hound")
	var d: SkillData = skills.get_skill(&"gloom_hound")
	var near: Player = _foe(w[0], w[1], 2, Vector2(100 + 420, 300))
	var far: Player = _foe(w[0], w[1], 3, Vector2(100 + 480, 120))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p, Vector2.RIGHT)
	var slot: CharacterSkill = p.skills[1]
	assert_almost_eq(slot.anchor, Vector2(100, 300) + Vector2.RIGHT * d.hound_distance, Vector2(0.5, 0.5), "rises ahead along the aim")
	var start_x: float = slot.anchor.x
	_run(p, ceili(d.hound_rise_time / DT) - 3)
	assert_eq(slot.anchor.x, start_x, "still rising: no moving")
	assert_eq(hits.size(), 0)
	_run(p, 60)
	assert_gt(slot.anchor.x, start_x + 100.0, "it runs at the nearest enemy")
	assert_almost_eq(slot.direction.x, 1.0, 0.2, "heading at it")
	_run(p, 4 * 60)
	assert_lt(slot.anchor.distance_to(near.global_position), d.hound_bite_radius + 2.0, "on top of its prey")
	assert_lt(_hp(near), near.stats.max_hp + near.stats.max_armor, "it bites")
	assert_eq(far.stats.hp, far.stats.max_hp, "only the nearest is chased")
	for h: Array in hits:
		assert_eq(h[0], 2)
		assert_eq(h[1], d.hound_damage)
	var bitten: int = hits.size()
	assert_gte(bitten, 2, "bites more than once")
	assert_lte(bitten, 1 + ceili(d.duration / d.hound_bite_interval), "with a cooldown between bites")


func test_hound_expires_and_is_no_target() -> void:
	var w: Array = _world()
	var p: Player = _shadow(w[0], w[1], &"gloom_hound")
	var d: SkillData = skills.get_skill(&"gloom_hound")
	var foe: Player = _foe(w[0], w[1], 2, Vector2(2000, 2000))
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	assert_eq(w[1].targets.size(), 2, "the hound is not a player: nothing to auto-aim at")
	_run(p, ceili(d.duration / DT) + 5)
	assert_false(p.skills[1].is_active(), "melts away")
	var at: Vector2 = p.skills[1].anchor
	foe.global_position = at
	_run(p, 120)
	assert_eq(foe.stats.hp, foe.stats.max_hp, "a gone hound bites nobody")
	assert_gt(p.skills[1].cooldown_remaining, 0.0)


func test_hound_ignores_hidden_enemies_and_walls_stop_it() -> void:
	var w: Array = _world()
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 600)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.add_child(Arena.feet_strip([Rect2(-shape.size * 0.5, shape.size)] as Array[Rect2]))
	body.position = Vector2(300, 300)
	w[0].add_child(body)
	var p: Player = _shadow(w[0], w[1], &"gloom_hound")
	var behind: Player = _foe(w[0], w[1], 2, Vector2(500, 300))
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	var start: Vector2 = p.skills[1].anchor
	_run(p, 200)
	assert_eq(p.skills[1].anchor, start, "nothing in sight past the wall: it stays")
	assert_eq(behind.stats.hp, behind.stats.max_hp)
	assert_null(p.hound_target(start, 600.0))


func test_hound_dies_with_its_owner() -> void:
	var w: Array = _world()
	var p: Player = _shadow(w[0], w[1], &"gloom_hound")
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	assert_true(p.skills[1].is_active())
	p.take_hit(9999, false, Vector2.ZERO, 7)
	assert_false(p.skills[1].is_active())


# --- Shadow Bind + stun ----------------------------------------------------------------------------------------------

func _bind_setup() -> Array:
	var w: Array = _world()
	var p: Player = _shadow(w[0], w[1], &"shadow_bind")
	return [w[0], w[1], p]


func test_bind_stuns_the_first_enemy_only() -> void:
	var s: Array = _bind_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"shadow_bind")
	var first: Player = _foe(s[0], s[1], 2, Vector2(100 + 150, 300))
	var second: Player = _foe(s[0], s[1], 3, Vector2(100 + 250, 300))
	var off: Player = _foe(s[0], s[1], 4, Vector2(100 + 150, 300 + 150))
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	assert_false(first.stats.is_stunned(), "it has to travel there first (telegraphed)")
	_run(p, 6)
	assert_false(first.stats.is_stunned(), "not yet: ~0.2 s to reach 150 px")
	_run(p, 20)
	assert_true(first.stats.is_stunned(), "caught")
	assert_almost_eq(first.stats.stun_remaining, d.bind_stun, 0.35)
	assert_false(second.stats.is_stunned(), "only the first one")
	assert_false(off.stats.is_stunned(), "off the line")
	assert_eq(first.stats.hp, first.stats.max_hp, "no damage: control only")
	assert_true(p.skills[1].is_active(), "the tether holds")
	assert_almost_eq(p.skills[1].direction.length(), 150.0, 6.0, "the line ends on him")
	_run(p, ceili(d.duration / DT))
	assert_false(p.skills[1].is_active())
	assert_gt(p.skills[1].cooldown_remaining, d.bind_stun * 5.0, "longish cooldown")
	assert_false(second.stats.is_stunned())


func test_bind_is_stopped_by_walls_and_misses_cleanly() -> void:
	var s: Array = _bind_setup()
	var p: Player = s[2]
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 600)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.add_child(Arena.feet_strip([Rect2(-shape.size * 0.5, shape.size)] as Array[Rect2]))
	body.position = Vector2(250, 300)
	s[0].add_child(body)
	var behind: Player = _foe(s[0], s[1], 2, Vector2(320, 300))
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	assert_lt(p.skills[1].direction.length(), 150.0, "the line is cut short by the wall")
	_run(p, 90)
	assert_false(behind.stats.is_stunned(), "behind the wall")
	assert_false(p.skills[1].is_active(), "a miss just ends")
	assert_gt(p.skills[1].cooldown_remaining, 0.0)


func test_bind_has_a_range() -> void:
	var s: Array = _bind_setup()
	var p: Player = s[2]
	var d: SkillData = skills.get_skill(&"shadow_bind")
	var out: Player = _foe(s[0], s[1], 2, Vector2(100 + d.bind_range + 80.0, 300))
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	_run(p, 120)
	assert_false(out.stats.is_stunned(), "out of range")


func test_bind_skips_whoever_cannot_be_hit() -> void:
	var s: Array = _bind_setup()
	var p: Player = s[2]
	var ghost: Player = _foe(s[0], s[1], 2, Vector2(100 + 100, 300))
	var real: Player = _foe(s[0], s[1], 3, Vector2(100 + 200, 300))
	ghost.stats.invulnerable_time = 5.0
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	_run(p, 40)
	assert_false(ghost.stats.is_stunned(), "an untargetable fighter slips through the line")
	assert_true(real.stats.is_stunned())


func test_stun_blocks_move_fire_and_specials_then_wears_off() -> void:
	var w: Array = _world()
	var v: Player = _shadow(w[0], w[1], &"shadow_step", 2, Vector2(300, 300), &"flicker")
	v.set_skill(1, skills.get_skill(&"smoke_bomb"))
	await wait_physics_frames(2)
	v.stats.apply_stun(0.5)
	var at: Vector2 = v.global_position
	watch_signals(v)
	var f := InputFrame.new()
	f.seq = 50
	f.move_vec = Vector2.RIGHT
	f.fire = true
	f.special = true
	f.skill = true
	for i: int in 20:
		f.seq += 1
		v.simulate(f, DT)
		f.special = false
		f.skill = false
	assert_eq(v.global_position, at, "can't move")
	assert_signal_not_emitted(v, "shot_fired", "can't fire")
	assert_signal_not_emitted(v, "skill_used", "can't use a special")
	assert_false(v.skills[1].is_active())
	assert_eq(v.skills[1].cooldown_remaining, 0.0, "nothing was spent")
	f.fire = false
	for i: int in 30:
		v.simulate(f, DT)
	assert_false(v.stats.is_stunned(), "wears off")
	assert_gt(v.global_position.x, at.x, "moves again")
	f.fire = true
	f.special = true
	f.seq += 1
	v.simulate(f, DT)
	assert_signal_emitted(v, "shot_fired", "fires again")
	assert_signal_emitted(v, "skill_used", "specials again")


func test_stun_never_shortens_clears_on_respawn_and_is_synced() -> void:
	var w: Array = _world()
	var a: Player = _shadow(w[0], null, &"shadow_bind")
	var b: Player = _shadow(w[0], null, &"shadow_bind", 2, Vector2(300, 100))
	await wait_physics_frames(2)
	a.stats.apply_stun(1.0)
	a.stats.apply_stun(0.3)
	assert_almost_eq(a.stats.stun_remaining, 1.0, 0.0001, "a shorter stun doesn't replace a longer one")
	var snap: Array = a.capture_state()
	assert_eq(snap.size(), Player.StateField.COUNT)
	assert_true(b.apply_state(snap, WeaponCatalog.load_all(), characters))
	assert_almost_eq(b.stats.stun_remaining, 1.0, 0.0001, "synced to every peer")
	_run(a, 30)
	assert_almost_eq(a.stats.stun_remaining, 0.5, 0.02, "ticks down")
	a.respawn(Vector2(100, 100))
	assert_false(a.stats.is_stunned(), "a respawn clears it")


func test_bind_replay_matches_and_stuns_nobody() -> void:
	var s: Array = _bind_setup()
	var a: Player = s[2]
	var b: Player = _shadow(s[0], null, &"shadow_bind", 5, Vector2(100, 300))
	var foe: Player = _foe(s[0], s[1], 2, Vector2(250, 300))
	var dup: Player = _foe(s[0], s[1], 6, Vector2(250, 330))
	s[1].targets.erase(dup)
	await wait_physics_frames(2)
	var snapshot: Array = a.capture_state()
	_press(a, Vector2.RIGHT)
	assert_true(b.apply_state(snapshot, WeaponCatalog.load_all(), characters))
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	b.simulate(f, DT, true)
	f.special = false
	for i: int in 60:
		a.simulate(f, DT)
		b.simulate(f, DT, true)
	assert_eq(b.skills[1].anchor, a.skills[1].anchor)
	assert_almost_eq(a.skills[1].direction.length(), 150.0, 8.0, "the authority cut the line at the victim")
	assert_almost_eq(b.skills[1].direction.length(), skills.get_skill(&"shadow_bind").bind_range, 0.5,
		"a replay draws the whole line: it never decides who is caught")
	assert_true(foe.stats.is_stunned(), "the authority's victim")
	assert_false(dup.stats.is_stunned(), "the replay stunned nobody")


# --- bots ------------------------------------------------------------------------------------------------------------

func test_bots_rotate_through_his_whole_kit_and_leave_others_alone() -> void:
	var w: Array = _world()
	var p: Player = _shadow(w[0], null, &"shadow_step")
	var brain := BotBrain.new(null, 12)
	var seen: Dictionary = {}
	for i: int in 60:
		p.skills[1].cooldown_remaining = 0.0
		brain._rotate_kit(p)  # ready
		seen[p.skills[1].data.id] = true
		p.skills[1].cooldown_remaining = 5.0
		brain._rotate_kit(p)  # on cooldown
	assert_eq(seen.size(), 3, "all three specials get used")
	var flicker: Player = _shadow(w[0], null, &"shadow_clones", 2, Vector2(300, 300), &"flicker")
	var other := BotBrain.new(null, 3)
	for i: int in 20:
		flicker.skills[1].cooldown_remaining = 0.0
		other._rotate_kit(flicker)
		flicker.skills[1].cooldown_remaining = 5.0
		other._rotate_kit(flicker)
	assert_eq(flicker.skills[1].data.id, &"shadow_clones", "other fighters keep their pick")


func test_step_actually_travels_with_move_input() -> void:
	var w: Array = _world()
	var p: Player = _shadow(w[0], w[1], &"shadow_step")
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT, Vector2.RIGHT)
	var start: float = p.global_position.x
	_run(p, 30, Vector2.RIGHT)
	assert_gt(p.global_position.x - start, 100.0, "the puddle moves")
	var mid: float = p.global_position.x
	_run(p, 30, Vector2.DOWN)
	assert_gt(p.global_position.y, 300.0 + 50.0, "and steers")
