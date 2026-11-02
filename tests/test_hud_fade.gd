extends GutTest
## HUD blocks fade when a fighter stands under them.

func test_clear_block_is_opaque() -> void:
	var block := Rect2(0, 0, 200, 150)
	assert_eq(Hud.fade_target(block, [] as Array[Rect2]), 1.0)
	assert_eq(Hud.fade_target(block, [Rect2(300, 300, 50, 50)] as Array[Rect2]), 1.0)


func test_overlap_fades() -> void:
	var block := Rect2(0, 0, 200, 150)
	var fighters: Array[Rect2] = [Rect2(300, 300, 50, 50), Rect2(190, 140, 40, 40)]
	assert_eq(Hud.fade_target(block, fighters), Hud.FADED_ALPHA)


func test_touching_edge_is_not_overlap() -> void:
	assert_eq(Hud.fade_target(Rect2(0, 0, 100, 100), [Rect2(100, 0, 50, 50)] as Array[Rect2]), 1.0)
