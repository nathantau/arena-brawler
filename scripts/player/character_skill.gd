class_name CharacterSkill
extends RefCounted
## One skill slot (the shared Dash or the picked special), on cooldown. Behaviour by SkillData.kind:
## - DASH: burst of speed in `direction` with i-frames (movement reads is_dashing()).
## - SHIELD: a barrier centred on `anchor`, facing `direction`, that blocks enemy projectiles.
## - TRANSFORM: a stronger form; fires `form_weapon` (its cooldown is snapshotted).
## - VOLLEY: the Player fires it.
## - SMOKE / CLONES: centred on `anchor` (where you stood), aimed along `direction`.
## - WARD: a ring round the player (wherever they are now) that catches enemy projectiles.
## - GRAPPLE: the Player casts the kunai; on a bite `anchor` is where the pull stops, on a miss it ends at once
##   with the short cooldown. `duration` only caps the pull.
## - SWING: from `anchor` (takeoff) to `anchor + direction` (landing; the Player sets `direction` to that whole
##   vector, not a unit one, so both ends are in the snapshot).
## - ERUPTION: `anchor` = the marked spot (the Player places it against the walls); it goes off as it ends.
## - WHIRL: a spinning staff round the player (wherever they are now); the Player damages and reflects.
## - TRAIL: the trail runs from `anchor` (takeoff) to `anchor + direction` (where he stopped; the Player sets `direction`
##   to that whole vector like SWING). Dash for the first `trail_dash_time`, then the fire burns on.
## - DRIFT: petals for `duration`; the Player moves faster along the stick (else `direction`), untouchable.
## - PILLAR: the line runs from `anchor` (his feet-level centre) to `anchor + direction` (the Player sets `direction` to that
##   whole vector, cut short by a wall); the slam lands when `pillar_windup` has passed.
## - STORM: `anchor` = the cloud's spot (the Player places it against the walls); strikes fall due every `storm_interval`.
## Pure state (no nodes) so it is captured in snapshots and replayed during prediction.

const WHIRL_EPSILON: float = 0.0001

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


func is_drifting() -> bool:
	return data.kind == SkillData.Kind.DRIFT and is_active()


func is_whirling() -> bool:
	return data.kind == SkillData.Kind.WHIRL and is_active()


## WHIRL: true on the one frame (of length `delta`, already ticked) a damage tick falls due.
func whirl_tick_due(delta: float) -> bool:
	var interval: float = data.whirl_interval
	var t: float = elapsed() + WHIRL_EPSILON  # float noise must not tip a frame over a boundary
	return floori(t / interval) != floori((t - delta) / interval)


## STORM: a strike falls due in the step that ticked from `before` to now (the cloud's last step counts).
func storm_tick_due(before: float) -> bool:
	var interval: float = data.storm_interval
	return data.kind == SkillData.Kind.STORM and floori((elapsed() + WHIRL_EPSILON) / interval) \
		> floori((before + WHIRL_EPSILON) / interval)


## Seconds since activation (drives clone paths).
func elapsed() -> float:
	return data.duration - active_remaining


## SWING: how far along the takeoff -> landing line he is, 0..1, slow at both ends like a swing.
func swing_progress() -> float:
	return (1.0 - cos(PI * clampf(elapsed() / data.duration, 0.0, 1.0))) * 0.5


## TRAIL: how far along the trail he is while dashing, 0..1.
func trail_progress() -> float:
	return clampf(elapsed() / data.trail_dash_time, 0.0, 1.0)


## TRAIL: still in the dash part (the frame it ends counts, so he lands exactly on the trail's end).
func trail_dashing(delta: float) -> bool:
	return data.kind == SkillData.Kind.TRAIL and is_active() and elapsed() - delta < data.trail_dash_time


## PILLAR: planting the staff, before the slam (he can't move or fire).
func pillar_winding() -> bool:
	return data.kind == SkillData.Kind.PILLAR and is_active() and elapsed() < data.pillar_windup


## PILLAR: the slam lands in the step that ticked from `before` to now.
func pillar_slammed(before: float) -> bool:
	return data.kind == SkillData.Kind.PILLAR and before < data.pillar_windup and elapsed() >= data.pillar_windup


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
		SkillData.Kind.DASH:
			stats.invulnerable_time = maxf(stats.invulnerable_time, data.dash_iframes)
		SkillData.Kind.SHIELD:
			anchor = origin + direction * data.shield_distance
		SkillData.Kind.SMOKE, SkillData.Kind.CLONES:
			anchor = origin
		SkillData.Kind.SWING, SkillData.Kind.TRAIL:
			anchor = origin
			stats.invulnerable_time = maxf(stats.invulnerable_time, data.swing_iframes)
		SkillData.Kind.DRIFT:
			stats.invulnerable_time = maxf(stats.invulnerable_time, data.duration)
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
