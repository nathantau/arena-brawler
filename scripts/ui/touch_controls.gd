class_name TouchControls
extends Control
## Multi-touch mobile controls inside the safe area, drawn with the pixel UI kit:
## - fixed joystick bottom-left (a touch anywhere on the left part of the screen steers the knob)
## - attack button (hold = fire with auto-aim; drag off-centre = manual aim, a knob follows the thumb)
## - three skill buttons, one per equipped special (skill icon, cooldown sweep + seconds). A skill casts when the finger lifts:
##   a tap is auto-aimed, a drag past the deadzone casts that way (dragging back inside it cancels to auto-aim)
## Touches that start on a visible `blockers` control (e.g. lobby buttons) are left to the GUI.

const JOYSTICK_ZONE_FRACTION: float = 0.45
## Art is drawn at whole-number scales: joy_base 40 px x4, round 33 px x4 / x3 / x2.
const JOY_RADIUS: float = 80.0
const JOY_SCALE: float = 4.0
## Joystick centre, from the bottom-left corner of the safe area.
const JOY_MARGIN: Vector2 = Vector2(132, 108)
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
## Slot 2's button sits straight above FIRE (clear of its hit area, so the thumb never grazes both).
const SPECIAL2_RADIUS: float = 50.0
const SPECIAL2_SCALE: float = 3.0
const SPECIAL2_OFFSET: Vector2 = Vector2(0, -152)
const HIT_SLOP: float = 1.25
const PRESS_DROP: float = 4.0
## The aim knob (joy_knob art) on a dragged button, at these whole-number scales.
const ATTACK_KNOB_SCALE: float = 3.0
const SKILL_KNOB_SCALE: float = 2.0
## A released skill button holds its flag this many physics frames so the sim sees one press edge.
const CAST_PULSE_FRAMES: int = 2
const SLOT_RADII: Array[float] = [SKILL_RADIUS, SPECIAL_RADIUS, SPECIAL2_RADIUS]
const SEGMENTS: int = 32
const IDLE_ALPHA: float = 0.75
const COLOR_COOLDOWN: Color = Color(0.1, 0.1, 0.18, 0.7)
const NO_FINGER: int = -1
## A special coming off cooldown pulses a ring that grows this far past the button for this long.
const READY_PULSE_TIME: float = 0.45
const READY_PULSE_GROW: float = 22.0
const COLOR_READY: Color = Color(1, 0.95, 0.6, 0.9)
## Ultimate button: gold ready glow (pulses ULT_PULSE_HZ), the charge fill while it fills.
const COLOR_ULT: Color = Color(1.0, 0.82, 0.2, 1.0)
const COLOR_ULT_FILL: Color = Color(1.0, 0.8, 0.2, 0.5)
const ULT_PULSE_HZ: float = 1.6
const ULT_GLOW_GROW: float = 6.0

const BUTTON_FIRE: int = -1
const BUTTON_STICK: int = -2
const TOUCH_FLAG: String = "--touch"

var player: Player
var blockers: Array[Control] = []
var move_vec: Vector2 = Vector2.ZERO
var attack_held: bool = false
## Zero unless the attack finger has been dragged past the deadzone.
var attack_aim: Vector2 = Vector2.ZERO
## Skill flags are one-shot casts: set when the finger lifts (a tap, or a drag released with `cast_aim`), cleared a couple of frames later.
var skill_held: bool = false
var special_held: bool = false
var special2_held: bool = false
## Per skill slot: the drag while its finger is down (zero inside the deadzone), and the aim the last cast carries (zero = auto-aim).
var skill_aim: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var cast_aim: Vector2 = Vector2.ZERO

## Called when a special comes off cooldown (Arena plays the sound).
var ready_sfx: Callable

var _joy_finger: int = NO_FINGER
var _joy_pos: Vector2 = Vector2.ZERO
var _attack_finger: int = NO_FINGER
## Where the attack finger landed: drag-aim is measured from here, so pressing off-centre doesn't aim.
var _attack_origin: Vector2 = Vector2.ZERO
var _slot_fingers: Array[int] = [NO_FINGER, NO_FINGER, NO_FINGER]
var _slot_origins: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _pulse_left: Array[int] = [0, 0, 0]
## Per special button: was it on cooldown last frame, and how long the "ready" pulse has left.
var _was_cooling: Array[bool] = [false, false, false]
var _pulse: Array[float] = [0.0, 0.0, 0.0]


func _ready() -> void:
	UiStyle.fit_to_safe_area(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(func() -> void:
		if not visible:
			release_all())


## Let go of every finger. Called when something swallows the touch events (pause menu, app backgrounded,
## controls hidden, a cancelled touch) so the stick / fire / specials can't stay held with nobody touching.
func release_all() -> void:
	_joy_finger = NO_FINGER
	_attack_finger = NO_FINGER
	_slot_fingers = [NO_FINGER, NO_FINGER, NO_FINGER]
	_pulse_left = [0, 0, 0]
	skill_aim = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	cast_aim = Vector2.ZERO
	move_vec = Vector2.ZERO
	attack_held = false
	attack_aim = Vector2.ZERO
	skill_held = false
	special_held = false
	special2_held = false
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		release_all()


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


func _joy_center() -> Vector2:
	return Vector2(JOY_MARGIN.x, size.y - JOY_MARGIN.y)


func _skill_center() -> Vector2:
	return _attack_center() + SKILL_OFFSET


func _special_center() -> Vector2:
	return _attack_center() + SPECIAL_OFFSET


func _special2_center() -> Vector2:
	return _attack_center() + SPECIAL2_OFFSET


## Centre of the button for skill slot `i`.
func _slot_center(i: int) -> Vector2:
	return [_skill_center(), _special_center(), _special2_center()][i]


## Screen position of a button's centre, for the tutorial highlight: slot 0..2, or `BUTTON_FIRE` / `BUTTON_STICK`.
func button_center(which: int) -> Vector2:
	var local: Vector2 = _attack_center() if which == BUTTON_FIRE else _joy_center() if which == BUTTON_STICK \
		else _slot_center(which)
	return get_global_transform() * local


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := make_input_local(event) as InputEventScreenTouch
		if t.canceled:
			release_all()
		elif t.pressed:
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


## The skill slot whose free button is under `p`, else -1.
func _slot_at(p: Vector2) -> int:
	for i: int in Constants.SKILL_SLOTS:
		if _slot_fingers[i] == NO_FINGER and _hits(p, _slot_center(i), SLOT_RADII[i]):
			return i
	return -1


func _set_slot_held(slot: int, on: bool) -> void:
	match slot:
		0: skill_held = on
		1: special_held = on
		_: special2_held = on


func _on_press(finger: int, p: Vector2) -> void:
	if _blocked(p):
		return
	if _attack_finger == NO_FINGER and _hits(p, _attack_center(), ATTACK_RADIUS):
		_attack_finger = finger
		_attack_origin = p
		attack_held = true
		attack_aim = Vector2.ZERO
	elif _slot_at(p) >= 0:
		var slot: int = _slot_at(p)
		_slot_fingers[slot] = finger
		_slot_origins[slot] = p
		skill_aim[slot] = Vector2.ZERO
	elif _joy_finger == NO_FINGER and p.x < size.x * JOYSTICK_ZONE_FRACTION:
		_joy_finger = finger
		_on_drag(finger, p)
	queue_redraw()


func _on_drag(finger: int, p: Vector2) -> void:
	if finger == _joy_finger:
		var offset: Vector2 = (p - _joy_center()).limit_length(JOY_RADIUS)
		_joy_pos = _joy_center() + offset
		move_vec = offset / JOY_RADIUS
	elif finger == _attack_finger:
		var drag: Vector2 = p - _attack_origin
		attack_aim = drag if drag.length() > Constants.DRAG_AIM_DEADZONE_PX else Vector2.ZERO
	elif _slot_fingers.has(finger):
		var slot: int = _slot_fingers.find(finger)
		var drag: Vector2 = p - _slot_origins[slot]
		skill_aim[slot] = drag if drag.length() > Constants.DRAG_AIM_DEADZONE_PX else Vector2.ZERO
	queue_redraw()


func _on_release(finger: int) -> void:
	if finger == _joy_finger:
		_joy_finger = NO_FINGER
		move_vec = Vector2.ZERO
	elif finger == _attack_finger:
		_attack_finger = NO_FINGER
		attack_held = false
		attack_aim = Vector2.ZERO
	elif _slot_fingers.has(finger):  # the cast: a tap (zero aim) is auto-aimed, a drag goes where it was dragged
		var slot: int = _slot_fingers.find(finger)
		_slot_fingers[slot] = NO_FINGER
		cast_aim = skill_aim[slot]
		skill_aim[slot] = Vector2.ZERO
		_set_slot_held(slot, true)
		_pulse_left[slot] = CAST_PULSE_FRAMES
	queue_redraw()


func _physics_process(_delta: float) -> void:
	for i: int in Constants.SKILL_SLOTS:
		if _pulse_left[i] > 0:
			_pulse_left[i] -= 1
			if _pulse_left[i] == 0:
				_set_slot_held(i, false)
	if cast_aim != Vector2.ZERO and _pulse_left == [0, 0, 0]:
		cast_aim = Vector2.ZERO


func _process(delta: float) -> void:
	# Cooldown sweeps change without input events.
	if not visible:
		return
	if player != null and is_instance_valid(player):
		for i: int in Constants.SKILL_SLOTS:
			var sk: CharacterSkill = player.skills[i]
			var ult: bool = i == Constants.ULT_SLOT
			var cooling: bool = (not player.ult_ready() and sk.data != Player.NO_ULT) if ult \
				else not sk.is_ready() and not sk.is_active()
			if _was_cooling[i] and (player.ult_ready() if ult else sk.is_ready()) and not player.dead:
				_pulse[i] = READY_PULSE_TIME
				if ready_sfx != null:
					ready_sfx.call()
				if ult:
					GameSettings.vibrate(Constants.HAPTIC_ULT_MS)
			_was_cooling[i] = cooling
			_pulse[i] = maxf(0.0, _pulse[i] - delta)
	queue_redraw()


func _draw() -> void:
	# Joystick
	var active_joy: bool = _joy_finger != NO_FINGER
	var base: Vector2 = _joy_center()
	var knob: Vector2 = _joy_pos if active_joy else base
	var joy_tint := Color(1, 1, 1, 1.0 if active_joy else IDLE_ALPHA)
	UiStyle.draw_icon(self, UiStyle.tex("joy_base"), base, JOY_SCALE, joy_tint)
	UiStyle.draw_icon(self, UiStyle.tex("joy_knob"), knob, JOY_SCALE, joy_tint)

	# Attack
	var ac: Vector2 = _attack_center()
	_round(ac, "round_fire", ATTACK_SCALE, attack_held)
	UiStyle.draw_icon(self, UiStyle.tex("icon_fire"), ac + _drop(attack_held), ATTACK_SCALE)
	if attack_aim != Vector2.ZERO:
		_knob(ac, attack_aim, ATTACK_RADIUS, ATTACK_KNOB_SCALE)

	# The three specials, with cooldown sweeps
	if player != null and is_instance_valid(player):
		_skill_button(_skill_center(), SKILL_RADIUS, SKILL_SCALE, player.skills[0], _down(0), player.skill_locked(0))
		_skill_button(_special_center(), SPECIAL_RADIUS, SPECIAL_SCALE, player.skills[1], _down(1), player.skill_locked(1))
		_ult_button(_special2_center(), SPECIAL2_RADIUS, SPECIAL2_SCALE, _down(2))
		for i: int in Constants.SKILL_SLOTS:
			if skill_aim[i] != Vector2.ZERO:
				_knob(_slot_center(i), skill_aim[i], SLOT_RADII[i], SKILL_KNOB_SCALE)
			if _pulse[i] > 0.0:
				var k: float = 1.0 - _pulse[i] / READY_PULSE_TIME
				var c: Vector2 = _slot_center(i)
				var r: float = SKILL_RADIUS + READY_PULSE_GROW * k
				draw_arc(c, r, 0.0, TAU, SEGMENTS, Color(COLOR_READY, COLOR_READY.a * (1.0 - k)), 4.0)


func _skill_button(c: Vector2, radius: float, scale_px: float, sk: CharacterSkill, held: bool, locked: bool = false) -> void:
	_round(c, "round", scale_px, held)
	UiStyle.draw_icon(self, sk.data.icon, c + _drop(held), scale_px)
	if locked:  # the other special is mid-use: lightly dimmed (icon still readable), small padlock badge, presses ignored
		draw_circle(c, radius * 0.9, Color(0.1, 0.1, 0.14, 0.35))
		var b: Vector2 = c + Vector2(radius * 0.62, radius * 0.62)
		draw_circle(b, radius * 0.34, Color(0.1, 0.1, 0.14, 0.9))
		draw_arc(b + Vector2(0.0, -radius * 0.04), radius * 0.11, PI, TAU, 10, UiStyle.C_WHITE, 3.0)
		draw_rect(Rect2(b + Vector2(-radius * 0.15, -radius * 0.04), Vector2(radius * 0.3, radius * 0.22)), UiStyle.C_WHITE)
	elif sk.is_active():
		draw_arc(c, radius - 2.0, 0.0, TAU, SEGMENTS, UiStyle.C_TEAL_L, 4.0)
	elif not sk.is_ready():
		draw_arc(c, radius * 0.45, -PI * 0.5, -PI * 0.5 + TAU * sk.cooldown_fraction(), SEGMENTS,
			COLOR_COOLDOWN, radius * 0.9)
		var secs: String = str(ceili(sk.cooldown_remaining))
		var w: float = UiStyle.text_width(secs, UiStyle.SIZE_HEADING, true)
		UiStyle.draw_text(self, c + Vector2(-w * 0.5, UiStyle.SIZE_HEADING * 0.35), secs, UiStyle.SIZE_HEADING,
			UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


## The ultimate: greyed out without one, a radial charge fill while it charges, a pulsing gold glow when full.
func _ult_button(c: Vector2, radius: float, scale_px: float, held: bool) -> void:
	var sk: CharacterSkill = player.skills[Constants.ULT_SLOT]
	if sk.data == Player.NO_ULT:
		_round(c, "round", scale_px, false)
		draw_circle(c, radius * 0.9, Color(0.1, 0.1, 0.14, 0.6))
		return
	_skill_button(c, radius, scale_px, sk, held, player.skill_locked(Constants.ULT_SLOT))
	if player.ult_ready():
		var k: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * ULT_PULSE_HZ)
		draw_arc(c, radius + ULT_GLOW_GROW * k, 0.0, TAU, SEGMENTS, Color(COLOR_ULT, 0.45 + 0.5 * k), 5.0 + 3.0 * k)
	elif not sk.is_active():
		draw_circle(c, radius * 0.9, Color(0.1, 0.1, 0.14, 0.45))
		draw_arc(c, radius * 0.45, -PI * 0.5, -PI * 0.5 + TAU * player.ult_charge, SEGMENTS, COLOR_ULT_FILL, radius * 0.9)
		var pct: String = "%d%%" % floori(player.ult_charge * 100.0)
		var w: float = UiStyle.text_width(pct, UiStyle.SIZE_SMALL, true)
		UiStyle.draw_text(self, c + Vector2(-w * 0.5, UiStyle.SIZE_SMALL * 0.35), pct, UiStyle.SIZE_SMALL,
			UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


## A finger is on skill slot `i`'s button.
func _down(i: int) -> bool:
	return _slot_fingers[i] != NO_FINGER


## The aim knob: follows the thumb, held inside the button's radius like the move stick's.
func _knob(center: Vector2, drag: Vector2, radius: float, scale_px: float) -> void:
	UiStyle.draw_icon(self, UiStyle.tex("joy_knob"), center + drag.limit_length(radius), scale_px)


func _round(center: Vector2, art: String, scale_px: float, pressed: bool) -> void:
	var tint := Color(0.8, 0.8, 0.85, 1.0) if pressed else Color(1, 1, 1, IDLE_ALPHA)
	UiStyle.draw_icon(self, UiStyle.tex(art), center + _drop(pressed), scale_px, tint)


func _drop(pressed: bool) -> Vector2:
	return Vector2(0.0, PRESS_DROP if pressed else 0.0)
