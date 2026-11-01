class_name TitleBackdrop
extends Control
## Everything behind the title menu, drawn in one canvas item (one redraw per frame, no allocations):
## a parallax night arena (far stands, stage floor, foreground pillars, swaying stage lights), the roster
## posed as two teams squaring off with light FX, drifting embers and petals, a dithered vignette,
## and the bobbing BRAWLBITS logo with its shine sweep. Art: tools/sprites/generate.py (title_*, logo*).
## IntroSplash drives `logo_scale` / `logo_alpha` / `reveal` / `punch` for the opening.

const ART_DIR: String = "res://assets/ui/"
const ART_W: float = 416.0
const ART_H: float = 200.0
const ART_HORIZON: float = 104.0
const ART_SCALE: float = 4.0
const LIGHT_X: Array[float] = [128.0, 288.0]
const LIGHT_Y: float = 16.0
const BEAM_SWAY: float = 0.1
const BEAM_ALPHA: float = 0.13
const FLOOR_THEME: StringName = &"gym"
const FLOOR_TILE: float = 64.0
const FLOOR_VEIL: Color = Color(0.05, 0.05, 0.1, 0.62)
const FLOOR_FADE_H: float = 90.0
const VIGNETTE_ALPHA: float = 0.7
const VIGNETTE_ART_W: float = 320.0
const VIGNETTE_ART_H: float = 180.0
## Camera drift (px) per layer factor, and its speeds.
const DRIFT: Vector2 = Vector2(14.0, 5.0)
const DRIFT_SPEED: Vector2 = Vector2(0.35, 0.27)
const FAR_PARALLAX: float = 0.3
const STAGE_PARALLAX: float = 0.8
const MID_PARALLAX: float = 1.5
const PUNCH_DECAY: float = 3.0
const PUNCH_PX: float = 14.0

## Home-screen layout concepts. `--home-concept=A|B|C` overrides DEFAULT_CONCEPT:
## A = hero lineup left, logo + button column right; B = one random featured fighter + silhouette crowd, buttons right;
## C = centred logo + PLAY, fighters in a cropped arc along the bottom.
const DEFAULT_CONCEPT: String = "A"
const CONCEPT_FLAG: String = "--home-concept="
const HERO_FLAG: String = "--home-hero="
const LOGO_BOB: float = 5.0
const LOGO_BOB_SPEED: float = 2.0
const SHINE_PERIOD: float = 3.8
const SHINE_TIME: float = 0.8
const TAGLINE: String = "Pick a fighter. Grab a weapon. Brawl."

const POSE_IDLE: int = 0
const POSE_STRIKE: int = 2
const CELL: float = 96.0
const BACK_DIM: float = 0.72
const SILHOUETTE: Color = Color(0.1, 0.1, 0.2, 1.0)
const STRIKE_PERIOD: float = 3.6
const STRIKE_FPS: float = 10.0
const RING_FPS: float = 24.0
const RING_ALPHA: float = 0.5
const SHADOW_ALPHA: float = 0.55
const REVEAL_RISE: float = 36.0
const SPOT_COLOR: Color = Color(1.0, 0.86, 0.55, 1.0)
const SPOT_STEPS: int = 9
## Right-hand button column width (concepts A, B) the lineup keeps clear of.
const COLUMN_W: float = 480.0

const EMBER_COUNT: int = 44
const PETAL_EVERY: int = 4
const EMBER_COLORS: Array[Color] = [UiStyle.C_ORANGE, UiStyle.C_YELLOW, UiStyle.C_RED, UiStyle.C_WHITE]
const PETAL_COLORS: Array[Color] = [Color8(226, 110, 160), Color8(250, 196, 214)]
const EMBER_SIZES: Array[float] = [4.0, 4.0, 6.0, 8.0]

## Set by IntroSplash.
var logo_scale: float = 1.0
var logo_alpha: float = 1.0
var reveal: float = 1.0
var punch: float = 0.0
## 0..1: opaque boot colour laid over the arena, under the logo (the intro fades it out).
var veil: float = 0.0

var _far: Texture2D = load(ART_DIR + "title_far.png")
var _mid: Texture2D = load(ART_DIR + "title_mid.png")
var _vignette: Texture2D = load(ART_DIR + "title_vignette.png")
var _beam: Texture2D = load(ART_DIR + "title_beam.png")
var _shadow: Texture2D = load(ART_DIR + "title_shadow.png")
var _logo: Texture2D = load(ART_DIR + "logo.png")
var _shine: Texture2D = load(ART_DIR + "logo_shine.png")
var _ring: Texture2D = load("res://assets/fx/slam.png")
var _tiles: Texture2D
var _idle: Array = []  ## per slot: Array[Texture2D]
var _run: Array = []
var _strike: Array = []
var _time: float = 0.0
var concept: String = DEFAULT_CONCEPT
var _fighters: Array[Dictionary] = []  ## placed per layout: i, feet, sc, flip, pose, shade, sil
var _boxes: Array[Rect2] = []  ## opaque rect of each fighter's idle frame inside its cell
var _names: Array[String] = []
var _hero: int = 0
var _laid_out: Vector2 = Vector2.ZERO
var _logo_rect: Rect2 = Rect2()
var _logo_align: int = HORIZONTAL_ALIGNMENT_CENTER
var _spot: Vector3 = Vector3.ZERO  ## spotlight pool centre x, y, half-width
var _insets: Vector4 = Vector4.ZERO
var _version: String = ""
var _ex: PackedFloat32Array = PackedFloat32Array()  ## ember x, y (0..1), rise speed, drift, phase, size index
var _ey: PackedFloat32Array = PackedFloat32Array()
var _ev: PackedFloat32Array = PackedFloat32Array()
var _ed: PackedFloat32Array = PackedFloat32Array()
var _ep: PackedFloat32Array = PackedFloat32Array()
var _ek: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tiles = load(ArenaFloor.ART_DIR + "%s_tiles.png" % FLOOR_THEME)
	var roster: Array[CharacterData] = CharacterCatalog.load_all().ordered
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(CONCEPT_FLAG):
			concept = a.trim_prefix(CONCEPT_FLAG).to_upper()
	_hero = randi() % roster.size()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(HERO_FLAG):
			_hero = a.trim_prefix(HERO_FLAG).to_int() % roster.size()
	for i: int in roster.size():
		_names.append(roster[i].display_name)
		var f: SpriteFrames = roster[i].sprite_frames()
		_idle.append(_textures(f, &"idle"))
		_run.append(_textures(f, &"walk"))
		_strike.append(_textures(f, &"attack") if f.has_animation(&"attack") else _textures(f, &"idle"))
		var img: Image = (_idle[i][0] as Texture2D).get_image()
		_boxes.append(Rect2(img.get_used_rect()))
	_insets = UiStyle.safe_insets(get_viewport())
	get_viewport().size_changed.connect(func() -> void: _insets = UiStyle.safe_insets(get_viewport()))
	_version = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1280
	for i: int in EMBER_COUNT:
		var petal: bool = i % PETAL_EVERY == 0
		_ex.append(rng.randf())
		_ey.append(rng.randf())
		_ev.append(rng.randf_range(-0.16, -0.05) if not petal else rng.randf_range(0.03, 0.07))
		_ed.append(rng.randf_range(-0.02, 0.02) if not petal else rng.randf_range(-0.07, -0.03))
		_ep.append(rng.randf() * TAU)
		_ek.append(rng.randi_range(0, EMBER_SIZES.size() - 1) if not petal else rng.randi_range(0, 1))
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))


func _process(delta: float) -> void:
	_time += delta
	punch = maxf(0.0, punch - delta * PUNCH_DECAY)
	for i: int in EMBER_COUNT:
		_ey[i] += _ev[i] * delta
		_ex[i] += (_ed[i] + sin(_time * 0.9 + _ep[i]) * 0.012) * delta
		if _ey[i] < -0.04 or _ey[i] > 1.04:
			_ey[i] = 1.03 if _ev[i] < 0.0 else -0.03
		_ex[i] = fposmod(_ex[i], 1.0)
	queue_redraw()


func _draw() -> void:
	var s: float = maxf(ART_SCALE, maxf(size.x * 1.06 / ART_W, size.y * 1.06 / ART_H))
	var cam := Vector2(sin(_time * DRIFT_SPEED.x) * DRIFT.x, sin(_time * DRIFT_SPEED.y) * DRIFT.y)
	cam += Vector2(sin(_time * 90.0), cos(_time * 77.0)) * (punch * PUNCH_PX)
	var origin := Vector2((size.x - ART_W * s) * 0.5, (size.y - ART_H * s) * 0.5)
	var art_size := Vector2(ART_W, ART_H) * s
	var far_at: Vector2 = (origin + cam * FAR_PARALLAX).round()
	var stage_at: Vector2 = (origin + cam * STAGE_PARALLAX).round()
	var floor_top: float = stage_at.y + ART_HORIZON * s

	draw_texture_rect(_far, Rect2(far_at, art_size), false)
	_draw_beams(far_at, s)
	_draw_floor(stage_at, floor_top)
	if _laid_out != size:
		_laid_out = size
		_place(floor_top)
	_draw_spot()
	_draw_fighters(false)
	_draw_embers()
	draw_texture_rect(_mid, Rect2((origin + cam * MID_PARALLAX).round(), art_size), false)
	_draw_fighters(true)
	_draw_scrim()
	var vs: float = maxf(size.x / VIGNETTE_ART_W, size.y / VIGNETTE_ART_H)
	var vsize := Vector2(VIGNETTE_ART_W, VIGNETTE_ART_H) * vs
	draw_texture_rect(_vignette, Rect2((size - vsize) * 0.5, vsize), false, Color(1, 1, 1, VIGNETTE_ALPHA))
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiStyle.C_OUTLINE, veil))
	_draw_logo()
	UiStyle.draw_text(self, Vector2(_insets.x, size.y - maxf(_insets.w, 16.0)), _version, UiStyle.SIZE_TINY,
		UiStyle.C_DIM)


func _draw_beams(far_at: Vector2, s: float) -> void:
	var bs: Vector2 = _beam.get_size()
	for i: int in LIGHT_X.size():
		var ang: float = sin(_time * 0.6 + i * 2.3) * BEAM_SWAY + (0.12 if i == 0 else -0.12)
		draw_set_transform(far_at + Vector2(LIGHT_X[i], LIGHT_Y) * s, ang, Vector2(s, s))
		draw_texture_rect(_beam, Rect2(-bs.x * 0.5, 0.0, bs.x, bs.y), false, Color(1, 1, 1, BEAM_ALPHA))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_floor(stage_at: Vector2, floor_top: float) -> void:
	var cell := Rect2(0, 0, ArenaFloor.ART_TILE, ArenaFloor.ART_TILE)
	var x0: float = fposmod(stage_at.x, FLOOR_TILE) - FLOOR_TILE
	var y: float = floor_top
	while y < size.y:
		var x: float = x0
		while x < size.x:
			draw_texture_rect_region(_tiles, Rect2(x, y, FLOOR_TILE, FLOOR_TILE), cell)
			x += FLOOR_TILE
		y += FLOOR_TILE
	draw_rect(Rect2(0.0, floor_top, size.x, size.y - floor_top), FLOOR_VEIL)
	var dark := Color(UiStyle.C_OUTLINE, 0.85)
	var clear := Color(UiStyle.C_OUTLINE, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, floor_top), Vector2(size.x, floor_top),
		Vector2(size.x, floor_top + FLOOR_FADE_H), Vector2(0, floor_top + FLOOR_FADE_H)]),
		PackedColorArray([dark, dark, clear, clear]))


## Concept layouts. Fighters are placed in canvas units; also sets the logo rect and the spotlight pool.
func _place(floor_top: float) -> void:
	_fighters.clear()
	var n: int = _idle.size()
	var w: float = size.x
	var h: float = size.y
	var ins: Vector4 = _insets
	var logo: Vector2 = _logo.get_size()
	match concept:
		"B":
			var lpx: float = 4.0 if w < 1400.0 else 4.5
			_logo_rect = Rect2(Vector2(maxf(ins.x, 16.0) + 0.17 * w + 10.0, ins.y + 10.0), logo * lpx)
			_logo_align = HORIZONTAL_ALIGNMENT_LEFT
			var hero_x: float = w * 0.30
			var others: Array[int] = []
			for i: int in n:
				if i != _hero:
					others.append(i)
			var cl: float = hero_x + (170.0 if w < 1400.0 else 200.0)
			var span: float = w - COLUMN_W - 120.0 - cl
			for k: int in others.size():
				var u: float = (k + 0.5) / others.size()
				var row: int = k % 2
				_fighters.append({"i": others[k], "feet": Vector2(cl + span * u + row * 20.0, floor_top + 60.0 + row * 34.0),
					"sc": 2.6, "flip": true, "pose": POSE_IDLE, "shade": 1.0, "sil": true})
			var hs: float = 7.0 if w > 1400.0 else 5.0
			_fighters.append({"i": _hero, "feet": Vector2(hero_x, h - 84.0), "sc": hs, "flip": false,
				"pose": POSE_STRIKE, "shade": 1.0, "sil": false, "hero": true})
			_spot = Vector3(hero_x, h - 80.0, 330.0)
		"C":
			var lpx2: float = 6.0 if w > 1400.0 else 5.0
			_logo_rect = Rect2(Vector2((w - logo.x * lpx2) * 0.5, ins.y + 4.0), logo * lpx2)
			_logo_align = HORIZONTAL_ALIGNMENT_CENTER
			var sc: float = clampf(w / (n * 42.0), 3.5, 7.0)
			for k: int in n:
				var u2: float = (k - (n - 1) * 0.5) / ((n - 1) * 0.5)
				var feet := Vector2(w * 0.5 + u2 * w * 0.46, h + 14.0 - u2 * u2 * 40.0)
				_fighters.append({"i": k, "feet": feet, "sc": sc, "flip": u2 > 0.05, "pose": POSE_STRIKE if k == n / 2 else POSE_IDLE,
					"shade": 1.0 if absf(u2) < 0.6 else 0.85, "sil": false, "front": true})
			_spot = Vector3(w * 0.5, h - 30.0, w * 0.4)
		_:
			var lpx3: float = floorf(COLUMN_W / logo.x)
			var cx: float = w - maxf(ins.z, 16.0) - 24.0 - COLUMN_W * 0.5
			_logo_rect = Rect2(Vector2(cx - logo.x * lpx3 * 0.5, ins.y + 6.0), logo * lpx3)
			_logo_align = HORIZONTAL_ALIGNMENT_CENTER
			var narrow: bool = w < 1400.0
			var left: float = 140.0 if narrow else 0.09 * w + 120.0
			var right: float = w - COLUMN_W - (20.0 if narrow else 90.0)
			var back: Array[int] = [0, 2, 4, 6]
			var front: Array[int] = [1, 3, 5]
			var bs: float = 3.0 if narrow else 4.5
			var fs: float = 3.5 if narrow else 5.5
			for k: int in back.size():
				if back[k] < n:
					var u3: float = (k + 0.5) / back.size()
					_fighters.append({"i": back[k], "feet": Vector2(lerpf(left, right, u3), floor_top + (70.0 if narrow else 80.0)),
						"sc": bs, "flip": false, "pose": POSE_IDLE, "shade": BACK_DIM, "sil": false, "front": true})
			for k: int in front.size():
				if front[k] < n:
					var u4: float = (k + 1.0) / (front.size() + 1.0)
					_fighters.append({"i": front[k], "feet": Vector2(lerpf(left, right, u4), floor_top + (165.0 if narrow else 190.0)),
						"sc": fs, "flip": false, "pose": POSE_STRIKE if k == 1 else POSE_IDLE, "shade": 1.0, "sil": false, "front": true})
			_spot = Vector3((left + right) * 0.5, h * 0.80, (right - left) * 0.65)
	_fighters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["feet"] as Vector2).y < (b["feet"] as Vector2).y)


## Warm spotlight pool (stacked ellipses) plus a soft light cone behind the featured fighters.
func _draw_spot() -> void:
	var c := Vector2(_spot.x, _spot.y)
	var wide: float = _spot.z
	var a: float = reveal
	for k: int in SPOT_STEPS:
		var f: float = 1.0 - float(k) / SPOT_STEPS
		var pts := PackedVector2Array()
		for j: int in 32:
			var t: float = TAU * j / 32.0
			pts.append(c + Vector2(cos(t) * wide * f, sin(t) * wide * f * 0.28))
		draw_colored_polygon(pts, Color(SPOT_COLOR, 0.05 * a))
	if concept != "C":
		var top := Vector2(c.x, -20.0)
		var tw: float = wide * 0.15
		var clear := Color(SPOT_COLOR, 0.0)
		var lit := Color(SPOT_COLOR, 0.13 * a)
		draw_polygon(PackedVector2Array([top + Vector2(-tw, 0), top + Vector2(tw, 0), c + Vector2(wide * 0.75, 0), c + Vector2(-wide * 0.75, 0)]),
			PackedColorArray([clear, clear, lit, lit]))


## Dark gradient behind the right-hand button column (A, B) so the pillars and banner don't fight the buttons.
func _draw_scrim() -> void:
	if concept == "C":
		return
	var x0: float = size.x - maxf(_insets.z, 16.0) - 24.0 - COLUMN_W - 70.0
	var clear := Color(UiStyle.C_OUTLINE, 0.0)
	var dark := Color(UiStyle.C_OUTLINE, 0.82 * reveal)
	draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 70.0, 0), Vector2(x0 + 70.0, size.y), Vector2(x0, size.y)]),
		PackedColorArray([clear, dark, dark, clear]))
	draw_rect(Rect2(x0 + 70.0, 0.0, size.x - x0 - 70.0, size.y), dark)


func _draw_fighters(front_pass: bool) -> void:
	var rise: float = (1.0 - reveal) * REVEAL_RISE
	for f: Dictionary in _fighters:
		if f.has("front") == front_pass:
			_draw_fighter(f, rise)


func _draw_fighter(f: Dictionary, rise: float) -> void:
	var i: int = f["i"]
	var sc: float = f["sc"]
	var flip: bool = f["flip"]
	var t: float = _time + i * 0.37
	var tex: Texture2D
	var ph: float = fposmod(_time + i * 1.1, STRIKE_PERIOD)
	var strike: bool = false
	if int(f["pose"]) == POSE_STRIKE:
		var atk: Array = _strike[i]
		var k: int = int(ph * STRIKE_FPS)
		if k < atk.size() and atk.size() > Constants.SPRITE_IDLE_FRAMES:
			tex = atk[k]
			strike = true
	if tex == null:
		var idle: Array = _idle[i]
		tex = idle[int(t * Constants.SPRITE_IDLE_FPS) % idle.size()]
	var box: Rect2 = _boxes[i]
	var feet: Vector2 = (f["feet"] as Vector2) + Vector2(0.0, rise)
	var shade: float = f["shade"]
	var tint := Color(shade, shade, shade, reveal)
	if f["sil"]:
		tint = Color(SILHOUETTE.r, SILHOUETTE.g, SILHOUETTE.b, reveal * 0.95)
	var ss: Vector2 = _shadow.get_size() * sc * 1.2
	draw_texture_rect(_shadow, Rect2(feet - Vector2(ss.x * 0.5, ss.y * 0.55), ss), false,
		Color(1, 1, 1, SHADOW_ALPHA * reveal))
	var cx: float = box.get_center().x
	var ox: float = feet.x - ((CELL - cx) if flip else cx) * sc
	var oy: float = feet.y - box.end.y * sc
	draw_texture_rect(tex, Rect2(Vector2(ox, oy), Vector2(CELL * sc * (-1.0 if flip else 1.0), CELL * sc)), false, tint)
	var frames: int = _ring.get_width() / _ring.get_height()
	if strike and ph < float(frames) / RING_FPS and not f["sil"]:
		var rs: float = _ring.get_height() * minf(sc / 3.0, 1.6)
		var fr: int = mini(int(ph * RING_FPS), frames - 1)
		var c: Vector2 = feet + Vector2((-1.0 if flip else 1.0) * 6.0 * sc, -6.0 * sc)
		draw_texture_rect_region(_ring, Rect2(c - Vector2(rs, rs) * 0.5, Vector2(rs, rs)),
			Rect2(fr * _ring.get_height(), 0, _ring.get_height(), _ring.get_height()), Color(1, 1, 1, RING_ALPHA * reveal))
	if f.has("hero"):
		UiStyle.draw_text(self, Vector2(feet.x - 150.0, feet.y + 46.0), _names[i].to_upper(), UiStyle.SIZE_HEADING,
			UiStyle.C_YELLOW, HORIZONTAL_ALIGNMENT_CENTER, 300.0, true)


func _draw_embers() -> void:
	for i: int in EMBER_COUNT:
		var petal: bool = i % PETAL_EVERY == 0
		var tw: float = 0.55 + 0.45 * sin(_time * 5.0 + _ep[i] * 3.0)
		var col: Color = PETAL_COLORS[_ek[i]] if petal else EMBER_COLORS[(i + _ek[i]) % EMBER_COLORS.size()]
		col.a = (0.9 if petal else tw) * reveal
		var px: float = EMBER_SIZES[_ek[i]]
		var at := Vector2(roundf(_ex[i] * size.x / px) * px, roundf(_ey[i] * size.y / px) * px)
		draw_rect(Rect2(at, Vector2(px * 1.5, px) if petal else Vector2(px, px)), col)


func _draw_logo() -> void:
	var base: Vector2 = _logo_rect.size
	var bob: float = roundf(sin(_time * LOGO_BOB_SPEED) * LOGO_BOB)
	var rect := Rect2(_logo_rect.position + Vector2(0.0, bob), base)
	var centre: Vector2 = rect.get_center()
	rect = Rect2(centre - base * logo_scale * 0.5, base * logo_scale)
	var tint := Color(1, 1, 1, logo_alpha)
	draw_texture_rect(_logo, rect, false, tint)
	var ph: float = fposmod(_time, SHINE_PERIOD)
	if ph < SHINE_TIME and logo_scale <= 1.01:
		var n: int = _shine.get_width() / _logo.get_width()
		var f: int = mini(int(ph / SHINE_TIME * n), n - 1)
		draw_texture_rect_region(_shine, rect, Rect2(f * _logo.get_width(), 0, _logo.get_width(), _logo.get_height()), tint)
	var tag_y: float = _logo_rect.end.y + 18.0 + UiStyle.SIZE_BODY
	UiStyle.draw_text(self, Vector2(_logo_rect.position.x, tag_y), TAGLINE, UiStyle.SIZE_BODY, Color(1, 1, 1, logo_alpha),
		_logo_align, _logo_rect.size.x)


## Y just below the logo + tagline: the menu stacks under it (concepts A, B, C).
func logo_bottom() -> float:
	return _logo_rect.end.y + 18.0 + UiStyle.SIZE_BODY + 14.0


static func _textures(f: SpriteFrames, anim: StringName) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for k: int in f.get_frame_count(anim):
		out.append(f.get_frame_texture(anim, k))
	return out
