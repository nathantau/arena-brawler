class_name MatchController
extends RefCounted
## Authoritative match flow (offline / server only):
## LOBBY (warm-up, ready up) -> COUNTDOWN -> PLAYING -> RESULTS -> LOBBY.
## Knows nothing about nodes: the Arena feeds it the roster and scores each tick and reacts
## to phase_changed (resetting players, freezing input, ...).

## Emitted whenever the state should be re-broadcast to clients.
signal changed
signal phase_changed(phase: MatchState.Phase)
## Teams: a round ended (winner team, 0 = nobody), and the next round is starting after the intermission.
signal round_ended(winner: int)
signal round_started

var state := MatchState.new()
## Teams: returns id -> hp of every player alive right now (asked only when a round runs out of time).
var living_hp: Callable


func set_mode(mode: MatchRules.Mode) -> void:
	if state.phase != MatchState.Phase.LOBBY or mode == state.mode:
		return
	state.mode = mode
	changed.emit()


func set_arena(index: int) -> void:
	if state.phase != MatchState.Phase.LOBBY or index == state.arena_index or index < 0 or index >= ArenaLayouts.count():
		return
	state.arena_index = index
	changed.emit()


## Lobby: pick a team (0 = auto). A full team (TEAM_SIZE) refuses more.
func set_team(id: int, team: int) -> void:
	if state.phase != MatchState.Phase.LOBBY or team < 0 or team > MatchRules.TEAM_B or state.team_of(id) == team:
		return
	if team != 0 and MatchRules.members(state.teams, team).size() >= Constants.TEAM_SIZE:
		return
	if team == 0:
		state.teams.erase(id)
	else:
		state.teams[id] = team
	changed.emit()


## Teams: a participant died. Spends a life while a round is running.
func on_death(id: int) -> void:
	if not _round_running() or not state.teams.has(id):
		return
	state.lives[id] = maxi(0, state.lives_of(id) - 1)
	changed.emit()


func set_ready(id: int, is_ready: bool) -> void:
	if state.phase != MatchState.Phase.LOBBY or state.ready.has(id) == is_ready:
		return
	if is_ready:
		state.ready.append(id)
	else:
		state.ready.erase(id)
	changed.emit()


## A player left (`humans` = the humans still connected). A running match ends right away if it drops below the
## minimum, or if no human is left in it: the remaining bots would play on for minutes while a spectator waits.
func remove_player(id: int, scores: ScoreBoard, humans: Array[int]) -> void:
	var was_in: bool = state.participants.has(id) or state.ready.has(id)
	state.ready.erase(id)
	state.participants.erase(id)
	state.teams.erase(id)
	state.lives.erase(id)
	var running: bool = state.phase == MatchState.Phase.COUNTDOWN or state.phase == MatchState.Phase.PLAYING
	var team_empty: bool = state.mode == MatchRules.Mode.TEAMS and was_in and (
			MatchRules.members(state.teams, MatchRules.TEAM_A).is_empty() \
			or MatchRules.members(state.teams, MatchRules.TEAM_B).is_empty())
	if running and (not MatchRules.has_enough_players(state.participants) \
			or not MatchRules.has_human(state.participants, humans) or team_empty):
		_end(scores)
	elif was_in:
		changed.emit()


func tick(delta: float, humans: Array[int], bots: Array[int], scores: ScoreBoard) -> void:
	match state.phase:
		MatchState.Phase.LOBBY:
			_tick_lobby(humans, bots)
		MatchState.Phase.COUNTDOWN:
			state.time_left -= delta
			if state.time_left <= 0.0:
				_enter(MatchState.Phase.PLAYING, _round_time())
		MatchState.Phase.PLAYING:
			if state.mode == MatchRules.Mode.TEAMS:
				_tick_round(delta, scores)
				return
			state.time_left -= delta
			if state.time_left <= 0.0 or MatchRules.kill_target_reached(state.participants, scores, state.mode):
				_end(scores)
		MatchState.Phase.RESULTS:
			state.time_left -= delta
			if state.time_left <= 0.0:
				state.ready.clear()
				state.results = []
				state.winner_id = 0
				_reset_teams()
				_enter(MatchState.Phase.LOBBY, 0.0)


## Seconds on the clock: the match length, or one round's in Teams (capped by the match length for quick tests).
func _round_time() -> float:
	if state.mode == MatchRules.Mode.TEAMS:
		return minf(state.time_limit, Constants.TEAMS_ROUND_TIME)
	return state.time_limit


func _round_running() -> bool:
	return state.phase == MatchState.Phase.PLAYING and state.mode == MatchRules.Mode.TEAMS and state.intermission <= 0.0


## Teams: between rounds count the intermission down, then reset for the next round; in a round look for a
## team that is out (every player's lives spent), or the clock running out.
func _tick_round(delta: float, scores: ScoreBoard) -> void:
	if state.intermission > 0.0:
		state.intermission -= delta
		if state.intermission <= 0.0:
			state.intermission = 0.0
			state.round_number += 1
			state.time_left = _round_time()
			_refill_lives()
			round_started.emit()
			changed.emit()
		return
	state.time_left -= delta
	var result: int = MatchRules.round_result(state.teams, state.lives)
	if result == MatchRules.ROUND_ON and state.time_left <= 0.0:
		var hp: Dictionary = living_hp.call() if living_hp.is_valid() else {}
		result = MatchRules.timeout_winner(state.teams, hp)
	if result != MatchRules.ROUND_ON:
		_end_round(result, scores)


func _end_round(winner: int, scores: ScoreBoard) -> void:
	state.round_winner = winner
	if winner != 0:
		state.round_scores[winner] += 1
	round_ended.emit(winner)
	if winner != 0 and state.round_scores[winner] >= Constants.TEAMS_ROUND_TARGET:
		_end(scores)
		return
	state.intermission = Constants.TEAMS_INTERMISSION
	changed.emit()


func _refill_lives() -> void:
	for id: int in state.teams:
		state.lives[id] = Constants.TEAMS_LIVES


func _tick_lobby(humans: Array[int], bots: Array[int]) -> void:
	var preview: Array[int] = MatchRules.pick_participants(humans, bots, state.mode)
	var blocker: String = MatchRules.start_blocker(humans, state.ready, state.mode)
	if blocker == "" and not MatchRules.has_enough_players(preview):
		blocker = "Need %d players" % Constants.MATCH_MIN_PLAYERS
	if preview != state.participants or blocker != state.blocker:
		state.participants = preview
		state.blocker = blocker
		changed.emit()
	if blocker == "":
		_enter(MatchState.Phase.COUNTDOWN, Constants.MATCH_COUNTDOWN)


func _end(scores: ScoreBoard) -> void:
	var ranking: Array[int] = MatchRules.rank(state.participants, scores)
	state.results = []
	for id: int in ranking:
		var row: Array = []
		row.resize(MatchState.ResultField.COUNT)
		row[MatchState.ResultField.ID] = id
		row[MatchState.ResultField.KILLS] = scores.kills_of(id)
		row[MatchState.ResultField.DEATHS] = scores.deaths_of(id)
		state.results.append(row)
	state.winner_id = MatchRules.winner(ranking, scores)
	if state.mode == MatchRules.Mode.TEAMS:  # the team ahead on rounds (nobody on a tie); winner_id isn't used
		var a: int = state.round_scores[MatchRules.TEAM_A]
		var b: int = state.round_scores[MatchRules.TEAM_B]
		state.round_winner = 0 if a == b else MatchRules.TEAM_A if a > b else MatchRules.TEAM_B
		state.winner_id = 0
		state.intermission = 0.0
	_enter(MatchState.Phase.RESULTS, Constants.MATCH_RESULTS_TIME)


func _reset_teams() -> void:
	state.teams.clear()
	state.lives.clear()
	state.round_scores = [0, 0, 0]
	state.round_number = 0
	state.round_winner = 0
	state.intermission = 0.0


## Teams: lock in everyone's team (picks kept, the rest balanced), round 1, full lives, 0-0.
func _start_teams() -> void:
	var picks: Dictionary[int, int] = state.teams.duplicate()
	_reset_teams()
	if state.mode == MatchRules.Mode.TEAMS:
		state.teams = MatchRules.assign_teams(state.participants, picks)
		state.round_number = 1
		_refill_lives()


func _enter(phase: MatchState.Phase, duration: float) -> void:
	if phase == MatchState.Phase.COUNTDOWN:
		_start_teams()
	state.phase = phase
	state.time_left = duration
	if phase != MatchState.Phase.LOBBY:
		state.blocker = ""
	phase_changed.emit(phase)
	changed.emit()
