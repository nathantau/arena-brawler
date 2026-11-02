class_name ArtBlock
extends Node2D
## One depth-sorted piece of arena art (a run of wall cells, a crate, an ability's upright art). The arena
## and its y-sorted containers sort children by node y, and a Player's node sits SORT_LIFT above its feet,
## so a block is placed SORT_LIFT above its base line and paints in WORLD coordinates (the paint callable
## gets this node as the CanvasItem to draw on). `ghosts` are see-through copies of fighters hidden behind
## the block (Arena._update_ghosts), already clipped to `rect`, drawn over the block's art.

## Feet (Player.FOOT_RING_Y) minus nothing: node y of a fighter standing on the same base line.
const SORT_LIFT: float = 40.0

## World rect the art covers (for occlusion tests).
var rect: Rect2 = Rect2()
## World y of the line the art stands on.
var base_y: float = 0.0
var paint: Callable
## Entries [texture, dst Rect2, src Rect2, tint Color].
var ghosts: Array = []


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Puts the block on `p_base_y` (parent must already be in the tree).
func place(p_rect: Rect2, p_base_y: float, p_paint: Callable) -> void:
	rect = p_rect
	base_y = p_base_y
	paint = p_paint
	global_position = Vector2(0.0, base_y - SORT_LIFT)
	queue_redraw()


func set_ghosts(list: Array) -> void:
	if list.is_empty() and ghosts.is_empty():
		return
	ghosts = list
	queue_redraw()


func _draw() -> void:
	draw_set_transform(-global_position)
	if paint.is_valid():
		paint.call(self)
	draw_set_transform(-global_position)  # (the paint may have changed it)
	for g: Array in ghosts:
		draw_texture_rect_region(g[0], g[1], g[2], g[3])
