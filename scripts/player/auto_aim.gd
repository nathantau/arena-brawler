class_name AutoAim
extends RefCounted
## Nearest-visible-enemy targeting.


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


## True if no wall blocks the segment. `query` is reused to avoid per-frame allocation.
static func has_line_of_sight(space: PhysicsDirectSpaceState2D, query: PhysicsRayQueryParameters2D, from: Vector2, to: Vector2) -> bool:
	query.from = from
	query.to = to
	query.collision_mask = Constants.LAYER_WALLS
	return space.intersect_ray(query).is_empty()
