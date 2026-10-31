class_name CharacterSkill
extends RefCounted
## One skill slot (the shared Dash or the picked special), on cooldown. Behaviour by SkillData.kind:
## - DASH: burst of speed in `direction` with i-frames (movement reads is_dashing()).
## - SHIELD: a barrier centred on `anchor`, facing `direction`, that blocks enemy projectiles.
## - TRANSFORM: a stronger form; fires `form_weapon` (its cooldown is snapshotted).
## - BLINK: like a dash's i-frames; the Player does the hop. VOLLEY: the Player fires it.
## - SMOKE / CLONES: centred on `anchor` (where you stood), aimed along `direction`.
## - WARD: a ring round the player (wherever they are now) that catches enemy projectiles.
## Pure state (no nodes) so it is captured in snapshots and replayed during prediction.

var data: SkillData
var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var direction: Vector2 = Vector2.ZERO
var anchor: Vector2 = Vector2.ZERO
## The transformed form's weapon (null for other kinds).
var form_weapon: WeaponState


func _init(p_data: SkillData = null) -> void:
	data = p_data
	if data != null and data.form_weapon != null:
		form_weapon = WeaponState.new(data.form_weapon)


func is_active() -> bool:
	return active_remaining > 0.0


func is_ready() -> bool:
	return cooldown_remaining <= 0.0 and not is_active()


func is_dashing() -> bool:
	return data.kind == SkillData.Kind.DASH and is_active()


func is_shielding() -> bool:
	return data.kind == SkillData.Kind.SHIELD and is_active()


func is_transformed() -> bool:
	return data.kind == SkillData.Kind.TRANSFORM and is_active()


func is_smoking() -> bool:
	return data.kind == SkillData.Kind.SMOKE and is_active()


func is_cloning() -> bool:
	return data.kind == SkillData.Kind.CLONES and is_active()


func is_warding() -> bool:
	return data.kind == SkillData.Kind.WARD and is_active()


## Seconds since activation (drives clone paths).
func elapsed() -> float:
	return data.duration - active_remaining


## 1.0 = just used, 0.0 = ready.
func cooldown_fraction() -> float:
	if data.cooldown <= 0.0:
		return 0.0
	return clampf(cooldown_remaining / data.cooldown, 0.0, 1.0)


## `dir`: dash direction / facing. `origin`: the player's position (shield placement).
func try_activate(dir: Vector2, origin: Vector2, stats: PlayerStats) -> bool:
	if not is_ready() or dir.length_squared() == 0.0:
		return false
	direction = dir.normalized()
	active_remaining = data.duration
	cooldown_remaining = data.cooldown
	match data.kind:
		SkillData.Kind.DASH, SkillData.Kind.BLINK:
			stats.invulnerable_time = maxf(stats.invulnerable_time, data.dash_iframes)
		SkillData.Kind.SHIELD:
			anchor = origin + direction * data.shield_distance
		SkillData.Kind.SMOKE, SkillData.Kind.CLONES:
			anchor = origin
		SkillData.Kind.TRANSFORM:
			form_weapon.cooldown = 0.0
	return true


## The cooldown runs while the skill is active too (set cooldown > duration).
func tick(delta: float) -> void:
	active_remaining = maxf(0.0, active_remaining - delta)
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if form_weapon != null:
		form_weapon.tick(delta)


func reset() -> void:
	cooldown_remaining = 0.0
	active_remaining = 0.0
	if form_weapon != null:
		form_weapon.cooldown = 0.0
