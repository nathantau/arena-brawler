extends GutTest
## Bolt's lightning specials: Lightning Beam (a channelled hitscan beam, ticking damage) and Thunder Strike (a marked spot, a
## telegraph, then a bolt with splash). Both are his own, both put him in godspeed while they run.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var skills: SkillCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	skills = SkillCatalog.shared()


func _bolt(world: Node2D, pool: ProjectilePool, special: StringName, id: int = 1, who: StringName = &"bolt") -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(who))
	world.add_child(p)
	if special != &"":
		p.set_skill(1, skills.get_skill(special))
	return p


func _world() -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	return [world, pool]


func _hits(pool: ProjectilePool) -> Array:
	var hits: Array = []
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, victim: int, dmg: int, _c: bool, _a: Vector2) -> void:
		hits.append([victim, dmg]))
	return hits


func _press(p: Player, aim: Vector2) -> void:
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = aim
	f.special = true
	p.simulate(f, DT)


func _run(p: Player, frames: int, aim: Vector2 = Vector2.RIGHT, replay: bool = false) -> void:
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 100 + i
		f.aim_vec = aim
		p.simulate(f, DT, replay)


func test_both_are_bolts_own() -> void:
	for id: StringName in [&"lightning_beam", &"thunder_strike"]:
		var sk: SkillData = skills.get_skill(id)
		assert_not_null(sk, String(id))
		assert_true(sk.special)
		for c: CharacterData in characters.ordered:
			assert_eq(c.can_use_skill(sk), c.id == &"bolt", "%s for %s" % [id, c.id])
		assert_not_null(sk.icon)
		assert_ne(sk.blurb, "")
		assert_lt(sk.blurb.length(), 26, "the loading-room row cuts long blurbs")
	assert_eq(skills.get_skill(&"lightning_beam").kind, SkillData.Kind.LIGHTNING)
	assert_eq(skills.get_skill(&"thunder_strike").kind, SkillData.Kind.THUNDER)
	assert_true(skills.get_skill(&"lightning_beam").beam_weapon.lightning)
	assert_true(skills.get_skill(&"thunder_strike").thunder_blast.blast)
	assert_ne(Sfx.skill_sound(SkillData.Kind.LIGHTNING), &"dash", "own sound")
	assert_ne(Sfx.skill_sound(SkillData.Kind.THUNDER), &"dash", "own sound")


func test_lightning_beam_ticks_damage_for_its_duration_then_stops() -> void:
	var w: Array = _world()
	var p: Player = _bolt(w[0], w[1], &"lightning_beam")
	p.global_position = Vector2(100, 300)
	var target: Player = _bolt(w[0], w[1], &"", 2)
	target.global_position = Vector2(300, p.shot_origin(skills.get_skill(&"lightning_beam").beam_weapon).y)  # the hand's height
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	var d: SkillData = skills.get_skill(&"lightning_beam")
	_press(p, Vector2.RIGHT)
	assert_true(p.skills[1].is_active())
	assert_eq(hits.size(), 0, "the first tick comes one interval after the press")
	_run(p, floori(d.duration / DT) + 6)
	assert_false(p.skills[1].is_active(), "ends after its duration")
	var ticks: int = roundi(d.duration / d.beam_weapon.fire_interval)
	assert_between(hits.size(), ticks - 2, ticks, "about one hit per tick (%d)" % ticks)
	for h: Array in hits:
		assert_eq(h[0], 2)
		assert_between(h[1], d.beam_weapon.damage - 1, d.beam_weapon.damage * 3, "tick damage")
	var seen: int = hits.size()
	_run(p, 30)
	assert_eq(hits.size(), seen, "no more ticks after it ends")
	assert_eq(p.stats.hp, p.stats.max_hp, "never hurts the caster")


func test_lightning_beam_slows_him_and_holds_his_normal_weapon() -> void:
	var w: Array = _world()
	var p: Player = _bolt(w[0], w[1], &"lightning_beam")
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	var f := InputFrame.new()
	f.seq = 11
	f.aim_vec = Vector2.RIGHT
	f.move_vec = Vector2.RIGHT
	f.fire = true
	p.simulate(f, DT)
	assert_true(p.skills[1].blocks_other(), "one ability at a time")
	assert_true(p.skill_locked(0), "no dash mid-beam")
	assert_almost_eq(p.weapon.cooldown, 0.0, 0.0001, "the loadout weapon stays quiet while he channels")
	assert_true(p.velocity.length() <= p.character.move_speed * p.skills[1].data.beam_speed_scale * 1.01, "slowed")


func test_thunder_strike_lands_only_after_the_telegraph() -> void:
	var w: Array = _world()
	var p: Player = _bolt(w[0], w[1], &"thunder_strike")
	p.global_position = Vector2(100, 300)
	var d: SkillData = skills.get_skill(&"thunder_strike")
	var target: Player = _bolt(w[0], w[1], &"", 2)
	target.global_position = Vector2(100 + d.thunder_distance, 300)
	var bystander: Player = _bolt(w[0], w[1], &"", 3)
	bystander.global_position = Vector2(100 + d.thunder_distance, 300 + d.thunder_blast.splash_radius * 3.0)
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p, Vector2.RIGHT)
	assert_true(p.skills[1].is_active(), "the ring shows")
	assert_almost_eq(p.skills[1].anchor.x, 100.0 + d.thunder_distance, 2.0, "marked ahead along the aim")
	_run(p, floori(d.duration / DT) - 3)
	assert_eq(hits.size(), 0, "nothing before the telegraph runs out")
	_run(p, 6)
	assert_eq(hits.size(), 1, "one bolt, one victim in the blast")
	assert_eq(hits[0][0], 2)
	assert_gt(hits[0][1], d.thunder_blast.damage * 0.9, "dead centre: near full damage")
	assert_eq(p.stats.hp, p.stats.max_hp)
	assert_false(p.skills[1].is_active())


func test_thunder_strike_replay_fires_nothing() -> void:
	var w: Array = _world()
	var p: Player = _bolt(w[0], w[1], &"thunder_strike")
	p.global_position = Vector2(100, 300)
	var d: SkillData = skills.get_skill(&"thunder_strike")
	var target: Player = _bolt(w[0], w[1], &"", 2)
	target.global_position = Vector2(100 + d.thunder_distance, 300)
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p, Vector2.RIGHT)
	_run(p, floori(d.duration / DT) + 6, Vector2.RIGHT, true)
	assert_eq(hits.size(), 0, "prediction replays change state, never spawn the strike")


func test_both_put_him_in_godspeed_smoothly() -> void:
	for id: StringName in [&"lightning_beam", &"thunder_strike"]:
		var w: Array = _world()
		var p: Player = _bolt(w[0], w[1], id)
		await wait_physics_frames(2)
		p._process(DT)
		assert_false(p.godspeed, "%s: normal first" % id)
		_press(p, Vector2.RIGHT)
		p._process(DT)
		assert_true(p.godspeed, "%s: active means godspeed" % id)
		assert_true(p.god_level > 0.0 and p.god_level < 0.2, "%s: eases in, no jump" % id)
		for i: int in 40:
			p._process(DT)
		assert_eq(p.god_level, 1.0)
		w[0].queue_free()


func test_bots_know_when_to_use_them() -> void:
	var brain := BotBrain.new(null, 1)
	var w: Array = _world()
	var p: Player = _bolt(w[0], w[1], &"lightning_beam")
	await wait_physics_frames(2)
	assert_true(brain.slot_wanted(p, 1, 200.0, true, false), "beam: enemy in range")
	assert_false(brain.slot_wanted(p, 1, 900.0, true, false), "beam: too far")
	assert_false(brain.slot_wanted(p, 1, 200.0, false, false), "beam: nobody in sight")
	p.set_skill(1, skills.get_skill(&"thunder_strike"))
	var d: SkillData = skills.get_skill(&"thunder_strike")
	assert_true(brain.slot_wanted(p, 1, d.thunder_distance, true, false), "thunder: enemy on the marked spot")
	assert_false(brain.slot_wanted(p, 1, d.thunder_distance + 400.0, true, false), "thunder: nothing at the spot")
