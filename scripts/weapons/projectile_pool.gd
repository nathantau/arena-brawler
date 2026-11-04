class_name ProjectilePool
extends Node2D
## Every weapon's effect in the world, simulated without per-projectile nodes:
## - PROJECTILE: fixed-size pool; each step is a raycast from the previous to the next
##   position. Optional splash (explodes on impact / end of life) and wall bounces.
## - BEAM: instant raycast at fire time.
## - MELEE: arc hit around the wielder; can reflect enemy projectiles inside the arc. With
##   splash it's a slam: one blast at the tip of the reach instead.
## Piercing projectiles damage each player they pass through, up to WeaponData.pierce.
## A Blossom Ward (ShieldWall.is_ward) catches enemy projectiles without their blast: at its edge, or on its
## owner if a shot got inside it. Beams pass it.
##
## Authoritative pools (offline / server) apply damage. Client pools are cosmetic: they stop
## on walls, shields and players locally but damage only ever comes from the server.
## Each pellet is keyed by (owner_id, shot_seq, pellet) so server hit events can find it;
## `attacker_id` (who gets credit / who it passes through) changes when a sword reflects it.

signal player_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, damage: int, crit: bool, at: Vector2)
## Cosmetic events, emitted on every peer.
signal shot_spawned(owner_id: int, origin: Vector2, facing: Vector2, weapon: WeaponData)
signal beam_drawn(owner_id: int, from: Vector2, to: Vector2, weapon: WeaponData)
## A chain hit jumped from one enemy to the next (cosmetic, every peer).
signal chained(from: Vector2, to: Vector2, color: Color)
## A parry sent a shot back (cosmetic, every peer).
signal deflected(at: Vector2, color: Color)
signal swung(origin: Vector2, facing: Vector2, weapon: WeaponData)
## `art` false: a skill draws its own (Eruption's pillar of fire); keep just the sound, sparks and shake.
signal exploded(at: Vector2, radius: float, color: Color, slam: bool, art: bool)
## A splash weapon with its own burst strip (WeaponData.burst_art): `art_radius` = art px to the splash edge.
signal burst_shown(at: Vector2, radius: float, art: Texture2D, art_radius: float)

## A fun weapon's shot ended (hit, wall or end of range): play its impact strip / floor decal (cosmetic, every peer).
signal fx_spawned(at: Vector2, weapon: WeaponData, seed: int)

## Slam lines reach this far past their end so a crate that stopped them is struck.
const LINE_END_REACH: float = 6.0
const TRAIL_TIME: float = 0.025
const TRAIL_WIDTH_SCALE: float = 1.2
const TRAIL_ALPHA: float = 0.45
const IMPACT_POOL_SIZE: int = 48
const IMPACT_TIME: float = 0.12
const IMPACT_RADIUS_SCALE: float = 3.0
const CRIT_RADIUS_SCALE: float = 1.4
## Bullet sprites alternate their 2 frames this fast (fused grenades twice as fast); crits are drawn
## bigger, flash every other frame and shed gold sparkles.
const SPRITE_FPS: float = 12.0
const CRIT_SPRITE_SCALE: float = 1.35
const CRIT_FLASH: Color = Color(1.8, 1.8, 1.8)
## A parried shot is drawn cool and bright.
const REFLECT_TINT: Color = Color(0.55, 0.95, 1.6)
const CRIT_SPARKLE_COLOR: Color = Color(1.0, 0.85, 0.35)
## Trail: this many art-pixel squares behind the bullet, shrinking.
const TRAIL_DOTS: int = 3
const IMPACT_SPARK_DIRS: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
const SPLASH_QUERY_MAX: int = 32
## Bouncing projectiles pulse so they read as "about to blow".
const FUSE_PULSE_SPEED: float = 18.0
const FUSE_PULSE_SCALE: float = 0.2
## Fun weapons: sparkle colours of a rainbow trail, a bee's wing-beat speed-up, the lob shadow.
const RAINBOW: Array[Color] = [Color8(217, 71, 75), Color8(245, 210, 86), Color8(126, 224, 207), Color8(226, 110, 160),
	Color8(172, 210, 104), Color8(240, 138, 62)]
const FLAP_FPS_SCALE: float = 2.5
const STRING_STEP: float = 1.0
const STRING_COLORS: Array[Color] = [Color8(244, 240, 226), Color8(244, 240, 226), Color8(170, 176, 190)]
const LOB_SHADOW: Color = Color(0, 0, 0, 0.28)
const LOB_SHADOW_SIZE: Vector2 = Vector2(0.9, 0.4)
const HIT_MASK: int = Constants.LAYER_WALLS | Constants.LAYER_PLAYERS | Constants.LAYER_SHIELDS | Constants.LAYER_CRATES


class Slot:
	var active: bool = false
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var owner_id: int = 0
	var shot_seq: int = 0
	var pellet: int = 0
	var attacker_id: int = 0
	var damage: int = 0
	var crit: bool = false
	var knockback: float = 0.0
	var radius: float = 0.0
	var color: Color = Color.WHITE
	var splash_radius: float = 0.0
	var splash_edge: float = 1.0
	var burst_art: Texture2D
	var burst_art_radius: float = 0.0
	var bounces_left: int = 0
	var bounce_damping: float = 1.0
	var drag: float = 0.0
	var homing: float = 0.0
	var pierce_left: int = 0
	var snare_time: float = 0.0
	var snare_factor: float = 1.0
	## Clients let piercing pellets fly on after server hit events (they stop where they stop locally).
	var piercing: bool = false
	var sprite: Texture2D
	## Weapon hooks (WeaponData "Hooks"), copied at spawn.
	var chain_range: float = 0.0
	var chain_scale: float = 0.0
	var boomerang: bool = false
	var returning: bool = false
	var hit_ids: Array[int] = []
	var base_damage: int = 0
	var bounce_gain: float = 0.0
	var bounced: int = 0
	var burn_time: float = 0.0
	var burn_damage: int = 0
	var burn_interval: float = 0.0
	var backstab: float = 0.0
	var split_count: int = 0
	var split_scale: float = 0.0
	## A player this shot sails past (a split shard never re-hits the player its parent burst on).
	var skip_id: int = -1
	## Parried: drawn in the parrier's colour so it reads as theirs now.
	var reflected: bool = false
	## The weapon, for the fun hooks (wobble, growth, soak, trap, sting, fx). Null for shards and blasts.
	var weapon: WeaponData
	var age: float = 0.0
	var total_life: float = 1.0
	var travelled: float = 0.0
	var base_radius: float = 0.0
	## Bee hover: time left circling the target (< 0 = not started), and whether it already stung / circled.
	var hover_left: float = -1.0
	var hovered: bool = false
	## Shards with a strip show this fixed frame (-1 = flicker through the frames).
	var frame_lock: int = -1


class Impact:
	var time_left: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var color: Color = Color.WHITE


var authoritative: bool = true
## Players homing projectiles steer toward (the Arena hands over its list).
var targets: Array[Player] = []

var _slots: Array[Slot] = []
var _impacts: Array[Impact] = []
var _cursor: int = 0
var _impact_cursor: int = 0
var _query := PhysicsRayQueryParameters2D.new()
var _los_query := PhysicsRayQueryParameters2D.new()
var _area_query := PhysicsShapeQueryParameters2D.new()
var _area_shape := CircleShape2D.new()
var _line_query := PhysicsShapeQueryParameters2D.new()
var _line_shape := RectangleShape2D.new()
var _empty_exclude: Array[RID] = []
var _shot_rng := RandomNumberGenerator.new()
var _time: float = 0.0
## Consecutive-shot streaks (WeaponData.crit_every): owner id -> Vector2(count, time of the last shot). Every peer counts.
var _streaks: Dictionary = {}
## Beam ramps (WeaponData.beam_ramp_time), authority only: owner id -> Vector3(target id, ramp start, last hit time).
var _ramps: Dictionary = {}


## Rarity whose damage multiplier the shot being spawned right now uses (set by fire_shot).
var _shot_rarity: int = 0
var _shot_salt: int = 0  # owner + seq of that shot: seeds the rarity bonus's rounding


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i: int in Constants.PROJECTILE_POOL_SIZE:
		_slots.append(Slot.new())
	for i: int in IMPACT_POOL_SIZE:
		_impacts.append(Impact.new())
	_query.collision_mask = HIT_MASK
	_query.hit_from_inside = false
	_area_query.shape = _area_shape
	_line_query.shape = _line_shape
	_line_query.collision_mask = Constants.LAYER_CRATES


## Fires one shot. Fully determined by its arguments, so any peer that receives
## (owner_id, seq, origin, facing, weapon) reproduces the identical volley.
## `rarity` = the SkillData.rarity of the ability that fired a skill weapon (-1 = the weapon's own rarity).
func fire_shot(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon: WeaponData, match_seed: int,
		rarity: int = -1) -> void:
	_shot_rarity = weapon.rarity if rarity < 0 else rarity
	_shot_salt = owner_id * 1000003 + seq
	if weapon.blast:
		_shot_rng.seed = CombatRules.shot_seed(match_seed, owner_id, seq)
		if weapon.destroys_shots:
			_destroy_shots(owner_id, origin, weapon.splash_radius)
		_blast(owner_id, seq, origin, weapon)
		return
	shot_spawned.emit(owner_id, origin, facing, weapon)
	if weapon.kind == WeaponData.Kind.MELEE:
		_shot_rng.seed = CombatRules.shot_seed(match_seed, owner_id, seq)
		_swing(owner_id, seq, origin, facing.normalized(), weapon)
		return
	_volley(owner_id, seq, origin, facing, weapon, match_seed)


## Remove a pellet the server says hit someone (client side). Splash pellets still pop.
func kill_shot(owner_id: int, shot_seq: int, pellet: int, at: Vector2) -> void:
	for s: Slot in _slots:
		if s.active and s.owner_id == owner_id and s.shot_seq == shot_seq and s.pellet == pellet:
			if not s.piercing:
				_stop(s, at)
			return


func clear() -> void:
	for s: Slot in _slots:
		s.active = false
	_streaks.clear()
	_ramps.clear()


## True while a tethered shot (Yo-Yo) of `owner` is in flight: its thrower's hand holds only the empty loop.
## Read from the slots every peer simulates, so no synced state.
func tether_out(owner: int) -> bool:
	for s: Slot in _slots:
		if s.active and s.owner_id == owner and s.weapon != null and s.weapon.tether:
			return true
	return false


## Read-only view for tests / debugging.
func debug_slots() -> Array[Slot]:
	return _slots


func active_count() -> int:
	var n: int = 0
	for s: Slot in _slots:
		if s.active:
			n += 1
	return n


func _volley(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon: WeaponData,
		match_seed: int) -> void:
	_shot_rng.seed = CombatRules.shot_seed(match_seed, owner_id, seq)
	var crit: bool = CombatRules.roll_crit(weapon, _shot_rng)
	if weapon.crit_every > 0 and _streak_hit(owner_id, weapon.crit_every):
		crit = true
	var damage: int = CombatRules.damage_for(weapon, crit, _shot_rarity, _shot_salt)
	var dirs: PackedVector2Array = CombatRules.shot_directions(facing, weapon, _shot_rng)
	for i: int in dirs.size():
		if weapon.kind == WeaponData.Kind.BEAM:
			_beam(owner_id, seq, i, origin, dirs[i], weapon, damage, crit)
		else:
			_spawn_pellet(owner_id, seq, i, origin, weapon.muzzle_distance(), dirs[i], weapon, damage, crit)


## Counts one more consecutive shot by `owner_id` (a streak resets after STREAK_RESET s idle); true on every `every`th.
func _streak_hit(owner_id: int, every: int) -> bool:
	var prev: Vector2 = _streaks.get(owner_id, Vector2.ZERO)
	var n: int = int(prev.x) + 1 if _time - prev.y <= Constants.STREAK_RESET else 1
	_streaks[owner_id] = Vector2(n, _time)
	return n % every == 0


## Spawns from `origin` (the shooter's hand) at distance `muzzle_dist`. If a wall sits between
## the shooter and the muzzle the shot pops on the wall instead of tunnelling through.
func _spawn_pellet(owner_id: int, seq: int, pellet: int, origin: Vector2, muzzle_dist: float, dir: Vector2,
		weapon: WeaponData, damage: int, crit: bool) -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var muzzle: Vector2 = origin + dir * muzzle_dist
	var slot: Slot = _next_free_slot()
	slot.active = true
	slot.pos = muzzle
	slot.vel = dir * weapon.projectile_speed
	slot.life = weapon.projectile_range / weapon.projectile_speed
	slot.owner_id = owner_id
	slot.shot_seq = seq
	slot.pellet = pellet
	slot.attacker_id = owner_id
	slot.damage = damage
	slot.crit = crit
	slot.knockback = weapon.knockback
	slot.radius = weapon.projectile_radius * (CRIT_RADIUS_SCALE if crit else 1.0)
	slot.color = weapon.color
	slot.sprite = weapon.projectile_sprite
	slot.splash_radius = weapon.splash_radius
	slot.splash_edge = weapon.splash_edge_scale
	slot.burst_art = weapon.burst_art
	slot.burst_art_radius = weapon.burst_art_radius
	slot.bounces_left = weapon.bounces
	slot.bounce_damping = weapon.bounce_damping
	slot.drag = weapon.drag
	slot.homing = weapon.homing
	slot.pierce_left = weapon.pierce
	slot.piercing = weapon.pierce > 0
	slot.snare_time = weapon.snare_time
	slot.snare_factor = weapon.snare_factor
	slot.chain_range = weapon.chain_range
	slot.chain_scale = weapon.chain_scale
	slot.boomerang = weapon.boomerang
	slot.returning = false
	slot.hit_ids.clear()
	slot.piercing = slot.piercing or weapon.boomerang
	slot.base_damage = damage
	slot.bounce_gain = weapon.bounce_damage_gain
	slot.bounced = 0
	slot.burn_time = weapon.burn_time
	slot.burn_damage = CombatRules.scaled(weapon.burn_damage, _shot_rarity, _shot_salt + 1)
	slot.burn_interval = weapon.burn_interval
	slot.backstab = weapon.backstab_bonus
	slot.split_count = weapon.split_count
	slot.split_scale = weapon.split_scale
	slot.skip_id = -1
	slot.reflected = false
	slot.weapon = weapon if _is_fun(weapon) else null
	slot.age = 0.0
	slot.total_life = slot.life
	slot.travelled = 0.0
	slot.base_radius = slot.radius
	slot.hover_left = -1.0
	slot.hovered = false
	slot.frame_lock = -1
	if not AutoAim.has_line_of_sight(space, _los_query, origin, muzzle):
		_stop(slot, muzzle)


## Whether a weapon uses any of the "Fun" hooks (so its slots keep a weapon reference).
static func _is_fun(w: WeaponData) -> bool:
	return w.lob_height > 0.0 or w.curve_deg != 0.0 or w.wobble_amp > 0.0 or w.grow_max > 0.0 or w.soak_time > 0.0 \
		or w.trap_time > 0.0 or w.sting_delay > 0.0 or w.rainbow_trail or w.impact_art != null or w.splat_art != null or w.tether


func _beam(owner_id: int, seq: int, pellet: int, origin: Vector2, dir: Vector2, weapon: WeaponData,
		damage: int, crit: bool) -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = origin + dir * weapon.muzzle_distance()
	if not AutoAim.has_line_of_sight(space, _los_query, origin, from):
		beam_drawn.emit(owner_id, origin, from, weapon)
		return
	var to: Vector2 = from + dir * weapon.projectile_range
	_query.from = from
	_query.to = to
	_query.exclude = _empty_exclude
	var end: Vector2 = to
	for attempt: int in Constants.PROJECTILE_MAX_PASS_THROUGH:
		var hit: Dictionary = space.intersect_ray(_query)
		if hit.is_empty():
			break
		var collider: Object = hit.collider
		if _passes_through(collider, owner_id) or (collider is ShieldWall and (collider as ShieldWall).is_ward):
			_exclude(hit.rid)  # wards only stop projectiles
			continue
		end = hit.position
		if authoritative:
			var target := collider as Player
			if target != null:
				if weapon.beam_ramp_time > 0.0:
					damage = roundi(damage * _beam_ramp(owner_id, target.player_id, weapon))
				_damage_player(target, owner_id, seq, pellet, damage, crit, dir * weapon.knockback, end)
			elif collider is Crate:
				(collider as Crate).take_damage(damage)
		break
	_add_impact(end, weapon.projectile_radius, weapon.color)
	beam_drawn.emit(owner_id, from, end, weapon)


## Damage multiplier of a ramping beam on `target_id`: 1 on a fresh target, up to beam_ramp_max after beam_ramp_time of
## unbroken hits, back to 1 when the target changes or the beam lets go for BEAM_RAMP_GRACE.
func _beam_ramp(owner_id: int, target_id: int, weapon: WeaponData) -> float:
	var r: Vector3 = _ramps.get(owner_id, Vector3(-1.0, 0.0, -INF))
	if int(r.x) != target_id or _time - r.z > Constants.BEAM_RAMP_GRACE:
		r = Vector3(target_id, _time, _time)
	r.z = _time
	_ramps[owner_id] = r
	return lerpf(1.0, weapon.beam_ramp_max, clampf((_time - r.y) / weapon.beam_ramp_time, 0.0, 1.0))


func _swing(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon: WeaponData) -> void:
	swung.emit(origin, facing, weapon)
	var reach: float = weapon.melee_range + Constants.PLAYER_RADIUS
	if weapon.reflects:
		for s: Slot in _slots:
			if s.active and _is_enemy_shot(s, owner_id) and s.pos.distance_to(origin) <= reach + s.radius \
					and CombatRules.in_arc(origin, facing, s.pos, weapon.melee_arc_deg):
				s.vel = _toward_shooter(s, origin, facing) * s.vel.length()
				s.color = weapon.color  # theirs became yours
				s.reflected = true
				deflected.emit(s.pos, weapon.color)
				s.attacker_id = owner_id
				s.life = maxf(s.life, Constants.REFLECT_MIN_LIFE)
	if weapon.splash_radius > 0.0:
		_slam(owner_id, seq, origin, facing, weapon)
		return
	if not authoritative:
		return
	var crit: bool = CombatRules.roll_crit(weapon, _shot_rng)
	var damage: int = CombatRules.damage_for(weapon, crit, _shot_rarity, _shot_salt)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for result: Dictionary in _overlaps(space, origin, reach, Constants.LAYER_PLAYERS | Constants.LAYER_CRATES):
		var collider: Object = result.collider
		var node := collider as Node2D
		if node == null or not CombatRules.in_arc(origin, facing, node.global_position, weapon.melee_arc_deg):
			continue
		var target := collider as Player
		if target != null:
			if _ally(owner_id, target) or not target.can_be_hit() \
					or not AutoAim.has_line_of_sight(space, _los_query, origin, target.global_position):
				continue
			var push: Vector2 = (target.global_position - origin).normalized() * weapon.knockback
			_damage_player(target, owner_id, seq, 0, damage, crit, push, target.global_position)
		elif collider is Crate:
			(collider as Crate).take_damage(damage)


## A parried shot goes back at whoever fired it (else the way the parrier faces).
func _toward_shooter(s: Slot, origin: Vector2, facing: Vector2) -> Vector2:
	for p: Player in targets:
		if p.player_id == s.attacker_id and not p.dead:
			var to: Vector2 = p.global_position - origin
			if to.length_squared() > 1.0:
				return to.normalized()
	return facing


## Hammer-style melee: a blast centred at the tip of the reach (pulled in to the wielder if a
## wall is in the way, so it never lands on the far side of a wall).
## Staff Whirl: enemy projectiles within `radius` of `origin` fly back outward and become `owner_id`'s (every
## peer). `damage` > 0 (authoritative only): players and crates in reach take it, pushed away from `origin`.
func whirl(owner_id: int, seq: int, origin: Vector2, radius: float, damage: int, knockback: float,
		slow_time: float = 0.0, slow_factor: float = 1.0) -> void:
	for s: Slot in _slots:
		if s.active and _is_enemy_shot(s, owner_id) and s.pos.distance_to(origin) <= radius + s.radius:
			s.vel = (s.pos - origin).normalized() * s.vel.length()
			s.attacker_id = owner_id
			s.life = maxf(s.life, Constants.REFLECT_MIN_LIFE)
	if not authoritative or damage <= 0:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for result: Dictionary in _overlaps(space, origin, radius, Constants.LAYER_PLAYERS | Constants.LAYER_CRATES):
		var target := result.collider as Player
		if target != null:
			if _ally(owner_id, target) or not target.can_be_hit() \
					or not AutoAim.has_line_of_sight(space, _los_query, origin, target.global_position):
				continue
			var push: Vector2 = (target.global_position - origin).normalized() * knockback
			_damage_player(target, owner_id, seq, 0, damage, false, push, target.global_position, -1, slow_time, slow_factor)
		elif result.collider is Crate:
			(result.collider as Crate).take_damage(damage)


## Verdant Bloom: heals `owner_id` (and only them) by `amount` if they stand within `radius` of the patch at `at`
## (their feet). Authoritative only. World Tree (`allies`, `damage`, `slow_time`): teammates in range are healed too, and
## enemies in range take `damage` (keyed `seq`) and are rooted (x`slow_factor` for `slow_time`).
func bloom(owner_id: int, at: Vector2, radius: float, amount: int, allies: bool = false, seq: int = 0, damage: int = 0,
		slow_time: float = 0.0, slow_factor: float = 1.0) -> void:
	if not authoritative:
		return
	for target: Player in targets:
		if target.dead or (target.global_position + Vector2(0.0, Player.FOOT_RING_Y)).distance_to(at) > radius:
			continue
		if target.player_id == owner_id or (allies and _ally(owner_id, target)):
			target.stats.heal(amount)
		elif not _ally(owner_id, target) and (damage > 0 or slow_time > 0.0) and target.can_be_hit():
			if damage > 0:
				_damage_player(target, owner_id, seq, 0, damage, false, Vector2.ZERO, target.global_position, -1, slow_time, slow_factor)
			else:
				target.stats.apply_slow(slow_time, slow_factor)


## Leaf Gust: enemy projectiles inside the cone (apex `origin`, along `dir`, `reach` long, `half_angle` rad each side)
## are destroyed on every peer; with `damage` > 0 (authoritative only) enemies in it with line of sight take it and are
## thrown `knockback` away from the apex (a crate in it takes the damage too).
func gust(owner_id: int, seq: int, origin: Vector2, dir: Vector2, reach: float, half_angle: float, damage: int,
		knockback: float) -> void:
	for s: Slot in _slots:
		if s.active and _is_enemy_shot(s, owner_id) and _in_cone(s.pos, origin, dir, reach + s.radius, half_angle):
			s.active = false
			_add_impact(s.pos, s.radius, s.color)
	if not authoritative or damage <= 0:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for target: Player in targets:
		if _ally(owner_id, target) or not target.can_be_hit() \
				or not _in_cone(target.global_position, origin, dir, reach, half_angle) \
				or not AutoAim.has_line_of_sight(space, _los_query, origin, target.global_position):
			continue
		var push: Vector2 = (target.global_position - origin).normalized() * knockback
		_damage_player(target, owner_id, seq, 0, damage, false, push, target.global_position)


static func _in_cone(at: Vector2, origin: Vector2, dir: Vector2, reach: float, half_angle: float) -> bool:
	var to: Vector2 = at - origin
	var dist: float = to.length()
	if dist > reach:
		return false
	return dist < 1.0 or absf(dir.angle_to(to)) <= half_angle


## Enemy projectiles within `radius` of `origin` vanish (every peer: the cosmetic copies go too).
func _destroy_shots(owner_id: int, origin: Vector2, radius: float) -> void:
	for s: Slot in _slots:
		if s.active and _is_enemy_shot(s, owner_id) and s.pos.distance_to(origin) <= radius + s.radius:
			s.active = false
			_add_impact(s.pos, s.radius, s.color)


## Whether `s` is an enemy of `owner_id` (the one place to widen for teams: treat teammates' shots as friendly).
func _is_enemy_shot(s: Slot, owner_id: int) -> bool:
	return not _same_team(s.attacker_id, owner_id)


func _slam(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon: WeaponData) -> void:
	var at: Vector2 = origin + facing * weapon.melee_range
	if not AutoAim.has_line_of_sight(get_world_2d().direct_space_state, _los_query, origin, at):
		at = origin
	_blast(owner_id, seq, at, weapon, true)


## One splash blast at `at` (keyed (owner, seq, 0) like any pellet); `_shot_rng` is already seeded for the shot.
func _blast(owner_id: int, seq: int, at: Vector2, weapon: WeaponData, slam: bool = false) -> void:
	var blast := Slot.new()
	blast.owner_id = owner_id
	blast.attacker_id = owner_id
	blast.shot_seq = seq
	blast.crit = CombatRules.roll_crit(weapon, _shot_rng)
	blast.damage = CombatRules.damage_for(weapon, blast.crit, _shot_rarity, _shot_salt)
	blast.knockback = weapon.knockback
	blast.snare_time = weapon.snare_time
	blast.snare_factor = weapon.snare_factor
	blast.color = weapon.color
	blast.splash_radius = weapon.splash_radius
	blast.splash_edge = weapon.splash_edge_scale
	blast.burst_art = weapon.burst_art
	blast.burst_art_radius = weapon.burst_art_radius
	_explode(blast, at, slam, not weapon.blast)


func _next_free_slot() -> Slot:
	var size: int = _slots.size()
	for i: int in size:
		var idx: int = (_cursor + i) % size
		if not _slots[idx].active:
			_cursor = (idx + 1) % size
			return _slots[idx]
	# Pool exhausted: recycle the slot at the cursor (roughly the oldest).
	var recycled: Slot = _slots[_cursor]
	_cursor = (_cursor + 1) % size
	return recycled


func _physics_process(delta: float) -> void:
	_time += delta
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for s: Slot in _slots:
		if s.active:
			_step_slot(s, delta, space)
	for imp: Impact in _impacts:
		if imp.time_left > 0.0:
			imp.time_left -= delta
	queue_redraw()


func _step_slot(s: Slot, delta: float, space: PhysicsDirectSpaceState2D) -> void:
	if s.drag > 0.0:
		s.vel *= exp(-s.drag * delta)
	if s.weapon != null:
		_step_fun(s, delta)
	if s.boomerang and s.returning:
		if not _steer_home(s):
			s.active = false
			return
	elif s.homing > 0.0 and s.hover_left <= 0.0:  # (a bee circling its target steers itself)
		_steer(s, delta)
	var to: Vector2 = s.pos + s.vel * delta
	_query.from = s.pos
	_query.to = to
	_query.exclude = _empty_exclude
	for attempt: int in Constants.PROJECTILE_MAX_PASS_THROUGH:
		var hit: Dictionary = space.intersect_ray(_query)
		if hit.is_empty():
			break
		var collider: Object = hit.collider
		var target := collider as Player
		if target != null and not _ally(s.attacker_id, target) and target.player_id != s.skip_id \
				and target.can_be_hit():
			if s.boomerang and s.hit_ids.has(target.player_id):  # already hit on this pass
				_exclude(hit.rid)
				continue
			if target.ward() != null:
				_catch(s, hit.position, target.ward())
				return
			var bubble: ShieldWall = target.bubble()
			if bubble != null:  # a shot that got inside the bubble (fired from within, or it grew onto the shot)
				_hit_bubble(s, hit.position, (s.pos - target.global_position).normalized(), bubble)
				return
			if s.splash_radius > 0.0:
				s.skip_id = target.player_id
				_stop(s, hit.position)
			else:
				_direct_hit(s, target, hit.position)
				if s.boomerang:
					s.hit_ids.append(target.player_id)
					_add_impact(hit.position, s.radius, s.color)
					_exclude(hit.rid)
					continue
				if s.pierce_left > 0:
					s.pierce_left -= 1
					_add_impact(hit.position, s.radius, s.color)
					_exclude(hit.rid)
					continue
				_finish(s, hit.position)
			return
		if target != null or _passes_through(collider, s.attacker_id):
			_exclude(hit.rid)
			continue
		if collider is ShieldWall and (collider as ShieldWall).is_ward:
			_catch(s, hit.position, collider)
			return
		if collider is ShieldWall and (collider as ShieldWall).reflects:
			_hit_bubble(s, hit.position, hit.normal, collider as ShieldWall)
			return
		if s.boomerang and not s.returning and not collider is ShieldWall:  # a wall sends it home
			s.pos = hit.position + hit.normal * Constants.BOUNCE_EPSILON
			_turn_back(s)
			return
		if s.bounces_left > 0 and not collider is ShieldWall:
			if collider is Crate and authoritative and s.splash_radius <= 0.0:
				(collider as Crate).take_damage(s.damage)  # ricochets still chip crates
			_bounce(s, hit.position, hit.normal, delta)
			return
		if collider is Crate and authoritative and s.splash_radius <= 0.0:
			(collider as Crate).take_damage(s.damage)
		if s.split_count > 0:  # shards burst back off the wall
			s.vel = s.vel.bounce(hit.normal)
		_stop(s, hit.position)
		return
	s.pos = to
	s.life -= delta
	if s.life <= 0.0:
		if s.boomerang and not s.returning:
			_turn_back(s)
		elif s.splash_radius > 0.0:
			_explode(s, s.pos)
		else:
			_finish(s, s.pos, false)


## The "Fun" hooks of one step: arc, wobble, growth, and a bee circling its target. All a pure function of the slot's own state.
func _step_fun(s: Slot, delta: float) -> void:
	var w: WeaponData = s.weapon
	s.age += delta
	s.travelled += s.vel.length() * delta
	if w.curve_deg != 0.0:
		s.vel = s.vel.rotated(deg_to_rad(w.curve_deg) * delta)
	if w.wobble_amp > 0.0:
		var phase: float = float(posmod(s.shot_seq * 7 + s.pellet * 13, 64)) * 0.37
		s.vel = s.vel.rotated(w.wobble_amp * delta * sin(s.age * TAU * w.wobble_hz + phase))
	if w.grow_max > 0.0:
		var k: float = clampf(s.travelled / w.projectile_range, 0.0, 1.0)
		var grow: float = lerpf(1.0, w.grow_max, k)
		s.damage = maxi(1, roundi(s.base_damage * grow))
		s.radius = s.base_radius * grow
	if w.sting_delay > 0.0:
		_step_bee(s, delta)


## Hive Gun: a bee close to its target buzzes round it for `sting_delay` (passing through it), then dives to sting.
func _step_bee(s: Slot, delta: float) -> void:
	if s.hovered:
		return
	if s.hover_left < 0.0:
		var best: Player = _nearest_enemy(s)
		if best != null and best.global_position.distance_to(s.pos) <= Constants.BEE_ORBIT_RADIUS:
			s.hover_left = s.weapon.sting_delay
			s.skip_id = best.player_id
			s.life += s.weapon.sting_delay
		return
	s.hover_left -= delta
	var side: float = 1.0 if s.pellet % 2 == 0 else -1.0
	s.vel = s.vel.rotated(Constants.BEE_ORBIT_RATE * side * delta)
	if s.hover_left <= 0.0:  # done buzzing: dive straight at the target
		s.hovered = true
		s.skip_id = -1
		var prey: Player = _nearest_enemy(s)
		if prey != null:
			s.vel = (prey.global_position - s.pos).normalized() * s.vel.length() * Constants.BEE_DIVE_SCALE


func _nearest_enemy(s: Slot) -> Player:
	var best: Player = null
	var best_d: float = INF
	for p: Player in targets:
		if _ally(s.attacker_id, p) or not p.can_be_hit() or p.is_hidden():
			continue
		var d: float = s.pos.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## A boomerang reached the end of its outward flight (or a wall): it comes back, free to hit everyone again.
func _turn_back(s: Slot) -> void:
	s.returning = true
	s.hit_ids.clear()
	s.life = Constants.BOOMERANG_RETURN_LIFE


## Points a returning boomerang at its thrower; false once it is caught (or the thrower is gone).
func _steer_home(s: Slot) -> bool:
	for p: Player in targets:
		if p.player_id != s.owner_id:
			continue
		if p.dead:
			return false
		var to: Vector2 = p.global_position - s.pos
		if to.length() <= Constants.PLAYER_RADIUS + s.radius:
			return false
		s.vel = to.normalized() * s.vel.length()
		return true
	return false


## The direct hit of a non-splash shot: backstabs count as crits, burns ignite, chains jump on.
func _direct_hit(s: Slot, target: Player, at: Vector2) -> void:
	var damage: int = s.damage
	var crit: bool = s.crit
	if s.backstab > 0.0 and absf(target.facing.angle_to(s.vel)) < deg_to_rad(Constants.BACKSTAB_ANGLE_DEG):
		damage = roundi(damage * (1.0 + s.backstab))
		crit = true
	if authoritative:
		_damage_player(target, s.attacker_id, s.shot_seq, s.pellet, damage, crit, s.vel.normalized() * s.knockback, at,
			s.owner_id, s.snare_time, s.snare_factor, s)
	if s.chain_range > 0.0:
		_chain(s, target, damage)


## Lightning jumps from `from` to the nearest other enemy in sight within chain_range for chain_scale x damage.
## `burst_at`: after a splash burst, skip foes the burst itself already hit (inside its radius with a clear line).
func _chain(s: Slot, from: Player, damage: int, burst: bool = false, burst_at: Vector2 = Vector2.ZERO) -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var best: Player = null
	var best_d: float = s.chain_range * s.chain_range
	for p: Player in targets:
		if p == from or _ally(s.attacker_id, p) or not p.can_be_hit() or p.is_hidden():
			continue
		if burst and _splashed(s, burst_at, p, space):
			continue
		var d: float = from.global_position.distance_squared_to(p.global_position)
		if d < best_d and AutoAim.has_line_of_sight(space, _los_query, from.global_position, p.global_position):
			best_d = d
			best = p
	if best == null:
		return
	chained.emit(from.global_position, best.global_position, s.color)
	if authoritative:
		var dir: Vector2 = (best.global_position - from.global_position).normalized()
		_damage_player(best, s.attacker_id, s.shot_seq, s.pellet, maxi(1, roundi(damage * s.chain_scale)), false,
			dir * s.knockback, best.global_position, s.owner_id)


## Turns toward the nearest enemy that can be hit and isn't hidden in smoke, at most `homing` rad/s.
## shortcut: clients steer toward interpolated (slightly old) positions, so cosmetic petals can curve a little
## differently from the server's; hits still come only from the server.
func _steer(s: Slot, delta: float) -> void:
	var best: Player = null
	var best_d: float = INF
	for p: Player in targets:
		if _ally(s.attacker_id, p) or not p.can_be_hit() or p.is_hidden():
			continue
		var d: float = s.pos.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	if best == null:
		return
	var turn: float = s.vel.angle_to(best.global_position - s.pos)
	s.vel = s.vel.rotated(clampf(turn, -s.homing * delta, s.homing * delta))


## True if `target` is the attacker or on the attacker's team (no friendly fire; team 0 = no team).
func _ally(attacker_id: int, target: Player) -> bool:
	return target.player_id == attacker_id or _same_team(attacker_id, target.player_id)


## Two different player ids on one real team (or the same id).
func _same_team(a_id: int, b_id: int) -> bool:
	if a_id == b_id:
		return true
	var team_a: int = 0
	var team_b: int = 0
	for p: Player in targets:
		if p.player_id == a_id:
			team_a = p.team
		elif p.player_id == b_id:
			team_b = p.team
	return team_a != 0 and team_a == team_b


## Owners pass through their own shield; i-framing / dead players don't block shots.
func _passes_through(collider: Object, attacker_id: int) -> bool:
	var shield := collider as ShieldWall
	if shield != null:
		return _same_team(shield.owner_id, attacker_id)
	var p := collider as Player
	return p != null and (_ally(attacker_id, p) or not p.can_be_hit())


## Re-cast the rest of the segment without this body. Rare path, so the alloc is fine.
func _exclude(rid: RID) -> void:
	var ex: Array[RID] = _query.exclude.duplicate()
	ex.append(rid)
	_query.exclude = ex


func _bounce(s: Slot, at: Vector2, normal: Vector2, delta: float) -> void:
	s.pos = at + normal * Constants.BOUNCE_EPSILON
	s.vel = s.vel.bounce(normal) * s.bounce_damping
	s.bounces_left -= 1
	s.bounced += 1
	if s.bounce_gain > 0.0:  # bank shots hit harder
		s.damage = roundi(s.base_damage * (1.0 + s.bounce_gain * s.bounced))
	s.life -= delta


## End of flight on an obstacle: explode if it has splash, else just pop.
func _stop(s: Slot, at: Vector2) -> void:
	if s.splash_radius > 0.0:
		# Pull the centre back off the surface so the blast's line-of-sight rays start in the open.
		_explode(s, at - s.vel.normalized() * s.radius)
	else:
		_finish(s, at)


## Hit a reflecting barrier: bounces off it and now belongs to the barrier's owner (the pellet key stays).
func _reflect(s: Slot, at: Vector2, normal: Vector2, new_owner: int) -> void:
	s.pos = at + normal * Constants.BOUNCE_EPSILON
	s.vel = s.vel.bounce(normal)
	s.attacker_id = new_owner
	s.life = maxf(s.life, Constants.REFLECT_MIN_LIFE)


## Hit the barrier bubble: reflected back as the owner's, and the authoritative pool spends one of its hits.
func _hit_bubble(s: Slot, at: Vector2, normal: Vector2, bubble: ShieldWall) -> void:
	if bubble.reflects:
		_reflect(s, at, normal, bubble.owner_id)
	else:
		_finish(s, at)
	bubble.absorb(at, authoritative)


## Caught by a Blossom Ward: gone in a petal pop, without its blast.
func _catch(s: Slot, at: Vector2, ward: ShieldWall) -> void:
	s.active = false
	ward.caught.emit(at)


func _finish(s: Slot, at: Vector2, pop: bool = true) -> void:
	s.active = false
	if s.weapon != null and (s.weapon.impact_art != null or s.weapon.splat_art != null):
		if (s.shot_seq + s.pellet) % maxi(1, s.weapon.fx_every) == 0:
			fx_spawned.emit(at, s.weapon, s.shot_seq * 31 + s.pellet)
		if s.weapon.impact_art != null:
			return  # the strip is the pop
	if pop:
		_add_impact(at, s.radius, s.color)


func _explode(s: Slot, at: Vector2, slam: bool = false, art: bool = true) -> void:
	s.active = false
	exploded.emit(at, s.splash_radius, s.color, slam, art and s.burst_art == null)
	if s.burst_art != null:
		burst_shown.emit(at, s.splash_radius, s.burst_art, s.burst_art_radius)
	if s.split_count > 0:
		_spawn_shards(s, at)
	if s.chain_range > 0.0:  # Storm Jar: lightning jumps on from the foe nearest the burst
		var anchor: Player = _splash_anchor(s, at)
		if anchor != null:
			_chain(s, anchor, s.damage, true, at)
	if not authoritative:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for result: Dictionary in _overlaps(space, at, s.splash_radius + Constants.PLAYER_RADIUS,
			Constants.LAYER_PLAYERS | Constants.LAYER_CRATES):
		var collider: Object = result.collider
		var target := collider as Player
		if target != null:
			# No self-damage: rocket-jumping would fight client prediction.
			if _ally(s.attacker_id, target) or not target.can_be_hit() \
					or not AutoAim.has_line_of_sight(space, _los_query, at, target.global_position):
				continue
			var offset: Vector2 = target.global_position - at
			var dist: float = maxf(0.0, offset.length() - Constants.PLAYER_RADIUS)
			var dmg: int = CombatRules.splash_damage(s.damage, dist, s.splash_radius, s.splash_edge)
			var push: Vector2 = (offset.normalized() if offset != Vector2.ZERO else Vector2.UP) * s.knockback
			_damage_player(target, s.attacker_id, s.shot_seq, s.pellet, dmg, s.crit, push, target.global_position,
				s.owner_id, s.snare_time, s.snare_factor)
		elif collider is Crate:
			var crate: Crate = collider
			var cdist: float = maxf(0.0, crate.global_position.distance_to(at) - crate.size * 0.5)
			crate.take_damage(CombatRules.splash_damage(s.damage, cdist, s.splash_radius, s.splash_edge))


## True if a burst at `at` damages `p` (inside the splash with a clear line), mirrors the loop in `_explode`.
func _splashed(s: Slot, at: Vector2, p: Player, space: PhysicsDirectSpaceState2D) -> bool:
	return at.distance_to(p.global_position) <= s.splash_radius + Constants.PLAYER_RADIUS \
		and AutoAim.has_line_of_sight(space, _los_query, at, p.global_position)


## The enemy standing nearest a burst at `at`, inside its splash radius (null if none): where a chain starts.
func _splash_anchor(s: Slot, at: Vector2) -> Player:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var best: Player = null
	var best_d: float = INF
	for p: Player in targets:
		if _ally(s.attacker_id, p) or not p.can_be_hit() or p.is_hidden() or not _splashed(s, at, p, space):
			continue  # (a foe behind a wall takes no splash, so it can't start the chain either)
		var d: float = at.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Seed Sling: the burst throws `split_count` small shards fanning onward (along the shot's velocity).
func _spawn_shards(s: Slot, at: Vector2) -> void:
	var speed: float = s.vel.length()
	if speed <= 0.0:
		return
	var dir: Vector2 = s.vel / speed
	var w: WeaponData = s.weapon
	if w != null and w.split_speed > 0.0:
		speed = w.split_speed
	var ring: bool = w != null and w.split_fan_deg >= 360.0
	var fan: float = deg_to_rad(w.split_fan_deg if w != null and w.split_fan_deg > 0.0 else Constants.SPLIT_FAN_DEG)
	var reach: float = w.split_range if w != null and w.split_range > 0.0 else Constants.SPLIT_RANGE
	for i: int in s.split_count:
		var t: float = 0.0 if s.split_count == 1 else float(i) / float(s.split_count - 1) - 0.5
		var turn: float = TAU * float(i) / float(s.split_count) if ring else t * fan
		var shard: Slot = _next_free_slot()
		shard.active = true
		shard.pos = at
		shard.vel = dir.rotated(turn) * speed
		shard.life = reach / speed
		shard.owner_id = s.owner_id
		shard.shot_seq = s.shot_seq
		shard.pellet = s.pellet + Constants.SPLIT_PELLET_BASE * (i + 1)
		shard.attacker_id = s.attacker_id
		shard.damage = maxi(1, roundi(s.damage * s.split_scale))
		shard.base_damage = shard.damage
		shard.crit = false
		shard.knockback = s.knockback * s.split_scale
		shard.radius = s.radius * Constants.SPLIT_RADIUS_SCALE
		shard.color = s.color
		shard.sprite = w.split_sprite if w != null and w.split_sprite != null else s.sprite
		shard.frame_lock = i if w != null and w.split_sprite != null else -1
		shard.weapon = null
		shard.age = 0.0
		shard.hover_left = -1.0
		shard.hovered = false
		shard.splash_radius = 0.0
		shard.bounces_left = 0
		shard.bounce_damping = 1.0
		shard.drag = 0.0
		shard.homing = 0.0
		shard.pierce_left = 0
		shard.piercing = false
		shard.snare_time = 0.0
		shard.snare_factor = 1.0
		shard.chain_range = 0.0
		shard.boomerang = false
		shard.returning = false
		shard.hit_ids.clear()
		shard.bounce_gain = 0.0
		shard.bounced = 0
		shard.burn_time = 0.0
		shard.backstab = 0.0
		shard.split_count = 0
		shard.skip_id = s.skip_id
		shard.reflected = false


## Storm Cloud: lightning strikes every other player within `radius` of `origin` that is in sight of it, pushed away from it.
func strike(owner_id: int, seq: int, origin: Vector2, radius: float, damage: int, knockback: float) -> void:
	if not authoritative:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for target: Player in targets:
		if _ally(owner_id, target) or not target.can_be_hit() \
				or target.global_position.distance_to(origin) > radius \
				or not AutoAim.has_line_of_sight(space, _los_query, origin, target.global_position):
			continue
		var push: Vector2 = (target.global_position - origin).normalized() * knockback
		_damage_player(target, owner_id, seq, 0, damage, false, push, target.global_position)


## Fire on the floor along from -> to: everyone within `radius` of the line (not the owner) takes `damage`,
## pushed `knockback` away from the line (along it if they stand right on it, sideways).
func burn_segment(owner_id: int, seq: int, from: Vector2, to: Vector2, radius: float, damage: int,
		knockback: float = 0.0) -> void:
	if not authoritative:
		return
	for target: Player in targets:
		if _ally(owner_id, target) or not target.can_be_hit():
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target.global_position, from, to)
		if closest.distance_to(target.global_position) <= radius:
			var away: Vector2 = target.global_position - closest
			if away.length_squared() < 1.0:
				away = (to - from).orthogonal()
			_damage_player(target, owner_id, seq, 0, damage, false, away.normalized() * knockback, target.global_position)


## A slam along from -> to: players as burn_segment, plus crates on the line (the line ends at the wall that stopped it,
## which may be a crate, so it reaches `LINE_END_REACH` past its end).
func line_hit(owner_id: int, seq: int, from: Vector2, to: Vector2, half_width: float, damage: int,
		knockback: float) -> void:
	if not authoritative:
		return
	burn_segment(owner_id, seq, from, to, half_width, damage, knockback)
	var line: Vector2 = to - from
	if line == Vector2.ZERO:
		return
	_line_shape.size = Vector2(line.length() + LINE_END_REACH, half_width * 2.0)
	_line_query.transform = Transform2D(line.angle(), from + line.normalized() * (_line_shape.size.x * 0.5))
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(_line_query, SPLASH_QUERY_MAX):
		if result.collider is Crate:
			(result.collider as Crate).take_damage(damage)


## Damage dealt to an enemy charges the attacker's ultimate (authority only).
func credit_damage(attacker_id: int, target: Player, dealt: int) -> void:
	if not authoritative or dealt <= 0 or _ally(attacker_id, target):
		return
	for p: Player in targets:
		if p.player_id == attacker_id:
			p.add_ult_damage(dealt)
			return


## `key_owner`: the pellet key's owner (differs from the attacker after a reflection).
func _damage_player(target: Player, attacker_id: int, seq: int, pellet: int, damage: int, crit: bool,
		knockback: Vector2, at: Vector2, key_owner: int = -1, snare_time: float = 0.0, snare_factor: float = 1.0,
		shot: Slot = null) -> void:
	var dealt: int = target.take_hit(damage, crit, knockback, attacker_id)
	credit_damage(attacker_id, target, dealt)
	if dealt > 0:
		if snare_time > 0.0:
			target.stats.apply_slow(snare_time, snare_factor)
		if shot != null and shot.burn_time > 0.0 and not target.dead:
			target.stats.ignite(shot.burn_time, shot.burn_damage, shot.burn_interval, attacker_id)
		if shot != null and shot.weapon != null and not target.dead:
			if shot.weapon.soak_time > 0.0:
				target.stats.soak(shot.weapon.soak_time)
			if shot.weapon.trap_time > 0.0:
				target.stats.trap(shot.weapon.trap_time, shot.weapon.trap_cooldown)
		player_hit.emit(key_owner if key_owner >= 0 else attacker_id, seq, pellet, target.player_id, dealt, crit, at)


func _overlaps(space: PhysicsDirectSpaceState2D, at: Vector2, radius: float, mask: int) -> Array[Dictionary]:
	_area_shape.radius = radius
	_area_query.transform = Transform2D(0.0, at)
	_area_query.collision_mask = mask
	return space.intersect_shape(_area_query, SPLASH_QUERY_MAX)


func _add_impact(at: Vector2, radius: float, color: Color) -> void:
	var imp: Impact = _impacts[_impact_cursor]
	_impact_cursor = (_impact_cursor + 1) % _impacts.size()
	imp.time_left = IMPACT_TIME
	imp.pos = at
	imp.radius = radius
	imp.color = color


## Yo-Yo: a pixel string from the thrower's hand to the yo-yo.
func _draw_string(s: Slot, w: WeaponData, px: float) -> void:
	draw_set_transform(Vector2.ZERO)
	for p: Player in targets:
		if p.player_id != s.owner_id:
			continue
		var from: Vector2 = p.shot_origin(w)
		var span: Vector2 = s.pos - from
		var n: int = int(span.length() / (px * STRING_STEP))
		for i: int in n:
			var at: Vector2 = ((from + span * (float(i) / float(maxi(n, 1)))) / px).floor() * px
			draw_rect(Rect2(at, Vector2(px, px)), STRING_COLORS[i % STRING_COLORS.size()])
		return


func _draw() -> void:
	var pulse: float = 1.0 + sin(_time * FUSE_PULSE_SPEED) * FUSE_PULSE_SCALE
	var px: float = Constants.SPRITE_SCALE
	for s: Slot in _slots:
		if not s.active:
			continue
		var fused: bool = s.splash_radius > 0.0 and (s.bounces_left > 0 or s.drag > 0.0)
		if s.sprite == null:
			var trail_color: Color = s.color
			trail_color.a = TRAIL_ALPHA
			draw_line(s.pos - s.vel * TRAIL_TIME, s.pos, trail_color, s.radius * TRAIL_WIDTH_SCALE)
			draw_circle(s.pos, s.radius * (pulse if fused else 1.0), s.color)
			continue
		var fps: float = SPRITE_FPS * (2.0 if fused else 1.0)
		var w: WeaponData = s.weapon
		if w != null and w.sting_delay > 0.0:
			fps *= FLAP_FPS_SCALE
		var tick: int = int(_time * fps) + s.pellet
		var back: Vector2 = -s.vel.normalized()
		var rainbow: bool = w != null and w.rainbow_trail
		var lift: Vector2 = Vector2.ZERO
		if w != null and w.lob_height > 0.0:  # drawn above its ground spot; a shadow stays on the floor
			var u: float = clampf(s.age / maxf(s.total_life, 0.001), 0.0, 1.0)
			lift = Vector2(0.0, -w.lob_height * 4.0 * u * (1.0 - u))
			draw_set_transform(s.pos, 0.0, LOB_SHADOW_SIZE)
			draw_circle(Vector2.ZERO, s.radius * 1.2, LOB_SHADOW)
			draw_set_transform(Vector2.ZERO)
		for i: int in TRAIL_DOTS * (2 if rainbow else 1):  # pixel trail, crits in gold
			var size: float = px * (TRAIL_DOTS - i % TRAIL_DOTS)
			var jitter: Vector2 = Vector2(sin(_time * 40.0 + i * 2.3 + s.pellet), cos(_time * 33.0 + i * 1.7)) * px * 2.0 if rainbow else Vector2.ZERO
			var at: Vector2 = ((s.pos + lift + back * px * 4.0 * (i + 2) * (0.5 if rainbow else 1.0) + jitter) / px).floor() * px
			draw_rect(Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)),
				CRIT_SPARKLE_COLOR if s.crit and (tick + i) % 2 == 0 else RAINBOW[(tick + i + s.pellet) % RAINBOW.size()] if rainbow else s.color)
		var h: float = s.sprite.get_height()
		var frames: int = int(s.sprite.get_width() / h)
		var scale_px: float = px * (CRIT_SPRITE_SCALE if s.crit else 1.0)
		var angle: float = _time * Constants.BOOMERANG_SPIN if s.boomerang else s.vel.angle()
		if s.boomerang:  # bigger, with a faint trail of fading afterimages
			scale_px *= Constants.BOOMERANG_SCALE
			for g: int in Constants.BOOMERANG_GHOSTS:
				draw_set_transform(s.pos - s.vel * Constants.BOOMERANG_GHOST_GAP * (g + 1),
					angle - Constants.BOOMERANG_SPIN * Constants.BOOMERANG_GHOST_GAP * (g + 1), Vector2(scale_px, scale_px))
				draw_texture_rect_region(s.sprite, Rect2(-h * 0.5, -h * 0.5, h, h), Rect2((tick % frames) * h, 0, h, h),
					Color(1, 1, 1, Constants.BOOMERANG_GHOST_ALPHA / (g + 1)))
		if w != null and w.tether:
			_draw_string(s, w, px)
		if w != null and w.grow_max > 0.0 and s.base_radius > 0.0:
			scale_px *= s.radius / s.base_radius
		var frame: int = s.frame_lock if s.frame_lock >= 0 else tick % frames
		draw_set_transform(s.pos + lift, angle, Vector2(scale_px, scale_px))
		draw_texture_rect_region(s.sprite, Rect2(-h * 0.5, -h * 0.5, h, h), Rect2((frame % frames) * h, 0, h, h),
			CRIT_FLASH if s.crit and tick % 2 == 0 else REFLECT_TINT if s.reflected else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	for imp: Impact in _impacts:
		if imp.time_left <= 0.0:
			continue
		# Pixel pop: four sparks flying out diagonally, shrinking.
		var t: float = 1.0 - imp.time_left / IMPACT_TIME
		var size: float = maxf(px, snappedf(imp.radius * (1.0 - t), px))
		var reach: float = imp.radius * lerpf(0.5, IMPACT_RADIUS_SCALE, t)
		for d: Vector2 in IMPACT_SPARK_DIRS:
			var at: Vector2 = ((imp.pos + d * reach * 0.7) / px).floor() * px
			draw_rect(Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)), imp.color)
