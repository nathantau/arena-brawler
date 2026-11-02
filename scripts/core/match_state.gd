class_name MatchState
extends RefCounted
## Match flow state shared by server and clients. The server owns it (MatchController) and
## sends it whole, reliably, on every change; clients only count time_left down for display.

enum Phase { LOBBY, COUNTDOWN, PLAYING, RESULTS }
enum Field { PHASE, MODE, ARENA, TIME_LEFT, TIME_LIMIT, PARTICIPANTS, READY, RESULTS, WINNER, BLOCKER, TEAMS, ROUND_SCORES, ROUND, ROUND_WINNER, INTERMISSION, COUNT }
## One results row: [id, kills, deaths].
enum ResultField { ID, KILLS, DEATHS, COUNT }

var phase: Phase = Phase.LOBBY
var mode: MatchRules.Mode = MatchRules.Mode.FFA
## Index into ArenaLayouts.
var arena_index: int = 0
## Seconds left in the current phase (countdown / match clock / results screen). 0 in LOBBY.
var time_left: float = 0.0
var time_limit: float = Constants.MATCH_TIME_LIMIT
## In LOBBY: who would play if the match started now. Afterwards: who is playing.
var participants: Array[int] = []
var ready: Array[int] = []
## Final standings (best first), set on entering RESULTS.
var results: Array = []
## 0 = draw.
var winner_id: int = 0
## Why the lobby can't start ("" when it can).
var blocker: String = ""
## Teams mode. In the lobby: player id -> team picked (absent = auto). From the countdown: everyone's team.
var teams: Dictionary[int, int] = {}
## Lives left this round, per participant (Teams only).
var lives: Dictionary[int, int] = {}
## Rounds won: [unused, team A, team B] (indexed by team id).
var round_scores: Array[int] = [0, 0, 0]
## 1-based round number (0 outside a Teams match).
var round_number: int = 0
## Team that won the last round (0 = nobody: tied timeout). At RESULTS: the match winner.
var round_winner: int = 0
## Seconds left in the pause between rounds (0 = a round is running). Counts down on clients too.
var intermission: float = 0.0


func is_participant(id: int) -> bool:
	return participants.has(id)


## Movement, firing and skills are frozen during the countdown and on the results screen.
## Everyone stands still outside a running match: the lobby hides the arena (no warm-up fights, no haptics).
func inputs_locked() -> bool:
	return phase != Phase.PLAYING or intermission > 0.0


## Warm-up in the lobby lets everyone respawn; in a match only participants do.
func may_respawn(id: int) -> bool:
	match phase:
		Phase.LOBBY:
			return true
		Phase.COUNTDOWN, Phase.PLAYING:
			if mode == MatchRules.Mode.TEAMS and phase == Phase.PLAYING:
				return is_participant(id) and intermission <= 0.0 and lives_of(id) > 0
			return is_participant(id)
	return false


func team_of(id: int) -> int:
	return teams.get(id, 0)


func lives_of(id: int) -> int:
	return lives.get(id, 0)


func to_array() -> Array:
	var a: Array = []
	a.resize(Field.COUNT)
	a[Field.PHASE] = phase
	a[Field.MODE] = mode
	a[Field.ARENA] = arena_index
	a[Field.TIME_LEFT] = time_left
	a[Field.TIME_LIMIT] = time_limit
	a[Field.PARTICIPANTS] = PackedInt32Array(participants)
	a[Field.READY] = PackedInt32Array(ready)
	a[Field.RESULTS] = results
	a[Field.WINNER] = winner_id
	a[Field.BLOCKER] = blocker
	var tl := PackedInt32Array()
	for id: int in teams:
		tl.append_array([id, teams[id], lives.get(id, 0)])
	a[Field.TEAMS] = tl
	a[Field.ROUND_SCORES] = PackedInt32Array(round_scores)
	a[Field.ROUND] = round_number
	a[Field.ROUND_WINNER] = round_winner
	a[Field.INTERMISSION] = intermission
	return a


## Adopt state from the server. Returns false (and changes nothing) on a malformed array.
func apply_array(a: Array) -> bool:
	if a.size() != Field.COUNT \
			or typeof(a[Field.PHASE]) != TYPE_INT or typeof(a[Field.MODE]) != TYPE_INT \
			or typeof(a[Field.ARENA]) != TYPE_INT \
			or typeof(a[Field.TIME_LEFT]) != TYPE_FLOAT or typeof(a[Field.TIME_LIMIT]) != TYPE_FLOAT \
			or typeof(a[Field.PARTICIPANTS]) != TYPE_PACKED_INT32_ARRAY \
			or typeof(a[Field.READY]) != TYPE_PACKED_INT32_ARRAY \
			or typeof(a[Field.RESULTS]) != TYPE_ARRAY or typeof(a[Field.WINNER]) != TYPE_INT \
			or typeof(a[Field.BLOCKER]) != TYPE_STRING \
			or typeof(a[Field.TEAMS]) != TYPE_PACKED_INT32_ARRAY or typeof(a[Field.ROUND_SCORES]) != TYPE_PACKED_INT32_ARRAY \
			or typeof(a[Field.ROUND]) != TYPE_INT or typeof(a[Field.ROUND_WINNER]) != TYPE_INT \
			or typeof(a[Field.INTERMISSION]) != TYPE_FLOAT:
		return false
	var tl: PackedInt32Array = a[Field.TEAMS]
	var rs: PackedInt32Array = a[Field.ROUND_SCORES]
	if tl.size() % 3 != 0 or rs.size() != 3:
		return false
	var p: int = a[Field.PHASE]
	var m: int = a[Field.MODE]
	var arena: int = a[Field.ARENA]
	if p < 0 or p >= Phase.size() or not MatchRules.is_valid_mode(m) or arena < 0 or arena >= ArenaLayouts.count():
		return false
	phase = p as Phase
	mode = m as MatchRules.Mode
	arena_index = arena
	time_left = a[Field.TIME_LEFT]
	time_limit = a[Field.TIME_LIMIT]
	participants = _ints(a[Field.PARTICIPANTS])
	ready = _ints(a[Field.READY])
	results = a[Field.RESULTS]
	winner_id = a[Field.WINNER]
	blocker = a[Field.BLOCKER]
	teams = {}
	lives = {}
	for i: int in range(0, tl.size(), 3):
		teams[tl[i]] = tl[i + 1]
		lives[tl[i]] = tl[i + 2]
	round_scores = [rs[0], rs[1], rs[2]]
	round_number = a[Field.ROUND]
	round_winner = a[Field.ROUND_WINNER]
	intermission = a[Field.INTERMISSION]
	return true


static func _ints(packed: PackedInt32Array) -> Array[int]:
	var out: Array[int] = []
	for v: int in packed:
		out.append(v)
	return out
