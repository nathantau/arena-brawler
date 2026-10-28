class_name ArenaMap
extends RefCounted
## Parsed arena layout: wall rects (merged per horizontal run) and spawn points.

const WALL_CHAR: String = "#"
const SPAWN_CHAR: String = "S"

var walls: Array[Rect2] = []
var spawns: PackedVector2Array = PackedVector2Array()
var size: Vector2 = Vector2.ZERO


static func parse(rows: Array[String], tile: float) -> ArenaMap:
	var map := ArenaMap.new()
	var width: int = 0
	for y: int in rows.size():
		var row: String = rows[y]
		width = maxi(width, row.length())
		var x: int = 0
		while x < row.length():
			var c: String = row[x]
			if c == WALL_CHAR:
				var start: int = x
				while x < row.length() and row[x] == WALL_CHAR:
					x += 1
				map.walls.append(Rect2(start * tile, y * tile, (x - start) * tile, tile))
				continue
			if c == SPAWN_CHAR:
				map.spawns.append(Vector2((x + 0.5) * tile, (y + 0.5) * tile))
			x += 1
	map.size = Vector2(width * tile, rows.size() * tile)
	return map


## The spawn whose nearest threat is farthest away. With no threats, the first spawn.
static func pick_spawn(spawns: PackedVector2Array, threats: PackedVector2Array) -> Vector2:
	if threats.is_empty():
		return spawns[0]
	var best: Vector2 = spawns[0]
	var best_score: float = -INF
	for s: Vector2 in spawns:
		var nearest: float = INF
		for t: Vector2 in threats:
			nearest = minf(nearest, s.distance_squared_to(t))
		if nearest > best_score:
			best_score = nearest
			best = s
	return best
