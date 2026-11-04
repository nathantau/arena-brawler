extends GutTest
## Rare / epic items hit 5% / 10% harder (Constants.RARITY_DAMAGE_MULT): a weapon by its own rarity, an ability's damage by its
## SkillData rarity (skill weapons carry rarity 0 themselves). Starters, signatures, forms and ultimates are common.

const DT: float = 1.0 / 60.0
var skills: SkillCatalog


func before_all() -> void:
	skills = SkillCatalog.shared()


func _blast(damage: int, rarity: int) -> WeaponData:
	var w := WeaponData.new()
	w.blast = true
	w.damage = damage
	w.rarity = rarity
	w.splash_radius = 100.0
	w.splash_edge_scale = 1.0
	w.crit_multiplier = 2.0
	return w


func _victim_world() -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var cc := CharacterCatalog.load_all()
	var wc := WeaponCatalog.load_all()
	var victim := Player.new()
	victim.setup(2, 0, Color.WHITE, wc.resolve([&"pistol"] as Array[StringName]), null, pool, 3, cc.get_character(&"bolt"))
	world.add_child(victim)
	victim.global_position = Vector2(300, 300)
	var hits: Array = []
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, _v: int, dmg: int, _c: bool, _a: Vector2) -> void:
		hits.append(dmg))
	return [world, pool, victim, hits, cc, wc]


func test_rarity_multiplier_rounds_and_keeps_a_hit_at_least_one() -> void:
	assert_eq(CombatRules.scaled(40, 0), 40)
	assert_eq(CombatRules.scaled(40, 1), 42)
	assert_eq(CombatRules.scaled(40, 2), 44)
	assert_between(CombatRules.scaled(10, 1, 3), 10, 11, "10.5 rounds either way")
	assert_eq(CombatRules.scaled(3, 1, 7), CombatRules.scaled(3, 1, 7), "same salt, same result")
	assert_eq(CombatRules.scaled(1, 2), 1, "min 1")
	assert_eq(CombatRules.scaled(0, 2), 0, "no hit stays no hit")
	assert_eq(CombatRules.scaled(40, 9), 44, "rarity clamps")
	assert_eq(Unlocks.dmg_bonus_text(0), "")
	assert_eq(Unlocks.dmg_bonus_text(1), "+5% dmg")
	assert_eq(Unlocks.dmg_bonus_text(2), "+10% dmg")


func _mean(damage: int, rarity: int) -> float:
	var total: int = 0
	for salt: int in 20000:
		var v: int = CombatRules.scaled(damage, rarity, salt)
		var x: float = damage * Constants.RARITY_DAMAGE_MULT[rarity]
		assert_between(v, floori(x + 0.0001), ceili(x - 0.0001))
		total += v
	return float(total) / 20000.0


func test_small_hits_average_damage_times_the_multiplier() -> void:
	assert_almost_eq(_mean(2, 2), 2.2, 0.05, "2-dmg epic")
	assert_almost_eq(_mean(3, 1), 3.15, 0.05, "3-dmg rare")
	assert_almost_eq(_mean(40, 1), 42.0, 0.001, "exact products never wobble")
	assert_eq(CombatRules.scaled(40, 1, 99), 42)
	assert_eq(CombatRules.scaled(1, 2, 5) >= 1, true)


func test_weapon_damage_scales_by_its_own_rarity() -> void:
	var w: Array = _victim_world()
	await wait_physics_frames(2)
	var pool: ProjectilePool = w[1]
	var victim: Player = w[2]
	var hits: Array = w[3]
	var seq: int = 0
	for r: int in 3:
		victim.stats.reset()
		pool.fire_shot(1, seq, victim.global_position, Vector2.RIGHT, _blast(20, r), 1)
		seq += 1
	assert_eq(hits, [20, 21, 22], "common / rare x1.05 / epic x1.10")


func test_skill_weapon_uses_the_skills_rarity_not_its_own() -> void:
	var w: Array = _victim_world()
	await wait_physics_frames(2)
	var pool: ProjectilePool = w[1]
	var hits: Array = w[3]
	pool.fire_shot(1, 0, (w[2] as Player).global_position, Vector2.RIGHT, _blast(60, 0), 1, 2)
	assert_eq(hits, [66], "rarity 0 weapon fired by an epic ability")


func _thunder_hit(rarity: int) -> int:
	var w: Array = _victim_world()
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, (w[5] as WeaponCatalog).resolve([&"pistol"] as Array[StringName]), null, w[1], 3,
		(w[4] as CharacterCatalog).get_character(&"bolt"))
	(w[0] as Node2D).add_child(p)
	var sk: SkillData = skills.get_skill(&"thunder_strike").duplicate()
	sk.rarity = rarity
	p.set_skill(1, sk)
	p.global_position = Vector2(100, 300)
	(w[2] as Player).global_position = Vector2(100 + sk.thunder_distance, 300)
	await wait_physics_frames(2)
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	p.simulate(f, DT)
	(w[2] as Player).global_position = p.skills[1].anchor  # dead centre: no falloff
	for i: int in floori(sk.duration / DT) + 6:
		var g := InputFrame.new()
		g.seq = 11 + i
		g.aim_vec = Vector2.RIGHT
		p.simulate(g, DT)
	var hits: Array = w[3]
	return 0 if hits.is_empty() else int(hits[0])


func test_epic_ability_damage_is_scaled_through_its_skilldata() -> void:
	var base: int = skills.get_skill(&"thunder_strike").thunder_blast.damage
	assert_eq(skills.get_skill(&"thunder_strike").thunder_blast.rarity, 0, "skill weapon is common itself")
	var common: int = await _thunder_hit(0)
	var epic: int = await _thunder_hit(2)
	assert_eq(common, base)
	assert_between(epic, floori(base * 1.1), floori(base * 1.1) + 1)
	assert_gt(epic, common)


func test_starters_signatures_forms_and_ultimates_are_common() -> void:
	var cc := CharacterCatalog.load_all()
	for c: CharacterData in cc.ordered:
		if c.signature_weapon != null:
			assert_eq(c.signature_weapon.rarity, 0, "%s signature weapon" % c.id)
		if c.signature_skill != null:
			assert_eq(c.signature_skill.rarity, 0, "%s signature skill" % c.id)
		if c.ultimate != null:
			assert_eq(c.ultimate.rarity, 0, "%s ultimate" % c.id)
	assert_eq(WeaponCatalog.load_all().get_weapon(&"ape_fists").rarity, 0)
	assert_eq(skills.get_skill(&"dash").rarity, 0)
	assert_eq(skills.get_skill(&"barrier").rarity, 0)
