class_name Crate
extends StaticBody2D
## A destructible crate. Blocks movement and sight like a wall (LAYER_WALLS) and is told
## apart by projectiles via LAYER_CRATES. Only authoritative damage destroys it; clients
## mirror hp from the server (CrateField.apply_array).

signal damaged(crate: Crate)

const INSET: float = 4.0
const COLOR_BODY: Color = Color(0.55, 0.4, 0.25)
const COLOR_EDGE: Color = Color(0.32, 0.22, 0.13)
const COLOR_CRACK: Color = Color(0.2, 0.13, 0.07)
const EDGE_WIDTH: float = 3.0
const CRACK_WIDTH: float = 2.0

var index: int = 0
var hp: int = Constants.CRATE_HP
var size: float = 0.0

var _cs := CollisionShape2D.new()


func setup(p_index: int, center: Vector2, tile: float) -> void:
	index = p_index
	position = center
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
	var r := Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size))
	draw_rect(r, COLOR_BODY)
	draw_rect(r, COLOR_EDGE, false, EDGE_WIDTH)
	draw_line(r.position, r.end, COLOR_EDGE, EDGE_WIDTH)
	# Cracks appear as it takes damage.
	var dmg: float = 1.0 - float(hp) / float(Constants.CRATE_HP)
	if dmg > 0.3:
		draw_line(Vector2(-size * 0.4, size * 0.1), Vector2(0, -size * 0.1), COLOR_CRACK, CRACK_WIDTH)
	if dmg > 0.6:
		draw_line(Vector2(size * 0.1, size * 0.4), Vector2(size * 0.35, -size * 0.2), COLOR_CRACK, CRACK_WIDTH)
