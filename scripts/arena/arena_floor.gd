class_name ArenaFloor
extends Node2D
## Pixel-art ground for a layout: floor tiles (shadowed under walls), an optional decal (court
## markings) and walls that show a front face where floor lies below them (3/4 look). Art comes
## from tools/sprites/generate.py: assets/arenas/<theme>_tiles.png is one row of 32 px cells in
## Tile order, drawn at the characters' pixel scale (32 art px per TILE_SIZE).

enum Tile { FLOOR_A, FLOOR_B, FLOOR_SHADOW, WALL_TOP, WALL_FACE, CRATE, CRATE_DAMAGED }

const ART_TILE: int = 32
const ART_DIR: String = "res://assets/arenas/"
## Every Nth floor cell (by a fixed hash, so all peers match) uses the second floor variant.
const FLOOR_B_EVERY: int = 5
## Crate contact shadow in art pixels of the crate's cell: an ellipse (centre, radii) under its base, the first row
## it may touch, the squared radius inside which it is solid, and its colour (like the fighters' ground shadow).
const CRATE_SHADOW_CX: float = 17.0
const CRATE_SHADOW_CY: float = 28.0
const CRATE_SHADOW_RX: float = 15.0
const CRATE_SHADOW_RY: float = 4.4
const CRATE_SHADOW_TOP: int = 24
const CRATE_SHADOW_CORE: float = 0.55
const CRATE_SHADOW_COLOR: Color = Color(0, 0, 0, 0.3)

## The theme's tile sheet; crates draw from it too.
var tiles: Texture2D

var _decal: Texture2D
## Optional dressing drawn over the walls (pipes, lamps, props), see tools/sprites/arena_decor.py.
var _overlay: Texture2D
var _rows: Array[String] = []
var _size: Vector2 = Vector2.ZERO
var _crate_spots := PackedVector2Array()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(map: ArenaMap, theme: StringName) -> void:
	_rows = map.rows
	_size = map.size
	_crate_spots = map.crate_spots
	tiles = load(ART_DIR + "%s_tiles.png" % theme)
	var decal_path: String = ART_DIR + "%s_decal.png" % theme
	_decal = load(decal_path) if ResourceLoader.exists(decal_path) else null
	var overlay_path: String = ART_DIR + "%s_overlay.png" % theme
	_overlay = load(overlay_path) if ResourceLoader.exists(overlay_path) else null
	queue_redraw()


static func region(t: Tile) -> Rect2:
	return Rect2(t * ART_TILE, 0, ART_TILE, ART_TILE)


static func tile_at(rows: Array[String], x: int, y: int) -> Tile:
	var below_is_wall: bool = y + 1 >= rows.size() or rows[y + 1][x] == ArenaMap.WALL_CHAR
	if rows[y][x] == ArenaMap.WALL_CHAR:
		return Tile.WALL_TOP if below_is_wall else Tile.WALL_FACE
	if y > 0 and rows[y - 1][x] == ArenaMap.WALL_CHAR:
		return Tile.FLOOR_SHADOW
	return Tile.FLOOR_B if (x * 7 + y * 13) % FLOOR_B_EVERY == 0 else Tile.FLOOR_A


## Flat ground only: floors, the decal over them, soft shadows under crates. Walls are ArtBlocks (build_walls) so
## they y-sort with fighters and upright ability art.
func _draw() -> void:
	if tiles == null:
		return
	_draw_cells(false)
	if _decal != null:
		draw_texture_rect(_decal, Rect2(Vector2.ZERO, _size), false)
	for c: Vector2 in _crate_spots:
		_draw_crate_shadow(c)


## A soft contact shadow under a crate, a little down-right like the fighters' ground shadows: translucent black on the
## art pixel grid, solid in the middle and dithered at the rim.
func _draw_crate_shadow(centre: Vector2) -> void:
	var px: float = Constants.TILE_SIZE / float(ART_TILE)
	var origin: Vector2 = centre - Vector2.ONE * Constants.TILE_SIZE * 0.5
	for ay: int in range(CRATE_SHADOW_TOP, ART_TILE):
		for ax: int in range(ART_TILE):
			var dx: float = (ax - CRATE_SHADOW_CX) / CRATE_SHADOW_RX
			var dy: float = (ay - CRATE_SHADOW_CY) / CRATE_SHADOW_RY
			var d: float = dx * dx + dy * dy
			if d < CRATE_SHADOW_CORE or (d < 1.0 and (ax + ay) % 2 == 0):
				draw_rect(Rect2(origin + Vector2(ax, ay) * px, Vector2(px, px)), CRATE_SHADOW_COLOR)


## One ArtBlock per horizontal run of wall cells (the map's wall rects) in `parent` (a y-sorted node), based on the
## run's bottom edge, with the wall overlay (pipes, lamps) painted over it.
func build_walls(parent: Node2D, map: ArenaMap) -> Array[ArtBlock]:
	var out: Array[ArtBlock] = []
	for w: Rect2 in map.walls:
		var block := ArtBlock.new()
		parent.add_child(block)
		block.place(w, w.end.y, _paint_wall.bind(w))
		out.append(block)
	return out


func _paint_wall(ci: CanvasItem, run: Rect2) -> void:
	if tiles == null:
		return
	var t: float = Constants.TILE_SIZE
	var y: int = roundi(run.position.y / t)
	var x0: int = roundi(run.position.x / t)
	for x: int in range(x0, x0 + roundi(run.size.x / t)):
		ci.draw_texture_rect_region(tiles, Rect2(x * t, y * t, t, t), region(tile_at(_rows, x, y)))
	if _overlay != null:
		var src := Rect2(run.position / t * ART_TILE, run.size / t * ART_TILE)
		ci.draw_texture_rect_region(_overlay, run, src)


func _draw_cells(walls: bool) -> void:
	var t: float = Constants.TILE_SIZE
	for y: int in _rows.size():
		for x: int in _rows[y].length():
			if (_rows[y][x] == ArenaMap.WALL_CHAR) == walls:
				draw_texture_rect_region(tiles, Rect2(x * t, y * t, t, t), region(tile_at(_rows, x, y)))
