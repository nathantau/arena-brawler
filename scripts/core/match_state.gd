class_name MatchState
extends RefCounted
## Match flow state shared by server and clients. The server owns it (MatchController) and
## sends it whole, reliably, on every change; clients only count time_left down for display.

enum Phase { LOBBY, COUNTDOWN, PLAYING, RESULTS }
enum Field { PHASE, MODE, ARENA, TIME_LEFT, TIME_LIMIT, PARTICIPANTS, READY, RESULTS, WINNER, BLOCKER, COUNT }
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


func is_participant(id: int) -> bool:
	return participants.has(id)


## Movement, firing and skills are frozen during the countdown and on the results screen.
func inputs_locked() -> bool:
	return phase == Phase.COUNTDOWN or phase == Phase.RESULTS


## Warm-up in the lobby lets everyone respawn; in a match only participants do.
func may_respawn(id: int) -> bool:
	match phase:
		Phase.LOBBY:
			return true
		Phase.COUNTDOWN, Phase.PLAYING:
			return is_participant(id)
	return false


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
			or typeof(a[Field.BLOCKER]) != TYPE_STRING:
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
	return true


static func _ints(packed: PackedInt32Array) -> Array[int]:
	var out: Array[int] = []
	for v: int in packed:
		out.append(v)
	return out
