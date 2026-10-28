class_name BotBrain
extends PlayerController
## M1 dummy AI: wanders, and when it sees the local player it strafes at a preferred
## distance and fires with some aim error. Uses its own seeded RNG.

var arena: Arena
var rng := RandomNumberGenerator.new()

var _frame := InputFrame.new()
var _query := PhysicsRayQueryParameters2D.new()
var _decision_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _strafe_sign: float = 1.0


func _init(p_arena: Arena, bot_seed: int) -> void:
	arena = p_arena
	rng.seed = bot_seed


func get_input(player: Player, delta: float) -> InputFrame:
	_frame.seq += 1
	_decision_timer -= delta
	if _decision_timer <= 0.0 or player.get_slide_collision_count() > 0:
		_decision_timer = rng.randf_range(Constants.BOT_DECISION_MIN, Constants.BOT_DECISION_MAX)
		_wander_dir = Vector2.RIGHT.rotated(rng.randf() * TAU)
		_strafe_sign = 1.0 if rng.randf() < 0.5 else -1.0

	_frame.move_vec = _wander_dir * Constants.BOT_MOVE_SCALE
	_frame.aim_vec = Vector2.ZERO
	_frame.fire = false

	var target: Player = arena.local_player
	if target != null and not target.dead:
		var to: Vector2 = target.global_position - player.global_position
		var dist: float = to.length()
		var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
		if dist > 0.0 and dist < Constants.BOT_SIGHT_RANGE \
				and AutoAim.has_line_of_sight(space, _query, player.global_position, target.global_position):
			var dir: Vector2 = to / dist
			var radial: Vector2 = dir if dist > Constants.BOT_PREFERRED_DISTANCE else -dir
			var strafe: Vector2 = dir.orthogonal() * _strafe_sign
			var move: Vector2 = radial * Constants.BOT_RADIAL_WEIGHT + strafe * Constants.BOT_STRAFE_WEIGHT
			_frame.move_vec = move.normalized() * Constants.BOT_MOVE_SCALE
			var err: float = deg_to_rad(Constants.BOT_AIM_ERROR_DEG)
			_frame.aim_vec = dir.rotated(rng.randf_range(-err, err))
			_frame.fire = true
	return _frame
