class_name LobbyPanel
extends PanelContainer
## The loading room, shown full screen during the lobby phase: pick a character, then a starting
## weapon from the ones that character can carry (next to its signature weapon), then Ready.
## Also shows mode + arena, the roster with ready state and why the match can't start yet.
## Cards are rebuilt when the local character changes; highlights follow the synced state.

const PAD: int = 24
const SPACING: int = 10
const TITLE_FONT_SIZE: int = 24
const STEP_FONT_SIZE: int = 18
const FONT_SIZE: int = 15
const SMALL_FONT_SIZE: int = 12
const BUTTON_MIN_SIZE: Vector2 = Vector2(150, 44)
const READY_MIN_SIZE: Vector2 = Vector2(220, 64)
const CHARACTER_CARD_SIZE: Vector2 = Vector2(190, 196)
const WEAPON_CARD_SIZE: Vector2 = Vector2(170, 132)
const CHARACTER_ART_SCALE: float = 2.0
const WEAPON_ART_SCALE: float = 2.5
const CARD_BORDER: int = 3
const CARD_RADIUS: int = 8
const COLOR_BG: Color = Color(0.07, 0.07, 0.12, 0.94)
const COLOR_CARD: Color = Color(1, 1, 1, 0.06)
const COLOR_CARD_BORDER: Color = Color(1, 1, 1, 0.15)
const COLOR_SELECTED: Color = Color(0.5, 0.95, 0.5)
const COLOR_SIGNATURE: Color = Color(1, 0.82, 0.35)
const COLOR_DIM: Color = Color(1, 1, 1, 0.55)
const COLOR_READY: Color = Color(0.5, 0.95, 0.5)
const COLOR_BLOCKER: Color = Color(1, 0.8, 0.45)

var arena: Arena

var _title: Label
var _rules: Label
var _mode_button: Button
var _arena_button: Button
var _character_cards: Dictionary[StringName, Button] = {}
var _weapon_row: HBoxContainer
var _weapon_cards: Dictionary[StringName, Button] = {}
var _weapons_for: StringName = &""
var _rows: VBoxContainer
var _blocker: Label
var _ready_button: Button
## Last highlighted (character, weapon), so _process only restyles on change.
var _shown_pick: Array[StringName] = [&"", &""]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.set_content_margin_all(PAD)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING)
	box.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title = _label(titles, TITLE_FONT_SIZE, Color.WHITE)
	_rules = _label(titles, FONT_SIZE, COLOR_DIM)
	_mode_button = _button(header, BUTTON_MIN_SIZE)
	_mode_button.pressed.connect(_on_mode_pressed)
	_arena_button = _button(header, BUTTON_MIN_SIZE)
	_arena_button.pressed.connect(func() -> void:
		arena.arena_requested.emit((arena.match_state.arena_index + 1) % ArenaLayouts.count()))

	_label(box, STEP_FONT_SIZE, Color.WHITE).text = "1 · Choose your fighter"
	var character_row := _row(box)
	for c: CharacterData in arena.characters.ordered:
		var card: Button = _card(character_row, CHARACTER_CARD_SIZE, c.sprite_frames().get_frame_texture(&"idle", 0),
			CHARACTER_ART_SCALE, [c.display_name, "%s · HP %d · Armor %d" % [c.skill_name, c.max_hp, c.max_armor]])
		var id: StringName = c.id
		card.pressed.connect(func() -> void: arena.character_requested.emit(id))
		_character_cards[id] = card

	_label(box, STEP_FONT_SIZE, Color.WHITE).text = "2 · Choose your weapon"
	_weapon_row = _row(box)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", SPACING)
	footer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(footer)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_rows)
	_blocker = _label(footer, FONT_SIZE, COLOR_BLOCKER)
	_blocker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ready_button = _button(footer, READY_MIN_SIZE)
	_ready_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_ready_button.pressed.connect(_on_ready_pressed)

	arena.match_updated.connect(_refresh)
	_refresh()


## Loadouts reach clients in snapshots, not match updates: restyle when the pick changes.
func _process(_delta: float) -> void:
	if visible and _pick() != _shown_pick:
		_refresh()


func _refresh() -> void:
	var st: MatchState = arena.match_state
	visible = st.phase == MatchState.Phase.LOBBY
	if not visible or arena.local_player == null:
		return
	var me: Player = arena.local_player
	_title.text = "LOADING ROOM · %s · %s" % [MatchRules.MODE_NAMES[st.mode], ArenaLayouts.NAMES[st.arena_index]]
	_rules.text = "First to %d kills · %d:%02d" % [MatchRules.kill_target(st.mode),
		int(st.time_limit) / 60, int(st.time_limit) % 60]
	_mode_button.text = "Mode: %s" % ("Duel" if st.mode == MatchRules.Mode.DUEL else "FFA")
	_arena_button.text = "Arena: %s" % ArenaLayouts.NAMES[st.arena_index]
	if _weapons_for != me.character.id:
		_build_weapon_cards(me.character)
	_shown_pick = _pick()
	for id: StringName in _character_cards:
		_style(_character_cards[id], COLOR_SELECTED if id == _shown_pick[0] else COLOR_CARD_BORDER)
	for id: StringName in _weapon_cards:
		_style(_weapon_cards[id], COLOR_SELECTED if id == _shown_pick[1] else COLOR_CARD_BORDER)

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
			tag = "picking"
		var you: String = " (you)" if p == me else ""
		_label(_rows, FONT_SIZE, p.display_color).text = "● %s%s · %s — %s" % [
			arena.player_name(p.player_id), you, p.character.display_name, tag]

	var picked: bool = _shown_pick[1] != &""
	_blocker.text = st.blocker if picked or _is_ready() else "Pick a weapon to get ready."
	_ready_button.disabled = not picked and not _is_ready()
	_ready_button.text = "Unready" if _is_ready() else "Ready"
	_ready_button.add_theme_color_override("font_color", Color.WHITE if _is_ready() else COLOR_READY)


func _build_weapon_cards(c: CharacterData) -> void:
	_weapons_for = c.id
	_weapon_cards.clear()
	for child: Node in _weapon_row.get_children():
		child.queue_free()
	var sig: WeaponData = c.signature_weapon
	if sig != null:
		var sig_card: Button = _card(_weapon_row, WEAPON_CARD_SIZE, sig.sprite, WEAPON_ART_SCALE,
			[sig.display_name, "Signature · always carried"])
		sig_card.disabled = true
		_style(sig_card, COLOR_SIGNATURE)
	for w: WeaponData in arena.starting_weapons_for(c):
		var card: Button = _card(_weapon_row, WEAPON_CARD_SIZE, w.sprite, WEAPON_ART_SCALE,
			[w.display_name, "%d dmg · %s energy" % [w.damage * maxi(1, w.pellets), w.energy_cost]])
		var id: StringName = w.id
		card.pressed.connect(func() -> void: arena.weapon_requested.emit(id))
		_weapon_cards[id] = card


## The local player's (character id, starting weapon id); the weapon is loadout slot 1.
func _pick() -> Array[StringName]:
	var me: Player = arena.local_player
	if me == null:
		return [&"", &""]
	var slots: Array[WeaponState] = me.loadout.slots
	return [me.character.id, slots[1].data.id if slots.size() > 1 else &""]


func _is_ready() -> bool:
	return arena.local_player != null and arena.match_state.ready.has(arena.local_player.player_id)


func _on_mode_pressed() -> void:
	var next: int = (arena.match_state.mode + 1) % MatchRules.Mode.size()
	arena.mode_requested.emit(next as MatchRules.Mode)


func _on_ready_pressed() -> void:
	arena.ready_requested.emit(not _is_ready())


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING)
	parent.add_child(row)
	return row


## A tappable card: pixel art (Nearest, scaled) over a bold first line and small lines below.
func _card(parent: Node, min_size: Vector2, art: Texture2D, art_scale: float, lines: Array[String]) -> Button:
	var card := _button(parent, min_size)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, SPACING)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var pic := TextureRect.new()
	pic.texture = art
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = art.get_size() * art_scale
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	for i: int in lines.size():
		var l: Label = _label(box, FONT_SIZE if i == 0 else SMALL_FONT_SIZE, Color.WHITE if i == 0 else COLOR_DIM)
		l.text = lines[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _style(card: Button, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD
	sb.border_color = border
	sb.set_border_width_all(CARD_BORDER)
	sb.set_corner_radius_all(CARD_RADIUS)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		card.add_theme_stylebox_override(state, sb)


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Node, min_size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b
