class_name TouchControls
extends Control
## Multi-touch mobile controls, drawn with primitives:
## - floating joystick anywhere on the left part of the screen
## - attack button (hold = fire with auto-aim; drag off-centre = manual aim)
## - skill button with cooldown sweep, weapon swap button, dev weapon-cycle button

const JOYSTICK_ZONE_FRACTION: float = 0.45
const JOY_RADIUS: float = 70.0
const JOY_KNOB_RADIUS: float = 30.0
const JOY_IDLE_POS_FRACTION: Vector2 = Vector2(0.15, 0.72)
const ATTACK_RADIUS: float = 64.0
const ATTACK_MARGIN: Vector2 = Vector2(120, 110)
const SKILL_RADIUS: float = 40.0
const SKILL_OFFSET: Vector2 = Vector2(-130, 20)
const SWAP_RADIUS: float = 32.0
const SWAP_OFFSET: Vector2 = Vector2(-20, -120)
const DEV_RADIUS: float = 22.0
const DEV_MARGIN: Vector2 = Vector2(40, 40)
const HIT_SLOP: float = 1.25
const AIM_LINE_WIDTH: float = 3.0
const RING_WIDTH: float = 3.0
const SEGMENTS: int = 32
const LABEL_FONT_SIZE: int = 14
const COLOR_IDLE: Color = Color(1, 1, 1, 0.18)
const COLOR_ACTIVE: Color = Color(1, 1, 1, 0.35)
const COLOR_RING: Color = Color(1, 1, 1, 0.55)
const COLOR_COOLDOWN: Color = Color(0, 0, 0, 0.55)
const COLOR_AIM: Color = Color(1, 0.4, 0.4, 0.8)
const NO_FINGER: int = -1

var player: Player
var move_vec: Vector2 = Vector2.ZERO
var attack_held: bool = false
## Zero unless the attack finger has been dragged past the deadzone.
var attack_aim: Vector2 = Vector2.ZERO
var skill_held: bool = false
var swap_held: bool = false

var _dev_cycle_requested: bool = false
var _joy_finger: int = NO_FINGER
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_pos: Vector2 = Vector2.ZERO
var _attack_finger: int = NO_FINGER
var _skill_finger: int = NO_FINGER
var _swap_finger: int = NO_FINGER


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func consume_dev_cycle() -> bool:
	var r: bool = _dev_cycle_requested
	_dev_cycle_requested = false
	return r


func _attack_center() -> Vector2:
	return size - ATTACK_MARGIN


func _skill_center() -> Vector2:
	return _attack_center() + SKILL_OFFSET


func _swap_center() -> Vector2:
	return _attack_center() + SWAP_OFFSET


func _dev_center() -> Vector2:
	return Vector2(size.x - DEV_MARGIN.x, DEV_MARGIN.y)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := make_input_local(event) as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		var d := make_input_local(event) as InputEventScreenDrag
		_on_drag(d.index, d.position)


func _hits(p: Vector2, center: Vector2, radius: float) -> bool:
	return p.distance_to(center) <= radius * HIT_SLOP


func _on_press(finger: int, p: Vector2) -> void:
	if _attack_finger == NO_FINGER and _hits(p, _attack_center(), ATTACK_RADIUS):
		_attack_finger = finger
		attack_held = true
		attack_aim = Vector2.ZERO
	elif _skill_finger == NO_FINGER and _hits(p, _skill_center(), SKILL_RADIUS):
		_skill_finger = finger
		skill_held = true
	elif _swap_finger == NO_FINGER and _hits(p, _swap_center(), SWAP_RADIUS):
		_swap_finger = finger
		swap_held = true
	elif _hits(p, _dev_center(), DEV_RADIUS):
		_dev_cycle_requested = true
	elif _joy_finger == NO_FINGER and p.x < size.x * JOYSTICK_ZONE_FRACTION:
		_joy_finger = finger
		_joy_origin = p
		_joy_pos = p
		move_vec = Vector2.ZERO
	queue_redraw()


func _on_drag(finger: int, p: Vector2) -> void:
	if finger == _joy_finger:
		var offset: Vector2 = p - _joy_origin
		if offset.length() > JOY_RADIUS:
			# Floating stick: drag the base along so reversing direction is instant.
			_joy_origin = p - offset.normalized() * JOY_RADIUS
			offset = p - _joy_origin
		_joy_pos = p
		move_vec = offset / JOY_RADIUS
	elif finger == _attack_finger:
		var drag: Vector2 = p - _attack_center()
		attack_aim = drag if drag.length() > Constants.DRAG_AIM_DEADZONE_PX else Vector2.ZERO
	queue_redraw()


func _on_release(finger: int) -> void:
	if finger == _joy_finger:
		_joy_finger = NO_FINGER
		move_vec = Vector2.ZERO
	elif finger == _attack_finger:
		_attack_finger = NO_FINGER
		attack_held = false
		attack_aim = Vector2.ZERO
	elif finger == _skill_finger:
		_skill_finger = NO_FINGER
		skill_held = false
	elif finger == _swap_finger:
		_swap_finger = NO_FINGER
		swap_held = false
	queue_redraw()


func _process(_delta: float) -> void:
	# Skill cooldown sweep changes every frame.
	if visible and player != null and not player.dash.is_ready():
		queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# Joystick
	var base: Vector2 = _joy_origin if _joy_finger != NO_FINGER else size * JOY_IDLE_POS_FRACTION
	var knob: Vector2 = _joy_pos if _joy_finger != NO_FINGER else base
	draw_arc(base, JOY_RADIUS, 0.0, TAU, SEGMENTS, COLOR_RING, RING_WIDTH)
	draw_circle(knob, JOY_KNOB_RADIUS, COLOR_ACTIVE if _joy_finger != NO_FINGER else COLOR_IDLE)

	# Attack
	var ac: Vector2 = _attack_center()
	draw_circle(ac, ATTACK_RADIUS, COLOR_ACTIVE if attack_held else COLOR_IDLE)
	draw_arc(ac, ATTACK_RADIUS, 0.0, TAU, SEGMENTS, COLOR_RING, RING_WIDTH)
	if attack_aim != Vector2.ZERO:
		draw_line(ac, ac + attack_aim.limit_length(ATTACK_RADIUS * 2.0), COLOR_AIM, AIM_LINE_WIDTH)
	_label(font, ac, "FIRE")

	# Skill + cooldown sweep
	var sc: Vector2 = _skill_center()
	draw_circle(sc, SKILL_RADIUS, COLOR_ACTIVE if skill_held else COLOR_IDLE)
	if player != null and not player.dash.is_ready():
		var frac: float = player.dash.cooldown_fraction()
		draw_arc(sc, SKILL_RADIUS * 0.5, -PI * 0.5, -PI * 0.5 + TAU * frac, SEGMENTS, COLOR_COOLDOWN, SKILL_RADIUS)
	draw_arc(sc, SKILL_RADIUS, 0.0, TAU, SEGMENTS, COLOR_RING, RING_WIDTH)
	_label(font, sc, "DASH")

	# Swap
	var wc: Vector2 = _swap_center()
	draw_circle(wc, SWAP_RADIUS, COLOR_ACTIVE if swap_held else COLOR_IDLE)
	draw_arc(wc, SWAP_RADIUS, 0.0, TAU, SEGMENTS, COLOR_RING, RING_WIDTH)
	_label(font, wc, "SWAP")

	# Dev weapon cycle
	var dc: Vector2 = _dev_center()
	draw_arc(dc, DEV_RADIUS, 0.0, TAU, SEGMENTS, COLOR_RING, RING_WIDTH)
	_label(font, dc, "W")


func _label(font: Font, center: Vector2, text: String) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	draw_string(font, center + Vector2(-w * 0.5, LABEL_FONT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, COLOR_RING)
