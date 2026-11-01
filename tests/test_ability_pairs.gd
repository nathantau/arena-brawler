extends GutTest
## Harness: every in-rotation fighter x every ordered pair of their specials (Dash included), pressed close together, with a
## stun / a death + respawn thrown in. Afterwards the player must be clean: abilities over, visible, normal speed, no leftover
## effect state. Runs the sim and the player's visual sync by hand (no rendering needed).

const DT: float = 1.0 / 60.0
const MAX_FRAMES: int = 720
const SETTLE_FRAMES: int = 150

var arena: Arena
var me: Player
var foe: Player


func before_each() -> void:
	arena = Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	me = arena.add_player(1, 0, null)
	foe = arena.add_player(2, 1, null)
	await wait_physics_frames(2)


func _spot() -> Vector2:
	return arena.play_area().get_center()


func _frame(seq: int, press0: bool, press1: bool, move: Vector2) -> InputFrame:
	var f := InputFrame.new()
	f.seq = seq
	f.aim_vec = Vector2.RIGHT
	f.move_vec = move
	f.fire = true
	f.skill = press0
	f.special = press1
	return f


func _tick(seq: int, press0: bool, press1: bool, move: Vector2) -> void:
	me.simulate(_frame(seq, press0, press1, move), DT)
	me._process(DT)
	me._special_fx._process(DT)


func _busy() -> bool:
	return me.skills[0].is_active() or me.skills[1].is_active()


func _check_clean(label: String) -> void:
	assert_false(_busy(), "%s: abilities over" % label)
	assert_true(me.visible and not me.dead, "%s: visible" % label)
	assert_false(me._special_fx.hides_owner() or me._special_fx.is_swinging(), "%s: body not hidden by fx" % label)
	assert_almost_eq(me._sprite.modulate.a, 1.0, 0.01, "%s: sprite opaque" % label)
	assert_true(me._special_fx._poofs.is_empty(), "%s: no leftover poofs" % label)
	assert_false(me._shield.is_up() or me._ward.is_up(), "%s: barrier / ward down" % label)
	assert_eq(me.clone_points().size(), 0, "%s: no clones" % label)
	assert_false(me.is_hidden(), "%s: targetable" % label)
	assert_false(me.stats.is_stunned(), "%s: not stunned" % label)
	assert_true(arena.play_area().grow(Constants.PLAYER_RADIUS + 1.0).has_point(me.global_position), "%s: inside the arena" % label)
	assert_false(is_nan(me.global_position.x) or is_nan(me.velocity.x), "%s: sane numbers" % label)
	assert_null(me.form(), "%s: no form" % label)
	assert_eq(me.collision_mask, Constants.LAYER_WALL_FEET, "%s: collides again" % label)
	for i: int in 40:  # speed back to normal
		_tick(10000 + i, false, false, Vector2.RIGHT)
	assert_lte(me.velocity.length(), me.character.move_speed * me.stats.speed_scale() * 1.01 + 0.1, "%s: normal speed" % label)


## `mode` 0: press both; 1: a stun lands mid-way; 2: killed mid-way and respawned.
func _run(a: SkillData, b: SkillData, mode: int) -> void:
	me.global_position = _spot()
	foe.global_position = _spot() + Vector2(180.0, 0.0)
	me.respawn(_spot())
	me.skills[0] = CharacterSkill.new(a)
	me.skills[1] = CharacterSkill.new(b)
	me.facing = Vector2.RIGHT
	var label := "%s %s+%s m%d" % [me.character.id, a.id, b.id, mode]
	for f: int in MAX_FRAMES:
		_tick(f + 1, f == 0, f == 8, Vector2.RIGHT if f % 120 < 60 else Vector2.LEFT)
		if mode == 1 and f == 14:
			me.stats.stun_remaining = 1.0
		if mode == 2 and f == 20:
			me.stats.invulnerable_time = 0.0
			me.stats.spawn_protect = 0.0
			me.take_hit(10000, false, Vector2.ZERO, 2)
			assert_true(me.dead, label)
			assert_false(_busy(), "%s: dying ends every ability" % label)
			me._process(DT)
			me._special_fx._process(DT)
			me.respawn(_spot())
			me.stats.invulnerable_time = 0.0
			me.stats.spawn_protect = 0.0  # (its blink would show as a not-opaque sprite)
			break
		if f > 20 and not _busy():
			break
	for i: int in SETTLE_FRAMES:
		_tick(5000 + i, false, false, Vector2.ZERO)
	_check_clean(label)


func test_every_pair_for_every_fighter() -> void:
	var cat := SkillCatalog.shared()
	for c: CharacterData in CharacterCatalog.load_all().ordered:
		if not c.in_rotation:
			continue
		arena.match_state.phase = MatchState.Phase.LOBBY
		arena.select_character(me, c.id)
		var pool: Array[SkillData] = cat.specials_for(c)
		for a: SkillData in pool:
			for b: SkillData in pool:
				if a == b:
					continue
				_run(a, b, 0)
				if pool.find(a) < pool.find(b):
					_run(a, b, 1)
					_run(a, b, 2)
	assert_true(true)
