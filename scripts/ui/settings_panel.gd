class_name SettingsPanel
extends Control
## Modal overlay with the volume sliders, the haptics toggle and a short controls guide. `show_on` mounts it on its
## own top CanvasLayer (works from the main menu and the pause menu, and while the tree is paused).
## `show_howto` opens it straight on the controls page (first launch).

const LAYER: int = 110
const PANEL_MIN_SIZE: Vector2 = Vector2(620, 0)
const SPACING: int = 14
const BUTTON_SIZE: Vector2 = Vector2(240, 60)
const SLIDER_MIN_SIZE: Vector2 = Vector2(280, 36)
const COLOR_VEIL: Color = Color(0.05, 0.05, 0.1, 0.8)
const HOWTO: Array[String] = [
	"MOVE   drag anywhere on the left side",
	"SHOOT   hold the big button (auto-aims; drag it to aim yourself)",
	"SPECIALS   the two round buttons, each with a cooldown",
	"WIN   score kills before the timer ends; armor regenerates, HP does not",
	"Desktop: WASD move, mouse aim, J / click fire, Space and E specials, Esc pause",
]

var _settings_page: Control
var _howto_page: Control
var _on_close: Callable
var _start_on_howto: bool = false


static func show_on(host: Node, howto_first: bool = false) -> void:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := SettingsPanel.new()
	panel._on_close = layer.queue_free
	panel._start_on_howto = howto_first
	layer.add_child(panel)
	host.get_tree().root.add_child.call_deferred(layer)


## Marks the controls guide as seen and shows it once, on a player's first match.
static func show_howto_once(host: Node) -> void:
	GameSettings.ensure_loaded()
	if GameSettings.howto_seen or DisplayServer.get_name() == "headless":
		return
	GameSettings.howto_seen = true
	GameSettings.save()
	show_on(host, true)


func _ready() -> void:
	GameSettings.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = COLOR_VEIL
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)  # swallows taps meant for what's underneath
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_MIN_SIZE
	center.add_child(panel)
	var pages := VBoxContainer.new()
	panel.add_child(pages)
	_settings_page = _build_settings()
	_howto_page = _build_howto()
	pages.add_child(_settings_page)
	pages.add_child(_howto_page)
	_show_page(not _start_on_howto)


func _show_page(settings: bool) -> void:
	_settings_page.visible = settings
	_howto_page.visible = not settings


func _build_settings() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	box.add_child(_title("SETTINGS"))
	_slider_row(box, "Music", GameSettings.music, func(v: float) -> void:
		GameSettings.music = v
		for m: Node in get_tree().get_nodes_in_group(&"music"):
			(m as Music).apply_volume())
	_slider_row(box, "Sound effects", GameSettings.sfx, func(v: float) -> void: GameSettings.sfx = v)
	var haptics := CheckButton.new()
	haptics.text = "Vibration"
	haptics.button_pressed = GameSettings.haptics
	haptics.focus_mode = Control.FOCUS_NONE
	haptics.toggled.connect(func(on: bool) -> void:
		GameSettings.haptics = on
		GameSettings.vibrate(Constants.HAPTIC_KILL_MS))
	box.add_child(haptics)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SPACING)
	box.add_child(row)
	var howto := _button("How to play")
	howto.pressed.connect(_show_page.bind(false))
	row.add_child(howto)
	var done := _button("Done")
	done.theme_type_variation = &"PrimaryButton"
	done.pressed.connect(_close)
	row.add_child(done)
	return box


func _build_howto() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	box.add_child(_title("HOW TO PLAY"))
	for line: String in HOWTO:
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = PANEL_MIN_SIZE.x - 60
		box.add_child(l)
	var ok := _button("Got it")
	ok.theme_type_variation = &"PrimaryButton"
	ok.pressed.connect(_close)
	var row := CenterContainer.new()
	row.add_child(ok)
	box.add_child(row)
	return box


func _close() -> void:
	GameSettings.save()
	if _on_close.is_valid():
		_on_close.call()


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiStyle.bold())
	l.add_theme_font_size_override("font_size", UiStyle.SIZE_HEADING)
	return l


func _slider_row(parent: Node, text: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING)
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = SLIDER_MIN_SIZE
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(on_change)
	row.add_child(s)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.focus_mode = Control.FOCUS_NONE
	return b
