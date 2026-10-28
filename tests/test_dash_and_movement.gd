extends GutTest


func test_dash_grants_iframes_and_cooldown() -> void:
	var stats := PlayerStats.new()
	var dash := DashSkill.new()
	assert_true(dash.try_activate(Vector2(0, 2), stats))
	assert_true(dash.is_active())
	assert_eq(dash.direction, Vector2(0, 1))
	assert_true(stats.is_invulnerable())
	assert_almost_eq(stats.invulnerable_time, Constants.DASH_IFRAME_TIME, 0.0001)


func test_dash_blocked_during_cooldown() -> void:
	var stats := PlayerStats.new()
	var dash := DashSkill.new()
	dash.try_activate(Vector2.RIGHT, stats)
	dash.tick(Constants.DASH_DURATION + 0.01)
	assert_false(dash.is_active())
	assert_false(dash.try_activate(Vector2.RIGHT, stats))
	dash.tick(Constants.DASH_COOLDOWN)
	assert_true(dash.try_activate(Vector2.RIGHT, stats))


func test_dash_needs_direction() -> void:
	var dash := DashSkill.new()
	assert_false(dash.try_activate(Vector2.ZERO, PlayerStats.new()))


func test_dash_velocity_overrides_input() -> void:
	var dash := DashSkill.new()
	dash.try_activate(Vector2.LEFT, PlayerStats.new())
	var v: Vector2 = MovementSim.step_velocity(Vector2.ZERO, Vector2.RIGHT, dash, 1.0 / 60.0)
	assert_eq(v, Vector2.LEFT * Constants.DASH_SPEED)


func test_movement_accelerates_to_max_speed() -> void:
	var dash := DashSkill.new()
	var v := Vector2.ZERO
	for i: int in 120:
		v = MovementSim.step_velocity(v, Vector2.RIGHT, dash, 1.0 / 60.0)
	assert_almost_eq(v.length(), Constants.PLAYER_MOVE_SPEED, 0.001)


func test_move_input_is_clamped_to_unit_length() -> void:
	var dash := DashSkill.new()
	var v := Vector2.ZERO
	for i: int in 120:
		v = MovementSim.step_velocity(v, Vector2(5, 5), dash, 1.0 / 60.0)
	assert_almost_eq(v.length(), Constants.PLAYER_MOVE_SPEED, 0.001)


func test_movement_stops_without_input() -> void:
	var dash := DashSkill.new()
	var v := Vector2(Constants.PLAYER_MOVE_SPEED, 0)
	for i: int in 60:
		v = MovementSim.step_velocity(v, Vector2.ZERO, dash, 1.0 / 60.0)
	assert_eq(v, Vector2.ZERO)


func test_deadzone_ignored() -> void:
	var dash := DashSkill.new()
	var v: Vector2 = MovementSim.step_velocity(Vector2.ZERO, Vector2(Constants.INPUT_DEADZONE * 0.5, 0), dash, 1.0 / 60.0)
	assert_eq(v, Vector2.ZERO)
