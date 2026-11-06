extends SceneTree
## Contact sheet of the five fun shared weapons, one labelled row each, written to
## fun_weapons_preview.png in the project root. Needs a window (small, off-screen: override.cfg as in CLAUDE.md Commands,
## with window/size/viewport_width=1334 and viewport_height=750):
##   godot --path . -s tools/fun_weapons_preview.gd

const START_FRAME: int = 420
const ROW_LEN: int = 110
const COLS: int = 6
const CELL: Vector2i = Vector2i(760, 380)
const LABEL_H: int = 40
const PAD: int = 4
const BG: Color = Color(0.08, 0.08, 0.1)
## Per row: label, zoom (1 = wide shot), the world focus offset from `home`, and the physics frames (from the row's start) photographed.
const ROWS_WIDE: Array = [
	{"label": "Splash Soaker: a stream of drooping droplets, the target is soaked (slow, drips); puddle splats fade",
		"zoom": 1, "focus": Vector2(-90, 0), "at": [8, 16, 24, 34, 50, 80]},
	{"label": "Bubble Wand: wobbly bubbles, a hit traps the target 0.7 s, then the bubble pops", "zoom": 1,
		"focus": Vector2(-90, 0), "at": [14, 34, 52, 62, 90, 100]},
	{"label": "Snowball Cannon: lobbed, grows with distance, bursts into snow puffs, chills, leaves a splat",
		"zoom": 1, "focus": Vector2(-80, 0), "at": [3, 9, 15, 22, 27, 45]},
	{"label": "Firework Launcher: sparkly rocket bursts into a star of 8 sparks plus a blast", "zoom": 1,
		"focus": Vector2(-30, 0), "at": [14, 30, 44, 50, 56, 66]},
	{"label": "Hive Gun: 3 bees home in, buzz round the target, then sting", "zoom": 1, "focus": Vector2(-90, 0),
		"at": [6, 16, 28, 40, 52, 64]},
]

## `-- close`: 2x crops (fun_weapons_close.png): each gun in a fighter's hand, the soaked target, the snowball impact, the
## soaker splash and the bees.
const ROWS_CLOSE: Array = [
	{"label": "In hand (2x): Splash Soaker, Bubble Wand, Snowball Cannon, Firework Launcher, Hive Gun", "zoom": 2,
		"focus": Vector2(-190, 0), "at": [5, 15, 25, 35, 45]},
	{"label": "Soaked target (2x): light cool wash plus drips, colours stay recognisable", "zoom": 2, "focus": Vector2(0, 0),
		"at": [20, 30, 40, 50, 60, 70]},
	{"label": "Snowball impact (2x): a crisp burst of round puffs in white / ice / grey", "zoom": 2, "focus": Vector2(60, 0),
		"at": [20, 22, 24, 26, 28, 32]},
	{"label": "Soaker splash (2x): crown + ripple where droplets land", "zoom": 2, "focus": Vector2(10, 0),
		"at": [22, 25, 28, 31, 34, 40]},
	{"label": "Bees (2x): 4-frame wing flap, outlined, circling then stinging", "zoom": 2, "focus": Vector2(0, 0),
		"at": [10, 20, 30, 40, 50, 60]},
]
## `-- new`: the five newer shared weapons (new_weapons_preview.png): Confetti Popper, Cactus Cannon (on a target, then on open
## ground for the full needle ring), Disc Launcher (aimed at the nearest wall), Yo-Yo and Storm Jar. `dump=<dir>` with `only=N`
## also writes every 2nd physics frame of that row as <dir>/f_NNN.png (for GIFs).
const ROWS_NEW: Array = [
	{"label": "Confetti Popper: a wide pop of 7 coloured bits, short range, a puff where they land", "zoom": 1,
		"focus": Vector2(-60, 0), "at": [3, 8, 13, 18, 24, 32]},
	{"label": "Cactus Cannon (hit): a lobbed spiky ball, green burst, a ring of needles flies out", "zoom": 1,
		"focus": Vector2(-40, 0), "at": [20, 36, 48, 52, 56, 62]},
	{"label": "Cactus Cannon (open ground): at the end of the throw the ring of 6 needles", "zoom": 1,
		"focus": Vector2(60, 0), "at": [30, 48, 60, 64, 68, 76]},
	{"label": "Disc Launcher: a fast spinning disc ricochets off the wall, harder every bounce", "zoom": 1,
		"focus": Vector2(0, 0), "at": [6, 14, 22, 30, 40, 52, 64]},
	{"label": "Yo-Yo: snaps out and slows, sleeps spinning at the end, snaps back faster, caught in the hand", "zoom": 2,
		"focus": Vector2(-90, 0), "at": [1, 6, 14, 20, 33, 38]},
	{"label": "Storm Jar: lobbed jar shatters, a thunder ring and lightning jumps to the second fighter", "zoom": 1,
		"focus": Vector2(-30, 0), "at": [20, 28, 32, 34, 38, 46]},
]
## `-- more`: the five even-more weapons (more_weapons_preview.png): Rubber Duck Lobber (bounces off the wall, pops), Popcorn
## Popper, Magnet Blaster (the foe is yanked toward the shooter: nobody simulates here, so his knockback is integrated by
## hand), Pumpkin Mortar (burst + 3 seeds) and Black Hole Orb (drags two foes in over its flight, then implodes).
const ROWS_MORE: Array = [
	{"label": "Rubber Duck Lobber: a lobbed duck bounces off the wall and pops in a splash of foam and water", "zoom": 1,
		"focus": Vector2(0, 0), "at": [6, 14, 22, 62, 66, 72]},
	{"label": "Popcorn Popper: a scatter of kernels that flicker into puffs and pop where they land", "zoom": 1,
		"focus": Vector2(-60, 0), "at": [3, 8, 13, 18, 24, 32]},
	{"label": "Magnet Blaster: a horseshoe bolt hits, field rings close in and the foe is yanked toward the shooter", "zoom": 1,
		"focus": Vector2(-60, 0), "at": [4, 10, 14, 18, 24, 32]},
	{"label": "Pumpkin Mortar: a lobbed pumpkin bursts in a squelchy splat and throws three seeds", "zoom": 1,
		"focus": Vector2(-20, 0), "at": [14, 24, 29, 33, 38, 48]},
	{"label": "Black Hole Orb: a slow orb drags both foes in as it flies, then implodes with a flash and a shock ring", "zoom": 1,
		"focus": Vector2(-20, 0), "at": [15, 45, 65, 77, 82, 90]},
]
var ROWS: Array = ROWS_WIDE
var dump_dir: String = ""
var new_set: bool = false
var more_set: bool = false
var disc_focus: Vector2 = Vector2.ZERO
var focus_now: Vector2 = Vector2.INF  ## a scenario can move the camera (`-- more`)
var close: bool = false
var arena: Arena
var me: Player
var a: Player
var b: Player
var frames: int = 0
var home: Vector2
var shots: Array = []  # per row: Array[Image], each CELL big
var seq: int = 1
var sheet_done: bool = false
## `-- only=N` renders just row N, to burn_preview.png style single-row output (<name>_preview.png via `out=`).
var only: int = -1
var out_path: String = "res://fun_weapons_preview.png"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = int(arg.substr(5))
		elif arg == "close":
			close = true
			ROWS = ROWS_CLOSE
			out_path = "res://fun_weapons_close.png"
		elif arg == "new":
			new_set = true
			ROWS = ROWS_NEW
			out_path = "res://new_weapons_preview.png"
		elif arg == "more":
			more_set = true
			ROWS = ROWS_MORE
			out_path = "res://more_weapons_preview.png"
		elif arg.begins_with("dump="):
			dump_dir = arg.substr(5)
		elif arg.begins_with("out="):
			out_path = arg.substr(4)
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)
	for r: int in ROWS.size():
		shots.append([])


func _w(id: StringName) -> WeaponData:
	return arena.catalog.get_weapon(id)


func _fire(who: Player, dir: Vector2, weapon: StringName) -> void:
	who.set_weapon(_w(weapon))  # the fighter really holds it
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
		arena.select_character(me, &"shadow")  # plain looks: Flint's own flames would read as burning
		arena.select_character(a, &"flicker")
		arena.select_character(b, &"eden")
		st.phase = phase
		for pl: Player in arena.players:
			arena.fill_gaps(pl)  # the lobby starts with empty ability slots
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
	var row: int = (frames - START_FRAME) / ROW_LEN if only < 0 else only
	var n: int = (frames - START_FRAME) % ROW_LEN
	if (only < 0 and row >= ROWS.size()) or (only >= 0 and frames - START_FRAME >= ROW_LEN):
		if not sheet_done:
			sheet_done = true
			_finish()
		return
	_scenario(row, n)
	if dump_dir != "" and n % 2 == 0 and n < 110:
		_dump(row, n)
	if ROWS[row].at.has(n):
		_grab(row)


func _put(who: Player, offset: Vector2) -> void:
	who.global_position = home + offset
	who.velocity = Vector2.ZERO


func _scenario_close(row: int, n: int) -> void:
	_put(b, Vector2(-700, -600))
	a.stats.tick(1.0 / 60.0)
	if n == 0:
		a.stats.reset()
		a.stats.invulnerable_time = 0.0
		arena.effects.clear()
	_put(me, Vector2(-200, 0))
	_put(a, Vector2(0, 0))
	me.facing = Vector2.RIGHT
	var ids: Array[StringName] = [&"splash_soaker", &"bubble_wand", &"snowball_cannon", &"firework_launcher", &"hive_gun"]
	match row:
		0:
			_put(a, Vector2(-700, 300))
			me.set_weapon(_w(ids[mini(n / 10, ids.size() - 1)]))
		1:
			if n < 16 and n % 4 == 0:
				_fire(me, Vector2.RIGHT, &"splash_soaker")
		2:
			_put(a, Vector2(60, 0))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"snowball_cannon")
		3:
			_put(a, Vector2(300, 0))
			if n < 16 and n % 4 == 0:
				_fire(me, Vector2.RIGHT, &"splash_soaker")
		4:
			if n == 0:
				_fire(me, Vector2.RIGHT, &"hive_gun")


func _scenario_new(row: int, n: int) -> void:
	_put(b, Vector2(-700, -600))
	a.stats.tick(1.0 / 60.0)
	if n == 0:
		a.stats.reset()
		a.stats.invulnerable_time = 0.0
		arena.effects.clear()
	_put(me, Vector2(-200, 0))
	_put(a, Vector2(0, 0))
	me.facing = Vector2.RIGHT
	match row:
		0:
			_put(a, Vector2(-60, 0))
			if n == 0 or n == 40:
				_fire(me, Vector2.RIGHT, &"confetti_popper")
		1:
			_put(a, Vector2(150, 0))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"cactus_cannon")
		2:
			_put(a, Vector2(-700, 300))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"cactus_cannon")
		3:
			_put(a, Vector2(-700, 300))
			var edge: float = arena.play_area().end.x - home.x - 170.0
			_put(me, Vector2(edge, 0))
			disc_focus = Vector2(edge - 90.0, 0)
			if n == 0:
				_fire(me, Vector2(1.0, -0.12).normalized(), &"disc_launcher")
		4:
			_put(a, Vector2(-50, 0))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"yoyo")
		5:
			_put(a, Vector2(100, 0))
			_put(b, Vector2(100, 105))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"storm_jar")


func _scenario_more(row: int, n: int) -> void:
	if row != 4:
		_put(b, Vector2(-700, -600))
	a.stats.tick(1.0 / 60.0)
	if n == 0:
		a.stats.reset()
		a.stats.invulnerable_time = 0.0
		arena.effects.clear()
	_put(me, Vector2(-200, 0))
	me.facing = Vector2.RIGHT
	focus_now = Vector2.INF
	match row:
		0:
			var edge: float = arena.play_area().end.x - home.x - 130.0
			focus_now = Vector2(edge - 100.0, 0)
			_put(me, Vector2(edge, 0))
			_put(a, Vector2(-700, 300))
			if n == 0:
				_fire(me, Vector2(1.0, -0.1).normalized(), &"duck_lobber")
		1:
			_put(a, Vector2(-60, 0))
			if n == 0 or n == 40:
				_fire(me, Vector2.RIGHT, &"popcorn_popper")
		2:
			if n == 0:
				_put(a, Vector2(0, 0))
				_fire(me, Vector2.RIGHT, &"magnet_blaster")
			else:  # the pull: knockback integrated by hand (a bit of decay like Player.simulate)
				a.global_position += a.velocity * (1.0 / 60.0)
				a.velocity = a.velocity.move_toward(Vector2.ZERO, Constants.PLAYER_DECEL / 60.0)
		3:
			_put(a, Vector2(60, 0))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"pumpkin_mortar")
		4:
			if n == 0:
				_put(a, Vector2(90, 10))
				_put(b, Vector2(30, -70))
				_fire(me, Vector2.RIGHT, &"black_hole_orb")


func _scenario(row: int, n: int) -> void:
	if more_set:
		_scenario_more(row, n)
		return
	if new_set:
		_scenario_new(row, n)
		return
	if close:
		_scenario_close(row, n)
		return
	var park: Vector2 = Vector2(-700, -600)  # off every photograph, near enough for the camera
	_put(b, park)
	a.stats.tick(1.0 / 60.0)  # (nobody simulates here: tick the timed effects by hand)
	if n == 0:
		a.stats.reset()
		a.stats.invulnerable_time = 0.0
		arena.effects.clear()
	_put(me, Vector2(-200, 0))
	_put(a, Vector2(0, 0))
	me.facing = Vector2.RIGHT
	match row:
		0:
			if n < 44 and n % 4 == 0:
				_fire(me, Vector2.RIGHT, &"splash_soaker")
		1:
			if n == 0:
				_fire(me, Vector2.RIGHT, &"bubble_wand")
		2:
			_put(a, Vector2(60, 0))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"snowball_cannon")
		3:
			_put(me, Vector2(-260, 0))
			_put(a, Vector2(120, 0))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"firework_launcher")
		4:
			if n == 0:
				_fire(me, Vector2.RIGHT, &"hive_gun")


func _crop(row: int) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var zoom: int = ROWS[row].zoom
	var crop_size: Vector2i = CELL / zoom
	var focus: Vector2 = disc_focus if new_set and row == 3 else focus_now if more_set and focus_now != Vector2.INF else ROWS[row].focus as Vector2
	var at: Vector2 = root.get_canvas_transform() * (home + focus)
	var corner: Vector2i = (Vector2i(at) - crop_size / 2).clamp(Vector2i.ZERO, img.get_size() - crop_size)
	var crop: Image = img.get_region(Rect2i(corner, crop_size))
	if zoom > 1:
		crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
	return crop


func _grab(row: int) -> void:
	shots[row].append(await _crop(row))


func _dump(row: int, n: int) -> void:
	var im: Image = await _crop(row)
	DirAccess.make_dir_recursive_absolute(dump_dir)
	im.save_png("%s/f_%03d.png" % [dump_dir, n])


## Blits the cells onto the sheet, then the row labels (rendered in a transparent SubViewport) over it.
func _finish() -> void:
	var rows: Array[int] = []
	if only >= 0:
		rows.append(only)
	else:
		for r: int in ROWS.size():
			rows.append(r)
	var strip_y: int = rows.size() * (CELL.y + LABEL_H + PAD) + PAD
	var size := Vector2i(COLS * (CELL.x + PAD) + PAD, strip_y + LABEL_H + 72 + PAD)
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	for i: int in rows.size():
		for c: int in shots[rows[i]].size():
			var im: Image = shots[rows[i]][c]
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, CELL), Vector2i(PAD + c * (CELL.x + PAD), _row_y(i) + LABEL_H))
	var ids: Array[StringName] = [&"splash_soaker", &"bubble_wand", &"snowball_cannon", &"firework_launcher", &"hive_gun"]
	if new_set:
		ids = [&"confetti_popper", &"cactus_cannon", &"disc_launcher", &"yoyo", &"storm_jar"]
	if more_set:
		ids = [&"duck_lobber", &"popcorn_popper", &"magnet_blaster", &"pumpkin_mortar", &"black_hole_orb"]
	for i: int in ids.size():  # held-weapon icons at 3x
		var icon: Image = _w(ids[i]).sprite.get_image()
		icon.convert(Image.FORMAT_RGBA8)
		icon.resize(icon.get_width() * 3, icon.get_height() * 3, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(PAD + i * (icon.get_width() + 20), strip_y + LABEL_H))
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var board := Node2D.new()
	vp.add_child(board)
	board.draw.connect(func() -> void:
		var font: Font = ThemeDB.fallback_font
		for i: int in rows.size():
			board.draw_string(font, Vector2(PAD + 6, _row_y(i) + LABEL_H - 12), ROWS[rows[i]].label, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				24, Color(0.95, 0.93, 0.85))
		board.draw_string(font, Vector2(PAD + 6, strip_y + LABEL_H - 12), "Held weapons at 3x", HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			24, Color(0.95, 0.93, 0.85)))
	board.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var labels: Image = vp.get_texture().get_image()
	labels.convert(Image.FORMAT_RGBA8)
	sheet.blend_rect(labels, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	if OS.get_cmdline_user_args().has("cells"):  # also write every cell on its own (cell_<row>_<col>.png) to inspect details
		for r: int in ROWS.size():
			for c: int in shots[r].size():
				(shots[r][c] as Image).save_png("/tmp/cell_%d_%d.png" % [r, c])
	sheet.save_png(out_path)
	quit()


func _row_y(r: int) -> int:
	return PAD + r * (CELL.y + LABEL_H + PAD)
