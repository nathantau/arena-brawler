extends GutTest


func test_drag_threshold() -> void:
	assert_false(HScroller.exceeds_threshold(HScroller.DRAG_THRESHOLD - 1.0))
	assert_true(HScroller.exceeds_threshold(HScroller.DRAG_THRESHOLD + 1.0))
	assert_true(HScroller.exceeds_threshold(-HScroller.DRAG_THRESHOLD - 1.0))


func test_offset_to_show() -> void:
	assert_eq(HScroller.offset_to_show(0.0, 500.0, 100.0, 250.0), 0.0)  # already visible
	assert_eq(HScroller.offset_to_show(0.0, 500.0, 450.0, 650.0, 20.0), 170.0)  # off the right edge
	assert_eq(HScroller.offset_to_show(300.0, 500.0, 100.0, 250.0, 20.0), 80.0)  # off the left edge
	assert_eq(HScroller.offset_to_show(300.0, 500.0, 5.0, 100.0, 20.0), 0.0)  # never negative


func test_fit_size_shrinks_to_width() -> void:
	var text: String = "HP 120 · Armor 50 and then some"
	var full: float = UiStyle.text_width(text, UiStyle.SIZE_BODY)
	assert_eq(UiStyle.fit_size(text, full + 1.0, UiStyle.SIZE_BODY), UiStyle.SIZE_BODY)
	var s: int = UiStyle.fit_size(text, full * 0.7, UiStyle.SIZE_BODY, 8)
	assert_lt(s, UiStyle.SIZE_BODY)
	assert_lte(UiStyle.text_width(text, s), full * 0.7)
	assert_eq(UiStyle.fit_size(text, 1.0, UiStyle.SIZE_BODY, 12), 12)  # never below the floor
