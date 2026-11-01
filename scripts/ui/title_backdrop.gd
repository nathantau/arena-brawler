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

## Home layout: logo, tagline and the menu form one centred group at the top; the roster stands in an arc along the
## bottom, cropped by the screen edge, scaled so it never reaches the group.
const LOGO_BOB: float = 5.0
const LOGO_BOB_SPEED: float = 2.0
const SHINE_PERIOD: float = 3.8
const SHINE_TIME: float = 0.8
const TAGLINE: String = "Pick a fighter. Grab a weapon. Brawl."
const LOGO_PX_WIDE: float = 6.0
const LOGO_PX_NARROW: float = 4.0
const WIDE_MIN: float = 1400.0
const TAG_GAP: float = 10.0  ## logo -> tagline
const MENU_GAP: float = 16.0  ## tagline -> PLAY
const MENU_BLOCK_H: float = 210.0  ## PLAY + status + secondary row, as built by MainMenu
const ARC_GAP: float = 20.0  ## menu block -> tallest fighter
const ARC_SPREAD: float = 0.46  ## fighters span +-this fraction of the width around the centre
const ARC_DIP: float = 40.0  ## the outer fighters stand this much higher than the centre one
const ARC_FEET: float = 14.0  ## centre fighters' feet below the screen bottom
const ARC_FIT: float = 0.85  ## share of a sprite's opaque width that counts toward overlap
const ARC_SCALE_MIN: float = 3.0
const ARC_SCALE_MAX: float = 5.5

const POSE_IDLE: int = 0
const POSE_STRIKE: int = 2
const CELL: float = 96.0
const STRIKE_PERIOD: float = 3.6
const STRIKE_FPS: float = 10.0
const RING_FPS: float = 24.0
const RING_ALPHA: float = 0.5
const SHADOW_ALPHA: float = 0.55
const REVEAL_RISE: float = 36.0
const SPOT_COLOR: Color = Color(1.0, 0.86, 0.55, 1.0)
const SPOT_STEPS: int = 9

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
var _fighters: Array[Dictionary] = []  ## placed per layout: i, feet, sc, flip, pose
var _boxes: Array[Rect2] = []  ## opaque rect of each fighter's idle frame inside its cell
var _laid_out: Vector2 = Vector2.ZERO
var _logo_rect: Rect2 = Rect2()
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
	for i: int in roster.size():
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
	_draw_embers()
	draw_texture_rect(_mid, Rect2((origin + cam * MID_PARALLAX).round(), art_size), false)
	_draw_fighters()
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


## Places the roster in the arc and sets the logo + spotlight; the arc scale keeps clear of the menu block.
func _place(_floor_top: float) -> void:
	_fighters.clear()
	var n: int = _idle.size()
	var w: float = size.x
	var h: float = size.y
	var logo: Vector2 = _logo.get_size()
	var lpx: float = LOGO_PX_WIDE if w >= WIDE_MIN else LOGO_PX_NARROW
	_logo_rect = Rect2(Vector2((w - logo.x * lpx) * 0.5, _insets.y + 4.0), logo * lpx)
	var max_w: float = 1.0
	var max_h: float = 1.0
	for b: Rect2 in _boxes:
		max_w = maxf(max_w, b.size.x)
		max_h = maxf(max_h, b.size.y)
	var spacing: float = w * ARC_SPREAD * 2.0 / maxf(1.0, n - 1.0)
	var room: float = h + ARC_FEET - ARC_DIP - (logo_bottom() + MENU_BLOCK_H + ARC_GAP)
	var sc: float = floorf(minf(spacing / (max_w * ARC_FIT), room / max_h) * 2.0) * 0.5
	sc = clampf(sc, ARC_SCALE_MIN, ARC_SCALE_MAX)
	for k: int in n:
		var u: float = (k - (n - 1) * 0.5) / ((n - 1) * 0.5)
		_fighters.append({"i": k, "feet": Vector2(w * 0.5 + u * w * ARC_SPREAD, h + ARC_FEET - u * u * ARC_DIP),
			"sc": sc, "flip": u > 0.05, "pose": POSE_STRIKE if k == n / 2 else POSE_IDLE})
	_spot = Vector3(w * 0.5, h - 30.0, w * 0.4)
	_fighters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["feet"] as Vector2).y < (b["feet"] as Vector2).y)


## Warm spotlight pool (stacked ellipses) under the arc.
func _draw_spot() -> void:
	var c := Vector2(_spot.x, _spot.y)
	var wide: float = _spot.z
	for k: int in SPOT_STEPS:
		var f: float = 1.0 - float(k) / SPOT_STEPS
		var pts := PackedVector2Array()
		for j: int in 32:
			var t: float = TAU * j / 32.0
			pts.append(c + Vector2(cos(t) * wide * f, sin(t) * wide * f * 0.28))
		draw_colored_polygon(pts, Color(SPOT_COLOR, 0.05 * reveal))


func _draw_fighters() -> void:
	var rise: float = (1.0 - reveal) * REVEAL_RISE
	for f: Dictionary in _fighters:
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
	var ss: Vector2 = _shadow.get_size() * sc * 1.2
	draw_texture_rect(_shadow, Rect2(feet - Vector2(ss.x * 0.5, ss.y * 0.55), ss), false,
		Color(1, 1, 1, SHADOW_ALPHA * reveal))
	var cx: float = box.get_center().x
	var ox: float = feet.x - ((CELL - cx) if flip else cx) * sc
	var oy: float = feet.y - box.end.y * sc
	draw_texture_rect(tex, Rect2(Vector2(ox, oy), Vector2(CELL * sc * (-1.0 if flip else 1.0), CELL * sc)), false,
		Color(1, 1, 1, reveal))
	var frames: int = _ring.get_width() / _ring.get_height()
	if strike and ph < float(frames) / RING_FPS:
		var rs: float = _ring.get_height() * minf(sc / 3.0, 1.6)
		var fr: int = mini(int(ph * RING_FPS), frames - 1)
		var c: Vector2 = feet + Vector2((-1.0 if flip else 1.0) * 6.0 * sc, -6.0 * sc)
		draw_texture_rect_region(_ring, Rect2(c - Vector2(rs, rs) * 0.5, Vector2(rs, rs)),
			Rect2(fr * _ring.get_height(), 0, _ring.get_height(), _ring.get_height()), Color(1, 1, 1, RING_ALPHA * reveal))


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
	var tag_y: float = _logo_rect.end.y + TAG_GAP + UiStyle.SIZE_BODY
	UiStyle.draw_text(self, Vector2(_logo_rect.position.x, tag_y), TAGLINE, UiStyle.SIZE_BODY, Color(1, 1, 1, logo_alpha),
		HORIZONTAL_ALIGNMENT_CENTER, _logo_rect.size.x)


## Y just below the logo + tagline: the menu starts here.
func logo_bottom() -> float:
	return _logo_rect.end.y + TAG_GAP + UiStyle.SIZE_BODY + MENU_GAP


static func _textures(f: SpriteFrames, anim: StringName) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for k: int in f.get_frame_count(anim):
		out.append(f.get_frame_texture(anim, k))
	return out
