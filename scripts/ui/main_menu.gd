class_name MainMenu
extends Control
## Title screen: `TitleBackdrop` (arena, roster, logo) behind the menu, `IntroSplash` on first show,
## then Play vs bots (primary) and join-a-server by IP (direct connect until matchmaking in M6).

signal offline_pressed
signal host_pressed
signal join_pressed(address: String)

## `--fake-keyboard N`: pretend an N-unit tall on-screen keyboard is up (desktop layout checks).
const FAKE_KEYBOARD_FLAG: String = "--fake-keyboard"
const BUTTON_MIN_SIZE: Vector2 = Vector2(360, 64)
const FIELD_MIN_SIZE: Vector2 = Vector2(236, 64)
const SPACING: int = 12
const GAME_LABEL_W: float = 430.0

var _status: Label
var _address: LineEdit
var _join: Button
var _host: Button
var _box: VBoxContainer
var _hide_while_typing: Array[Control] = []
var _browser: LanDiscovery
var _games_box: VBoxContainer
var _ip_row: Control
var _ip_toggle: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := TitleBackdrop.new()
	add_child(backdrop)

	var box := VBoxContainer.new()
	_box = box
	box.add_theme_constant_override("separation", SPACING)
	box.alignment = BoxContainer.ALIGNMENT_END
	add_child(box)
	UiStyle.fit_to_safe_area(box)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UiStyle.C_ORANGE)
	box.add_child(_status)

	var offline := _button("PLAY VS BOTS", BUTTON_MIN_SIZE)
	offline.theme_type_variation = &"PrimaryButton"
	offline.add_theme_font_size_override("font_size", UiStyle.SIZE_HEADING)
	offline.add_child(ButtonShine.new())
	offline.pressed.connect(offline_pressed.emit)
	var offline_row := _centered(offline)
	box.add_child(offline_row)
	_hide_while_typing.append(offline_row)

	_games_box = VBoxContainer.new()
	_games_box.add_theme_constant_override("separation", SPACING)
	box.add_child(_games_box)
	_hide_while_typing.append(_games_box)
	_browser = LanDiscovery.new()
	add_child(_browser)
	_browser.games_changed.connect(_refresh_games)
	visibility_changed.connect(_sync_browser)
	_sync_browser()

	_ip_toggle = _button("Enter IP", Vector2(BUTTON_MIN_SIZE.x, FIELD_MIN_SIZE.y))
	_ip_toggle.pressed.connect(func() -> void: _ip_row.visible = not _ip_row.visible)
	var toggle_row := _centered(_ip_toggle)
	box.add_child(toggle_row)
	_hide_while_typing.append(toggle_row)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", SPACING)
	_address = LineEdit.new()
	_address.text = LanAddress.prefill(LanAddress.load_last(), LanAddress.local())
	_address.placeholder_text = "192.168.1.42"
	_address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_address.caret_column = _address.text.length()
	_address.custom_minimum_size = FIELD_MIN_SIZE
	_address.text_submitted.connect(func(_t: String) -> void: _on_join())
	join_row.add_child(_address)
	_join = _button("Join", Vector2(BUTTON_MIN_SIZE.x - FIELD_MIN_SIZE.x - SPACING, FIELD_MIN_SIZE.y))
	_join.pressed.connect(_on_join)
	join_row.add_child(_join)
	_ip_row = _centered(join_row)
	_ip_row.visible = false  # manual IP is the fallback; "Enter IP" reveals it
	box.add_child(_ip_row)

	_host = _button("HOST A GAME ON THIS WI-FI", Vector2(BUTTON_MIN_SIZE.x, FIELD_MIN_SIZE.y))
	_host.pressed.connect(host_pressed.emit)
	var host_row := _centered(_host)
	box.add_child(host_row)
	_hide_while_typing.append(host_row)
	var settings := _button("Settings", Vector2(BUTTON_MIN_SIZE.x, FIELD_MIN_SIZE.y))
	settings.pressed.connect(func() -> void: SettingsPanel.show_on(self))
	var settings_row := _centered(settings)
	box.add_child(settings_row)
	_hide_while_typing.append(settings_row)
	add_child(IntroSplash.new(backdrop, box))  # first-launch opening; skippable


## Browse only while the menu is showing (the socket is closed during a match).
func _sync_browser() -> void:
	if is_visible_in_tree():
		if _browser.mode != LanDiscovery.Mode.BROWSE:
			_browser.start_browse()
		_refresh_games()
	else:
		_browser.stop()


func _refresh_games() -> void:
	for c: Node in _games_box.get_children():
		c.queue_free()
		_games_box.remove_child(c)
	if _browser.games.is_empty():
		var l := Label.new()
		l.text = "Looking for games on this Wi-Fi..."
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", UiStyle.C_DIM)
		_games_box.add_child(l)
		return
	var keys: Array = _browser.games.keys()
	keys.sort()
	for k: Variant in keys:
		var g: Dictionary = _browser.games[k]
		var info: Dictionary = g["info"]
		var ok: bool = info["compatible"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING)
		var l := Label.new()
		l.text = LanDiscovery.label(info) if ok else "%s · different version" % info["name"]
		l.custom_minimum_size = Vector2(GAME_LABEL_W, 0)
		l.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		if not ok:
			l.add_theme_color_override("font_color", UiStyle.C_DIM)
		row.add_child(l)
		var b := _button("JOIN", Vector2(108, FIELD_MIN_SIZE.y))
		b.disabled = not ok
		var addr: String = "%s:%d" % [g["ip"], info["port"]]
		b.pressed.connect(func() -> void:
			_address.text = addr
			_on_join())
		row.add_child(b)
		var panel := PanelContainer.new()
		panel.add_child(row)
		_games_box.add_child(_centered(panel))


func set_status(text: String) -> void:
	_status.text = text
	_join.disabled = false


func _process(_delta: float) -> void:
	_lift_above_keyboard()


## While the on-screen keyboard is up, hide the other buttons and raise the address row above it.
func _lift_above_keyboard() -> void:
	var lift: float = _keyboard_height()
	var typing: bool = lift > 0.0 and (_address.has_focus() or _fake_keyboard() > 0.0)
	for row: Control in _hide_while_typing:
		row.visible = not typing
	var insets: Vector4 = UiStyle.safe_insets(get_viewport())
	_box.offset_bottom = -(insets.w + (lift if typing else 0.0)) - (SPACING if typing else 0)


## Keyboard height in canvas units (0 when closed).
func _keyboard_height() -> float:
	var fake: float = _fake_keyboard()
	if fake > 0.0:
		return fake
	var win_h: float = float(DisplayServer.window_get_size().y)
	if win_h <= 0.0:
		return 0.0
	return float(DisplayServer.virtual_keyboard_get_height()) * get_viewport().get_visible_rect().size.y / win_h


func _fake_keyboard() -> float:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find(FAKE_KEYBOARD_FLAG)
	return args[i + 1].to_float() if i >= 0 and i + 1 < args.size() else 0.0


func _on_join() -> void:
	DisplayServer.virtual_keyboard_hide()
	_address.release_focus()
	_join.disabled = true
	_status.text = "Connecting..."
	join_pressed.emit(_address.text)


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b


func _centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc
