extends GutTest
## Teams hero select: one locked fighter per team (server-enforced, first request wins), teammates see hovers and
## locks but enemies never do, bots yield to humans, Duel / FFA unchanged.

const A: int = MatchRules.TEAM_A
const B: int = MatchRules.TEAM_B
const SHADE: StringName = &"flicker"
const EDEN: StringName = &"eden"


func _teams_controller(humans: Array[int], bots: Array[int]) -> MatchController:
	var c := MatchController.new()
	c.set_mode(MatchRules.Mode.TEAMS)
	c.tick(0.0, humans, bots, ScoreBoard.new())  # fills the participants preview
	return c


func test_second_teammate_cannot_lock_a_taken_fighter() -> void:
	var c := _teams_controller([1, 2], [10, 11, 12, 13])
	c.set_team(1, A)
	c.set_team(2, A)
	assert_eq(c.set_ready(1, true, SHADE), 0)
	assert_eq(c.set_ready(2, true, SHADE), 1, "refused, holder reported")
	assert_false(c.state.ready.has(2))
	assert_eq(c.set_ready(2, true, EDEN), 0, "another fighter is fine")


func test_first_request_wins_and_enemy_team_may_share() -> void:
	var c := _teams_controller([1, 2, 3], [10, 11, 12])
	c.set_team(1, A)
	c.set_team(2, A)
	c.set_team(3, B)
	assert_eq(c.set_ready(2, true, SHADE), 0, "processed first")
	assert_eq(c.set_ready(1, true, SHADE), 2, "processed second")
	assert_eq(c.set_ready(3, true, SHADE), 0, "enemy team is a different pool")


func test_unlock_frees_the_fighter() -> void:
	var c := _teams_controller([1, 2], [10, 11, 12, 13])
	c.set_team(1, A)
	c.set_team(2, A)
	c.set_ready(1, true, SHADE)
	c.set_ready(1, false, SHADE)
	assert_eq(c.set_ready(2, true, SHADE), 0)


func test_switching_team_unlocks_when_taken_on_the_new_team() -> void:
	var c := _teams_controller([1, 2], [10, 11, 12, 13])
	c.set_team(1, A)
	c.set_team(2, B)
	c.set_ready(1, true, SHADE)
	c.set_ready(2, true, SHADE)
	assert_true(c.state.ready.has(2))
	c.set_team(2, A)
	assert_false(c.state.ready.has(2), "player 2 lost the race on team A")
	assert_false(c.state.locked.has(2))
	assert_true(c.state.ready.has(1))


func test_duel_and_ffa_ready_ignores_fighters() -> void:
	for mode: MatchRules.Mode in [MatchRules.Mode.DUEL, MatchRules.Mode.FFA]:
		var c := MatchController.new()
		c.set_mode(mode)
		c.tick(0.0, [1, 2], [], ScoreBoard.new())
		assert_eq(c.set_ready(1, true, SHADE), 0)
		assert_eq(c.set_ready(2, true, SHADE), 0, "same fighter is fine outside Teams")
		assert_true(c.state.locked.is_empty())


func test_locks_survive_the_wire() -> void:
	var s := MatchState.new()
	s.locked[1] = SHADE
	s.locked[10] = EDEN
	var r := MatchState.new()
	assert_true(r.apply_array(s.to_array()))
	assert_eq(r.locked, s.locked)


func test_enemies_never_see_picks() -> void:
	var teams: Dictionary = {1: A, 2: A, 3: B}
	var hovers: Dictionary = {1: SHADE, 2: EDEN, 3: SHADE}
	var locked: Dictionary = {2: EDEN}
	var mine: Dictionary = MatchRules.teammate_picks(1, teams, hovers, locked)
	assert_eq(mine.keys(), [2], "only the teammate")
	assert_eq(mine[2], [EDEN, true])
	var theirs: Dictionary = MatchRules.teammate_picks(3, teams, hovers, locked)
	assert_true(theirs.is_empty(), "alone on team B: nobody else's pick is visible")
	var hover_only: Dictionary = MatchRules.teammate_picks(2, teams, hovers, {})
	assert_eq(hover_only[1], [SHADE, false], "a hover is visible, not locked")


func _lobby_arena() -> Arena:
	var arena := Arena.new(Arena.Mode.OFFLINE, 1, MatchRules.Mode.TEAMS)
	add_child_autofree(arena)
	arena.add_player(1, 0, BotBrain.new(arena, 1))
	return arena


func _step(arena: Arena, n: int = 3) -> void:
	for i: int in n:
		arena._physics_process(1.0 / 60.0)


func test_bots_hold_distinct_fighters_and_count_as_locked() -> void:
	var arena := _lobby_arena()
	_step(arena, 10)
	var st: MatchState = arena.match_state
	var teams: Dictionary[int, int] = MatchRules.assign_teams(st.participants, st.teams)
	for team: int in [A, B]:
		var seen: Array[StringName] = []
		for id: int in st.participants:
			if teams[id] == team and id != 1:
				assert_true(st.locked.has(id), "bot is locked at once")
				assert_false(seen.has(st.locked[id]), "no two bots share a fighter")
				seen.append(st.locked[id])


func test_bot_switches_away_when_a_human_locks_its_fighter() -> void:
	var arena := _lobby_arena()
	_step(arena, 10)
	var st: MatchState = arena.match_state
	var teams: Dictionary[int, int] = MatchRules.assign_teams(st.participants, st.teams)
	var mate: int = 0
	for id: int in st.participants:
		if id != 1 and teams[id] == teams[1]:
			mate = id
			break
	assert_ne(mate, 0)
	var want: StringName = arena.get_player(mate).character.id
	arena.select_character(arena.get_player(1), want)
	arena.fill_gaps(arena.get_player(1))  # a fresh pick has empty ability slots: READY needs them filled
	assert_eq(arena.try_ready(1, true), 0, "a human beats a bot")
	_step(arena, 3)
	assert_ne(arena.get_player(mate).character.id, want, "the bot moved")
	assert_eq(st.locked[1], want)
	# nobody on the team shares it, and a locked-in player can no longer change fighter
	for id: int in st.participants:
		if id != 1 and teams[id] == teams[1]:
			assert_ne(st.locked[id], want)
	arena.select_character(arena.get_player(1), EDEN if want != EDEN else SHADE)
	assert_eq(arena.get_player(1).character.id, want, "locked in: fighter fixed")


func test_non_teams_modes_hold_no_locks() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE, 1, MatchRules.Mode.FFA)
	add_child_autofree(arena)
	arena.add_player(1, 0, BotBrain.new(arena, 1))
	arena.add_bot(10, 1)
	_step(arena, 5)
	assert_eq(arena.try_ready(1, true), 0)
	assert_true(arena.match_state.locked.is_empty())
	arena.select_character(arena.get_player(1), EDEN)
	assert_eq(arena.get_player(1).character.id, EDEN, "FFA: READY doesn't fix the fighter")


func test_two_teammates_hover_the_same_fighter_first_to_lock_wins() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE, 1, MatchRules.Mode.TEAMS)
	add_child_autofree(arena)
	for id: int in [1, 2, 3]:
		arena.add_player(id, id, BotBrain.new(arena, id))
		arena.referee.set_team(id, A)
	arena.select_character(arena.get_player(2), EDEN)
	arena.select_character(arena.get_player(3), EDEN)
	for id: int in [2, 3]:
		arena.fill_gaps(arena.get_player(id))  # empty ability slots refuse READY
	_step(arena, 3)
	var st: MatchState = arena.match_state
	var hovers: Dictionary = {1: arena.get_player(1).character.id, 2: EDEN, 3: EDEN}
	var picks: Dictionary = MatchRules.teammate_picks(1, MatchRules.assign_teams(st.participants, st.teams), hovers, st.locked)
	assert_eq(picks[2], [EDEN, false], "P2 hovering")
	assert_eq(picks[3], [EDEN, false], "P3 hovering the same card")
	assert_eq(arena.get_player(3).character.id, EDEN, "hovering is never refused")
	assert_eq(arena.try_ready(3, true), 0, "first to lock gets it")
	assert_eq(arena.try_ready(2, true), 3, "the second is refused, naming P3")
	assert_false(st.ready.has(2))
	assert_eq(arena.try_ready(3, false), 0)
	assert_eq(arena.try_ready(2, true), 0, "free again after the unlock")
	assert_eq(st.locked[2], EDEN)
