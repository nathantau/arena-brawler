extends GutTest
## Bot decisions: weapon-dependent range keeping, dodging, difficulty knob, the one-ability lock, special gating, unsticking.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var skills: SkillCatalog
var weapons: WeaponCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	skills = SkillCatalog.shared()
	weapons = WeaponCatalog.load_all()


func _player(slot0: StringName, slot1: StringName, weapon: StringName = &"pistol", id: int = 1) -> Player:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, weapons.resolve([weapon] as Array[StringName]), null, pool, 3, characters.get_character(&"flicker"))
	world.add_child(p)
	p.global_position = Vector2(300, 300)
	p.skills[0] = CharacterSkill.new(skills.get_skill(slot0))
	p.skills[1] = CharacterSkill.new(skills.get_skill(slot1))
	return p


func test_melee_closes_in_and_snipers_keep_away() -> void:
	var sword: float = BotBrain.preferred_range(weapons.get_weapon(&"sword"))
	var pistol: float = BotBrain.preferred_range(weapons.get_weapon(&"pistol"))
	var sniper: float = BotBrain.preferred_range(weapons.get_weapon(&"sniper"))
	assert_lt(sword, pistol, "melee wants to be closer than a pistol")
	assert_gt(sniper, pistol, "a sniper stays further back")
	assert_lte(sniper, BotBrain.PREF_MAX)
	assert_gte(sword, BotBrain.PREF_MELEE_MIN)


func test_dodge_sidesteps_a_shot_that_would_hit_and_ignores_misses() -> void:
	var me := Vector2(300, 300)
	var side: Vector2 = BotBrain.dodge_dir(me, Vector2(700, 296), Vector2(-900, 0), 30.0, 0.6)
	assert_ne(side, Vector2.ZERO, "incoming shot")
	assert_almost_eq(absf(side.dot(Vector2.RIGHT)), 0.0, 0.001, "sidestep is perpendicular to the shot")
	assert_gt(side.y, 0.0, "the shot passes just above the centre line, so step down, away from it")
	assert_eq(BotBrain.dodge_dir(me, Vector2(700, 400), Vector2(-900, 0), 30.0, 0.6), Vector2.ZERO, "passes wide")
	assert_eq(BotBrain.dodge_dir(me, Vector2(700, 300), Vector2(900, 0), 30.0, 0.6), Vector2.ZERO, "flying away")
	assert_eq(BotBrain.dodge_dir(me, Vector2(2000, 300), Vector2(-900, 0), 30.0, 0.6), Vector2.ZERO, "too far to matter yet")


func test_bot_notices_enemy_projectiles_but_not_its_own() -> void:
	var p: Player = _player(&"dash", &"smoke_bomb", &"pistol", 1)
	var bot := BotBrain.new(null, 1)
	p.projectiles.fire_shot(2, 1, Vector2(640, 300), Vector2.LEFT, weapons.get_weapon(&"sniper"), 3)
	assert_ne(bot._scan_threat(p), Vector2.ZERO, "enemy shot flying at us")
	p.projectiles.clear()
	p.projectiles.fire_shot(1, 2, Vector2(640, 300), Vector2.LEFT, weapons.get_weapon(&"sniper"), 3)
	assert_eq(bot._scan_threat(p), Vector2.ZERO, "our own shot is no threat")


func test_skill_knob_drives_reaction_accuracy_and_dodging() -> void:
	var easy := BotBrain.new(null, 1)
	easy.skill = 0.0
	var hard := BotBrain.new(null, 1)
	hard.skill = 1.0
	assert_gt(easy.reaction_time(), hard.reaction_time())
	assert_gt(easy.aim_error_deg(), hard.aim_error_deg())
	assert_lt(easy.turn_rate(), hard.turn_rate())
	assert_lt(easy.dodge_chance(), hard.dodge_chance())
	assert_eq(BotBrain.new(null, 1).skill, BotBrain.SKILL_DEFAULT)


func test_press_respects_the_one_ability_lock() -> void:
	var p: Player = _player(&"dash", &"smoke_bomb")
	assert_true(BotBrain.can_press(p, 1))
	var f := InputFrame.new()
	f.seq = 1
	f.aim_vec = Vector2.RIGHT
	f.move_vec = Vector2.RIGHT
	f.skill = true
	p.simulate(f, DT)
	assert_true(p.skills[0].is_active(), "dashing")
	assert_false(BotBrain.can_press(p, 1), "special locked while dashing")
	assert_false(BotBrain.can_press(p, 0), "dash is busy")


func test_specials_are_used_at_sensible_moments() -> void:
	var bot := BotBrain.new(null, 1)
	var p: Player = _player(&"dash", &"barrier")
	assert_true(bot.slot_wanted(p, 1, 200.0, true, true), "barrier when shot at")
	assert_false(bot.slot_wanted(p, 1, 200.0, true, false), "not for nothing")
	assert_false(bot.slot_wanted(p, 1, INF, false, true), "not with nobody in sight")
	var nova: Player = _player(&"dash", &"smoke_bomb")
	assert_false(bot.slot_wanted(nova, 1, 200.0, true, false), "smoke is for when hurt")
	nova.stats.hp = 20
	assert_true(bot.slot_wanted(nova, 1, 200.0, true, true), "smoke when hurt and pressured")
	var hurt_dash: Player = _player(&"dash", &"barrier")
	hurt_dash.stats.hp = 20
	assert_true(bot.slot_wanted(hurt_dash, 0, 120.0, true, true), "dash away when low and pressed")
	assert_false(bot.slot_wanted(hurt_dash, 0, 120.0, true, false), "no reason to dash when nobody's hitting us")


func test_unstick_triggers_only_when_trying_to_move_and_not_moving() -> void:
	var bot := BotBrain.new(null, 1)
	var fired: bool = false
	for i: int in 80:
		fired = fired or bot.track_stuck(Vector2(100, 100), true, DT)
	assert_true(fired, "wanted to move for a second and went nowhere")
	assert_gt(bot.stuck_time, 0.0)
	var moving := BotBrain.new(null, 1)
	var pos := Vector2(100, 100)
	var ever: bool = false
	for i: int in 60:
		pos += Vector2(2, 0)
		ever = ever or moving.track_stuck(pos, true, DT)
	assert_false(ever, "walking freely")
	var idle := BotBrain.new(null, 1)
	for i: int in 60:
		assert_false(idle.track_stuck(Vector2.ZERO, false, DT), "standing still on purpose is fine")


func test_bot_can_target_another_bot() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var a := BotBrain.new(arena, 1)
	var b := BotBrain.new(arena, 2)
	var pa: Player = arena.add_player(1, 0, a, true)
	var pb: Player = arena.add_player(2, 1, b, true)
	pa.global_position = Vector2(300, 300)
	pb.global_position = Vector2(400, 300)
	await wait_physics_frames(2)
	assert_ne(a._nearest_visible_enemy(pa), null, "FFA: a bot fights other bots")
	assert_eq(a._target, pb)
