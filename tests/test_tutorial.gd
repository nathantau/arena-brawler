extends GutTest

const TMP: String = "user://test_tutorial.cfg"

var _saved_done: bool = false


func before_each() -> void:
	_saved_done = GameSettings.tutorial_done
	GameSettings.tutorial_done = false


func after_each() -> void:
	GameSettings.tutorial_done = _saved_done
	DirAccess.remove_absolute(TMP)


func _to(flow: TutorialFlow, step: TutorialFlow.Step) -> void:
	if step >= TutorialFlow.Step.SHOOT:
		flow.add_travel(TutorialFlow.MOVE_GOAL)
	if step >= TutorialFlow.Step.ABILITY:
		for i: int in TutorialFlow.HIT_GOAL:
			flow.add_hit()
	if step >= TutorialFlow.Step.ULTIMATE:
		flow.slot_pressed(0)
	if step >= TutorialFlow.Step.DEFEAT:
		flow.slot_pressed(TutorialFlow.ULTIMATE_SLOT)
	if step >= TutorialFlow.Step.DONE:
		flow.bot_defeated()


func test_move_needs_the_full_distance() -> void:
	var f := TutorialFlow.new()
	f.add_travel(TutorialFlow.MOVE_GOAL - 1.0)
	assert_eq(f.step, TutorialFlow.Step.MOVE)
	f.add_travel(1.0)
	assert_eq(f.step, TutorialFlow.Step.SHOOT)


func test_shoot_needs_three_hits() -> void:
	var f := TutorialFlow.new()
	_to(f, TutorialFlow.Step.SHOOT)
	f.add_hit()
	f.add_hit()
	assert_eq(f.step, TutorialFlow.Step.SHOOT)
	f.add_hit()
	assert_eq(f.step, TutorialFlow.Step.ABILITY)


func test_hits_before_their_step_do_not_count() -> void:
	var f := TutorialFlow.new()
	for i: int in 5:
		f.add_hit()
	_to(f, TutorialFlow.Step.SHOOT)
	assert_eq(f.hits, 0)


func test_ability_takes_either_ability_button_but_not_the_ultimate() -> void:
	for slot: int in [0, 1]:
		var f := TutorialFlow.new()
		_to(f, TutorialFlow.Step.ABILITY)
		f.slot_pressed(TutorialFlow.ULTIMATE_SLOT)
		assert_eq(f.step, TutorialFlow.Step.ABILITY)
		f.slot_pressed(slot)
		assert_eq(f.step, TutorialFlow.Step.ULTIMATE)


func test_ultimate_waits_for_slot_two() -> void:
	var f := TutorialFlow.new()
	_to(f, TutorialFlow.Step.ULTIMATE)
	f.slot_pressed(0)
	f.slot_pressed(1)
	assert_eq(f.step, TutorialFlow.Step.ULTIMATE)
	f.slot_pressed(TutorialFlow.ULTIMATE_SLOT)
	assert_eq(f.step, TutorialFlow.Step.DEFEAT)


func test_defeating_the_bot_ends_the_steps() -> void:
	var f := TutorialFlow.new()
	f.bot_defeated()
	assert_eq(f.step, TutorialFlow.Step.MOVE, "a kill before the step does nothing")
	_to(f, TutorialFlow.Step.DEFEAT)
	f.bot_defeated()
	assert_eq(f.step, TutorialFlow.Step.DONE)
	assert_false(f.is_finished)


func test_finish_only_from_the_last_step_and_marks_done() -> void:
	var f := TutorialFlow.new()
	watch_signals(f)
	f.finish()
	assert_false(f.is_finished)
	assert_false(GameSettings.tutorial_done)
	_to(f, TutorialFlow.Step.DONE)
	f.finish()
	assert_true(f.is_finished)
	assert_true(GameSettings.tutorial_done)
	assert_signal_emitted_with_parameters(f, "finished", [false])


func test_skip_works_on_any_step_and_marks_done() -> void:
	for step: int in TutorialFlow.Step.size():
		GameSettings.tutorial_done = false
		var f := TutorialFlow.new()
		_to(f, step as TutorialFlow.Step)
		watch_signals(f)
		f.skip()
		assert_true(f.is_finished and f.skipped, "step %d" % step)
		assert_true(GameSettings.tutorial_done)
		assert_signal_emitted_with_parameters(f, "finished", [true])


func test_steps_stop_after_finish() -> void:
	var f := TutorialFlow.new()
	f.skip()
	f.add_travel(1000.0)
	assert_eq(f.step, TutorialFlow.Step.MOVE, "a skipped tutorial stays put")


func test_tutorial_done_persists() -> void:
	GameSettings.tutorial_done = true
	assert_eq(GameSettings.save_to(TMP), OK)
	GameSettings.tutorial_done = false
	GameSettings.load_from(TMP)
	assert_true(GameSettings.tutorial_done)


func test_prompts_exist_for_every_step() -> void:
	for s: int in TutorialFlow.Step.size():
		assert_ne(TutorialFlow.prompt(s as TutorialFlow.Step, true), "")
		assert_ne(TutorialFlow.prompt(s as TutorialFlow.Step, false), "")


func test_min_hp_stops_lethal_hits() -> void:
	var arena := Arena.new()
	add_child_autofree(arena)
	var p: Player = arena.add_player(1, 0, LocalInput.new())
	p.min_hp = TutorialFlow.MIN_HP
	p.take_hit(9999, false, Vector2.ZERO, 5)
	assert_false(p.dead)
	assert_eq(p.stats.hp + p.stats.armor, TutorialFlow.MIN_HP)
	p.take_hit(50, false, Vector2.ZERO, 5)
	assert_false(p.dead)
	assert_eq(p.stats.hp + p.stats.armor, TutorialFlow.MIN_HP)
