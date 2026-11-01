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


func test_ui_scale_only_for_phone_sized_screens() -> void:
	assert_eq(UiStyle.scale_for(1440.0, 2.0), 1.0)  # a desktop window: plain 720-unit canvas
	assert_eq(UiStyle.scale_for(1640.0, 2.0), 1.0)  # iPad
	var phone: float = UiStyle.scale_for(1170.0, 3.0)  # iPhone 14 landscape
	assert_gt(phone, 1.0)
	assert_lte(phone, UiStyle.MAX_UI_SCALE)
	assert_gt(UiStyle.scale_for(750.0, 2.0), 1.0)  # iPhone SE
	# Phone canvas stays tall enough for the loading room: 720 / scale units.
	assert_gt(720.0 / phone, 500.0)


func test_safe_area_fit_stops_listening_when_the_control_is_freed() -> void:
	var host := Control.new()
	add_child_autofree(host)
	var before: int = host.get_viewport().size_changed.get_connections().size()
	var c := Control.new()
	host.add_child(c)
	UiStyle.fit_to_safe_area(c)
	assert_eq(host.get_viewport().size_changed.get_connections().size(), before + 1)
	c.free()
	assert_eq(host.get_viewport().size_changed.get_connections().size(), before, "no stale resize handler on a freed screen")
	host.get_viewport().size_changed.emit()  # must not touch the freed control
