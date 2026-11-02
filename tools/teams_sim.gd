extends SceneTree
## Teams 3v3 check: one offline match where every fighter (the "human" seat included) is driven by a BotBrain.
## Prints each round's result and the final winner; exits 1 if no winner is declared in time.
##   godot --path . --headless --fixed-fps 60 -s tools/teams_sim.gd -- [round=120] [seed=1] [max=1800]
## Screenshot (needs a window; focus-safe like the smoke test, see CLAUDE.md Commands): add `shot=<png path>`
## and the match is rendered with a camera over the whole arena; the png is written mid round 1 and it quits.

var shot_frames: int = 330  ## physics frames after the countdown ends (the bots are mid fight by then)
var _carrier: Player
var win: bool = false  ## screenshot: the local player captures the flag, shot taken during the round-end banner
var lobby: bool = false
var shared: int = 0  ## screenshot with lobby=1: 1 = P2 + P3 hover one card, 2 = P3 locked and P2 hovers that card  ## screenshot: the loading room (nobody readies up)
var step: int = 0  ## screenshot with lobby=1: which character select step is showing (0 the fighter grid, 1 the detail overlay open)
var toggle: bool = false  ## screenshot with lobby=1 strip=1 fly=1: first remove an equipped ability, then add one
var tab: int = 0  ## screenshot with lobby=1 step>=1: 1 = the Weapon tab
var sheet: bool = false  ## screenshot with lobby=1: a contact sheet of the showcase backdrop of all nine fighters
var pick: StringName = &"eden"  ## screenshot with lobby=1 step=1: the fighter the overlay opens on
var fly: bool = false  ## screenshot with lobby=1 strip=1: capture an ability flying into a slot instead of the slide-in
var strip: bool = false  ## screenshot with lobby=1: instead a strip of 6 frames of the overlay sliding in
var dead: bool = false  ## screenshot: the local player dies at once, so the respawn countdown shows (use at=200)
var carry: bool = false  ## screenshot: an enemy bot is made to carry our flag across the middle

var arena: Arena
var frames: int = 0
var round_secs: float = 120.0
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
				"dead": dead = kv[1] == "1"
				"win": win = kv[1] == "1"
				"lobby": lobby = kv[1] == "1"
				"shared": shared = int(kv[1])
				"step": step = int(kv[1])
				"strip": strip = kv[1] == "1"
				"fly": fly = kv[1] == "1"
				"char": pick = StringName(kv[1])
				"backdrops": sheet = kv[1] == "1"
				"tab": tab = int(kv[1])
				"toggle": toggle = kv[1] == "1"
	InputSetup.ensure_actions()
	if lobby and shot_path != "":
		UiStyle.install()  # Main does this in the real game
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
		if not lobby:
			arena.referee.set_ready(1, true)
		else:  # hero select screenshot: two human teammates, one hovering, one locked in
			arena.referee.set_team(1, MatchRules.TEAM_A)
			for id: int in [2, 3]:
				arena.add_player(id, id, BotBrain.new(arena, id))
				arena.referee.set_team(id, MatchRules.TEAM_A)
			arena.select_character(arena.get_player(2), &"bolt")
			arena.select_character(arena.get_player(3), &"sakura")
			arena.select_character(me, &"eden")
			if shared == 1:  # both teammates eye Bolt
				arena.select_character(arena.get_player(3), &"bolt")
			elif shared == 2:  # P3 locks Sakura while P2 hovers it
				arena.select_character(arena.get_player(2), &"sakura")
			if shared != 1:
				arena.try_ready(3, true)
		arena.referee.round_ended.connect(_on_round_ended)
	if lobby and shot_path != "" and frames == 60:
		_shoot_lobby()
		return
	if lobby and shot_path != "" and frames > 60:
		return
	if arena.match_state.phase == MatchState.Phase.PLAYING:
		_play_frames += 1
		if win and _play_frames == 20:
			var me: Player = arena.get_player(1)
			arena.referee.flag_pickup(1, MatchRules.other_team(me.team))
			arena.referee.flag_capture(1, arena.scores)
		if dead and _play_frames == 20:
			arena.get_player(1).stats.spawn_protect = 0.0
			arena.get_player(1).take_hit(9999, false, Vector2.ZERO, Constants.BOT_ID_BASE)
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
	if dead:
		pass
	elif _carrier != null:  # close up on the carrier
		arena.camera.zoom = Vector2.ONE * arena._zoom() * 1.3
		arena.camera.global_position = _carrier.global_position
	else:
		arena.camera.zoom = Vector2.ONE * minf(view.x / arena.map.size.x, view.y / arena.map.size.y)
		arena.camera.global_position = arena.map.size * 0.5
	if not dead:
		arena.camera.set_process(false)
	arena.set_physics_process(false)
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	print("[teams_sim] screenshot ", shot_path, " ", img.save_png(shot_path))
	quit(0)


func _find_lobby(n: Node) -> LobbyPanel:
	if n is LobbyPanel:
		return n
	for c: Node in n.get_children():
		var l: LobbyPanel = _find_lobby(c)
		if l != null:
			return l
	return null


## Loading room: the fighter grid (step=0), the overlay open on Eden (step=1), or (strip=1) 6 frames of the overlay
## sliding in after tapping Bolt. The window size comes from `--resolution WxH` (before the `--`).
func _shoot_lobby() -> void:
	var lp: LobbyPanel = _find_lobby(root)
	physics_frame.disconnect(_tick)
	for i: int in 8:
		await process_frame
	var ratio: float = float(root.size.x) / root.get_visible_rect().size.x
	if sheet:
		lp._on_fighter_pressed(&"eden")
		lp._slide_overlay(false)
		var cells: Array[Image] = []
		for id: StringName in [&"eden", &"flint", &"bolt", &"flicker", &"shadow", &"sakura", &"wukong", &"twinshot", &"warden"]:
			arena.select_character(arena.get_player(1), id)
			for i: int in 40:  # the zoom-in and the crossfade finish; the backdrop has moved on a little
				await process_frame
			var rect := Rect2i(lp._stage.get_global_rect().position * ratio, lp._stage.size * ratio)
			var cell: Image = root.get_texture().get_image().get_region(rect)
			cell.convert(Image.FORMAT_RGBA8)
			cell.resize(cell.get_width() / 2, cell.get_height() / 2, Image.INTERPOLATE_BILINEAR)
			cells.append(cell)
		var cs: Vector2i = cells[0].get_size()
		var sheet_img := Image.create(cs.x * 5, cs.y * 2, false, Image.FORMAT_RGBA8)
		for k: int in cells.size():
			sheet_img.blit_rect(cells[k], Rect2i(Vector2i.ZERO, cs), Vector2i((k % 5) * cs.x, (k / 5) * cs.y))
		print("[teams_sim] backdrops ", shot_path, " ", sheet_img.save_png(shot_path))
		quit(0)
		return
	if strip:
		lp._on_fighter_pressed(&"bolt")
		var ids: Array = lp._special_cards.keys()
		for k: int in Constants.SKILL_SLOTS:  # a fresh pick has empty slots: equip three to toggle
			arena.select_special(arena.get_player(1), k, ids[k])
		if fly:  # let the slide finish
			for i: int in 24:
				await process_frame
		var removed: StringName = lp._pick()[3]
		var crops: Array[Image] = []
		var picks: Array = [1, 4, 7, 9, 11, 14] if toggle else [0, 1, 2, 3, 4, 6] if fly else [0, 2, 4, 6, 9, 14]
		for i: int in 18:
			if toggle and i == 0:
				lp._on_special_pressed(removed)  # tapping an equipped ability empties its slot
			if toggle and i == 8:
				lp._on_special_pressed(removed)  # and tapping it again puts it back in the first empty slot
			elif fly and not toggle and i == 0:
				for id: StringName in lp._special_cards.keys().slice(3):
					if not lp._pick().slice(2).has(id):
						lp._on_special_pressed(id)
						break
			await process_frame
			if i in picks:
				var frame: Image = root.get_texture().get_image()
				frame.convert(Image.FORMAT_RGBA8)
				frame.resize(frame.get_width() / 2, frame.get_height() / 2, Image.INTERPOLATE_BILINEAR)
				crops.append(frame)
		var cell: Vector2i = crops[0].get_size()
		var out := Image.create(cell.x * 3, cell.y * 2, false, Image.FORMAT_RGBA8)
		for k: int in crops.size():
			out.blit_rect(crops[k], Rect2i(Vector2i.ZERO, cell), Vector2i((k % 3) * cell.x, (k / 3) * cell.y))
		print("[teams_sim] strip ", shot_path, " ", out.save_png(shot_path))
		quit(0)
		return
	if step > 0:
		lp._on_fighter_pressed(pick)
		lp._slide_overlay(false)
		if step == 2:  # two abilities picked, the third slot still empty
			for k: int in 2:
				lp._on_special_pressed(lp._special_cards.keys()[k])
		if tab == 1:
			lp._show_tab(LobbyOverlay.Tab.WEAPON, false)
	for i: int in 10:
		await process_frame
	var img: Image = root.get_texture().get_image()
	print("[teams_sim] lobby screenshot ", shot_path, " ", img.get_size(), " ", img.save_png(shot_path))
	quit(0)
