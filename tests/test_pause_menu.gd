extends GutTest
## Pause menu: freezes an offline match and asks the arena to restart / leave.


func test_pause_freezes_offline_and_restart_signals_arena() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var input := LocalInput.new()
	arena.attach_local_view(arena.add_player(1, 0, input), input)
	var pause: PauseMenu = arena.get_node("UI").get_children().filter(func(n: Node) -> bool: return n is PauseMenu)[0]
	watch_signals(arena)
	pause.open()
	assert_true(get_tree().paused)
	pause.close()
	assert_false(get_tree().paused)
	pause.open()
	pause._leave(true)
	assert_false(get_tree().paused, "unpaused before the arena goes away")
	assert_signal_emitted_with_parameters(arena, "leave_requested", [true])


func test_escape_in_settings_closes_only_the_settings() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var pause := PauseMenu.new()
	pause.arena = arena
	add_child_autofree(pause)
	await wait_physics_frames(2)
	pause.open()
	assert_true(get_tree().paused)
	SettingsPanel.show_on(pause)
	await wait_physics_frames(2)
	var panels: Array[Node] = get_tree().root.find_children("*", "SettingsPanel", true, false)
	assert_eq(panels.size(), 1, "settings is up")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait_physics_frames(2)
	assert_true(pause.is_open(), "the pause menu stays open under the settings")
	assert_true(get_tree().paused, "the match stays paused")
	assert_true(get_tree().root.find_children("*", "SettingsPanel", true, false).is_empty(), "settings closed")
	pause.close()
