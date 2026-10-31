class_name SpecialFx
extends Node2D
## Cosmetic, on every peer: the smoke cloud and shadow clones of a player's special, rebuilt each
## frame from the synced skill state (Player calls sync()). Clones copy the owner's sprite,
## walk animation, weapon and hand so they're hard to tell apart.
## Start / end flourishes are detected from state changes (so remote players get them too):
## each clone appears from its own cloud poof around the player and vanishes in one; a transformation morphs into
## the form (SkillData.form_morph) and morphs back when it ends (no cloud drawn over the ape). Grapple Kunai: the kunai
## flies out trailing its chain, sparks where it bites and she zips along it in her own pose with speed lines; a miss
## (seen as the short cooldown appearing) flies out to full range and snaps back. All pixel-art strips from
## tools/sprites/generate.py (assets/fx), drawn at the characters' pixel scale.

const FX_DIR: String = "res://assets/fx/"
const POOF_BIG: Texture2D = preload(FX_DIR + "poof.png")
const POOF_SMALL: Texture2D = preload(FX_DIR + "poof_small.png")
const SMOKE_ART: Texture2D = preload(FX_DIR + "smoke.png")
const POOF_TIME: float = 0.5
const SMOKE_FPS: float = 10.0
## The cloud swells in when thrown and fades out at the end instead of popping.
const SMOKE_SWELL_TIME: float = 0.25
const SMOKE_SWELL_FROM: float = 0.4
## smoke.png is drawn for this radius; other radii scale it.
const SMOKE_ART_RADIUS: float = 90.0
const SMOKE_ALPHA: float = 0.9
const FADE_TIME: float = 0.4
## Clones fade in inside their cloud while it's at its fullest (it plays slower than other poofs).
const APPEAR_DELAY: float = 0.08
const APPEAR_TIME: float = 0.2
const CLONE_POOF_TIME: float = 0.7
const MORPH_TIME: float = 1.0
const ZIP_ART: Texture2D = preload(FX_DIR + "flicker_zip.png")
const SPARK_ART: Texture2D = preload(FX_DIR + "grapple_spark.png")
const CHAIN_ART: Texture2D = preload(FX_DIR + "grapple_chain.png")
const KUNAI_ART: Texture2D = preload("res://assets/sprites/projectiles/flicker_kunai.png")
const ZIP_FPS: float = 12.0
## Her outstretched hand in the zip pose (generate.py flicker_zip), from the sprite's centre, facing right.
const ZIP_HAND: Vector2 = Vector2(35, 14)
## Art px from the kunai sprite's centre to its tip and to its ring (generate.py kunai).
const KUNAI_TIP: float = 7.0
const KUNAI_RING: float = 6.0
## Art px between chain links (each link is 6 long, so they overlap like a chain).
const CHAIN_LINK_STEP: float = 4.0
const SPARK_TIME: float = 0.3
## A miss: out to full range, then snapped back faster.
const MISS_OUT_TIME: float = 0.14
const MISS_BACK_TIME: float = 0.1
const SPEED_LINES: int = 5
const SPEED_LINE_GAP: float = 12.0
const SPEED_LINE_LEN: float = 26.0
const SPEED_LINE_SCROLL: float = 900.0
const SPEED_LINE_SPAN: float = 70.0
const SPEED_LINE_COLORS: Array[Color] = [Color("f2f0e6"), Color("9aa7c2")]  # palette WHITE, STEEL


class Poof:
	var pos: Vector2 = Vector2.ZERO
	var art: Texture2D
	var t: float = 0.0
	var duration: float = POOF_TIME


var _clones: Array[AnimatedSprite2D] = []
var _points := PackedVector2Array()
var _owner: Player
var _smoke_t: float = -1.0
var _smoke: CharacterSkill
var _poofs: Array[Poof] = []
var _was_cloning: bool = false
var _was_transformed: bool = false
var _last_points := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
## Seconds into the transformation morph (-1 = none); `_morph_back` plays it in reverse.
var _morph_t: float = -1.0
var _morph_back: bool = false
var _morph_art: Texture2D
var _morph_at: Vector2 = Vector2.ZERO
var _morph_flip: bool = false
var _grapple: CharacterSkill
var _grapple_at: Vector2 = Vector2.ZERO
var _grapple_bit: bool = false
var _grapple_cd: float = 0.0
## Seconds into a missed throw (-1 = none), and its direction.
var _miss_t: float = -1.0
var _miss_dir: Vector2 = Vector2.RIGHT
var _time: float = 0.0


func _init() -> void:
	top_level = true
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func sync(p: Player) -> void:
	_owner = p
	_points = p.clone_points()
	var clones: CharacterSkill = _slot(p, SkillData.Kind.CLONES)
	var smoke: CharacterSkill = _slot(p, SkillData.Kind.SMOKE)
	_smoke = smoke
	var cloning: bool = clones != null and clones.is_cloning()
	if cloning and not _was_cloning:
		for at: Vector2 in _points:
			_poof(at, POOF_BIG, CLONE_POOF_TIME)
	elif _was_cloning and not cloning:
		for at: Vector2 in _last_points:
			_poof(at, POOF_SMALL)
	_was_cloning = cloning
	if cloning:
		_last_points = _points
	var transformed: bool = p.is_transformed()
	if transformed and not _was_transformed:
		_start_morph(p, false)
		if _morph_t < 0.0:
			_poof(p.global_position, POOF_BIG)
	elif _was_transformed and not transformed and not p.dead:
		_start_morph(p, true)
	_was_transformed = transformed
	if p.dead:
		_morph_t = -1.0
	_morph_at = p.global_position + p.visual_offset
	_morph_flip = p.facing.x < 0.0
	var frames: SpriteFrames = p.character.sprite_frames()
	while _clones.size() < _points.size():
		var c := AnimatedSprite2D.new()
		c.scale = Vector2.ONE * Constants.SPRITE_SCALE
		c.show_behind_parent = true
		add_child(c)
		_clones.append(c)
	var alpha: float = 0.0
	if cloning:
		alpha = minf(clampf(clones.active_remaining / FADE_TIME, 0.0, 1.0),
			clampf((clones.elapsed() - APPEAR_DELAY) / APPEAR_TIME, 0.0, 1.0))
	for i: int in _clones.size():
		var c: AnimatedSprite2D = _clones[i]
		c.visible = i < _points.size()
		if not c.visible:
			continue
		if c.sprite_frames != frames:
			c.sprite_frames = frames
		if c.animation != &"walk" or not c.is_playing():
			c.play(&"walk")
		c.position = _points[i]
		c.flip_h = _points[i].x < clones.anchor.x
		c.modulate.a = alpha
	_smoke_t = smoke.elapsed() if smoke != null and smoke.is_smoking() else -1.0
	_sync_grapple(p)
	queue_redraw()


func _sync_grapple(p: Player) -> void:
	var g: CharacterSkill = _slot(p, SkillData.Kind.GRAPPLE)
	var was: CharacterSkill = _grapple
	_grapple = g if g != null and g.is_active() and not p.dead else null
	_grapple_at = p.global_position + p.visual_offset
	if g == null:
		return
	if _grapple != null and was == null:
		_grapple_bit = false
	elif _grapple == null and not p.dead and g.cooldown_remaining > _grapple_cd + 0.01 \
			and g.cooldown_remaining <= g.data.grapple_miss_cooldown:  # a fresh miss (a bite charges the full cooldown)
		_miss_t = 0.0
		_miss_dir = g.direction
	_grapple_cd = g.cooldown_remaining
	if _grapple != null and not _grapple_bit and _grapple.elapsed() >= _grapple.data.grapple_bite_time:
		_grapple_bit = true
		_poof(_bite_point(), SPARK_ART, SPARK_TIME)


func _process(delta: float) -> void:
	for pf: Poof in _poofs:
		pf.t += delta
	_poofs = _poofs.filter(func(pf: Poof) -> bool: return pf.t < pf.duration)
	_time += delta
	if _miss_t >= 0.0:
		_miss_t += delta
		if _miss_t > MISS_OUT_TIME + MISS_BACK_TIME:
			_miss_t = -1.0
	if _morph_t >= 0.0:
		_morph_t += delta
		if _morph_t > MORPH_TIME:
			_morph_t = -1.0


## The owner's first skill slot of `kind` (active or not), or null.
static func _slot(p: Player, kind: SkillData.Kind) -> CharacterSkill:
	for slot: CharacterSkill in p.skills:
		if slot.data.kind == kind:
			return slot
	return null


## The owner's sprite is hidden while a morph or the grapple zip pose plays (Player).
func hides_owner() -> bool:
	return _morph_t >= 0.0 or _grapple != null


func _start_morph(p: Player, back: bool) -> void:
	var form: CharacterSkill = _slot(p, SkillData.Kind.TRANSFORM)
	_morph_art = form.data.form_morph if form != null else null
	if _morph_art == null:
		return
	_morph_back = back
	_morph_t = 0.0


func _poof(at: Vector2, art: Texture2D, duration: float = POOF_TIME) -> void:
	var pf := Poof.new()
	pf.pos = at
	pf.art = art
	pf.duration = duration
	_poofs.append(pf)


## Frame `frame` of a horizontal strip of square frames, centred on `at`, at the sprite scale.
func _draw_frame(art: Texture2D, frame: int, frame_w: float, at: Vector2, scale_px: float, alpha: float = 1.0) -> void:
	var h: float = art.get_height()
	var size := Vector2(frame_w, h) * scale_px
	draw_texture_rect_region(art, Rect2(at - size * 0.5, size), Rect2(frame * frame_w, 0, frame_w, h),
		Color(1, 1, 1, alpha))


func _draw() -> void:
	_draw_grapple()
	_draw_morph()
	_draw_flourishes()
	if _owner == null:
		return
	for i: int in _points.size():
		_draw_clone_weapon(_points[i], Vector2.LEFT if _clones[i].flip_h else Vector2.RIGHT, _clones[i].modulate.a)
	if _smoke_t >= 0.0:
		var frame: int = int(_smoke_t * SMOKE_FPS) % (SMOKE_ART.get_width() / SMOKE_ART.get_height())
		var swell: float = lerpf(SMOKE_SWELL_FROM, 1.0, clampf(_smoke_t / SMOKE_SWELL_TIME, 0.0, 1.0))
		var k: float = _smoke.data.smoke_radius / SMOKE_ART_RADIUS * swell
		var fade: float = clampf(_smoke.active_remaining / FADE_TIME, 0.0, 1.0)
		_draw_frame(SMOKE_ART, frame, SMOKE_ART.get_height(), _smoke.anchor, Constants.SPRITE_SCALE * k,
			SMOKE_ALPHA * fade)

## The clone holds the owner's current weapon (and hand), pointing the way it runs.
func _draw_clone_weapon(at: Vector2, dir: Vector2, alpha: float) -> void:
	var w: WeaponData = _owner.held_weapon().data
	if w.sprite == null or not w.held_art:
		return
	var flip_v: float = -1.0 if dir.x < 0.0 else 1.0
	var s: float = Constants.SPRITE_SCALE
	if w.upright:
		draw_set_transform(at + Player.hand_offset(dir), 0.0, Vector2(s * flip_v, s))
	else:
		draw_set_transform(at + Player.hand_offset(dir), dir.angle(), Vector2(s, s * flip_v))
	var tint := Color(1, 1, 1, alpha)
	w.draw_held(self, Player.WEAPON_GRIP, tint)
	draw_set_transform(Vector2.ZERO)


## Frame by frame from the character into the form (or back). The strip has the growth baked in.
func _draw_morph() -> void:
	if _morph_t < 0.0:
		return
	var n: int = _morph_art.get_width() / _morph_art.get_height()
	var k: int = mini(int(_morph_t / MORPH_TIME * n), n - 1)
	if _morph_back:
		k = n - 1 - k
	draw_set_transform(_morph_at, 0.0, Vector2(-1.0 if _morph_flip else 1.0, 1.0))
	_draw_frame(_morph_art, k, _morph_art.get_height(), Vector2.ZERO, Constants.SPRITE_SCALE)
	draw_set_transform(Vector2.ZERO)


## Poofs play their strip once.
func _draw_flourishes() -> void:
	var px: float = Constants.SPRITE_SCALE
	for pf: Poof in _poofs:
		var n: int = pf.art.get_width() / pf.art.get_height()
		var frame: int = mini(int(pf.t / pf.duration * n), n - 1)
		_draw_frame(pf.art, frame, pf.art.get_height(), pf.pos, px)


## Where the kunai bit: the stop point is a player radius short of the feet-level wall; the wall itself is drawn
## WALL_FEET_STRIP lower.
func _bite_point() -> Vector2:
	return _grapple.anchor + _grapple.direction * (Constants.PLAYER_RADIUS + Constants.GRAPPLE_STANDOFF) \
		+ Vector2(0.0, Constants.WALL_FEET_STRIP)


func _draw_grapple() -> void:
	if _owner == null:
		return
	var s: float = Constants.SPRITE_SCALE
	if _miss_t >= 0.0:
		var hand: Vector2 = _grapple_at + Player.hand_offset(_miss_dir)
		var out: float = _miss_t / MISS_OUT_TIME if _miss_t < MISS_OUT_TIME \
			else 1.0 - (_miss_t - MISS_OUT_TIME) / MISS_BACK_TIME
		var range_px: float = _slot(_owner, SkillData.Kind.GRAPPLE).data.grapple_range
		_draw_chain(hand, hand + _miss_dir * range_px * clampf(out, 0.0, 1.0))
	if _grapple == null:
		return
	var flip: bool = _grapple.direction.x < 0.0
	var hand: Vector2 = _grapple_at + Vector2(-ZIP_HAND.x if flip else ZIP_HAND.x, ZIP_HAND.y)
	var bite: Vector2 = _bite_point()
	var throw: float = clampf(_grapple.elapsed() / _grapple.data.grapple_bite_time, 0.0, 1.0)
	if throw >= 1.0:  # speed lines streaming off behind her while she's pulled
		var dir: Vector2 = _grapple.direction
		for k: int in SPEED_LINES:
			var side: float = (k - (SPEED_LINES - 1) * 0.5) * SPEED_LINE_GAP
			var back: float = fposmod(_time * SPEED_LINE_SCROLL + k * 37.0, SPEED_LINE_SPAN) + Constants.PLAYER_RADIUS
			var a: Vector2 = (_grapple_at + dir.orthogonal() * side - dir * back).snapped(Vector2.ONE * s)
			draw_line(a, a - dir * SPEED_LINE_LEN, SPEED_LINE_COLORS[k % 2], s)
	_draw_chain(hand, hand.lerp(bite, throw))
	draw_set_transform(_grapple_at, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	var n: int = ZIP_ART.get_width() / ZIP_ART.get_height()
	_draw_frame(ZIP_ART, int(_time * ZIP_FPS) % n, ZIP_ART.get_height(), Vector2.ZERO, s)
	draw_set_transform(Vector2.ZERO)


## The kunai with its tip at `tip`, its chain of links trailing back to `hand`.
func _draw_chain(hand: Vector2, tip: Vector2) -> void:
	var s: float = Constants.SPRITE_SCALE
	var dir: Vector2 = (tip - hand).normalized() if tip != hand else Vector2.RIGHT
	var ring: Vector2 = tip - dir * (KUNAI_TIP + KUNAI_RING) * s
	var links: int = int(maxf(0.0, (ring - hand).dot(dir)) / (CHAIN_LINK_STEP * s))
	var link: float = CHAIN_ART.get_height()
	for i: int in links:
		draw_set_transform(hand + dir * (i + 0.5) * CHAIN_LINK_STEP * s, dir.angle(), Vector2(s, s))
		draw_texture_rect_region(CHAIN_ART, Rect2(-link * 0.5, -link * 0.5, link, link), Rect2(i % 2 * link, 0, link, link))
	var kh: float = KUNAI_ART.get_height()
	draw_set_transform(tip - dir * KUNAI_TIP * s, dir.angle(), Vector2(s, s))
	draw_texture_rect_region(KUNAI_ART, Rect2(-kh * 0.5, -kh * 0.5, kh, kh), Rect2(0, 0, kh, kh))
	draw_set_transform(Vector2.ZERO)
