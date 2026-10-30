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

## The theme's tile sheet; crates draw from it too.
var tiles: Texture2D

var _decal: Texture2D
var _rows: Array[String] = []
var _size: Vector2 = Vector2.ZERO


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(map: ArenaMap, theme: StringName) -> void:
	_rows = map.rows
	_size = map.size
	tiles = load(ART_DIR + "%s_tiles.png" % theme)
	var decal_path: String = ART_DIR + "%s_decal.png" % theme
	_decal = load(decal_path) if ResourceLoader.exists(decal_path) else null
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


## Floors, then the decal over them, then walls on top.
func _draw() -> void:
	if tiles == null:
		return
	_draw_cells(false)
	if _decal != null:
		draw_texture_rect(_decal, Rect2(Vector2.ZERO, _size), false)
	_draw_cells(true)


func _draw_cells(walls: bool) -> void:
	var t: float = Constants.TILE_SIZE
	for y: int in _rows.size():
		for x: int in _rows[y].length():
			if (_rows[y][x] == ArenaMap.WALL_CHAR) == walls:
				draw_texture_rect_region(tiles, Rect2(x * t, y * t, t, t), region(tile_at(_rows, x, y)))
