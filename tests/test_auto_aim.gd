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


func test_sees_a_player_standing_just_below_a_wall() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var wall := StaticBody2D.new()
	wall.collision_layer = Constants.LAYER_WALLS
	var cs := CollisionShape2D.new()
	cs.shape = RectangleShape2D.new()
	(cs.shape as RectangleShape2D).size = Vector2(200, 48)
	wall.add_child(cs)
	world.add_child(wall)  # spans y -24..24
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState2D = world.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.new()
	var target := Vector2(0, 20)  # pressed up under it: centre inside the wall, as feet-based collision allows
	var shooter := Vector2(-200, 120)
	assert_false(AutoAim.has_line_of_sight(space, query, shooter, target), "centre-to-centre calls it hidden")
	var spot: Variant = AutoAim.visible_point(space, query, shooter, target)
	assert_not_null(spot, "but its lower half is in plain sight")
	var far := Vector2(0, -120)  # really behind the wall
	assert_null(AutoAim.visible_point(space, query, shooter, far))
