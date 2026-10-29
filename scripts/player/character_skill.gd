class_name CharacterSkill
extends RefCounted
## The character's one skill, on cooldown. Behaviour depends on CharacterData.skill:
## - DASH: burst of speed in `direction` with i-frames (movement reads is_dashing()).
## - SHIELD: a barrier centred on `anchor`, facing `direction`, that blocks enemy projectiles.
## - DUAL_WIELD: every shot fires a second, offset volley for no extra energy.
## Pure state (no nodes) so it is captured in snapshots and replayed during prediction.

var data: CharacterData
var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var direction: Vector2 = Vector2.ZERO
var anchor: Vector2 = Vector2.ZERO


func _init(p_data: CharacterData = null) -> void:
	data = p_data


func is_active() -> bool:
	return active_remaining > 0.0


func is_ready() -> bool:
	return cooldown_remaining <= 0.0 and not is_active()


func is_dashing() -> bool:
	return data.skill == CharacterData.SkillKind.DASH and is_active()


func is_shielding() -> bool:
	return data.skill == CharacterData.SkillKind.SHIELD and is_active()


func is_dual_wielding() -> bool:
	return data.skill == CharacterData.SkillKind.DUAL_WIELD and is_active()


## 1.0 = just used, 0.0 = ready.
func cooldown_fraction() -> float:
	if data.skill_cooldown <= 0.0:
		return 0.0
	return clampf(cooldown_remaining / data.skill_cooldown, 0.0, 1.0)


## `dir`: dash direction / facing. `origin`: the player's position (shield placement).
func try_activate(dir: Vector2, origin: Vector2, stats: PlayerStats) -> bool:
	if not is_ready() or dir.length_squared() == 0.0:
		return false
	direction = dir.normalized()
	active_remaining = data.skill_duration
	cooldown_remaining = data.skill_cooldown
	match data.skill:
		CharacterData.SkillKind.DASH:
			stats.invulnerable_time = maxf(stats.invulnerable_time, data.dash_iframes)
		CharacterData.SkillKind.SHIELD:
			anchor = origin + direction * data.shield_distance
	return true


func tick(delta: float) -> void:
	active_remaining = maxf(0.0, active_remaining - delta)
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


func reset() -> void:
	cooldown_remaining = 0.0
	active_remaining = 0.0
