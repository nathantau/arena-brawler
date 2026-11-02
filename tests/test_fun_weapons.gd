extends GutTest
## The five playful shared weapons: Splash Soaker (soak), Bubble Wand (trap), Snowball Cannon (growth + chill), Firework
## Launcher (star burst) and Hive Gun (homing bees).

const SHOOTER: int = 1
const TARGET: int = 2
const OTHER: int = 3
const SEED: int = 5
const DT: float = 1.0 / 60.0

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
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, victim: int, dmg: int, _c: bool, _a: Vector2) -> void:
		hits.append({"victim": victim, "dmg": dmg}))


func _w(id: StringName) -> WeaponData:
	return catalog.get_weapon(id)


func _player(id: int, at: Vector2, team: int = 0) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, catalog.resolve([&"pistol"] as Array[StringName]), null, pool, SEED,
		characters.get_character(&"flicker"))
	world.add_child(p)
	p.global_position = at
	p.team = team
	pool.targets.append(p)
	return p


func _fire(w: StringName, from: Vector2, dir: Vector2, seq: int = 1) -> void:
	pool.fire_shot(SHOOTER, seq, from, dir, _w(w), SEED)


func test_every_new_weapon_is_a_shared_pickup_with_a_card_hook() -> void:
	for id: StringName in [&"splash_soaker", &"bubble_wand", &"snowball_cannon", &"firework_launcher", &"hive_gun"]:
		var w: WeaponData = _w(id)
		assert_not_null(w, String(id))
		assert_true(w.pickup, String(id))
		assert_ne(w.hook, "", String(id))
		var pref: float = BotBrain.preferred_range(w)
		assert_between(pref, BotBrain.PREF_MIN, w.projectile_range, "%s: bots keep a range it can reach" % id)


func test_soak_slows_and_extinguishes_burn() -> void:
	var stats := PlayerStats.new()
	stats.ignite(1.5, 2, 0.25, SHOOTER)
	assert_gt(stats.burn_remaining, 0.0)
	stats.soak(2.0)
	assert_eq(stats.burn_remaining, 0.0, "soaking puts the fire out")
	assert_almost_eq(stats.speed_scale(), Constants.SOAK_SLOW, 0.001)
	stats.ignite(1.5, 2, 0.25, SHOOTER)
	assert_eq(stats.burn_remaining, 0.0, "wet fighters don't catch fire")
	stats.tick(2.1)
	assert_eq(stats.speed_scale(), 1.0, "dries off after 2 s")
	stats.ignite(1.5, 2, 0.25, SHOOTER)
	assert_gt(stats.burn_remaining, 0.0)


func test_a_soaker_droplet_soaks_a_burning_target() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var target: Player = _player(TARGET, Vector2(220, 300))
	target.stats.ignite(1.5, 2, 0.25, SHOOTER)
	await wait_physics_frames(2)
	_fire(&"splash_soaker", shooter.global_position, Vector2.RIGHT)
	await wait_physics_frames(30)
	assert_gt(target.stats.soak_remaining, 1.0, "soaked for about 2 s")
	assert_eq(target.stats.burn_remaining, 0.0, "the burn is out")
	assert_lt(target.stats.hp + target.stats.armor, target.stats.max_hp + target.stats.max_armor, "it still hurts a little")


func test_bubble_trap_roots_and_has_a_per_target_cooldown() -> void:
	var stats := PlayerStats.new()
	assert_true(stats.trap(0.7, 3.0))
	assert_false(stats.trap(0.7, 3.0), "no chain-lock while trapped")
	stats.tick(0.8)
	assert_false(stats.is_trapped())
	assert_false(stats.trap(0.7, 3.0), "still cooling down")
	stats.tick(2.3)
	assert_true(stats.trap(0.7, 3.0), "3 s after the first trap it can catch again")

	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var target: Player = _player(TARGET, Vector2(220, 300))
	await wait_physics_frames(2)
	_fire(&"bubble_wand", shooter.global_position, Vector2.RIGHT, 1)
	for i: int in 90:
		await wait_physics_frames(1)
		if target.stats.trap_remaining > 0.0:
			break
	assert_gt(target.stats.trap_remaining, 0.0, "a bubble caught the target")
	var at: Vector2 = target.global_position
	var input := InputFrame.new()
	input.move_vec = Vector2.DOWN
	for i: int in 10:
		target.simulate(input, DT)
	assert_eq(target.global_position, at, "trapped: can't move")
	watch_signals(target)
	input.fire = true
	input.aim_vec = Vector2.LEFT
	target.simulate(input, DT)
	assert_signal_emitted(target, "shot_fired", "but can still aim and shoot")
	assert_true(target.stats.is_trapped())


func test_snowball_grows_with_distance() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	await wait_physics_frames(2)
	_fire(&"snowball_cannon", shooter.global_position, Vector2.RIGHT)
	var s: ProjectilePool.Slot = null
	for slot: ProjectilePool.Slot in pool.debug_slots():
		if slot.active:
			s = slot
	assert_not_null(s)
	var dmg0: int = s.damage
	var r0: float = s.radius
	await wait_physics_frames(50)
	assert_true(s.active, "still flying")
	assert_gt(s.damage, dmg0, "heavier further out")
	assert_gt(s.radius, r0 * 1.4, "and bigger")
	assert_lte(s.radius, r0 * _w(&"snowball_cannon").grow_max + 0.01)


func test_snowball_hit_chills() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var target: Player = _player(TARGET, Vector2(260, 300))
	await wait_physics_frames(2)
	_fire(&"snowball_cannon", shooter.global_position, Vector2.RIGHT)
	await wait_physics_frames(40)
	assert_almost_eq(target.stats.slow_factor, 0.7, 0.001)
	assert_gt(target.stats.slow_remaining, 0.0)


func test_firework_bursts_into_a_star_of_eight() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	await wait_physics_frames(2)
	_fire(&"firework_launcher", shooter.global_position, Vector2.RIGHT)
	assert_eq(pool.active_count(), 1)
	var frames: int = 0
	while pool.active_count() == 1 and frames < 200:
		await wait_physics_frames(1)
		frames += 1
	assert_eq(pool.active_count(), 8, "the rocket burst into 8 sparks at max range")
	var dirs: Array[float] = []
	for slot: ProjectilePool.Slot in pool.debug_slots():
		if slot.active:
			dirs.append(snappedf(slot.vel.angle(), 0.01))
	dirs.sort()
	for i: int in dirs.size() - 1:
		assert_almost_eq(dirs[i + 1] - dirs[i], TAU / 8.0, 0.1, "an even star")


func test_bees_home_onto_an_enemy_and_skip_allies() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300), 1)
	var ally: Player = _player(OTHER, Vector2(150, 330), 1)
	var enemy: Player = _player(TARGET, Vector2(260, 360), 2)
	await wait_physics_frames(2)
	_fire(&"hive_gun", shooter.global_position, Vector2.RIGHT)
	assert_eq(pool.active_count(), 3, "three bees a shot")
	await wait_physics_frames(150)
	var victims: Array[int] = []
	for h: Dictionary in hits:
		victims.append(h.victim)
	assert_true(victims.has(TARGET), "the bees found the enemy off their line")
	assert_false(victims.has(OTHER), "never an ally in Teams")
	assert_false(victims.has(SHOOTER))
	assert_eq(ally.stats.hp, ally.stats.max_hp)
	assert_lt(enemy.stats.hp + enemy.stats.armor, enemy.stats.max_hp + enemy.stats.max_armor)


func test_bees_buzz_round_their_target_before_stinging() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	var enemy: Player = _player(TARGET, Vector2(200, 300))
	await wait_physics_frames(2)
	_fire(&"hive_gun", shooter.global_position, Vector2.RIGHT)
	var start: int = Engine.get_physics_frames()
	var first_hit: int = -1
	for i: int in 100:
		await wait_physics_frames(1)
		if first_hit < 0 and not hits.is_empty():
			first_hit = Engine.get_physics_frames() - start
	assert_gte(first_hit, 0, "they sting eventually")
	# 140 px at 270 px/s is ~0.4 s (25 frames); the circling adds `sting_delay` on top.
	assert_gt(first_hit, 25 + 20, "they circle first")
	assert_not_null(enemy)
