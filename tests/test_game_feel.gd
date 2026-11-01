extends GutTest
## Game-feel + UI-state fixes: camera clamp, touch release, effect/HUD clearing.


func test_camera_clamps_to_arena_and_centres_when_view_is_bigger() -> void:
	var bounds := Rect2(0, 0, 1000, 600)
	var view := Vector2(400, 300)
	assert_eq(Arena.clamp_camera(Vector2(50, 50), view, bounds), Vector2(200, 150))
	assert_eq(Arena.clamp_camera(Vector2(990, 590), view, bounds), Vector2(800, 450))
	assert_eq(Arena.clamp_camera(Vector2(500, 300), view, bounds), Vector2(500, 300))
	# view wider than the arena on x: centred on x, still clamped on y
	assert_eq(Arena.clamp_camera(Vector2(10, 10), Vector2(1400, 300), bounds), Vector2(500, 150))


func test_touch_release_all_clears_every_held_input() -> void:
	var tc: TouchControls = autofree(TouchControls.new())
	tc.size = Vector2(1000, 500)
	tc._on_press(1, Vector2(100, 300))  # joystick
	tc._on_drag(1, Vector2(160, 300))
	tc._on_press(2, tc._attack_center())
	tc._on_press(3, tc._skill_center())
	assert_true(tc.attack_held)
	assert_true(tc.skill_held)
	assert_ne(tc.move_vec, Vector2.ZERO)
	tc.release_all()
	assert_false(tc.attack_held)
	assert_false(tc.skill_held)
	assert_false(tc.special_held)
	assert_eq(tc.move_vec, Vector2.ZERO)
	# a finger can grab the stick again afterwards
	tc._on_press(4, Vector2(100, 300))
	tc._on_drag(4, Vector2(180, 300))
	assert_gt(tc.move_vec.x, 0.5)


func test_joystick_base_follows_a_drag_past_its_ring() -> void:
	var tc: TouchControls = autofree(TouchControls.new())
	tc.size = Vector2(1000, 500)
	tc._on_press(1, Vector2(100, 300))
	tc._on_drag(1, Vector2(400, 300))
	assert_almost_eq(tc.move_vec.x, 1.0, 0.01)
	tc._on_drag(1, Vector2(400 - TouchControls.JOY_RADIUS, 300))
	assert_lt(tc.move_vec.x, 0.01, "pulling back by one radius is neutral, not still full right")


func test_effects_clear_and_hud_transients() -> void:
	var fx := Effects.new()
	add_child_autofree(fx)
	fx.damage_number(Vector2.ZERO, 10, false)
	fx.hit_marker(Vector2.ZERO, true)
	fx.burst(Vector2.ZERO, Color.WHITE, 5, 100.0, 4.0, 1.0)
	fx.clear()
	for n: Effects.DamageNumber in fx._numbers:
		assert_lte(n.life, 0.0)
	for m: Effects.Marker in fx._markers:
		assert_lte(m.life, 0.0)
	for p: Effects.Particle in fx._particles:
		assert_lte(p.life, 0.0)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.add_kill_feed("A", Color.RED, "B", Color.BLUE, false, false)
	hud.banner("KO", Color.WHITE)
	hud.clear_transients()
	assert_eq(hud._feed.size(), 0)
	assert_eq(hud._banners.size(), 0)


func test_kill_feed_keeps_the_newest_rows() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	for i: int in Hud.FEED_MAX + 3:
		hud.add_kill_feed("k%d" % i, Color.WHITE, "v", Color.WHITE, false, false)
	assert_eq(hud._feed.size(), Hud.FEED_MAX)
	assert_eq(hud._feed[Hud.FEED_MAX - 1].killer, "k%d" % (Hud.FEED_MAX + 2))
