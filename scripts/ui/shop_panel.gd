class_name ShopPanel
extends Control
## Full-screen "Shop" from the main menu: spend gold on blind boxes. Pick a fighter (its box only rolls its own locked
## abilities and weapons), see the odds and what is still locked, open a box (`Unlocks.open_box` decides at the tap),
## then `BoxOpening` plays the reveal. Gold only. Mounted on its own top CanvasLayer like ProfilePanel.

const LAYER: int = 110
const SPACING: int = 10
const COLOR_BG: Color = Color(0.07, 0.07, 0.13)
const COLOR_STAGE: Color = Color(0.105, 0.105, 0.19)
const BACK_SIZE: Vector2 = Vector2(150, UiStyle.TOUCH_MIN_H)
const OPEN_SIZE: Vector2 = Vector2(0, UiStyle.TOUCH_MIN_H)
const CARD_SIZE: Vector2 = Vector2(112, 132)
const PORTRAIT_SIZE: Vector2 = Vector2(96, 72)
const PORTRAIT_SCALE: float = 1.25
const SIDE_W: float = 430.0
const SLOT_SIZE: float = 56.0
const BOX_FPS: float = 8.0
const IDLE_CELL: int = 64
const COLOR_DISABLED_TEXT: Color = Color(0.7, 0.7, 0.78)

var _on_close: Callable
var _characters: CharacterCatalog
var _fighter: CharacterData
var _cards: Dictionary[StringName, Button] = {}
var _left_labels: Dictionary[StringName, Label] = {}
var _gold: GoldChip
var _stage: Control
var _idle: Texture2D
var _idle_frames: int = 8
var _name_label: Label
var _left_label: Label
var _collection_title: Label
var _slots: HFlowContainer
var _odds: Label
var _open_button: Button
var _reason: Label
var _scroller: HScroller
var _sfx: Sfx
var _opening: BoxOpening
## Seeded for tests / previews; null = Unlocks randomizes.
var rng: RandomNumberGenerator


static func show_on(host: Node, on_closed: Callable = Callable()) -> void:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := ShopPanel.new()
	panel._on_close = func() -> void:
		layer.queue_free()
		if on_closed.is_valid():
			on_closed.call()
	layer.add_child(panel)
	host.get_tree().root.add_child.call_deferred(layer)


## "" when a box can be opened, else why not (shown on the greyed button).
static func open_state(gold: int, pool_size: int) -> String:
	if pool_size <= 0:
		return "All unlocked"
	if gold < Unlocks.BOX_PRICE:
		return "Not enough gold"
	return ""


## "Common 60% · Rare 30% · Epic 10%"
static func odds_text() -> String:
	var total: int = 0
	for w: int in Unlocks.RARITY_WEIGHTS:
		total += w
	var parts: Array[String] = []
	for i: int in Unlocks.RARITY_WEIGHTS.size():
		parts.append("%s %d%%" % [Unlocks.RARITY_NAMES[i], roundi(100.0 * Unlocks.RARITY_WEIGHTS[i] / total)])
	return " · ".join(parts)


## Every ability and weapon a box can ever give `c` (locked or not): [{kind, id, rarity}], abilities first.
static func lockable(c: CharacterData) -> Array:
	return Unlocks.lockable(c)


## "Duplicates refund 30 / 50 / 80 gold · new item guaranteed after 3 duplicates"
static func dupe_text() -> String:
	var parts: Array[String] = []
	for g: int in Unlocks.DUPE_REFUND:
		parts.append(str(g))
	return "Duplicates refund %s gold · new item guaranteed after %d duplicates" % [" / ".join(parts), Unlocks.PITY_DUPES]


## What the reveal card and the collection show for a pool entry: {name, kind, icon, weapon, desc, rarity}. Descriptions
## are the lobby rows' own text: an ability's blurb, a weapon's damage / cost line + hook.
static func item_info(entry: Dictionary) -> Dictionary:
	if entry["kind"] == &"skill":
		var s: SkillData = SkillCatalog.shared().get_skill(entry["id"])
		return {"name": s.display_name, "kind": "Ability", "icon": s.icon, "weapon": false, "desc": s.blurb,
			"rarity": s.rarity}
	var w: WeaponData = _weapon_catalog().get_weapon(entry["id"])
	var desc: String = "%d dmg · %s" % [w.damage * maxi(1, w.pellets), "free" if w.energy_cost == 0 else "%d energy" % w.energy_cost]
	if w.hook != "":
		desc += "\n" + w.hook
	return {"name": w.display_name, "kind": "Weapon", "icon": w.sprite, "weapon": true, "desc": desc, "rarity": w.rarity}


static var _weapons: WeaponCatalog


static func _weapon_catalog() -> WeaponCatalog:
	if _weapons == null:
		_weapons = WeaponCatalog.load_all()
	return _weapons


func _ready() -> void:
	PlayerProfile.ensure_loaded()
	GameSettings.ensure_loaded()
	_characters = CharacterCatalog.load_all()
	_idle = load("res://assets/fx/box_common_idle.png")
	_idle_frames = BoxOpening.frames_of(_idle.get_size())
	_sfx = Sfx.new()
	add_child(_sfx)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var i: Vector4 = UiStyle.safe_insets(get_viewport())
	margin.add_theme_constant_override("margin_left", int(i.x))
	margin.add_theme_constant_override("margin_top", int(i.y))
	margin.add_theme_constant_override("margin_right", int(i.z))
	margin.add_theme_constant_override("margin_bottom", int(i.w))
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", SPACING)
	margin.add_child(root)
	root.add_child(_build_top_bar())
	root.add_child(_build_picker())
	root.add_child(_build_body())
	var first: CharacterData = _default_fighter()
	_select(first.id)
	_scroller.reveal(_cards[first.id])


## The fighter you play most (mastery XP) that still has something to open, else the first.
func _default_fighter() -> CharacterData:
	var best: CharacterData = null
	for c: CharacterData in _characters.ordered:
		if Unlocks.box_pool(c).is_empty():
			continue
		if best == null or PlayerProfile.xp_of(c.id) > PlayerProfile.xp_of(best.id):
			best = c
	return best if best != null else _characters.ordered[0]


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", SPACING)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = BACK_SIZE
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_close)
	bar.add_child(back)
	var title := Label.new()
	title.text = "SHOP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiStyle.bold())
	title.add_theme_font_size_override("font_size", UiStyle.SIZE_TITLE)
	bar.add_child(title)
	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.custom_minimum_size.x = BACK_SIZE.x
	_gold = GoldChip.new(UiStyle.SIZE_HEADING)
	_gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(_gold)
	bar.add_child(right)
	return bar


func _build_picker() -> Control:
	_scroller = HScroller.new()
	_scroller.fade_color = COLOR_BG
	var row: BoxContainer = _scroller.content
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", SPACING)
	for c: CharacterData in _characters.ordered:
		var card := Button.new()
		card.theme_type_variation = &"Card"
		card.custom_minimum_size = CARD_SIZE
		card.focus_mode = Control.FOCUS_NONE
		row.add_child(card)
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		col.add_theme_constant_override("separation", 0)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(col)
		var art: Control = _portrait(c)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(art)
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", UiStyle.bold())
		name_label.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiStyle.fit_label(name_label, c.display_name, CARD_SIZE.x - 20.0, UiStyle.SIZE_SMALL, UiStyle.SIZE_TINY - 2, true)
		col.add_child(name_label)
		var left := Label.new()
		left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left.add_theme_font_override("font", UiStyle.body_font(true))
		left.add_theme_font_size_override("font_size", UiStyle.SIZE_TINY)
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(left)
		var id: StringName = c.id
		_scroller.on_tap(card, func() -> void: _select(id))
		_cards[id] = card
		_left_labels[id] = left
	return _scroller


func _build_body() -> Control:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", SPACING * 2)
	_stage = Control.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	body.add_child(_stage)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = SIDE_W
	side.add_theme_constant_override("separation", SPACING)
	body.add_child(side)
	_name_label = Label.new()
	_name_label.add_theme_font_override("font", UiStyle.bold())
	_name_label.add_theme_font_size_override("font_size", UiStyle.SIZE_HEADING)
	side.add_child(_name_label)
	_left_label = Label.new()
	_left_label.theme_type_variation = &"DimLabel"
	side.add_child(_left_label)
	_collection_title = Label.new()
	_collection_title.theme_type_variation = &"DimLabel"
	_collection_title.add_theme_font_override("font", UiStyle.body_font(true))
	side.add_child(_collection_title)
	_slots = HFlowContainer.new()
	_slots.add_theme_constant_override("h_separation", 6)
	_slots.add_theme_constant_override("v_separation", 6)
	side.add_child(_slots)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	_odds = Label.new()
	_odds.text = odds_text()
	_odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_odds.add_theme_font_override("font", UiStyle.body_font(true))
	_odds.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
	_odds.add_theme_color_override("font_color", UiStyle.C_STEEL)
	side.add_child(_odds)
	var dupes := Label.new()
	dupes.text = dupe_text()
	dupes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dupes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dupes.add_theme_font_size_override("font_size", UiStyle.SIZE_TINY)
	dupes.add_theme_color_override("font_color", UiStyle.C_DIM)
	side.add_child(dupes)
	_open_button = Button.new()
	_open_button.theme_type_variation = &"PrimaryButton"
	_open_button.custom_minimum_size = OPEN_SIZE
	_open_button.focus_mode = Control.FOCUS_NONE
	_open_button.pressed.connect(_on_open)
	side.add_child(_open_button)
	_reason = Label.new()
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.add_theme_font_size_override("font_size", UiStyle.SIZE_SMALL)
	_reason.add_theme_color_override("font_color", UiStyle.C_ORANGE)
	_reason.custom_minimum_size.y = UiStyle.SIZE_SMALL + 6
	side.add_child(_reason)
	return body


## Animated idle portrait (same window the lobby roster uses).
func _portrait(c: CharacterData) -> Control:
	var window := Control.new()
	window.custom_minimum_size = PORTRAIT_SIZE
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = c.sprite_frames()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * PORTRAIT_SCALE
	sprite.position = PORTRAIT_SIZE * 0.5
	window.add_child(sprite)
	sprite.play(&"idle")
	return window


# --- selection / state ------------------------------------------------------------------------------------------

func _select(id: StringName) -> void:
	_fighter = _characters.get_character(id)
	_refresh()


func _refresh() -> void:
	for c: CharacterData in _characters.ordered:
		var n: int = Unlocks.box_pool(c).size()
		var left: Label = _left_labels[c.id]
		left.text = "%d left" % n if n > 0 else "All unlocked"
		left.add_theme_color_override("font_color", UiStyle.C_YELLOW if n > 0 else UiStyle.C_TEAL_L)
		_cards[c.id].theme_type_variation = &"CardGold" if c.id == _fighter.id else &"Card"
	var pool: Array = Unlocks.box_pool(_fighter)
	var all: Array = lockable(_fighter)
	_name_label.text = _fighter.display_name
	_left_label.text = "%d left in the box" % pool.size() if not pool.is_empty() else "Everything unlocked"
	_collection_title.text = "COLLECTION  %d / %d" % [all.size() - pool.size(), all.size()]
	for child: Node in _slots.get_children():
		child.queue_free()
		_slots.remove_child(child)
	for entry: Dictionary in all:
		_slots.add_child(_slot(entry, _is_unlocked(entry)))
	var state: String = open_state(PlayerProfile.gold, pool.size())
	_open_button.text = "Open box · %d" % Unlocks.BOX_PRICE
	_open_button.disabled = state != ""
	_open_button.modulate = Color(0.75, 0.75, 0.8) if state != "" else Color.WHITE
	_reason.text = state
	_stage.queue_redraw()


func _is_unlocked(entry: Dictionary) -> bool:
	if entry["kind"] == &"skill":
		return Unlocks.is_skill_unlocked(_fighter, SkillCatalog.shared().get_skill(entry["id"]))
	return Unlocks.is_weapon_unlocked(_fighter, _weapon_catalog().get_weapon(entry["id"]))


## One collection tile: the item's icon in its rarity colour, dimmed with a padlock while still locked.
func _slot(entry: Dictionary, unlocked: bool) -> Control:
	var info: Dictionary = item_info(entry)
	var edge: Color = Unlocks.RARITY_COLORS[clampi(int(entry["rarity"]), 0, Unlocks.RARITY_COLORS.size() - 1)]
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, tile.size)
		tile.draw_rect(r, UiStyle.C_OUTLINE)
		tile.draw_rect(r.grow(-2.0), Color(edge, 1.0 if unlocked else 0.45), false, 2.0)
		var tex: Texture2D = info["icon"]
		if tex != null:
			var k: float = maxf(1.0, floorf((SLOT_SIZE - 12.0) / maxf(tex.get_width(), tex.get_height())))
			UiStyle.draw_icon(tile, tex, r.get_center(), k, Color.WHITE if unlocked else Color(0.35, 0.35, 0.4))
		if not unlocked:
			var p: Vector2 = Vector2(SLOT_SIZE - 17.0, SLOT_SIZE - 20.0)
			tile.draw_arc(p + Vector2(6.0, 5.0), 4.0, PI, TAU, 8, edge, 2.0)
			tile.draw_rect(Rect2(p + Vector2(0.0, 5.0), Vector2(12.0, 10.0)), edge))
	return tile


# --- opening ----------------------------------------------------------------------------------------------------

## The result is decided here, the animation only plays it. Returns what was rolled ({} if nothing was opened).
func _on_open() -> Dictionary:
	if _opening != null or _fighter == null:
		return {}
	var got: Dictionary = Unlocks.open_box(_fighter, rng)
	if got.is_empty():
		_refresh()
		return {}
	var again: bool = open_state(PlayerProfile.gold, Unlocks.box_pool(_fighter).size()) == ""
	var info: Dictionary = item_info(got)
	info["dupe"] = got["dupe"]
	info["refund"] = got["refund"]
	_opening = BoxOpening.new(info, again, _sfx)
	_opening.closed.connect(_on_opening_closed)
	add_child(_opening)
	return got


func _on_opening_closed(again: bool) -> void:
	_opening = null
	_gold.set_gold(PlayerProfile.gold, true)
	_refresh()
	if again:
		_on_open.call_deferred()


# --- drawing / input --------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_stage.queue_redraw()


## The fighter's box on a lit floor, idle strip at the biggest whole-number scale that fits.
func _draw_stage() -> void:
	var r := Rect2(Vector2.ZERO, _stage.size)
	_stage.draw_rect(r, COLOR_STAGE)
	var s: int = clampi(int(minf(r.size.x, r.size.y) / (IDLE_CELL + 8.0)), 1, 6)
	var cell: float = IDLE_CELL * s
	var floor_y: float = r.size.y * 0.5 + cell * 0.5 - 5.0 * s
	var mid: float = r.size.x * 0.5
	# soft floor glow: stacked ellipses, brightest in the middle
	for k: int in 7:
		var w: float = cell * (1.5 - 0.2 * k)
		var pts := PackedVector2Array()
		for a: int in 32:
			var ang: float = TAU * a / 32.0
			pts.append(Vector2(mid + cos(ang) * w * 0.5, floor_y + sin(ang) * w * 0.1))
		_stage.draw_colored_polygon(pts, Color(UiStyle.C_STEEL, 0.045))
	var f: int = int(Time.get_ticks_msec() / 1000.0 * BOX_FPS) % _idle_frames
	_stage.draw_texture_rect_region(_idle, Rect2(Vector2(mid - cell * 0.5, floor_y - (IDLE_CELL - 5) * s).round(), Vector2.ONE * cell),
		Rect2(f * IDLE_CELL, 0, IDLE_CELL, IDLE_CELL))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _opening == null:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	if _on_close.is_valid():
		_on_close.call()
