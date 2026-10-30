class_name LobbyPanel
extends PanelContainer
## The loading room, shown full screen during the lobby phase: pick a character, then a starting
## weapon from the ones that character can carry (next to its signature weapon), then Ready.
## Also shows mode + arena, the roster with ready state and why the match can't start yet.
## Cards are rebuilt when the local character changes; highlights follow the synced state.

const SPACING: int = 10
const BUTTON_MIN_SIZE: Vector2 = Vector2(170, 52)
const READY_MIN_SIZE: Vector2 = Vector2(240, 64)
const CHARACTER_CARD_SIZE: Vector2 = Vector2(210, 196)
const WEAPON_CARD_SIZE: Vector2 = Vector2(182, 128)
const CHARACTER_ART_SCALE: float = 2.0
const WEAPON_ART_SCALE: float = 2.0
const COLOR_BG: Color = Color(0.07, 0.07, 0.13, 0.96)

var arena: Arena

var _title: Label
var _rules: Label
var _mode_button: Button
var _arena_button: Button
var _character_cards: Dictionary[StringName, Button] = {}
var _weapon_row: HBoxContainer
var _weapon_cards: Dictionary[StringName, Button] = {}
var _weapons_for: StringName = &""
var _rows: HFlowContainer
var _blocker: Label
var _ready_button: Button
## Last highlighted (character, weapon), so _process only restyles on change.
var _shown_pick: Array[StringName] = [&"", &""]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_background()
	get_viewport().size_changed.connect(_apply_background)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING)
	box.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title = _label(titles, &"HeaderLabel")
	_rules = _label(titles, &"DimLabel")
	_mode_button = _button(header, BUTTON_MIN_SIZE)
	_mode_button.pressed.connect(_on_mode_pressed)
	_arena_button = _button(header, BUTTON_MIN_SIZE)
	_arena_button.pressed.connect(func() -> void:
		arena.arena_requested.emit((arena.match_state.arena_index + 1) % ArenaLayouts.count()))

	_label(box, &"HeaderLabel").text = "1 · Choose your fighter"
	var character_row := _row(box)
	for c: CharacterData in arena.characters.ordered:
		var card: Button = _card(character_row, CHARACTER_CARD_SIZE, c.sprite_frames().get_frame_texture(&"idle", 0),
			CHARACTER_ART_SCALE, [c.display_name, "%s · HP %d" % [c.skill_name, c.max_hp]])
		var id: StringName = c.id
		card.pressed.connect(func() -> void: arena.character_requested.emit(id))
		_character_cards[id] = card

	_label(box, &"HeaderLabel").text = "2 · Choose your weapon"
	_weapon_row = _row(box)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", SPACING)
	footer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(footer)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_END
	footer.add_child(info)
	_rows = HFlowContainer.new()
	_rows.add_theme_constant_override("h_separation", SPACING * 2)
	info.add_child(_rows)
	_blocker = _label(info, &"Label")
	_blocker.add_theme_color_override("font_color", UiStyle.C_YELLOW)
	_blocker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ready_button = _button(footer, READY_MIN_SIZE)
	_ready_button.theme_type_variation = &"PrimaryButton"
	_ready_button.add_theme_font_size_override("font_size", UiStyle.SIZE_HEADING)
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
		_character_cards[id].theme_type_variation = &"CardSelected" if id == _shown_pick[0] else &"Card"
	for id: StringName in _weapon_cards:
		_weapon_cards[id].theme_type_variation = &"CardSelected" if id == _shown_pick[1] else &"Card"

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
		var row: Label = _label(_rows, &"Label")
		row.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
		row.add_theme_color_override("font_color", p.display_color)
		row.text = "● %s%s · %s · %s" % [arena.player_name(p.player_id), you, p.character.display_name, tag]

	var picked: bool = _shown_pick[1] != &""
	_blocker.text = st.blocker if picked or _is_ready() else "Pick a weapon to get ready."
	_ready_button.disabled = not picked and not _is_ready()
	_ready_button.text = "UNREADY" if _is_ready() else "READY!"
	_ready_button.theme_type_variation = &"Button" if _is_ready() else &"PrimaryButton"


func _build_weapon_cards(c: CharacterData) -> void:
	_weapons_for = c.id
	_weapon_cards.clear()
	for child: Node in _weapon_row.get_children():
		child.queue_free()
	var sig: WeaponData = c.signature_weapon
	if sig != null:
		var sig_card: Button = _card(_weapon_row, WEAPON_CARD_SIZE, sig.sprite, WEAPON_ART_SCALE,
			[sig.display_name, "Signature · always"])
		sig_card.disabled = true
		sig_card.theme_type_variation = &"CardGold"
	for w: WeaponData in arena.starting_weapons_for(c):
		var card: Button = _card(_weapon_row, WEAPON_CARD_SIZE, w.sprite, WEAPON_ART_SCALE,
			[w.display_name, "%d dmg · %s" % [w.damage * maxi(1, w.pellets),
				"free" if w.energy_cost == 0 else "%d energy" % w.energy_cost]])
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
		var l: Label = _label(box, &"Label" if i == 0 else &"DimLabel")
		if i == 0:
			l.add_theme_font_override("font", UiStyle.bold())
		else:
			l.add_theme_font_size_override("font_size", UiStyle.SIZE_TINY)
		l.text = lines[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## Full-screen backdrop; content padded clear of notches / the home bar.
func _apply_background() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	var i: Vector4 = UiStyle.safe_insets(get_viewport())
	style.content_margin_left = i.x + SPACING
	style.content_margin_top = i.y + SPACING
	style.content_margin_right = i.z + SPACING
	style.content_margin_bottom = i.w
	add_theme_stylebox_override("panel", style)


func _label(parent: Node, variation: StringName) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	parent.add_child(l)
	return l


func _button(parent: Node, min_size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b
