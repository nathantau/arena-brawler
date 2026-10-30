class_name Crate
extends StaticBody2D
## A destructible crate. Blocks movement and sight like a wall (LAYER_WALLS) and is told
## apart by projectiles via LAYER_CRATES. Only authoritative damage destroys it; clients
## mirror hp from the server (CrateField.apply_array).

signal damaged(crate: Crate)

const INSET: float = 4.0
## Below this fraction of hp the damaged frame shows.
const DAMAGED_FRACTION: float = 0.5

var index: int = 0
var hp: int = Constants.CRATE_HP
var size: float = 0.0

## Theme tile sheet (ArenaFloor.tiles); drawn with the crate frames from it.
var art: Texture2D

var _cs := CollisionShape2D.new()


func setup(p_index: int, center: Vector2, tile: float) -> void:
	index = p_index
	position = center
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = tile - INSET * 2.0
	collision_layer = Constants.LAYER_WALLS | Constants.LAYER_CRATES
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size, size)
	_cs.shape = shape
	add_child(_cs)


func is_intact() -> bool:
	return hp > 0


## Authoritative damage. Returns true if this destroyed it.
func take_damage(amount: int) -> bool:
	if not is_intact() or amount <= 0:
		return false
	set_hp(hp - amount)
	damaged.emit(self)
	return not is_intact()


func set_hp(value: int) -> void:
	var was_intact: bool = is_intact()
	hp = maxi(0, value)
	if was_intact != is_intact():
		visible = is_intact()
		_cs.set_deferred("disabled", not is_intact())
	queue_redraw()


func _draw() -> void:
	if art == null:
		return
	var t: float = Constants.TILE_SIZE
	var damaged: bool = hp < Constants.CRATE_HP * DAMAGED_FRACTION
	var frame: ArenaFloor.Tile = ArenaFloor.Tile.CRATE_DAMAGED if damaged else ArenaFloor.Tile.CRATE
	draw_texture_rect_region(art, Rect2(-t * 0.5, -t * 0.5, t, t), ArenaFloor.region(frame))
