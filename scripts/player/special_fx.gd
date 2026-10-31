class_name SpecialFx
extends Node2D
## Cosmetic, on every peer: the smoke cloud and shadow clones of a player's special, rebuilt each
## frame from the synced skill state (Player calls sync()). Clones copy the owner's sprite,
## walk animation, weapon and hand so they're hard to tell apart.
## Start / end flourishes are detected from state changes (so remote players get them too):
## each clone appears from its own cloud poof around the player and vanishes in one; a transformation morphs into
## the form (SkillData.form_morph) and morphs back when it ends (no cloud drawn over the ape). All pixel-art strips from
## tools/sprites/generate.py (assets/fx), drawn at the characters' pixel scale.
## Vine Swing: the owner's sprite is hidden while his swing pose is drawn raised along the arc, hanging by one fist
## from a vine whose pivot is above the arc's midpoint; leaves burst at takeoff, dust puffs on landing, then the
## vine swings on and pulls up. Progress comes from where the body is drawn along the takeoff -> landing line, so
## interpolated remote players (whose skill state runs ahead of their drawn position) stay in step.

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
const SWING_ART: Texture2D = preload(FX_DIR + "wukong_swing.png")
const VINE_ART: Texture2D = preload(FX_DIR + "vine.png")
const VINE_TOP: Texture2D = preload(FX_DIR + "vine_top.png")
const LEAF_BURST: Texture2D = preload(FX_DIR + "leaf_burst.png")
const SWING_DUST: Texture2D = preload(FX_DIR + "swing_dust.png")
## The gripping fist in a swing frame (cell px; generate.py SWING_HAND): the vine ends there.
const SWING_HAND: Vector2 = Vector2(65, 13)
## How high he rises off the floor mid-swing, and how high above the arc's midpoint the vine hangs from.
const SWING_LIFT_PX: float = 56.0
const VINE_PIVOT_HEIGHT: float = 230.0
## Keep drawing the swing this long after it ends in the synced state, until the drawn body reaches the landing.
const SWING_LINGER: float = 0.25
const VINE_RETRACT_TIME: float = 0.35
## The vine swings on past the landing by this much (radians) while it pulls up.
const VINE_OVERSHOOT: float = 0.6
const LEAF_TIME: float = 0.45
const DUST_TIME: float = 0.4
## Takeoff leaves and landing dust sit at his feet, not his middle.
const SWING_FEET_Y: float = 26.0


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
var _was_swinging: bool = false
## Drawing a swing from _swing_from to _swing_to, _swing_u of the way along; _vine_t >= 0: the vine pulling up after.
var _swing_on: bool = false
var _swing_from: Vector2 = Vector2.ZERO
var _swing_to: Vector2 = Vector2.ZERO
var _swing_u: float = 0.0
var _swing_ground: Vector2 = Vector2.ZERO
var _swing_linger: float = 0.0
var _swing_hand: Vector2 = Vector2.ZERO
var _vine_t: float = -1.0


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
	_sync_swing(p)
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
	queue_redraw()


func _process(delta: float) -> void:
	for pf: Poof in _poofs:
		pf.t += delta
	_poofs = _poofs.filter(func(pf: Poof) -> bool: return pf.t < pf.duration)
	if _morph_t >= 0.0:
		_morph_t += delta
		if _morph_t > MORPH_TIME:
			_morph_t = -1.0
	if _vine_t >= 0.0:
		_vine_t += delta
		if _vine_t > VINE_RETRACT_TIME:
			_vine_t = -1.0


## The owner's first skill slot of `kind` (active or not), or null.
static func _slot(p: Player, kind: SkillData.Kind) -> CharacterSkill:
	for slot: CharacterSkill in p.skills:
		if slot.data.kind == kind:
			return slot
	return null


## The owner's sprite is hidden while this plays (Player).
func is_morphing() -> bool:
	return _morph_t >= 0.0


## The owner's sprite is hidden while the swing pose is drawn instead (Player).
func is_swinging() -> bool:
	return _swing_on


func _sync_swing(p: Player) -> void:
	var swing: CharacterSkill = _slot(p, SkillData.Kind.SWING)
	var active: bool = swing != null and swing.is_active()
	if active and not _was_swinging:
		_swing_on = true
		_swing_from = swing.anchor
		_swing_to = swing.anchor + swing.direction
		_swing_linger = 0.0
		_vine_t = -1.0
		_poof(_swing_from + Vector2(0.0, SWING_FEET_Y), LEAF_BURST, LEAF_TIME)
	_was_swinging = active
	if not _swing_on:
		return
	var chord: Vector2 = _swing_to - _swing_from
	_swing_u = clampf((p.global_position - _swing_from).dot(chord) / maxf(chord.length_squared(), 1.0), 0.0, 1.0)
	_swing_ground = p.global_position + p.visual_offset
	if not active:
		_swing_linger += get_process_delta_time()
	if p.dead:
		_swing_on = false
	elif not active and (_swing_u >= 0.999 or _swing_linger > SWING_LINGER):
		_swing_on = false
		_vine_t = 0.0
		_poof(_swing_to + Vector2(0.0, SWING_FEET_Y), SWING_DUST, DUST_TIME)


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
	_draw_morph()
	_draw_swing()
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


func _draw_swing() -> void:
	var pivot: Vector2 = (_swing_from + _swing_to) * 0.5 + Vector2(0.0, -VINE_PIVOT_HEIGHT)
	var px: float = Constants.SPRITE_SCALE
	var rightward: bool = _swing_to.x >= _swing_from.x
	if _swing_on:
		var body: Vector2 = _swing_ground + Vector2(0.0, -sin(PI * _swing_u) * SWING_LIFT_PX)
		var mirror := Vector2(1.0 if rightward else -1.0, 1.0)
		var cell: float = SWING_ART.get_height()
		_swing_hand = body + (SWING_HAND - Vector2(cell, cell) * 0.5) * mirror * px
		_draw_vine(pivot, _swing_hand)
		var n: int = SWING_ART.get_width() / SWING_ART.get_height()
		draw_set_transform(body, 0.0, mirror)
		_draw_frame(SWING_ART, mini(int(_swing_u * n), n - 1), cell, Vector2.ZERO, px)
		draw_set_transform(Vector2.ZERO)
	elif _vine_t >= 0.0:  # let go: the vine swings on and pulls back up
		var k: float = _vine_t / VINE_RETRACT_TIME
		var spin: float = VINE_OVERSHOOT * k * (-1.0 if rightward else 1.0)
		_draw_vine(pivot, pivot + (_swing_hand - pivot).rotated(spin) * (1.0 - k))


## The vine hanging from `top` down to `end` (cropped to length, never stretched), under its leafy clump.
func _draw_vine(top: Vector2, end: Vector2) -> void:
	var v: Vector2 = end - top
	var px: float = Constants.SPRITE_SCALE
	var w: float = VINE_ART.get_width()
	var h: float = minf(v.length() / px, VINE_ART.get_height())
	if h >= 1.0:
		draw_set_transform(top, v.angle() - PI * 0.5, Vector2(px, px))
		draw_texture_rect_region(VINE_ART, Rect2(-w * 0.5, 0.0, w, h), Rect2(0.0, 0.0, w, h))
		draw_set_transform(Vector2.ZERO)
	_draw_frame(VINE_TOP, 0, VINE_TOP.get_width(), top, px)
