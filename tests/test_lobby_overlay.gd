extends GutTest
## Character select flow: fighter grid -> overlay for the tapped fighter -> back / lock in.


func test_starts_closed() -> void:
	assert_false(LobbyOverlay.new().is_open)


func test_tapping_a_fighter_opens_the_overlay_for_it() -> void:
	var o := LobbyOverlay.new()
	assert_true(o.open_for(&"eden"), "slides in")
	assert_true(o.is_open)
	assert_eq(o.fighter, &"eden")


func test_scrim_or_back_closes() -> void:
	var o := LobbyOverlay.new()
	o.open_for(&"eden")
	assert_true(o.close())
	assert_false(o.is_open)
	assert_false(o.close(), "nothing left to close")


func test_another_fighter_while_open_only_swaps() -> void:
	var o := LobbyOverlay.new()
	o.open_for(&"eden")
	assert_false(o.open_for(&"bolt"), "already in")
	assert_eq(o.fighter, &"bolt")


func test_tapping_a_fighter_while_closing_slides_it_back_in() -> void:
	var o := LobbyOverlay.new()
	o.open_for(&"eden")
	o.close()  # the slide-out is still running
	assert_true(o.open_for(&"bolt"), "reopens from wherever the slide got to")
	assert_eq(o.fighter, &"bolt")


func test_locking_in_closes_unlocking_does_not() -> void:
	var o := LobbyOverlay.new()
	o.open_for(&"eden")
	o.ready_pressed(false)
	assert_true(o.is_open)
	o.ready_pressed(true)
	assert_false(o.is_open)


func test_target_slot_starts_on_the_second_and_advances() -> void:
	var o := LobbyOverlay.new()
	assert_eq(o.take_slot(), 1)
	assert_eq(o.take_slot(), 2)
	assert_eq(o.take_slot(), 0, "wraps round")
	assert_eq(o.target_slot, 1)


func test_tapping_a_slot_makes_it_the_target() -> void:
	var o := LobbyOverlay.new()
	o.set_target(0)
	assert_eq(o.take_slot(), 0)
	assert_eq(o.target_slot, 1, "continues from there")
	o.set_target(99)
	assert_eq(o.target_slot, Constants.SKILL_SLOTS - 1, "clamped")


func test_new_fighter_resets_the_target() -> void:
	var o := LobbyOverlay.new()
	o.set_target(2)
	o.reset_target()
	assert_eq(o.target_slot, LobbyOverlay.DEFAULT_TARGET)
