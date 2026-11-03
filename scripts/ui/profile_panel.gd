class_name ProfilePanel
extends Control
## Modal "Profile" view from the main menu: lifetime totals and each fighter's mastery level + XP bar. Mounted on its
## own top CanvasLayer like SettingsPanel.

const LAYER: int = 110
const PANEL_MIN_SIZE: Vector2 = Vector2(620, 0)
const SPACING: int = 10
const BUTTON_SIZE: Vector2 = Vector2(240, UiStyle.TOUCH_MIN_H)
const COLOR_VEIL: Color = Color(0.05, 0.05, 0.1, 0.8)
const BAR_SIZE: Vector2 = Vector2(150, 12)
const NAME_W: float = 150.0
const COLUMNS: int = 2

var _on_close: Callable
var _characters: CharacterCatalog


static func show_on(host: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := ProfilePanel.new()
	panel._on_close = layer.queue_free
	layer.add_child(panel)
	host.get_tree().root.add_child.call_deferred(layer)


func _ready() -> void:
	PlayerProfile.ensure_loaded()
	_characters = CharacterCatalog.load_all()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = COLOR_VEIL
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_MIN_SIZE
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PROFILE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiStyle.bold())
	title.add_theme_font_size_override("font_size", UiStyle.SIZE_HEADING)
	box.add_child(title)
	var totals := HBoxContainer.new()
	totals.alignment = BoxContainer.ALIGNMENT_CENTER
	totals.add_theme_constant_override("separation", SPACING * 3)
	box.add_child(totals)
	var rate: String = "%d%%" % roundi(100.0 * PlayerProfile.wins / PlayerProfile.matches) if PlayerProfile.matches > 0 else "-"
	for t: Array in [["MATCHES", PlayerProfile.matches], ["WINS", PlayerProfile.wins], ["WIN RATE", rate],
			["KILLS", PlayerProfile.kills], ["DAMAGE", PlayerProfile.damage]]:
		totals.add_child(_stat(t[0], str(t[1])))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", SPACING * 3)
	grid.add_theme_constant_override("v_separation", SPACING)
	var center_grid := CenterContainer.new()
	center_grid.add_child(grid)
	box.add_child(center_grid)
	for c: CharacterData in _characters.ordered:
		grid.add_child(_fighter_row(c))
	var done := Button.new()
	done.text = "Done"
	done.theme_type_variation = &"PrimaryButton"
	done.custom_minimum_size = BUTTON_SIZE
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(_close)
	var row := CenterContainer.new()
	row.add_child(done)
	box.add_child(row)


func _fighter_row(c: CharacterData) -> Control:
	var xp: int = PlayerProfile.xp_of(c.id)
	var f: Dictionary = PlayerProfile.fighters.get(String(c.id), {})
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", SPACING)
	var pic := TextureRect.new()
	pic.texture = c.portrait()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(44, 44)
	line.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	line.add_child(col)
	var name_label := Label.new()
	name_label.text = "%s  Lv %d" % [c.display_name, PlayerProfile.level_for_xp(xp)]
	name_label.custom_minimum_size.x = NAME_W
	name_label.clip_text = true
	name_label.add_theme_font_override("font", UiStyle.bold())
	col.add_child(name_label)
	var track := ColorRect.new()
	track.color = UiStyle.C_SHADOW
	track.custom_minimum_size = BAR_SIZE
	var fill := ColorRect.new()
	fill.color = UiStyle.C_YELLOW
	fill.size = Vector2(BAR_SIZE.x * PlayerProfile.level_fraction(xp), BAR_SIZE.y)
	track.add_child(fill)
	col.add_child(track)
	var sub := Label.new()
	sub.theme_type_variation = &"DimLabel"
	sub.text = "%d played · %d won" % [int(f.get("matches", 0)), int(f.get("wins", 0))]
	col.add_child(sub)
	return line


func _stat(caption: String, value: String) -> Control:
	var col := VBoxContainer.new()
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_theme_font_override("font", UiStyle.bold())
	v.add_theme_color_override("font_color", UiStyle.C_YELLOW)
	col.add_child(v)
	var l := Label.new()
	l.text = caption
	l.theme_type_variation = &"DimLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return col


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	if _on_close.is_valid():
		_on_close.call()
