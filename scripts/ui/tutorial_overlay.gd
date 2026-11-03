class_name TutorialOverlay
extends CanvasLayer
## The Training match's guide: a big prompt banner, a pulsing ring + arrow on the touch button to use, a Skip button
## and, on the last step, a button back to the menu. It watches the arena and feeds `TutorialFlow`; the step rules
## live there. Mounted by `Main._start_offline(true)` on the offline arena.

signal exit_requested

const LAYER_INDEX: int = 2
const BANNER_W: float = 760.0
const BANNER_TOP: float = 78.0
const SKIP_SIZE: Vector2 = Vector2(200, UiStyle.TOUCH_MIN_H)
const RING_RADIUS: float = 76.0
const RING_PULSE: float = 10.0
const RING_PULSE_HZ: float = 2.2
const ARROW_GAP: float = 30.0
const ARROW_SIZE: float = 22.0
const ARROW_BOB: float = 8.0
const SLOT_ACTIONS: Array[StringName] = [&"skill", &"special", &"special2"]
const COLOR_RING: Color = Color(1, 0.95, 0.6, 0.95)

var flow := TutorialFlow.new()
var arena: Arena
var player: Player
var bot: Player

var _touch: TouchControls
var _canvas: Control
var _panel: PanelContainer
var _counter: Label
var _prompt: Label
var _progress: Label
var _skip: Button
var _done: Button
var _held: Array[bool] = [false, false, false]
var _last_pos: Vector2 = Vector2.INF
var _time: float = 0.0


func _ready() -> void:
	layer = LAYER_INDEX
	player = arena.local_player
	player.min_hp = TutorialFlow.MIN_HP
	for t: Node in arena.find_children("*", "TouchControls", true, false):
		_touch = t as TouchControls
	arena.player_hit.connect(_on_player_hit)
	arena.kill_registered.connect(_on_kill)
	flow.step_changed.connect(_on_step)
	flow.finished.connect(_on_finished)
	_build()
	_refresh()


## Training bot: very easy, and the player can't die (`Player.min_hp`).
static func setup_bot(bot_player: Player) -> void:
	(bot_player.controller as BotBrain).skill = TutorialFlow.BOT_SKILL


func _build() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_highlight)
	add_child(_canvas)
	var insets: Vector4 = UiStyle.safe_insets(get_viewport())

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = maxf(insets.y, 0.0) + BANNER_TOP
	_panel.custom_minimum_size = Vector2(BANNER_W, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	_counter = _label(UiStyle.SIZE_SMALL, UiStyle.C_TEAL_L, false)
	col.add_child(_counter)
	_prompt = _label(UiStyle.SIZE_HEADING, UiStyle.C_WHITE, true)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_prompt)
	_progress = _label(UiStyle.SIZE_BODY, UiStyle.C_YELLOW, true)
	col.add_child(_progress)

	_skip = Button.new()
	_skip.text = "SKIP"
	_skip.custom_minimum_size = SKIP_SIZE
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_bottom = -maxf(insets.w, 0.0) - 16.0
	_skip.pressed.connect(flow.skip)
	_canvas.add_child(_skip)

	_done = Button.new()
	_done.text = "BACK TO MENU"
	_done.theme_type_variation = &"PrimaryButton"
	_done.custom_minimum_size = Vector2(380, UiStyle.TOUCH_MIN_H)
	_done.focus_mode = Control.FOCUS_NONE
	_done.set_anchors_preset(Control.PRESET_CENTER)
	_done.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_done.grow_vertical = Control.GROW_DIRECTION_BOTH
	_done.pressed.connect(flow.finish)
	_canvas.add_child(_done)

	if _touch != null:  # taps on our buttons must not also reach the stick / fire zones
		_touch.blockers.append(_skip)
		_touch.blockers.append(_done)


func _label(size: int, color: Color, heavy: bool) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if heavy:
		l.add_theme_font_override("font", UiStyle.body_font(true))
	return l


func _touch_on() -> bool:
	return _touch != null and _touch.visible


func _refresh() -> void:
	var s: TutorialFlow.Step = flow.step
	_counter.text = "TRAINING  %d / %d" % [mini(s + 1, TutorialFlow.Step.DONE), TutorialFlow.Step.DONE] \
		if s != TutorialFlow.Step.DONE else "TRAINING COMPLETE"
	_prompt.text = TutorialFlow.prompt(s, _touch_on())
	_progress.text = flow.progress_text()
	_progress.visible = _progress.text != ""
	_done.visible = s == TutorialFlow.Step.DONE
	_skip.visible = not _done.visible


func _on_step(_s: TutorialFlow.Step) -> void:
	_fill_ultimate_charge()
	_refresh()
	_canvas.queue_redraw()


## TRAINING STUB: stands in for the real ultimate charge. Slot 2 is a plain cooldown skill in this tree, so "charged" =
## ready now. Replace the body with the ultimate-charge API (fill the charge to full) when it exists.
func _fill_ultimate_charge() -> void:
	if flow.step == TutorialFlow.Step.ULTIMATE and is_instance_valid(player):
		player.skills[TutorialFlow.ULTIMATE_SLOT].cooldown_remaining = 0.0


func _on_player_hit(owner_id: int, _seq: int, _pellet: int, victim_id: int, _dmg: int, _crit: bool,
		_at: Vector2) -> void:
	if owner_id == player.player_id and victim_id == bot.player_id:
		flow.add_hit()
		_refresh()


func _on_kill(killer_id: int, victim_id: int) -> void:
	if killer_id == player.player_id and victim_id == bot.player_id:
		flow.bot_defeated()


func _on_finished(_skipped: bool) -> void:
	GameSettings.save()
	exit_requested.emit()


func _physics_process(_delta: float) -> void:
	if flow.is_finished or arena.match_state.phase != MatchState.Phase.PLAYING or not is_instance_valid(player):
		return
	var pos: Vector2 = player.global_position
	if _last_pos != Vector2.INF and not player.dead and _is_steering():
		flow.add_travel(pos.distance_to(_last_pos))
	_last_pos = pos
	for slot: int in SLOT_ACTIONS.size():
		var down: bool = Input.is_action_pressed(SLOT_ACTIONS[slot]) or _touch_slot_held(slot)
		if down and not _held[slot]:
			flow.slot_pressed(slot)
		_held[slot] = down
	_fill_ultimate_charge()
	_refresh()


func _is_steering() -> bool:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down") != Vector2.ZERO \
		or (_touch_on() and _touch.move_vec != Vector2.ZERO)


func _touch_slot_held(slot: int) -> bool:
	if not _touch_on():
		return false
	return bool([_touch.skill_held, _touch.special_held, _touch.special2_held][slot])


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()


## Buttons to point at for the current step: TouchControls slot numbers, `BUTTON_FIRE` or `BUTTON_STICK`.
func highlight_targets() -> Array[int]:
	match flow.step:
		TutorialFlow.Step.MOVE:
			return [TouchControls.BUTTON_STICK]
		TutorialFlow.Step.SHOOT, TutorialFlow.Step.DEFEAT:
			return [TouchControls.BUTTON_FIRE]
		TutorialFlow.Step.ABILITY:
			return [0, 1]
		TutorialFlow.Step.ULTIMATE:
			return [TutorialFlow.ULTIMATE_SLOT]
	return []


func _draw_highlight() -> void:
	if not _touch_on():
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * TAU * RING_PULSE_HZ)
	for which: int in highlight_targets():
		var c: Vector2 = _touch.button_center(which)
		_canvas.draw_arc(c, RING_RADIUS + RING_PULSE * pulse, 0.0, TAU, 40, COLOR_RING, 6.0)
		var tip := c + Vector2(0.0, -(RING_RADIUS + ARROW_GAP + ARROW_BOB * pulse))
		_canvas.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-ARROW_SIZE, -ARROW_SIZE * 1.4),
			tip + Vector2(ARROW_SIZE, -ARROW_SIZE * 1.4)]), COLOR_RING)
