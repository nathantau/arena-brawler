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
signal swung(origin: Vector2, facing: Vector2, weapon: WeaponData)
## `art` false: a skill draws its own (Eruption's pillar of fire); keep just the sound, sparks and shake.
signal exploded(at: Vector2, radius: float, color: Color, slam: bool, art: bool)

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
const CRIT_SPARKLE_COLOR: Color = Color(1.0, 0.85, 0.35)
## Trail: this many art-pixel squares behind the bullet, shrinking.
const TRAIL_DOTS: int = 3
const IMPACT_SPARK_DIRS: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
const SPLASH_QUERY_MAX: int = 32
## Bouncing projectiles pulse so they read as "about to blow".
const FUSE_PULSE_SPEED: float = 18.0
const FUSE_PULSE_SCALE: float = 0.2
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
var _empty_exclude: Array[RID] = []
var _shot_rng := RandomNumberGenerator.new()
var _time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i: int in Constants.PROJECTILE_POOL_SIZE:
		_slots.append(Slot.new())
	for i: int in IMPACT_POOL_SIZE:
		_impacts.append(Impact.new())
	_query.collision_mask = HIT_MASK
	_query.hit_from_inside = false
	_area_query.shape = _area_shape


## Fires one shot. Fully determined by its arguments, so any peer that receives
## (owner_id, seq, origin, facing, weapon) reproduces the identical volley.
func fire_shot(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon: WeaponData, match_seed: int) -> void:
	if weapon.blast:
		_shot_rng.seed = CombatRules.shot_seed(match_seed, owner_id, seq)
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
	var damage: int = CombatRules.damage_for(weapon, crit)
	var dirs: PackedVector2Array = CombatRules.shot_directions(facing, weapon, _shot_rng)
	for i: int in dirs.size():
		if weapon.kind == WeaponData.Kind.BEAM:
			_beam(owner_id, seq, i, origin, dirs[i], weapon, damage, crit)
		else:
			_spawn_pellet(owner_id, seq, i, origin, weapon.muzzle_distance(), dirs[i], weapon, damage, crit)


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
	slot.bounces_left = weapon.bounces
	slot.bounce_damping = weapon.bounce_damping
	slot.drag = weapon.drag
	slot.homing = weapon.homing
	slot.pierce_left = weapon.pierce
	slot.piercing = weapon.pierce > 0
	slot.snare_time = weapon.snare_time
	slot.snare_factor = weapon.snare_factor
	if not AutoAim.has_line_of_sight(space, _los_query, origin, muzzle):
		_stop(slot, muzzle)


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
				_damage_player(target, owner_id, seq, pellet, damage, crit, dir * weapon.knockback, end)
			elif collider is Crate:
				(collider as Crate).take_damage(damage)
		break
	_add_impact(end, weapon.projectile_radius, weapon.color)
	beam_drawn.emit(owner_id, from, end, weapon)


func _swing(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon: WeaponData) -> void:
	swung.emit(origin, facing, weapon)
	var reach: float = weapon.melee_range + Constants.PLAYER_RADIUS
	if weapon.reflects:
		for s: Slot in _slots:
			if s.active and s.attacker_id != owner_id and s.pos.distance_to(origin) <= reach + s.radius \
					and CombatRules.in_arc(origin, facing, s.pos, weapon.melee_arc_deg):
				s.vel = facing * s.vel.length()
				s.attacker_id = owner_id
				s.life = maxf(s.life, Constants.REFLECT_MIN_LIFE)
	if weapon.splash_radius > 0.0:
		_slam(owner_id, seq, origin, facing, weapon)
		return
	if not authoritative:
		return
	var crit: bool = CombatRules.roll_crit(weapon, _shot_rng)
	var damage: int = CombatRules.damage_for(weapon, crit)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for result: Dictionary in _overlaps(space, origin, reach, Constants.LAYER_PLAYERS | Constants.LAYER_CRATES):
		var collider: Object = result.collider
		var node := collider as Node2D
		if node == null or not CombatRules.in_arc(origin, facing, node.global_position, weapon.melee_arc_deg):
			continue
		var target := collider as Player
		if target != null:
			if target.player_id == owner_id or not target.can_be_hit() \
					or not AutoAim.has_line_of_sight(space, _los_query, origin, target.global_position):
				continue
			var push: Vector2 = (target.global_position - origin).normalized() * weapon.knockback
			_damage_player(target, owner_id, seq, 0, damage, crit, push, target.global_position)
		elif collider is Crate:
			(collider as Crate).take_damage(damage)


## Hammer-style melee: a blast centred at the tip of the reach (pulled in to the wielder if a
## wall is in the way, so it never lands on the far side of a wall).
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
	blast.damage = CombatRules.damage_for(weapon, blast.crit)
	blast.knockback = weapon.knockback
	blast.color = weapon.color
	blast.splash_radius = weapon.splash_radius
	blast.splash_edge = weapon.splash_edge_scale
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
	if s.homing > 0.0:
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
		if target != null and target.player_id != s.attacker_id and target.can_be_hit():
			if target.ward() != null:
				_catch(s, hit.position, target.ward())
				return
			if s.splash_radius > 0.0:
				_stop(s, hit.position)
			else:
				if authoritative:
					_damage_player(target, s.attacker_id, s.shot_seq, s.pellet, s.damage, s.crit,
						s.vel.normalized() * s.knockback, hit.position, s.owner_id, s.snare_time, s.snare_factor)
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
		if s.bounces_left > 0 and not collider is ShieldWall:
			if collider is Crate and authoritative and s.splash_radius <= 0.0:
				(collider as Crate).take_damage(s.damage)  # ricochets still chip crates
			_bounce(s, hit.position, hit.normal, delta)
			return
		if collider is Crate and authoritative and s.splash_radius <= 0.0:
			(collider as Crate).take_damage(s.damage)
		_stop(s, hit.position)
		return
	s.pos = to
	s.life -= delta
	if s.life <= 0.0:
		if s.splash_radius > 0.0:
			_explode(s, s.pos)
		else:
			s.active = false


## Turns toward the nearest enemy that can be hit and isn't hidden in smoke, at most `homing` rad/s.
## shortcut: clients steer toward interpolated (slightly old) positions, so cosmetic petals can curve a little
## differently from the server's; hits still come only from the server.
func _steer(s: Slot, delta: float) -> void:
	var best: Player = null
	var best_d: float = INF
	for p: Player in targets:
		if p.player_id == s.attacker_id or not p.can_be_hit() or p.is_hidden():
			continue
		var d: float = s.pos.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	if best == null:
		return
	var turn: float = s.vel.angle_to(best.global_position - s.pos)
	s.vel = s.vel.rotated(clampf(turn, -s.homing * delta, s.homing * delta))


## Owners pass through their own shield; i-framing / dead players don't block shots.
func _passes_through(collider: Object, attacker_id: int) -> bool:
	var shield := collider as ShieldWall
	if shield != null:
		return shield.owner_id == attacker_id
	var p := collider as Player
	return p != null and (p.player_id == attacker_id or not p.can_be_hit())


## Re-cast the rest of the segment without this body. Rare path, so the alloc is fine.
func _exclude(rid: RID) -> void:
	var ex: Array[RID] = _query.exclude.duplicate()
	ex.append(rid)
	_query.exclude = ex


func _bounce(s: Slot, at: Vector2, normal: Vector2, delta: float) -> void:
	s.pos = at + normal * Constants.BOUNCE_EPSILON
	s.vel = s.vel.bounce(normal) * s.bounce_damping
	s.bounces_left -= 1
	s.life -= delta


## End of flight on an obstacle: explode if it has splash, else just pop.
func _stop(s: Slot, at: Vector2) -> void:
	if s.splash_radius > 0.0:
		# Pull the centre back off the surface so the blast's line-of-sight rays start in the open.
		_explode(s, at - s.vel.normalized() * s.radius)
	else:
		_finish(s, at)


## Caught by a Blossom Ward: gone in a petal pop, without its blast.
func _catch(s: Slot, at: Vector2, ward: ShieldWall) -> void:
	s.active = false
	ward.caught.emit(at)


func _finish(s: Slot, at: Vector2) -> void:
	s.active = false
	_add_impact(at, s.radius, s.color)


func _explode(s: Slot, at: Vector2, slam: bool = false, art: bool = true) -> void:
	s.active = false
	exploded.emit(at, s.splash_radius, s.color, slam, art)
	if not authoritative:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for result: Dictionary in _overlaps(space, at, s.splash_radius + Constants.PLAYER_RADIUS,
			Constants.LAYER_PLAYERS | Constants.LAYER_CRATES):
		var collider: Object = result.collider
		var target := collider as Player
		if target != null:
			# No self-damage: rocket-jumping would fight client prediction.
			if target.player_id == s.attacker_id or not target.can_be_hit() \
					or not AutoAim.has_line_of_sight(space, _los_query, at, target.global_position):
				continue
			var offset: Vector2 = target.global_position - at
			var dist: float = maxf(0.0, offset.length() - Constants.PLAYER_RADIUS)
			var dmg: int = CombatRules.splash_damage(s.damage, dist, s.splash_radius, s.splash_edge)
			var push: Vector2 = (offset.normalized() if offset != Vector2.ZERO else Vector2.UP) * s.knockback
			_damage_player(target, s.attacker_id, s.shot_seq, s.pellet, dmg, s.crit, push, target.global_position,
				s.owner_id)
		elif collider is Crate:
			var crate: Crate = collider
			var cdist: float = maxf(0.0, crate.global_position.distance_to(at) - crate.size * 0.5)
			crate.take_damage(CombatRules.splash_damage(s.damage, cdist, s.splash_radius, s.splash_edge))


## `key_owner`: the pellet key's owner (differs from the attacker after a reflection).
func _damage_player(target: Player, attacker_id: int, seq: int, pellet: int, damage: int, crit: bool,
		knockback: Vector2, at: Vector2, key_owner: int = -1, snare_time: float = 0.0, snare_factor: float = 1.0) -> void:
	var dealt: int = target.take_hit(damage, crit, knockback, attacker_id)
	if dealt > 0:
		if snare_time > 0.0:
			target.stats.apply_slow(snare_time, snare_factor)
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
		var tick: int = int(_time * SPRITE_FPS * (2.0 if fused else 1.0)) + s.pellet
		var back: Vector2 = -s.vel.normalized()
		for i: int in TRAIL_DOTS:  # pixel trail, crits in gold
			var size: float = px * (TRAIL_DOTS - i)
			var at: Vector2 = ((s.pos + back * px * 4.0 * (i + 2)) / px).floor() * px
			draw_rect(Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)),
				CRIT_SPARKLE_COLOR if s.crit and (tick + i) % 2 == 0 else s.color)
		var h: float = s.sprite.get_height()
		var frames: int = int(s.sprite.get_width() / h)
		var scale_px: float = px * (CRIT_SPRITE_SCALE if s.crit else 1.0)
		draw_set_transform(s.pos, s.vel.angle(), Vector2(scale_px, scale_px))
		draw_texture_rect_region(s.sprite, Rect2(-h * 0.5, -h * 0.5, h, h), Rect2((tick % frames) * h, 0, h, h),
			CRIT_FLASH if s.crit and tick % 2 == 0 else Color.WHITE)
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
