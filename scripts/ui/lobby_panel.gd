class_name LobbyPanel
extends PanelContainer
## The loading room, shown full screen during the lobby phase: pick a character, the one weapon it fights
## with (its signature by default) and three specials (its own or generic ones like Dash), then Ready.
## Header and footer stay put; the three steps scroll between them on short screens.
## Also shows mode + arena, the roster with ready state and why the match can't start yet.
## Cards are rebuilt when the local character changes; highlights follow the synced state.

const SPACING: int = 10
## Roster text for your side: a lighter blue than the HUD's so it reads on the dark panel (enemies use UiStyle.C_RED).
const TEAM_ALLY_COLOR: Color = Color8(110, 160, 255)
const BUTTON_MIN_SIZE: Vector2 = Vector2(190, UiStyle.TOUCH_MIN_H)
const READY_MIN_SIZE: Vector2 = Vector2(240, UiStyle.TOUCH_MIN_H)
const LEAVE_MIN_SIZE: Vector2 = Vector2(140, UiStyle.TOUCH_MIN_H)
const CHARACTER_CARD_SIZE: Vector2 = Vector2(150, 174)
## Fighters play their idle loop: the whole sheet cell at this scale, cropped to this window. Every character shares
## the cell's body box, so they all stand in the same spot.
const FIGHTER_ART_SCALE: float = 1.5
const FIGHTER_ART_SIZE: Vector2 = Vector2(120, 96)
## Specials are compact rows (icon, name, blurb) in a column beside the fighters.
const SKILL_ROW_SIZE: Vector2 = Vector2(320, 64)  # 7 rows (5 own + Dash + Barrier) fit above READY on a phone
const SKILL_ICON_SIZE: Vector2 = Vector2(40, 40)
const WEAPON_CARD_SIZE: Vector2 = Vector2(168, 140)
const WEAPON_ART_SCALE: float = 1.5
## Teams hero select: a teammate's locked card is dimmed to this, and shows "LOCKED · name".
const LOCKED_DIM: Color = Color(0.5, 0.5, 0.55)
const TOAST_TIME: float = 2.5
const COLOR_BG: Color = Color(0.07, 0.07, 0.13)  # opaque: the arena behind stays hidden until the match

var arena: Arena

var _title: Label
var _rules: Label
var _join_hint: Label
var _mode_button: Button
var _team_button: Button
var _arena_button: Button
var _character_cards: Dictionary[StringName, Button] = {}
var _weapon_row: BoxContainer
var _fighter_scroller: HScroller
var _weapon_scroller: HScroller
var _weapon_cards: Dictionary[StringName, Button] = {}
var _weapons_for: StringName = &""
var _special_row: BoxContainer
var _special_scroller: HScroller
var _special_cards: Dictionary[StringName, Button] = {}
## The "1" / "2" / "3" slot badge on each special row.
var _special_badges: Dictionary[StringName, Label] = {}
## The slot a newly tapped special replaces: the one set least recently.
var _older_slot: int = 1
var _rows: VBoxContainer
var _blocker: Label
var _ready_button: Button
## Per fighter card: teammates' hover tags (top) and the lock badge (middle).
var _fighter_tags: Dictionary[StringName, HBoxContainer] = {}
var _fighter_badges: Dictionary[StringName, Label] = {}
## Everyone's (fighter, locked) as last drawn, so _process restyles when a teammate browses.
var _shown_crowd: Array = []
var _toast: String = ""
var _toast_left: float = 0.0
## Last highlighted (character, weapon, slots 0-2 specials), so _process only restyles on change.
var _revealed: Array[StringName] = [&"", &""]
var _shown_pick: Array[StringName] = [&"", &"", &"", &"", &""]


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
	titles.custom_minimum_size.x = 0.0
	_title = _label(titles, &"HeaderLabel")
	_rules = _label(titles, &"DimLabel")
	_join_hint = _label(titles, &"HeaderLabel")
	_join_hint.add_theme_color_override("font_color", UiStyle.C_YELLOW)
	for l: Label in [_title, _rules, _join_hint]:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mode_button = _button(header, BUTTON_MIN_SIZE)
	_mode_button.pressed.connect(_on_mode_pressed)
	_team_button = _button(header, BUTTON_MIN_SIZE)
	_team_button.pressed.connect(_on_team_pressed)
	_arena_button = _button(header, BUTTON_MIN_SIZE)
	# These grow to fit their text: the arena name must never be clipped to "...".
	for b: Button in [_mode_button, _team_button, _arena_button]:
		b.clip_text = false
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_arena_button.pressed.connect(func() -> void:
		arena.arena_requested.emit((arena.match_state.arena_index + 1) % ArenaLayouts.count()))

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", SPACING * 2)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(top)
	# Each column scrolls vertically on its own when it doesn't fit (drag it; tap selects).
	var left := HScroller.new(true)
	left.fade_color = COLOR_BG
	left.content.add_theme_constant_override("separation", SPACING)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # pushes the specials column to the right edge
	top.add_child(left)
	var fighters: BoxContainer = left.content
	_label(fighters, &"HeaderLabel").text = "1 · Choose your fighter"
	# Scrolls sideways once there are more fighters than fit (drag the row; tap selects).
	_fighter_scroller = _scroller(fighters)
	for c: CharacterData in arena.characters.ordered:
		var card: Button = _card(_fighter_scroller.content, CHARACTER_CARD_SIZE, _fighter_art(c),
			[c.display_name, "HP %d · Armor %d" % [c.max_hp, c.max_armor]])
		var id: StringName = c.id
		_fighter_scroller.on_tap(card, func() -> void: arena.character_requested.emit(id))
		_character_cards[id] = card
		var tags := HBoxContainer.new()
		tags.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 6)
		tags.add_theme_constant_override("separation", 4)
		tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tags)
		_fighter_tags[id] = tags
		var badge: Label = _label(card, &"Label")
		badge.add_theme_font_size_override("font_size", UiStyle.SIZE_TINY)
		badge.add_theme_font_override("font", UiStyle.bold())
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
		badge.grow_vertical = Control.GROW_DIRECTION_BOTH
		badge.offset_top -= 24.0
		badge.offset_bottom -= 24.0
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		_fighter_badges[id] = badge

	# Weapons under the fighters, so a character with many specials can't push them below the fold.
	var gap := Control.new()
	gap.custom_minimum_size.y = SPACING
	fighters.add_child(gap)
	_label(fighters, &"HeaderLabel").text = "2 · Choose your weapon"
	_weapon_scroller = _scroller(fighters)
	_weapon_row = _weapon_scroller.content

	var specials := VBoxContainer.new()
	specials.add_theme_constant_override("separation", SPACING)
	top.add_child(specials)
	_label(specials, &"HeaderLabel").text = "3 · Choose 3 specials"
	_special_scroller = HScroller.new(true)
	_special_scroller.fade_color = COLOR_BG
	_special_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	specials.add_child(_special_scroller)
	_special_row = _special_scroller.content
	_special_row.add_theme_constant_override("separation", SPACING / 2)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", SPACING)
	box.add_child(footer)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_END
	footer.add_child(info)
	_rows = VBoxContainer.new()
	info.add_child(_rows)
	_blocker = _label(info, &"Label")
	_blocker.add_theme_color_override("font_color", UiStyle.C_YELLOW)
	_blocker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var leave: Button = _button(footer, LEAVE_MIN_SIZE)
	leave.text = "Leave"
	leave.size_flags_vertical = Control.SIZE_SHRINK_END
	leave.pressed.connect(func() -> void: arena.leave_requested.emit(false))
	_ready_button = _button(footer, READY_MIN_SIZE)
	_ready_button.theme_type_variation = &"PrimaryButton"
	_ready_button.add_theme_font_size_override("font_size", UiStyle.SIZE_HEADING)
	_ready_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_ready_button.pressed.connect(_on_ready_pressed)

	arena.match_updated.connect(_refresh)
	arena.lock_refused.connect(func(holder: int) -> void:
		_toast = "Taken by %s" % _team_name(arena.get_player(holder))
		_toast_left = TOAST_TIME
		_refresh())
	_refresh()


## Loadouts reach clients in snapshots, not match updates: restyle when the pick (or a teammate's hover) changes.
func _process(delta: float) -> void:
	if not visible:
		return
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_refresh()
	if _pick() != _shown_pick or _crowd() != _shown_crowd:
		_refresh()


## Every player's current fighter + whether it is locked, for change detection.
func _crowd() -> Array:
	var out: Array = []
	for p: Player in arena.players:
		out.append([p.player_id, p.character.id, arena.match_state.locked.has(p.player_id)])
	return out


func _hovers() -> Dictionary:
	var out: Dictionary = {}
	for p: Player in arena.players:
		if arena.match_state.is_participant(p.player_id):
			out[p.player_id] = p.character.id
	return out


## How a player is named on the team lines: You / <fighter> (bot) / Player N.
func _team_name(p: Player) -> String:
	if p == null:
		return "a teammate"
	if p == arena.local_player:
		return "You"
	return "%s (bot)" % p.character.display_name if p.is_bot else "Player %d" % p.player_id


func _refresh() -> void:
	var st: MatchState = arena.match_state
	visible = st.phase == MatchState.Phase.LOBBY
	if not visible or arena.local_player == null:
		return
	var me: Player = arena.local_player
	_title.text = "LOADING ROOM · %s · %s" % [MatchRules.MODE_NAMES[st.mode], ArenaLayouts.NAMES[st.arena_index]]
	if st.mode == MatchRules.Mode.TEAMS:
		_rules.text = "First team to %d rounds · %ds rounds · %d lives each" % [MatchRules.kill_target(st.mode),
			int(minf(st.time_limit, Constants.TEAMS_ROUND_TIME)), Constants.TEAMS_LIVES]
	else:
		_rules.text = "First to %d kills · %d:%02d" % [MatchRules.kill_target(st.mode),
			int(st.time_limit) / 60, int(st.time_limit) % 60]
	_join_hint.visible = arena.host_address != ""
	_join_hint.text = "Friends join: %s" % LanAddress.friendly(arena.host_address)
	_mode_button.text = "Mode: %s" % MatchRules.SHORT_NAMES[st.mode]
	_team_button.visible = shows_team_picker(st.mode, arena.mode)
	_team_button.text = "Team: %s" % MatchRules.LOBBY_TEAM_NAMES[st.team_of(me.player_id)]
	_arena_button.text = "Arena: %s" % ArenaLayouts.NAMES[st.arena_index]
	if _weapons_for != me.character.id:
		_build_weapon_cards(me.character)
	_shown_pick = _pick()
	if _shown_pick[0] != _revealed[0] or _shown_pick[1] != _revealed[1]:
		_revealed = [_shown_pick[0], _shown_pick[1]]
		if _character_cards.has(_shown_pick[0]):
			_fighter_scroller.reveal(_character_cards[_shown_pick[0]])
		if _weapon_cards.has(_shown_pick[1]):
			_weapon_scroller.reveal(_weapon_cards[_shown_pick[1]])
	for id: StringName in _character_cards:
		_character_cards[id].theme_type_variation = &"CardSelected" if id == _shown_pick[0] else &"Card"
	for id: StringName in _weapon_cards:
		_weapon_cards[id].theme_type_variation = &"CardSelected" if id == _shown_pick[1] else &"Card"
	for id: StringName in _special_cards:
		var slot: int = _shown_pick.slice(2).find(id)
		_special_cards[id].theme_type_variation = &"CardSelected" if slot >= 0 else &"Card"
		_special_badges[id].visible = slot >= 0
		_special_badges[id].text = str(slot + 1)

	for child: Node in _rows.get_children():
		child.queue_free()
	var order: Array[Player] = arena.players.duplicate()
	var shown_teams: Dictionary[int, int] = {}
	var my_team: int = MatchRules.TEAM_A
	var flows: Dictionary[int, HFlowContainer] = {}  # team -> its line (Duel / FFA: one line under key 0)
	if st.mode == MatchRules.Mode.TEAMS:  # your team on the first line, the enemy on the second, from YOUR side
		shown_teams = MatchRules.assign_teams(st.participants, st.teams)
		my_team = MatchRules.viewer_of(shown_teams.get(me.player_id, 0))
		order.sort_custom(func(a: Player, b: Player) -> bool:
			return shown_teams.get(a.player_id, 3) < shown_teams.get(b.player_id, 3))
		for t: int in [my_team, MatchRules.other_team(my_team)]:
			var flow: HFlowContainer = _new_row_flow()
			flows[t] = flow
			var head: Label = _label(flow, &"Label")
			head.add_theme_font_size_override("font_size", UiStyle.SIZE_TINY)
			head.add_theme_color_override("font_color", TEAM_ALLY_COLOR if t == my_team else UiStyle.C_RED)
			head.text = "YOUR TEAM:" if t == my_team else "ENEMY:"
	else:
		flows[0] = _new_row_flow()
	for p: Player in order:
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
		if p.is_bot and tag == "sits out" and not shown_teams.is_empty():
			continue  # filler bots that don't play
		var team: int = shown_teams.get(p.player_id, 0)
		var row: Label = _label(flows.get(team, flows[flows.keys()[0]]), &"Label")
		row.add_theme_font_size_override("font_size", UiStyle.SIZE_TINY)
		if shown_teams.is_empty():
			row.add_theme_color_override("font_color", p.display_color)
			row.text = "● %s%s · %s · %s" % [arena.player_name(p.player_id), you, p.character.display_name, tag]
		else:  # no colour words in team names (they clash with ally blue / enemy red)
			row.add_theme_color_override("font_color", TEAM_ALLY_COLOR if team == my_team else UiStyle.C_RED)
			if team != my_team:  # enemies: no fighter until the match starts
				var foe: String = "Bot %d" % (p.player_id - Constants.BOT_ID_BASE + 1) if p.is_bot \
					else "Player %d" % p.player_id
				row.text = "● %s" % foe if p.is_bot or tag == "sits out" else "● %s · %s" % [foe, tag]
			else:
				var state: String = tag if tag == "sits out" else "LOCKED" if st.locked.has(p.player_id) else "hovering"
				row.text = "● %s · %s" % [_team_name(p), state] if p.is_bot \
					else "● %s · %s · %s" % [_team_name(p), p.character.display_name, state]

	_shown_crowd = _crowd()
	var teams_mode: bool = st.mode == MatchRules.Mode.TEAMS
	var taker: int = MatchRules.lock_holder(shown_teams, _human_locks(st), me.player_id, me.character.id) \
		if teams_mode and not _is_ready() else 0
	_mark_fighters(st, me, shown_teams, taker)
	_blocker.text = _toast if _toast_left > 0.0 else "Taken by %s" % _team_name(arena.get_player(taker)) if taker != 0 \
		else st.blocker
	_ready_button.text = ("UNLOCK" if teams_mode else "UNREADY") if _is_ready() else "LOCK IN" if teams_mode else "READY!"
	_ready_button.disabled = taker != 0
	_ready_button.theme_type_variation = &"Button" if _is_ready() else &"PrimaryButton"


## Locks held by humans (bots yield to them, so they never block a lock-in).
func _human_locks(st: MatchState) -> Dictionary:
	var out: Dictionary = {}
	for id: int in st.locked:
		if st.ready.has(id):
			out[id] = st.locked[id]
	return out


## Teams hero select on the fighter cards: teammates' hover tags, their locks (dimmed + badge), your own lock (gold).
## Enemy picks are never drawn (MatchRules.teammate_picks only returns teammates).
func _mark_fighters(st: MatchState, me: Player, shown_teams: Dictionary, taker: int) -> void:
	for id: StringName in _character_cards:
		_character_cards[id].modulate = Color.WHITE
		_fighter_badges[id].visible = false
		for t: Node in _fighter_tags[id].get_children():
			t.queue_free()
	if st.mode != MatchRules.Mode.TEAMS:
		return
	if _is_ready() and _character_cards.has(me.character.id):
		_character_cards[me.character.id].theme_type_variation = &"CardGold"
		_badge(me.character.id, "LOCKED IN", UiStyle.C_YELLOW)
	var picks: Dictionary = MatchRules.teammate_picks(me.player_id, shown_teams, _hovers(), st.locked)
	for pid: int in picks:
		var who: Player = arena.get_player(pid)
		var fid: StringName = picks[pid][0]
		if who == null or not _character_cards.has(fid):
			continue
		if not picks[pid][1]:  # hovering: a coloured dot + short name
			var tag: Label = _label(_fighter_tags[fid], &"Label")
			tag.add_theme_font_size_override("font_size", UiStyle.SIZE_TINY - 2)
			tag.add_theme_font_override("font", UiStyle.bold())
			tag.add_theme_color_override("font_color", who.display_color)
			tag.text = "● P%d" % pid
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif who.is_bot:  # a bot yields to a human, so its card stays pickable
			_badge(fid, "BOT", UiStyle.C_STEEL)
		else:
			_character_cards[fid].modulate = LOCKED_DIM
			_badge(fid, "LOCKED · P%d" % pid, UiStyle.C_ORANGE)


func _badge(fighter: StringName, text: String, color: Color) -> void:
	var badge: Label = _fighter_badges[fighter]
	badge.text = text
	badge.add_theme_color_override("font_color", color)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(COLOR_BG, 0.85)
	box.set_content_margin_all(3.0)
	box.set_corner_radius_all(2)
	badge.add_theme_stylebox_override("normal", box)
	badge.visible = true


func _build_weapon_cards(c: CharacterData) -> void:
	_weapons_for = c.id
	_weapon_cards.clear()
	for child: Node in _weapon_row.get_children():
		child.queue_free()
	for w: WeaponData in arena.weapons_for(c):
		var card: Button = _card(_weapon_row, WEAPON_CARD_SIZE, _art(w.sprite, WEAPON_ART_SCALE),
			[w.display_name, "%d dmg · %s" % [w.damage * maxi(1, w.pellets),
				"free" if w.energy_cost == 0 else "%d energy" % w.energy_cost], w.hook])
		var id: StringName = w.id
		_weapon_scroller.on_tap(card, func() -> void: arena.weapon_requested.emit(id))
		_weapon_cards[id] = card

	_special_cards.clear()
	_special_badges.clear()
	_older_slot = 1
	for child: Node in _special_row.get_children():
		child.queue_free()
	for sk: SkillData in SkillCatalog.shared().specials_for(c):
		var card: Button = _skill_row(sk, "%s · %ds" % [sk.blurb, roundi(sk.cooldown)])
		var sid: StringName = sk.id
		_special_scroller.on_tap(card, func() -> void: _on_special_pressed(sid))
		_special_cards[sid] = card
		var badge: Label = _label(card, &"HeaderLabel")
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, SPACING * 2)
		badge.add_theme_color_override("font_color", UiStyle.C_YELLOW)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_special_badges[sid] = badge


## An equipped special stays put; any other one replaces the slot set least recently.
func _on_special_pressed(id: StringName) -> void:
	if _pick().slice(2).has(id):
		return
	arena.special_requested.emit(_older_slot, id)
	_older_slot = (_older_slot + 1) % Constants.SKILL_SLOTS


## A compact special row: icon on the left, bold name over a dim blurb.
func _skill_row(sk: SkillData, blurb: String) -> Button:
	var b := _button(_special_row, SKILL_ROW_SIZE)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, SPACING)
	row.offset_right = -(SPACING + 30.0)  # room for the 1 / 2 / 3 badge
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
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		l.clip_text = true  # never spill past the row; a too-long blurb ends in "…"
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return b


## The local player's (character id, weapon id, then the special id of each slot).
func _pick() -> Array[StringName]:
	var me: Player = arena.local_player
	if me == null:
		return [&"", &"", &"", &"", &""]
	return [me.character.id, me.weapon.data.id, me.skills[0].data.id, me.skills[1].data.id, me.skills[2].data.id]


func _is_ready() -> bool:
	return arena.local_player != null and arena.match_state.ready.has(arena.local_player.player_id)


func _on_mode_pressed() -> void:
	var next: int = (arena.match_state.mode + 1) % MatchRules.Mode.size()
	arena.mode_requested.emit(next as MatchRules.Mode)


## Cycles Auto -> A -> B.
## Only a LAN lobby with friends needs to pick a side; offline the player is auto-placed and bots fill the rest.
static func shows_team_picker(match_mode: MatchRules.Mode, arena_mode: Arena.Mode) -> bool:
	return match_mode == MatchRules.Mode.TEAMS and arena_mode != Arena.Mode.OFFLINE


func _on_team_pressed() -> void:
	arena.team_requested.emit((arena.match_state.team_of(arena.local_player.player_id) + 1) % (MatchRules.TEAM_B + 1))


func _on_ready_pressed() -> void:
	arena.ready_requested.emit(not _is_ready())


func _scroller(parent: Node) -> HScroller:
	var h := HScroller.new()
	h.fade_color = COLOR_BG
	h.content.add_theme_constant_override("separation", SPACING)
	parent.add_child(h)
	return h


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
		var avail: float = min_size.x - SPACING * 2.0 - 8.0
		UiStyle.fit_label(l, lines[i], avail, UiStyle.SIZE_BODY if i == 0 else UiStyle.SIZE_TINY, UiStyle.SIZE_TINY - 4, i == 0)
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


func _new_row_flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", SPACING * 2)
	_rows.add_child(flow)
	return flow


func _label(parent: Node, variation: StringName) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	parent.add_child(l)
	return l


func _button(parent: Node, min_size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(b)
	return b
