class_name LobbyPanel
extends PanelContainer
## Lobby overlay (top-right, so warm-up play stays visible): roster with ready state, the
## mode, why the match can't start yet, and Mode / Ready buttons. Rebuilt on match_updated.

const MARGIN: float = 16.0
const PANEL_WIDTH: float = 300.0
const TITLE_FONT_SIZE: int = 20
const FONT_SIZE: int = 15
const BUTTON_MIN_SIZE: Vector2 = Vector2(130, 48)
const SPACING: int = 6
const COLOR_BG: Color = Color(0, 0, 0, 0.6)
const COLOR_DIM: Color = Color(1, 1, 1, 0.55)
const COLOR_READY: Color = Color(0.5, 0.95, 0.5)
const COLOR_BLOCKER: Color = Color(1, 0.8, 0.45)
const PANEL_PAD: float = 12.0

var arena: Arena

var _title: Label
var _rules: Label
var _rows: VBoxContainer
var _blocker: Label
var _mode_button: Button
var _ready_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, int(MARGIN))
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.set_content_margin_all(PANEL_PAD)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	add_child(box)
	_title = _label(box, TITLE_FONT_SIZE, Color.WHITE)
	_rules = _label(box, FONT_SIZE, COLOR_DIM)
	_rows = VBoxContainer.new()
	box.add_child(_rows)
	_blocker = _label(box, FONT_SIZE, COLOR_BLOCKER)
	_blocker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", SPACING)
	box.add_child(buttons)
	_mode_button = _button(buttons)
	_mode_button.pressed.connect(_on_mode_pressed)
	_ready_button = _button(buttons)
	_ready_button.pressed.connect(_on_ready_pressed)

	arena.match_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var st: MatchState = arena.match_state
	visible = st.phase == MatchState.Phase.LOBBY
	if not visible:
		return
	_title.text = "LOBBY · %s" % MatchRules.MODE_NAMES[st.mode]
	_rules.text = "First to %d kills · %d:%02d" % [MatchRules.kill_target(st.mode),
		int(st.time_limit) / 60, int(st.time_limit) % 60]
	for child: Node in _rows.get_children():
		child.queue_free()
	for p: Player in arena.players:
		var tag: String
		if not st.is_participant(p.player_id):
			tag = "sits out"
		elif p.is_bot:
			tag = "bot"
		elif st.ready.has(p.player_id):
			tag = "READY"
		else:
			tag = "not ready"
		var you: String = " (you)" if p == arena.local_player else ""
		var row := _label(_rows, FONT_SIZE, p.display_color)
		row.text = "● %s%s — %s" % [arena.player_name(p.player_id), you, tag]
	_blocker.text = st.blocker
	_mode_button.text = "Mode: %s" % ("Duel" if st.mode == MatchRules.Mode.DUEL else "FFA")
	_ready_button.text = "Unready" if _is_ready() else "Ready"
	_ready_button.add_theme_color_override("font_color", Color.WHITE if _is_ready() else COLOR_READY)


func _is_ready() -> bool:
	return arena.local_player != null and arena.match_state.ready.has(arena.local_player.player_id)


func _on_mode_pressed() -> void:
	var next: int = (arena.match_state.mode + 1) % MatchRules.Mode.size()
	arena.mode_requested.emit(next as MatchRules.Mode)


func _on_ready_pressed() -> void:
	arena.ready_requested.emit(not _is_ready())


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Node) -> Button:
	var b := Button.new()
	b.custom_minimum_size = BUTTON_MIN_SIZE
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b
