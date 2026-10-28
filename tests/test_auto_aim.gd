extends GutTest


func _all_visible(_i: int) -> bool:
	return true


func test_picks_nearest() -> void:
	var pos := PackedVector2Array([Vector2(300, 0), Vector2(100, 0), Vector2(200, 0)])
	assert_eq(AutoAim.pick_nearest(Vector2.ZERO, pos, 1000.0, _all_visible), 1)


func test_skips_hidden_targets() -> void:
	var pos := PackedVector2Array([Vector2(300, 0), Vector2(100, 0), Vector2(200, 0)])
	var hidden_one := func(i: int) -> bool: return i != 1
	assert_eq(AutoAim.pick_nearest(Vector2.ZERO, pos, 1000.0, hidden_one), 2)


func test_ignores_out_of_range() -> void:
	var pos := PackedVector2Array([Vector2(600, 0)])
	assert_eq(AutoAim.pick_nearest(Vector2.ZERO, pos, 500.0, _all_visible), -1)


func test_no_candidates() -> void:
	assert_eq(AutoAim.pick_nearest(Vector2.ZERO, PackedVector2Array(), 500.0, _all_visible), -1)


func test_visibility_only_checked_for_closer_candidates() -> void:
	var checked: Array[int] = []
	var record := func(i: int) -> bool:
		checked.append(i)
		return true
	var pos := PackedVector2Array([Vector2(100, 0), Vector2(300, 0)])
	AutoAim.pick_nearest(Vector2.ZERO, pos, 1000.0, record)
	assert_eq(checked, [0] as Array[int])
