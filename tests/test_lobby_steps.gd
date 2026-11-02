extends GutTest
## Character select flow: fighter -> abilities -> weapon, with back navigation.


func test_starts_on_the_fighter_step() -> void:
	assert_eq(LobbySteps.new().step, LobbySteps.Step.FIGHTER)


func test_fighter_pick_opens_abilities() -> void:
	var s := LobbySteps.new()
	s.pick_fighter(true)
	assert_eq(s.step, LobbySteps.Step.ABILITIES)


func test_third_special_opens_weapons() -> void:
	var s := LobbySteps.new()
	s.pick_fighter(true)
	s.pick_special(Constants.SKILL_SLOTS)
	s.pick_special(Constants.SKILL_SLOTS)
	assert_eq(s.step, LobbySteps.Step.ABILITIES, "two picks: still choosing")
	s.pick_special(Constants.SKILL_SLOTS)
	assert_eq(s.step, LobbySteps.Step.WEAPON)


func test_back_navigation_and_repick() -> void:
	var s := LobbySteps.new()
	s.pick_fighter(true)
	s.go(LobbySteps.Step.WEAPON)
	s.go(LobbySteps.Step.FIGHTER)
	assert_eq(s.step, LobbySteps.Step.FIGHTER)
	s.pick_fighter(false)
	assert_eq(s.step, LobbySteps.Step.ABILITIES, "same fighter tapped again still moves on")


func test_new_fighter_resets_the_special_count() -> void:
	var s := LobbySteps.new()
	s.pick_fighter(true)
	s.pick_special(Constants.SKILL_SLOTS)
	s.pick_special(Constants.SKILL_SLOTS)
	s.pick_fighter(true)
	s.pick_special(Constants.SKILL_SLOTS)
	assert_eq(s.step, LobbySteps.Step.ABILITIES, "count restarted")


func test_next_stops_at_weapon() -> void:
	var s := LobbySteps.new()
	s.next()
	s.next()
	s.next()
	assert_eq(s.step, LobbySteps.Step.WEAPON)
