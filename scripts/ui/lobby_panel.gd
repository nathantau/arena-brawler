class_name LobbyPanel
extends PanelContainer
## The loading room, shown full screen during the lobby phase: a character select in three steps.
## Fighter (a grid of portraits; the pick zooms in as a big animated preview), then Abilities (three specials, slides
## in from the right), then Weapon (cards slide in). Defaults are pre-filled, so READY is always one tap away at the
## bottom right, and the step tabs (or tapping the preview) go back to any earlier step.
## A top bar carries mode + arena, a bottom strip the roster with ready state and why the match can't start yet.
## Cards are rebuilt when the local character changes; highlights follow the synced state.

const SPACING: int = 10
## Roster text for your side: a lighter blue than the HUD's so it reads on the dark panel (enemies use UiStyle.C_RED).
const TEAM_ALLY_COLOR: Color = Color8(110, 160, 255)
const BAR_H: float = 52.0
const BUTTON_MIN_SIZE: Vector2 = Vector2(150, BAR_H)
const READY_MIN_SIZE: Vector2 = Vector2(240, 68)
const LEAVE_MIN_SIZE: Vector2 = Vector2(120, 68)
const CHARACTER_CARD_SIZE: Vector2 = Vector2(172, 176)
## Fighters play their idle loop: the whole sheet cell at this scale, cropped to this window. Every character shares
## the cell's body box, so they all stand in the same spot.
const FIGHTER_ART_SCALE: float = 1.75
const FIGHTER_ART_SIZE: Vector2 = Vector2(150, 112)
## Specials are rows (icon, name + cooldown, one-line description) in a column; 7 (5 own + Dash + Barrier) fit.
const SKILL_ROW_H: float = 92.0
const SKILL_ICON_SIZE: Vector2 = Vector2(52, 52)
## Text in the lists under the tabs (the pixel body font): names, then descriptions / stats.
const LIST_NAME_SIZE: int = 24
const LIST_TEXT_SIZE: int = 20
const TAB_H: float = 56.0
## Loadout pane: card height, and how an icon flies from its row into its slot (then the slot pops).
const SLOT_CARD_H: float = 84.0
## Weapons carry a warm accent (slot card, selected card, header); abilities the blue one.
const WEAPON_COLOR: Color = Color8(240, 170, 70)
const SLOT_ICON_SIZE: Vector2 = Vector2(64, 40)
const FLY_TIME: float = 0.2
const POP_TIME: float = 0.12
const POP_SCALE: float = 1.12
## The ability list gets two columns once it is at least this wide.
## (Two 24 / 20 px text columns need far more than the sheet has on a phone, so in practice it is one column.)
const SKILL_TWO_COL_W: float = 1000.0
const WEAPON_CARD_H: float = 108.0
const WEAPON_ART_SCALE: float = 2.0
## Room for a weapon's stats / hook line on a phone-width sheet (the card minus its art).
const WEAPON_TEXT_W: float = 380.0
## Teams hero select: the lock / bot strip across the foot of a fighter's portrait.
const BADGE_H: float = 24.0
const TOAST_TIME: float = 2.5
const COLOR_BG: Color = Color(0.07, 0.07, 0.13)  # opaque: the arena behind stays hidden until the match
const COLOR_STAGE: Color = Color(0.105, 0.105, 0.19)
## The big preview: pixel scale is a whole number (the sheet cell times this), it zooms in over ZOOM_TIME.
## Height the name + HP / Armor block takes at the top of the showcase.
const PREVIEW_TOP: float = 118.0
const PREVIEW_MAX_SCALE: int = 6
const ZOOM_FROM: float = 0.72
const ZOOM_TIME: float = 0.25
const SLIDE_TIME: float = 0.25
## The detail overlay: how much of the width its sheet takes, and how dark the scrim over the grid gets.
const SHEET_FRACTION: float = 0.87
const SCRIM_ALPHA: float = 0.6
## Seconds between the preview's idle and a short walk / attack loop.
const FLAIR_GAP: Vector2 = Vector2(2.5, 4.5)
const FLAIR_WALK_LOOPS: int = 2

var arena: Arena

var _overlay_state := LobbyOverlay.new()
var _title: Label
var _rules: Label
var _join_hint: Label
var _team_button: Button
var _arena_button: Button
var _character_cards: Dictionary[StringName, Button] = {}
var _fighter_scroller: HScroller
## The abilities scroll in a column; the weapons sit under them in a sideways row that is always on screen.
var _detail_scroller: HScroller
var _weapon_scroller: HScroller
var _weapon_row: BoxContainer
var _tab_buttons: Array[Button] = []
var _tab_tween: Tween
var _weapon_cards: Dictionary[StringName, Button] = {}
var _weapons_for: StringName = &""
var _special_row: GridContainer
var _special_cards: Dictionary[StringName, Button] = {}
## The "1" / "2" / "3" slot badge on each special row.
var _special_badges: Dictionary[StringName, Label] = {}
var _rows: VBoxContainer
var _blocker: Label
## READY / LOCK IN: one in the footer, one at the foot of the overlay.
var _ready_buttons: Array[Button] = []
## Per fighter card: teammates' hover tags (top) and the lock badge (middle).
var _fighter_tags: Dictionary[StringName, HBoxContainer] = {}
var _fighter_badges: Dictionary[StringName, Label] = {}
var _mastery_badges: Dictionary[StringName, Label] = {}
var _fighter_frames: Dictionary[StringName, Panel] = {}
## Everyone's (fighter, locked) as last drawn, so _process restyles when a teammate browses.
var _shown_crowd: Array = []
var _toast: String = ""
var _toast_left: float = 0.0
## Last highlighted (character, weapon, slots 0-2 specials), so _process only restyles on change.
var _shown_pick: Array[StringName] = [&"", &"", &"", &"", &""]
var _was_visible: bool = false
## The overlay: a scrim over the grid and a sheet sliding in from the right.
var _margin: MarginContainer
var _overlay: Control
var _scrim: ColorRect
var _sheet: PanelContainer
var _slide_tween: Tween
## The loadout pane: the three ability slot cards, then the weapon slot card.
var _slot_cards: Array[Button] = []
var _slot_icons: Array[TextureRect] = []
var _slot_names: Array[Label] = []
var _special_icons: Dictionary[StringName, TextureRect] = {}
var _weapon_icons: Dictionary[StringName, TextureRect] = {}
## Icons in flight into a slot (slot index -> [icon node, tween]); one per slot, a new pick replaces it.
var _flyers: Dictionary[int, Array] = {}
## Dashed "+" drawn over an emptied slot card.
var _empty_marks: Array[Control] = []
var _ability_hint: Label
var _full_hint_left: float = 0.0
var _flash_tween: Tween
## The big preview.
var _stage: Panel
var _pivot: Node2D
var _backdrop: StageBackdrop
var _floor_fx: Control
var _sprite: AnimatedSprite2D
var _preview_id: StringName = &""
var _preview_tween: Tween
var _name_label: Label
var _hp_label: Label
var _armor_label: Label
var _hp_fill: ColorRect
var _armor_fill: ColorRect
var _stage_badge: Label
var _flair_left: float = FLAIR_GAP.x
var _in_flair: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Backdrop + a stack: the page (padded clear of notches) and the overlay (edge to edge) share it.
	var stack := Control.new()
	add_child(stack)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_margin)
	_apply_background()
	get_viewport().size_changed.connect(_apply_background)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SPACING)
	_margin.add_child(box)
	_build_top_bar(box)
	_build_fighter_grid(box)
	_build_footer(box)
	_build_overlay(stack)
	_apply_background()

	arena.match_updated.connect(_refresh)
	arena.lock_refused.connect(func(holder: int) -> void:
		_toast = "Taken by %s" % _team_name(arena.get_player(holder))
		_toast_left = TOAST_TIME
		_refresh())
	_refresh()
	_slide_overlay(false)


func _build_top_bar(box: BoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", SPACING)
	box.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	titles.custom_minimum_size.x = 0.0
	header.add_child(titles)
	_title = _label(titles, &"HeaderLabel")
	_title.add_theme_font_size_override("font_size", UiStyle.SIZE_BODY + 2)
	_rules = _label(titles, &"DimLabel")
	_rules.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
	_rules.add_theme_font_override("font", UiStyle.body_font())
	_join_hint = _label(titles, &"Label")
	_join_hint.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
	_join_hint.add_theme_font_override("font", UiStyle.body_font(true))
	_join_hint.add_theme_color_override("font_color", UiStyle.C_YELLOW)
	for l: Label in [_title, _rules, _join_hint]:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_team_button = _button(header, BUTTON_MIN_SIZE)
	_team_button.pressed.connect(_on_team_pressed)
	_arena_button = _button(header, BUTTON_MIN_SIZE)
	# These grow to fit their text: the arena name must never be clipped to "...".
	for b: Button in [_team_button, _arena_button]:
		b.clip_text = false
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_arena_button.pressed.connect(func() -> void:
		arena.arena_requested.emit((arena.match_state.arena_index + 1) % ArenaLayouts.count()))


## The main screen: big portraits, centred. Tapping one opens its overlay.
func _build_fighter_grid(box: BoxContainer) -> void:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", SPACING)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(p)
	var head := _label(p, &"HeaderLabel")
	head.text = "Choose your fighter"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fighter_scroller = HScroller.new(true)
	_fighter_scroller.fade_color = COLOR_BG
	_fighter_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(_fighter_scroller)
	var grid := HFlowContainer.new()
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("h_separation", SPACING * 2)
	grid.add_theme_constant_override("v_separation", SPACING * 2)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fighter_scroller.content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fighter_scroller.content.alignment = BoxContainer.ALIGNMENT_CENTER
	_fighter_scroller.content.add_child(grid)
	var count: int = arena.characters.ordered.size()
	_fighter_scroller.resized.connect(func() -> void:
		grid.custom_minimum_size.x = grid_width(_fighter_scroller.size.x, count))
	for c: CharacterData in arena.characters.ordered:
		var card: Button = _card(grid, CHARACTER_CARD_SIZE, _fighter_art(c), [c.display_name])
		var id: StringName = c.id
		_fighter_scroller.on_tap(card, func() -> void: _on_fighter_pressed(id))
		_character_cards[id] = card
		var frame := Panel.new()  # outline + tint over the card: your hover, a teammate's hover, a teammate's lock
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.visible = false
		card.add_child(frame)
		_fighter_frames[id] = frame
		var tags := HBoxContainer.new()
		tags.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 6)
		tags.add_theme_constant_override("separation", 4)
		tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tags)
		_fighter_tags[id] = tags
		var badge: Label = _label(card, &"Label")
		badge.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
		badge.add_theme_font_override("font", UiStyle.body_font(true))
		# A strip across the foot of the portrait.
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, SPACING)
		badge.offset_top = SPACING + FIGHTER_ART_SIZE.y - BADGE_H
		badge.offset_bottom = SPACING + FIGHTER_ART_SIZE.y
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		_fighter_badges[id] = badge
		var mastery: Label = _label(card, &"Label")  # mastery level, bottom right corner of the card
		mastery.text = "Lv %d" % PlayerProfile.level_of(id)
		mastery.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
		mastery.add_theme_font_override("font", UiStyle.bold())
		mastery.add_theme_color_override("font_color", UiStyle.C_YELLOW)
		mastery.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, SPACING)
		mastery.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mastery_badges[id] = mastery


## Width of a grid of `count` fighter cards that wraps into evenly filled rows (4 + 3, not 6 + 1) in `avail` px.
static func grid_width(avail: float, count: int) -> float:
	var gap: float = SPACING * 2.0
	var per_row: int = maxi(1, floori((avail + gap) / (CHARACTER_CARD_SIZE.x + gap)))
	var rows: int = ceili(float(count) / per_row)
	var cols: int = ceili(float(count) / rows)
	return cols * (CHARACTER_CARD_SIZE.x + gap) - gap


## Scrim + the right-hand sheet: showcase on the left, abilities and weapons on the right, READY / back below.
func _build_overlay(stack: Control) -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.clip_contents = true
	_overlay.visible = false
	_overlay.resized.connect(func() -> void: _slide_overlay(false))
	stack.add_child(_overlay)
	_scrim = ColorRect.new()
	_scrim.color = Color(0.0, 0.0, 0.0, SCRIM_ALPHA)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_scrim)
	var tap := Button.new()  # the whole scrim is a close button
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(_close_overlay)
	_overlay.add_child(tap)

	_sheet = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = UiStyle.C_SHADOW
	style.border_width_left = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 16
	_sheet.add_theme_stylebox_override("panel", style)
	_overlay.add_child(_sheet)
	var sheet_box := VBoxContainer.new()
	sheet_box.add_theme_constant_override("separation", SPACING)
	_sheet.add_child(sheet_box)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", SPACING * 2)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet_box.add_child(body)
	_build_stage(body)
	_build_details(body)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", SPACING)
	sheet_box.add_child(bar)
	var back: Button = _button(bar, Vector2(190, READY_MIN_SIZE.y))
	back.text = "‹  Fighters"
	back.clip_text = false
	back.pressed.connect(_close_overlay)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	_add_ready_button(bar)


## The showcase: a framed panel, the fighter at an integer scale under its name and stat bars, the lock state along
## the foot.
func _build_stage(body: BoxContainer) -> void:
	_stage = Panel.new()
	_stage.clip_contents = true
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_stretch_ratio = 0.8
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_STAGE
	style.border_color = UiStyle.C_SHADOW
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_stage.add_theme_stylebox_override("panel", style)
	_stage.resized.connect(_layout_stage)
	body.add_child(_stage)
	_backdrop = StageBackdrop.new()  # the themed pixel-art scene, under everything else
	_stage.add_child(_backdrop)
	_floor_fx = Control.new()  # the fighter's contact shadow, over the scene
	_floor_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floor_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_fx.draw.connect(_draw_floor_fx)
	_stage.add_child(_floor_fx)
	_pivot = Node2D.new()
	_stage.add_child(_pivot)
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pivot.add_child(_sprite)

	var info := VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 18)
	info.add_theme_constant_override("separation", 4)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(info)
	_name_label = _label(info, &"HeaderLabel")
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp: Array = _stat_bar(info, UiStyle.C_RED)
	_hp_label = hp[0]
	_hp_fill = hp[1]
	var armor: Array = _stat_bar(info, UiStyle.C_STEEL)
	_armor_label = armor[0]
	_armor_fill = armor[1]

	_stage_badge = _label(_stage, &"HeaderLabel")
	_stage_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	_stage_badge.offset_top = -44.0
	_stage_badge.offset_bottom = 0.0
	_stage_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_badge.visible = false


## A caption over a thin bar; returns [caption label, fill rect].
func _stat_bar(parent: Node, color: Color) -> Array:
	var cap := _label(parent, &"Label")
	cap.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL + 2)
	cap.add_theme_font_override("font", UiStyle.body_font(true))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	var back := ColorRect.new()
	back.color = Color(0.0, 0.0, 0.0, 0.45)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 0.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	return [cap, fill]


## Right column: the abilities header (title + the three slot chips) stays put; the ability list and, under it,
## the weapons scroll together.
func _build_details(body: BoxContainer) -> void:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", SPACING)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 1.2
	body.add_child(p)
	var pane := HBoxContainer.new()
	pane.add_theme_constant_override("separation", SPACING)
	p.add_child(pane)
	# Two clearly different groups: three ability slots (blue), a divider, the weapon slot (amber).
	var abilities := _pane_group(pane, "ABILITIES", TEAM_ALLY_COLOR, 3.0)
	for i: int in Constants.SKILL_SLOTS:
		_build_slot_card(abilities, i)
	var divider := ColorRect.new()
	divider.color = UiStyle.C_SHADOW
	divider.custom_minimum_size.x = 2.0
	pane.add_child(divider)
	var weapon_group := _pane_group(pane, "WEAPON", WEAPON_COLOR, 1.5)
	_build_slot_card(weapon_group, Constants.SKILL_SLOTS)
	# Two big tabs pick which list shows below; the loadout pane above stays put.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", SPACING)
	p.add_child(tabs)
	for t: int in 2:
		var tb: Button = _button(tabs, Vector2(0.0, TAB_H))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.text = "Abilities" if t == LobbyOverlay.Tab.ABILITIES else "Weapon"
		tb.add_theme_font_override("font", UiStyle.body_font(true))
		tb.add_theme_font_size_override("font_size", LIST_NAME_SIZE + 2)
		tb.pressed.connect(func() -> void: _show_tab(t as LobbyOverlay.Tab))
		_tab_buttons.append(tb)
	_ability_hint = _label(p, &"DimLabel")
	_ability_hint.add_theme_font_size_override("font_size", LIST_TEXT_SIZE)
	_ability_hint.add_theme_font_override("font", UiStyle.body_font())
	_ability_hint.clip_text = true
	_ability_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail_scroller = HScroller.new(true)
	_detail_scroller.fade_color = COLOR_BG
	_detail_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(_detail_scroller)
	_special_row = GridContainer.new()
	_special_row.columns = 1
	_special_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_special_row.add_theme_constant_override("h_separation", SPACING)
	_special_row.add_theme_constant_override("v_separation", 6)
	_detail_scroller.content.add_child(_special_row)
	_detail_scroller.resized.connect(func() -> void:
		_special_row.columns = 2 if _detail_scroller.size.x >= SKILL_TWO_COL_W else 1)
	_weapon_scroller = HScroller.new(true)
	_weapon_scroller.fade_color = COLOR_BG
	_weapon_scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(_weapon_scroller)
	_weapon_row = _weapon_scroller.content
	_weapon_row.add_theme_constant_override("separation", 6)
	_show_tab(LobbyOverlay.Tab.ABILITIES, false)


## Shows one list under the loadout pane (a short fade in) and restyles the tabs: the active one wears its accent.
func _show_tab(t: LobbyOverlay.Tab, animate: bool = true) -> void:
	var changed: bool = _overlay_state.show_tab(t)
	var weapons: bool = _overlay_state.tab == LobbyOverlay.Tab.WEAPON
	_detail_scroller.visible = not weapons
	_weapon_scroller.visible = weapons
	_ability_hint.visible = not weapons
	for i: int in _tab_buttons.size():
		var on: bool = (i == LobbyOverlay.Tab.WEAPON) == weapons
		var color: Color = WEAPON_COLOR if i == LobbyOverlay.Tab.WEAPON else TEAM_ALLY_COLOR
		_outline_selected(_tab_buttons[i], on, color)
		_tab_buttons[i].add_theme_color_override("font_color", color if on else UiStyle.C_WHITE)
		_tab_buttons[i].add_theme_color_override("font_hover_color", color if on else UiStyle.C_WHITE)
		_tab_buttons[i].add_theme_color_override("font_pressed_color", color)
	if _tab_tween != null:
		_tab_tween.kill()
	var shown: Control = _weapon_scroller if weapons else _detail_scroller
	shown.modulate.a = 1.0
	if animate and changed and is_inside_tree():
		shown.modulate.a = 0.0
		_tab_tween = create_tween()
		_tab_tween.tween_property(shown, "modulate:a", 1.0, SLIDE_TIME * 0.6)


## A labelled group of loadout cards: a small coloured caption over a row of cards.
func _pane_group(pane: Node, caption: String, color: Color, ratio: float) -> HBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.size_flags_stretch_ratio = ratio
	pane.add_child(group)
	var label := _label(group, &"Label")
	label.text = caption
	label.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
	label.add_theme_font_override("font", UiStyle.body_font(true))
	label.add_theme_color_override("font_color", color)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SPACING)
	group.add_child(row)
	return row


## One loadout card: its number (or "Weapon"), the icon and the name. Ability cards are buttons that make their slot
## the target for the next pick; the weapon card only shows.
func _build_slot_card(parent: Node, i: int) -> void:
	var weapon: bool = i >= Constants.SKILL_SLOTS
	var card := Button.new()
	card.custom_minimum_size = Vector2(0.0, SLOT_CARD_H)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.theme_type_variation = &"Card"
	card.pressed.connect(func() -> void: _on_slot_pressed(i))
	parent.add_child(card)
	var box: BoxContainer = HBoxContainer.new() if weapon else VBoxContainer.new()  # weapon: icon left, name right
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2 if not weapon else SPACING)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var pic := TextureRect.new()
	pic.custom_minimum_size = SLOT_ICON_SIZE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	var name_label := _label(box, &"Label")
	name_label.add_theme_font_override("font", UiStyle.body_font(true))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if weapon else HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not weapon:
		var tag := _label(card, &"Label")  # slot number, top left
		tag.text = str(i + 1)
		tag.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
		tag.add_theme_font_override("font", UiStyle.body_font(true))
		tag.add_theme_color_override("font_color", UiStyle.C_YELLOW)
		tag.position = Vector2(10, 4)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := Control.new()  # an emptied slot: a dashed outline with a "+"
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.visible = false
	mark.draw.connect(func() -> void: _draw_empty_mark(mark))
	card.add_child(mark)
	_empty_marks.append(mark)
	_slot_cards.append(card)
	_slot_icons.append(pic)
	_slot_names.append(name_label)


## Tapping a slot card shows its list; a filled ability slot is also emptied.
func _on_slot_pressed(i: int) -> void:
	if i >= Constants.SKILL_SLOTS:  # the weapon slot: show the weapons
		_show_tab(LobbyOverlay.Tab.WEAPON)
		return
	_show_tab(LobbyOverlay.Tab.ABILITIES)
	var slots: Array = _slots()
	if slots[i] == &"":
		return
	_remove_slot(i)


## Dashed outline and a plus on an empty slot card.
func _draw_empty_mark(mark: Control) -> void:
	var r := Rect2(Vector2.ZERO, mark.size)
	var c: Color = UiStyle.C_STEEL_D
	for pair: Array in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		mark.draw_dashed_line(pair[0], pair[1], c, 2.0, 8.0)
	var font: Font = UiStyle.body_font(true)
	var size: int = UiStyle.SIZE_TITLE
	var text_size: Vector2 = font.get_string_size("+", HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	mark.draw_string(font, Vector2((r.size.x - text_size.x) * 0.5, (r.size.y + font.get_ascent(size) - font.get_descent(size)) * 0.5),
		"+", HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _remove_slot(slot: int) -> void:
	arena.special_requested.emit(slot, &"")
	_clear_flyer(slot)
	_pop_slot(slot)
	_refresh_loadout()


## The three ability slots as ids, &"" for an emptied one.
func _slots() -> Array:
	return _pick().slice(2)


func _tilt_slots(angle: float) -> void:
	for i: int in Constants.SKILL_SLOTS:
		_slot_cards[i].rotation = angle


## All three slots are taken: a short shake + red flash on the slot cards and a hint to remove one first.
func _flash_full() -> void:
	_full_hint_left = TOAST_TIME
	_refresh_loadout()
	if _flash_tween != null:
		_flash_tween.kill()
	var tween: Tween = create_tween().set_parallel(false)
	_flash_tween = tween
	for i: int in Constants.SKILL_SLOTS:
		_slot_cards[i].pivot_offset = _slot_cards[i].size * 0.5
		_outline_selected(_slot_cards[i], true, UiStyle.C_RED)
	var prev: float = 0.0
	for angle: float in [0.03, -0.03, 0.02, -0.01, 0.0]:
		tween.tween_method(_tilt_slots, prev, angle, 0.05)
		prev = angle
	tween.finished.connect(func() -> void:
		for i: int in Constants.SKILL_SLOTS:
			_slot_cards[i].rotation = 0.0
		_flash_tween = null
		_refresh_loadout())


## Shrinks `label`'s text in the clean sans until it fits `max_w` (never below the old 12), ellipsis as last resort.
func _fit_body(label: Label, text: String, max_w: float, size: int, heavy: bool = false) -> void:
	label.text = text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font: Font = UiStyle.body_font(heavy)
	var fit: int = size
	while fit > UiStyle.SIZE_TINY - 4 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x > max_w:
		fit -= 1
	label.add_theme_font_size_override("font_size", fit)


## Roster + blocker on the left, Leave and the always-visible READY on the right.
func _build_footer(box: BoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", SPACING)
	box.add_child(footer)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_END
	info.add_theme_constant_override("separation", 0)
	footer.add_child(info)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	info.add_child(_rows)
	_blocker = _label(info, &"Label")
	_blocker.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
	_blocker.add_theme_font_override("font", UiStyle.body_font(true))
	_blocker.add_theme_color_override("font_color", UiStyle.C_YELLOW)
	_blocker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var leave: Button = _button(footer, LEAVE_MIN_SIZE)
	leave.text = "Leave"
	leave.size_flags_vertical = Control.SIZE_SHRINK_END
	leave.pressed.connect(func() -> void: arena.leave_requested.emit(false))
	_add_ready_button(footer)


func _add_ready_button(parent: Node) -> void:
	var b: Button = _button(parent, READY_MIN_SIZE)
	b.theme_type_variation = &"PrimaryButton"
	b.add_theme_font_size_override("font_size", UiStyle.SIZE_HEADING)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.pressed.connect(_on_ready_pressed)
	_ready_buttons.append(b)


## A fighter card was tapped: request it (a hover in Teams, the lock comes with READY) and open its overlay.
func _on_fighter_pressed(id: StringName) -> void:
	arena.character_requested.emit(id)
	var slides_in: bool = _overlay_state.open_for(id)
	_show_tab(_overlay_state.tab, false)  # (a fresh fighter resets it to the abilities)
	if arena.local_player != null and arena.local_player.character.id == id:
		_show_preview(arena.local_player.character)  # already your fighter: replay the zoom (else _refresh does it)
	if slides_in:
		_slide_overlay(true)


func _close_overlay() -> void:
	if _overlay_state.close():
		_slide_overlay(true)


## Puts the sheet where the overlay state says: open (docked to the right) or closed (off the right edge), with the
## scrim fading to match. Animated, any slide in flight is replaced, so a tap on a card while it closes just reverses.
func _slide_overlay(animate: bool) -> void:
	if _slide_tween != null:
		_slide_tween.kill()
		_slide_tween = null
	var w: float = _overlay.size.x
	var h: float = _overlay.size.y
	var sheet_w: float = roundf(w * SHEET_FRACTION)
	var open: bool = _overlay_state.is_open
	var x: float = w - sheet_w if open else w
	var alpha: float = SCRIM_ALPHA if open else 0.0
	_sheet.size = Vector2(sheet_w, h)
	_sheet.position.y = 0.0
	if animate and is_inside_tree() and w > 0.0:
		_overlay.visible = true
		var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slide_tween = tween
		tween.tween_property(_sheet, "position:x", x, SLIDE_TIME)
		tween.tween_property(_scrim, "color:a", alpha, SLIDE_TIME)
		tween.finished.connect(func() -> void:
			_slide_tween = null
			_overlay.visible = _overlay_state.is_open
			if not _overlay_state.is_open:
				_clear_flyers())
	else:
		_sheet.position.x = x
		_scrim.color.a = alpha
		_overlay.visible = open


## Integer pixel scale that fits the sprite cell under the name block of a stage this big.
static func preview_scale(stage: Vector2) -> int:
	var cell: float = float(Constants.SPRITE_CELL_SIZE) * 0.9
	var fit: float = minf((stage.x - 40.0) / cell, (stage.y - PREVIEW_TOP - 40.0) / cell)
	return clampi(floori(fit), 2, PREVIEW_MAX_SCALE)


func _layout_stage() -> void:
	var s: int = preview_scale(_stage.size)
	_sprite.scale = Vector2.ONE * s
	var room: float = _stage.size.y - PREVIEW_TOP - 30.0
	_pivot.position = Vector2(_stage.size.x * 0.5, PREVIEW_TOP + room * 0.5 + 4.0 * s)
	_backdrop.art_scale = s
	_backdrop.floor_y = _pivot.position.y + 22.0 * s
	_floor_fx.queue_redraw()


## A soft contact shadow under the fighter's feet.
func _draw_floor_fx() -> void:
	var s: float = _sprite.scale.x
	var feet: Vector2 = _pivot.position + Vector2(0.0, 22.0 * s)
	_floor_fx.draw_set_transform(feet, 0.0, Vector2(1.0, 0.28))
	var r: float = 18.0 * s
	for i: int in 5:
		_floor_fx.draw_circle(Vector2.ZERO, r * (1.0 - i * 0.16), Color(0.0, 0.0, 0.0, 0.17))
	_floor_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Shows `c` in the showcase: a smooth zoom + fade in. A fast change replaces the tween in flight.
func _show_preview(c: CharacterData) -> void:
	_preview_id = c.id
	if _preview_tween != null:
		_preview_tween.kill()
		_preview_tween = null
	_sprite.sprite_frames = c.sprite_frames()
	_sprite.play(&"idle")
	_backdrop.show_theme(StageBackdrop.texture_for(c.id))
	_in_flair = false
	_flair_left = FLAIR_GAP.x
	_layout_stage()
	UiStyle.fit_label(_name_label, c.display_name, maxf(_stage.size.x - 36.0, 120.0), UiStyle.SIZE_HEADING + 6, UiStyle.SIZE_BODY, true)
	var top_hp := 1
	var top_armor := 1
	for o: CharacterData in arena.characters.ordered:
		top_hp = maxi(top_hp, o.max_hp)
		top_armor = maxi(top_armor, o.max_armor)
	_hp_label.text = "HP  %d" % c.max_hp
	_armor_label.text = "Armor  %d" % c.max_armor
	_hp_fill.anchor_right = float(c.max_hp) / top_hp
	_armor_fill.anchor_right = float(c.max_armor) / top_armor
	if not is_inside_tree():
		return
	_pivot.scale = Vector2.ONE * ZOOM_FROM
	_pivot.modulate.a = 0.0
	_preview_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_preview_tween.tween_property(_pivot, "scale", Vector2.ONE, ZOOM_TIME)
	_preview_tween.tween_property(_pivot, "modulate:a", 1.0, ZOOM_TIME * 0.8)


## Now and then the preview runs or swings before settling back to idle.
func _tick_flair(delta: float) -> void:
	if _sprite.sprite_frames == null or not _overlay.visible:
		return
	_flair_left -= delta
	if _flair_left > 0.0:
		return
	var frames: SpriteFrames = _sprite.sprite_frames
	if _in_flair:
		_in_flair = false
		_sprite.play(&"idle")
		_flair_left = randf_range(FLAIR_GAP.x, FLAIR_GAP.y)
		return
	var options: Array[StringName] = []
	for a: StringName in [&"walk", &"attack"]:
		if frames.has_animation(a):
			options.append(a)
	if options.is_empty():
		_flair_left = FLAIR_GAP.y
		return
	var anim: StringName = options[randi() % options.size()]
	_sprite.play(anim)
	_in_flair = true
	var loops: int = FLAIR_WALK_LOOPS if frames.get_animation_loop(anim) else 1
	_flair_left = loops * frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 1.0) + 0.1


## Loadouts reach clients in snapshots, not match updates: restyle when the pick (or a teammate's hover) changes.
func _process(delta: float) -> void:
	if not visible:
		return
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_refresh()
	if _full_hint_left > 0.0:
		_full_hint_left -= delta
		if _full_hint_left <= 0.0:
			_refresh_loadout()
	if _pick() != _shown_pick or _crowd() != _shown_crowd:
		_refresh()
	_tick_flair(delta)


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
		_was_visible = false
		return
	if not _was_visible:  # a fresh loading room starts back on the fighter step
		_was_visible = true
		_overlay_state.close()
		_slide_overlay(false)
	var me: Player = arena.local_player
	_title.text = "LOADING ROOM · %s" % MatchRules.MODE_NAMES[st.mode]
	if st.mode == MatchRules.Mode.TEAMS:
		_rules.text = "First team to %d rounds · %ds rounds · %ds respawns" % [MatchRules.kill_target(st.mode),
			int(minf(st.time_limit, Constants.TEAMS_ROUND_TIME)), int(Constants.TEAMS_RESPAWN_DELAY)]
	else:
		_rules.text = "First to %d kills · %d:%02d" % [MatchRules.kill_target(st.mode),
			int(st.time_limit) / 60, int(st.time_limit) % 60]
	_join_hint.visible = arena.host_address != ""
	_join_hint.text = "Friends join: %s" % LanAddress.friendly(arena.host_address)
	_team_button.visible = shows_team_picker(st.mode, arena.mode)
	_team_button.text = "Team: %s" % MatchRules.LOBBY_TEAM_NAMES[st.team_of(me.player_id)]
	_arena_button.text = "Arena: %s" % ArenaLayouts.NAMES[st.arena_index]
	if _weapons_for != me.character.id:
		_build_weapon_cards(me.character)
	_shown_pick = _pick()
	if _shown_pick[0] != _preview_id:
		_show_preview(me.character)
		if _character_cards.has(_shown_pick[0]):
			_fighter_scroller.reveal(_character_cards[_shown_pick[0]])
	for id: StringName in _character_cards:
		_character_cards[id].theme_type_variation = &"CardSelected" if id == _shown_pick[0] else &"Card"
		_mastery_badges[id].text = "Lv %d" % PlayerProfile.level_of(id)
	for id: StringName in _weapon_cards:
		_weapon_cards[id].theme_type_variation = &"CardSelected" if id == _shown_pick[1] else &"Card"
		_outline_selected(_weapon_cards[id], id == _shown_pick[1], WEAPON_COLOR)
	for id: StringName in _special_cards:
		var slot: int = _shown_pick.slice(2).find(id)
		_special_cards[id].theme_type_variation = &"CardSelected" if slot >= 0 else &"Card"
		_outline_selected(_special_cards[id], slot >= 0)
		_special_badges[id].visible = slot >= 0
		_special_badges[id].text = str(slot + 1)
	_refresh_loadout()

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
			head.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
			head.add_theme_font_override("font", UiStyle.body_font(true))
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
		row.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
		row.add_theme_font_override("font", UiStyle.body_font())
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
	var gap: bool = st.has_gap(me.player_id)
	_mark_fighters(st, me, shown_teams, taker)
	_blocker.text = _toast if _toast_left > 0.0 else "Taken by %s" % _team_name(arena.get_player(taker)) if taker != 0 \
		else "Pick 3 abilities" if gap else st.blocker
	for b: Button in _ready_buttons:
		b.text = ("UNLOCK" if teams_mode else "UNREADY") if _is_ready() else "LOCK IN" if teams_mode else "READY!"
		b.disabled = taker != 0 or gap
		b.theme_type_variation = &"Button" if _is_ready() else &"PrimaryButton"
	_mark_preview(taker)


## Locks held by humans (bots yield to them, so they never block a lock-in).
func _human_locks(st: MatchState) -> Dictionary:
	var out: Dictionary = {}
	for id: int in st.locked:
		if st.ready.has(id):
			out[id] = st.locked[id]
	return out


## Teams hero select on the fighter cards: your hover (blue outline), teammates' hovers (a pill + outline in their
## colour), their locks (dimmed + "LOCKED" strip), your own lock (gold). Enemy picks are never drawn
## (MatchRules.teammate_picks only returns teammates).
func _mark_fighters(st: MatchState, me: Player, shown_teams: Dictionary, taker: int) -> void:
	for id: StringName in _character_cards:
		_fighter_badges[id].visible = false
		_fighter_frames[id].visible = false
		for t: Node in _fighter_tags[id].get_children():
			t.queue_free()
	if st.mode != MatchRules.Mode.TEAMS:
		return
	var picks: Dictionary = MatchRules.teammate_picks(me.player_id, shown_teams, _hovers(), st.locked)
	var order: Array = picks.keys()
	order.sort()  # lowest id first: the outline colour on a shared card never flickers between teammates
	var framed: Dictionary = {}
	for pass_locks: bool in [true, false]:  # a lock's frame wins over a hover's on the same card
		for pid: int in order:
			var who: Player = arena.get_player(pid)
			var fid: StringName = picks[pid][0]
			var is_lock: bool = picks[pid][1]
			if who == null or not _character_cards.has(fid) or is_lock != pass_locks:
				continue
			if is_lock:
				if who.is_bot:  # a bot yields to a human, so its card stays pickable
					_badge(fid, "BOT", UiStyle.C_STEEL)
				else:
					_frame(fid, UiStyle.C_STEEL_D, Color(COLOR_BG, 0.6), 1)
					framed[fid] = true
					_badge(fid, "LOCKED · P%d" % pid, UiStyle.C_ORANGE)
			else:  # hovering: a pill in their colour (side by side when shared) and an outline
				_pill(fid, "P%d" % pid, who.display_color)
				if not framed.has(fid):
					_frame(fid, who.display_color, Color(who.display_color, 0.1), 1)
					framed[fid] = true
	if not _character_cards.has(me.character.id):
		return
	if _is_ready():
		_character_cards[me.character.id].theme_type_variation = &"CardGold"
		_badge(me.character.id, "LOCKED IN", UiStyle.C_YELLOW)
	else:  # your pick: a bright outline and a lighter card
		_frame(me.character.id, TEAM_ALLY_COLOR, Color(TEAM_ALLY_COLOR, 0.14), 2)


func _frame(fighter: StringName, border: Color, fill: Color, width: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	var f: Panel = _fighter_frames[fighter]
	f.add_theme_stylebox_override("panel", box)
	f.visible = true


## A small rounded tag at the top of a card, readable on any teammate colour.
func _pill(fighter: StringName, text: String, color: Color) -> void:
	var pill := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 1.0
	pill.add_theme_stylebox_override("panel", box)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fighter_tags[fighter].add_child(pill)
	var l: Label = _label(pill, &"Label")
	l.add_theme_font_size_override("font_size", UiStyle.SIZE_TINY)
	l.add_theme_font_override("font", UiStyle.body_font(true))
	l.add_theme_color_override("font_color", UiStyle.C_OUTLINE if color.get_luminance() > 0.4 else UiStyle.C_WHITE)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _badge(fighter: StringName, text: String, color: Color) -> void:
	var badge: Label = _fighter_badges[fighter]
	badge.text = text
	badge.add_theme_color_override("font_color", color)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.03, 0.07, 0.85)
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	badge.add_theme_stylebox_override("normal", box)
	badge.visible = true


func _build_weapon_cards(c: CharacterData) -> void:
	_weapons_for = c.id
	_weapon_cards.clear()
	_weapon_icons.clear()
	_clear_flyers()
	for child: Node in _weapon_row.get_children():
		child.queue_free()
	for w: WeaponData in arena.weapons_for(c):
		var art: TextureRect = _art(w.sprite, WEAPON_ART_SCALE)
		var card: Button = _weapon_card(art, w)
		var id: StringName = w.id
		_weapon_scroller.on_tap(card, func() -> void: _on_weapon_pressed(id))
		_weapon_cards[id] = card
		_weapon_icons[id] = art

	_special_cards.clear()
	_special_badges.clear()
	_special_icons.clear()
	for child: Node in _special_row.get_children():
		child.queue_free()
	for sk: SkillData in SkillCatalog.shared().specials_for(c):
		var card: Button = _skill_row(sk)
		var sid: StringName = sk.id
		_detail_scroller.on_tap(card, func() -> void: _on_special_pressed(sid))
		_special_cards[sid] = card
		var badge: Label = _label(card, &"Label")
		badge.add_theme_font_size_override("font_size", UiStyle.SIZE_HEADING)
		badge.add_theme_font_override("font", UiStyle.body_font(true))
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, SPACING * 2)
		badge.add_theme_color_override("font_color", UiStyle.C_YELLOW)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_special_badges[sid] = badge


## A plain toggle: an unequipped ability fills the first empty slot (its icon flies in), an equipped one is removed,
## and with all three slots full nothing is replaced.
func _on_special_pressed(id: StringName) -> void:
	var r: Dictionary = LobbyOverlay.toggle(_slots(), id)
	match r["kind"]:
		"add":
			var slot: int = r["slot"]
			arena.special_requested.emit(slot, id)
			if _special_icons.has(id):
				_fly_icon(_special_icons[id], slot)
			_refresh_loadout()
			var after: Array = _slots()  # (the server's answer may not be back yet)
			after[slot] = id
			if _overlay_state.ability_added(after):
				_show_tab(LobbyOverlay.Tab.WEAPON)
		"remove":
			_remove_slot(r["slot"])
		_:
			_flash_full()


func _on_weapon_pressed(id: StringName) -> void:
	arena.weapon_requested.emit(id)
	if _weapon_icons.has(id) and id != _shown_pick[1]:
		_fly_icon(_weapon_icons[id], Constants.SKILL_SLOTS)


## A copy of `from`'s icon flies from its row into slot card `slot` over FLY_TIME, then the slot pops. Replaces
## whatever was still flying into that slot, so quick taps never leave stray icons.
func _fly_icon(from: TextureRect, slot: int) -> void:
	_clear_flyer(slot)
	if from == null or from.texture == null or not _overlay.visible or not is_inside_tree():
		return
	var to: Control = _slot_icons[slot]
	var origin: Vector2 = _overlay.get_global_rect().position
	var fly := TextureRect.new()
	fly.texture = from.texture
	fly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.position = from.get_global_rect().position - origin
	fly.size = from.size
	_overlay.add_child(fly)
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(fly, "position", to.get_global_rect().position - origin, FLY_TIME)
	tween.tween_property(fly, "size", to.size, FLY_TIME)
	tween.finished.connect(func() -> void:
		_clear_flyer(slot)
		_pop_slot(slot))
	_slot_icons[slot].modulate.a = 0.0  # the slot shows its new icon only once the flying one lands
	_flyers[slot] = [fly, tween]


func _clear_flyer(slot: int) -> void:
	if not _flyers.has(slot):
		return
	var entry: Array = _flyers[slot]
	_flyers.erase(slot)
	_slot_icons[slot].modulate.a = 1.0
	(entry[1] as Tween).kill()
	if is_instance_valid(entry[0]):
		(entry[0] as Node).queue_free()


func _clear_flyers() -> void:
	for slot: int in _flyers.keys():
		_clear_flyer(slot)


## A quick scale pop on a slot card (replaces one still running).
func _pop_slot(slot: int) -> void:
	var card: Button = _slot_cards[slot]
	if card.has_meta(&"pop"):
		(card.get_meta(&"pop") as Tween).kill()
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * POP_SCALE, POP_TIME * 0.5)
	tween.tween_property(card, "scale", Vector2.ONE, POP_TIME * 0.5)
	card.set_meta(&"pop", tween)


## A weapon row: art on the left; name, stats and hook stacked on the right, all in the pixel body font.
func _weapon_card(art: Control, w: WeaponData) -> Button:
	var card := _button(_weapon_row, Vector2(0.0, WEAPON_CARD_H))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, SPACING)
	row.add_theme_constant_override("separation", SPACING * 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.custom_minimum_size.x = 100.0
	row.add_child(art)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var lines: Array[String] = [w.display_name, "%d dmg · %s" % [w.damage * maxi(1, w.pellets),
		"free" if w.energy_cost == 0 else "%d energy" % w.energy_cost], w.hook]
	for i: int in lines.size():
		if lines[i] == "":
			continue
		var l: Label = _label(text, &"Label" if i == 0 else &"DimLabel")
		l.add_theme_font_override("font", UiStyle.body_font(i == 0))
		l.add_theme_font_size_override("font_size", LIST_NAME_SIZE if i == 0 else LIST_TEXT_SIZE)
		l.text = lines[i]
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## A special row: icon, bold name with its cooldown on the right, one-line description below.
func _skill_row(sk: SkillData) -> Button:
	var b := _button(_special_row, Vector2(0.0, SKILL_ROW_H))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.theme_type_variation = &"Card"
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, SPACING - 2)
	row.offset_right = -(SPACING + 40.0)  # room for the 1 / 2 / 3 badge
	row.add_theme_constant_override("separation", SPACING)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var pic := TextureRect.new()
	pic.texture = sk.icon
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = SKILL_ICON_SIZE
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	_special_icons[sk.id] = pic
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", SPACING)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(top)
	var name_label: Label = _label(top, &"Label")
	name_label.add_theme_font_override("font", UiStyle.body_font(true))
	name_label.add_theme_font_size_override("font_size", LIST_NAME_SIZE)
	name_label.text = sk.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cd_label: Label = _label(top, &"Label")
	cd_label.add_theme_font_size_override("font_size", LIST_TEXT_SIZE)
	cd_label.add_theme_font_override("font", UiStyle.body_font(true))
	cd_label.add_theme_color_override("font_color", UiStyle.C_TEAL_L)
	cd_label.text = "CD %ds" % roundi(sk.cooldown)
	var blurb_label: Label = _label(text, &"DimLabel")
	blurb_label.add_theme_font_size_override("font_size", LIST_TEXT_SIZE)
	blurb_label.add_theme_font_override("font", UiStyle.body_font())
	blurb_label.text = sk.blurb
	for l: Label in [name_label, blurb_label]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = true  # never spill past the row; a too-long blurb ends in "…"
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## A picked special / weapon card or the target slot: an outline and tint over the card style (removed when off).
func _outline_selected(card: Button, on: bool, color: Color = TEAM_ALLY_COLOR) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		if not on:
			card.remove_theme_stylebox_override(state)
			continue
		var box := StyleBoxFlat.new()
		box.bg_color = Color(color, 0.16)
		box.border_color = color
		box.set_border_width_all(2)
		box.set_corner_radius_all(3)
		card.add_theme_stylebox_override(state, box)


## The loadout pane: what each slot holds now (icon + name), the target ability slot outlined in gold.
func _refresh_loadout() -> void:
	var me: Player = arena.local_player
	if me == null or _slot_cards.is_empty():
		return
	for i: int in Constants.SKILL_SLOTS:
		var empty: bool = arena.match_state.slot_empty(me.player_id, i)
		_slot_icons[i].visible = not empty
		_slot_names[i].visible = not empty
		_empty_marks[i].visible = empty
		_empty_marks[i].queue_redraw()
		if _flash_tween == null:  # filled ability slots carry the blue accent, like the equipped rows below
			_outline_selected(_slot_cards[i], not empty)
		if not empty:
			_slot_icons[i].texture = me.skills[i].data.icon
			_fit_body(_slot_names[i], me.skills[i].data.display_name, 140.0, LIST_TEXT_SIZE, true)
	var gap: bool = arena.match_state.has_gap(me.player_id)
	_ability_hint.text = "Pick 3 abilities" if gap else "Tap an ability to remove it first" if _full_hint_left > 0.0 \
		else "Tap an ability to equip or remove it"
	_ability_hint.add_theme_color_override("font_color", UiStyle.C_YELLOW if gap or _full_hint_left > 0.0 else UiStyle.C_DIM)
	var w: int = Constants.SKILL_SLOTS
	_slot_icons[w].texture = me.weapon.data.sprite
	_fit_body(_slot_names[w], me.weapon.data.display_name, 118.0, LIST_TEXT_SIZE, true)
	_outline_selected(_slot_cards[w], true, WEAPON_COLOR)


## The preview's lock state: dimmed with "LOCKED · Px" when a teammate holds this fighter, gold when you locked in.
func _mark_preview(taker: int) -> void:
	var text: String = ""
	var color: Color = UiStyle.C_ORANGE
	if arena.match_state.mode == MatchRules.Mode.TEAMS:
		if taker != 0:
			text = "LOCKED · P%d" % taker
		elif _is_ready():
			text = "LOCKED IN"
			color = UiStyle.C_YELLOW
	_stage_badge.visible = text != ""
	_stage_badge.text = text
	_stage_badge.add_theme_color_override("font_color", color)
	_sprite.modulate = Color(0.45, 0.45, 0.5) if taker != 0 else Color.WHITE


## The local player's (character id, weapon id, then the special id of each slot).
func _pick() -> Array[StringName]:
	var me: Player = arena.local_player
	if me == null:
		return [&"", &"", &"", &"", &""]
	var out: Array[StringName] = [me.character.id, me.weapon.data.id]
	for i: int in Constants.SKILL_SLOTS:  # an emptied slot reads as &""
		out.append(&"" if arena.match_state.slot_empty(me.player_id, i) else me.skills[i].data.id)
	return out


func _is_ready() -> bool:
	return arena.local_player != null and arena.match_state.ready.has(arena.local_player.player_id)


## Cycles Auto -> A -> B.
## Only a LAN lobby with friends needs to pick a side; offline the player is auto-placed and bots fill the rest.
static func shows_team_picker(match_mode: MatchRules.Mode, arena_mode: Arena.Mode) -> bool:
	return match_mode == MatchRules.Mode.TEAMS and arena_mode != Arena.Mode.OFFLINE


func _on_team_pressed() -> void:
	arena.team_requested.emit((arena.match_state.team_of(arena.local_player.player_id) + 1) % (MatchRules.TEAM_B + 1))


func _on_ready_pressed() -> void:
	var will_be_ready: bool = not _is_ready()
	arena.ready_requested.emit(will_be_ready)
	if will_be_ready and _overlay_state.is_open:  # locked in: back to the grid, your card turns gold
		_overlay_state.ready_pressed(true)
		_slide_overlay(true)


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
		var avail: float = min_size.x - SPACING * 2.0 - 8.0
		if i == 0:
			l.add_theme_font_override("font", UiStyle.bold())
			UiStyle.fit_label(l, lines[i], avail, UiStyle.SIZE_BODY, UiStyle.SIZE_TINY - 4, true)
		else:  # stats / hook lines: the clean sans, shrunk to the card (never below the old 12)
			l.add_theme_font_override("font", UiStyle.body_font())
			_fit_body(l, lines[i], avail, UiStyle.SIZE_SMALL)
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
	add_theme_stylebox_override("panel", style)
	var i: Vector4 = UiStyle.safe_insets(get_viewport())
	_margin.add_theme_constant_override("margin_left", int(i.x) + SPACING)
	_margin.add_theme_constant_override("margin_top", int(i.y) + SPACING)
	_margin.add_theme_constant_override("margin_right", int(i.z) + SPACING)
	_margin.add_theme_constant_override("margin_bottom", int(i.w))
	if _sheet != null:
		var sheet: StyleBoxFlat = _sheet.get_theme_stylebox("panel") as StyleBoxFlat
		sheet.content_margin_left = SPACING * 2
		sheet.content_margin_top = i.y + SPACING
		sheet.content_margin_right = i.z + SPACING
		sheet.content_margin_bottom = i.w


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
