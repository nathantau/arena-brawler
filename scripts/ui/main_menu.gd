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
const PLAY_SIZE: Vector2 = Vector2(560, 100)
const PLAY_FONT: int = 44
const ROW_H: float = 56.0
## Menu column width (centred under the logo).
const CENTRE_W: float = 620.0
const SPACING: int = 10
const SHOT_FLAG: String = "--home-shot="
const SHOT_DELAY: float = 2.0
const GAME_LABEL_W: float = 430.0

var _status: Label
var _address: LineEdit
var _join: Button
var _host: Button
var _box: VBoxContainer
var _backdrop: TitleBackdrop
var _hide_while_typing: Array[Control] = []
var _browser: LanDiscovery
var _games_box: VBoxContainer
var _ip_row: Control
var _ip_toggle: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := TitleBackdrop.new()
	add_child(backdrop)
	_backdrop = backdrop

	var box := VBoxContainer.new()
	_box = box
	box.add_theme_constant_override("separation", SPACING)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(box)
	_place_box()
	get_viewport().size_changed.connect(_place_box)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UiStyle.C_ORANGE)

	var offline := _button("PLAY VS BOTS", PLAY_SIZE)
	offline.theme_type_variation = &"PrimaryButton"
	offline.add_theme_font_size_override("font_size", PLAY_FONT)
	offline.add_child(ButtonShine.new())
	offline.pressed.connect(offline_pressed.emit)
	var offline_row := _centered(offline)
	box.add_child(offline_row)
	_hide_while_typing.append(offline_row)
	box.add_child(_status)

	_games_box = VBoxContainer.new()
	_games_box.add_theme_constant_override("separation", SPACING)
	box.add_child(_games_box)
	_hide_while_typing.append(_games_box)
	_browser = LanDiscovery.new()
	add_child(_browser)
	_browser.games_changed.connect(_refresh_games)
	visibility_changed.connect(_sync_browser)
	_sync_browser()

	var small: Vector2 = Vector2((PLAY_SIZE.x - SPACING * 2.0) / 3.0, ROW_H)
	_ip_toggle = _button("Enter IP", small)
	_ip_toggle.pressed.connect(func() -> void: _ip_row.visible = not _ip_row.visible)
	_host = _button("Host Wi-Fi", small)
	_host.pressed.connect(host_pressed.emit)
	var settings := _button("Settings", small)
	settings.pressed.connect(func() -> void: SettingsPanel.show_on(self))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING)
	for c: Control in [_ip_toggle, _host, settings]:
		row.add_child(c)
	var secondary := _centered(row)
	box.add_child(secondary)
	_hide_while_typing.append(secondary)

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
	add_child(IntroSplash.new(backdrop, box))  # first-launch opening; skippable
	_maybe_shoot()


## Centred column right under the logo + tagline (the backdrop owns that spacing).
func _place_box() -> void:
	var i: Vector4 = UiStyle.safe_insets(get_viewport())
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.offset_left = -CENTRE_W * 0.5
	_box.offset_right = CENTRE_W * 0.5
	_box.offset_top = _backdrop.logo_bottom()
	_box.offset_bottom = -i.w


## `--home-shot=PATH`: save the menu to PNG once the intro is done and quit (layout checks / renders).
func _maybe_shoot() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(SHOT_FLAG):
			var path: String = a.trim_prefix(SHOT_FLAG)
			get_tree().create_timer(SHOT_DELAY).timeout.connect(func() -> void:
				get_viewport().get_texture().get_image().save_png(path)
				get_tree().quit())


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
	_box.offset_top = _backdrop.logo_bottom()
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
