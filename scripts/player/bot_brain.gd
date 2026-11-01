class_name BotBrain
extends PlayerController
## Offline / server bot. Produces InputFrames like a player would: keeps a preferred range per weapon while strafing,
## aims with lead + a human reaction delay and inaccuracy, dodges incoming shots (sidestep, Dash for big ones), hides
## behind walls when hurt or out of energy and peeks back out, walks to energy pickups when low, uses its specials at
## sensible moments per kind (respecting the one-ability-at-a-time lock) and unsticks itself from corners.
## `skill` (0..1, default medium) is the single difficulty knob: reaction time, aim error, aim turn speed, how often it
## dodges. All randomness comes from `rng`, seeded per bot (match_seed + id), so a given match replays identically.

## Difficulty knob default (0 = sluggish and sloppy, 1 = sharp).
const SKILL_DEFAULT: float = 0.5
const REACTION_SLOW: float = 0.55
const REACTION_FAST: float = 0.12
const AIM_ERROR_SLOW_DEG: float = 16.0
const AIM_ERROR_FAST_DEG: float = 3.0
const TURN_RATE_SLOW: float = 5.0
const TURN_RATE_FAST: float = 16.0
const DODGE_CHANCE_SLOW: float = 0.15
const DODGE_CHANCE_FAST: float = 0.85
const LEAD_MAX_SKILL: float = 0.9
const LEAD_MAX_PX: float = 90.0

const PREF_MIN: float = 130.0
const PREF_MAX: float = 480.0
const PREF_RANGE_SHARE: float = 0.5
const PREF_BEAM_SHARE: float = 0.6
const PREF_MELEE_SHARE: float = 0.7
const PREF_MELEE_MIN: float = 50.0
const RANGE_DEADZONE: float = 0.15
const RADIAL_GAIN: float = 1.6
const STRAFE_WEIGHT: float = 0.9
const LOW_HP_FRACTION: float = 0.35
const LOW_ENERGY_FRACTION: float = 0.15
const PICKUP_ENERGY_FRACTION: float = 0.35
const PICKUP_PULL_RANGE: float = 260.0
const PICKUP_PULL: float = 0.7

const DODGE_HORIZON: float = 0.6
const DODGE_MARGIN: float = 14.0
const DODGE_TIME: float = 0.3
const DODGE_RECHECK: float = 0.35
const DODGE_WEIGHT: float = 1.6
const DASH_DODGE_TIME: float = 0.3
const BIG_SHOT_SHARE: float = 0.25
const BIG_SPLASH_DAMAGE: int = 20
const PRESSURE_TIME: float = 1.2

const COVER_DIRS: int = 12
const COVER_DISTANCES: Array[float] = [80.0, 150.0, 230.0]
const COVER_MIN_ENEMY_DIST: float = 100.0
const COVER_STAY_MIN: float = 1.6
const COVER_STAY_MAX: float = 2.6
const COVER_COOLDOWN_MIN: float = 2.0
const COVER_COOLDOWN_MAX: float = 3.5
const COVER_REACHED: float = 24.0
const ENEMY_MEMORY: float = 4.0
const INVESTIGATE_TIME: float = 3.0

const WHISKER_LENGTH: float = 70.0
const WHISKER_ANGLES: Array[float] = [40.0, 80.0, 120.0]
const STUCK_WINDOW: float = 0.5
const STUCK_MIN_MOVE: float = 12.0
const STUCK_MIN_INPUT: float = 0.3
const UNSTICK_TIME: float = 0.5
const UNSTICK_MIN_DEG: float = 70.0
const UNSTICK_MAX_DEG: float = 130.0

const GOAL_REACHED: float = 60.0
const GOAL_TIME_MIN: float = 4.0
const GOAL_TIME_MAX: float = 7.0
const GOAL_HUNT_CHANCE: float = 0.5
const SPECIAL_PRESS_RATE: float = 3.0
const ESCAPE_DIST: float = 220.0
const ESCAPE_HP_FRACTION: float = 0.5
const DASH_CLOSE_EXTRA: float = 140.0
const DASH_CLOSE_MAX: float = 400.0
const SWING_CLOSE_MIN: float = 260.0
const TRAIL_MIN: float = 120.0
const TRAIL_EXTRA: float = 60.0
const ZONE_FIT: float = 0.8
const NEAR_FIGHT: float = 500.0
const STEP_ENGAGE: float = 360.0
const TARGET_STICK: float = 0.75
const TARGET_WEAK_BIAS: float = 0.5
const MOVING_TARGET_DIST: float = 20.0

var arena: Arena
var rng := RandomNumberGenerator.new()
## Difficulty 0..1 (see top). Set after construction to change.
var skill: float = SKILL_DEFAULT
## Total seconds spent stuck (asked to move, not moving), for logging.
var stuck_time: float = 0.0
## Fighters with several signature specials (kinds from SkillData.Kind.STEP up, e.g. Shadow's) rotate between them: a random
## one is picked into slot 1 each time it comes off cooldown, so bots use the whole kit.
var rotates_kit: bool = true

var _frame := InputFrame.new()
var _query := PhysicsRayQueryParameters2D.new()
var _wall_query := PhysicsRayQueryParameters2D.new()
var _decision_timer: float = 0.0
var _strafe_sign: float = 1.0
## Re-rolled with each decision, not every frame: a fresh error each frame flipped bots left/right when aiming up/down.
var _aim_error: float = 0.0
var _last_aim: Vector2 = Vector2.ZERO
var _aim_cur: Vector2 = Vector2.ZERO
var _since_target: float = INF
var _kit_ready: bool = false
var _target: Player
var _target_spot: Vector2 = Vector2.ZERO
var _react_left: float = 0.0
var _last_enemy_pos: Vector2 = Vector2.ZERO
var _last_total: int = 0
var _pressure: float = 0.0
var _dodge_cd: float = 0.0
var _dodge_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _threat_time: float = 0.0
var _threat_big: bool = false
var _cover_left: float = 0.0
var _cover_cd: float = 0.0
var _cover_pt: Vector2 = Vector2.ZERO
var _goal: Vector2 = Vector2.ZERO
var _goal_left: float = 0.0
var _stuck_clock: float = 0.0
var _stuck_ref: Vector2 = Vector2.ZERO
var _unstick_left: float = 0.0
var _unstick_dir: Vector2 = Vector2.ZERO
var _want_dir: Vector2 = Vector2.ZERO


func _init(p_arena: Arena, bot_seed: int) -> void:
	arena = p_arena
	rng.seed = bot_seed


# --- Difficulty ---

func reaction_time() -> float:
	return lerpf(REACTION_SLOW, REACTION_FAST, skill)


func aim_error_deg() -> float:
	return lerpf(AIM_ERROR_SLOW_DEG, AIM_ERROR_FAST_DEG, skill)


func turn_rate() -> float:
	return lerpf(TURN_RATE_SLOW, TURN_RATE_FAST, skill)


func dodge_chance() -> float:
	return lerpf(DODGE_CHANCE_SLOW, DODGE_CHANCE_FAST, skill)


# --- Pure decisions (tested) ---

## Distance a bot likes to fight at with this weapon: melee closes in, snipers keep away.
static func preferred_range(w: WeaponData) -> float:
	match w.kind:
		WeaponData.Kind.MELEE:
			return maxf(PREF_MELEE_MIN, maxf(w.melee_range, w.splash_radius) * PREF_MELEE_SHARE)
		WeaponData.Kind.BEAM:
			return clampf(w.projectile_range * PREF_BEAM_SHARE, PREF_MIN, PREF_MAX)
	return clampf(w.projectile_range * PREF_RANGE_SHARE, PREF_MIN, PREF_MAX)


## Unit sidestep (perpendicular to the shot, away from the side it passes on) if a projectile at `proj_pos` flying at
## `proj_vel` will pass within `hit_radius` of `me` in the next `horizon` seconds; else ZERO. `time` gets the time to closest approach.
static func dodge_dir(me: Vector2, proj_pos: Vector2, proj_vel: Vector2, hit_radius: float, horizon: float) -> Vector2:
	var sp2: float = proj_vel.length_squared()
	if sp2 < 1.0:
		return Vector2.ZERO
	var t: float = (me - proj_pos).dot(proj_vel) / sp2
	if t < 0.0 or t > horizon:
		return Vector2.ZERO
	var off: Vector2 = me - (proj_pos + proj_vel * t)
	if off.length() > hit_radius:
		return Vector2.ZERO
	var perp: Vector2 = proj_vel.normalized().orthogonal()
	if off.dot(perp) < 0.0:
		perp = -perp
	return perp


## Call every frame with where the bot is and whether it is trying to move; true once when a stuck window ends without
## the bot having gone anywhere (it should then try another way).
func track_stuck(pos: Vector2, moving: bool, delta: float) -> bool:
	if not moving:
		_stuck_clock = 0.0
		_stuck_ref = pos
		return false
	if _stuck_clock <= 0.0:
		_stuck_ref = pos
	_stuck_clock += delta
	if _stuck_clock < STUCK_WINDOW:
		return false
	var stuck: bool = pos.distance_to(_stuck_ref) < STUCK_MIN_MOVE
	_stuck_clock = 0.0
	_stuck_ref = pos
	if stuck:
		stuck_time += STUCK_WINDOW
	return stuck


## True if a ready special can be pressed now: ready, not locked by the other slot's ability.
static func can_press(player: Player, slot: int) -> bool:
	return player.skills[slot].is_ready() and not player.skill_locked(slot)


## Whether pressing the special now would do anything: Leaf Gust only helps with an enemy in its cone's reach, Verdant
## Bloom only when hurt, Bark Skin only when a fight is on; everything else is always fine.
func special_useful(player: Player, enemy_dist: float) -> bool:
	return slot_useful(player, 1, enemy_dist)


func slot_useful(player: Player, slot: int, enemy_dist: float) -> bool:
	var sd: SkillData = player.skills[slot].data
	match sd.kind:
		SkillData.Kind.GUST:
			return enemy_dist <= sd.gust_range * Constants.BOT_GUST_REACH_SCALE
		SkillData.Kind.BLOOM:
			return player.stats.hp < player.stats.max_hp * Constants.BOT_BLOOM_HP_FRACTION
		SkillData.Kind.BARK_SKIN:
			return enemy_dist <= Constants.BOT_BARK_ENGAGE_DISTANCE
	return true


## Whether this slot's special is worth pressing right now: `dist` to the target (INF if none), `in_sight` a target is
## visible, `pressured` we took damage lately. Ignores readiness / the lock (see can_press).
func slot_wanted(player: Player, slot: int, dist: float, in_sight: bool, pressured: bool) -> bool:
	if not slot_useful(player, slot, dist):
		return false
	var sd: SkillData = player.skills[slot].data
	var hurt: bool = player.stats.hp < player.stats.max_hp * ESCAPE_HP_FRACTION
	var escape: bool = hurt and pressured and dist < ESCAPE_DIST
	var w: WeaponData = player.held_weapon().data
	match sd.kind:
		SkillData.Kind.DASH:
			var closes: bool = w.kind == WeaponData.Kind.MELEE and dist > preferred_range(w) + DASH_CLOSE_EXTRA \
				and dist < DASH_CLOSE_MAX
			return in_sight and (closes or escape)
		SkillData.Kind.SHIELD, SkillData.Kind.WARD:
			return in_sight and pressured
		SkillData.Kind.BARK_SKIN:
			return in_sight and (pressured or dist < ESCAPE_DIST)
		SkillData.Kind.SMOKE:
			return hurt and pressured
		SkillData.Kind.CLONES:
			return in_sight and pressured
		SkillData.Kind.TRANSFORM:
			return in_sight and dist < NEAR_FIGHT
		SkillData.Kind.VOLLEY, SkillData.Kind.SNARE:
			var reach: float = sd.volley_weapon.projectile_range if sd.volley_weapon != null else NEAR_FIGHT
			return in_sight and dist < reach * ZONE_FIT
		SkillData.Kind.SWING:
			return in_sight and ((dist > SWING_CLOSE_MIN and dist < sd.swing_range + DASH_CLOSE_EXTRA) or escape)
		SkillData.Kind.GRAPPLE:
			return in_sight and dist > SWING_CLOSE_MIN and dist <= sd.grapple_range
		SkillData.Kind.TRAIL:
			return in_sight and (escape or (dist > TRAIL_MIN and dist < sd.trail_distance + TRAIL_EXTRA))
		SkillData.Kind.ERUPTION:
			var r: float = sd.eruption_blast.splash_radius if sd.eruption_blast != null else 60.0
			return in_sight and absf(dist - sd.eruption_distance) < r * ZONE_FIT
		SkillData.Kind.STORM:
			return in_sight and absf(dist - sd.storm_distance) < sd.storm_radius * ZONE_FIT
		SkillData.Kind.LIGHTNING:
			return in_sight and dist < (sd.beam_weapon.projectile_range if sd.beam_weapon != null else NEAR_FIGHT) * ZONE_FIT
		SkillData.Kind.THUNDER:
			var tr: float = sd.thunder_blast.splash_radius if sd.thunder_blast != null else 60.0
			return in_sight and absf(dist - sd.thunder_distance) < tr * ZONE_FIT
		SkillData.Kind.PILLAR:
			return in_sight and dist < sd.pillar_length * ZONE_FIT
		SkillData.Kind.NOVA:
			var nr: float = sd.nova_blast.splash_radius if sd.nova_blast != null else 100.0
			return in_sight and dist < nr * ZONE_FIT
		SkillData.Kind.WHIRL:
			return in_sight and dist < sd.whirl_radius * 1.2
		SkillData.Kind.DRIFT:
			return escape
		SkillData.Kind.STEP:
			return in_sight and (dist < STEP_ENGAGE or escape)
		SkillData.Kind.OVERDRIVE:
			return in_sight and dist < NEAR_FIGHT
		SkillData.Kind.HOUND:
			return in_sight and dist < sd.hound_sight
		SkillData.Kind.BIND:
			return in_sight and dist < sd.bind_range * ZONE_FIT
	return in_sight


## Kinds whose press moves the bot along move_vec / aim_vec (so an escape press points away from the enemy).
static func is_mover(kind: SkillData.Kind) -> bool:
	return kind == SkillData.Kind.DASH or kind == SkillData.Kind.SWING or kind == SkillData.Kind.TRAIL \
		or kind == SkillData.Kind.DRIFT or kind == SkillData.Kind.STEP


# --- Per-frame brain ---

func get_input(player: Player, delta: float) -> InputFrame:
	_frame.seq += 1
	_rotate_kit(player)
	_tick_timers(delta)
	var pos: Vector2 = player.global_position
	var total: int = player.stats.hp + player.stats.armor
	if total < _last_total:
		_pressure = PRESSURE_TIME
	_last_total = total
	var hp_frac: float = float(player.stats.hp) / float(player.stats.max_hp)
	var w: WeaponData = player.held_weapon().data
	if _decision_timer <= 0.0:
		_decision_timer = rng.randf_range(Constants.BOT_DECISION_MIN, Constants.BOT_DECISION_MAX)
		_strafe_sign = 1.0 if rng.randf() < 0.5 else -1.0
		_aim_error = deg_to_rad(rng.randf_range(-aim_error_deg(), aim_error_deg()))

	_frame.move_vec = Vector2.ZERO
	_frame.aim_vec = Vector2.ZERO
	_frame.fire = false
	_frame.skill = false
	_frame.special = false

	var prev_target: Player = _target
	_target = null
	var spot: Variant = _nearest_visible_enemy(player)
	var has_target: bool = spot != null
	var seen_before: float = _since_target
	_since_target = 0.0 if has_target else _since_target + delta
	var dist: float = INF
	var dir: Vector2 = Vector2.ZERO
	if has_target:
		_target_spot = spot as Vector2
		_last_enemy_pos = _target_spot
		var to: Vector2 = _target_spot - pos
		dist = to.length()
		dir = to / maxf(dist, 0.001)
		if seen_before > Constants.BOT_TARGET_MEMORY or (_target != prev_target and _target != null):
			_react_left = reaction_time() * rng.randf_range(0.8, 1.2)
	elif _since_target < Constants.BOT_TARGET_MEMORY:
		_frame.aim_vec = _last_aim

	var move: Vector2 = Vector2.ZERO
	var low_hp: bool = hp_frac < LOW_HP_FRACTION
	var cost: int = w.energy_cost
	var low_energy: bool = cost > 0 and player.stats.energy < player.stats.max_energy * LOW_ENERGY_FRACTION
	var enemy_known: bool = has_target or _since_target < ENEMY_MEMORY

	# Cover: hide when hurt or dry, peek out again once the timer runs out.
	if _cover_left <= 0.0 and _cover_cd <= 0.0 and enemy_known and (low_hp or low_energy):
		var cover: Variant = _find_cover(player, _last_enemy_pos)
		if cover != null:
			_cover_pt = cover as Vector2
			_cover_left = rng.randf_range(COVER_STAY_MIN, COVER_STAY_MAX)
			_cover_cd = _cover_left + rng.randf_range(COVER_COOLDOWN_MIN, COVER_COOLDOWN_MAX)
	if _cover_left > 0.0 and not low_hp and not low_energy and player.stats.energy > player.stats.max_energy * 0.7:
		_cover_left = 0.0

	if _cover_left > 0.0:
		var to_cover: Vector2 = _cover_pt - pos
		if to_cover.length() > COVER_REACHED:
			move = to_cover.normalized()
		else:
			move = Vector2.ZERO
	elif has_target:
		move = _combat_move(player, w, dist, dir, low_hp)
	else:
		move = _roam_move(player, pos, low_hp)

	# Pickup pull while fighting with a dry tank.
	if has_target and _cover_left <= 0.0 and player.stats.energy < player.stats.max_energy * PICKUP_ENERGY_FRACTION:
		var e: Variant = _nearest_spot(arena.map.energy_spots if arena != null and arena.map != null else PackedVector2Array(), pos, PICKUP_PULL_RANGE)
		if e != null:
			move += ((e as Vector2) - pos).normalized() * PICKUP_PULL

	# Dodge incoming shots.
	if _dodge_cd <= 0.0:
		var side: Vector2 = _scan_threat(player)
		if side != Vector2.ZERO:
			_dodge_cd = DODGE_RECHECK
			if rng.randf() < dodge_chance():
				if _blocked(player, side):
					side = -side
				_dodge_dir = side
				_dodge_left = DODGE_TIME
				if _threat_big and _threat_time < DASH_DODGE_TIME and player.skills[0].data.kind == SkillData.Kind.DASH \
						and can_press(player, 0) and rng.randf() < dodge_chance():
					_frame.skill = true
	if _dodge_left > 0.0:
		move = (_dodge_dir * DODGE_WEIGHT + move * (1.0 - DODGE_WEIGHT * 0.5)).limit_length(1.0)

	# Unstick overrides everything it must: step off in another direction for a moment.
	_want_dir = move
	var moving: bool = move.length() > STUCK_MIN_INPUT and not _rooted(player)
	if track_stuck(pos, moving, delta):
		_unstick_left = UNSTICK_TIME
		var turn: float = deg_to_rad(rng.randf_range(UNSTICK_MIN_DEG, UNSTICK_MAX_DEG)) * (1.0 if rng.randf() < 0.5 else -1.0)
		_unstick_dir = move.normalized().rotated(turn)
		_strafe_sign = -_strafe_sign
		_goal_left = 0.0
		_cover_left = 0.0
	if _unstick_left > 0.0:
		move = _unstick_dir
	move = _steer(player, move)
	_frame.move_vec = move * Constants.BOT_MOVE_SCALE if move.length() > 0.0 else Vector2.ZERO

	if has_target:
		# Aim with lead and error; the aim vector turns at a limited speed, like a thumb.
		var aim_pt: Vector2 = _target_spot
		if _target != null and w.kind == WeaponData.Kind.PROJECTILE and w.projectile_speed > 0.0 \
				and _target_spot.distance_to(_target.global_position) < MOVING_TARGET_DIST + Constants.PLAYER_RADIUS:
			var lead: Vector2 = _target.velocity * (dist / w.projectile_speed) * skill * LEAD_MAX_SKILL
			aim_pt += lead.limit_length(LEAD_MAX_PX)
		var want: Vector2 = player.aim_at(aim_pt).rotated(_aim_error)
		if _aim_cur == Vector2.ZERO:
			_aim_cur = want
		else:
			var ang: float = _aim_cur.angle_to(want)
			var step: float = turn_rate() * delta
			_aim_cur = _aim_cur.rotated(clampf(ang, -step, step))
		_frame.aim_vec = _aim_cur
		_last_aim = _aim_cur
		var can_afford: bool = cost <= 0 or player.stats.energy >= cost
		_frame.fire = _react_left <= 0.0 and can_afford and not player.is_hidden()
	else:
		_aim_cur = Vector2.ZERO

	_use_specials(player, dist, has_target, hp_frac, dir, delta)
	return _frame


func _tick_timers(delta: float) -> void:
	_decision_timer -= delta
	_react_left = maxf(0.0, _react_left - delta)
	_pressure = maxf(0.0, _pressure - delta)
	_dodge_cd -= delta
	_dodge_left -= delta
	_cover_left -= delta
	_cover_cd -= delta
	_goal_left -= delta
	_unstick_left -= delta


## Pressing specials: each ready, unlocked slot is pressed (once per frame) when slot_wanted, at a human-ish rate.
func _use_specials(player: Player, dist: float, has_target: bool, hp_frac: float, dir: Vector2, delta: float) -> void:
	if _frame.skill:
		return
	for slot: int in player.skills.size():
		if not can_press(player, slot):
			continue
		var pressured: bool = _pressure > 0.0
		if not slot_wanted(player, slot, dist, has_target, pressured):
			continue
		if rng.randf() >= SPECIAL_PRESS_RATE * delta:
			continue
		var kind: SkillData.Kind = player.skills[slot].data.kind
		if is_mover(kind) and has_target and hp_frac < ESCAPE_HP_FRACTION and pressured and dist < ESCAPE_DIST:
			_frame.aim_vec = -dir
			_frame.move_vec = -dir
			_frame.fire = false
		if slot == 0:
			_frame.skill = true
		else:
			_frame.special = true
		return


func _rooted(player: Player) -> bool:
	if player.frozen or player.dead or player.stats.stun_remaining > 0.0:
		return true
	for s: CharacterSkill in player.skills:
		if s.is_active():
			return true
	return false


## Movement while an enemy is in sight: close or open the gap to the preferred range, strafe around it.
func _combat_move(player: Player, w: WeaponData, dist: float, dir: Vector2, low_hp: bool) -> Vector2:
	var pref: float = preferred_range(w)
	if low_hp:
		pref *= 1.5
	var err: float = (dist - pref) / pref
	var radial: float = 0.0 if absf(err) < RANGE_DEADZONE else clampf(err * RADIAL_GAIN, -1.0, 1.0)
	var strafe_w: float = STRAFE_WEIGHT * (1.0 - 0.6 * clampf(err, 0.0, 1.0))
	return (dir * radial + dir.orthogonal() * _strafe_sign * strafe_w).limit_length(1.0)


## Movement with nobody in sight: investigate where one was, fetch energy when low, else patrol between points.
func _roam_move(player: Player, pos: Vector2, low_hp: bool) -> Vector2:
	var goal: Vector2 = _goal
	if _since_target < INVESTIGATE_TIME and not low_hp:
		goal = _last_enemy_pos
	elif player.stats.energy < player.stats.max_energy * PICKUP_ENERGY_FRACTION and arena != null and arena.map != null \
			and arena.map.energy_spots.size() > 0:
		goal = _nearest_spot(arena.map.energy_spots, pos, INF) as Vector2
	elif _goal_left <= 0.0 or pos.distance_to(_goal) < GOAL_REACHED:
		_pick_goal(player, pos)
		goal = _goal
	if pos.distance_to(goal) < GOAL_REACHED * 0.5:
		return Vector2.ZERO
	return (goal - pos).normalized()


func _pick_goal(player: Player, pos: Vector2) -> void:
	_goal_left = rng.randf_range(GOAL_TIME_MIN, GOAL_TIME_MAX)
	var spots: PackedVector2Array = PackedVector2Array()
	if arena != null and arena.map != null:
		spots.append_array(arena.map.spawns)
		spots.append_array(arena.map.energy_spots)
		spots.append_array(arena.map.weapon_spots)
	var hunt: bool = rng.randf() < GOAL_HUNT_CHANCE
	if hunt and arena != null:
		var best: Variant = null
		var best_d: float = INF
		for p: Player in arena.players:
			if p == player or p.dead:
				continue
			var d: float = pos.distance_squared_to(p.global_position)
			if d < best_d:
				best_d = d
				best = p.global_position
		if best != null:
			_goal = best as Vector2
			return
	if spots.size() > 0:
		_goal = spots[rng.randi() % spots.size()]
	else:
		_goal = pos + Vector2.RIGHT.rotated(rng.randf() * TAU) * 200.0


static func _nearest_spot(spots: PackedVector2Array, pos: Vector2, max_dist: float) -> Variant:
	var best: Variant = null
	var best_d: float = max_dist * max_dist if max_dist != INF else INF
	for s: Vector2 in spots:
		var d: float = pos.distance_squared_to(s)
		if d < best_d:
			best_d = d
			best = s
	return best


## Whiskers: if the way ahead is blocked by a wall, turn to the nearest free direction (preferring the strafe side),
## so bots don't push into corners or run along walls.
func _steer(player: Player, dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO or player.get_world_2d() == null:
		return dir
	if not _blocked(player, dir):
		return dir
	for a: float in WHISKER_ANGLES:
		for sgn: float in [_strafe_sign, -_strafe_sign]:
			var cand: Vector2 = dir.rotated(deg_to_rad(a) * sgn)
			if not _blocked(player, cand):
				return cand
	return dir


func _blocked(player: Player, dir: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	_wall_query.from = player.global_position
	_wall_query.to = player.global_position + dir.normalized() * (WHISKER_LENGTH + Constants.PLAYER_RADIUS)
	_wall_query.collision_mask = Constants.LAYER_WALL_FEET
	return not space.intersect_ray(_wall_query).is_empty()


## The earliest enemy projectile that will hit us soon: returns the sidestep direction (ZERO if none) and fills
## _threat_time / _threat_big.
func _scan_threat(player: Player) -> Vector2:
	var pool: ProjectilePool = player.projectiles
	if pool == null:
		return Vector2.ZERO
	var best_t: float = INF
	var best: Vector2 = Vector2.ZERO
	var pos: Vector2 = player.global_position
	var vitals: float = float(player.stats.hp + player.stats.armor)
	for s: ProjectilePool.Slot in pool.debug_slots():
		if not s.active or s.attacker_id == player.player_id:
			continue
		var reach: float = Constants.PLAYER_RADIUS + s.radius + s.splash_radius * 0.6 + DODGE_MARGIN
		var side: Vector2 = dodge_dir(pos, s.pos, s.vel, reach, DODGE_HORIZON)
		if side == Vector2.ZERO:
			continue
		var t: float = (pos - s.pos).dot(s.vel) / s.vel.length_squared()
		if t < best_t:
			best_t = t
			best = side
			_threat_big = float(s.damage) >= vitals * BIG_SHOT_SHARE or (s.splash_radius > 0.0 and s.damage >= BIG_SPLASH_DAMAGE)
	_threat_time = best_t
	return best


## A nearby spot hidden from `enemy` that we can walk to in a straight line; null if none.
func _find_cover(player: Player, enemy: Vector2) -> Variant:
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var pos: Vector2 = player.global_position
	var bounds: Rect2 = arena.play_area() if arena != null else Rect2(pos - Vector2(2000, 2000), Vector2(4000, 4000))
	var phase: float = rng.randf() * TAU / COVER_DIRS
	for d: float in COVER_DISTANCES:
		var best: Variant = null
		var best_score: float = INF
		for i: int in COVER_DIRS:
			var p: Vector2 = pos + Vector2.from_angle(phase + TAU * i / COVER_DIRS) * d
			if not bounds.has_point(p) or p.distance_to(enemy) < COVER_MIN_ENEMY_DIST:
				continue
			if AutoAim.has_line_of_sight(space, _query, p, enemy):
				continue
			if not AutoAim.has_line_of_sight(space, _query, pos, p):
				continue
			# Away from the enemy is better than past it.
			var score: float = p.distance_to(enemy) * -1.0
			if score < best_score:
				best_score = score
				best = p
		if best != null:
			return best
	return null


## Where to shoot: the best visible enemy (weak and close preferred, the current target sticks), or one of its shadow
## clones (bots fall for them). Enemies hidden in their smoke are ignored. Null if nothing is in sight. Sets `_target`.
func _nearest_visible_enemy(player: Player) -> Variant:
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var best: Variant = null
	var best_score: float = Constants.BOT_SIGHT_RANGE * Constants.BOT_SIGHT_RANGE
	var best_player: Player = null
	for p: Player in arena.players:
		if p == player or p.dead:
			continue
		var vit: float = float(p.stats.hp + p.stats.armor) / float(p.stats.max_hp + p.stats.max_armor)
		var w: float = 1.0 - TARGET_WEAK_BIAS * (1.0 - vit)
		if p == _prev_target_ref:
			w *= TARGET_STICK
		var spots: PackedVector2Array = p.clone_points()
		if not p.is_hidden():
			spots.append(p.global_position)
		for at: Vector2 in spots:
			var d: float = player.global_position.distance_squared_to(at)
			if d <= 0.0 or d >= Constants.BOT_SIGHT_RANGE * Constants.BOT_SIGHT_RANGE:
				continue
			var score: float = d * w * w
			if score >= best_score:
				continue
			var spot: Variant = AutoAim.visible_point(space, _query, player.global_position, at)
			if spot != null:
				best = spot
				best_score = score
				best_player = p
	_remember_target(best_player)
	return best


var _prev_target_ref: Player


func _remember_target(p: Player) -> void:
	_target = p
	_prev_target_ref = p


## Pick a random kit special (see `rotates_kit`) into slot 1 when it is ready again.
func _rotate_kit(player: Player) -> void:
	var slot: CharacterSkill = player.skills[1]
	var ready: bool = slot.is_ready()
	if ready and not _kit_ready and rotates_kit and slot.data.kind >= SkillData.Kind.STEP:
		var kit: Array[SkillData] = []
		for sd: SkillData in SkillCatalog.shared().specials_for(player.character):
			if sd.kind >= SkillData.Kind.STEP and sd.tags.has(player.character.id):
				kit.append(sd)
		if kit.size() > 1:
			player.set_skill(1, kit[rng.randi() % kit.size()])
	_kit_ready = ready
