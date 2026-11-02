class_name MatchRules
extends RefCounted
## Pure match rules: per-mode settings, who plays, when a match may start, ranking and winner.

enum Mode { DUEL, FFA, TEAMS }

const MODE_NAMES: Array[String] = ["Duel 1v1", "Free-for-all", "Teams 3v3"]
const SHORT_NAMES: Array[String] = ["Duel", "FFA", "3v3"]
## Team ids (0 = unassigned / no teams).
const TEAM_A: int = 1
const TEAM_B: int = 2
const TEAM_NAMES: Array[String] = ["", "Team A", "Team B"]
## round_result() while both teams still have someone in.
const ROUND_ON: int = -1


static func is_valid_mode(value: int) -> bool:
	return value >= 0 and value < Mode.size()


static func max_players(mode: Mode) -> int:
	match mode:
		Mode.DUEL:
			return Constants.DUEL_PLAYERS
		Mode.TEAMS:
			return Constants.TEAMS_MAX_PLAYERS
	return Constants.FFA_MAX_PLAYERS


## Kills to win (Duel / FFA); round wins to win in Teams.
static func kill_target(mode: Mode) -> int:
	match mode:
		Mode.DUEL:
			return Constants.DUEL_KILL_TARGET
		Mode.TEAMS:
			return Constants.TEAMS_ROUND_TARGET
	return Constants.FFA_KILL_TARGET


static func other_team(team: int) -> int:
	return TEAM_B if team == TEAM_A else TEAM_A


static func members(teams: Dictionary, team: int) -> Array[int]:
	var out: Array[int] = []
	for id: int in teams:
		if teams[id] == team:
			out.append(id)
	return out


## Full team assignment for `participants`: picks (id -> team) are kept up to half the roster per team (rounded up),
## so a lopsided lobby can't leave a team empty; everyone else joins the smaller team (ties go to A), in order.
static func assign_teams(participants: Array[int], picks: Dictionary) -> Dictionary[int, int]:
	var out: Dictionary[int, int] = {}
	var counts: Array[int] = [0, 0, 0]
	var cap: int = (participants.size() + 1) / 2
	for id: int in participants:
		var t: int = picks.get(id, 0)
		if (t == TEAM_A or t == TEAM_B) and counts[t] < cap:
			out[id] = t
			counts[t] += 1
	for id: int in participants:
		if not out.has(id):
			var t: int = TEAM_A if counts[TEAM_A] <= counts[TEAM_B] else TEAM_B
			out[id] = t
			counts[t] += 1
	return out


## ROUND_ON while both teams have a player with lives left; else the team still standing (0 if both are out).
static func round_result(teams: Dictionary, lives: Dictionary) -> int:
	var in_a: bool = false
	var in_b: bool = false
	for id: int in teams:
		if lives.get(id, 0) > 0:
			in_a = in_a or teams[id] == TEAM_A
			in_b = in_b or teams[id] == TEAM_B
	if in_a and in_b:
		return ROUND_ON
	return TEAM_A if in_a else TEAM_B if in_b else 0


## Round clock ran out: the team with more players alive wins, then more total HP; a full tie is 0 (no point).
## `hp` = id -> hp of every player alive right now.
static func timeout_winner(teams: Dictionary, hp: Dictionary) -> int:
	var alive: Array[int] = [0, 0, 0]
	var total: Array[int] = [0, 0, 0]
	for id: int in hp:
		var t: int = teams.get(id, 0)
		if t == TEAM_A or t == TEAM_B:
			alive[t] += 1
			total[t] += hp[id]
	if alive[TEAM_A] != alive[TEAM_B]:
		return TEAM_A if alive[TEAM_A] > alive[TEAM_B] else TEAM_B
	if total[TEAM_A] != total[TEAM_B]:
		return TEAM_A if total[TEAM_A] > total[TEAM_B] else TEAM_B
	return 0


## Humans always get a seat; bots fill the rest up to the mode's player count.
static func pick_participants(humans: Array[int], bots: Array[int], mode: Mode) -> Array[int]:
	var out: Array[int] = []
	var cap: int = max_players(mode)
	for id: int in humans:
		if out.size() < cap:
			out.append(id)
	for id: int in bots:
		if out.size() < cap:
			out.append(id)
	return out


## Why the lobby can't start yet, or "" if it can.
static func start_blocker(humans: Array[int], ready: Array[int], mode: Mode) -> String:
	if humans.is_empty():
		return "Waiting for players"
	if humans.size() > max_players(mode):
		return "Too many players for %s" % MODE_NAMES[mode]
	for id: int in humans:
		if not ready.has(id):
			return "Waiting for everyone to ready up"
	return ""


## Participant count needed to start (bots included).
static func has_enough_players(participants: Array[int]) -> bool:
	return participants.size() >= Constants.MATCH_MIN_PLAYERS


## True if at least one participant is a human (bots alone don't make a match worth running).
static func has_human(participants: Array[int], humans: Array[int]) -> bool:
	for id: int in participants:
		if humans.has(id):
			return true
	return false


## Best first: most kills, then fewest deaths, then lowest id (stable on every peer).
static func rank(ids: Array[int], scores: ScoreBoard) -> Array[int]:
	var out: Array[int] = ids.duplicate()
	out.sort_custom(func(a: int, b: int) -> bool:
		var ka: int = scores.kills_of(a)
		var kb: int = scores.kills_of(b)
		if ka != kb:
			return ka > kb
		var da: int = scores.deaths_of(a)
		var db: int = scores.deaths_of(b)
		if da != db:
			return da < db
		return a < b)
	return out


## Top of the ranking, or 0 for a draw (top two tied on kills and deaths).
static func winner(ranking: Array[int], scores: ScoreBoard) -> int:
	if ranking.is_empty():
		return 0
	if ranking.size() > 1:
		var a: int = ranking[0]
		var b: int = ranking[1]
		if scores.kills_of(a) == scores.kills_of(b) and scores.deaths_of(a) == scores.deaths_of(b):
			return 0
	return ranking[0]


static func kill_target_reached(ids: Array[int], scores: ScoreBoard, mode: Mode) -> bool:
	if mode == Mode.TEAMS:
		return false
	var target: int = kill_target(mode)
	for id: int in ids:
		if scores.kills_of(id) >= target:
			return true
	return false
