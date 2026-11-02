class_name MatchController
extends RefCounted
## Authoritative match flow (offline / server only):
## LOBBY (warm-up, ready up) -> COUNTDOWN -> PLAYING -> RESULTS -> LOBBY.
## Knows nothing about nodes: the Arena feeds it the roster and scores each tick and reacts
## to phase_changed (resetting players, freezing input, ...).

## Emitted whenever the state should be re-broadcast to clients.
signal changed
signal phase_changed(phase: MatchState.Phase)
## Teams: a round ended (winner team, 0 = nobody; reason = MatchRules.Reason), and the next round is starting after the intermission.
signal round_ended(winner: int, reason: int)
signal round_started

var state := MatchState.new()
## Teams: returns id -> hp of every player alive right now (asked only when a round runs out of time).
## Kills this round per team (index = team id), authoritative only: the clock-out tiebreak.
var round_kills: Array[int] = [0, 0, 0]


func set_mode(mode: MatchRules.Mode) -> void:
	if state.phase != MatchState.Phase.LOBBY or mode == state.mode:
		return
	if mode == MatchRules.Mode.TEAMS or state.mode == MatchRules.Mode.TEAMS:  # READY means LOCK IN only in Teams
		state.ready.clear()
		state.locked.clear()
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
	_unlock_duplicates()
	changed.emit()


## Teams: a participant died at `at`. Counts the other team's kill while a round is running, and a carried flag drops there.
func on_death(id: int, at: Vector2 = Vector2.ZERO, killer_id: int = 0) -> void:
	if not _round_running() or not state.teams.has(id):
		return
	var killer_team: int = state.team_of(killer_id)
	if killer_team != 0 and killer_team != state.team_of(id):
		round_kills[killer_team] += 1
	var flag: int = state.carried_flag_of(id)
	if flag != 0:
		state.flag_state[flag] = MatchState.Flag.DROPPED
		state.flag_carrier[flag] = 0
		state.flag_pos[flag] = at
		state.flag_timer[flag] = Constants.FLAG_RETURN_TIME
	changed.emit()


## Teams: `carrier_id` (on the other team) touched `flag_team`'s flag at its base or where it lies.
func flag_pickup(carrier_id: int, flag_team: int) -> void:
	if not _round_running() or state.flag_state[flag_team] == MatchState.Flag.CARRIED \
			or state.team_of(carrier_id) != MatchRules.other_team(flag_team) or state.carried_flag_of(carrier_id) != 0:
		return
	state.flag_state[flag_team] = MatchState.Flag.CARRIED
	state.flag_carrier[flag_team] = carrier_id
	state.flag_timer[flag_team] = 0.0
	changed.emit()


## Teams: a flag goes back to its base (its owner touched it, or it lay there too long).
func flag_return(flag_team: int) -> void:
	if not _round_running() or state.flag_state[flag_team] == MatchState.Flag.HOME:
		return
	state.flag_state[flag_team] = MatchState.Flag.HOME
	state.flag_carrier[flag_team] = 0
	state.flag_timer[flag_team] = 0.0
	changed.emit()


## Teams: the carrier reached their own base pad: their team wins the round on the spot.
func flag_capture(carrier_id: int, scores: ScoreBoard) -> void:
	var flag: int = state.carried_flag_of(carrier_id)
	if not _round_running() or flag == 0 or state.team_of(carrier_id) != MatchRules.other_team(flag):
		return
	state.flag_state[flag] = MatchState.Flag.HOME
	state.flag_carrier[flag] = 0
	_end_round(MatchRules.other_team(flag), MatchRules.Reason.CAPTURE, scores)


## READY. In Teams with a `fighter` it is the lock-in: refused (returns the teammate holding it) when a human
## teammate already locked that fighter. The server handles requests one at a time, so the first one wins.
func set_ready(id: int, is_ready: bool, fighter: StringName = &"") -> int:
	if state.phase != MatchState.Phase.LOBBY or state.ready.has(id) == is_ready:
		return 0
	if is_ready and state.has_gap(id):  # an emptied ability slot: pick three first
		return 0
	if is_ready:
		if state.mode == MatchRules.Mode.TEAMS and fighter != &"":
			var holder: int = MatchRules.lock_holder(lobby_teams(), _human_locks(), id, fighter)
			if holder != 0:
				return holder
			state.locked[id] = fighter
		state.ready.append(id)
	else:
		state.ready.erase(id)
		state.locked.erase(id)
	changed.emit()
	return 0


## Lobby: the emptied ability slots of a player as a bitmask (0 = all filled).
func set_gap_mask(id: int, mask: int) -> void:
	if state.phase != MatchState.Phase.LOBBY or state.gaps.get(id, 0) == mask:
		return
	if mask == 0:
		state.gaps.erase(id)
	else:
		state.gaps[id] = mask
	changed.emit()


## Teams lobby: the team everyone would play on right now (picks kept, the rest balanced).
func lobby_teams() -> Dictionary[int, int]:
	return MatchRules.assign_teams(state.participants, state.teams)


func _human_locks() -> Dictionary[int, StringName]:
	var out: Dictionary[int, StringName] = {}
	for id: int in state.locked:
		if state.ready.has(id):
			out[id] = state.locked[id]
	return out


## Teams lobby: a lock whose fighter a teammate locked first (after a team change) is released.
func _unlock_duplicates() -> bool:
	if state.mode != MatchRules.Mode.TEAMS:
		return false
	var teams: Dictionary[int, int] = lobby_teams()
	var kept: Dictionary[int, StringName] = {}
	var dropped: bool = false
	for id: int in state.ready.duplicate():  # ready order = lock order
		if not state.locked.has(id):
			continue
		if MatchRules.lock_holder(teams, kept, id, state.locked[id]) != 0:
			state.ready.erase(id)
			state.locked.erase(id)
			dropped = true
		else:
			kept[id] = state.locked[id]
	return dropped


## A player left (`humans` = the humans still connected). A running match ends right away if it drops below the
## minimum, or if no human is left in it: the remaining bots would play on for minutes while a spectator waits.
func remove_player(id: int, scores: ScoreBoard, humans: Array[int]) -> void:
	var was_in: bool = state.participants.has(id) or state.ready.has(id)
	state.ready.erase(id)
	state.locked.erase(id)
	state.gaps.erase(id)
	state.participants.erase(id)
	var held: int = state.carried_flag_of(id)
	if held != 0:  # a carrier who leaves: the flag flies home
		state.flag_state[held] = MatchState.Flag.HOME
		state.flag_carrier[held] = 0
	state.teams.erase(id)
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
				state.locked.clear()
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
## flag capture (ends the round in `flag_capture`) or the clock running out.
func _tick_round(delta: float, scores: ScoreBoard) -> void:
	if state.intermission > 0.0:
		state.intermission -= delta
		if state.intermission <= 0.0:
			state.intermission = 0.0
			state.round_number += 1
			state.time_left = _round_time()
			round_kills = [0, 0, 0]
			state.reset_flags()
			round_started.emit()
			changed.emit()
		return
	state.time_left -= delta
	for flag: int in [MatchRules.TEAM_A, MatchRules.TEAM_B]:  # a dropped flag left alone flies home
		if state.flag_state[flag] == MatchState.Flag.DROPPED:
			state.flag_timer[flag] -= delta
			if state.flag_timer[flag] <= 0.0:
				flag_return(flag)
	if state.time_left <= 0.0:
		_end_round(MatchRules.timeout_winner(round_kills), MatchRules.Reason.TIMEOUT, scores)


func _end_round(winner: int, reason: int, scores: ScoreBoard) -> void:
	state.round_reason = reason
	state.round_winner = winner
	if winner != 0:
		state.round_scores[winner] += 1
	round_ended.emit(winner, reason)
	if winner != 0 and state.round_scores[winner] >= Constants.TEAMS_ROUND_TARGET:
		_end(scores)
		return
	state.intermission = Constants.TEAMS_INTERMISSION
	changed.emit()


func _tick_lobby(humans: Array[int], bots: Array[int]) -> void:
	var preview: Array[int] = MatchRules.pick_participants(humans, bots, state.mode)
	var blocker: String = MatchRules.start_blocker(humans, state.ready, state.mode)
	if blocker == "" and not MatchRules.has_enough_players(preview):
		blocker = "Need %d players" % Constants.MATCH_MIN_PLAYERS
	if preview != state.participants or blocker != state.blocker:
		state.participants = preview
		if _unlock_duplicates():
			blocker = MatchRules.start_blocker(humans, state.ready, state.mode)
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
	round_kills = [0, 0, 0]
	state.round_scores = [0, 0, 0]
	state.round_number = 0
	state.round_winner = 0
	state.round_reason = MatchRules.Reason.NONE
	state.intermission = 0.0
	state.reset_flags()


## Teams: lock in everyone's team (picks kept, the rest balanced), round 1, 0-0.
func _start_teams() -> void:
	var picks: Dictionary[int, int] = state.teams.duplicate()
	_reset_teams()
	if state.mode == MatchRules.Mode.TEAMS:
		state.teams = MatchRules.assign_teams(state.participants, picks)
		state.round_number = 1


func _enter(phase: MatchState.Phase, duration: float) -> void:
	if phase == MatchState.Phase.COUNTDOWN:
		_start_teams()
	state.phase = phase
	state.time_left = duration
	if phase != MatchState.Phase.LOBBY:
		state.blocker = ""
	phase_changed.emit(phase)
	changed.emit()
