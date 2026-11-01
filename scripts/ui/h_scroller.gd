class_name HScroller
extends Control
## A row (or, with `HScroller.new(true)`, a column) you scroll by dragging it, even when the drag starts on a card (Buttons swallow touches, so the
## built-in ScrollContainer never sees them). Tap selects, drag scrolls: after a drag the release does not count as a
## tap (`tap_ok()` / `on_tap()`). Edge fades with an arrow show when more content is off-screen.
## Put the items into `content`; a row is as tall as its content and as wide as its parent gives it, a column the other
## way round (give it SIZE_EXPAND_FILL to take the height left). Nested scrollers of both axes work: a drag is claimed by
## the one whose axis it follows, and any drag stops the release from counting as a tap anywhere.

## Finger travel (canvas units) before a press becomes a drag.
const DRAG_THRESHOLD: float = 12.0
const FADE_W: float = 44.0
const ARROW_SIZE: Vector2 = Vector2(10.0, 16.0)
const FADE_STEPS: int = 6
const EDGE_EPS: float = 2.0

var content: BoxContainer
var vertical: bool = false
var scroll: ScrollContainer
var fade_color: Color = Color(0.07, 0.07, 0.13)

var _hint: Control
var _pressed: bool = false
var _dragged: bool = false
var _travel: Vector2 = Vector2.ZERO

## True while the current press has turned into a drag in any scroller.
static var _any_dragged: bool = false


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


func _init(vertical_: bool = false) -> void:
	vertical = vertical_
	clip_contents = true
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if vertical else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if vertical else ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE  # we do the dragging; no double scrolling
	add_child(scroll)
	content = VBoxContainer.new() if vertical else HBoxContainer.new()
	if vertical:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_hint = Control.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.draw.connect(_draw_hint)
	add_child(_hint)


func _get_minimum_size() -> Vector2:
	if vertical:
		return Vector2(content.get_combined_minimum_size().x, 0.0)
	return Vector2(0.0, content.get_combined_minimum_size().y)


func _process(_delta: float) -> void:
	if _hint.visible:
		_hint.queue_redraw()


func max_scroll() -> float:
	if vertical:
		return maxf(0.0, content.get_combined_minimum_size().y - size.y)
	return maxf(0.0, content.get_combined_minimum_size().x - size.x)


func _offset() -> float:
	return scroll.scroll_vertical if vertical else scroll.scroll_horizontal


func _set_offset(v: float) -> void:
	var o: int = clampi(int(v), 0, int(max_scroll()))
	if vertical:
		scroll.scroll_vertical = o
	else:
		scroll.scroll_horizontal = o


## False if the press that just ended was a drag (call from a card's `pressed` handler).
func tap_ok() -> bool:
	return not _dragged and not _any_dragged


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
	var start: float = item.position.y if vertical else item.position.x
	var len: float = item.size.y if vertical else item.size.x
	var margin: float = 0.0 if vertical else FADE_W
	_set_offset(offset_to_show(_offset(), size.y if vertical else size.x, start, start + len, margin))


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var b := event as InputEventMouseButton
		if b.pressed:
			_pressed = get_global_rect().has_point(b.position)
			_dragged = false
			_any_dragged = false
			_travel = Vector2.ZERO
		else:
			_pressed = false
	elif event is InputEventMouseMotion and _pressed:
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		_travel += rel
		var mine: float = _travel.y if vertical else _travel.x
		var other: float = _travel.x if vertical else _travel.y
		if not _dragged and exceeds_threshold(mine) and absf(mine) >= absf(other):
			_dragged = true
		if _dragged:
			_any_dragged = true
			_set_offset(_offset() - (rel.y if vertical else rel.x))


func _draw_hint() -> void:
	var room: float = max_scroll()
	if room <= EDGE_EPS:
		return
	var at: float = _offset()
	if at > EDGE_EPS:
		_edge(true)
	if at < room - EDGE_EPS:
		_edge(false)


## `first`: the left / top edge.
func _edge(first: bool) -> void:
	var extent: float = size.y if vertical else size.x
	var x0: float = 0.0 if first else extent
	var dir: float = 1.0 if first else -1.0
	var step: float = FADE_W / FADE_STEPS
	for i: int in FADE_STEPS:
		var a: float = 0.95 * (1.0 - float(i) / FADE_STEPS)
		var x: float = x0 + dir * step * i
		var lo: float = minf(x, x + dir * step)
		var r: Rect2 = Rect2(0.0, lo, size.x, step) if vertical else Rect2(lo, 0.0, step, size.y)
		_hint.draw_rect(r, Color(fade_color, a))
	var cx: float = x0 + dir * (ARROW_SIZE.x + 4.0)
	var cy: float = (size.x if vertical else size.y) * 0.5
	var tip := Vector2(cx - dir * ARROW_SIZE.x * 0.5, cy)
	var back_x: float = cx + dir * ARROW_SIZE.x * 0.5
	var pts := PackedVector2Array([tip, Vector2(back_x, cy - ARROW_SIZE.y * 0.5), Vector2(back_x, cy + ARROW_SIZE.y * 0.5)])
	if vertical:
		for k: int in pts.size():
			pts[k] = Vector2(pts[k].y, pts[k].x)
	_hint.draw_colored_polygon(pts, UiStyle.C_YELLOW)
