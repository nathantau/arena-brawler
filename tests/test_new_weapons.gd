extends GutTest
## Five more shared weapons: Confetti Popper (fan), Cactus Cannon (needle ring), Disc Launcher (ricochet + growth), Yo-Yo
## (tethered boomerang) and Storm Jar (splash + chain lightning). All untagged pickups, locked until a box rolls them.

const SHOOTER: int = 1
const TARGET: int = 2
const OTHER: int = 3
const SEED: int = 5
const TMP: String = "user://test_new_weapons_tmp.cfg"
const IDS: Array[StringName] = [&"confetti_popper", &"cactus_cannon", &"disc_launcher", &"yoyo", &"storm_jar"]
const RARITIES: Array[int] = [0, 0, 1, 1, 2]

var world: Node2D
var pool: ProjectilePool
var catalog: WeaponCatalog
var characters: CharacterCatalog
var hits: Array = []
var _old_path: String
var _old_all: bool


func before_each() -> void:
	_old_path = PlayerProfile.path
	_old_all = Unlocks.all_unlocked
	Unlocks.all_unlocked = false
	PlayerProfile.path = TMP
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	PlayerProfile.load_from(TMP)
	world = Node2D.new()
	add_child_autofree(world)
	pool = ProjectilePool.new()
	world.add_child(pool)
	catalog = WeaponCatalog.load_all()
	characters = CharacterCatalog.load_all()
	hits = []
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, victim: int, dmg: int, _c: bool, _a: Vector2) -> void:
		hits.append({"victim": victim, "dmg": dmg}))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	PlayerProfile.path = _old_path
	PlayerProfile.load_from(TMP)
	Unlocks.all_unlocked = _old_all


func _w(id: StringName) -> WeaponData:
	return catalog.get_weapon(id)


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


func _fire(w: StringName, from: Vector2, dir: Vector2, seq: int = 1) -> void:
	pool.fire_shot(SHOOTER, seq, from, dir, _w(w), SEED)


func _active() -> Array[ProjectilePool.Slot]:
	var out: Array[ProjectilePool.Slot] = []
	for s: ProjectilePool.Slot in pool.debug_slots():
		if s.active:
			out.append(s)
	return out


func test_each_weapon_is_an_untagged_pickup_of_the_right_rarity_with_a_hook() -> void:
	for i: int in IDS.size():
		var w: WeaponData = _w(IDS[i])
		assert_not_null(w, String(IDS[i]))
		assert_true(w.pickup, String(IDS[i]))
		assert_true(w.tags.is_empty(), "%s: no tags, anyone can use it" % IDS[i])
		assert_eq(w.rarity, RARITIES[i], String(IDS[i]))
		assert_ne(w.hook, "", String(IDS[i]))
		assert_not_null(w.sprite, "%s has a held sprite (the lobby icon)" % IDS[i])
		assert_not_null(w.projectile_sprite, String(IDS[i]))
		var pref: float = BotBrain.preferred_range(w)
		assert_between(pref, BotBrain.PREF_MIN, w.projectile_range, "%s: bots keep a range it can reach" % IDS[i])


func test_every_fighter_can_use_them_and_they_start_locked_in_the_box_pool() -> void:
	assert_gt(characters.ordered.size(), 0)
	for c: CharacterData in characters.ordered:
		var listed: Array[StringName] = []
		for w: WeaponData in Unlocks.weapons_for(c):
			listed.append(w.id)
		var lockable: Array[StringName] = []
		for e: Dictionary in Unlocks.lockable_all():
			lockable.append(e.id)
		var pool_ids: Array[StringName] = []
		for e: Dictionary in Unlocks.box_pool_all():
			pool_ids.append(e.id)
		for id: StringName in IDS:
			assert_true(c.can_use(_w(id)), "%s can use %s" % [c.id, id])
			assert_true(listed.has(id), "%s lists %s in the lobby" % [c.id, id])
			assert_true(lockable.has(id), "%s: %s can come out of a box" % [c.id, id])
			assert_false(Unlocks.is_weapon_unlocked(c, _w(id)), "%s starts locked for %s" % [id, c.id])
			assert_true(pool_ids.has(id), "%s: %s is in the box pool" % [c.id, id])
	var flicker: CharacterData = characters.get_character(&"flicker")
	PlayerProfile.unlocked[Unlocks.key(&"weapon", &"yoyo")] = true
	assert_true(Unlocks.is_weapon_unlocked(flicker, _w(&"yoyo")), "an unlock sticks")


func test_the_pickup_pad_pool_has_them_and_the_protocol_version_moved() -> void:
	var ids: Array[StringName] = catalog.pickup_ids()
	for id: StringName in IDS:
		assert_true(ids.has(id), String(id))
	assert_gte(LanDiscovery.VERSION, 16, "new weapon ids are a protocol change")


func test_confetti_pops_a_wide_short_fan_of_seven() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	await wait_physics_frames(2)
	_fire(&"confetti_popper", shooter.global_position, Vector2.RIGHT)
	var live: Array[ProjectilePool.Slot] = _active()
	assert_eq(live.size(), 7, "seven pellets")
	var lo: float = INF
	var hi: float = -INF
	for s: ProjectilePool.Slot in live:
		lo = minf(lo, s.vel.angle())
		hi = maxf(hi, s.vel.angle())
		assert_not_null(s.sprite)
	assert_gt(rad_to_deg(hi - lo), 40.0, "a wide fan")
	assert_lt(rad_to_deg(hi - lo), 60.0)
	var frames: int = 0
	while pool.active_count() > 0 and frames < 120:
		await wait_physics_frames(1)
		frames += 1
	assert_lt(frames, 60, "short range: all gone within a second")
	assert_lt(_w(&"confetti_popper").projectile_range, 260.0)


func test_cactus_cannon_bursts_into_a_ring_of_six_needles() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	await wait_physics_frames(2)
	_fire(&"cactus_cannon", shooter.global_position, Vector2.RIGHT)
	assert_eq(pool.active_count(), 1)
	var frames: int = 0
	while pool.active_count() == 1 and frames < 200:
		await wait_physics_frames(1)
		frames += 1
	assert_eq(pool.active_count(), 6, "six needles at the end of the throw")
	var dirs: Array[float] = []
	for s: ProjectilePool.Slot in _active():
		dirs.append(snappedf(s.vel.angle(), 0.01))
		assert_between(s.damage, DmgExpect.lo(_w(&"cactus_cannon").damage * 0.5), DmgExpect.hi(_w(&"cactus_cannon").damage * 0.5), "needles do half")
	dirs.sort()
	for i: int in dirs.size() - 1:
		assert_almost_eq(dirs[i + 1] - dirs[i], TAU / 6.0, 0.1, "an even ring")


func test_disc_gains_damage_with_each_of_three_bounces() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	_wall(Vector2(200, 300), Vector2(20, 400))
	_wall(Vector2(-50, 300), Vector2(20, 400))
	await wait_physics_frames(2)
	_fire(&"disc_launcher", shooter.global_position, Vector2.RIGHT)
	var seen: Array[int] = []
	for i: int in 150:
		await wait_physics_frames(1)
		for s: ProjectilePool.Slot in _active():
			if s.bounced > 0 and not seen.has(s.bounced):
				seen.append(s.bounced)
				assert_eq(s.damage, roundi(s.base_damage * (1.0 + 0.3 * s.bounced)), "bounce %d" % s.bounced)
	assert_eq(seen, [1, 2, 3] as Array[int], "three bounces, each stronger")


func test_yoyo_goes_out_and_back_on_a_string_and_hits_once_each_way() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	_player(TARGET, Vector2(250, 300))
	var w: WeaponData = _w(&"yoyo")
	assert_true(w.boomerang)
	assert_true(w.tether)
	await wait_physics_frames(2)
	_fire(&"yoyo", shooter.global_position, Vector2.RIGHT)
	assert_not_null(_active()[0].weapon, "tethered shots keep their weapon (the string is drawn from it)")
	var turned: bool = false
	var far: float = 0.0
	for i: int in 150:
		await wait_physics_frames(1)
		for s: ProjectilePool.Slot in _active():
			turned = turned or s.returning
			far = maxf(far, s.pos.x - 100.0)
		if _active().is_empty():
			break
	assert_true(turned, "it turned round")
	assert_lt(far, w.projectile_range + 60.0, "short throw")
	assert_true(_active().is_empty(), "caught by the thrower")
	assert_eq(hits.size(), 2, "once out, once back, not once per frame")


func test_yoyo_position_follows_ease_out_sleep_and_snap_back() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var w: WeaponData = _w(&"yoyo")
	assert_between(w.projectile_range, 150.0, 175.0, "60-70% of the old 250 px throw")
	assert_almost_eq(w.yoyo_reach(0.0), 0.0, 0.001)
	assert_almost_eq(w.yoyo_reach(w.yoyo_out_time()), w.projectile_range, 0.001)
	assert_almost_eq(w.yoyo_home(w.yoyo_sleep), 1.0, 0.001, "still at the far point when the sleep ends")
	assert_almost_eq(w.yoyo_home(w.yoyo_sleep + w.yoyo_back_time()), 0.0, 0.001, "in the hand at the end")
	await wait_physics_frames(2)
	_fire(&"yoyo", shooter.global_position, Vector2.RIGHT)
	var start_x: float = shooter.global_position.x + w.muzzle_distance()
	var xs: Array[float] = []
	for i: int in 90:
		await get_tree().physics_frame  # one tick (wait_physics_frames(1) is two)
		if _active().is_empty():
			break
		xs.append(_active()[0].pos.x)
	var out_n: int = int(w.yoyo_out_time() * 60.0)
	var sleep_n: int = int(w.yoyo_sleep * 60.0)
	# out: always moving away, each step shorter than the last (ease-out), launched faster than the old 480 px/s
	var prev: float = start_x
	var prev_step: float = INF
	for i: int in out_n - 1:
		var step: float = xs[i] - prev
		assert_gt(step, 0.0, "out frame %d moves out" % i)
		assert_lte(step, prev_step + 0.01, "out frame %d decelerates" % i)
		prev = xs[i]
		prev_step = step
	assert_gt(xs[0] - start_x, 480.0 / 60.0 * 1.5, "snaps out fast")
	# the position is the curve of its age (give or take a frame of phase)
	for i: int in out_n - 1:
		var age: float = float(i + 1) / 60.0
		assert_between(xs[i] - start_x, w.yoyo_reach(age - 2.0 / 60.0) - 0.5, w.yoyo_reach(age + 2.0 / 60.0) + 0.5, "frame %d on the curve" % i)
	# sleep: parked at full reach for about yoyo_sleep
	var parked: int = 0
	for x: float in xs:
		if absf(x - (start_x + w.projectile_range)) < 0.5:
			parked += 1
	assert_gte(parked, sleep_n - 2, "sleeps at the far point")
	assert_lte(parked, sleep_n + 3)
	# snap back: after the sleep every step toward the hand is longer than the last, until it is caught
	var first_back: int = out_n + parked - 1
	var last_step: float = 0.0
	for i: int in range(first_back + 1, xs.size()):
		var step: float = xs[i - 1] - xs[i]
		assert_gte(step, last_step - 0.01, "return frame %d accelerates" % i)
		last_step = step
	assert_gt(last_step, 5.0, "arrives at speed")
	var total: float = w.yoyo_out_time() + w.yoyo_sleep + w.yoyo_back_time()
	assert_almost_eq(float(xs.size()) / 60.0, total, 0.1, "caught after out + sleep + back")


func test_storm_jar_splashes_and_the_lightning_jumps_to_a_second_enemy() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	_player(TARGET, Vector2(300, 300))
	_player(OTHER, Vector2(300, 410))  # outside the 38 px splash, inside the 150 px chain
	_player(4, Vector2(300, 640))  # too far
	var arcs: Array = []
	pool.chained.connect(func(from: Vector2, to: Vector2, _c: Color) -> void: arcs.append([from, to]))
	await wait_physics_frames(2)
	_fire(&"storm_jar", shooter.global_position, Vector2.RIGHT)
	await wait_physics_frames(60)
	var victims: Array[int] = []
	for h: Dictionary in hits:
		victims.append(h.victim)
	assert_true(victims.has(TARGET), "the jar shattered on the first enemy")
	assert_true(victims.has(OTHER), "lightning jumped to the second")
	assert_false(victims.has(4), "not to the far one")
	assert_eq(arcs.size(), 1, "one arc (shown on every peer)")
	for h: Dictionary in hits:
		if h.victim == OTHER:
			assert_between(h.dmg, DmgExpect.lo(_w(&"storm_jar").damage * 0.6), DmgExpect.hi(_w(&"storm_jar").damage * 0.6), "chain scale 0.6")


func test_storm_jar_never_chains_to_an_ally() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	shooter.team = 1
	_player(TARGET, Vector2(300, 300))
	var ally: Player = _player(OTHER, Vector2(300, 410))
	ally.team = 1
	await wait_physics_frames(2)
	_fire(&"storm_jar", shooter.global_position, Vector2.RIGHT)
	await wait_physics_frames(60)
	for h: Dictionary in hits:
		assert_ne(h.victim, OTHER)


func test_storm_jar_chain_skips_an_enemy_the_splash_already_hit() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	_player(TARGET, Vector2(300, 300))
	_player(OTHER, Vector2(300, 318))  # inside the splash with the first
	_player(4, Vector2(300, 410))  # outside the splash, inside the chain
	await wait_physics_frames(2)
	_fire(&"storm_jar", shooter.global_position, Vector2.RIGHT)
	await wait_physics_frames(60)
	var count: Dictionary = {}
	for h: Dictionary in hits:
		count[h.victim] = int(count.get(h.victim, 0)) + 1
	assert_eq(count.get(OTHER, 0), 1, "the second enemy in the splash is hit once (no chain on top)")
	assert_eq(count.get(4, 0), 1, "the chain jumps on to the one the burst missed")


func _lobby_player(weapon: StringName) -> Player:
	var p := Player.new()
	p.setup(SHOOTER, 0, Color.WHITE, catalog.resolve([weapon] as Array[StringName]), null, pool, SEED,
		characters.get_character(&"flicker"))
	add_child_autofree(p)
	p.set_weapon(_w(weapon))
	return p


func test_lobby_enforce_unlocks_asks_once_per_locked_pick() -> void:
	var panel := LobbyPanel.new()
	autofree(panel)
	var arena := Arena.new()
	autofree(arena)
	panel.arena = arena
	var asked: Array = []
	arena.weapon_requested.connect(func(id: StringName) -> void: asked.append(id))
	var locked: Player = _lobby_player(&"yoyo")
	panel._enforce_unlocks(locked)
	panel._enforce_unlocks(locked)
	panel._enforce_unlocks(locked)
	assert_eq(asked.size(), 1, "one request while the snapshot has not caught up")
	panel._enforce_unlocks(_lobby_player(&"flicker_kunai"))  # the pick is now fine
	panel._enforce_unlocks(locked)  # a locked pick again
	assert_eq(asked.size(), 2, "asks again after the pick changed")
