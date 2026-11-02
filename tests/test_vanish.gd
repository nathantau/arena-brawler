extends GutTest
## Smoke Bomb: a poof, then Shade is invisible to enemies for `duration`; firing or another special breaks it; bots skip her.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var skills: SkillCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	skills = SkillCatalog.shared()


func _shade(local: bool = true, id: int = 1) -> Player:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"flicker"))
	p.is_local = local
	world.add_child(p)
	p.global_position = Vector2(300, 300)
	p.set_skill(1, skills.get_skill(&"smoke_bomb"))
	return p


func _step(p: Player, frames: int, fire: bool = false, special: bool = false, seq: int = 10) -> void:
	var f := InputFrame.new()
	f.aim_vec = Vector2.RIGHT
	f.fire = fire
	f.special = special
	for i: int in frames:
		f.seq = seq + i
		p.simulate(f, DT)
		f.special = false


func _poof_count(p: Player) -> int:
	return p._special_fx._poofs.size()


func test_press_vanishes_for_the_duration_then_reappears() -> void:
	var p: Player = _shade(false)
	var d: SkillData = skills.get_skill(&"smoke_bomb")
	assert_eq(d.duration, 3.0)
	await wait_physics_frames(2)
	assert_false(p.is_vanished())
	_step(p, 1, false, true)
	p._process(DT)
	assert_true(p.is_vanished())
	assert_true(p.is_concealed(), "an enemy's view of her draws nothing")
	assert_eq(_poof_count(p), 1, "the poof that hides her")
	_step(p, int(d.duration / DT) - 5, false, false, 20)
	assert_true(p.is_vanished())
	_step(p, 10, false, false, 400)
	p._process(DT)
	assert_false(p.is_vanished(), "timed out")
	assert_eq(_poof_count(p), 2, "and the one she returns in")


func test_you_see_yourself_but_enemies_do_not() -> void:
	var me: Player = _shade(true)
	await wait_physics_frames(2)
	_step(me, 1, false, true)
	for i: int in 30:
		me._process(DT)
	assert_true(me.is_vanished())
	assert_false(me.is_concealed())
	assert_almost_eq(me._sprite.modulate.a, Player.INVULN_ALPHA, 0.01, "ghosted for herself")
	var other: Player = _shade(false, 2)
	await wait_physics_frames(2)
	_step(other, 1, false, true)
	for i: int in 30:
		other._process(DT)
	assert_eq(other._sprite.modulate.a, 0.0, "not drawn for enemies")


func test_firing_breaks_it_and_the_cooldown_keeps_running() -> void:
	var p: Player = _shade(false)
	await wait_physics_frames(2)
	_step(p, 1, false, true)
	p._process(DT)
	assert_true(p.is_vanished())
	_step(p, 1, true, false, 50)
	p._process(DT)
	assert_false(p.is_vanished(), "shooting gives her away")
	assert_eq(_poof_count(p), 2, "reappearing poof")
	assert_gt(p.skills[1].cooldown_remaining, 0.0)


func test_another_special_breaks_it() -> void:
	var p: Player = _shade(false)
	await wait_physics_frames(2)
	_step(p, 1, false, true)
	assert_true(p.is_vanished())
	var f := InputFrame.new()
	f.seq = 60
	f.aim_vec = Vector2.RIGHT
	f.skill = true  # Dash, slot 0
	p.simulate(f, DT)
	assert_false(p.is_vanished())


func test_bots_ignore_a_vanished_player() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var a := BotBrain.new(arena, 1)
	var b := BotBrain.new(arena, 2)
	var pa: Player = arena.add_player(1, 0, a, true)
	var pb: Player = arena.add_player(2, 1, b, true)
	pa.global_position = Vector2(300, 300)
	pb.global_position = Vector2(400, 300)
	await wait_physics_frames(2)
	pb.frozen = false
	pb.skills[1] = CharacterSkill.new(skills.get_skill(&"smoke_bomb"))  # after the arena has set up the kit; set_skill would swap
	assert_ne(a._nearest_visible_enemy(pa), null)
	_step(pb, 1, false, true)
	assert_true(pb.is_hidden())
	assert_eq(a._nearest_visible_enemy(pa), null, "invisible")


func test_snapshot_roundtrip_keeps_her_invisible() -> void:
	var a: Player = _shade(false)
	var b: Player = _shade(false, 2)
	await wait_physics_frames(2)
	_step(a, 20, false, true)
	assert_true(b.apply_state(a.capture_state(), WeaponCatalog.load_all(), characters))
	assert_true(b.is_vanished())
	assert_almost_eq(b.skills[1].active_remaining, a.skills[1].active_remaining, 0.0001)
