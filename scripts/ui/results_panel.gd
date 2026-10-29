class_name ResultsPanel
extends CenterContainer
## End-of-match screen: winner banner, standings, and a countdown back to the lobby.

const PANEL_MIN_SIZE: Vector2 = Vector2(420, 0)
const TITLE_FONT_SIZE: int = 40
const FONT_SIZE: int = 20
const SPACING: int = 10
const PANEL_PAD: float = 24.0
const COLOR_BG: Color = Color(0, 0, 0, 0.75)
const COLOR_WIN: Color = Color(1, 0.85, 0.35)
const COLOR_LOSE: Color = Color(0.85, 0.85, 0.9)
const COLOR_DIM: Color = Color(1, 1, 1, 0.55)

var arena: Arena

var _title: Label
var _rows: VBoxContainer
var _footer: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_MIN_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.set_content_margin_all(PANEL_PAD)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	panel.add_child(box)
	_title = _label(box, TITLE_FONT_SIZE, COLOR_WIN)
	_rows = VBoxContainer.new()
	box.add_child(_rows)
	_footer = _label(box, FONT_SIZE, COLOR_DIM)
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
		_title.add_theme_color_override("font_color", COLOR_LOSE)
	elif st.winner_id == me:
		_title.text = "VICTORY"
		_title.add_theme_color_override("font_color", COLOR_WIN)
	else:
		_title.text = "%s WINS" % arena.player_name(st.winner_id).to_upper()
		_title.add_theme_color_override("font_color", COLOR_LOSE)
	for child: Node in _rows.get_children():
		child.queue_free()
	var place: int = 1
	for row: Variant in st.results:
		if not row is Array or (row as Array).size() != MatchState.ResultField.COUNT:
			continue
		var r: Array = row
		var id: int = r[MatchState.ResultField.ID]
		var you: String = " (you)" if id == me else ""
		var l := _label(_rows, FONT_SIZE, arena.player_color(id))
		l.text = "#%d  %s%s   %d kills  %d deaths" % [place, arena.player_name(id), you,
			r[MatchState.ResultField.KILLS], r[MatchState.ResultField.DEATHS]]
		place += 1


func _process(_delta: float) -> void:
	if visible:
		_footer.text = "Back to lobby in %d" % ceili(arena.match_state.time_left)


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
