extends GutTest
## One distinct hook per weapon: chain, boomerang, ricochet growth, burn, backstab, split, spin-up, 3rd-shot crit,
## beam ramp, hammer slow, blade parry.

const SHOOTER: int = 1
const TARGET: int = 2
const OTHER: int = 3
const SEED: int = 5

var world: Node2D
var pool: ProjectilePool
var catalog: WeaponCatalog
var characters: CharacterCatalog
var hits: Array = []


func before_each() -> void:
	world = Node2D.new()
	add_child_autofree(world)
	pool = ProjectilePool.new()
	world.add_child(pool)
	catalog = WeaponCatalog.load_all()
	characters = CharacterCatalog.load_all()
	hits = []
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, victim: int, dmg: int, crit: bool, _a: Vector2) -> void:
		hits.append({"victim": victim, "dmg": dmg, "crit": crit}))


func _player(id: int, at: Vector2) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, catalog.resolve([&"pistol"] as Array[StringName]), null, pool, SEED,
		characters.get_character(&"flicker"))
	world.add_child(p)
	p.global_position = at
	pool.targets.append(p)
	return p


func _wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	world.add_child(body)


func _w(id: StringName) -> WeaponData:
	return catalog.get_weapon(id)


func _active() -> Array[ProjectilePool.Slot]:
	var out: Array[ProjectilePool.Slot] = []
	for s: ProjectilePool.Slot in pool.debug_slots():
		if s.active:
			out.append(s)
	return out


func test_arc_zapper_chains_once_to_a_near_enemy_for_70_percent() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	_player(TARGET, Vector2(300, 300))
	_player(OTHER, Vector2(300, 400))
	_player(4, Vector2(300, 600))
	var w: WeaponData = _w(&"bolt_zapper")
	assert_eq(w.bounces, 0, "no wall bounce")
	var arcs: Array = []
	pool.chained.connect(func(from: Vector2, to: Vector2, _c: Color) -> void: arcs.append([from, to]))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, shooter.global_position, Vector2.RIGHT, w, SEED)
	await wait_physics_frames(30)
	assert_eq(hits.size(), 2, "one hit plus one jump, none to the far player")
	assert_eq(hits[0].victim, TARGET)
	assert_eq(hits[1].victim, OTHER)
	assert_eq(hits[1].dmg, roundi(hits[0].dmg * 0.7))
	assert_eq(arcs.size(), 1)


func test_shuriken_returns_and_hits_on_the_way_out_and_back() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	_player(TARGET, Vector2(300, 300))
	var w: WeaponData = _w(&"shadow_shuriken")
	assert_true(w.boomerang)
	assert_eq(w.bounces, 0)
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, shooter.global_position, Vector2.RIGHT, w, SEED)
	var turned: bool = false
	for i: int in 150:
		await wait_physics_frames(1)
		for s: ProjectilePool.Slot in _active():
			turned = turned or s.returning
		if _active().is_empty():
			break
	assert_true(turned, "it turned around")
	assert_true(_active().is_empty(), "and was caught by the thrower")
	assert_eq(hits.size(), 2, "once out, once back")


func test_ricochet_gains_damage_per_wall_bounce() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	_wall(Vector2(300, 300), Vector2(20, 400))
	_wall(Vector2(-100, 300), Vector2(20, 400))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, shooter.global_position, Vector2.RIGHT, _w(&"twinshot_revolver"), SEED)
	var seen: Array[int] = []
	for i: int in 120:
		await wait_physics_frames(1)
		for s: ProjectilePool.Slot in _active():
			if s.bounced > 0 and not seen.has(s.bounced):
				seen.append(s.bounced)
				assert_eq(s.damage, roundi(s.base_damage * (1.0 + 0.4 * s.bounced)))
	assert_eq(seen.size(), 2, "two bounces, each stronger")


func test_burn_ticks_refreshes_and_does_not_stack() -> void:
	var stats := PlayerStats.new()
	stats.ignite(1.5, 2, 0.25, 7)
	var ticks: int = 0
	for i: int in 120:
		stats.tick(1.0 / 60.0)
		ticks += stats.burn_due
	assert_eq(ticks, 6, "2 dmg x 6 ticks over 1.5 s")
	assert_eq(stats.burn_remaining, 0.0)
	stats.ignite(1.5, 2, 0.25, 7)
	stats.tick(0.5)
	stats.ignite(1.5, 2, 0.25, 7)
	assert_almost_eq(stats.burn_remaining, 1.5, 0.001)


func test_ember_palm_ignites_and_burn_damages_the_victim() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var target: Player = _player(TARGET, Vector2(250, 300))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, shooter.global_position, Vector2.RIGHT, _w(&"flint_palm"), SEED)
	await wait_physics_frames(20)
	assert_gt(target.stats.burn_remaining, 0.0)
	assert_eq(target.stats.burn_attacker, SHOOTER)
	var before: int = target.stats.hp + target.stats.armor
	var total: int = 0
	for i: int in 100:
		target.simulate(InputFrame.new(), 1.0 / 60.0)
		total = before - (target.stats.hp + target.stats.armor)
	assert_gte(total, 10, "burn ticks hurt (2 per 0.25 s)")
	assert_lte(total, 6 * DmgExpect.hi(2), "6 ticks of the scaled burn damage")


func test_kunai_backstab_is_a_crit_only_from_behind() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var target: Player = _player(TARGET, Vector2(300, 300))
	await wait_physics_frames(2)
	target.facing = Vector2.RIGHT  # his back is to the shooter
	pool.fire_shot(SHOOTER, 1, shooter.global_position, Vector2.RIGHT, _w(&"flicker_kunai"), SEED)
	await wait_physics_frames(20)
	var behind: Array = hits.duplicate()
	hits.clear()
	target.facing = Vector2.LEFT
	pool.fire_shot(SHOOTER, 3, shooter.global_position, Vector2.RIGHT, _w(&"flicker_kunai"), SEED)
	await wait_physics_frames(20)
	assert_gt(behind.size(), 0)
	assert_gt(hits.size(), 0)
	assert_true(behind[0].crit, "backstab shows as a crit")
	assert_between(behind[0].dmg, roundi(DmgExpect.lo(6) * 1.75), roundi(DmgExpect.hi(6) * 1.75))
	assert_lt(hits[0].dmg, behind[0].dmg)


func test_seed_sling_bursts_into_three_shards_on_a_wall() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	_wall(Vector2(300, 300), Vector2(20, 400))
	await wait_physics_frames(2)
	var w: WeaponData = _w(&"eden_sling")
	pool.fire_shot(SHOOTER, 1, shooter.global_position, Vector2.RIGHT, w, SEED)
	var shards: Array[ProjectilePool.Slot] = []
	for i: int in 60:
		await wait_physics_frames(1)
		shards.clear()
		for s: ProjectilePool.Slot in _active():
			if s.pellet >= Constants.SPLIT_PELLET_BASE:
				shards.append(s)
		if not shards.is_empty():
			break
	assert_eq(shards.size(), 3)
	for s: ProjectilePool.Slot in shards:
		assert_eq(s.split_count, 0, "shards don't split again")
		assert_between(s.damage, roundi(DmgExpect.lo(w.damage) * 0.35), roundi(DmgExpect.hi(w.damage) * 0.35))
		assert_lt(s.vel.x, 0.0, "fanning back off the wall")


func test_smg_spins_up_and_resets_when_released() -> void:
	var stats := PlayerStats.new(100, 50, 10000)
	var ws := WeaponState.new(_w(&"smg"))
	var first: float = 0.0
	var last: float = 0.0
	var elapsed: float = 0.0
	var fires: int = 0
	while elapsed < 2.0:
		if ws.try_fire(stats):
			fires += 1
			last = ws.cooldown
			if fires == 1:
				first = ws.cooldown
		ws.tick(1.0 / 60.0)
		elapsed += 1.0 / 60.0
	assert_almost_eq(first, 0.16, 0.001)
	assert_almost_eq(last, 0.08, 0.001)
	for i: int in 30:
		ws.tick(1.0 / 60.0)
	assert_eq(ws.spin, 0.0, "released")
	assert_true(ws.try_fire(stats))
	assert_almost_eq(ws.cooldown, 0.16, 0.001)


func test_pocket_blaster_every_third_shot_is_a_guaranteed_crit() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var w: WeaponData = _w(&"pistol")
	var crits: Array[bool] = []
	for seq: int in 6:
		pool.fire_shot(SHOOTER, seq + 1, shooter.global_position, Vector2.RIGHT, w, SEED)
		var newest: ProjectilePool.Slot = null
		for s: ProjectilePool.Slot in _active():
			if s.shot_seq == seq + 1:
				newest = s
		crits.append(newest.crit)
	assert_true(crits[2] and crits[5], "3rd and 6th")
	assert_eq(w.crit_every, 3)


func test_prism_lance_ramps_on_one_target_and_resets_on_switch() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	_player(TARGET, Vector2(300, 300))
	await wait_physics_frames(2)
	var w: WeaponData = _w(&"laser")
	for i: int in 10:
		pool.fire_shot(SHOOTER, i + 1, shooter.global_position, Vector2.RIGHT, w, SEED)
		pool._physics_process(0.15)
	assert_between(hits[0].dmg, DmgExpect.lo(w.damage), DmgExpect.hi(w.damage))
	assert_gt(hits[9].dmg, w.damage * 1.5)
	assert_lte(hits[9].dmg, DmgExpect.hi(w.damage * 2))
	assert_almost_eq(pool._beam_ramp(SHOOTER, OTHER, w), 1.0, 0.001, "a new target starts over")


func test_oath_hammer_slows_briefly() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var target: Player = _player(TARGET, Vector2(156, 300))
	await wait_physics_frames(2)
	var w: WeaponData = _w(&"warden_hammer")
	pool.fire_shot(SHOOTER, 1, shooter.global_position, Vector2.RIGHT, w, SEED)
	assert_almost_eq(target.stats.slow_remaining, 0.3, 0.001)
	assert_lt(target.stats.slow_factor, 1.0)
	assert_gte(w.knockback, 320.0)


func test_arc_blade_parries_a_shot_back_at_the_shooter() -> void:
	_player(SHOOTER, Vector2(100, 200))
	var defender: Player = _player(TARGET, Vector2(300, 300))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(250, 300), Vector2.RIGHT, _w(&"pistol"), SEED)
	pool.fire_shot(TARGET, 1, defender.global_position, Vector2.LEFT, _w(&"sword"), SEED)
	var s: ProjectilePool.Slot = _active()[0]
	assert_eq(s.attacker_id, TARGET, "now the parrier's")
	assert_lt(s.vel.x, 0.0)
	assert_lt(s.vel.y, 0.0, "aimed up at the shooter, not just the way he faces")
