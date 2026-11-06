extends GutTest
## Drag-to-aim: the attack button and the skill buttons override auto-aim; Aim assist off removes auto-aim.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var skills: SkillCatalog
var _assist_saved: bool = true


func before_all() -> void:
	InputSetup.ensure_actions()
	characters = CharacterCatalog.load_all()
	skills = SkillCatalog.shared()


func before_each() -> void:
	_assist_saved = GameSettings.aim_assist


func after_each() -> void:
	GameSettings.aim_assist = _assist_saved


func _touch() -> TouchControls:
	var tc: TouchControls = autofree(TouchControls.new())
	tc.size = Vector2(1280, 720)
	return tc


## A local input with a player and one enemy in sight, up-left of him (auto-aim would point there).
func _rig(tc: TouchControls) -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var arena: Arena = autofree(Arena.new(Arena.Mode.CLIENT, 1))
	var me := Player.new()
	me.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"flicker"))
	world.add_child(me)
	me.global_position = Vector2(500, 500)
	var foe := Player.new()
	foe.setup(2, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(&"flicker"))
	world.add_child(foe)
	foe.global_position = Vector2(500, 300)
	arena.players = [me, foe] as Array[Player]
	var input := LocalInput.new()
	input.arena = arena
	input.touch = tc
	tc.visible = true
	return [input, me]


func test_attack_drag_beyond_deadzone_sets_manual_aim_and_overrides_auto_aim() -> void:
	var tc: TouchControls = _touch()
	var rig: Array = _rig(tc)
	var input: LocalInput = rig[0]
	var me: Player = rig[1]
	var c: Vector2 = tc._attack_center()
	tc._on_press(0, c)
	var auto: InputFrame = input.get_input(me, DT)
	assert_true(auto.fire)
	assert_lt(auto.aim_vec.y, -0.5, "not dragging: auto-aim at the enemy above")
	tc._on_drag(0, c + Vector2(40, 0))
	assert_gt(tc.attack_aim.x, 0.0)
	var manual: InputFrame = input.get_input(me, DT)
	assert_almost_eq(manual.aim_vec.x, 1.0, 0.01, "the drag wins over auto-aim")
	assert_eq(input.guide_aim(), tc.attack_aim)
	assert_eq(input.guide_slot, -1)
	assert_false(input.shows_aim_marker())


func test_dragged_special_casts_on_release_in_the_dragged_direction() -> void:
	var tc: TouchControls = _touch()
	var rig: Array = _rig(tc)
	var input: LocalInput = rig[0]
	var me: Player = rig[1]
	me.skills[1] = CharacterSkill.new(skills.get_skill(&"blossom_snare"))
	var c: Vector2 = tc._special_center()
	tc._on_press(0, c)
	tc._on_drag(0, c + Vector2(-50, 0))
	assert_false(tc.special_held, "nothing is cast while the thumb is still down")
	assert_ne(input.guide_aim(), Vector2.ZERO, "the guide follows the drag")
	assert_eq(input.guide_slot, 1)
	assert_false(input.get_input(me, DT).special)
	tc._on_release(0)
	var f: InputFrame = input.get_input(me, DT)
	assert_true(f.special)
	assert_almost_eq(f.aim_vec.x, -1.0, 0.01, "cast along the drag, not at the enemy")
	me.simulate(f, DT)
	assert_lt(me.skills[1].direction.x, -0.99)
	assert_false(me.skills[1].is_ready())


func test_tapped_special_casts_with_auto_aim() -> void:
	var tc: TouchControls = _touch()
	var rig: Array = _rig(tc)
	var input: LocalInput = rig[0]
	var me: Player = rig[1]
	me.skills[1] = CharacterSkill.new(skills.get_skill(&"blossom_snare"))
	var c: Vector2 = tc._special_center()
	tc._on_press(0, c)
	tc._on_drag(0, c + Vector2(5, 3))  # a wobble inside the deadzone is still a tap
	tc._on_release(0)
	var f: InputFrame = input.get_input(me, DT)
	assert_true(f.special)
	assert_lt(f.aim_vec.y, -0.5, "auto-aimed at the enemy above")
	assert_eq(tc.cast_aim, Vector2.ZERO)


func test_dragging_back_into_the_deadzone_cancels_to_auto_aim() -> void:
	var tc: TouchControls = _touch()
	var rig: Array = _rig(tc)
	var input: LocalInput = rig[0]
	var me: Player = rig[1]
	var c: Vector2 = tc._special_center()
	tc._on_press(0, c)
	tc._on_drag(0, c + Vector2(60, 0))
	assert_ne(tc.skill_aim[1], Vector2.ZERO)
	tc._on_drag(0, c + Vector2(4, 0))
	assert_eq(tc.skill_aim[1], Vector2.ZERO)
	assert_eq(input.guide_aim(), Vector2.ZERO, "no guide once cancelled")
	tc._on_release(0)
	var f: InputFrame = input.get_input(me, DT)
	assert_true(f.special)
	assert_lt(f.aim_vec.y, -0.5, "auto-aim")


func test_cast_pulse_lasts_a_couple_of_frames() -> void:
	var tc: TouchControls = _touch()
	tc._on_press(0, tc._skill_center())
	assert_false(tc.skill_held)
	tc._on_release(0)
	assert_true(tc.skill_held)
	for i: int in TouchControls.CAST_PULSE_FRAMES:
		tc._physics_process(DT)
	assert_false(tc.skill_held)


func test_aim_assist_off_has_no_auto_target_aim() -> void:
	GameSettings.aim_assist = false
	var tc: TouchControls = _touch()
	var rig: Array = _rig(tc)
	var input: LocalInput = rig[0]
	var me: Player = rig[1]
	tc._on_press(0, tc._attack_center())
	var f: InputFrame = input.get_input(me, DT)
	assert_true(f.fire)
	assert_eq(f.aim_vec, Vector2.ZERO, "no manual aim yet: shoots along the facing")
	assert_false(input.shows_aim_marker())
	var c: Vector2 = tc._attack_center()
	tc._on_drag(0, c + Vector2(0, 40))
	input.get_input(me, DT)
	tc._on_drag(0, c)
	var held: InputFrame = input.get_input(me, DT)
	assert_gt(held.aim_vec.y, 0.99, "keeps the last manual aim")
	# a tapped special uses the facing
	tc._on_release(0)
	tc._on_press(1, tc._special_center())
	tc._on_release(1)
	input.last_manual_aim = Vector2.ZERO
	assert_eq(input.get_input(me, DT).aim_vec, Vector2.ZERO)


func test_aim_assist_setting_round_trips() -> void:
	var path: String = "user://test_drag_aim.cfg"
	GameSettings.aim_assist = false
	assert_eq(GameSettings.save_to(path), OK)
	GameSettings.aim_assist = true
	GameSettings.load_from(path)
	assert_false(GameSettings.aim_assist)
	DirAccess.remove_absolute(path)


func test_guide_shapes() -> void:
	var w := WeaponData.new()
	w.projectile_range = 500.0
	var line: Dictionary = AimGuide.weapon_shape(w)
	assert_eq(line["cone"], 0.0)
	assert_eq(line["land"], 0.0)
	w.pellets = 6
	w.pellet_spread_deg = 30.0
	assert_eq(AimGuide.weapon_shape(w)["cone"], 30.0)
	w.pellets = 1
	w.pellet_spread_deg = 0.0
	w.lob_height = 20.0
	w.splash_radius = 40.0
	assert_eq(AimGuide.weapon_shape(w)["land"], 40.0)
	w.kind = WeaponData.Kind.MELEE
	assert_eq(AimGuide.weapon_shape(w)["reach"], w.melee_range)
