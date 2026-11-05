extends GutTest
## Shadow Army (Shade's ultimate): while it runs, every shot she fires is also fired from each clone at
## `clone_fire_scale` x the damage. Shadow Clones is her ordinary (harmless) ability again.

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
	pool.authoritative = true
	world.add_child(pool)
	return [world, pool]


func _player(w: Array, id: int, at: Vector2, who: StringName = &"flicker") -> Player:
	var p := Player.new()
	p.setup(id, id - 1, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, w[1], 3, characters.get_character(who))
	w[0].add_child(p)
	p.global_position = at
	w[1].targets.append(p)
	return p


func _wall(w: Array, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = rect.get_center()
	w[0].add_child(body)


func _frame(p: Player, seq: int, fire: bool = false, skill: bool = false, special: bool = false, ult: bool = false) -> void:
	var f := InputFrame.new()
	f.seq = seq
	f.aim_vec = Vector2.RIGHT
	f.fire = fire
	f.skill = skill
	f.special = special
	f.special2 = ult
	p.simulate(f, DT)


## Shade with the ult running (or the Shadow Clones ability in slot 1), clones out for a moment.
func _shade(w: Array, mode: StringName) -> Player:
	var p: Player = _player(w, 1, Vector2(100, 300))
	p.set_skill(1, skills.get_skill(&"shadow_clones"))
	return p


func _start(p: Player, mode: StringName) -> void:
	if mode == &"ult":
		p.ult_charge = 1.0
		_frame(p, 1, false, false, false, true)
	elif mode == &"ability":
		_frame(p, 1, false, false, true)
	for i: int in 20:
		_frame(p, 2 + i)


func _shots_of(pool: ProjectilePool, owner: int) -> Dictionary:
	var out: Dictionary = {}
	for s: ProjectilePool.Slot in pool.debug_slots():
		if s.active and s.owner_id == owner:
			out[s.shot_seq] = s
	return out


func test_clones_fire_with_her_during_the_ult() -> void:
	var w: Array = _world()
	var p: Player = _shade(w, &"ult")
	await wait_physics_frames(2)
	_start(p, &"ult")
	assert_eq(p.clone_points().size(), 4)
	_frame(p, 500, true)
	var shots: Dictionary = _shots_of(w[1], 1)
	assert_eq(shots.size(), 5, "her shot + one per clone")
	assert_true(shots.has(500))
	for k: int in 4:
		assert_true(shots.has(500 + (k + 1) * Player.CLONE_SEQ_OFFSET), "clone %d has its own key" % k)


func test_clones_do_not_fire_without_the_ult() -> void:
	var w: Array = _world()
	var p: Player = _shade(w, &"none")
	await wait_physics_frames(2)
	_frame(p, 1)
	_frame(p, 500, true)
	assert_eq(_shots_of(w[1], 1).size(), 1, "only her own shot")


func test_shadow_clones_ability_does_not_fire() -> void:
	var w: Array = _world()
	var p: Player = _shade(w, &"ability")
	await wait_physics_frames(2)
	_start(p, &"ability")
	assert_eq(p.clone_points().size(), 4, "the decoys are out")
	_frame(p, 500, true)
	assert_eq(_shots_of(w[1], 1).size(), 1, "decoys stay harmless")


func test_clone_shot_damage_is_scaled_and_charges_nothing() -> void:
	var w: Array = _world()
	var p: Player = _shade(w, &"ult")
	var foe: Player = _player(w, 2, Vector2(700, 300))
	await wait_physics_frames(2)
	_start(p, &"ult")
	_frame(p, 500, true)
	var scale: float = skills.get_skill(&"shadow_army").clone_fire_scale
	var base: int = -1
	for s: ProjectilePool.Slot in w[1].debug_slots():
		if s.active and s.shot_seq == 500 and not s.crit:
			base = s.damage
	assert_gt(base, p.held_weapon().data.damage, "her own shot gets the ult bonus")
	var checked: int = 0
	for s: ProjectilePool.Slot in w[1].debug_slots():
		if s.active and s.shot_seq >= Player.CLONE_SEQ_OFFSET and not s.crit:
			assert_almost_eq(float(s.damage), base * scale, 1.01, "about scale x her damage")
			checked += 1
	assert_gt(checked, 0)
	assert_eq(p.ult_charge, 0.0, "nothing refills mid-ult")
	assert_eq(foe.ult_charge, 0.0)


func test_clone_aim_picks_nearest_visible_enemy_and_falls_back_to_facing() -> void:
	var w: Array = _world()
	var p: Player = _player(w, 1, Vector2(100, 300))
	var far: Player = _player(w, 2, Vector2(100, 600))
	var near: Player = _player(w, 3, Vector2(500, 300))
	await wait_physics_frames(2)
	var at := Vector2(100, 400)
	p.facing = Vector2.LEFT
	var dir: Vector2 = p.clone_aim(at, p.held_weapon().data)
	assert_gt(dir.y, 0.9, "the enemy 200 px below is nearer than the one 400 px right: %s" % dir)
	far.global_position = Vector2(100, 1500)
	near.global_position = Vector2(100, 1100)
	assert_eq(p.clone_aim(at, p.held_weapon().data), Vector2.LEFT, "everyone out of range: along her facing")
	near.global_position = Vector2(100, 600)
	_wall(w, Rect2(60, 480, 100, 20))
	await wait_physics_frames(2)
	assert_eq(p.clone_aim(at, p.held_weapon().data), Vector2.LEFT, "a wall hides him: along her facing")


func test_shadow_clones_is_an_ability_and_shadow_army_the_ultimate() -> void:
	var shade: CharacterData = characters.get_character(&"flicker")
	var clones: SkillData = skills.get_skill(&"shadow_clones")
	var army: SkillData = skills.get_skill(&"shadow_army")
	assert_eq(shade.signature_skill, clones)
	assert_eq(shade.ultimate, army)
	assert_false(skills.is_ultimate(clones))
	assert_true(skills.is_ultimate(army))
	assert_eq(clones.duration, 6.5)
	assert_eq(clones.clone_fire_scale, 0.0)
	assert_gt(army.clone_fire_scale, 0.0)
	assert_true(skills.specials_for(shade).has(clones))
	assert_false(skills.specials_for(shade).has(army))
	assert_true(Unlocks.is_starter_skill(shade, clones))
	assert_true(Unlocks.is_starter_skill(shade, army))
	assert_true(Player.default_skills(shade).has(clones))
