class_name ResultsPanel
extends CenterContainer
## End-of-match screen: winner banner, standings with each player's character, kills and
## deaths, and a countdown back to the lobby. Pixel panel from the UI theme.

const PANEL_MIN_SIZE: Vector2 = Vector2(560, 0)
const SPACING: int = 10
const ROW_SPACING: int = 14
const ICON_SIZE: Vector2 = Vector2(26, 26)
const PORTRAIT_SIZE: Vector2 = Vector2(48, 48)
const NAME_MIN_W: float = 220.0
const STAT_MIN_W: float = 64.0
const COLOR_VEIL: Color = Color(0.05, 0.05, 0.1, 0.6)

var arena: Arena

var _title: Label
var _rows: VBoxContainer
var _footer: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil := ColorRect.new()
	veil.color = COLOR_VEIL
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_MIN_SIZE
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", UiStyle.bold())
	_title.add_theme_font_size_override("font_size", UiStyle.SIZE_TITLE)
	box.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", SPACING)
	box.add_child(_rows)
	_footer = Label.new()
	_footer.theme_type_variation = &"DimLabel"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_footer)
	arena.match_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var st: MatchState = arena.match_state
	visible = st.phase == MatchState.Phase.RESULTS
	if not visible:
		return
	var me: int = arena.local_player.player_id if arena.local_player != null else 0
	if st.winner_id == 0:
		_title.text = "DRAW"
		_title.add_theme_color_override("font_color", UiStyle.C_STEEL)
	elif st.winner_id == me:
		_title.text = "VICTORY!"
		_title.add_theme_color_override("font_color", UiStyle.C_YELLOW)
	else:
		_title.text = "%s WINS" % arena.player_name(st.winner_id).to_upper()
		_title.add_theme_color_override("font_color", UiStyle.C_WHITE)
	for child: Node in _rows.get_children():
		child.queue_free()
	var place: int = 1
	for row: Variant in st.results:
		if not row is Array or (row as Array).size() != MatchState.ResultField.COUNT:
			continue
		var r: Array = row
		var id: int = r[MatchState.ResultField.ID]
		_add_row(place, id, id == me, r[MatchState.ResultField.KILLS], r[MatchState.ResultField.DEATHS])
		place += 1


## "#1 [trophy]  [portrait] Name (you)   [swords] 5   [skull] 2"
func _add_row(place: int, id: int, is_me: bool, kills: int, deaths: int) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", ROW_SPACING)
	_rows.add_child(line)
	if place == 1:
		_icon(line, UiStyle.tex("icon_trophy"), ICON_SIZE)
	else:
		var rank := _text(line, "#%d" % place, UiStyle.C_DIM)
		rank.custom_minimum_size.x = ICON_SIZE.x
	var p: Player = arena.get_player(id)
	if p != null:
		_icon(line, p.character.sprite_frames().get_frame_texture(&"idle", 0), PORTRAIT_SIZE)
	var name_label := _text(line, arena.player_name(id) + (" (you)" if is_me else ""), arena.player_color(id))
	name_label.custom_minimum_size.x = NAME_MIN_W
	if is_me:
		name_label.add_theme_font_override("font", UiStyle.bold())
	_icon(line, UiStyle.tex("icon_kills"), ICON_SIZE)
	_text(line, str(kills), UiStyle.C_WHITE).custom_minimum_size.x = STAT_MIN_W
	_icon(line, UiStyle.tex("icon_deaths"), ICON_SIZE)
	_text(line, str(deaths), UiStyle.C_STEEL).custom_minimum_size.x = STAT_MIN_W


func _process(_delta: float) -> void:
	if visible:
		_footer.text = "Back to the loading room in %d" % ceili(arena.match_state.time_left)


func _text(parent: Node, text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _icon(parent: Node, art: Texture2D, min_size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = art
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = min_size
	parent.add_child(t)
	return t
