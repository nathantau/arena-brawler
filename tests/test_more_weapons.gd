extends GutTest
## Five even-more shared weapons: Rubber Duck Lobber (2 bounces, splash), Popcorn Popper (kernels that pop), Magnet Blaster
## (negative knockback = a pull), Pumpkin Mortar (splash + 3 seeds) and Black Hole Orb (a vortex that drags foes in, then
## implodes). All untagged pickups, locked until a box rolls them.

const SHOOTER: int = 1
const TARGET: int = 2
const OTHER: int = 3
const SEED: int = 5
const TMP: String = "user://test_more_weapons_tmp.cfg"
const IDS: Array[StringName] = [&"duck_lobber", &"popcorn_popper", &"magnet_blaster", &"pumpkin_mortar", &"black_hole_orb"]
const RARITIES: Array[int] = [0, 0, 1, 1, 2]
const MAX_HIT: int = 70

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
		assert_not_null(w.sprite, "%s has a held sprite" % IDS[i])
		assert_not_null(w.projectile_sprite, String(IDS[i]))
		assert_gt(w.projectile_scale, 1.0, "%s is drawn a little bigger so it reads" % IDS[i])
		assert_lte(w.damage * maxi(1, w.pellets), MAX_HIT, "%s: one use stays under the cap" % IDS[i])
		var pref: float = BotBrain.preferred_range(w)
		assert_between(pref, BotBrain.PREF_MIN, w.projectile_range, "%s: bots keep a range it can reach" % IDS[i])


func test_every_fighter_can_use_them_and_they_start_locked_in_the_box_pool() -> void:
	for c: CharacterData in characters.ordered:
		var pool_ids: Array[StringName] = []
		for e: Dictionary in Unlocks.box_pool(c):
			pool_ids.append(e.id)
		for id: StringName in IDS:
			assert_true(c.can_use(_w(id)), "%s can use %s" % [c.id, id])
			assert_false(Unlocks.is_weapon_unlocked(c, _w(id)), "%s starts locked for %s" % [id, c.id])
			assert_true(pool_ids.has(id), "%s: %s is in the box pool" % [c.id, id])
	assert_true(catalog.pickup_ids().has(&"black_hole_orb"))
	assert_gte(LanDiscovery.VERSION, 17, "new weapon ids are a protocol change")


func test_new_field_defaults_are_off_so_older_weapons_are_untouched() -> void:
	for id: StringName in [&"pistol", &"storm_jar", &"confetti_popper", &"cactus_cannon", &"disc_launcher", &"yoyo"]:
		assert_eq(_w(id).vortex_radius, 0.0, String(id))
		assert_eq(_w(id).vortex_force, 0.0, String(id))
	assert_gt(_w(&"black_hole_orb").vortex_radius, 0.0)


func test_duck_bounces_twice_off_walls_then_pops_in_a_splash() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(150, 300))
	_wall(Vector2(300, 300), Vector2(20, 400))
	_wall(Vector2(100, 300), Vector2(20, 400))
	var bounces: Array = []
	var bursts: Array = []
	pool.bounced.connect(func(_at: Vector2, w: WeaponData) -> void: bounces.append(w.id))
	pool.exploded.connect(func(at: Vector2, _r: float, _c: Color, _s: bool, _a: bool) -> void: bursts.append(at))
	await wait_physics_frames(2)
	_fire(&"duck_lobber", shooter.global_position, Vector2.RIGHT)
	var seen: Array[int] = []
	for i: int in 150:
		await wait_physics_frames(1)
		for s: ProjectilePool.Slot in _active():
			if s.bounced > 0 and not seen.has(s.bounced):
				seen.append(s.bounced)
		if _active().is_empty():
			break
	assert_eq(seen, [1, 2] as Array[int], "two bounces, no more")
	assert_eq(bounces.size(), 2)
	assert_eq(bursts.size(), 1, "then one pop")
	assert_true(_active().is_empty())
	assert_eq(Sfx.bounce_sound(&"duck_lobber"), &"duck_bounce")
	assert_eq(_w(&"duck_lobber").sfx, &"duck_squeak")


func test_popcorn_scatters_eight_short_kernels_and_every_second_one_puffs() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var puffs: Array = []
	pool.fx_spawned.connect(func(_at: Vector2, w: WeaponData, _seed: int) -> void: puffs.append(w.id))
	await wait_physics_frames(2)
	_fire(&"popcorn_popper", shooter.global_position, Vector2.RIGHT, 2)
	var live: Array[ProjectilePool.Slot] = _active()
	assert_eq(live.size(), 8, "eight kernels")
	var lo: float = INF
	var hi: float = -INF
	for s: ProjectilePool.Slot in live:
		lo = minf(lo, s.vel.angle())
		hi = maxf(hi, s.vel.angle())
	assert_between(rad_to_deg(hi - lo), 34.0, 48.0, "a scatter fan")
	var frames: int = 0
	while pool.active_count() > 0 and frames < 120:
		await wait_physics_frames(1)
		frames += 1
	assert_lt(_w(&"popcorn_popper").projectile_range, 220.0, "short range")
	assert_eq(puffs.size(), 4, "a tiny puff on every 2nd kernel where it lands")


func test_magnet_pulls_the_foe_toward_the_shooter() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var victim: Player = _player(TARGET, Vector2(300, 300))
	assert_lt(_w(&"magnet_blaster").knockback, 0.0, "negative knockback is the pull")
	await wait_physics_frames(2)
	_fire(&"magnet_blaster", shooter.global_position, Vector2.RIGHT)
	for i: int in 60:
		await wait_physics_frames(1)
		if not hits.is_empty():
			break
	assert_eq(hits.size(), 1)
	assert_lt(victim.velocity.x, -200.0, "thrown back toward the shooter (who is on his left)")
	assert_lt(absf(victim.velocity.y), 30.0, "straight along the shot")
	victim.velocity = Vector2.ZERO  # a plain gun still shoves away
	hits.clear()
	_fire(&"pistol", shooter.global_position, Vector2.RIGHT, 2)
	await wait_physics_frames(40)
	assert_gte(victim.velocity.x, 0.0, "normal shots push away")


func test_pumpkin_bursts_and_splits_into_three_seeds() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	await wait_physics_frames(2)
	_fire(&"pumpkin_mortar", shooter.global_position, Vector2.RIGHT)
	assert_eq(pool.active_count(), 1)
	var parent: int = _active()[0].damage
	var frames: int = 0
	while pool.active_count() == 1 and frames < 200:
		await wait_physics_frames(1)
		frames += 1
	assert_eq(pool.active_count(), 3, "three seeds out of the burst")
	for s: ProjectilePool.Slot in _active():
		assert_eq(s.damage, maxi(1, roundi(parent * 0.4)), "seeds do 40%")
		assert_not_null(s.sprite)
		assert_eq(s.vortex_radius, 0.0, "a shard never inherits a vortex")


func test_black_hole_drags_a_nearby_foe_toward_its_path_then_implodes() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	var victim: Player = _player(TARGET, Vector2(260, 360))  # 60 px off the orb's line, inside the 130 px pull
	var far: Player = _player(OTHER, Vector2(260, 560))  # 260 px off: out of reach
	_player(4, Vector2(450, 335))  # waits near the end of the throw: hauled in, caught by the implosion
	var bursts: Array = []
	pool.exploded.connect(func(at: Vector2, _r: float, _c: Color, _s: bool, _a: bool) -> void: bursts.append(at))
	await wait_physics_frames(2)
	_fire(&"black_hole_orb", shooter.global_position, Vector2.RIGHT)
	var start: Vector2 = victim.global_position
	await wait_physics_frames(45)
	assert_lt(victim.global_position.y, start.y - 5.0, "dragged toward the orb's line")
	assert_eq(far.global_position, Vector2(260, 560), "out of range: not moved")
	var frames: int = 0
	while not _active().is_empty() and frames < 300:
		await wait_physics_frames(1)
		frames += 1
	assert_eq(bursts.size(), 1, "it imploded once")
	var caught: Array[int] = []
	for h: Dictionary in hits:
		caught.append(h.victim)
		assert_lte(h.dmg, MAX_HIT)
	assert_true(caught.has(4), "the foe waiting at the end was caught by the implosion")
	assert_false(caught.has(OTHER), "the far one never was")


func test_black_hole_pull_is_server_side_only_and_skips_allies_and_walls() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(60, 300))
	shooter.team = 1
	var ally: Player = _player(OTHER, Vector2(260, 360))
	ally.team = 1
	_wall(Vector2(200, 250), Vector2(80, 8))
	var behind: Player = _player(4, Vector2(200, 215))  # the wall shields him from the orb's path
	await wait_physics_frames(2)
	_fire(&"black_hole_orb", shooter.global_position, Vector2.RIGHT)
	await wait_physics_frames(40)
	assert_eq(ally.global_position, Vector2(260, 360), "allies are not pulled")
	assert_eq(behind.global_position, Vector2(200, 215), "no pull through a wall")
	pool.clear()  # a client's cosmetic pool never moves anybody: the server's positions win
	pool.authoritative = false
	var victim: Player = _player(5, Vector2(300, 340))
	_fire(&"black_hole_orb", shooter.global_position, Vector2.RIGHT, 2)
	await wait_physics_frames(60)
	assert_eq(victim.global_position, Vector2(300, 340), "client pools do not apply the pull")


func test_black_hole_pull_is_deterministic() -> void:
	var ends: Array[Vector2] = []
	for run: int in 2:
		pool.clear()
		pool.targets.clear()
		var shooter: Player = _player(SHOOTER, Vector2(60, 300))
		var victim: Player = _player(TARGET, Vector2(260, 360))
		await wait_physics_frames(2)
		_fire(&"black_hole_orb", shooter.global_position, Vector2.RIGHT)
		await wait_physics_frames(50)
		ends.append(victim.global_position)
		pool.targets.clear()
		shooter.free()
		victim.free()
		await wait_physics_frames(2)
	assert_eq(ends[0], ends[1], "same state, same pull")


func test_numbers_sit_next_to_their_rarity_peers() -> void:
	var duck: WeaponData = _w(&"duck_lobber")
	var cactus: WeaponData = _w(&"cactus_cannon")
	assert_between(float(duck.damage), cactus.damage - 4.0, cactus.damage + 2.0, "common lob")
	assert_eq(duck.bounces, 2)
	assert_gt(duck.splash_radius, 0.0)
	var pop: WeaponData = _w(&"popcorn_popper")
	assert_between(float(pop.damage * pop.pellets), 20.0, 30.0, "common scatter: ~ confetti's 28")
	var mag: WeaponData = _w(&"magnet_blaster")
	assert_between(float(mag.damage), 9.0, 13.0, "rare: ~ disc / yo-yo")
	var pump: WeaponData = _w(&"pumpkin_mortar")
	assert_eq(pump.split_count, 3)
	assert_lte(pump.damage + 3 * roundi(pump.damage * pump.split_scale), MAX_HIT)
	var hole: WeaponData = _w(&"black_hole_orb")
	assert_between(float(hole.damage), 16.0, 30.0, "epic: ~ storm jar")
	assert_lt(hole.projectile_speed, 250.0, "slow orb")
	assert_lt(hole.knockback, 0.0, "the implosion pulls in")


func test_sounds_exist_are_short_and_wired() -> void:
	var fire: Dictionary = {&"duck_lobber": &"duck_squeak", &"popcorn_popper": &"popcorn_pop", &"magnet_blaster": &"magnet_zap",
		&"pumpkin_mortar": &"pumpkin_thunk", &"black_hole_orb": &"hole_warble"}
	for id: StringName in fire:
		assert_eq(_w(id).sfx, fire[id], String(id))
	var names: Array = fire.values() + [&"duck_bounce", &"duck_pop", &"popcorn_crackle", &"popcorn_tick", &"magnet_hum", &"magnet_clack",
		&"pumpkin_squelch", &"hole_warble_down", &"hole_whoomp"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for n: StringName in names:
		assert_true(Sfx.RECIPES.has(n), String(n))
		var wav: AudioStreamWAV = Sfx.synthesize(Sfx.RECIPES[n], rng)
		assert_lte(wav.get_length(), 0.35, "%s length" % n)
		var peak: float = 0.0
		for i: int in wav.data.size() / 2:
			peak = maxf(peak, absf(wav.data.decode_s16(i * 2) / 32768.0))
		assert_between(peak, 0.05, 0.6, "%s peak %.2f" % [n, peak])
	for first: StringName in [&"popcorn_pop", &"magnet_zap", &"hole_warble"]:
		assert_true(Sfx.FOLLOW_UPS.has(first), String(first))
	assert_eq(Sfx.impact_sound(&"popcorn_popper"), &"popcorn_tick")
	assert_eq(Sfx.impact_sound(&"magnet_blaster"), &"magnet_clack")
	assert_eq(Sfx.burst_sound(load("res://assets/fx/pumpkin_burst.png")), &"pumpkin_squelch")
	assert_eq(Sfx.burst_sound(load("res://assets/fx/hole_implode.png")), &"hole_whoomp")
	assert_eq(Sfx.burst_sound(load("res://assets/fx/duck_pop.png")), &"duck_pop")
