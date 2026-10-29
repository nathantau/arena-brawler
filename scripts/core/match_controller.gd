class_name MatchController
extends RefCounted
## Authoritative match flow (offline / server only):
## LOBBY (warm-up, ready up) -> COUNTDOWN -> PLAYING -> RESULTS -> LOBBY.
## Knows nothing about nodes: the Arena feeds it the roster and scores each tick and reacts
## to phase_changed (resetting players, freezing input, ...).

## Emitted whenever the state should be re-broadcast to clients.
signal changed
signal phase_changed(phase: MatchState.Phase)

var state := MatchState.new()


func set_mode(mode: MatchRules.Mode) -> void:
	if state.phase != MatchState.Phase.LOBBY or mode == state.mode:
		return
	state.mode = mode
	changed.emit()


func set_ready(id: int, is_ready: bool) -> void:
	if state.phase != MatchState.Phase.LOBBY or state.ready.has(id) == is_ready:
		return
	if is_ready:
		state.ready.append(id)
	else:
		state.ready.erase(id)
	changed.emit()


## A player left. If a running match drops below the minimum, it ends right away.
func remove_player(id: int, scores: ScoreBoard) -> void:
	var was_in: bool = state.participants.has(id) or state.ready.has(id)
	state.ready.erase(id)
	state.participants.erase(id)
	var running: bool = state.phase == MatchState.Phase.COUNTDOWN or state.phase == MatchState.Phase.PLAYING
	if running and not MatchRules.has_enough_players(state.participants):
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
				_enter(MatchState.Phase.PLAYING, state.time_limit)
		MatchState.Phase.PLAYING:
			state.time_left -= delta
			if state.time_left <= 0.0 or MatchRules.kill_target_reached(state.participants, scores, state.mode):
				_end(scores)
		MatchState.Phase.RESULTS:
			state.time_left -= delta
			if state.time_left <= 0.0:
				state.ready.clear()
				state.results = []
				state.winner_id = 0
				_enter(MatchState.Phase.LOBBY, 0.0)


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
	_enter(MatchState.Phase.RESULTS, Constants.MATCH_RESULTS_TIME)


func _enter(phase: MatchState.Phase, duration: float) -> void:
	state.phase = phase
	state.time_left = duration
	if phase != MatchState.Phase.LOBBY:
		state.blocker = ""
	phase_changed.emit(phase)
	changed.emit()
