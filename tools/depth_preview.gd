extends SceneTree
## Preview: depth sorting (fighters, walls, crates and upright ability art in one y-sorted layer, the see-through ghost
## of a fighter hidden behind a wall) and the obstacle shading of the three arena themes. Stages one scene, saves a PNG
## of the viewport and quits. Needs a window (focus-safe launch as in CLAUDE.md Commands, add `viewport_width/height`
## to override.cfg for a phone layout):
##   ... -s tools/depth_preview.gd -- scene=coil|sapling|hound_a|hound_b|clones|quake|eruption|wall|crate|themes arena=0|1|2 cap=N out=/tmp/x.png
## `arena` is the layout index (0 Pit, 1 Foundry, 2 Gym), `cap` the frame to grab after the special is pressed.

var arena: Arena
var frames: int = 0
var scene: String = "coil"
var arena_index: int = 0
var cap: int = 45
var out: String = "/tmp/depth_preview.png"
var actors: Array[Dictionary] = []
var players: Array[Player] = []
var focus: Vector2 = Vector2.ZERO
var cam: Camera2D
var grabbed: bool = false

const PRESS_AT: int = 12


class Idle extends PlayerController:
	var aim: Vector2 = Vector2.ZERO
	var press: bool = false
	var seq: int = 0

	func get_input(_p: Player, _d: float) -> InputFrame:
		var f := InputFrame.new()
		seq += 1
		f.seq = seq
		f.aim_vec = aim
		f.special = press
		return f


class Local extends LocalInput:
	var aim: Vector2 = Vector2.ZERO
	var press: bool = false

	func get_input(p: Player, d: float) -> InputFrame:
		var f: InputFrame = super.get_input(p, d)
		f.move_vec = Vector2.ZERO
		f.fire = false
		f.aim_vec = aim
		f.special = press
		return f


func _initialize() -> void:
	InputSetup.ensure_actions()
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"scene": scene = kv[1]
			"arena": arena_index = int(kv[1])
			"cap": cap = int(kv[1])
			"out": out = kv[1]
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)
	process_frame.connect(_hold)  # again after the sim step, so a wall can't push them off their marks in the grabbed frame


## Floor spot (centre of a 5x5 block of plain floor) nearest to `near`.
func open_spot(near: Vector2) -> Vector2:
	var t: float = Constants.TILE_SIZE
	var best: Vector2 = near
	var best_d: float = INF
	var rows: Array[String] = arena.map.rows
	for y: int in range(2, rows.size() - 2):
		for x: int in range(2, rows[y].length() - 2):
			var clear: bool = true
			for dy: int in range(-2, 3):
				for dx: int in range(-2, 3):
					if rows[y + dy][x + dx] in ["#", "C"]:
						clear = false
			var c := Vector2((x + 0.5) * t, (y + 0.5) * t)
			if clear and c.distance_to(near) < best_d:
				best = c
				best_d = c.distance_to(near)
	return best


## An interior wall run (not the border) of at least 3 tiles, nearest to the arena centre.
func wall_run() -> Rect2:
	var t: float = Constants.TILE_SIZE
	var best := Rect2()
	var best_d: float = INF
	for w: Rect2 in arena.map.walls:
		if w.position.y < t * 2 or w.end.y > arena.map.size.y - t * 2 or w.size.x < t * 3 or w.size.x > t * 20:
			continue
		var d: float = w.get_center().distance_to(arena.map.size * 0.5)
		if d < best_d:
			best = w
			best_d = d
	return best


func spawn(id: int, character: StringName, special: StringName, foot: Vector2, aim: Vector2 = Vector2.ZERO) -> void:
	actors.append({"id": id, "char": character, "special": special, "foot": foot, "aim": aim})


func stage() -> void:
	var t: float = Constants.TILE_SIZE
	var p: Vector2 = open_spot(arena.map.size * 0.5)
	match scene:
		"coil", "sapling":
			var owner_char: StringName = &"bolt" if scene == "coil" else &"sakura"
			var skill: StringName = &"tesla_coil" if scene == "coil" else &"cherry_sapling"
			focus = p
			spawn(1, owner_char, skill, p)
			spawn(2, &"flint", &"", p + Vector2(-8, -64))  # behind it
			spawn(3, &"eden", &"", p + Vector2(34, 52))  # in front of it
			actors[0]["after"] = p + Vector2(-110, 4)
		"hound_a", "hound_b":
			focus = p + Vector2(60, 0)
			var dy: float = 14.0 if scene == "hound_a" else -14.0
			spawn(1, &"shadow", &"gloom_hound", p, Vector2.RIGHT)
			spawn(2, &"flint", &"", p + Vector2(210, dy))
		"clones":  # Shade casts Shadow Clones right beside a wall, aiming into it
			var w: Rect2 = wall_run()
			var c: Vector2 = w.get_center()
			focus = Vector2(c.x, w.end.y + 20.0)
			spawn(1, &"flicker", &"shadow_clones", Vector2(c.x, w.end.y + 36.0), Vector2.UP)
		"quake", "eruption":
			var w: Rect2 = wall_run()
			var c: Vector2 = w.get_center()
			focus = Vector2(c.x, w.position.y - 40.0)
			var owner_char: StringName = &"eden" if scene == "quake" else &"flint"
			var skill: StringName = &"thorn_quake" if scene == "quake" else &"eruption"
			spawn(1, owner_char, skill, Vector2(c.x - 90.0, w.position.y - 100.0), Vector2(0.45, 0.9).normalized())
			spawn(2, &"sakura", &"", Vector2(c.x + 60.0, w.position.y - 64.0))
			spawn(3, &"bolt", &"", Vector2(c.x + 5.0, w.end.y + 44.0))  # in front of the wall
		"wall":
			var w: Rect2 = wall_run()
			var c: Vector2 = w.get_center()
			focus = Vector2(c.x, w.end.y - 20.0)
			spawn(1, &"bolt", &"", Vector2(c.x - 70.0, w.end.y - 18.0))  # feet inside the wall: behind its front
			spawn(2, &"flint", &"", Vector2(c.x + 20.0, w.end.y + 46.0))  # in front
			spawn(3, &"sakura", &"", Vector2(c.x + 100.0, w.position.y - 2.0))  # standing on its far side
		"crate":
			var cs: PackedVector2Array = arena.map.crate_spots
			var c: Vector2 = cs[cs.size() / 2] if cs.size() > 0 else p
			focus = c + Vector2(0, 10)
			spawn(1, &"bolt", &"", c + Vector2(-34, 12))  # beside, feet above the crate's base: behind it
			spawn(2, &"flint", &"", c + Vector2(30, 80))
			spawn(3, &"sakura", &"", c + Vector2(0, -16))
		_:  # themes: walls and crates close up
			var w: Rect2 = wall_run()
			focus = w.get_center() + Vector2(0, 30)
			var cs: PackedVector2Array = arena.map.crate_spots
			if cs.size() > 0:
				var best: Vector2 = cs[0]
				for c: Vector2 in cs:
					if c.distance_to(focus) < best.distance_to(focus):
						best = c
				focus = (focus + best) * 0.5
			spawn(1, &"bolt", &"", focus + Vector2(-40, 70))


func _tick() -> void:
	frames += 1
	if frames == 2:
		arena.match_state.arena_index = arena_index
		arena._load_layout(arena_index)
		stage()
		for i: int in actors.size():
			var a: Dictionary = actors[i]
			var ctrl: PlayerController
			if i == 0:
				var l := Local.new()
				l.arena = arena
				ctrl = l
			else:
				ctrl = Idle.new()
			var pl: Player = arena.add_player(a["id"], i, ctrl)
			arena.match_state.phase = MatchState.Phase.LOBBY
			arena.select_character(pl, a["char"])
			if a["special"] != &"":
				arena.select_special(pl, 1, a["special"])
			players.append(pl)
			if i == 0:
				arena.attach_local_view(pl, ctrl)
	if frames == 3:
		arena.set_physics_process(false)  # no referee: the match is simply running
		arena.match_state.phase = MatchState.Phase.PLAYING
		for pl: Player in players:
			pl.frozen = false
		arena.get_node("UI").visible = false
		cam = Camera2D.new()
		cam.zoom = arena.camera.zoom
		arena.add_child(cam)
		cam.make_current()
	if frames >= 3 and cam != null:
		cam.global_position = focus
	_hold()
	if frames == PRESS_AT:
		var l: Local = players[0].controller as Local
		l.aim = actors[0]["aim"]
		l.press = actors[0]["special"] != &""
	if frames == PRESS_AT + 4:
		(players[0].controller as Local).press = false
	if frames == PRESS_AT + cap and not grabbed:
		grabbed = true
		for sk: CharacterSkill in players[0].skills:
			print("slot ", sk.data.id, " active=", sk.is_active(), " anchor=", sk.anchor)
		RenderingServer.frame_post_draw.connect(_grab, CONNECT_ONE_SHOT)


func _hold() -> void:
	if frames < 3 or players.is_empty():
		return
	for i: int in players.size():  # everyone stays on his mark
		if i == 0 and frames >= PRESS_AT + 20 and actors[0].has("after"):
			actors[0]["foot"] = actors[0]["after"]  # the coil / tree stands where it was cast: step the caster aside
		players[i].global_position = (actors[i]["foot"] as Vector2) - Vector2(0, Player.FOOT_RING_Y)
		players[i].facing = Vector2.RIGHT


func _grab() -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
