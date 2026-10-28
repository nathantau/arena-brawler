class_name ProjectilePool
extends Node2D
## Fixed-size pool of projectiles simulated without per-projectile nodes. Each step is a
## raycast from the previous to the next position, and everything is drawn in one _draw.

const TRAIL_TIME: float = 0.025
const TRAIL_WIDTH_SCALE: float = 1.2
const TRAIL_ALPHA: float = 0.45
const IMPACT_POOL_SIZE: int = 48
const IMPACT_TIME: float = 0.12
const IMPACT_RADIUS_SCALE: float = 3.0
const CRIT_RADIUS_SCALE: float = 1.4


class Slot:
	var active: bool = false
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var owner_id: int = 0
	var damage: int = 0
	var crit: bool = false
	var knockback: float = 0.0
	var radius: float = 0.0
	var color: Color = Color.WHITE


class Impact:
	var time_left: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var color: Color = Color.WHITE


var _slots: Array[Slot] = []
var _impacts: Array[Impact] = []
var _cursor: int = 0
var _impact_cursor: int = 0
var _query := PhysicsRayQueryParameters2D.new()
var _los_query := PhysicsRayQueryParameters2D.new()
var _empty_exclude: Array[RID] = []


func _ready() -> void:
	for i: int in Constants.PROJECTILE_POOL_SIZE:
		_slots.append(Slot.new())
	for i: int in IMPACT_POOL_SIZE:
		_impacts.append(Impact.new())
	_query.collision_mask = Constants.LAYER_WALLS | Constants.LAYER_PLAYERS
	_query.hit_from_inside = false


## Spawns from `origin` (shooter centre) at distance `muzzle_dist`. If a wall sits between
## the shooter and the muzzle the shot pops on the wall instead of tunnelling through.
func spawn(owner_id: int, origin: Vector2, muzzle_dist: float, dir: Vector2, weapon: WeaponData, damage: int, crit: bool) -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var muzzle: Vector2 = origin + dir * muzzle_dist
	if not AutoAim.has_line_of_sight(space, _los_query, origin, muzzle):
		_add_impact(muzzle, weapon.projectile_radius, weapon.color)
		return
	var slot: Slot = _next_free_slot()
	slot.active = true
	slot.pos = muzzle
	slot.vel = dir * weapon.projectile_speed
	slot.life = weapon.projectile_range / weapon.projectile_speed
	slot.owner_id = owner_id
	slot.damage = damage
	slot.crit = crit
	slot.knockback = weapon.knockback
	slot.radius = weapon.projectile_radius * (CRIT_RADIUS_SCALE if crit else 1.0)
	slot.color = weapon.color


func active_count() -> int:
	var n: int = 0
	for s: Slot in _slots:
		if s.active:
			n += 1
	return n


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
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for s: Slot in _slots:
		if s.active:
			_step_slot(s, delta, space)
	for imp: Impact in _impacts:
		if imp.time_left > 0.0:
			imp.time_left -= delta
	queue_redraw()


func _step_slot(s: Slot, delta: float, space: PhysicsDirectSpaceState2D) -> void:
	var to: Vector2 = s.pos + s.vel * delta
	_query.from = s.pos
	_query.to = to
	_query.exclude = _empty_exclude
	for attempt: int in Constants.PROJECTILE_MAX_PASS_THROUGH:
		var hit: Dictionary = space.intersect_ray(_query)
		if hit.is_empty():
			break
		var target := hit.collider as Player
		if target == null:
			_finish(s, hit.position)
			return
		if target.player_id != s.owner_id and target.can_be_hit():
			target.take_hit(s.damage, s.crit, s.vel.normalized() * s.knockback, s.owner_id)
			_finish(s, hit.position)
			return
		# Owner or i-framing player: pass through and re-cast the rest of the segment
		# so a wall right behind them is still detected. Rare path, so the alloc is fine.
		var ex: Array[RID] = _query.exclude.duplicate()
		ex.append(hit.rid)
		_query.exclude = ex
	s.pos = to
	s.life -= delta
	if s.life <= 0.0:
		s.active = false


func _finish(s: Slot, at: Vector2) -> void:
	s.active = false
	_add_impact(at, s.radius, s.color)


func _add_impact(at: Vector2, radius: float, color: Color) -> void:
	var imp: Impact = _impacts[_impact_cursor]
	_impact_cursor = (_impact_cursor + 1) % _impacts.size()
	imp.time_left = IMPACT_TIME
	imp.pos = at
	imp.radius = radius
	imp.color = color


func _draw() -> void:
	for s: Slot in _slots:
		if not s.active:
			continue
		var trail_color: Color = s.color
		trail_color.a = TRAIL_ALPHA
		draw_line(s.pos - s.vel * TRAIL_TIME, s.pos, trail_color, s.radius * TRAIL_WIDTH_SCALE)
		draw_circle(s.pos, s.radius, s.color)
	for imp: Impact in _impacts:
		if imp.time_left <= 0.0:
			continue
		var t: float = 1.0 - imp.time_left / IMPACT_TIME
		var c: Color = imp.color
		c.a = 1.0 - t
		draw_circle(imp.pos, imp.radius * lerpf(1.0, IMPACT_RADIUS_SCALE, t), c)
