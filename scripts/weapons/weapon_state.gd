class_name WeaponState
extends RefCounted
## Runtime state for one carried weapon (cooldown, spin-up). Energy lives on PlayerStats.

var data: WeaponData
var cooldown: float = 0.0
## Spin-up (WeaponData.spinup_time): seconds of continuous fire so far, and how long the trigger has been up. Synced.
var spin: float = 0.0
var idle: float = 0.0


func _init(p_data: WeaponData) -> void:
	data = p_data


func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown <= 0.0 and spin > 0.0:
		idle += delta
		if idle > Constants.FIRE_STREAK_GRACE:
			spin = 0.0


func is_ready() -> bool:
	return cooldown <= 0.0


## Seconds until the next shot: slower while a spin-up weapon is still winding up.
func current_interval() -> float:
	if data.spinup_time <= 0.0:
		return data.fire_interval
	return data.fire_interval * lerpf(data.spinup_slow, 1.0, clampf(spin / data.spinup_time, 0.0, 1.0))


## Spends energy and starts the cooldown. Returns false (and changes nothing) if
## the weapon is cooling down or the player can't afford the shot.
func try_fire(stats: PlayerStats) -> bool:
	if not is_ready():
		return false
	if not stats.try_spend_energy(data.energy_cost):
		return false
	cooldown = current_interval()
	if data.spinup_time > 0.0:
		spin = minf(data.spinup_time, spin + cooldown)
		idle = 0.0
	return true
