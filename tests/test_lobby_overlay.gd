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
	var r: Dictionary = LobbyOverlay.toggle([&"dash", &""], &"barrier", [0, 1])
	assert_eq(r["kind"], "add")
	assert_eq(r["slot"], 1)
	assert_eq(LobbyOverlay.toggle([&"", &""], &"barrier", [0, 1])["slot"], 0)


func test_tapping_an_equipped_ability_removes_it() -> void:
	var r: Dictionary = LobbyOverlay.toggle([&"dash", &"bark_skin"], &"bark_skin", [0, 1])
	assert_eq(r["kind"], "remove")
	assert_eq(r["slot"], 1)


func test_full_slots_replace_the_least_recently_set() -> void:
	var r: Dictionary = LobbyOverlay.toggle([&"dash", &"bark_skin"], &"barrier", [1, 0])
	assert_eq(r["kind"], "add")
	assert_eq(r["slot"], 1, "slot 1 was set longest ago")


func test_remove_then_add_round_trip() -> void:
	var slots: Array = [&"dash", &"bark_skin"]
	var r: Dictionary = LobbyOverlay.toggle(slots, &"bark_skin", [0, 1])
	slots[r["slot"]] = &""
	r = LobbyOverlay.toggle(slots, &"barrier", [0, 1])
	assert_eq(r["kind"], "add")
	assert_eq(r["slot"], 1, "the freed slot")


func test_opens_on_the_abilities_tab() -> void:
	var o := LobbyOverlay.new()
	o.open_for(&"eden")
	assert_eq(o.tab, LobbyOverlay.Tab.ABILITIES)
	o.show_tab(LobbyOverlay.Tab.WEAPON)
	o.close()
	o.open_for(&"eden")
	assert_eq(o.tab, LobbyOverlay.Tab.ABILITIES, "reopening starts on abilities again")


func test_another_fighter_resets_the_tab_but_the_same_one_keeps_it() -> void:
	var o := LobbyOverlay.new()
	o.open_for(&"eden")
	o.show_tab(LobbyOverlay.Tab.WEAPON)
	o.open_for(&"eden")
	assert_eq(o.tab, LobbyOverlay.Tab.WEAPON)
	o.open_for(&"bolt")
	assert_eq(o.tab, LobbyOverlay.Tab.ABILITIES)


func test_show_tab_reports_a_change() -> void:
	var o := LobbyOverlay.new()
	assert_false(o.show_tab(LobbyOverlay.Tab.ABILITIES))
	assert_true(o.show_tab(LobbyOverlay.Tab.WEAPON))


func test_the_third_ability_switches_to_the_weapon_tab() -> void:
	var o := LobbyOverlay.new()
	o.open_for(&"eden")
	assert_false(o.ability_added([&"a", &"", &""]))
	assert_false(o.ability_added([&"a", &"b", &""]))
	assert_eq(o.tab, LobbyOverlay.Tab.ABILITIES)
	assert_true(o.ability_added([&"a", &"b", &"c"]))
	assert_eq(o.tab, LobbyOverlay.Tab.WEAPON)


func test_no_auto_switch_when_already_on_weapons() -> void:
	var o := LobbyOverlay.new()
	o.open_for(&"eden")
	o.show_tab(LobbyOverlay.Tab.WEAPON)
	assert_false(o.ability_added([&"a", &"b", &"c"]))
