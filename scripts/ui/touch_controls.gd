class_name TouchControls
extends Control
## Multi-touch mobile controls inside the safe area, drawn with the pixel UI kit:
## - joystick anywhere on the left part of the screen (base fixed where you touch until release)
## - attack button (hold = fire with auto-aim; drag off-centre = manual aim)
## - two skill buttons, one per equipped special (skill icon, cooldown sweep + seconds)
## Touches that start on a visible `blockers` control (e.g. lobby buttons) are left to the GUI.

const JOYSTICK_ZONE_FRACTION: float = 0.45
## Art is drawn at whole-number scales: joy_base 40 px x4, round 33 px x4 / x3 / x2.
const JOY_RADIUS: float = 80.0
const JOY_SCALE: float = 4.0
const JOY_IDLE_POS_FRACTION: Vector2 = Vector2(0.14, 0.7)
const ATTACK_RADIUS: float = 66.0
const ATTACK_SCALE: float = 4.0
const ATTACK_MARGIN: Vector2 = Vector2(96, 92)
const SKILL_RADIUS: float = 50.0
const SKILL_SCALE: float = 3.0
const SKILL_OFFSET: Vector2 = Vector2(-152, 24)
## Slot 1's button sits above slot 0's.
const SPECIAL_RADIUS: float = 50.0
const SPECIAL_SCALE: float = 3.0
const SPECIAL_OFFSET: Vector2 = Vector2(-140, -104)
const HIT_SLOP: float = 1.25
const PRESS_DROP: float = 4.0
const AIM_LINE_WIDTH: float = 4.0
const SEGMENTS: int = 32
const IDLE_ALPHA: float = 0.75
const COLOR_COOLDOWN: Color = Color(0.1, 0.1, 0.18, 0.7)
const COLOR_AIM: Color = Color(1, 0.45, 0.4, 0.85)
const NO_FINGER: int = -1

const TOUCH_FLAG: String = "--touch"

var player: Player
var blockers: Array[Control] = []
var move_vec: Vector2 = Vector2.ZERO
var attack_held: bool = false
## Zero unless the attack finger has been dragged past the deadzone.
var attack_aim: Vector2 = Vector2.ZERO
var skill_held: bool = false
var special_held: bool = false

var _joy_finger: int = NO_FINGER
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_pos: Vector2 = Vector2.ZERO
var _attack_finger: int = NO_FINGER
## Where the attack finger landed: drag-aim is measured from here, so pressing off-centre doesn't aim.
var _attack_origin: Vector2 = Vector2.ZERO
var _skill_finger: int = NO_FINGER
var _special_finger: int = NO_FINGER


func _ready() -> void:
	UiStyle.fit_to_safe_area(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## On for mobile/touchscreens, or desktop with --touch (mouse then emulates touch).
static func should_enable() -> bool:
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		return true
	if OS.get_cmdline_user_args().has(TOUCH_FLAG):
		Input.emulate_touch_from_mouse = true
		return true
	return false


func _attack_center() -> Vector2:
	return size - ATTACK_MARGIN


func _skill_center() -> Vector2:
	return _attack_center() + SKILL_OFFSET


func _special_center() -> Vector2:
	return _attack_center() + SPECIAL_OFFSET


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


func _blocked(p: Vector2) -> bool:
	var global_p: Vector2 = get_global_transform() * p
	for b: Control in blockers:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(global_p):
			return true
	return false


func _on_press(finger: int, p: Vector2) -> void:
	if _blocked(p):
		return
	if _attack_finger == NO_FINGER and _hits(p, _attack_center(), ATTACK_RADIUS):
		_attack_finger = finger
		_attack_origin = p
		attack_held = true
		attack_aim = Vector2.ZERO
	elif _skill_finger == NO_FINGER and _hits(p, _skill_center(), SKILL_RADIUS):
		_skill_finger = finger
		skill_held = true
	elif _special_finger == NO_FINGER and _hits(p, _special_center(), SPECIAL_RADIUS):
		_special_finger = finger
		special_held = true
	elif _joy_finger == NO_FINGER and p.x < size.x * JOYSTICK_ZONE_FRACTION:
		_joy_finger = finger
		_joy_origin = p
		_joy_pos = p
		move_vec = Vector2.ZERO
	queue_redraw()


func _on_drag(finger: int, p: Vector2) -> void:
	if finger == _joy_finger:
		# The base stays where the finger first landed until release; the knob is clamped to its ring.
		var offset: Vector2 = (p - _joy_origin).limit_length(JOY_RADIUS)
		_joy_pos = _joy_origin + offset
		move_vec = offset / JOY_RADIUS
	elif finger == _attack_finger:
		var drag: Vector2 = p - _attack_origin
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
	elif finger == _special_finger:
		_special_finger = NO_FINGER
		special_held = false
	queue_redraw()


func _process(_delta: float) -> void:
	# Cooldown sweeps change without input events.
	if visible:
		queue_redraw()


func _draw() -> void:
	# Joystick
	var active_joy: bool = _joy_finger != NO_FINGER
	var base: Vector2 = _joy_origin if active_joy else size * JOY_IDLE_POS_FRACTION
	var knob: Vector2 = _joy_pos if active_joy else base
	var joy_tint := Color(1, 1, 1, 1.0 if active_joy else IDLE_ALPHA)
	UiStyle.draw_icon(self, UiStyle.tex("joy_base"), base, JOY_SCALE, joy_tint)
	UiStyle.draw_icon(self, UiStyle.tex("joy_knob"), knob, JOY_SCALE, joy_tint)

	# Attack
	var ac: Vector2 = _attack_center()
	if attack_aim != Vector2.ZERO:
		draw_line(ac, ac + attack_aim.limit_length(ATTACK_RADIUS * 2.0), COLOR_AIM, AIM_LINE_WIDTH)
	_round(ac, "round_fire", ATTACK_SCALE, attack_held)
	UiStyle.draw_icon(self, UiStyle.tex("icon_fire"), ac + _drop(attack_held), ATTACK_SCALE)

	# The two specials, with cooldown sweeps
	if player != null:
		_skill_button(_skill_center(), SKILL_RADIUS, SKILL_SCALE, player.skills[0], skill_held, player.skill_locked(0))
		_skill_button(_special_center(), SPECIAL_RADIUS, SPECIAL_SCALE, player.skills[1], special_held, player.skill_locked(1))


func _skill_button(c: Vector2, radius: float, scale_px: float, sk: CharacterSkill, held: bool, locked: bool = false) -> void:
	_round(c, "round", scale_px, held)
	UiStyle.draw_icon(self, sk.data.icon, c + _drop(held), scale_px)
	if locked:  # the other special is mid-use: greyed out with a padlock, presses are ignored
		draw_circle(c, radius * 0.9, Color(0.1, 0.1, 0.14, 0.7))
		draw_arc(c, radius * 0.22, PI, TAU, 12, UiStyle.C_WHITE, 4.0)
		draw_rect(Rect2(c + Vector2(-radius * 0.3, -radius * 0.02), Vector2(radius * 0.6, radius * 0.45)), UiStyle.C_WHITE)
	elif sk.is_active():
		draw_arc(c, radius - 2.0, 0.0, TAU, SEGMENTS, UiStyle.C_TEAL_L, 4.0)
	elif not sk.is_ready():
		draw_arc(c, radius * 0.45, -PI * 0.5, -PI * 0.5 + TAU * sk.cooldown_fraction(), SEGMENTS,
			COLOR_COOLDOWN, radius * 0.9)
		var secs: String = str(ceili(sk.cooldown_remaining))
		var w: float = UiStyle.text_width(secs, UiStyle.SIZE_HEADING, true)
		UiStyle.draw_text(self, c + Vector2(-w * 0.5, UiStyle.SIZE_HEADING * 0.35), secs, UiStyle.SIZE_HEADING,
			UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


func _round(center: Vector2, art: String, scale_px: float, pressed: bool) -> void:
	var tint := Color(0.8, 0.8, 0.85, 1.0) if pressed else Color(1, 1, 1, IDLE_ALPHA)
	UiStyle.draw_icon(self, UiStyle.tex(art), center + _drop(pressed), scale_px, tint)


func _drop(pressed: bool) -> Vector2:
	return Vector2(0.0, PRESS_DROP if pressed else 0.0)
