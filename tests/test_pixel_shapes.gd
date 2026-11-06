extends GutTest

const PX: float = 1.5


func test_disc_symmetric_and_covers_centre() -> void:
	var spans: Array[Rect2] = PixelShapes.disc_spans(Vector2(100.3, 50.2), 20.0, 9.0, PX)
	var c: Vector2 = Vector2(100.3, 50.2).snappedf(PX)
	var covered: bool = false
	for r: Rect2 in spans:
		assert_almost_eq(r.get_center().x, c.x, 0.001)
		if r.has_point(c + Vector2(0.1, 0.1)):
			covered = true
	assert_true(covered)


func test_ring_on_grid_and_hollow() -> void:
	var c: Vector2 = Vector2(30.0, 30.0)
	var spans: Array[Rect2] = PixelShapes.ring_spans(c, 24.0, 24.0, 3.0, PX)
	for r: Rect2 in spans:
		assert_almost_eq(fposmod(r.position.x, PX), 0.0, 0.001)
		assert_almost_eq(fposmod(r.position.y, PX), 0.0, 0.001)
		assert_almost_eq(r.size.y, PX, 0.001)
		assert_false(r.has_point(c + Vector2(0.1, 0.1)))
	assert_gt(spans.size(), 20)
