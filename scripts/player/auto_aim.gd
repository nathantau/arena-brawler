class_name AutoAim
extends RefCounted
## Nearest-visible-enemy targeting.

## How far down a player's hitbox (in radii) the fallback aim spot is.
const LOW_SPOT: float = 0.75


## Index of the nearest position within max_range for which is_visible(index) is true,
## or -1. Visibility (a raycast) is only checked for candidates closer than the best so far.
static func pick_nearest(origin: Vector2, positions: PackedVector2Array, max_range: float, is_visible: Callable) -> int:
	var best: int = -1
	var best_dist_sq: float = max_range * max_range
	for i: int in positions.size():
		var d: float = origin.distance_squared_to(positions[i])
		if d > best_dist_sq:
			continue
		if is_visible.call(i):
			best = i
			best_dist_sq = d
	return best


## Where to aim at a player standing at `target` (its centre) so a shot from `shooter`'s hand reaches it, or null
## if walls hide it. A player just below a wall has its centre inside the wall (feet-based collision lets the head
## overlap the wall above), so the lower half of its hitbox counts too.
static func visible_point(space: PhysicsDirectSpaceState2D, query: PhysicsRayQueryParameters2D, shooter: Vector2,
		target: Vector2) -> Variant:
	var hand: Vector2 = shooter + Player.hand_offset(target - shooter)
	for spot: Vector2 in [target, target + Vector2(0.0, Constants.PLAYER_RADIUS * LOW_SPOT)]:
		if has_line_of_sight(space, query, hand, spot):
			return spot
	return null


## True if no wall blocks the segment. `query` is reused to avoid per-frame allocation.
static func has_line_of_sight(space: PhysicsDirectSpaceState2D, query: PhysicsRayQueryParameters2D, from: Vector2, to: Vector2) -> bool:
	query.from = from
	query.to = to
	query.collision_mask = Constants.LAYER_WALLS
	return space.intersect_ray(query).is_empty()
