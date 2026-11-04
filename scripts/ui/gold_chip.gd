class_name GoldChip
extends HBoxContainer
## A small pixel coin and the gold balance beside it (main menu, shop). `set_gold(n, true)` counts up / down to `n`.

const COIN_SIZE: float = 26.0
const COUNT_TIME: float = 0.6
const COIN_RIM: Color = Color8(176, 112, 40)

var label: Label
var shown: int = 0
var _tween: Tween


func _init(font_size: int = UiStyle.SIZE_BODY) -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := Control.new()
	coin.custom_minimum_size = Vector2(COIN_SIZE, COIN_SIZE)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.draw.connect(_draw_coin.bind(coin))
	add_child(coin)
	label = Label.new()
	label.add_theme_font_override("font", UiStyle.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiStyle.C_YELLOW)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_show(PlayerProfile.gold)


## Pixel coin: dark outline, gold face, rim, a glint and a slot.
func _draw_coin(c: Control) -> void:
	var px: float = COIN_SIZE / 13.0
	var mid: Vector2 = Vector2(COIN_SIZE, COIN_SIZE) * 0.5
	c.draw_circle(mid, COIN_SIZE * 0.5, UiStyle.C_OUTLINE)
	c.draw_circle(mid, COIN_SIZE * 0.5 - px, COIN_RIM)
	c.draw_circle(mid + Vector2(-px * 0.4, -px * 0.4), COIN_SIZE * 0.5 - px * 2.0, UiStyle.C_YELLOW)
	c.draw_rect(Rect2(mid.x - px, mid.y - px * 3.0, px * 2.0, px * 6.0), COIN_RIM)
	c.draw_rect(Rect2(mid.x - px * 4.0, mid.y - px * 4.0, px * 2.0, px), UiStyle.C_WHITE)


func _show(n: int) -> void:
	shown = n
	label.text = str(n)


## Sets the number; animated it ticks there over COUNT_TIME.
func set_gold(n: int, animate: bool = false) -> void:
	if _tween != null:
		_tween.kill()
	if not animate or n == shown or not is_inside_tree():
		_show(n)
		return
	var from: int = shown
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void: _show(roundi(lerpf(from, n, t))), 0.0, 1.0, COUNT_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.finished.connect(_show.bind(n))
