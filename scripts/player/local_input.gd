class_name LocalInput
extends PlayerController
## Builds InputFrames from touch controls or keyboard/mouse, and computes auto-aim
## client-side (the resulting aim_vec is what gets sent to the server).

var touch: TouchControls
var arena: Arena
var auto_target: Player
## Where auto-aim points: the target, or one of its shadow clones if that's nearer.
var auto_aim_point: Vector2 = Vector2.ZERO
## Dev/test: drive in circles and fire continuously (--autopilot).
var autopilot: bool = false

var _frame := InputFrame.new()
var _query := PhysicsRayQueryParameters2D.new()
var _candidates: Array[Player] = []
var _positions := PackedVector2Array()
var _is_clone: Array[bool] = []
var _space: PhysicsDirectSpaceState2D
var _origin: Vector2 = Vector2.ZERO
var _is_visible_cb: Callable = _is_visible


func get_input(player: Player, _delta: float) -> InputFrame:
	_frame.seq += 1
	var touch_on: bool = touch != null and touch.visible

	var move: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if touch_on and touch.move_vec != Vector2.ZERO:
		move = touch.move_vec
	_frame.move_vec = move

	var fire_mouse: bool = not touch_on and Input.is_action_pressed(&"fire_mouse")
	var fire_auto: bool = Input.is_action_pressed(&"fire_auto") or (touch_on and touch.attack_held)
	_frame.fire = fire_mouse or fire_auto
	_frame.skill = Input.is_action_pressed(&"skill") or (touch_on and touch.skill_held)
	_frame.special = Input.is_action_pressed(&"special") or (touch_on and touch.special_held)
	_frame.swap = Input.is_action_pressed(&"swap") or (touch_on and touch.swap_held)
	_update_auto_target(player)
	if autopilot:
		_drive_autopilot(player)
	var aim := Vector2.ZERO
	if fire_mouse:
		aim = player.get_global_mouse_position() - player.global_position
	elif touch_on and touch.attack_aim != Vector2.ZERO:
		aim = touch.attack_aim
	elif auto_target != null:
		aim = auto_aim_point - player.global_position
	_frame.aim_vec = aim.normalized() if aim != Vector2.ZERO else Vector2.ZERO

	return _frame


## Enemies hidden in their smoke are skipped; shadow clones count as targets (that's the trick).
func _update_auto_target(player: Player) -> void:
	_candidates.clear()
	_positions.clear()
	_is_clone.clear()
	for p: Player in arena.players:
		if p == player or p.dead:
			continue
		if not p.is_hidden():
			_candidates.append(p)
			_positions.append(p.global_position)
			_is_clone.append(false)
		for c: Vector2 in p.clone_points():
			_candidates.append(p)
			_positions.append(c)
			_is_clone.append(true)
	_space = player.get_world_2d().direct_space_state
	_origin = player.global_position
	var idx: int = AutoAim.pick_nearest(_origin, _positions, Constants.AUTO_AIM_RANGE, _is_visible_cb)
	var new_target: Player = _candidates[idx] if idx >= 0 else null
	if auto_target != null:
		auto_target.targeted = false
	auto_target = new_target
	if auto_target != null:
		auto_aim_point = _positions[idx]
		# The red ring would give away which one is real.
		auto_target.targeted = not _is_clone[idx]


func _is_visible(i: int) -> bool:
	return AutoAim.has_line_of_sight(_space, _query, _origin, _positions[i])


## Circle-strafe and fire when a target is visible, otherwise walk toward the nearest enemy.
func _drive_autopilot(player: Player) -> void:
	_frame.fire = auto_target != null
	_frame.skill = auto_target != null and _frame.seq % Constants.AUTOPILOT_SKILL_EVERY_FRAMES == 0
	_frame.special = auto_target != null and _frame.seq % Constants.AUTOPILOT_SPECIAL_EVERY_FRAMES == 0
	if auto_target != null:
		_frame.move_vec = Vector2.RIGHT.rotated(_frame.seq * Constants.AUTOPILOT_TURN_PER_FRAME)
		return
	var nearest: Vector2 = Vector2.ZERO
	var best: float = INF
	for p: Vector2 in _positions:
		var d: float = player.global_position.distance_squared_to(p)
		if d < best:
			best = d
			nearest = p
	if best == INF:
		_frame.move_vec = Vector2.ZERO
		return
	# Greedy obstacle steering: the open direction most aligned with the enemy.
	var desired: Vector2 = (nearest - player.global_position).normalized()
	var origin: Vector2 = player.global_position
	var best_dir: Vector2 = desired
	var best_score: float = -INF
	for i: int in Constants.AUTOPILOT_STEER_DIRECTIONS:
		var d: Vector2 = Vector2.RIGHT.rotated(TAU * i / Constants.AUTOPILOT_STEER_DIRECTIONS)
		if not AutoAim.has_line_of_sight(_space, _query, origin, origin + d * Constants.AUTOPILOT_PROBE_DISTANCE):
			continue
		var score: float = d.dot(desired)
		if score > best_score:
			best_score = score
			best_dir = d
	_frame.move_vec = best_dir
