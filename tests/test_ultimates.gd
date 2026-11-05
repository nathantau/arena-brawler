extends GutTest
## Four ultimates (the charge system that gates them lives elsewhere; today they are normal specials tagged to their fighter):
## Sakura's Hanami Tempest (WHIRL path), Bolt's Thunderstorm (RAIN), Eden's World Tree (BLOOM), Shadow's Eclipse (SMOKE).

const DT: float = 1.0 / 60.0
## One use on a single standing target never reaches a one-shot on an 80 hp fighter (CLAUDE.md "Ability damage rescale").
## The old ~70-per-use cap, x the global and ultimate damage multipliers, x1.2 for the longer ultimates (+ rounding slack).
var DAMAGE_CAP: int = ceili(70.0 * Constants.DAMAGE_MULT * Constants.ULT_DAMAGE_MULT * 1.2) + 6
const IDS: Array[StringName] = [&"hanami_tempest", &"thunderstorm", &"world_tree", &"eclipse"]
const OWNERS: Dictionary = {&"hanami_tempest": &"sakura", &"thunderstorm": &"bolt", &"world_tree": &"eden", &"eclipse": &"shadow"}

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


func _total(hits: Array, victim: int) -> int:
	var sum: int = 0
	for h: Array in hits:
		if h[0] == victim:
			sum += h[1]
	return sum


func _press(p: Player) -> void:
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	p.simulate(f, DT)


func _run(p: Player, frames: int, fire: bool = false) -> void:
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 100 + i
		f.aim_vec = Vector2.RIGHT
		f.fire = fire
		p.simulate(f, DT)


func _full(id: StringName) -> int:
	return ceili(skills.get_skill(id).duration / DT) + 30


# --- catalog ---------------------------------------------------------------------------

func test_ultimates_belong_to_their_fighters_and_are_special() -> void:
	for id: StringName in IDS:
		var sd: SkillData = skills.get_skill(id)
		assert_not_null(sd, id)
		assert_not_null(sd.icon, id)
		assert_true(sd.special, id)
		assert_lte(sd.blurb.length(), 20, id)
		assert_gte(sd.cooldown, 15.0, "an ultimate is on a long cooldown: %s" % id)
		for c: CharacterData in characters.ordered:
			assert_eq(c.can_use_skill(sd), c.id == OWNERS[id], "%s / %s" % [id, c.id])


func test_ultimates_reuse_existing_kinds_and_have_their_own_sound() -> void:
	var kinds: Dictionary = {&"hanami_tempest": SkillData.Kind.WHIRL, &"thunderstorm": SkillData.Kind.RAIN,
		&"world_tree": SkillData.Kind.BLOOM, &"eclipse": SkillData.Kind.SMOKE}
	for id: StringName in IDS:
		var sd: SkillData = skills.get_skill(id)
		assert_eq(sd.kind, kinds[id], id)
		var sound: StringName = Sfx.skill_sound(sd.kind, sd.id)
		assert_true(Sfx.RECIPES.has(sound), id)
		assert_ne(sound, Sfx.skill_sound(sd.kind), "%s: not its kind's shared sound" % id)


# --- Hanami Tempest --------------------------------------------------------------------

func test_hanami_tempest_shreds_and_slows_nearby_enemies_within_cap() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"hanami_tempest")
	var p: Player = _fighter(w[0], w[1], 1, &"sakura", &"hanami_tempest", Vector2(300, 300))
	var near: Player = _fighter(w[0], w[1], 2, &"eden", &"", Vector2(300 + d.whirl_radius * 0.5, 300))
	var far: Player = _fighter(w[0], w[1], 3, &"eden", &"", Vector2(300 + d.whirl_radius * 3.0, 300))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	assert_true(p.skills[1].is_active(), "fired")
	_run(p, 30)
	assert_gt(near.stats.slow_remaining, 0.0, "slowed while inside")
	assert_lt(near.stats.slow_factor, 1.0)
	_run(p, _full(&"hanami_tempest"))
	var dealt: int = _total(hits, 2)
	assert_gt(dealt, 30, "a big hit over its 4 s")
	assert_lte(dealt, DAMAGE_CAP, "one use stays under the cap")
	assert_eq(_total(hits, 3), 0, "nothing outside the radius")
	assert_eq(far.stats.hp, far.stats.max_hp)
	assert_eq(p.stats.hp, p.stats.max_hp, "no self-damage")


# --- Thunderstorm ----------------------------------------------------------------------

func test_thunderstorm_strikes_visible_enemies_in_the_big_ring_within_cap() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"thunderstorm")
	var p: Player = _fighter(w[0], w[1], 1, &"bolt", &"thunderstorm", Vector2(100, 300))
	var edge: Player = _fighter(w[0], w[1], 2, &"eden", &"", Vector2(100 + d.storm_distance + d.storm_radius * 0.8, 300))
	var far: Player = _fighter(w[0], w[1], 3, &"eden", &"", Vector2(100 + d.storm_distance + d.storm_radius * 1.6, 300))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	assert_almost_eq(p.skills[1].anchor.x, 100.0 + d.storm_distance, 2.0, "the storm sits ahead along the aim")
	_run(p, _full(&"thunderstorm"))
	var dealt: int = _total(hits, 2)
	assert_gte(dealt, d.storm_damage * 5, "about six strikes land on someone at the edge of the ring")
	assert_lte(dealt, DAMAGE_CAP)
	assert_gt(d.storm_radius, 150.0, "a big ring")
	assert_eq(_total(hits, 3), 0, "outside the ring")
	assert_eq(far.stats.hp, far.stats.max_hp)
	assert_eq(edge.player_id, 2)


# --- World Tree ------------------------------------------------------------------------

func test_world_tree_heals_self_and_allies_and_roots_and_hurts_enemies_within_cap() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"world_tree")
	var p: Player = _fighter(w[0], w[1], 1, &"eden", &"world_tree", Vector2(300, 300))
	var ally: Player = _fighter(w[0], w[1], 2, &"flicker", &"", Vector2(300 + d.bloom_radius * 0.6, 300))
	var foe: Player = _fighter(w[0], w[1], 3, &"flicker", &"", Vector2(300 - d.bloom_radius * 0.6, 300))
	var outside: Player = _fighter(w[0], w[1], 4, &"flicker", &"", Vector2(300, 300 + d.bloom_radius * 3.0))
	p.team = 1
	ally.team = 1
	foe.team = 2
	outside.team = 2
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	p.stats.hp = 30
	ally.stats.hp = 30
	_press(p)
	assert_true(p.skills[1].is_active(), "fired")
	_run(p, 40)
	assert_gt(foe.stats.slow_remaining, 0.0, "rooted")
	assert_lte(foe.stats.slow_factor, 0.35)
	_run(p, _full(&"world_tree"))
	assert_gt(p.stats.hp, 70, "she heals a lot")
	assert_gt(ally.stats.hp, 70, "so does her ally")
	assert_gt(_total(hits, 3), 20, "thorns hurt the enemy")
	assert_lte(_total(hits, 3), DAMAGE_CAP)
	assert_eq(_total(hits, 2), 0, "never the ally")
	assert_eq(outside.stats.hp, outside.stats.max_hp, "outside the radius")
	assert_eq(outside.stats.slow_remaining, 0.0)


func test_verdant_bloom_is_unchanged_by_the_tree_fields() -> void:
	var d: SkillData = skills.get_skill(&"verdant_bloom")
	assert_false(d.bloom_heal_allies)
	assert_eq(d.bloom_damage, 0)
	assert_eq(d.bloom_slow_time, 0.0)


# --- Eclipse ---------------------------------------------------------------------------

func test_eclipse_bursts_slows_hides_him_and_firing_does_not_break_it() -> void:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(&"eclipse")
	var p: Player = _fighter(w[0], w[1], 1, &"shadow", &"eclipse", Vector2(300, 300))
	var near: Player = _fighter(w[0], w[1], 2, &"eden", &"", Vector2(300 + d.volley_weapon.splash_radius * 0.5, 300))
	var far: Player = _fighter(w[0], w[1], 3, &"eden", &"", Vector2(300 + d.volley_weapon.splash_radius * 2.5, 300))
	await wait_physics_frames(2)
	var hits: Array = _hits(w[1])
	_press(p)
	assert_true(p.is_vanished(), "unseen")
	assert_true(p.is_hidden(), "auto-aim and bots skip him")
	assert_gt(_total(hits, 2), 10, "the darkness bursts")
	assert_lte(_total(hits, 2), DAMAGE_CAP)
	assert_gt(near.stats.slow_remaining, 0.0, "marked: slowed")
	assert_eq(_total(hits, 3), 0)
	assert_eq(far.stats.hp, far.stats.max_hp)
	_run(p, 30, true)
	assert_true(p.is_vanished(), "firing does not break Eclipse")
	_run(p, _full(&"eclipse"))
	assert_false(p.is_vanished(), "it ends after its duration")


# --- refused while frozen, stunned or dead -----------------------------------------------

func _refusal_case(id: StringName, mode: String) -> void:
	var w: Array = _world()
	var p: Player = _fighter(w[0], w[1], 1, OWNERS[id], id, Vector2(300, 300))
	_fighter(w[0], w[1], 2, &"eden", &"", Vector2(400, 300))
	await wait_physics_frames(2)
	match mode:
		"frozen":
			p.frozen = true
		"stunned":
			p.stats.apply_stun(2.0)
		"dead":
			p.dead = true
	_press(p)
	assert_false(p.skills[1].is_active(), "%s refused while %s" % [id, mode])
	assert_eq(p.skills[1].cooldown_remaining, 0.0, "%s: no cooldown spent while %s" % [id, mode])


func test_hanami_tempest_refused_frozen_stunned_dead() -> void:
	for mode: String in ["frozen", "stunned", "dead"]:
		await _refusal_case(&"hanami_tempest", mode)


func test_thunderstorm_refused_frozen_stunned_dead() -> void:
	for mode: String in ["frozen", "stunned", "dead"]:
		await _refusal_case(&"thunderstorm", mode)


func test_world_tree_refused_frozen_stunned_dead() -> void:
	for mode: String in ["frozen", "stunned", "dead"]:
		await _refusal_case(&"world_tree", mode)


func test_eclipse_refused_frozen_stunned_dead() -> void:
	for mode: String in ["frozen", "stunned", "dead"]:
		await _refusal_case(&"eclipse", mode)


func test_a_stun_ends_a_running_tempest() -> void:
	var w: Array = _world()
	var p: Player = _fighter(w[0], w[1], 1, &"sakura", &"hanami_tempest", Vector2(300, 300))
	await wait_physics_frames(2)
	_press(p)
	assert_true(p.skills[1].is_active())
	p.stats.apply_stun(1.0)
	_run(p, 2)
	assert_false(p.skills[1].is_active(), "channels end on a stun")
