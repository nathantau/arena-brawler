class_name MainMenu
extends Control
## Title screen: tiled arena floor behind a dim veil, the logo, the roster idling in a row,
## then Play vs bots (primary) and join-a-server by IP (direct connect until matchmaking in M6).

signal offline_pressed
signal host_pressed
signal join_pressed(address: String)

const DEFAULT_ADDRESS: String = "127.0.0.1:7777"
const BUTTON_MIN_SIZE: Vector2 = Vector2(360, 64)
const FIELD_MIN_SIZE: Vector2 = Vector2(236, 56)
const SPACING: int = 14
const LOGO_SIZE: int = 96
const TAGLINE: String = "Pick a fighter. Grab a weapon. Brawl."
const FLOOR_THEME: StringName = &"gym"
const FLOOR_TILE: float = 64.0
const VEIL: Color = Color(0.05, 0.05, 0.1, 0.72)
## The roster stands on this fraction of the screen height, at this pixel scale.
const ROSTER_Y: float = 0.42
const ROSTER_SCALE: float = 3.0
const ROSTER_GAP: float = 190.0
const IDLE_FPS: float = 6.0

var _status: Label
var _address: LineEdit
var _join: Button
var _host: Button
var _tiles: Texture2D
var _roster: Array[CharacterData] = []
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tiles = load(ArenaFloor.ART_DIR + "%s_tiles.png" % FLOOR_THEME)
	_roster = CharacterCatalog.load_all().ordered

	var box := VBoxContainer.new()
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
	offline.pressed.connect(offline_pressed.emit)
	box.add_child(_centered(offline))

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", SPACING)
	_address = LineEdit.new()
	_address.text = DEFAULT_ADDRESS
	_address.custom_minimum_size = FIELD_MIN_SIZE
	_address.text_submitted.connect(func(_t: String) -> void: _on_join())
	join_row.add_child(_address)
	_join = _button("Join", Vector2(BUTTON_MIN_SIZE.x - FIELD_MIN_SIZE.x - SPACING, FIELD_MIN_SIZE.y))
	_join.pressed.connect(_on_join)
	join_row.add_child(_join)
	box.add_child(_centered(join_row))

	_host = _button("HOST A GAME ON THIS WI-FI", Vector2(BUTTON_MIN_SIZE.x, FIELD_MIN_SIZE.y))
	_host.pressed.connect(host_pressed.emit)
	box.add_child(_centered(_host))


func set_status(text: String) -> void:
	_status.text = text
	_join.disabled = false


func _process(delta: float) -> void:
	_time += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	var cell := Rect2(0, 0, ArenaFloor.ART_TILE, ArenaFloor.ART_TILE)
	var y: float = 0.0
	while y < size.y:
		var x: float = 0.0
		while x < size.x:
			draw_texture_rect_region(_tiles, Rect2(x, y, FLOOR_TILE, FLOOR_TILE), cell)
			x += FLOOR_TILE
		y += FLOOR_TILE
	draw_rect(Rect2(Vector2.ZERO, size), VEIL)

	var top: float = UiStyle.safe_insets(get_viewport()).y + LOGO_SIZE + 20.0
	UiStyle.draw_text(self, Vector2(0, top), "BRAWLBITS", LOGO_SIZE, UiStyle.C_YELLOW, HORIZONTAL_ALIGNMENT_CENTER,
		size.x, true)
	UiStyle.draw_text(self, Vector2(0, top + UiStyle.SIZE_BODY + 18.0), TAGLINE, UiStyle.SIZE_BODY, UiStyle.C_WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, size.x)

	var frame: int = int(_time * IDLE_FPS)
	var x0: float = size.x * 0.5 - ROSTER_GAP * (_roster.size() - 1) * 0.5
	for i: int in _roster.size():
		var art: Texture2D = _roster[i].portrait(frame + i)
		UiStyle.draw_icon(self, art, Vector2(x0 + ROSTER_GAP * i, size.y * ROSTER_Y + 40.0), ROSTER_SCALE)


func _on_join() -> void:
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
