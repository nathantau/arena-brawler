class_name ArenaFloor
extends Node2D
## Pixel-art ground for a layout: floor tiles (shadowed under walls), an optional decal (court
## markings) and walls that show a front face where floor lies below them (3/4 look). Art comes
## from tools/sprites/generate.py: assets/arenas/<theme>_tiles.png is one row of 32 px cells in
## Tile order, drawn at the characters' pixel scale (32 art px per TILE_SIZE).

enum Tile { FLOOR_A, FLOOR_B, FLOOR_SHADOW, WALL_TOP, WALL_FACE, CRATE, CRATE_DAMAGED }

const ART_TILE: int = 32
## Rows of a wall tile that are its front face (generate.py FACE_H).
const ARENA_FACE_ROWS: int = 16
const ART_DIR: String = "res://assets/arenas/"
## Every Nth floor cell (by a fixed hash, so all peers match) uses the second floor variant.
const FLOOR_B_EVERY: int = 5
## Drop shadows (art pixels, 1 art px = 1.5 world px): every wall run and crate casts a shadow SHADOW_OFFSET down-right (the
## way the fighters' shadows lean), solid at SHADOW_COLOR with one ring of dithered pixels at its edge, plus a fainter dithered
## ring of ambient occlusion hugging the footprint. A crate's footprint is this rect of its 32 px cell.
const SHADOW_OFFSET: Vector2i = Vector2i(7, 6)
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.5)
const AO_COLOR: Color = Color(0, 0, 0, 0.4)
const CRATE_FOOT: Rect2i = Rect2i(4, 15, 24, 14)
## Lit top face: a highlight along its top and left edge, a dark line along its right edge (translucent over the art).
const EDGE_LIGHT: Color = Color(1, 1, 1, 0.38)
const EDGE_DARK: Color = Color(0, 0, 0, 0.3)

## Teams halfway line (court-style midline on the ground): MID_W art px wide, dashes MID_DASH on / MID_GAP off, translucent cream
## over a thin dark edge so it reads on every floor. Never over wall tiles.
const MID_W: int = 3
const MID_DASH: int = 12
const MID_GAP: int = 4
const MID_COLOR: Color = Color(1.0, 0.96, 0.82, 0.78)
const MID_EDGE: Color = Color(0, 0, 0, 0.3)
## Soft halo: 2 art px either side, fainter outwards.
const MID_HALO: Color = Color(1.0, 0.96, 0.82, 0.16)

## The theme's tile sheet; crates draw from it too.
var tiles: Texture2D

var _decal: Texture2D
## Optional dressing drawn over the walls (pipes, lamps, props), see tools/sprites/arena_decor.py.
var _overlay: Texture2D
var _rows: Array[String] = []
var _size: Vector2 = Vector2.ZERO
var _crate_spots := PackedVector2Array()
var _walls: Array[Rect2] = []
var _midline: bool = false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(map: ArenaMap, theme: StringName) -> void:
	_rows = map.rows
	_size = map.size
	_crate_spots = map.crate_spots
	_walls = map.walls
	tiles = load(ART_DIR + "%s_tiles.png" % theme)
	var decal_path: String = ART_DIR + "%s_decal.png" % theme
	_decal = load(decal_path) if ResourceLoader.exists(decal_path) else null
	var overlay_path: String = ART_DIR + "%s_overlay.png" % theme
	_overlay = load(overlay_path) if ResourceLoader.exists(overlay_path) else null
	queue_redraw()


## Teams only: show / hide the halfway line.
func set_midline(on: bool) -> void:
	if on != _midline:
		_midline = on
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
	if _midline:
		_draw_midline()
	var t: float = Constants.TILE_SIZE
	for w: Rect2 in _walls:
		_draw_drop_shadow(w)
	for c: Vector2 in _crate_spots:
		var origin: Vector2 = c - Vector2.ONE * t * 0.5
		var px: float = t / float(ART_TILE)
		_draw_drop_shadow(Rect2(origin + Vector2(CRATE_FOOT.position) * px, Vector2(CRATE_FOOT.size) * px))


## Dashed line at the map's halfway x, full height, snapped to the art pixel grid and skipped over wall tiles.
func _draw_midline() -> void:
	var t: float = Constants.TILE_SIZE
	var px: float = t / float(ART_TILE)
	var x: float = floorf(_size.x * 0.5 / px) * px - px * (MID_W / 2)
	var cols: Array[int] = [int((x - 1.0) / t), int((x + px * MID_W) / t)]
	var n: int = int(_size.y / px)
	var i: int = 0
	while i < n:
		var len: int = mini(MID_DASH, n - i)
		for k: int in len:
			var y: float = (i + k) * px
			var row: int = int(y / t)
			var blocked: bool = false
			for c: int in cols:
				if row >= _rows.size() or c >= _rows[row].length() or _rows[row][c] == ArenaMap.WALL_CHAR:
					blocked = true
			if blocked:
				continue
			draw_rect(Rect2(x - px * 2.0, y, px, px), Color(MID_HALO, MID_HALO.a * 0.5))
			draw_rect(Rect2(x - px, y, px, px), MID_HALO)
			draw_rect(Rect2(x, y, px * MID_W, px), MID_COLOR)
			draw_rect(Rect2(x + px * MID_W, y, px, px), MID_EDGE)
			draw_rect(Rect2(x + px * (MID_W + 1), y, px, px), MID_HALO)
			draw_rect(Rect2(x + px * (MID_W + 2), y, px, px), Color(MID_HALO, MID_HALO.a * 0.5))
		i += MID_DASH + MID_GAP


## `foot` (world rect) casts SHADOW_OFFSET down-right: a solid block, a dithered edge, and AO round the footprint itself.
func _draw_drop_shadow(foot: Rect2) -> void:
	var px: float = Constants.TILE_SIZE / float(ART_TILE)
	var shadow := Rect2(foot.position + Vector2(SHADOW_OFFSET) * px, foot.size)
	draw_rect(shadow, SHADOW_COLOR)
	_dither_ring(shadow, 1, SHADOW_COLOR, px)
	_dither_ring(foot, 1, AO_COLOR, px)
	_dither_ring(foot, 2, AO_COLOR, px)


## A one art pixel ring `dist` pixels outside `r`, every other pixel (a checker), for soft edges.
func _dither_ring(r: Rect2, dist: int, color: Color, px: float) -> void:
	var x0: int = roundi(r.position.x / px) - dist
	var y0: int = roundi(r.position.y / px) - dist
	var x1: int = roundi(r.end.x / px) + dist - 1
	var y1: int = roundi(r.end.y / px) + dist - 1
	for x: int in range(x0, x1 + 1):
		for y: int in [y0, y1]:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * px, y * px, px, px), color)
	for y: int in range(y0 + 1, y1):
		for x: int in [x0, x1]:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * px, y * px, px, px), color)


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
	_paint_edges(ci, run, x0, y)
	if _overlay != null:
		var src := Rect2(run.position / t * ART_TILE, run.size / t * ART_TILE)
		ci.draw_texture_rect_region(_overlay, run, src)


func _draw_cells(walls: bool) -> void:
	var t: float = Constants.TILE_SIZE
	for y: int in _rows.size():
		for x: int in _rows[y].length():
			if (_rows[y][x] == ArenaMap.WALL_CHAR) == walls:
				draw_texture_rect_region(tiles, Rect2(x * t, y * t, t, t), region(tile_at(_rows, x, y)))


## Lighting from the top left on a run's roof: a highlight on its top edge (where no wall sits above) and left end, a dark
## line on its right end, over the roof only (not its front face).
func _paint_edges(ci: CanvasItem, run: Rect2, x0: int, y: int) -> void:
	var t: float = Constants.TILE_SIZE
	var px: float = t / float(ART_TILE)
	var cells: int = roundi(run.size.x / t)
	var below_wall: bool = tile_at(_rows, x0, y) == Tile.WALL_TOP
	var roof_h: float = (ART_TILE if below_wall else ART_TILE - ARENA_FACE_ROWS) * px
	var above_wall: bool = y > 0 and _rows[y - 1][x0] == ArenaMap.WALL_CHAR
	if not above_wall:
		ci.draw_rect(Rect2(run.position, Vector2(run.size.x, px)), EDGE_LIGHT)
	ci.draw_rect(Rect2(run.position + Vector2(0.0, px if not above_wall else 0.0), Vector2(px, roof_h)), EDGE_LIGHT)
	ci.draw_rect(Rect2(run.position + Vector2(run.size.x - px, 0.0), Vector2(px, roof_h)), EDGE_DARK)
