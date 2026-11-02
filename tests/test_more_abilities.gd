extends GutTest
## Five more specials so every fighter has at least five of their own: Shadow's Void Rift (Kunai Rain's path) and Umbral Spikes
## (Thunder Strike's), Bolt's Tesla Coil (Cherry Sapling's) and Arc Dash (a long DASH), Eden's Thorn Burst (a VOLLEY ring).

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


func _fighter(world: Node2D, pool: ProjectilePool, id: int, who: StringName, special: StringName, at: Vector2) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(who))
	world.add_child(p)
	p.global_position = at
	if special != &"":
		p.set_skill(1, skills.get_skill(special))
	pool.targets.append(p)
	return p


func _hits(pool: ProjectilePool) -> Array:
	var hits: Array = []
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, victim: int, dmg: int, _c: bool, _a: Vector2) -> void:
		hits.append([victim, dmg]))
	return hits


func _press(p: Player, move: Vector2 = Vector2.ZERO) -> void:
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.move_vec = move
	f.special = true
	p.simulate(f, DT)


func _run(p: Player, frames: int, replay: bool = false) -> void:
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 100 + i
		f.aim_vec = Vector2.RIGHT
		p.simulate(f, DT, replay)


# --- catalog -----------------------------------------------------------------------

func test_every_fighter_has_five_own_specials() -> void:
	for c: CharacterData in characters.ordered:
		var own: int = 0
		for sd: SkillData in skills.specials_for(c):
			if sd.tags.has(c.id):
				own += 1
		assert_gte(own, 5, "%s has %d own specials" % [c.id, own])


func test_new_specials_belong_to_their_fighters() -> void:
	var owners: Dictionary = {&"void_rift": &"shadow", &"umbral_spikes": &"shadow", &"tesla_coil": &"bolt", &"arc_dash": &"bolt",
		&"thorn_burst": &"eden"}
	for id: StringName in owners:
		var sd: SkillData = skills.get_skill(id)
		assert_not_null(sd, id)
		assert_not_null(sd.icon, id)
		assert_lte(sd.blurb.length(), 20, id)
		assert_gt(sd.cooldown, 0.0)
		for c: CharacterData in characters.ordered:
			assert_eq(c.can_use_skill(sd), c.id == owners[id], "%s / %s" % [id, c.id])


# --- Umbral Spikes ------------------------------------------------------------------

func test_umbral_spikes_land_after_the_telegraph() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"umbral_spikes")
	assert_eq(d.kind, SkillData.Kind.THUNDER)
	var p: Player = _fighter(w[0], w[1], 1, &"shadow", &"umbral_spikes", Vector2(100, 300))
	var foe: Player = _fighter(w[0], w[1], 2, &"eden", &"", Vector2(100 + d.thunder_distance, 300))
	var far: Player = _fighter(w[0], w[1], 3, &"eden", &"", Vector2(100 + d.thunder_distance, 300 + d.thunder_blast.splash_radius * 3.0))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	assert_true(p.skills[1].is_active(), "telegraph running")
	assert_almost_eq(p.skills[1].anchor.x, 100.0 + d.thunder_distance, 2.0, "marked ahead along the aim")
	_run(p, floori(d.duration / DT) - 3)
	assert_eq(hits.size(), 0, "nothing before the telegraph runs out")
	_run(p, 6)
	assert_eq(hits.size(), 1, "one victim in the spikes")
	assert_eq(hits[0][0], 2)
	assert_gt(hits[0][1], d.thunder_blast.damage * 0.9, "dead centre: near full damage")
	assert_eq(far.stats.hp, far.stats.max_hp, "outside the blast")
	assert_eq(foe.stats.slow_remaining, 0.0, "no slow: that is Thorn Quake")
	assert_eq(p.stats.hp, p.stats.max_hp, "no self-damage")


func test_umbral_spikes_replay_fires_nothing() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"umbral_spikes")
	var p: Player = _fighter(w[0], w[1], 1, &"shadow", &"umbral_spikes", Vector2(100, 300))
	_fighter(w[0], w[1], 2, &"eden", &"", Vector2(100 + d.thunder_distance, 300))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	_run(p, floori(d.duration / DT) + 6, true)
	assert_eq(hits.size(), 0)


# --- Void Rift ----------------------------------------------------------------------

func test_void_rift_lashes_whoever_stands_in_it() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"void_rift")
	assert_eq(d.kind, SkillData.Kind.RAIN)
	var p: Player = _fighter(w[0], w[1], 1, &"shadow", &"void_rift", Vector2(100, 300))
	var foe: Player = _fighter(w[0], w[1], 2, &"eden", &"", Vector2(100 + d.storm_distance + 30.0, 322))
	var far: Player = _fighter(w[0], w[1], 3, &"eden", &"", Vector2(100 + d.storm_distance, 322 + d.storm_radius + 60.0))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	assert_almost_eq(p.skills[1].anchor.x, 100.0 + d.storm_distance, 2.0)
	_run(p, floori(d.storm_interval / DT) - 3)
	assert_eq(hits.size(), 0, "nothing before the first lash")
	_run(p, 6)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0], [2, d.storm_damage])
	_run(p, ceili(d.duration / DT))
	assert_gte(hits.size(), 9, "a lash every interval for its whole life")
	assert_lte(hits.size(), 11)
	assert_eq(far.stats.hp, far.stats.max_hp, "outside the rift")
	assert_eq(p.stats.hp, p.stats.max_hp)
	assert_eq(foe.velocity.x, 0.0, "no push")
	var served: int = hits.size()
	_run(p, 90)
	assert_eq(hits.size(), served, "nothing once it has closed")


# --- Tesla Coil ---------------------------------------------------------------------

func test_tesla_coil_zaps_the_nearest_visible_enemy() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"tesla_coil")
	assert_eq(d.kind, SkillData.Kind.SAPLING)
	var p: Player = _fighter(w[0], w[1], 1, &"bolt", &"tesla_coil", Vector2(100, 300))
	var near: Player = _fighter(w[0], w[1], 2, &"eden", &"", Vector2(300, 300))
	var far: Player = _fighter(w[0], w[1], 3, &"eden", &"", Vector2(100 + d.sapling_range + 200.0, 300))
	await wait_physics_frames(2)
	var shots: Array = []
	p.shot_fired.connect(func(_who: Player, seq: int, _o: Vector2, dir: Vector2, id: StringName) -> void:
		shots.append([seq, dir, id]))
	_press(p)
	assert_eq(p.skills[1].anchor, Vector2(100, 300 + Player.FOOT_RING_Y), "planted at his feet")
	assert_eq(shots.size(), 0, "nothing on the press")
	_run(p, floori(d.sapling_interval / DT) + 3)
	assert_eq(shots.size(), 1, "one zap after the first interval")
	assert_eq(shots[0][2], &"coil_zap")
	assert_gt(shots[0][1].x, 0.9, "at the near one")
	_run(p, ceili(d.duration / DT))
	assert_eq(shots.size(), floori(d.duration / d.sapling_interval), "one per interval over its life")
	assert_eq(far.stats.hp, far.stats.max_hp, "out of range")
	assert_eq(near.stats.max_hp > 0, true)
	assert_eq(p.stats.hp, p.stats.max_hp, "never hurts him")


# --- Arc Dash -----------------------------------------------------------------------

func test_arc_dash_is_a_long_dash_with_iframes() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"arc_dash")
	assert_eq(d.kind, SkillData.Kind.DASH)
	assert_gt(d.dash_speed * d.duration, skills.dash().dash_speed * skills.dash().duration * 2.0, "much further than a Dash")
	var p: Player = _fighter(w[0], w[1], 1, &"bolt", &"arc_dash", Vector2(100, 300))
	await wait_physics_frames(2)
	var start: Vector2 = p.global_position
	_press(p, Vector2(0.0, 1.0))  # the stick decides the way, not the aim
	assert_true(p.is_dashing())
	assert_true(p.stats.is_invulnerable())
	_run(p, ceili(d.duration / DT) + 2)
	assert_false(p.is_dashing())
	var moved: Vector2 = p.global_position - start
	assert_gt(moved.y, d.dash_speed * d.duration * 0.8, "ran down along the stick")
	assert_lt(absf(moved.x), 5.0)
	assert_gt(p.skills[1].cooldown_remaining, 0.0)


# --- Thorn Burst --------------------------------------------------------------------

func test_thorn_burst_fires_a_ring_of_thorns() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"thorn_burst")
	assert_eq(d.kind, SkillData.Kind.VOLLEY)
	var p: Player = _fighter(w[0], w[1], 1, &"eden", &"thorn_burst", Vector2(500, 500))
	await wait_physics_frames(2)
	_press(p)
	assert_eq(w[1].active_count(), d.volley_weapon.pellets, "every thorn is out")
	var spread := Rect2(p.global_position, Vector2.ZERO)
	for sl: ProjectilePool.Slot in w[1].debug_slots():
		if sl.active:
			spread = spread.expand(sl.pos + sl.vel)
	assert_true(spread.size.x > 300.0 and spread.size.y > 300.0, "thorns fly every way")
	assert_eq(p.stats.hp, p.stats.max_hp)


func test_thorn_burst_hurts_a_close_enemy_and_replay_fires_nothing() -> void:
	var w: Array = _world()
	var p: Player = _fighter(w[0], w[1], 1, &"eden", &"thorn_burst", Vector2(500, 500))
	_fighter(w[0], w[1], 2, &"shadow", &"", Vector2(580, 500))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	await wait_physics_frames(30)
	assert_gt(hits.size(), 0, "a thorn lands")
	if hits.size() > 0:
		assert_eq(hits[0][0], 2)
	var w2: Array = _world()
	var r: Player = _fighter(w2[0], w2[1], 1, &"eden", &"thorn_burst", Vector2(500, 500))
	await wait_physics_frames(2)
	var f := InputFrame.new()
	f.seq = 10
	f.special = true
	r.simulate(f, DT, true)
	assert_eq(w2[1].active_count(), 0, "replay fires nothing")
