class_name ButtonShine
extends Control
## Child of a primary button: slow scale pulse on the parent plus a diagonal shine sweep clipped to it.

const PULSE: float = 0.025
const PULSE_SPEED: float = 3.0
const PERIOD: float = 2.6
const SWEEP_TIME: float = 0.6
const BAND_W: float = 26.0
const SKEW: float = 0.5
const INSET: float = 8.0
const ALPHA: float = 0.4

var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	offset_left = INSET
	offset_right = -INSET
	offset_top = INSET * 0.5
	offset_bottom = -INSET


func _process(delta: float) -> void:
	_t += delta
	var b := get_parent() as Control
	b.pivot_offset = b.size * 0.5
	var k: float = 1.0 + PULSE * (0.5 + 0.5 * sin(_t * PULSE_SPEED))
	b.scale = Vector2(k, k)
	queue_redraw()


func _draw() -> void:
	var ph: float = fposmod(_t, PERIOD)
	if ph > SWEEP_TIME:
		return
	var x: float = lerpf(-BAND_W * 2.0, size.x + BAND_W, ph / SWEEP_TIME)
	var sk: float = size.y * SKEW
	draw_colored_polygon(PackedVector2Array([Vector2(x + sk, 0), Vector2(x + sk + BAND_W, 0),
		Vector2(x + BAND_W, size.y), Vector2(x, size.y)]), Color(1, 1, 1, ALPHA))
