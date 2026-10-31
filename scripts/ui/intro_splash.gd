class_name IntroSplash
extends Control
## ~1 s opening over the title screen: dark boot colour, the logo slams in from big with a white flash and
## a camera kick, the arena fades up behind it, then the menu fades in. Tap / click / key skips.

const HOLD: float = 0.12
const LAND_AT: float = 0.55
const FADE_END: float = 1.1
const UI_FROM: float = 0.75
const START_SCALE: float = 3.2
const FLASH_ALPHA: float = 0.6
const FLASH_TIME: float = 0.22
const MAX_STEP: float = 0.05

var _backdrop: TitleBackdrop
var _ui: Control
var _t: float = 0.0
var _landed: bool = false
var _flash: float = 0.0


func _init(backdrop: TitleBackdrop, ui: Control) -> void:
	_backdrop = backdrop
	_ui = ui


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply(0.0)


func _process(delta: float) -> void:
	_t += minf(delta, MAX_STEP)  # the first frame after loading is long
	if _t >= FADE_END:
		_finish()
		return
	_apply(_t)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_finish()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed():
		_finish()


func _apply(t: float) -> void:
	var u: float = clampf((t - HOLD) / (LAND_AT - HOLD), 0.0, 1.0)
	_backdrop.logo_scale = lerpf(START_SCALE, 1.0, 1.0 - pow(1.0 - u, 2.0))
	_backdrop.logo_alpha = clampf(u * 4.0, 0.0, 1.0)
	var r: float = clampf((t - LAND_AT) / (FADE_END - LAND_AT), 0.0, 1.0)
	_backdrop.reveal = r
	_backdrop.veil = 1.0 - r
	_ui.modulate.a = clampf((t - UI_FROM) / (FADE_END - UI_FROM), 0.0, 1.0)
	if t >= LAND_AT and not _landed:
		_landed = true
		_flash = 1.0
		_backdrop.punch = 1.0
	if _landed:
		_flash = maxf(0.0, 1.0 - (t - LAND_AT) / FLASH_TIME)


func _draw() -> void:
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash * FLASH_ALPHA))


func _finish() -> void:
	_backdrop.logo_scale = 1.0
	_backdrop.logo_alpha = 1.0
	_backdrop.reveal = 1.0
	_backdrop.veil = 0.0
	_ui.modulate.a = 1.0
	queue_free()
