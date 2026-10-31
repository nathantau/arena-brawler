extends GutTest
## Pause menu: freezes an offline match and asks the arena to restart / leave.


func test_pause_freezes_offline_and_restart_signals_arena() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var input := LocalInput.new()
	arena.attach_local_view(arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, input), input)
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
