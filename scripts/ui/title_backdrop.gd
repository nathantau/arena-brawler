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

const LOGO_PX: float = 5.0
const LOGO_TOP: float = 6.0
const LOGO_BOB: float = 5.0
const LOGO_BOB_SPEED: float = 2.0
const SHINE_PERIOD: float = 3.8
const SHINE_TIME: float = 0.8
const TAGLINE: String = "Pick a fighter. Grab a weapon. Brawl."
const TAGLINE_GAP: float = 14.0

## Fighters: where each of the six stands, relative to the screen centre / the floor line.
## (dx, dy, pixel scale, faces left, pose, dim). Left team faces right, right team faces left.
const POSE_IDLE: int = 0
const POSE_RUN: int = 1
const POSE_STRIKE: int = 2
const SLOTS_SMALL: Array[Vector4] = [
	Vector4(-330.0, -6.0, 3.0, POSE_RUN), Vector4(0.0, 10.0, 3.4, POSE_STRIKE), Vector4(330.0, -6.0, 3.0, POSE_RUN)]
const SMALL_ROSTER: int = 3
const FOUR_ROSTER: int = 4
const SLOTS: Array[Vector4] = [
	Vector4(-540.0, -40.0, 2.5, POSE_IDLE), Vector4(-310.0, -14.0, 2.9, POSE_RUN),
	Vector4(-120.0, 6.0, 3.0, POSE_STRIKE), Vector4(120.0, 6.0, 3.0, POSE_STRIKE),
	Vector4(310.0, -14.0, 2.9, POSE_RUN), Vector4(540.0, -40.0, 2.5, POSE_IDLE)]
const FLOOR_LINE_ART: float = 14.0  ## fighters stand this many art px (x ART_SCALE) below the horizon
const CELL_FEET: float = 78.0  ## feet row inside a 96 px sprite cell
const CELL: float = 96.0
const BACK_DIM: float = 0.72
const RUN_SWAY: float = 12.0
const STRIKE_PERIOD: float = 3.6
const STRIKE_STAGGER: float = 1.1
const STRIKE_FPS: float = 10.0
const RING_FPS: float = 36.0
const RING_SCALE: float = 1.7
const RING_ALPHA: float = 0.7
const SHADOW_ALPHA: float = 0.55
const REVEAL_RISE: float = 36.0

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
var _ring: Texture2D = load("res://assets/fx/flare_ring.png")
var _tiles: Texture2D
var _idle: Array = []  ## per slot: Array[Texture2D]
var _run: Array = []
var _strike: Array = []
var _time: float = 0.0
var _slots: Array[Vector4] = SLOTS
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
	if roster.size() <= SMALL_ROSTER:
		_slots = SLOTS_SMALL
	elif roster.size() == FOUR_ROSTER:
		_slots = SLOTS.slice(1, 5)  # the two runners and the two strikers
	else:
		_slots = SLOTS
	for i: int in mini(roster.size(), _slots.size()):
		var f: SpriteFrames = roster[i].sprite_frames()
		_idle.append(_textures(f, &"idle"))
		_run.append(_textures(f, &"walk"))
		_strike.append(_textures(f, &"attack") if f.has_animation(&"attack") else _textures(f, &"idle"))
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
	_draw_fighters(size.x * 0.5 + stage_at.x - origin.x, floor_top + FLOOR_LINE_ART * s)
	_draw_embers()
	draw_texture_rect(_mid, Rect2((origin + cam * MID_PARALLAX).round(), art_size), false)
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


func _draw_fighters(centre_x: float, ground_y: float) -> void:
	var rise: float = (1.0 - reveal) * REVEAL_RISE
	var base := Vector2(centre_x, ground_y)
	# Smallest (back row) first, so nearer fighters overlap them.
	for pass_i: int in 3:
		for i: int in _idle.size():
			var sc: float = _slots[i].z
			var rank: int = 0 if sc < 2.6 else (1 if sc < 2.95 else 2)
			if rank == pass_i:
				_draw_fighter(i, _slots[i], base, rise)


func _draw_fighter(i: int, slot: Vector4, base: Vector2, rise: float) -> void:
	var sc: float = slot.z
	var right_team: bool = slot.x > 0.0
	var pose: int = int(slot.w)
	var t: float = _time + i * 0.37
	var tex: Texture2D
	var ph: float = fposmod(_time + i * STRIKE_STAGGER, STRIKE_PERIOD)
	var dx: float = slot.x
	match pose:
		POSE_RUN:
			var run: Array = _run[i]
			tex = run[int(t * Constants.SPRITE_WALK_FPS) % run.size()]
			dx += sin(_time * 1.3 + i) * RUN_SWAY
		POSE_STRIKE:
			var atk: Array = _strike[i]
			var k: int = int(ph * STRIKE_FPS)
			if k < atk.size() and atk.size() > Constants.SPRITE_IDLE_FRAMES:
				tex = atk[k]
			else:
				var idle: Array = _idle[i]
				tex = idle[int(t * Constants.SPRITE_IDLE_FPS) % idle.size()]
		_:
			var idle2: Array = _idle[i]
			tex = idle2[int(t * Constants.SPRITE_IDLE_FPS) % idle2.size()]
	var feet := Vector2(base.x + dx, base.y + slot.y + rise)
	var shade: float = BACK_DIM if sc < 2.6 else 1.0
	var tint := Color(shade, shade, shade, reveal)
	var ss: Vector2 = _shadow.get_size() * sc * 1.1
	draw_texture_rect(_shadow, Rect2(feet - Vector2(ss.x * 0.5, ss.y * 0.55), ss), false,
		Color(1, 1, 1, SHADOW_ALPHA * reveal))
	var w: float = CELL * sc * (-1.0 if right_team else 1.0)
	var origin := Vector2(feet.x - absf(w) * 0.5, feet.y - CELL_FEET * sc)
	draw_texture_rect(tex, Rect2(origin, Vector2(w, CELL * sc)), false, tint)
	if pose == POSE_STRIKE and ph < 30.0 / RING_FPS:
		var rs: float = _ring.get_height() * RING_SCALE
		var frames: int = _ring.get_width() / _ring.get_height()
		var f: int = mini(int(ph * RING_FPS), frames - 1)
		var c: Vector2 = feet + Vector2(0.0, -6.0 * sc)
		draw_texture_rect_region(_ring, Rect2(c - Vector2(rs, rs) * 0.5, Vector2(rs, rs)),
			Rect2(f * _ring.get_height(), 0, _ring.get_height(), _ring.get_height()), Color(1, 1, 1, RING_ALPHA * reveal))


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
	var base: Vector2 = _logo.get_size() * LOGO_PX
	var bob: float = roundf(sin(_time * LOGO_BOB_SPEED) * LOGO_BOB)
	var top: float = _insets.y + LOGO_TOP
	var rect := Rect2(Vector2((size.x - base.x) * 0.5, top + bob), base)
	var centre: Vector2 = rect.get_center()
	rect = Rect2(centre - base * logo_scale * 0.5, base * logo_scale)
	var tint := Color(1, 1, 1, logo_alpha)
	draw_texture_rect(_logo, rect, false, tint)
	var ph: float = fposmod(_time, SHINE_PERIOD)
	if ph < SHINE_TIME and logo_scale <= 1.01:
		var n: int = _shine.get_width() / _logo.get_width()
		var f: int = mini(int(ph / SHINE_TIME * n), n - 1)
		draw_texture_rect_region(_shine, rect, Rect2(f * _logo.get_width(), 0, _logo.get_width(), _logo.get_height()), tint)
	var tag_y: float = top + base.y + TAGLINE_GAP + UiStyle.SIZE_BODY
	UiStyle.draw_text(self, Vector2(0.0, tag_y), TAGLINE, UiStyle.SIZE_BODY, Color(1, 1, 1, logo_alpha),
		HORIZONTAL_ALIGNMENT_CENTER, size.x)


static func _textures(f: SpriteFrames, anim: StringName) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for k: int in f.get_frame_count(anim):
		out.append(f.get_frame_texture(anim, k))
	return out
