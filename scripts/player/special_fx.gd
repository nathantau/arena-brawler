class_name SpecialFx
extends Node2D
## Cosmetic, on every peer: the smoke cloud and shadow clones of a player's special, rebuilt each
## frame from the synced skill state (Player calls sync()). Clones copy the owner's sprite,
## walk animation, weapon and hand so they're hard to tell apart.
## Start / end flourishes are detected from state changes (so remote players get them too):
## each clone appears from its own cloud poof around the player and vanishes in one; a transformation morphs into
## the form (SkillData.form_morph) and morphs back when it ends (no cloud drawn over the ape); the Blossom Ward's
## petals burst out into a ring that follows the player, scatter when it ends and pop where it catches a shot. All pixel-art strips from
## tools/sprites/generate.py (assets/fx), drawn at the characters' pixel scale.

const FX_DIR: String = "res://assets/fx/"
const POOF_BIG: Texture2D = preload(FX_DIR + "poof.png")
const POOF_SMALL: Texture2D = preload(FX_DIR + "poof_small.png")
const SMOKE_ART: Texture2D = preload(FX_DIR + "smoke.png")
const WARD_ART: Texture2D = preload(FX_DIR + "blossom_ward.png")
const WARD_OPEN_ART: Texture2D = preload(FX_DIR + "blossom_ward_open.png")
const WARD_CLOSE_ART: Texture2D = preload(FX_DIR + "blossom_ward_close.png")
const PETAL_POP_ART: Texture2D = preload(FX_DIR + "petal_pop.png")
## The ward strips are drawn for this radius (generate.py WARD_R art px x SPRITE_SCALE); other radii scale them.
const WARD_ART_RADIUS: float = 69.0
const WARD_FPS: float = 10.0
const WARD_OPEN_TIME: float = 0.3
const WARD_CLOSE_TIME: float = 0.5
const PETAL_POP_TIME: float = 0.3
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


class Poof:
	var pos: Vector2 = Vector2.ZERO
	var art: Texture2D
	var t: float = 0.0
	var duration: float = POOF_TIME
	var scale: float = 1.0


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
## Seconds the ward has been up (-1 = down), its radius and where it's drawn (the owner, as drawn).
var _ward_t: float = -1.0
var _ward_radius: float = 0.0
var _ward_at: Vector2 = Vector2.ZERO


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
	var ward: CharacterSkill = _slot(p, SkillData.Kind.WARD)
	var warding: bool = ward != null and ward.is_warding() and not p.dead
	_ward_at = p.global_position + p.visual_offset
	if warding:
		_ward_radius = ward.data.ward_radius
	elif _ward_t >= 0.0 and not p.dead:
		_poof(_ward_at, WARD_CLOSE_ART, WARD_CLOSE_TIME, _ward_scale())
	_ward_t = ward.elapsed() if warding else -1.0
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
	queue_redraw()


func _process(delta: float) -> void:
	for pf: Poof in _poofs:
		pf.t += delta
	_poofs = _poofs.filter(func(pf: Poof) -> bool: return pf.t < pf.duration)
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


## The owner's sprite is hidden while this plays (Player).
func is_morphing() -> bool:
	return _morph_t >= 0.0


func _start_morph(p: Player, back: bool) -> void:
	var form: CharacterSkill = _slot(p, SkillData.Kind.TRANSFORM)
	_morph_art = form.data.form_morph if form != null else null
	if _morph_art == null:
		return
	_morph_back = back
	_morph_t = 0.0


func _poof(at: Vector2, art: Texture2D, duration: float = POOF_TIME, scale: float = 1.0) -> void:
	var pf := Poof.new()
	pf.pos = at
	pf.art = art
	pf.duration = duration
	pf.scale = scale
	_poofs.append(pf)


## A shot caught on the ward (ShieldWall.caught, on every peer).
func petal_pop(at: Vector2) -> void:
	_poof(at, PETAL_POP_ART, PETAL_POP_TIME)


func _ward_scale() -> float:
	return _ward_radius / WARD_ART_RADIUS


## Frame `frame` of a horizontal strip of square frames, centred on `at`, at the sprite scale.
func _draw_frame(art: Texture2D, frame: int, frame_w: float, at: Vector2, scale_px: float, alpha: float = 1.0) -> void:
	var h: float = art.get_height()
	var size := Vector2(frame_w, h) * scale_px
	draw_texture_rect_region(art, Rect2(at - size * 0.5, size), Rect2(frame * frame_w, 0, frame_w, h),
		Color(1, 1, 1, alpha))


func _draw() -> void:
	_draw_morph()
	_draw_ward()
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


## The ring opens in a bloom (its last frame is the loop's first), then loops while it's up.
func _draw_ward() -> void:
	if _ward_t < 0.0:
		return
	var px: float = Constants.SPRITE_SCALE * _ward_scale()
	if _ward_t < WARD_OPEN_TIME:
		var n: int = WARD_OPEN_ART.get_width() / WARD_OPEN_ART.get_height()
		_draw_frame(WARD_OPEN_ART, mini(int(_ward_t / WARD_OPEN_TIME * n), n - 1), WARD_OPEN_ART.get_height(),
			_ward_at, px)
		return
	var frame: int = int((_ward_t - WARD_OPEN_TIME) * WARD_FPS) % (WARD_ART.get_width() / WARD_ART.get_height())
	_draw_frame(WARD_ART, frame, WARD_ART.get_height(), _ward_at, px)


## Poofs play their strip once.
func _draw_flourishes() -> void:
	var px: float = Constants.SPRITE_SCALE
	for pf: Poof in _poofs:
		var n: int = pf.art.get_width() / pf.art.get_height()
		var frame: int = mini(int(pf.t / pf.duration * n), n - 1)
		_draw_frame(pf.art, frame, pf.art.get_height(), pf.pos, px * pf.scale)
