extends SceneTree
## Teams 3v3 check: one offline match where every fighter (the "human" seat included) is driven by a BotBrain.
## Prints each round's result and the final winner; exits 1 if no winner is declared in time.
##   godot --path . --headless --fixed-fps 60 -s tools/teams_sim.gd -- [round=90] [seed=1] [max=1800]
## Screenshot (needs a window; focus-safe like the smoke test, see CLAUDE.md Commands): add `shot=<png path>`
## and the match is rendered with a camera over the whole arena; the png is written mid round 1 and it quits.

var shot_frames: int = 330  ## physics frames after the countdown ends (the bots are mid fight by then)
var _carrier: Player
var carry: bool = false  ## screenshot: an enemy bot is made to carry our flag across the middle

var arena: Arena
var frames: int = 0
var round_secs: float = 90.0
var base_seed: int = 1
var max_secs: float = 1800.0
var shot_path: String = ""
var _play_frames: int = 0
var _by_reason: Dictionary = {}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"round": round_secs = float(kv[1])
				"seed": base_seed = int(kv[1])
				"max": max_secs = float(kv[1])
				"shot": shot_path = kv[1]
				"at": shot_frames = int(kv[1])
				"carry": carry = kv[1] == "1"
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE, base_seed, MatchRules.Mode.TEAMS, round_secs)
	arena.match_state.arena_index = 0
	root.add_child(arena)
	physics_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 2:
		var brain := BotBrain.new(arena, base_seed)
		var me: Player = arena.add_player(1, 0, brain)
		if shot_path != "":
			var input := LocalInput.new()
			input.autopilot = true
			me.controller = input
			arena.attach_local_view(me, input)
			arena.camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
		arena.referee.set_ready(1, true)
		arena.referee.round_ended.connect(_on_round_ended)
	if arena.match_state.phase == MatchState.Phase.PLAYING:
		_play_frames += 1
		if shot_path != "" and carry and _play_frames == 20:
			for p: Player in arena.players:
				if p.team == MatchRules.TEAM_B and not p.is_local and not p.dead:
					_carrier = p
					arena.referee.flag_pickup(p.player_id, MatchRules.TEAM_A)
					p.global_position = arena.map.size * 0.5 + Vector2(-330.0, 30.0)
					break
			for p: Player in arena.players:  # everyone else holds still far away, so the carrier is alone in the open
				if p != _carrier and not p.is_local:
					p.frozen = true
					p.global_position = arena.flag_base(p.team) + Vector2(0.0, 380.0 if p.player_id % 2 == 0 else -380.0)
				elif p.is_local:
					p.frozen = true
					p.global_position = arena.flag_base(p.team) + Vector2(0.0, 300.0)
		if shot_path != "" and _play_frames == shot_frames:
			_shoot()
			return
	if arena.match_state.phase == MatchState.Phase.RESULTS:
		_report()
		return
	if frames > max_secs * 60.0:
		print("[teams_sim] FAIL: no winner after %d s (round %d, score %s)" % [max_secs, arena.match_state.round_number,
			arena.match_state.round_scores])
		quit(1)


func _on_round_ended(winner: int, reason: int) -> void:
	var st: MatchState = arena.match_state
	var why: String = MatchRules.Reason.keys()[reason].to_lower()
	_by_reason[why] = _by_reason.get(why, 0) + 1
	print("[teams_sim] round %d -> %s by %s  (score %d-%d, %.0f s left on the clock)" % [st.round_number,
		MatchRules.TEAM_NAMES[winner] if winner != 0 else "no point", why, st.round_scores[MatchRules.TEAM_A],
		st.round_scores[MatchRules.TEAM_B], st.time_left])


func _report() -> void:
	var st: MatchState = arena.match_state
	print("[teams_sim] MATCH OVER: %s wins %d-%d after %d rounds" % [MatchRules.TEAM_NAMES[st.round_winner],
		st.round_scores[MatchRules.TEAM_A], st.round_scores[MatchRules.TEAM_B], st.round_number])
	print("[teams_sim] rounds by reason: ", _by_reason)
	quit(0 if st.round_winner != 0 else 1)


## Whole-arena view (the local camera follows one player); saves the viewport.
func _shoot() -> void:
	var view: Vector2 = root.get_visible_rect().size
	arena.camera.position_smoothing_enabled = false
	if _carrier != null:  # close up on the carrier
		arena.camera.zoom = Vector2.ONE * arena._zoom() * 1.3
		arena.camera.global_position = _carrier.global_position
	else:
		arena.camera.zoom = Vector2.ONE * minf(view.x / arena.map.size.x, view.y / arena.map.size.y)
		arena.camera.global_position = arena.map.size * 0.5
	arena.camera.set_process(false)
	arena.set_physics_process(false)
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	print("[teams_sim] screenshot ", shot_path, " ", img.save_png(shot_path))
	quit(0)
