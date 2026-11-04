class_name BoxOpening
extends Control
## The blind-box opening, full screen over the shop. The result is decided before this plays (`info` = ShopPanel.item_info):
## the common box rattles (`box_common_shake`, twice, epic three times), cuts to the ROLLED rarity's `box_<r>_open` strip,
## and on the burst frame a flash, `rays_<r>` and the reveal card come out of the box. A tap skips ahead: to the burst,
## then to the finished card, then it dismisses. `closed(again)` fires once ("Open another" -> true).
## Strips: frame count = width / height. The 64 px shake cell is drawn so its floor shadow (5 px above the cell bottom)
## lands on y 133 of the 160 px open cell, so the cut does not jump. Everything is drawn at an integer scale, nearest.

signal closed(again: bool)

const SHAKE_FPS: float = 16.0
const OPEN_FPS: float = 14.0
const RAYS_FPS: float = 6.0
const SHAKE_CELL: int = 64
const OPEN_CELL: int = 160
const RAYS_CELL: int = 128
## Open-cell y of the floor shadow, and the shake cell's own (64 - 5).
const OPEN_FLOOR_Y: int = 133
const SHAKE_FLOOR_Y: int = 59
const BOX_TOP_ABOVE_FLOOR: int = 40
## Open frame the lid blows off and the light bursts out.
const BURST_FRAME: int = 1
const SHAKE_LOOPS: Array[int] = [2, 2, 3]
## Seconds from the burst to the card starting to rise (epic holds longer), and how long it rises.
const CARD_DELAY: Array[float] = [0.2, 0.3, 0.8]
const CARD_RISE: float = 0.5
const RAYS_FADE: Array[float] = [0.5, 0.5, 0.9]
const FLASH_TIME: Array[float] = [0.28, 0.32, 0.5]
const SHAKE_PX: Array[float] = [5.0, 6.0, 9.0]
## Clear space kept between the composition (rays / card) and the top of the screen.
const EDGE_MARGIN: float = 16.0
const BURST_KICK: float = 16.0
const KICK_TIME: float = 0.35
const VEIL: Color = Color(0.02, 0.02, 0.06, 0.96)
const CARD_W: float = 380.0
const CARD_BG: Color = Color(0.07, 0.07, 0.14, 0.97)
const BUTTON_W: float = 250.0
const BUTTON_FADE: float = 0.25

var info: Dictionary
var can_again: bool
var rarity: int = 0
## Preview tools: stop the clock and set it by hand with `jump_to`.
var frozen: bool = false

var _t: float = 0.0
var _prev_t: float = -1.0
var _shake: Texture2D
var _open: Texture2D
var _rays: Texture2D
var _shake_frames: int
var _open_frames: int
var _rays_frames: int
var _stage: Control
var _flash: ColorRect
var _card: PanelContainer
var _buttons: HBoxContainer
var _sfx: Sfx
var _rng := RandomNumberGenerator.new()
var _done: bool = false
var _balance: GoldChip


## Frames in a horizontal strip of square cells.
static func frames_of(strip_size: Vector2) -> int:
	return maxi(1, roundi(strip_size.x / maxf(strip_size.y, 1.0)))


static func rarity_id(r: int) -> String:
	return ["common", "rare", "epic"][clampi(r, 0, 2)]


func _init(info_: Dictionary, can_again_: bool, sfx: Sfx = null) -> void:
	info = info_
	can_again = can_again_
	_sfx = sfx
	rarity = clampi(int(info["rarity"]), 0, Unlocks.RARITY_NAMES.size() - 1)


## A duplicate (`info.dupe`, `info.refund` gold): same sequence and card, a softer chime, and the refund counts into the balance.
func is_dupe() -> bool:
	return bool(info.get("dupe", false))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shake = load("res://assets/fx/box_common_shake.png")
	_open = load("res://assets/fx/box_%s_open.png" % rarity_id(rarity))
	_rays = load("res://assets/fx/rays_%s.png" % rarity_id(rarity))
	_shake_frames = frames_of(_shake.get_size())
	_open_frames = frames_of(_open.get_size())
	_rays_frames = frames_of(_rays.get_size())
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_build_card()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_build_buttons()
	_build_balance()
	resized.connect(_place)
	_place()


# --- timeline ---------------------------------------------------------------------------------------------------

func shake_time() -> float:
	return SHAKE_LOOPS[rarity] * _shake_frames / SHAKE_FPS


func burst_time() -> float:
	return shake_time() + BURST_FRAME / OPEN_FPS


func card_time() -> float:
	return burst_time() + CARD_DELAY[rarity]


func settled_time() -> float:
	return card_time() + CARD_RISE


## Scale of the strips: whole numbers only, as big as the screen allows while the card still fits above the box.
func art_scale() -> int:
	var card_fit: int = int((floor_y() - _card_height() - 14.0 - EDGE_MARGIN) / BOX_TOP_ABOVE_FLOOR)
	# rays are centred on the box top: their top edge is (box top + half a rays cell) above the floor
	var rays_fit: int = int((floor_y() - EDGE_MARGIN) / (BOX_TOP_ABOVE_FLOOR + RAYS_CELL * 0.5))
	return clampi(mini(mini(card_fit, rays_fit), int(size.y / 200.0)), 1, 4)


func floor_y() -> float:
	return size.y * 0.74


func jump_to(t: float) -> void:
	_prev_t = _t
	_t = t
	_update()


func _process(delta: float) -> void:
	if frozen:
		return
	_prev_t = _t
	_t += delta
	_update()


func _update() -> void:
	_events()
	_place()
	queue_redraw()


## True the frame the clock passes `at`.
func _crossed(at: float) -> bool:
	return _prev_t < at and _t >= at


func _events() -> void:
	var loops: int = SHAKE_LOOPS[rarity]
	# Rattles: one per frame pair, then one per frame in the last loop (rising).
	for i: int in loops * _shake_frames:
		var step: int = 2 if i < _shake_frames * (loops - 1) else 1
		if i % step == 0 and _crossed(i / SHAKE_FPS):
			_play(&"box_rattle")
			GameSettings.vibrate(10 + 10 * (i / _shake_frames) + (10 if rarity == 2 else 0))
	if _crossed(burst_time()):
		_play(&"box_burst")
		GameSettings.vibrate(70 if rarity < 2 else 140)
	if _crossed(card_time()):
		_play(&"box_chime_soft" if is_dupe() else (&"box_chime_epic" if rarity == 2 else &"box_chime"))
		if rarity == 2 and not is_dupe():
			GameSettings.vibrate(90)


func _play(id: StringName) -> void:
	if _sfx != null:
		_sfx.play(id)


## Screen-shake-lite offset for the box and card: grows through the rattle, a kick on the burst that dies away.
func shake_offset() -> Vector2:
	var amp: float = 0.0
	if _t < burst_time():
		amp = lerpf(0.15, 1.0, clampf(_t / maxf(shake_time(), 0.01), 0.0, 1.0)) * SHAKE_PX[rarity]
	elif _t < burst_time() + KICK_TIME:
		amp = BURST_KICK * (1.0 + float(rarity) * 0.5) * (1.0 - (_t - burst_time()) / KICK_TIME)
	if amp <= 0.0:
		return Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_t * 60.0) + 11
	return Vector2(rng.randf_range(-amp, amp), rng.randf_range(-amp, amp) * 0.6)


# --- drawing ----------------------------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(VEIL, VEIL.a * clampf(_t / 0.2 + 0.001, 0.0, 1.0)))
	var s: int = art_scale()
	var centre: Vector2 = Vector2(size.x * 0.5, floor_y()) + shake_offset()
	if _t >= burst_time():
		_draw_rays(centre, s)
	if _t < shake_time():
		var f: int = int(_t * SHAKE_FPS) % _shake_frames
		# 64 cell, floor shadow on the open cell's floor line.
		var origin: Vector2 = centre - Vector2(SHAKE_CELL * 0.5, SHAKE_FLOOR_Y) * s
		draw_texture_rect_region(_shake, Rect2(origin.round(), Vector2.ONE * SHAKE_CELL * s),
			Rect2(f * SHAKE_CELL, 0, SHAKE_CELL, SHAKE_CELL))
	else:
		var f: int = mini(int((_t - shake_time()) * OPEN_FPS), _open_frames - 1)
		var origin: Vector2 = centre - Vector2(OPEN_CELL * 0.5, OPEN_FLOOR_Y) * s
		draw_texture_rect_region(_open, Rect2(origin.round(), Vector2.ONE * OPEN_CELL * s),
			Rect2(f * OPEN_CELL, 0, OPEN_CELL, OPEN_CELL))


func _draw_rays(centre: Vector2, s: int) -> void:
	var a: float = clampf((_t - burst_time()) / RAYS_FADE[rarity], 0.0, 1.0)
	var f: int = int(_t * RAYS_FPS) % _rays_frames
	var mid: Vector2 = centre - Vector2(0.0, BOX_TOP_ABOVE_FLOOR * s)  # on the beam, just above the box
	var half: float = RAYS_CELL * s * 0.5  # same pixel size as the box strips
	draw_texture_rect_region(_rays, Rect2((mid - Vector2.ONE * half).round(), Vector2.ONE * half * 2.0),
		Rect2(f * RAYS_CELL, 0, RAYS_CELL, RAYS_CELL), Color(1, 1, 1, a * 0.9))


func _place() -> void:
	if _card == null:
		return
	var s: int = art_scale()
	_stage.position = shake_offset()
	var h: float = _card_height()
	_card.size = Vector2(CARD_W, h)
	_card.pivot_offset = Vector2(CARD_W * 0.5, h)
	var top_final: float = floor_y() - BOX_TOP_ABOVE_FLOOR * s - 14.0 - h
	var k: float = clampf((_t - card_time()) / CARD_RISE, 0.0, 1.0)
	var e: float = _ease_back(k)
	var from_y: float = floor_y() - BOX_TOP_ABOVE_FLOOR * s * 0.5 - h
	_card.position = Vector2((size.x - CARD_W) * 0.5, lerpf(from_y, top_final, e))
	_card.scale = Vector2.ONE * lerpf(0.4, 1.0, e)
	_card.modulate.a = clampf(k * 3.0, 0.0, 1.0)
	_card.visible = _t >= card_time()
	if _balance != null:
		_balance.visible = _card.visible
		if _crossed(settled_time()):
			_balance.set_gold(PlayerProfile.gold, true)
	# Flash on the burst; epic flashes again as the card comes out.
	var fa: float = 0.0
	var ft: float = FLASH_TIME[rarity]
	if _t >= burst_time() and _t < burst_time() + ft:
		fa = 1.0 - (_t - burst_time()) / ft
	if rarity == 2 and _t >= card_time() and _t < card_time() + 0.3:
		fa = maxf(fa, 0.55 * (1.0 - (_t - card_time()) / 0.3))
	_flash.color.a = fa * fa * 0.85
	var bk: float = clampf((_t - settled_time()) / BUTTON_FADE, 0.0, 1.0)
	_buttons.modulate.a = bk
	_buttons.visible = bk > 0.0


static func _ease_back(k: float) -> float:
	var c1: float = 1.4
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)


# --- card -------------------------------------------------------------------------------------------------------

func _card_height() -> float:
	return _card.get_combined_minimum_size().y if _card != null else 300.0


func _build_card() -> void:
	var color: Color = Unlocks.RARITY_COLORS[rarity]
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(CARD_W, 0.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.set_border_width_all(4)
	sb.border_color = color
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	sb.shadow_color = Color(color, 0.35)
	sb.shadow_size = 14
	_card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	var tex: Texture2D = info["icon"]
	var icon := TextureRect.new()
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = tex.get_size() * (4 if info["weapon"] else 6) if tex != null else Vector2(96, 96)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	_line(col, info["name"], UiStyle.SIZE_HEADING, UiStyle.C_WHITE, false, true)
	_line(col, "%s · %s" % [info["kind"], Unlocks.RARITY_NAMES[rarity]], UiStyle.SIZE_SMALL, color, true, true)
	if is_dupe():
		_line(col, "DUPLICATE", UiStyle.SIZE_SMALL, UiStyle.C_DIM, true, true)
		var refund := GoldChip.new(UiStyle.SIZE_BODY)
		refund.label.text = "+%d gold" % int(info["refund"])
		refund.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(refund)
	var desc: Label = _line(col, info["desc"], UiStyle.SIZE_SMALL, UiStyle.C_DIM, true)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = CARD_W - 48.0
	_stage.add_child(_card)
	_card.visible = false


func _line(parent: Control, text: String, font_size: int, color: Color, body: bool, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_font_override("font", UiStyle.bold() if (bold and not body) else UiStyle.body_font(bold))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Duplicates only: the wallet top right, showing the balance before the refund and counting up once the card settles.
func _build_balance() -> void:
	if not is_dupe():
		return
	_balance = GoldChip.new(UiStyle.SIZE_HEADING)
	_balance.set_gold(PlayerProfile.gold - int(info["refund"]))
	_balance.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	var inset: Vector4 = UiStyle.safe_insets(get_viewport())
	_balance.offset_left -= inset.z + 16.0
	_balance.offset_right -= inset.z + 16.0
	_balance.offset_top += inset.y + 12.0
	_balance.offset_bottom += inset.y + 12.0
	_balance.visible = false
	add_child(_balance)


func _build_buttons() -> void:
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 16)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	var inset: Vector4 = UiStyle.safe_insets(get_viewport())
	_buttons.offset_top = -(UiStyle.TOUCH_MIN_H + inset.w + 12.0)
	_buttons.offset_bottom = -(inset.w + 12.0)
	_buttons.visible = false
	var nice := Button.new()
	nice.text = "Nice!"
	nice.theme_type_variation = &"PrimaryButton"
	nice.custom_minimum_size = Vector2(BUTTON_W, UiStyle.TOUCH_MIN_H)
	nice.focus_mode = Control.FOCUS_NONE
	nice.pressed.connect(_finish.bind(false))
	_buttons.add_child(nice)
	if can_again:
		var again := Button.new()
		again.text = "Open another · %d" % Unlocks.BOX_PRICE
		again.custom_minimum_size = Vector2(BUTTON_W + 40.0, UiStyle.TOUCH_MIN_H)
		again.focus_mode = Control.FOCUS_NONE
		again.pressed.connect(_finish.bind(true))
		_buttons.add_child(again)
	add_child(_buttons)


# --- input ------------------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b != null and b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
		tap()
		accept_event()


## A tap: skip to the burst, then to the finished card, then dismiss.
func tap() -> void:
	if _t < burst_time():
		jump_to(burst_time())
	elif _t < settled_time():
		jump_to(settled_time())
	else:
		_finish(false)


func _finish(again: bool) -> void:
	if _done:
		return
	_done = true
	closed.emit(again)
	queue_free()
