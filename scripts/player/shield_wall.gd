class_name ShieldWall
extends StaticBody2D
## The Warden's barrier. A thin static body on LAYER_SHIELDS: projectiles from anyone but
## the owner stop on it; players and line-of-sight ignore it. Positioned from the owner's
## CharacterSkill state every frame, so it's identical on server, predictor and observers.

const COLOR_ALPHA: float = 0.45
const EDGE_ALPHA: float = 0.9
const EDGE_WIDTH: float = 2.0

var owner_id: int = 0
var color: Color = Color.WHITE

var _shape := RectangleShape2D.new()
var _cs := CollisionShape2D.new()
var _up: bool = false
var _width: float = 0.0


func _init() -> void:
	top_level = true
	collision_layer = Constants.LAYER_SHIELDS
	collision_mask = 0
	_cs.shape = _shape
	_cs.disabled = true
	add_child(_cs)
	visible = false


## Follow the skill state; called after every simulate / apply_state.
func sync(skill: CharacterSkill, dead: bool) -> void:
	var up: bool = skill.is_shielding() and not dead
	if up:
		global_position = skill.anchor
		rotation = skill.direction.angle()
		if _width != skill.data.shield_width:
			_width = skill.data.shield_width
			_shape.size = Vector2(Constants.SHIELD_THICKNESS, _width)
			queue_redraw()
	if up != _up:
		_up = up
		visible = up
		_cs.set_deferred("disabled", not up)


func _draw() -> void:
	var rect := Rect2(Vector2(-Constants.SHIELD_THICKNESS, -_width) * 0.5, Vector2(Constants.SHIELD_THICKNESS, _width))
	var fill: Color = color
	fill.a = COLOR_ALPHA
	draw_rect(rect, fill)
	var edge: Color = color.lightened(0.4)
	edge.a = EDGE_ALPHA
	draw_rect(rect, edge, false, EDGE_WIDTH)
