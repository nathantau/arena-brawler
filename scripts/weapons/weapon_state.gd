class_name WeaponState
extends RefCounted
## Runtime state for one carried weapon (cooldown). Energy lives on PlayerStats.

var data: WeaponData
var cooldown: float = 0.0


func _init(p_data: WeaponData) -> void:
	data = p_data


func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)


func is_ready() -> bool:
	return cooldown <= 0.0


## Spends energy and starts the cooldown. Returns false (and changes nothing) if
## the weapon is cooling down or the player can't afford the shot.
func try_fire(stats: PlayerStats) -> bool:
	if not is_ready():
		return false
	if not stats.try_spend_energy(data.energy_cost):
		return false
	cooldown = data.fire_interval
	return true
