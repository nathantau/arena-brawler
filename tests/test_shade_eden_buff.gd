extends GutTest
## The Shade / Eden buff pass: Eden's Thorn Quake (a telegraphed thorn blast that slows) and Shade's Kunai Rain (a zone that hurts), both reusing the Thunder Strike / Storm Cloud sim paths, plus the numbers the pass changed.

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
	p.stats.max_hp = 5000  # these tests count whole-cast damage: keep the 35% ability cap out of the way
	p.stats.hp = 5000
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


func _press(p: Player) -> void:
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	p.simulate(f, DT)


func _run(p: Player, frames: int, replay: bool = false) -> void:
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 100 + i
		f.aim_vec = Vector2.RIGHT
		p.simulate(f, DT, replay)


# --- catalog ---------------------------------------------------------------------

func test_new_specials_belong_to_their_fighters() -> void:
	var quake: SkillData = skills.get_skill(&"thorn_quake")
	var pool: SkillData = skills.get_skill(&"kunai_rain")
	assert_eq(quake.kind, SkillData.Kind.QUAKE)
	assert_eq(pool.kind, SkillData.Kind.RAIN)
	for sd: SkillData in [quake, pool]:
		assert_not_null(sd.icon, sd.id)
		assert_lte(sd.blurb.length(), 20, sd.id)
		assert_gt(sd.cooldown, 0.0)
	for c: CharacterData in characters.ordered:
		assert_eq(c.can_use_skill(quake), c.id == &"eden", String(c.id))
		assert_eq(c.can_use_skill(pool), c.id == &"flicker", String(c.id))
	assert_ne(Sfx.skill_sound(SkillData.Kind.QUAKE), &"dash")
	assert_ne(Sfx.skill_sound(SkillData.Kind.RAIN), &"dash")
	assert_gt(quake.thunder_blast.snare_time, 0.0, "the thorns slow")
	assert_gte(pool.storm_knockback, 0.0, "no pull")


# --- Thorn Quake -----------------------------------------------------------------

func test_thorn_quake_lands_after_the_telegraph_and_slows() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"thorn_quake")
	var p: Player = _fighter(w[0], w[1], 1, &"eden", &"thorn_quake", Vector2(100, 300))
	var foe: Player = _fighter(w[0], w[1], 2, &"shadow", &"", Vector2(100 + d.thunder_distance, 300))
	var far: Player = _fighter(w[0], w[1], 3, &"shadow", &"", Vector2(100 + d.thunder_distance, 300 + d.thunder_blast.splash_radius * 3.0))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	assert_true(p.skills[1].is_active(), "telegraph running")
	assert_almost_eq(p.skills[1].anchor.x, 100.0 + d.thunder_distance, 2.0, "marked ahead along the aim")
	_run(p, floori(d.duration / DT) - 3)
	assert_eq(hits.size(), 0, "nothing before the telegraph runs out")
	_run(p, 6)
	assert_eq(hits.size(), 1, "one victim in the blast")
	assert_eq(hits[0][0], 2)
	assert_gt(hits[0][1], d.thunder_blast.damage * 0.9, "dead centre: near full damage")
	assert_gt(foe.stats.slow_remaining, 1.0, "slowed")
	assert_almost_eq(foe.stats.slow_factor, d.thunder_blast.snare_factor, 0.001)
	assert_eq(far.stats.slow_remaining, 0.0, "outside the blast")
	assert_eq(p.stats.hp, p.stats.max_hp, "no self-damage")
	assert_false(p.skills[1].is_active())


func test_thorn_quake_replay_fires_nothing() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"thorn_quake")
	var p: Player = _fighter(w[0], w[1], 1, &"eden", &"thorn_quake", Vector2(100, 300))
	var foe: Player = _fighter(w[0], w[1], 2, &"shadow", &"", Vector2(100 + d.thunder_distance, 300))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	_run(p, floori(d.duration / DT) + 6, true)
	assert_eq(hits.size(), 0)
	assert_eq(foe.stats.slow_remaining, 0.0)


# --- Kunai Rain -------------------------------------------------------------------

func test_kunai_rain_hurts_whoever_stands_in_it() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"kunai_rain")
	var p: Player = _fighter(w[0], w[1], 1, &"flicker", &"kunai_rain", Vector2(100, 300))
	# The spot is d.storm_distance ahead at feet level (y 322); the foe stands a little beyond it, so a pull points back at the caster.
	var foe: Player = _fighter(w[0], w[1], 2, &"eden", &"", Vector2(100 + d.storm_distance + 40.0, 322))
	var far: Player = _fighter(w[0], w[1], 3, &"eden", &"", Vector2(100 + d.storm_distance, 322 + d.storm_radius + 50.0))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	_run(p, floori(d.storm_interval / DT) - 3)
	assert_eq(hits.size(), 0, "nothing before the first tick")
	_run(p, 6)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0], [2, d.storm_damage])
	assert_gte(foe.velocity.x, 0.0, "not pulled in")
	_run(p, ceili(d.duration / DT))
	assert_eq(hits.size(), int(d.duration / d.storm_interval), "a tick every interval for its whole life")
	assert_eq(far.stats.hp, far.stats.max_hp, "outside the pool")
	assert_eq(p.stats.hp, p.stats.max_hp, "not himself")
	var served: int = hits.size()
	_run(p, 90)
	assert_eq(hits.size(), served, "nothing once it has closed")
	assert_gt(p.skills[1].cooldown_remaining, 0.0)


func test_kunai_rain_replay_hurts_nobody() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"kunai_rain")
	var p: Player = _fighter(w[0], w[1], 1, &"flicker", &"kunai_rain", Vector2(100, 300))
	var foe: Player = _fighter(w[0], w[1], 2, &"eden", &"", Vector2(100 + d.storm_distance, 322))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	_run(p, 120, true)
	assert_eq(hits.size(), 0)
	assert_eq(foe.stats.hp, foe.stats.max_hp)


# --- bots ------------------------------------------------------------------------

func test_bots_use_the_new_specials_at_their_reach() -> void:
	var w: Array = _world()
	var brain := BotBrain.new(null, 5)
	var q: Player = _fighter(w[0], w[1], 1, &"eden", &"thorn_quake", Vector2(100, 300))
	var qd: SkillData = skills.get_skill(&"thorn_quake")
	assert_true(brain.slot_wanted(q, 1, qd.thunder_distance, true, false))
	assert_false(brain.slot_wanted(q, 1, qd.thunder_distance + 500.0, true, false))
	var s: Player = _fighter(w[0], w[1], 2, &"flicker", &"kunai_rain", Vector2(300, 300))
	var pd: SkillData = skills.get_skill(&"kunai_rain")
	assert_true(brain.slot_wanted(s, 1, pd.storm_distance, true, false))
	assert_false(brain.slot_wanted(s, 1, pd.storm_distance, false, false))


func test_shade_bots_rotate_through_his_kit() -> void:
	var w: Array = _world()
	var e: Player = _fighter(w[0], w[1], 1, &"flicker", &"shadow_clones", Vector2(100, 300))
	var ids: Dictionary = {}
	var brain := BotBrain.new(null, 5)
	for i: int in 40:
		e.skills[1].cooldown_remaining = 1.0
		brain._rotate_kit(e)
		e.skills[1].cooldown_remaining = 0.0
		brain._rotate_kit(e)
		ids[e.skills[1].data.id] = true
	assert_gt(ids.size(), 3, "his bots pick more than one of his specials: %s" % [ids.keys()])
	for id: StringName in ids:
		assert_true(skills.get_skill(id).tags.has(&"flicker"))


# --- the numbers -------------------------------------------------------------------

func test_buffed_numbers_hold() -> void:
	assert_gte(characters.get_character(&"eden").signature_weapon.damage, 26)
	assert_gte(characters.get_character(&"eden").max_hp, 130)
	assert_gte(skills.get_skill(&"leaf_gust").gust_damage, 14)
	assert_lte(skills.get_skill(&"bark_skin").cooldown, 11.0)
