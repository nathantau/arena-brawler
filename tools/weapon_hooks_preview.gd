extends SceneTree
## Contact sheet of the weapon hooks (chain arc, boomerang, burn embers, split shards, parry), one row each, written to
## weapon_hooks_preview.png in the project root. Needs a window (small, off-screen: override.cfg as in CLAUDE.md Commands):
##   godot --path . -s tools/weapon_hooks_preview.gd

const START_FRAME: int = 420
const ROW_LEN: int = 110
const COLS: int = 8
const ZOOM: int = 2
const CROP: Vector2i = Vector2i(300, 170)  # screen px around the row's focus point
## Physics frames (from a row's start) that are photographed, per row.
const SHOT_AT: Array = [
	[3, 6, 9, 12, 15, 18, 22, 28],
	[6, 14, 22, 30, 38, 46, 54, 62],
	[4, 8, 12, 16, 20, 24, 28, 32],
	[19, 21, 23, 25, 27, 30, 34, 40],
	[3, 6, 9, 12, 15, 18, 22, 28],
]
const PAD: int = 4

var arena: Arena
var me: Player
var a: Player
var b: Player
var frames: int = 0
var home: Vector2
var shots: Array = []  # Array of Array[Image], per row
var seq: int = 1


func _initialize() -> void:
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)
	for r: int in SHOT_AT.size():
		shots.append([])


func _w(id: StringName) -> WeaponData:
	return arena.catalog.get_weapon(id)


func _fire(who: Player, dir: Vector2, weapon: StringName) -> void:
	who.facing = dir
	arena.projectiles.fire_shot(who.player_id, seq, who.global_position, dir, _w(weapon), 11 + seq)
	seq += 1


func _tick() -> void:
	frames += 1
	if frames == 2:
		var input := LocalInput.new()
		input.arena = arena
		me = arena.add_player(1, 0, input)
		arena.attach_local_view(me, input)
		a = arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
		b = arena.add_bot(Constants.BOT_ID_BASE + 1, arena.free_color_index())
		var st: MatchState = arena.match_state
		var phase: MatchState.Phase = st.phase
		st.phase = MatchState.Phase.LOBBY
		arena.select_character(a, &"shadow")  # plain looks: Flint's own flames would read as burning
		arena.select_character(b, &"bolt")
		st.phase = phase
		arena.referee.set_ready(1, true)  # leaves the loading room: the match counts down, then plays
	if me == null or frames < START_FRAME:
		return
	if frames == START_FRAME:
		home = arena.play_area().get_center() + Vector2(0, 40)
		for n: Node in arena.get_children():
			if n is CanvasLayer:
				(n as CanvasLayer).visible = false
	for p: Player in [me, a, b]:
		p.controller = null
		p.stats.invulnerable_time = 0.0
		p.stats.hp = p.stats.max_hp
	var row: int = (frames - START_FRAME) / ROW_LEN
	var n: int = (frames - START_FRAME) % ROW_LEN
	if row >= SHOT_AT.size():
		_finish()
		return
	_scenario(row, n)
	if SHOT_AT[row].has(n):
		_grab(row)


func _stage(me_at: Vector2, a_at: Vector2, b_at: Vector2) -> void:
	me.global_position = me_at
	a.global_position = a_at
	b.global_position = b_at
	for p: Player in [me, a, b]:
		p.velocity = Vector2.ZERO


func _scenario(row: int, n: int) -> void:
	var far: Vector2 = home + Vector2(-450, 300)  # parked off the photographed area, near enough for the camera
	match row:
		0:  # chain: Bolt's zap hits A, jumps to B
			if n == 0:
				_stage(home - Vector2(240, 0), home, home + Vector2(36, 78))
				me.facing = Vector2.RIGHT
				_fire(me, Vector2.RIGHT, &"bolt_zapper")
			elif n < 30:
				a.global_position = home
				b.global_position = home + Vector2(36, 78)
		1:  # boomerang out and back
			if n == 0:
				_stage(home - Vector2(150, 0), far, far)
				_fire(me, Vector2.RIGHT, &"shadow_shuriken")
			me.global_position = home - Vector2(150, 0)
			a.global_position = far
			b.global_position = far
		2:  # burning target
			if n == 0:
				_stage(home - Vector2(450, 0), home, far)
				a.stats.ignite(1.5, 2, 0.25, 1)
			a.global_position = home
			b.global_position = far
			me.global_position = home - Vector2(450, 0)
		3:  # seed sling bursting on a fighter, shards fanning onward
			if n == 0:
				_stage(home - Vector2(200, 0), home + Vector2(60, 0), far)
				_fire(me, Vector2.RIGHT, &"eden_sling")
			a.global_position = home + Vector2(60, 0)
			me.global_position = home - Vector2(200, 0)
			b.global_position = far
		4:  # parry: A shoots, the Arc Blade sends it back
			if n == 0:
				_stage(home + Vector2(60, 0), home - Vector2(140, 0), far)
				a.facing = Vector2.RIGHT
				me.facing = Vector2.LEFT
				_fire(a, Vector2.RIGHT, &"pistol")
			if n == 4:
				_fire(me, Vector2.LEFT, &"sword")
			a.global_position = home - Vector2(140, 0)
			me.global_position = home + Vector2(60, 0)
			b.global_position = far


func _grab(row: int) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var focus: Vector2 = home + Vector2(-40, 0)
	if row == 0 or row == 2:
		focus = home + Vector2(0, 30 if row == 0 else 0)
	var at: Vector2 = root.get_canvas_transform() * focus
	var corner: Vector2i = (Vector2i(at) - CROP / 2).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var rect := Rect2i(corner, CROP)
	var crop: Image = img.get_region(rect)
	crop.convert(Image.FORMAT_RGBA8)
	crop.resize(crop.get_width() * ZOOM, crop.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	shots[row].append(crop)


func _finish() -> void:
	var cell := Vector2i(CROP * ZOOM)
	var sheet := Image.create(COLS * (cell.x + PAD) + PAD, shots.size() * (cell.y + PAD) + PAD, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.08, 0.1))
	for r: int in shots.size():
		for c: int in shots[r].size():
			var im: Image = shots[r][c]
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(PAD + c * (cell.x + PAD), PAD + r * (cell.y + PAD)))
	sheet.save_png("res://weapon_hooks_preview.png")
	quit()
