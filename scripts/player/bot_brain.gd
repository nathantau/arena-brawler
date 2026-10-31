class_name BotBrain
extends PlayerController
## Dummy AI: wanders, and when it sees an enemy it strafes at a preferred distance and
## fires with some aim error. Uses its own seeded RNG.

var arena: Arena
var rng := RandomNumberGenerator.new()

var _frame := InputFrame.new()
var _query := PhysicsRayQueryParameters2D.new()
var _decision_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _strafe_sign: float = 1.0
## Re-rolled with each decision, not every frame: a fresh error each frame flipped bots left/right when aiming up/down.
var _aim_error: float = 0.0
var _last_aim: Vector2 = Vector2.ZERO
var _since_target: float = INF


func _init(p_arena: Arena, bot_seed: int) -> void:
	arena = p_arena
	rng.seed = bot_seed


func get_input(player: Player, delta: float) -> InputFrame:
	_frame.seq += 1
	_decision_timer -= delta
	# Only a wall we're walking into forces a new direction; re-rolling on every touch made bots jitter in place.
	var wall := Vector2.ZERO  # summed, so a corner counts as one wall
	for i: int in player.get_slide_collision_count():
		wall += player.get_slide_collision(i).get_normal()
	if _decision_timer <= 0.0 or _wander_dir.dot(wall) < 0.0:
		_decision_timer = rng.randf_range(Constants.BOT_DECISION_MIN, Constants.BOT_DECISION_MAX)
		_wander_dir = Vector2.RIGHT.rotated(rng.randf() * TAU)
		if _wander_dir.dot(wall) < 0.0:
			_wander_dir = _wander_dir.bounce(wall.normalized())
		_strafe_sign = 1.0 if rng.randf() < 0.5 else -1.0
		_aim_error = deg_to_rad(rng.randf_range(-Constants.BOT_AIM_ERROR_DEG, Constants.BOT_AIM_ERROR_DEG))

	_frame.move_vec = _wander_dir * Constants.BOT_MOVE_SCALE
	_frame.aim_vec = Vector2.ZERO
	_frame.fire = false
	_frame.skill = false
	_frame.special = false

	var target: Variant = _nearest_visible_enemy(player)
	_since_target = 0.0 if target != null else _since_target + delta
	if target == null and _since_target < Constants.BOT_TARGET_MEMORY:
		_frame.aim_vec = _last_aim
	if target != null:
		var to: Vector2 = (target as Vector2) - player.global_position
		var dist: float = to.length()
		var dir: Vector2 = to / dist
		var radial: Vector2 = dir if dist > Constants.BOT_PREFERRED_DISTANCE else -dir
		var strafe: Vector2 = dir.orthogonal() * _strafe_sign
		var move: Vector2 = radial * Constants.BOT_RADIAL_WEIGHT + strafe * Constants.BOT_STRAFE_WEIGHT
		_frame.move_vec = move.normalized() * Constants.BOT_MOVE_SCALE
		_frame.aim_vec = player.aim_at(target as Vector2).rotated(_aim_error)
		_last_aim = _frame.aim_vec
		_frame.fire = true
		# Skills are edge-triggered: a one-frame press now and then.
		_frame.skill = rng.randf() < Constants.BOT_SKILL_CHANCE_PER_SEC * delta
		_frame.special = rng.randf() < Constants.BOT_SPECIAL_CHANCE_PER_SEC * delta
	return _frame


## Where to shoot: the nearest visible non-bot enemy, or one of its shadow clones (bots fall for
## them). Enemies hidden in their smoke are ignored. Null if nothing is in sight.
func _nearest_visible_enemy(player: Player) -> Variant:
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var best: Variant = null
	var best_dist_sq: float = Constants.BOT_SIGHT_RANGE * Constants.BOT_SIGHT_RANGE
	for p: Player in arena.players:
		if p == player or p.dead or p.controller is BotBrain:
			continue
		var spots: PackedVector2Array = p.clone_points()
		if not p.is_hidden():
			spots.append(p.global_position)
		for at: Vector2 in spots:
			var d: float = player.global_position.distance_squared_to(at)
			if d <= 0.0 or d >= best_dist_sq:
				continue
			var spot: Variant = AutoAim.visible_point(space, _query, player.global_position, at)
			if spot != null:
				best = spot
				best_dist_sq = d
	return best
