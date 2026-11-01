class_name PauseMenu
extends Control
## Pause button (top right, under the status line; hidden in the lobby and results, which have their own Leave button) and
## its menu: Resume, Restart (offline), Leave.
## Offline the whole tree pauses while it's open; online the match keeps running underneath.
## Esc toggles it on desktop.

const BUTTON_SIZE: Vector2 = Vector2(64, 56)
const BUTTON_TOP: float = 28.0
const MENU_BUTTON_SIZE: Vector2 = Vector2(300, 64)
const SPACING: int = 14
const COLOR_VEIL: Color = Color(0.05, 0.05, 0.1, 0.6)

var arena: Arena

var button: Button
var menu: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var safe := Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	UiStyle.fit_to_safe_area(safe)
	button = _button("II", BUTTON_SIZE)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.position = Vector2(-BUTTON_SIZE.x, BUTTON_TOP)
	button.pressed.connect(open)
	safe.add_child(button)

	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	var veil := ColorRect.new()
	veil.color = COLOR_VEIL
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(veil)  # also swallows taps meant for the arena
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED" if arena.mode == Arena.Mode.OFFLINE else "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiStyle.bold())
	title.add_theme_font_size_override("font_size", UiStyle.SIZE_TITLE)
	box.add_child(title)
	var resume := _button("Resume", MENU_BUTTON_SIZE)
	resume.theme_type_variation = &"PrimaryButton"
	resume.pressed.connect(close)
	box.add_child(resume)
	if arena.mode == Arena.Mode.OFFLINE:
		var restart := _button("Restart", MENU_BUTTON_SIZE)
		restart.pressed.connect(_leave.bind(true))
		box.add_child(restart)
	var settings := _button("Settings", MENU_BUTTON_SIZE)
	settings.pressed.connect(func() -> void: SettingsPanel.show_on(self))
	box.add_child(settings)
	var leave := _button("Leave match", MENU_BUTTON_SIZE)
	leave.pressed.connect(_leave.bind(false))
	box.add_child(leave)
	add_child(menu)


func _process(_delta: float) -> void:
	button.visible = not is_open() and arena.match_state.phase in [MatchState.Phase.COUNTDOWN, MatchState.Phase.PLAYING]


func is_open() -> bool:
	return menu.visible


func open() -> void:
	menu.visible = true
	if arena.mode == Arena.Mode.OFFLINE:
		get_tree().paused = true


func close() -> void:
	menu.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		close() if is_open() else open()
		get_viewport().set_input_as_handled()


func _leave(restart: bool) -> void:
	get_tree().paused = false
	arena.leave_requested.emit(restart)


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b
