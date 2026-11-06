extends SceneTree
## Grid of a fighter holding every pickup weapon at 8 aim angles (one labelled row per weapon, plus a reference row of
## signature weapons), 3x. A red dot marks where shots spawn (muzzle). Needs a window; run it off-screen (override.cfg
## with window/size/no_focus=true, initial_position_type=0, initial_position=Vector2i(-4000,-4000), viewport 1334x750):
##   godot --path . -s tools/held_weapons_preview.gd -- out=/path/grid.png [ids=yoyo,duck_lobber] [nodots]

const START_FRAME: int = 420
const SETTLE: int = 4  ## physics frames between setting a pose and photographing it
const ZOOM: int = 2
const CROP: Vector2i = Vector2i(240, 224)  ## screen px around the fighter
const CELL: Vector2i = CROP * ZOOM
const LABEL_W: int = 250
const HEAD_H: int = 34
const PAD: int = 2
const BG: Color = Color(0.1, 0.1, 0.13)
const ANGLES: Array[int] = [0, 45, 90, 135, 180, 225, 270, 315]  ## right, down-right, down, down-left, left, up-left, up, up-right
const ANGLE_NAMES: Array[String] = ["right", "down-right", "down", "down-left", "left", "up-left", "up", "up-right"]
const REFERENCE: Array[StringName] = [&"flicker_kunai", &"bolt_zapper", &"eden_sling"]
const DOT: Color = Color(1.0, 0.15, 0.15)

var arena: Arena
var me: Player
var frames: int = 0
var home: Vector2
var ids: Array[StringName] = []
var out_path: String = "res://held_weapons_preview.png"
var dots: bool = true
var cells: Array[Image] = []
var step: int = 0
var done: bool = false
var marker: Node2D


func _initialize() -> void:
	var only: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_path = arg.substr(4)
		elif arg.begins_with("ids="):
			only = arg.substr(4).split(",")
		elif arg == "nodots":
			dots = false
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	if only.is_empty():
		var all: Array[WeaponData] = []
		var dir: DirAccess = DirAccess.open("res://data/weapons")
		for f: String in dir.get_files():
			if f.ends_with(".tres"):
				var w: WeaponData = load("res://data/weapons/" + f) as WeaponData
				if w != null and w.pickup:
					all.append(w)
		all.sort_custom(func(x: WeaponData, y: WeaponData) -> bool: return String(x.id) < String(y.id))
		for w: WeaponData in all:
			ids.append(w.id)
		ids.append_array(REFERENCE)
	else:
		for s: String in only:
			ids.append(StringName(s))
	physics_frame.connect(_tick)


func _w(id: StringName) -> WeaponData:
	return arena.catalog.get_weapon(id)


func _tick() -> void:
	frames += 1
	if frames == 2:
		var input := LocalInput.new()
		input.arena = arena
		me = arena.add_player(1, 0, input)
		arena.attach_local_view(me, input)
		var a: Player = arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
		var st: MatchState = arena.match_state
		var phase: MatchState.Phase = st.phase
		st.phase = MatchState.Phase.LOBBY
		arena.select_character(me, &"shadow")
		arena.select_character(a, &"flicker")
		st.phase = phase
		for pl: Player in arena.players:
			arena.fill_gaps(pl)
		arena.referee.set_ready(1, true)
	if me == null or frames < START_FRAME or done:
		return
	if frames == START_FRAME:
		home = arena.play_area().get_center() + Vector2(0, 40)
		for n: Node in arena.get_children():
			if n is CanvasLayer:
				(n as CanvasLayer).visible = false
		marker = Node2D.new()
		marker.z_index = 100
		marker.draw.connect(_draw_marker)
		arena.add_child(marker)
	for p: Player in arena.players:
		p.controller = null
		p.stats.invulnerable_time = 0.0
		p.stats.hp = p.stats.max_hp
		p.velocity = Vector2.ZERO
		if p != me:
			p.global_position = home + Vector2(-700, -600)
	me.global_position = home
	var total: int = ids.size() * ANGLES.size()
	if step >= total * SETTLE:
		done = true
		_finish()
		return
	var cell: int = step / SETTLE
	var w: WeaponData = _w(ids[cell / ANGLES.size()])
	me.set_weapon(w)
	me.facing = Vector2.from_angle(deg_to_rad(ANGLES[cell % ANGLES.size()]))
	marker.queue_redraw()
	step += 1
	if step % SETTLE == 0:
		_grab()


func _draw_marker() -> void:
	if not dots:
		return
	var w: WeaponData = me.held_weapon().data
	var tip: Vector2 = me.shot_origin(w) + me.facing * w.muzzle_distance()
	marker.draw_circle(tip, 1.6, DOT)


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var at: Vector2 = root.get_canvas_transform() * (home + Vector2(8, 16))
	var corner: Vector2i = (Vector2i(at) - CROP / 2).clamp(Vector2i.ZERO, img.get_size() - CROP)
	var crop: Image = img.get_region(Rect2i(corner, CROP))
	crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
	cells.append(crop)


func _finish() -> void:
	while cells.size() < ids.size() * ANGLES.size():
		await process_frame
	var cols: int = ANGLES.size()
	var size := Vector2i(LABEL_W + cols * (CELL.x + PAD) + PAD, HEAD_H + ids.size() * (CELL.y + PAD) + PAD)
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	for i: int in cells.size():
		var r: int = i / cols
		var c: int = i % cols
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(LABEL_W + PAD + c * (CELL.x + PAD), HEAD_H + r * (CELL.y + PAD)))
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var board := Node2D.new()
	vp.add_child(board)
	board.draw.connect(func() -> void:
		var font: Font = ThemeDB.fallback_font
		var ink := Color(0.95, 0.93, 0.85)
		for c: int in cols:
			board.draw_string(font, Vector2(LABEL_W + PAD + c * (CELL.x + PAD) + 6, HEAD_H - 10), ANGLE_NAMES[c], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, ink)
		for r: int in ids.size():
			var label: String = String(ids[r]) + (" (ref)" if REFERENCE.has(ids[r]) else "")
			board.draw_string(font, Vector2(8, HEAD_H + r * (CELL.y + PAD) + 40), label, HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 12, 22, ink))
	board.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var labels: Image = vp.get_texture().get_image()
	labels.convert(Image.FORMAT_RGBA8)
	sheet.blend_rect(labels, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	sheet.save_png(out_path)
	if OS.get_cmdline_user_args().has("pairs"):  # also <out>_NN.png: two rows each (header cropped in), easier to inspect
		for r: int in range(0, ids.size(), 2):
			var h: int = mini(2, ids.size() - r) * (CELL.y + PAD)
			sheet.get_region(Rect2i(0, HEAD_H + r * (CELL.y + PAD), size.x, h)).save_png("%s_%02d.png" % [out_path.get_basename(), r / 2])
	quit()
