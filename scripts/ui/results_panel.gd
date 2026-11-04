class_name ResultsPanel
extends CenterContainer
## End-of-match screen: winner banner, standings (character, kills, deaths, damage, accuracy, flag captures in
## Teams, MVP tag), the local player's mastery XP bar and a countdown back to the lobby. Pixel panel from the UI theme.

const PANEL_MIN_SIZE: Vector2 = Vector2(820, 0)
const SPACING: int = 8
const LEAVE_MIN_SIZE: Vector2 = Vector2(180, UiStyle.TOUCH_MIN_H)
const ROW_SPACING: int = 10
const ICON_SIZE: Vector2 = Vector2(26, 26)
const PORTRAIT_SIZE: Vector2 = Vector2(40, 40)
const NAME_MIN_W: float = 190.0
const TAG_W: float = 56.0
## Stat columns: header, minimum width.
const COL_KILLS_W: float = 52.0
const COL_DEATHS_W: float = 52.0
const COL_DAMAGE_W: float = 84.0
const COL_ACC_W: float = 72.0
const COL_CAP_W: float = 60.0
const XP_BAR_SIZE: Vector2 = Vector2(420, 18)
const XP_ANIM_TIME: float = 1.4
const XP_ANIM_DELAY: float = 0.5
const COLOR_VEIL: Color = Color(0.05, 0.05, 0.1, 0.6)

var arena: Arena

var _title: Label
var _rows: VBoxContainer
var _footer: Label
var _xp_label: Label
var _gold_label: Label
var _level_label: Label
var _up_label: Label
var _bar_fill: ColorRect
var _xp_box: Control
var _recorded: bool = false


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
	_xp_box = _build_xp()
	box.add_child(_xp_box)
	_footer = Label.new()
	_footer.theme_type_variation = &"DimLabel"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_footer)
	var leave := Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = LEAVE_MIN_SIZE
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(func() -> void: arena.leave_requested.emit(false))
	var leave_row := CenterContainer.new()
	leave_row.add_child(leave)
	box.add_child(leave_row)
	arena.match_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var st: MatchState = arena.match_state
	visible = st.phase == MatchState.Phase.RESULTS
	if not visible:
		_recorded = false
		_xp_box.visible = false
		return
	var me: int = arena.local_player.player_id if arena.local_player != null else 0
	if st.mode == MatchRules.Mode.TEAMS:
		var mine: int = arena.local_player.team if arena.local_player != null else 0
		_title.text = MatchRules.result_title(st.round_winner, mine)
		_title.add_theme_color_override("font_color", UiStyle.C_STEEL if st.round_winner == 0 else UiStyle.C_YELLOW \
			if st.round_winner == MatchRules.viewer_of(mine) else UiStyle.C_WHITE)
	elif st.winner_id == 0:
		_title.text = "DRAW"
		_title.add_theme_color_override("font_color", UiStyle.C_STEEL)
	elif st.winner_id == me:
		_title.text = "VICTORY!"
		_title.add_theme_color_override("font_color", UiStyle.C_YELLOW)
	else:
		_title.text = "%s WINS" % arena.player_name(st.winner_id).to_upper()
		_title.add_theme_color_override("font_color", UiStyle.C_WHITE)
	_footer.text = "Back to the loading room in %d" % ceili(st.time_left)
	for child: Node in _rows.get_children():
		child.queue_free()
	var place: int = 1
	var mvp: int = MatchRules.mvp(st.results)
	_add_header(st.mode == MatchRules.Mode.TEAMS)
	for row: Variant in st.results:
		if not row is Array or (row as Array).size() != MatchState.ResultField.COUNT:
			continue
		var r: Array = row
		var id: int = r[MatchState.ResultField.ID]
		_add_row(place, r, id == me, id == mvp, st.mode == MatchRules.Mode.TEAMS)
		place += 1
	if not _recorded:
		_recorded = true
		_record_progress(me)


func _add_header(teams: bool) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", ROW_SPACING)
	_rows.add_child(line)
	var lead := Control.new()  # rank + portrait + name + MVP tag
	lead.custom_minimum_size.x = ICON_SIZE.x + PORTRAIT_SIZE.x + NAME_MIN_W + TAG_W + ROW_SPACING * 3
	line.add_child(lead)
	_cell(line, "K", COL_KILLS_W, UiStyle.C_DIM)
	_cell(line, "D", COL_DEATHS_W, UiStyle.C_DIM)
	_cell(line, "DMG", COL_DAMAGE_W, UiStyle.C_DIM)
	_cell(line, "ACC", COL_ACC_W, UiStyle.C_DIM)
	if teams:
		_cell(line, "CAP", COL_CAP_W, UiStyle.C_DIM)


## "#1 [trophy]  [portrait] Name (you) MVP   5   2   340   62%   1"
func _add_row(place: int, r: Array, is_me: bool, is_mvp: bool, teams: bool) -> void:
	var id: int = r[MatchState.ResultField.ID]
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
		_icon(line, p.character.portrait(), PORTRAIT_SIZE)
	var name_label := _text(line, arena.player_name(id) + (" (you)" if is_me else ""), arena.player_color(id))
	name_label.custom_minimum_size.x = NAME_MIN_W
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_me:
		name_label.add_theme_font_override("font", UiStyle.bold())
	var tag := _text(line, "MVP" if is_mvp else "", UiStyle.C_YELLOW)
	tag.custom_minimum_size.x = TAG_W
	tag.add_theme_font_override("font", UiStyle.bold())
	_cell(line, str(r[MatchState.ResultField.KILLS]), COL_KILLS_W, UiStyle.C_WHITE)
	_cell(line, str(r[MatchState.ResultField.DEATHS]), COL_DEATHS_W, UiStyle.C_STEEL)
	_cell(line, str(r[MatchState.ResultField.DAMAGE]), COL_DAMAGE_W, UiStyle.C_YELLOW if is_mvp else UiStyle.C_WHITE)
	_cell(line, "%d%%" % ScoreBoard.accuracy(r[MatchState.ResultField.HITS], r[MatchState.ResultField.SHOTS]),
		COL_ACC_W, UiStyle.C_WHITE)
	if teams:
		_cell(line, str(r[MatchState.ResultField.CAPTURES]), COL_CAP_W, UiStyle.C_TEAL_L)


func _cell(parent: Node, text: String, width: float, color: Color) -> Label:
	var l := _text(parent, text, color)
	l.custom_minimum_size.x = width
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _build_xp() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.visible = false
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", SPACING * 2)
	col.add_child(top)
	_level_label = _text(top, "", UiStyle.C_WHITE)
	_level_label.add_theme_font_override("font", UiStyle.bold())
	_xp_label = _text(top, "", UiStyle.C_YELLOW)
	_up_label = _text(top, "LEVEL UP!", UiStyle.C_YELLOW)
	_up_label.add_theme_font_override("font", UiStyle.bold())
	_up_label.visible = false
	var track := ColorRect.new()
	track.color = UiStyle.C_SHADOW
	track.custom_minimum_size = XP_BAR_SIZE
	_bar_fill = ColorRect.new()
	_bar_fill.color = UiStyle.C_YELLOW
	_bar_fill.size = Vector2(0.0, XP_BAR_SIZE.y)
	track.add_child(_bar_fill)
	var bar_row := CenterContainer.new()
	bar_row.add_child(track)
	col.add_child(bar_row)
	_gold_label = _text(col, "", UiStyle.C_YELLOW)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return col


## Adds the finished match to the local profile (skipped headless: tests and the dedicated server) and animates
## the fighter's mastery bar from before to after, flashing LEVEL UP when a level is crossed.
func _record_progress(me: int) -> void:
	var st: MatchState = arena.match_state
	var player: Player = arena.local_player
	if player == null or DisplayServer.get_name() == "headless":
		return
	var kills: int = 0
	var damage: int = 0
	for row: Variant in st.results:
		if (row as Array)[MatchState.ResultField.ID] == me:
			kills = (row as Array)[MatchState.ResultField.KILLS]
			damage = (row as Array)[MatchState.ResultField.DAMAGE]
	var won: bool = st.round_winner != 0 and st.round_winner == player.team if st.mode == MatchRules.Mode.TEAMS \
		else st.winner_id == me
	var info: Dictionary = PlayerProfile.record_match(player.character.id, won, kills, damage)
	show_progress(info)


func show_progress(info: Dictionary) -> void:
	_xp_box.visible = true
	_up_label.visible = false
	_xp_label.text = "+%d XP" % info["xp"]
	var before: int = info["xp_before"]
	var after: int = info["xp_after"]
	_set_xp(before)
	_gold_label.visible = info.has("gold")
	_set_gold(0.0, info.get("gold", 0))
	var tw := create_tween()
	tw.tween_interval(XP_ANIM_DELAY)
	tw.tween_method(_set_xp, float(before), float(after), XP_ANIM_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_set_gold.bind(info.get("gold", 0)), 0.0, 1.0, XP_ANIM_TIME)
	if info["level_after"] > info["level_before"]:
		tw.tween_callback(func() -> void:
			_up_label.visible = true
			_up_label.pivot_offset = _up_label.size * 0.5
			var pop := create_tween()
			pop.tween_property(_up_label, "scale", Vector2.ONE, 0.25).from(Vector2(1.8, 1.8)).set_trans(Tween.TRANS_BACK))


## Counts "+N gold" up as `t` runs 0..1.
func _set_gold(t: float, total: int) -> void:
	_gold_label.text = "+%d gold" % roundi(total * t)


func _set_xp(xp: float) -> void:
	var v: int = int(xp)
	_level_label.text = "MASTERY LV %d" % PlayerProfile.level_for_xp(v)
	_bar_fill.size.x = XP_BAR_SIZE.x * PlayerProfile.level_fraction(v)


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
