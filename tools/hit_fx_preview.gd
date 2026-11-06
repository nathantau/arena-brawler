extends SceneTree
## Preview of the local player's hit confirmation: rows of normal hit / crit / kill markers at five ages of their run
## (impact -> gone), plus the damage numbers other players see (top) vs the ones you deal (bottom). Needs a window;
## run it off-screen (override.cfg: window/size/no_focus=true, initial_position_type=0,
## initial_position=Vector2i(-4000,-4000), viewport_width=2200, viewport_height=1200):
##   open -g -W -n -a /Applications/Godot.app --args --path <repo> --log-file <log> -s tools/hit_fx_preview.gd -- out=/path/hit_fx.png

const ZOOM: float = 2.0
const COLS: int = 5
const CELL: Vector2 = Vector2(220.0, 150.0)
const AGES: Array[float] = [0.04, 0.18, 0.38, 0.62, 0.86]  ## fraction of each marker's run
const BG: Color = Color8(46, 44, 66)
const BG_ALT: Color = Color8(54, 52, 76)

var out: String = "hit_fx.png"
var fxs: Array[Effects] = []
var frames: int = 0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	UiStyle.install()
	var world := Node2D.new()
	world.scale = Vector2.ONE * ZOOM
	root.add_child(world)
	var floor_layer := Node2D.new()
	floor_layer.draw.connect(_draw_floor.bind(floor_layer))
	world.add_child(floor_layer)
	var fighter: CharacterData = CharacterCatalog.load_all().get_character(&"flicker")
	for row: int in 3:
		for col: int in COLS:
			var s := Sprite2D.new()
			s.texture = fighter.portrait(0)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.scale = Vector2.ONE * Constants.SPRITE_SCALE
			s.position = Vector2(col, row) * CELL + CELL * 0.5
			world.add_child(s)
	for i: int in 4:  # one Effects per row: each pool holds 8 markers
		var e := Effects.new()
		e.z_index = 5
		world.add_child(e)
		e.set_process(false)
		fxs.append(e)
	var names: Array[String] = ["HIT", "CRIT", "KILL"]
	for row: int in 3:
		_label(world, names[row], Vector2(4, row * CELL.y + 4))
	_label(world, "NUMBERS  top: other players'   bottom: yours (pop, settled; normal, crit)", Vector2(4, 3 * CELL.y + 4))
	process_frame.connect(_tick)


func _label(world: Node2D, text: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.scale = Vector2.ONE * 0.5
	l.add_theme_font_size_override("font_size", 22)
	world.add_child(l)


func _draw_floor(layer: Node2D) -> void:
	for row: int in 4:
		for col: int in COLS:
			layer.draw_rect(Rect2(Vector2(col, row) * CELL, CELL), BG if (row + col) % 2 == 0 else BG_ALT)


func _tick() -> void:
	frames += 1
	if frames == 2:
		for row: int in 3:
			var fx: Effects = fxs[row]
			for col: int in COLS:
				var c := Vector2(col, row) * CELL + CELL * 0.5 + Vector2(0.0, -4.0)
				fx.hit_marker(c, row >= 1, row == 2)
				var m: Effects.Marker = fx._markers[(fx._mc + fx._markers.size() - 1) % fx._markers.size()]
				m.life = m.duration * (1.0 - AGES[col])
		var base_y: float = 3.0 * CELL.y
		var fx: Effects = fxs[3]
		var ages: Array[float] = [0.04, 0.3, 0.04, 0.3, 0.04]
		var crits: Array[bool] = [false, false, true, true, false]
		for i: int in COLS:
			for local: bool in [false, true]:
				var n_at := Vector2(i * CELL.x + CELL.x * 0.5, base_y + (CELL.y * 0.45 if not local else CELL.y * 0.85))
				fx.damage_number(n_at, 12 + i * 7, crits[i], local)
				var n: Effects.DamageNumber = fx._numbers[(fx._nc + fx._numbers.size() - 1) % fx._numbers.size()]
				n.pos = n_at
				n.life = Effects.NUMBER_TIME - ages[i]
	if frames == 6:
		_grab()


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
