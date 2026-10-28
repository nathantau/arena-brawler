class_name MovementSim
extends RefCounted
## Pure velocity integration. Collision is resolved by CharacterBody2D.move_and_slide().


static func step_velocity(velocity: Vector2, move_vec: Vector2, dash: DashSkill, delta: float) -> Vector2:
	if dash.is_active():
		return dash.direction * Constants.DASH_SPEED
	var input: Vector2 = move_vec.limit_length(1.0)
	if input.length() < Constants.INPUT_DEADZONE:
		input = Vector2.ZERO
	var target: Vector2 = input * Constants.PLAYER_MOVE_SPEED
	var rate: float = Constants.PLAYER_ACCEL if input != Vector2.ZERO else Constants.PLAYER_DECEL
	if velocity.length() > Constants.PLAYER_MOVE_SPEED:
		rate = Constants.PLAYER_OVERSPEED_DECEL
	return velocity.move_toward(target, rate * delta)
