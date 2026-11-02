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


func test_tapping_an_unequipped_ability_takes_the_first_empty_slot() -> void:
	var r: Dictionary = LobbyOverlay.toggle([&"dash", &"", &"leaf_gust"], &"barrier")
	assert_eq(r["kind"], "add")
	assert_eq(r["slot"], 1)
	assert_eq(LobbyOverlay.toggle([&"", &"", &"leaf_gust"], &"barrier")["slot"], 0)


func test_tapping_an_equipped_ability_removes_it() -> void:
	var r: Dictionary = LobbyOverlay.toggle([&"dash", &"bark_skin", &"leaf_gust"], &"bark_skin")
	assert_eq(r["kind"], "remove")
	assert_eq(r["slot"], 1)


func test_full_slots_refuse_a_new_ability() -> void:
	assert_eq(LobbyOverlay.toggle([&"dash", &"bark_skin", &"leaf_gust"], &"barrier")["kind"], "full")


func test_remove_then_add_round_trip() -> void:
	var slots: Array = [&"dash", &"bark_skin", &"leaf_gust"]
	var r: Dictionary = LobbyOverlay.toggle(slots, &"bark_skin")
	slots[r["slot"]] = &""
	r = LobbyOverlay.toggle(slots, &"barrier")
	assert_eq(r["kind"], "add")
	assert_eq(r["slot"], 1, "the freed slot")
