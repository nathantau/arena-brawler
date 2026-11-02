extends GutTest
## One ability use (a "cast") can't deal more than Constants.ABILITY_DAMAGE_CAP_FRACTION of the victim's max HP;
## ordinary weapon fire (cast 0) is never capped. The clamp lives in Player.take_hit (server / offline only).

var characters: CharacterCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()


func _world() -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	return [world, pool]


func _victim(world: Node2D, pool: ProjectilePool, hp: int = 100, scale: float = 1.0) -> Player:
	var p := Player.new()
	p.setup(2, 1, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"eden"))
	world.add_child(p)
	p.stats.max_hp = hp
	p.stats.hp = hp
	p.stats.armor = 0
	p.stats.spawn_protect = 0.0
	if scale != 1.0:
		p.set_hp_scale(scale)
		p.stats.hp = p.stats.max_hp
	pool.targets.append(p)
	return p


func test_a_big_ability_hit_is_clamped_to_the_cap() -> void:
	var w: Array = _world()
	var v: Player = _victim(w[0], w[1])
	var dealt: int = v.take_hit(90, false, Vector2.ZERO, 1, 7)
	assert_eq(dealt, 35)
	assert_eq(v.stats.hp, 65)
	assert_eq(v.take_hit(10, false, Vector2.ZERO, 1, 7), 0, "the budget for this cast is spent")
	assert_eq(v.stats.hp, 65)


func test_many_small_hits_of_one_cast_add_up_to_the_cap() -> void:
	var w: Array = _world()
	var v: Player = _victim(w[0], w[1])
	var total: int = 0
	for i: int in 30:
		total += v.take_hit(4, false, Vector2.ZERO, 1, 3)
	assert_eq(total, 35)


func test_separate_casts_each_get_their_own_budget() -> void:
	var w: Array = _world()
	var v: Player = _victim(w[0], w[1], 1000)
	assert_eq(v.take_hit(900, false, Vector2.ZERO, 1, 1), 350)
	assert_eq(v.take_hit(900, false, Vector2.ZERO, 1, 2), 350)
	assert_eq(v.stats.hp, 300)


func test_weapon_fire_is_not_capped() -> void:
	var w: Array = _world()
	var v: Player = _victim(w[0], w[1])
	assert_eq(v.take_hit(80, false, Vector2.ZERO, 1, 0), 80)
	assert_eq(v.take_hit(20, false, Vector2.ZERO, 1), 20)
	assert_true(v.stats.is_dead())


func test_cap_uses_the_scaled_max_hp_in_teams() -> void:
	var w: Array = _world()
	var v: Player = _victim(w[0], w[1], 100, Constants.TEAMS_HP_SCALE)
	assert_eq(v.stats.max_hp, roundi(characters.get_character(&"eden").max_hp * Constants.TEAMS_HP_SCALE))
	assert_eq(v.take_hit(500, false, Vector2.ZERO, 1, 9), roundi(v.stats.max_hp * Constants.ABILITY_DAMAGE_CAP_FRACTION))


func test_respawn_forgets_the_budgets() -> void:
	var w: Array = _world()
	var v: Player = _victim(w[0], w[1])
	v.take_hit(90, false, Vector2.ZERO, 1, 4)
	v.respawn(Vector2(50, 50))
	v.stats.spawn_protect = 0.0
	assert_gt(v.take_hit(90, false, Vector2.ZERO, 1, 4), 0)


func test_pool_carries_the_cast_through_blasts() -> void:
	var w: Array = _world()
	var pool: ProjectilePool = w[1]
	var v: Player = _victim(w[0], pool, 1000)
	v.global_position = Vector2(300, 300)
	await wait_physics_frames(2)
	var blast: WeaponData = SkillCatalog.shared().get_skill(&"eruption").eruption_blast
	var cast: int = pool.new_cast()
	for i: int in 10:  # ten pillars of one cast on the same spot
		pool.fire_shot(1, i, v.global_position, Vector2.RIGHT, blast, 3, cast)
	assert_eq(v.stats.hp, 1000 - 350, "one cast: capped at 35%")
	pool.fire_shot(1, 20, v.global_position, Vector2.RIGHT, blast, 3, pool.new_cast())
	assert_eq(v.stats.hp, 1000 - 350 - blast.damage, "a new cast, a new budget")
	pool.fire_shot(1, 21, v.global_position, Vector2.RIGHT, blast, 3)
	assert_lt(v.stats.hp, 1000 - 350 - blast.damage, "plain fire of the same weapon is not capped")
