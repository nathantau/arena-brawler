class_name HScroller
extends Control
## A sideways row you scroll by dragging it, even when the drag starts on a card (Buttons swallow touches, so the
## built-in ScrollContainer never sees them). Tap selects, drag scrolls: after a drag the release does not count as a
## tap (`tap_ok()` / `on_tap()`). Edge fades with an arrow show when more content is off-screen.
## Put the row's items into `content`; the scroller is as tall as the content and as wide as its parent gives it.

## Finger travel (canvas units) before a press becomes a drag.
const DRAG_THRESHOLD: float = 12.0
const FADE_W: float = 44.0
const ARROW_SIZE: Vector2 = Vector2(10.0, 16.0)
const FADE_STEPS: int = 6
const EDGE_EPS: float = 2.0

var content: HBoxContainer
var scroll: ScrollContainer
var fade_color: Color = Color(0.07, 0.07, 0.13)

var _hint: Control
var _pressed: bool = false
var _dragged: bool = false
var _travel: float = 0.0


## True once a finger moved far enough that the gesture is a scroll, not a tap.
static func exceeds_threshold(travel: float) -> bool:
	return absf(travel) > DRAG_THRESHOLD


## Scroll offset that brings [left, right] fully into a viewport of `page` width at offset `current`, `margin` clear of the edge.
static func offset_to_show(current: float, page: float, left: float, right: float, margin: float = 0.0) -> float:
	if left - margin < current:
		return maxf(0.0, left - margin)
	if right + margin > current + page:
		return right + margin - page
	return current


func _init() -> void:
	clip_contents = true
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE  # we do the dragging; no double scrolling
	add_child(scroll)
	content = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_hint = Control.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.draw.connect(_draw_hint)
	add_child(_hint)


func _get_minimum_size() -> Vector2:
	return Vector2(0.0, content.get_combined_minimum_size().y)


func _process(_delta: float) -> void:
	if _hint.visible:
		_hint.queue_redraw()


func max_scroll() -> float:
	return maxf(0.0, content.get_combined_minimum_size().x - size.x)


## False if the press that just ended was a drag (call from a card's `pressed` handler).
func tap_ok() -> bool:
	return not _dragged


## Runs `action` when the card is tapped but not when the tap was the end of a drag.
func on_tap(card: BaseButton, action: Callable) -> void:
	card.pressed.connect(func() -> void:
		if tap_ok():
			action.call())


## Scrolls so `item` (a child of `content`) is fully visible, with a little air around it.
func reveal(item: Control) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(item) or not is_instance_valid(self):
		return
	var left: float = item.position.x
	scroll.scroll_horizontal = int(offset_to_show(scroll.scroll_horizontal, size.x, left, left + item.size.x, FADE_W))


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var b := event as InputEventMouseButton
		if b.pressed:
			_pressed = get_global_rect().has_point(b.position)
			_dragged = false
			_travel = 0.0
		else:
			_pressed = false
	elif event is InputEventMouseMotion and _pressed:
		var dx: float = (event as InputEventMouseMotion).relative.x
		_travel += dx
		if _dragged or exceeds_threshold(_travel):
			_dragged = true
			scroll.scroll_horizontal = clampi(int(scroll.scroll_horizontal - dx), 0, int(max_scroll()))


func _draw_hint() -> void:
	var room: float = max_scroll()
	if room <= EDGE_EPS:
		return
	var at: float = scroll.scroll_horizontal
	if at > EDGE_EPS:
		_edge(true)
	if at < room - EDGE_EPS:
		_edge(false)


func _edge(left: bool) -> void:
	var x0: float = 0.0 if left else size.x
	var dir: float = 1.0 if left else -1.0
	var step: float = FADE_W / FADE_STEPS
	for i: int in FADE_STEPS:
		var a: float = 0.95 * (1.0 - float(i) / FADE_STEPS)
		var x: float = x0 + dir * step * i
		_hint.draw_rect(Rect2(minf(x, x + dir * step), 0.0, step, size.y), Color(fade_color, a))
	var cx: float = x0 + dir * (ARROW_SIZE.x + 4.0)
	var cy: float = size.y * 0.5
	var tip := Vector2(cx - dir * ARROW_SIZE.x * 0.5, cy)
	var back_x: float = cx + dir * ARROW_SIZE.x * 0.5
	_hint.draw_colored_polygon(PackedVector2Array([tip, Vector2(back_x, cy - ARROW_SIZE.y * 0.5),
		Vector2(back_x, cy + ARROW_SIZE.y * 0.5)]), UiStyle.C_YELLOW)
