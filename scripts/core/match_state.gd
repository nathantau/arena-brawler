class_name MatchState
extends RefCounted
## Match flow state shared by server and clients. The server owns it (MatchController) and
## sends it whole, reliably, on every change; clients only count time_left down for display.

enum Phase { LOBBY, COUNTDOWN, PLAYING, RESULTS }
enum Field { PHASE, MODE, ARENA, TIME_LEFT, TIME_LIMIT, PARTICIPANTS, READY, RESULTS, WINNER, BLOCKER, TEAMS, ROUND_SCORES, ROUND, ROUND_WINNER, INTERMISSION, FLAGS, ROUND_REASON, LOCKS, COUNT }
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
## Teams lobby: player id -> the fighter they locked in (humans: set with READY; bots: held from the moment they pick).
## Teammates see these; humans are unique per team, a bot yields to a human (see Arena._resolve_bot_fighters).
var locked: Dictionary[int, StringName] = {}
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
## Why the last round ended (MatchRules.Reason).
var round_reason: int = MatchRules.Reason.NONE
## Capture the flag, per team (index = the flag's owner, 0 unused): where it is, who carries it (an enemy's id),
## where it lies when dropped and how long until it flies home. The server owns these; clients count the timer down.
enum Flag { HOME, CARRIED, DROPPED }
var flag_state: Array[int] = [0, 0, 0]
var flag_carrier: Array[int] = [0, 0, 0]
var flag_pos: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var flag_timer: Array[float] = [0.0, 0.0, 0.0]


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


func reset_flags() -> void:
	flag_state = [Flag.HOME, Flag.HOME, Flag.HOME]
	flag_carrier = [0, 0, 0]
	flag_timer = [0.0, 0.0, 0.0]


## The team whose flag `id` is carrying, or 0.
func carried_flag_of(id: int) -> int:
	for t: int in [MatchRules.TEAM_A, MatchRules.TEAM_B]:
		if flag_state[t] == Flag.CARRIED and flag_carrier[t] == id:
			return t
	return 0


## Teams holding the enemy flag right now (carried, not dropped).
func teams_carrying() -> Array[int]:
	var out: Array[int] = []
	for t: int in [MatchRules.TEAM_A, MatchRules.TEAM_B]:
		if flag_state[MatchRules.other_team(t)] == Flag.CARRIED:
			out.append(t)
	return out


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
	var fl := PackedFloat32Array()
	for t: int in [MatchRules.TEAM_A, MatchRules.TEAM_B]:
		fl.append_array([flag_state[t], flag_carrier[t], flag_pos[t].x, flag_pos[t].y, flag_timer[t]])
	a[Field.FLAGS] = fl
	a[Field.ROUND_REASON] = round_reason
	var lk: Array = []
	for id: int in locked:
		lk.append_array([id, String(locked[id])])
	a[Field.LOCKS] = lk
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
			or typeof(a[Field.INTERMISSION]) != TYPE_FLOAT or typeof(a[Field.ROUND_REASON]) != TYPE_INT \
			or typeof(a[Field.FLAGS]) != TYPE_PACKED_FLOAT32_ARRAY or (a[Field.FLAGS] as PackedFloat32Array).size() != 10 \
			or typeof(a[Field.LOCKS]) != TYPE_ARRAY or (a[Field.LOCKS] as Array).size() % 2 != 0:
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
	round_reason = a[Field.ROUND_REASON]
	locked = {}
	var lk: Array = a[Field.LOCKS]
	for i: int in range(0, lk.size() - 1, 2):
		if typeof(lk[i]) == TYPE_INT and typeof(lk[i + 1]) == TYPE_STRING:
			locked[lk[i]] = StringName(lk[i + 1])
	var fl: PackedFloat32Array = a[Field.FLAGS]
	for i: int in 2:
		var t: int = i + 1
		flag_state[t] = clampi(roundi(fl[i * 5]), 0, Flag.size() - 1)
		flag_carrier[t] = roundi(fl[i * 5 + 1])
		flag_pos[t] = Vector2(fl[i * 5 + 2], fl[i * 5 + 3])
		flag_timer[t] = fl[i * 5 + 4]
	return true


static func _ints(packed: PackedInt32Array) -> Array[int]:
	var out: Array[int] = []
	for v: int in packed:
		out.append(v)
	return out
