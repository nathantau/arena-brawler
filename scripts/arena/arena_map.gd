class_name ArenaMap
extends RefCounted
## Parsed arena layout: wall rects (merged per horizontal run), spawn points and pickup spots.

const WALL_CHAR: String = "#"
const SPAWN_CHAR: String = "S"
const ENERGY_CHAR: String = "E"
const WEAPON_CHAR: String = "W"
const CRATE_CHAR: String = "C"

## The layout as parsed (the floor art reads it per cell).
var rows: Array[String] = []
var walls: Array[Rect2] = []
var spawns: PackedVector2Array = PackedVector2Array()
var energy_spots: PackedVector2Array = PackedVector2Array()
var weapon_spots: PackedVector2Array = PackedVector2Array()
var crate_spots: PackedVector2Array = PackedVector2Array()
var size: Vector2 = Vector2.ZERO
var _base_spawns: Dictionary = {}  # team -> PackedVector2Array, built on first use


static func parse(rows: Array[String], tile: float) -> ArenaMap:
	var map := ArenaMap.new()
	map.rows = rows
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
			var center := Vector2((x + 0.5) * tile, (y + 0.5) * tile)
			if c == SPAWN_CHAR:
				map.spawns.append(center)
			elif c == ENERGY_CHAR:
				map.energy_spots.append(center)
			elif c == WEAPON_CHAR:
				map.weapon_spots.append(center)
			elif c == CRATE_CHAR:
				map.crate_spots.append(center)
			x += 1
	map.size = Vector2(width * tile, rows.size() * tile)
	return map


## The spawns on one team's side of the map (team A left half, B right half); all of them if that side has none.
static func side_spawns(spawns: PackedVector2Array, width: float, team: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for s: Vector2 in spawns:
		if (s.x < width * 0.5) == (team == MatchRules.TEAM_A):
			out.append(s)
	return spawns if out.is_empty() else out


## Where a team's flag stands: the open floor tile nearest the middle of its back wall (A left, B right), found from
## the outermost spawn on that side. Mirrored layouts give mirrored bases.
func flag_base(team: int, tile: float) -> Vector2:
	var near: PackedVector2Array = ArenaMap.side_spawns(spawns, size.x, team)
	var x: float = near[0].x
	for s: Vector2 in near:
		x = minf(x, s.x) if team == MatchRules.TEAM_A else maxf(x, s.x)
	var ideal := Vector2(x, size.y * 0.5)
	var best: Vector2 = ideal
	var best_d: float = INF
	for y: int in rows.size():
		for cx: int in rows[y].length():
			var c: String = rows[y][cx]
			if c == WALL_CHAR or c == CRATE_CHAR:
				continue
			var at := Vector2((cx + 0.5) * tile, (y + 0.5) * tile)
			var d: float = at.distance_squared_to(ideal)
			if d < best_d:
				best_d = d
				best = at
	return best


## Teams spawn points: open floor tile centres within `reach` tiles of the team's flag base (not the base itself), with no
## wall/crate on the tile or its orthogonal neighbours so a player never clips a wall. Falls back to side_spawns.
func base_spawns(team: int, tile: float, reach: float = 3.0) -> PackedVector2Array:
	if _base_spawns.has(team):
		return _base_spawns[team]
	var base: Vector2 = flag_base(team, tile)
	var out := PackedVector2Array()
	for y: int in rows.size():
		for x: int in rows[y].length():
			var at := Vector2((x + 0.5) * tile, (y + 0.5) * tile)
			if at.is_equal_approx(base) or at.distance_to(base) > reach * tile:
				continue
			if _open(x, y) and _open(x + 1, y) and _open(x - 1, y) and _open(x, y + 1) and _open(x, y - 1):
				out.append(at)
	if out.is_empty():
		out = ArenaMap.side_spawns(spawns, size.x, team)
	_base_spawns[team] = out
	return out


func _open(x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return false
	var c: String = rows[y][x]
	return c != WALL_CHAR and c != CRATE_CHAR


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
