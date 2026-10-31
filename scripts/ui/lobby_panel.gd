class_name LobbyPanel
extends PanelContainer
## The loading room, shown full screen during the lobby phase: pick a character, a starting
## weapon (next to its signature weapon) and a special (next to everyone's Dash), then Ready.
## Header and footer stay put; the three steps scroll between them on short screens.
## Also shows mode + arena, the roster with ready state and why the match can't start yet.
## Cards are rebuilt when the local character changes; highlights follow the synced state.

const SPACING: int = 10
const BUTTON_MIN_SIZE: Vector2 = Vector2(170, 52)
const READY_MIN_SIZE: Vector2 = Vector2(240, 64)
const CHARACTER_CARD_SIZE: Vector2 = Vector2(150, 222)
## Fighters play their idle loop: the whole sheet cell at this scale, cropped to this window. Every character shares
## the cell's body box, so they all stand in the same spot.
const FIGHTER_ART_SCALE: float = 2.0
const FIGHTER_ART_SIZE: Vector2 = Vector2(136, 150)
## Specials are compact rows (icon, name, blurb) in a column beside the fighters.
const SKILL_ROW_SIZE: Vector2 = Vector2(320, 66)
const SKILL_ICON_SIZE: Vector2 = Vector2(40, 40)
const WEAPON_CARD_SIZE: Vector2 = Vector2(168, 128)
const WEAPON_ART_SCALE: float = 2.0
const COLOR_BG: Color = Color(0.07, 0.07, 0.13)  # opaque: the arena behind stays hidden until the match

var arena: Arena

var _title: Label
var _rules: Label
var _mode_button: Button
var _arena_button: Button
var _character_cards: Dictionary[StringName, Button] = {}
var _weapon_row: HBoxContainer
var _weapon_cards: Dictionary[StringName, Button] = {}
var _weapons_for: StringName = &""
var _special_row: VBoxContainer
var _special_cards: Dictionary[StringName, Button] = {}
var _rows: HFlowContainer
var _blocker: Label
var _ready_button: Button
## Last highlighted (character, weapon, special), so _process only restyles on change.
var _shown_pick: Array[StringName] = [&"", &"", &""]


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

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", SPACING)
	steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(steps)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", SPACING * 2)
	steps.add_child(top)
	var fighters := VBoxContainer.new()
	fighters.add_theme_constant_override("separation", SPACING)
	fighters.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # pushes the specials column to the right edge
	top.add_child(fighters)
	_label(fighters, &"HeaderLabel").text = "1 · Choose your fighter"
	var character_row := _row(fighters)
	for c: CharacterData in arena.characters.ordered:
		var card: Button = _card(character_row, CHARACTER_CARD_SIZE, _fighter_art(c),
			[c.display_name, "HP %d · Armor %d" % [c.max_hp, c.max_armor]])
		var id: StringName = c.id
		card.pressed.connect(func() -> void: arena.character_requested.emit(id))
		_character_cards[id] = card

	# Weapons under the fighters, so a character with many specials can't push them below the fold.
	var gap := Control.new()
	gap.custom_minimum_size.y = SPACING
	fighters.add_child(gap)
	_label(fighters, &"HeaderLabel").text = "2 · Choose your weapon"
	_weapon_row = _row(fighters)

	var specials := VBoxContainer.new()
	specials.add_theme_constant_override("separation", SPACING)
	top.add_child(specials)
	_label(specials, &"HeaderLabel").text = "3 · Choose your special"
	_special_row = VBoxContainer.new()
	_special_row.add_theme_constant_override("separation", SPACING)
	specials.add_child(_special_row)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", SPACING)
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
	for id: StringName in _special_cards:
		_special_cards[id].theme_type_variation = &"CardSelected" if id == _shown_pick[2] else &"Card"

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
		var sig_card: Button = _card(_weapon_row, WEAPON_CARD_SIZE, _art(sig.sprite, WEAPON_ART_SCALE),
			[sig.display_name, "Signature · always"])
		sig_card.disabled = true
		sig_card.theme_type_variation = &"CardGold"
	for w: WeaponData in arena.starting_weapons_for(c):
		var card: Button = _card(_weapon_row, WEAPON_CARD_SIZE, _art(w.sprite, WEAPON_ART_SCALE),
			[w.display_name, "%d dmg · %s" % [w.damage * maxi(1, w.pellets),
				"free" if w.energy_cost == 0 else "%d energy" % w.energy_cost]])
		var id: StringName = w.id
		card.pressed.connect(func() -> void: arena.weapon_requested.emit(id))
		_weapon_cards[id] = card

	_special_cards.clear()
	for child: Node in _special_row.get_children():
		child.queue_free()
	var dash: SkillData = SkillCatalog.shared().dash()
	var dash_card: Button = _skill_row(dash, "Everyone has it")
	dash_card.disabled = true
	dash_card.theme_type_variation = &"CardGold"
	for sk: SkillData in SkillCatalog.shared().specials_for(c):
		var card: Button = _skill_row(sk, "%s · %ds" % [sk.blurb, roundi(sk.cooldown)])
		var sid: StringName = sk.id
		card.pressed.connect(func() -> void: arena.special_requested.emit(sid))
		_special_cards[sid] = card


## A compact special row: icon on the left, bold name over a dim blurb.
func _skill_row(sk: SkillData, blurb: String) -> Button:
	var b := _button(_special_row, SKILL_ROW_SIZE)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, SPACING)
	row.add_theme_constant_override("separation", SPACING)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var pic := TextureRect.new()
	pic.texture = sk.icon
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = SKILL_ICON_SIZE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_label: Label = _label(text, &"Label")
	name_label.add_theme_font_override("font", UiStyle.bold())
	name_label.text = sk.display_name
	var blurb_label: Label = _label(text, &"DimLabel")
	blurb_label.add_theme_font_size_override("font_size", UiStyle.SIZE_TINY)
	blurb_label.text = blurb
	for l: Label in [name_label, blurb_label]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## The local player's (character id, starting weapon id, special id); the weapon is loadout slot 1.
func _pick() -> Array[StringName]:
	var me: Player = arena.local_player
	if me == null:
		return [&"", &"", &""]
	var slots: Array[WeaponState] = me.loadout.slots
	return [me.character.id, slots[1].data.id if slots.size() > 1 else &"", me.special.data.id]


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


## A tappable card: art over a bold first line and small lines below.
func _card(parent: Node, min_size: Vector2, art: Control, lines: Array[String]) -> Button:
	var card := _button(parent, min_size)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, SPACING)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
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


## Still pixel art (Nearest, scaled).
func _art(tex: Texture2D, art_scale: float) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = tex.get_size() * art_scale
	return pic


## The fighter playing its idle loop: the sheet's whole cell, centred in a clipped window, so every character
## stands in the same spot.
func _fighter_art(c: CharacterData) -> Control:
	var window := Control.new()
	window.custom_minimum_size = FIGHTER_ART_SIZE
	window.clip_contents = true
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = c.sprite_frames()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * FIGHTER_ART_SCALE
	sprite.position = FIGHTER_ART_SIZE * 0.5
	window.add_child(sprite)
	sprite.play(&"idle")
	return window


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
