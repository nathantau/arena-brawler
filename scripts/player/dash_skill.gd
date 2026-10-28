class_name DashSkill
extends RefCounted
## Dash-dodge: short burst of speed with i-frames, on cooldown.

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var direction: Vector2 = Vector2.ZERO


func is_active() -> bool:
	return active_remaining > 0.0


func is_ready() -> bool:
	return cooldown_remaining <= 0.0 and not is_active()


## 1.0 = just used, 0.0 = ready.
func cooldown_fraction() -> float:
	return clampf(cooldown_remaining / Constants.DASH_COOLDOWN, 0.0, 1.0)


func try_activate(dir: Vector2, stats: PlayerStats) -> bool:
	if not is_ready() or dir.length_squared() == 0.0:
		return false
	direction = dir.normalized()
	active_remaining = Constants.DASH_DURATION
	cooldown_remaining = Constants.DASH_COOLDOWN
	stats.invulnerable_time = maxf(stats.invulnerable_time, Constants.DASH_IFRAME_TIME)
	return true


func tick(delta: float) -> void:
	active_remaining = maxf(0.0, active_remaining - delta)
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


func reset() -> void:
	cooldown_remaining = 0.0
	active_remaining = 0.0
