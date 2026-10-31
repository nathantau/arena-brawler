extends GutTest
## Match rules, match state sync and the authoritative match flow.

const HUMANS: Array[int] = [1, 2]
const NO_BOTS: Array[int] = []


func _scores(kills: Dictionary, deaths: Dictionary = {}) -> ScoreBoard:
	var sb := ScoreBoard.new()
	for id: int in kills:
		sb.kills[id] = kills[id]
	for id: int in deaths:
		sb.deaths[id] = deaths[id]
	return sb


# --- MatchRules -------------------------------------------------------------

func test_participants_humans_first_then_bots_fill() -> void:
	var bots: Array[int] = [10, 11, 12]
	var ffa: Array[int] = MatchRules.pick_participants([1], bots, MatchRules.Mode.FFA)
	assert_eq(ffa, [1, 10, 11, 12] as Array[int])
	var duel: Array[int] = MatchRules.pick_participants([1], bots, MatchRules.Mode.DUEL)
	assert_eq(duel, [1, 10] as Array[int])
	var duel_humans: Array[int] = MatchRules.pick_participants(HUMANS, bots, MatchRules.Mode.DUEL)
	assert_eq(duel_humans, [1, 2] as Array[int], "humans take seats before bots")


func test_start_blocker() -> void:
	var none: Array[int] = []
	assert_ne(MatchRules.start_blocker(none, none, MatchRules.Mode.FFA), "", "no humans")
	assert_ne(MatchRules.start_blocker(HUMANS, [1] as Array[int], MatchRules.Mode.FFA), "", "one not ready")
	assert_eq(MatchRules.start_blocker(HUMANS, HUMANS, MatchRules.Mode.FFA), "")
	var three: Array[int] = [1, 2, 3]
	assert_ne(MatchRules.start_blocker(three, three, MatchRules.Mode.DUEL), "", "3 humans can't duel")


func test_rank_by_kills_then_fewest_deaths_then_id() -> void:
	var sb := _scores({1: 3, 2: 5, 3: 3, 4: 3}, {1: 2, 3: 1, 4: 1})
	var ranking: Array[int] = MatchRules.rank([1, 2, 3, 4] as Array[int], sb)
	assert_eq(ranking, [2, 3, 4, 1] as Array[int])


func test_winner_and_draw() -> void:
	var sb := _scores({1: 4, 2: 2})
	assert_eq(MatchRules.winner(MatchRules.rank(HUMANS, sb), sb), 1)
	var tied := _scores({1: 2, 2: 2}, {1: 1, 2: 1})
	assert_eq(MatchRules.winner(MatchRules.rank(HUMANS, tied), tied), 0, "tied on kills + deaths = draw")
	var tiebreak := _scores({1: 2, 2: 2}, {1: 3, 2: 1})
	assert_eq(MatchRules.winner(MatchRules.rank(HUMANS, tiebreak), tiebreak), 2, "fewer deaths wins")


func test_kill_target() -> void:
	var sb := _scores({1: Constants.DUEL_KILL_TARGET - 1})
	assert_false(MatchRules.kill_target_reached(HUMANS, sb, MatchRules.Mode.DUEL))
	sb.kills[1] = Constants.DUEL_KILL_TARGET
	assert_true(MatchRules.kill_target_reached(HUMANS, sb, MatchRules.Mode.DUEL))
	assert_false(MatchRules.kill_target_reached(HUMANS, sb, MatchRules.Mode.FFA), "FFA needs more")


func test_kills_by_non_participants_dont_end_the_match() -> void:
	var sb := _scores({99: Constants.FFA_KILL_TARGET})
	assert_false(MatchRules.kill_target_reached(HUMANS, sb, MatchRules.Mode.FFA))


# --- MatchState -------------------------------------------------------------

func test_state_roundtrip() -> void:
	var a := MatchState.new()
	a.phase = MatchState.Phase.RESULTS
	a.mode = MatchRules.Mode.DUEL
	a.arena_index = 1
	a.time_left = 4.5
	a.time_limit = 60.0
	a.participants = [1, 10]
	a.ready = [1]
	a.results = [[1, 5, 2], [10, 2, 5]]
	a.winner_id = 1
	a.blocker = ""
	var b := MatchState.new()
	assert_true(b.apply_array(a.to_array()))
	assert_eq(b.phase, MatchState.Phase.RESULTS)
	assert_eq(b.mode, MatchRules.Mode.DUEL)
	assert_eq(b.arena_index, 1)
	assert_eq(b.time_left, 4.5)
	assert_eq(b.time_limit, 60.0)
	assert_eq(b.participants, [1, 10] as Array[int])
	assert_eq(b.ready, [1] as Array[int])
	assert_eq(b.results, a.results)
	assert_eq(b.winner_id, 1)


func test_state_rejects_malformed() -> void:
	var s := MatchState.new()
	assert_false(s.apply_array([]))
	var bad: Array = MatchState.new().to_array()
	bad[MatchState.Field.PHASE] = 99
	assert_false(s.apply_array(bad))
	bad = MatchState.new().to_array()
	bad[MatchState.Field.ARENA] = ArenaLayouts.count()
	assert_false(s.apply_array(bad), "unknown arena")
	bad = MatchState.new().to_array()
	bad[MatchState.Field.PARTICIPANTS] = "nope"
	assert_false(s.apply_array(bad))
	assert_eq(s.phase, MatchState.Phase.LOBBY, "unchanged")


func test_respawn_and_lock_rules_per_phase() -> void:
	var s := MatchState.new()
	s.participants = [1]
	assert_true(s.may_respawn(2), "anyone respawns in the lobby")
	assert_true(s.inputs_locked(), "frozen behind the loading room")
	s.phase = MatchState.Phase.COUNTDOWN
	assert_true(s.inputs_locked())
	assert_true(s.may_respawn(1))
	assert_false(s.may_respawn(2), "non-participants spectate")
	s.phase = MatchState.Phase.PLAYING
	assert_false(s.inputs_locked())
	assert_false(s.may_respawn(2))
	s.phase = MatchState.Phase.RESULTS
	assert_true(s.inputs_locked())
	assert_false(s.may_respawn(1))


# --- MatchController --------------------------------------------------------

func _run(mc: MatchController, seconds: float, humans: Array[int], bots: Array[int], sb: ScoreBoard) -> void:
	var t: float = 0.0
	while t < seconds:
		mc.tick(Constants.PHYSICS_DT, humans, bots, sb)
		t += Constants.PHYSICS_DT


func test_full_match_flow_ends_on_kill_target() -> void:
	var mc := MatchController.new()
	var sb := ScoreBoard.new()
	mc.tick(Constants.PHYSICS_DT, HUMANS, NO_BOTS, sb)
	assert_eq(mc.state.phase, MatchState.Phase.LOBBY)
	assert_ne(mc.state.blocker, "")
	mc.set_ready(1, true)
	mc.tick(Constants.PHYSICS_DT, HUMANS, NO_BOTS, sb)
	assert_eq(mc.state.phase, MatchState.Phase.LOBBY, "player 2 not ready")
	mc.set_ready(2, true)
	mc.tick(Constants.PHYSICS_DT, HUMANS, NO_BOTS, sb)
	assert_eq(mc.state.phase, MatchState.Phase.COUNTDOWN)
	assert_eq(mc.state.participants, HUMANS)

	_run(mc, Constants.MATCH_COUNTDOWN + Constants.PHYSICS_DT, HUMANS, NO_BOTS, sb)
	assert_eq(mc.state.phase, MatchState.Phase.PLAYING)
	mc.set_mode(MatchRules.Mode.DUEL)
	assert_eq(mc.state.mode, MatchRules.Mode.FFA, "mode locked outside the lobby")

	sb.kills[2] = Constants.FFA_KILL_TARGET
	mc.tick(Constants.PHYSICS_DT, HUMANS, NO_BOTS, sb)
	assert_eq(mc.state.phase, MatchState.Phase.RESULTS)
	assert_eq(mc.state.winner_id, 2)
	assert_eq(mc.state.results[0][MatchState.ResultField.ID], 2)
	assert_eq(mc.state.results[0][MatchState.ResultField.KILLS], Constants.FFA_KILL_TARGET)

	_run(mc, Constants.MATCH_RESULTS_TIME + Constants.PHYSICS_DT, HUMANS, NO_BOTS, sb)
	assert_eq(mc.state.phase, MatchState.Phase.LOBBY)
	assert_true(mc.state.ready.is_empty(), "everyone readies again")
	assert_true(mc.state.results.is_empty())


func test_match_ends_on_time_limit() -> void:
	var mc := MatchController.new()
	mc.state.time_limit = 2.0
	var sb := _scores({1: 1})
	var humans: Array[int] = [1]
	var bots: Array[int] = [10]
	mc.set_ready(1, true)
	_run(mc, Constants.MATCH_COUNTDOWN + 1.0, humans, bots, sb)
	assert_eq(mc.state.phase, MatchState.Phase.PLAYING)
	_run(mc, 1.5, humans, bots, sb)
	assert_eq(mc.state.phase, MatchState.Phase.RESULTS)
	assert_eq(mc.state.winner_id, 1)


func test_solo_human_needs_a_bot() -> void:
	var mc := MatchController.new()
	var sb := ScoreBoard.new()
	var humans: Array[int] = [1]
	mc.set_ready(1, true)
	mc.tick(Constants.PHYSICS_DT, humans, NO_BOTS, sb)
	assert_eq(mc.state.phase, MatchState.Phase.LOBBY)
	assert_ne(mc.state.blocker, "")


func test_leaver_below_minimum_ends_match() -> void:
	var mc := MatchController.new()
	var sb := ScoreBoard.new()
	mc.set_ready(1, true)
	mc.set_ready(2, true)
	_run(mc, Constants.MATCH_COUNTDOWN + 1.0, HUMANS, NO_BOTS, sb)
	assert_eq(mc.state.phase, MatchState.Phase.PLAYING)
	mc.remove_player(2, sb)
	assert_eq(mc.state.phase, MatchState.Phase.RESULTS)
	assert_eq(mc.state.winner_id, 1)


func test_ready_ignored_outside_lobby() -> void:
	var mc := MatchController.new()
	mc.state.phase = MatchState.Phase.PLAYING
	mc.set_ready(1, true)
	assert_true(mc.state.ready.is_empty())


## The server only accepts a weapon / special the fighter may use, in a real slot.
func test_lobby_picks_are_validated() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var p: Player = arena.add_player(1, 0, null)
	arena.select_character(p, &"flicker")
	assert_eq(p.weapon.data, p.character.signature_weapon, "signature by default")
	arena.select_weapon(p, &"smg")
	assert_eq(p.weapon.data.id, &"smg", "Flicker is light")
	arena.select_weapon(p, &"rocket")
	arena.select_weapon(p, &"sakura_fan")
	arena.select_weapon(p, &"ape_fists")
	assert_eq(p.weapon.data.id, &"smg", "heavy, other fighters' and form weapons refused")
	arena.select_special(p, 0, &"smoke_bomb")
	assert_eq(p.skills[0].data.id, &"smoke_bomb")
	arena.select_special(p, 1, &"great_ape")
	arena.select_special(p, 2, &"barrier")
	arena.select_special(p, 0, &"inferno")
	assert_eq(p.skills[0].data.id, &"smoke_bomb")
	assert_eq(p.skills[1].data.id, &"shadow_clones", "others' specials and bad slots refused")
