class_name MovementSim
extends RefCounted
## Pure velocity integration. Collision is resolved by CharacterBody2D.move_and_slide().


static func step_velocity(velocity: Vector2, move_vec: Vector2, skill: CharacterSkill, max_speed: float,
		delta: float) -> Vector2:
	if skill.is_dashing():
		return skill.direction * skill.data.dash_speed
	# Direction only: any push past the deadzone is full speed (no half-speed from a short joystick drag).
	var input: Vector2 = move_vec.normalized() if move_vec.length() >= Constants.INPUT_DEADZONE else Vector2.ZERO
	var target: Vector2 = input * max_speed
	var rate: float = Constants.PLAYER_ACCEL if input != Vector2.ZERO else Constants.PLAYER_DECEL
	if velocity.length() > max_speed:
		rate = Constants.PLAYER_OVERSPEED_DECEL
	return velocity.move_toward(target, rate * delta)
