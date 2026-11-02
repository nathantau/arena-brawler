extends SceneTree
## Contact sheet of the weapon hooks (chain arc, boomerang, burn, split shards, parry), one labelled row each, written to
## weapon_hooks_preview.png in the project root. Needs a window (small, off-screen: override.cfg as in CLAUDE.md Commands,
## with window/size/viewport_width=1334 and viewport_height=750):
##   godot --path . -s tools/weapon_hooks_preview.gd

const START_FRAME: int = 420
const ROW_LEN: int = 110
const COLS: int = 6
const CELL: Vector2i = Vector2i(760, 380)
const LABEL_H: int = 40
const PAD: int = 4
const BG: Color = Color(0.08, 0.08, 0.1)
## Per row: label, screen px cropped around the focus (CELL / zoom: 1 = wide shot, 2 = close-up), the world focus offset from
## `home`, and the physics frames (from the row's start) that are photographed.
const ROWS: Array = [
	{"label": "Arc Zapper: chain lightning jumps to the nearest other enemy (70%)", "zoom": 1, "focus": Vector2(-30, 40),
		"at": [4, 5, 6, 7, 9, 12]},
	{"label": "Umbral Shuriken: boomerang, out, turn, back to Shadow", "zoom": 1, "focus": Vector2(-10, 0),
		"at": [4, 16, 28, 34, 46, 58]},
	{"label": "Ember Palm: burning target (tint pulse + flame licks)", "zoom": 2, "focus": Vector2(0, 0),
		"at": [4, 8, 12, 16, 20, 24]},
	{"label": "Seed Sling: bursts into 3 thorn shards", "zoom": 2, "focus": Vector2(60, 0), "at": [19, 22, 25, 28, 32, 38]},
	{"label": "Arc Blade: parry sends the shot back at the shooter", "zoom": 1, "focus": Vector2(-70, 0),
		"at": [9, 11, 12, 14, 18, 23]},
]

var arena: Arena
var me: Player
var a: Player
var b: Player
var frames: int = 0
var home: Vector2
var shots: Array = []  # per row: Array[Image], each CELL big
var seq: int = 1
var sheet_done: bool = false


func _initialize() -> void:
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)
	for r: int in ROWS.size():
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
		arena.select_character(me, &"shadow")  # plain looks: Flint's own flames would read as burning
		arena.select_character(a, &"flicker")
		arena.select_character(b, &"eden")
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
	if row >= ROWS.size():
		if not sheet_done:
			sheet_done = true
			_finish()
		return
	_scenario(row, n)
	if ROWS[row].at.has(n):
		_grab(row)


func _put(who: Player, offset: Vector2) -> void:
	who.global_position = home + offset
	who.velocity = Vector2.ZERO


func _scenario(row: int, n: int) -> void:
	var park: Vector2 = Vector2(-700, -600)  # off every photograph, near enough for the camera
	_put(b, park)
	if row != 2:
		a.stats.burn_remaining = 0.0  # (nobody simulates here, so a burn would never run out)
	match row:
		0:  # Bolt's zap hits A, jumps to the separate B
			_put(me, Vector2(-170, 40))
			_put(a, Vector2(0, 40))
			_put(b, Vector2(100, -25))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"bolt_zapper")
		1:  # boomerang out and back, nobody in the way
			_put(me, Vector2(-230, 0))
			_put(a, park)
			if n == 0:
				_fire(me, Vector2.RIGHT, &"shadow_shuriken")
		2:  # burning target
			_put(me, Vector2(-450, 0))
			_put(a, Vector2.ZERO)
			if n == 0:
				a.stats.ignite(1.5, 2, 0.25, 1)
		3:  # seed sling bursting on a fighter, shards fanning onward
			_put(me, Vector2(-200, 0))
			_put(a, Vector2(60, 0))
			if n == 0:
				_fire(me, Vector2.RIGHT, &"eden_sling")
		4:  # parry: A shoots from the left, the Arc Blade sends it back
			_put(me, Vector2(60, 0))
			_put(a, Vector2(-200, 0))
			me.facing = Vector2.LEFT
			if n == 0:
				_fire(a, Vector2.RIGHT, &"pistol")
			if n == 11:
				_fire(me, Vector2.LEFT, &"sword")


func _grab(row: int) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var zoom: int = ROWS[row].zoom
	var crop_size: Vector2i = CELL / zoom
	var at: Vector2 = root.get_canvas_transform() * (home + ROWS[row].focus as Vector2)
	var corner: Vector2i = (Vector2i(at) - crop_size / 2).clamp(Vector2i.ZERO, img.get_size() - crop_size)
	var crop: Image = img.get_region(Rect2i(corner, crop_size))
	if zoom > 1:
		crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
	shots[row].append(crop)


## Blits the cells onto the sheet, then the row labels (rendered in a transparent SubViewport) over it.
func _finish() -> void:
	var size := Vector2i(COLS * (CELL.x + PAD) + PAD, ROWS.size() * (CELL.y + LABEL_H + PAD) + PAD)
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	for r: int in ROWS.size():
		for c: int in shots[r].size():
			var im: Image = shots[r][c]
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, CELL), Vector2i(PAD + c * (CELL.x + PAD), _row_y(r) + LABEL_H))
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var board := Node2D.new()
	vp.add_child(board)
	board.draw.connect(func() -> void:
		var font: Font = ThemeDB.fallback_font
		for r: int in ROWS.size():
			board.draw_string(font, Vector2(PAD + 6, _row_y(r) + LABEL_H - 12), ROWS[r].label, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
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
	sheet.save_png("res://weapon_hooks_preview.png")
	quit()


func _row_y(r: int) -> int:
	return PAD + r * (CELL.y + LABEL_H + PAD)
