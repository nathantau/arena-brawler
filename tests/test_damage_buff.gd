extends GutTest
## Global damage buff: every attack x Constants.DAMAGE_MULT (weapons and abilities); an ultimate's hits also x ULT_DAMAGE_MULT
## (its own skill, and the weapon fired while its form runs). Expectations come from the constants (see DmgExpect).

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


func _fighter(world: Node2D, pool: ProjectilePool, id: int, who: StringName, at: Vector2) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(who))
	world.add_child(p)
	p.global_position = at
	pool.targets.append(p)
	return p


func _hits(pool: ProjectilePool) -> Array:
	var hits: Array = []
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, _v: int, dmg: int, _c: bool, _a: Vector2) -> void:
		hits.append(dmg))
	return hits


func _blast(damage: int) -> WeaponData:
	var w := WeaponData.new()
	w.blast = true
	w.damage = damage
	w.splash_radius = 100.0
	w.splash_edge_scale = 1.0
	return w


## First damage tick of `skill_id` (slot 1) from a Bolt on a foe standing under the storm.
func _first_storm_hit(skill_id: StringName) -> int:
	var w: Array = _world()
	var d: SkillData = skills.get_skill(skill_id)
	var p: Player = _fighter(w[0], w[1], 1, &"bolt", Vector2(100, 300))
	p.set_skill(1, d)
	var foe: Player = _fighter(w[0], w[1], 2, &"eden", Vector2(100 + d.storm_distance, 300))
	var hits: Array = _hits(w[1])
	await wait_physics_frames(2)
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = Vector2.RIGHT
	f.special = true
	p.simulate(f, DT)
	foe.global_position = p.skills[1].anchor
	for i: int in ceili(d.storm_interval / DT) + 4:
		var g := InputFrame.new()
		g.seq = 11 + i
		g.aim_vec = Vector2.RIGHT
		p.simulate(g, DT)
	return 0 if hits.is_empty() else int(hits[0])


func test_constants_are_a_buff() -> void:
	assert_gt(Constants.DAMAGE_MULT, 1.0)
	assert_gt(Constants.ULT_DAMAGE_MULT, 1.0)


func test_global_multiplier_applies_to_a_weapon_hit() -> void:
	var w: Array = _world()
	var victim: Player = _fighter(w[0], w[1], 2, &"bolt", Vector2(300, 300))
	var hits: Array = _hits(w[1])
	await wait_physics_frames(2)
	w[1].fire_shot(1, 0, victim.global_position, Vector2.RIGHT, _blast(40), 1)
	assert_eq(hits.size(), 1)
	assert_between(hits[0], DmgExpect.lo(40), DmgExpect.hi(40))
	assert_gt(hits[0], 40, "more than the raw damage")


func test_global_multiplier_applies_to_a_skill_hit() -> void:
	var d: SkillData = skills.get_skill(&"storm_cloud")
	assert_false(skills.is_ultimate(d))
	var hit: int = await _first_storm_hit(&"storm_cloud")
	assert_between(hit, DmgExpect.lo(d.storm_damage), DmgExpect.hi(d.storm_damage))
	assert_gt(hit, d.storm_damage)


func test_an_ultimates_skill_hit_gets_the_extra_multiplier() -> void:
	var d: SkillData = skills.get_skill(&"thunderstorm")
	assert_true(skills.is_ultimate(d))
	var hit: int = await _first_storm_hit(&"thunderstorm")
	assert_between(hit, DmgExpect.lo(d.storm_damage, 0, true), DmgExpect.hi(d.storm_damage, 0, true))
	assert_gt(hit, DmgExpect.hi(d.storm_damage), "more than a normal skill's hit of the same base damage")


func test_ult_flag_goes_through_scaled_and_fire_shot() -> void:
	assert_between(CombatRules.scaled(40, 0, 5, true), DmgExpect.lo(40, 0, true), DmgExpect.hi(40, 0, true))
	assert_gt(CombatRules.scaled(100, 0, 5, true), CombatRules.scaled(100, 0, 5))
	var w: Array = _world()
	var victim: Player = _fighter(w[0], w[1], 2, &"bolt", Vector2(300, 300))
	var hits: Array = _hits(w[1])
	await wait_physics_frames(2)
	w[1].fire_shot(1, 0, victim.global_position, Vector2.RIGHT, _blast(40), 1, -1, true)
	assert_between(hits[0], DmgExpect.lo(40, 0, true), DmgExpect.hi(40, 0, true))


func test_the_weapon_of_a_running_ultimate_form_gets_it_too() -> void:
	var w: Array = _world()
	var ape: Player = _fighter(w[0], w[1], 1, &"wukong", Vector2(300, 300))
	var foe: Player = _fighter(w[0], w[1], 2, &"eden", Vector2(330, 300))
	var fists: WeaponData = WeaponCatalog.load_all().get_weapon(&"ape_fists")
	var hits: Array = _hits(w[1])
	await wait_physics_frames(2)
	ape.ult_charge = 1.0
	var f := InputFrame.new()
	f.seq = 1
	f.aim_vec = Vector2.RIGHT
	f.special2 = true
	ape.simulate(f, DT)
	assert_true(ape.skills[Constants.ULT_SLOT].is_active(), "Great Ape is running")
	for i: int in 90:
		var g := InputFrame.new()
		g.seq = 2 + i
		g.aim_vec = Vector2.RIGHT
		g.fire = true
		ape.simulate(g, DT)
		foe.global_position = Vector2(330, 300)
	assert_gt(hits.size(), 0, "the fists landed")
	assert_gte(hits[0], DmgExpect.lo(fists.damage, 0, true), "fists hit with the ultimate bonus")
