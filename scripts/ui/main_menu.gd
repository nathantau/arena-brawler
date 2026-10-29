class_name MainMenu
extends Control
## Dev menu until the M3 lobby: play offline vs bots, or join a server by IP.

signal offline_pressed
signal join_pressed(address: String)

const DEFAULT_ADDRESS: String = "127.0.0.1:7777"
const TITLE_FONT_SIZE: int = 40
const FONT_SIZE: int = 22
const BUTTON_MIN_SIZE: Vector2 = Vector2(320, 64)
const SPACING: int = 16
const COLOR_BG: Color = Color(0.07, 0.07, 0.09)
const COLOR_STATUS: Color = Color(1, 0.6, 0.5)

var _status: Label
var _address: LineEdit
var _join: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	center.add_child(box)

	var title := Label.new()
	title.text = "ARENA BRAWLER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	box.add_child(title)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", COLOR_STATUS)
	_status.add_theme_font_size_override("font_size", FONT_SIZE)
	box.add_child(_status)

	var offline := _button("Play vs bots (offline)")
	offline.pressed.connect(offline_pressed.emit)
	box.add_child(offline)

	_address = LineEdit.new()
	_address.text = DEFAULT_ADDRESS
	_address.custom_minimum_size = BUTTON_MIN_SIZE
	_address.add_theme_font_size_override("font_size", FONT_SIZE)
	_address.text_submitted.connect(func(_t: String) -> void: _on_join())
	box.add_child(_address)

	_join = _button("Join server")
	_join.pressed.connect(_on_join)
	box.add_child(_join)


func set_status(text: String) -> void:
	_status.text = text
	_join.disabled = false


func _on_join() -> void:
	_join.disabled = true
	_status.text = "Connecting..."
	join_pressed.emit(_address.text)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_MIN_SIZE
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	return b
