class_name ScoreBoard
extends RefCounted
## Kill/death tally. Killer id <= 0 means environment / no credit.

var kills: Dictionary[int, int] = {}
var deaths: Dictionary[int, int] = {}


func register_kill(killer_id: int, victim_id: int) -> void:
	deaths[victim_id] = deaths.get(victim_id, 0) + 1
	if killer_id > 0 and killer_id != victim_id:
		kills[killer_id] = kills.get(killer_id, 0) + 1


func kills_of(player_id: int) -> int:
	return kills.get(player_id, 0)


func deaths_of(player_id: int) -> int:
	return deaths.get(player_id, 0)
