class_name ScoreBoard
extends RefCounted
## Per-match tally: kills / deaths (killer id <= 0 means environment / no credit), damage dealt, shots fired,
## shots that hit (a multi-pellet shot counts once) and flag captures. Authority-side only.

var kills: Dictionary[int, int] = {}
var deaths: Dictionary[int, int] = {}
var damage: Dictionary[int, int] = {}
var shots: Dictionary[int, int] = {}
var hits: Dictionary[int, int] = {}
var captures: Dictionary[int, int] = {}
var _fired: Dictionary = {}  ## shot key -> already counted as a hit?


func register_kill(killer_id: int, victim_id: int) -> void:
	deaths[victim_id] = deaths.get(victim_id, 0) + 1
	if killer_id > 0 and killer_id != victim_id:
		kills[killer_id] = kills.get(killer_id, 0) + 1


func kills_of(player_id: int) -> int:
	return kills.get(player_id, 0)


func deaths_of(player_id: int) -> int:
	return deaths.get(player_id, 0)


func register_shot(owner_id: int, seq: int) -> void:
	shots[owner_id] = shots.get(owner_id, 0) + 1
	_fired[[owner_id, seq]] = false


## Damage to another player. `seq` ties it to a fired shot so pellets of one shot count as one hit;
## ability damage (no matching shot) only adds damage.
func register_damage(owner_id: int, victim_id: int, seq: int, amount: int) -> void:
	if owner_id <= 0 or owner_id == victim_id:
		return
	damage[owner_id] = damage.get(owner_id, 0) + amount
	var key: Array = [owner_id, seq]
	if _fired.get(key, true) == false:
		_fired[key] = true
		hits[owner_id] = hits.get(owner_id, 0) + 1


func register_capture(player_id: int) -> void:
	captures[player_id] = captures.get(player_id, 0) + 1


func damage_of(player_id: int) -> int:
	return damage.get(player_id, 0)


func shots_of(player_id: int) -> int:
	return shots.get(player_id, 0)


func hits_of(player_id: int) -> int:
	return hits.get(player_id, 0)


func captures_of(player_id: int) -> int:
	return captures.get(player_id, 0)


## Hit percentage 0..100 (0 with no shots).
static func accuracy(hit_count: int, shot_count: int) -> int:
	return 0 if shot_count <= 0 else clampi(roundi(100.0 * hit_count / shot_count), 0, 100)


func reset() -> void:
	damage.clear()
	shots.clear()
	hits.clear()
	captures.clear()
	_fired.clear()
	kills.clear()
	deaths.clear()
