class_name MatchRules
extends RefCounted
## Pure match rules: per-mode settings, who plays, when a match may start, ranking and winner.

enum Mode { DUEL, FFA }

const MODE_NAMES: Array[String] = ["Duel 1v1", "Free-for-all"]


static func is_valid_mode(value: int) -> bool:
	return value >= 0 and value < Mode.size()


static func max_players(mode: Mode) -> int:
	return Constants.DUEL_PLAYERS if mode == Mode.DUEL else Constants.FFA_MAX_PLAYERS


static func kill_target(mode: Mode) -> int:
	return Constants.DUEL_KILL_TARGET if mode == Mode.DUEL else Constants.FFA_KILL_TARGET


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
	var target: int = kill_target(mode)
	for id: int in ids:
		if scores.kills_of(id) >= target:
			return true
	return false
