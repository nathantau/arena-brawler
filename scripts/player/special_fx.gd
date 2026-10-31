class_name SpecialFx
extends Node2D
## Cosmetic, on every peer: the smoke cloud, shadow clones and eruption crack of a player's special, rebuilt each
## frame from the synced skill state (Player calls sync()). Clones copy the owner's sprite,
## walk animation, weapon and hand so they're hard to tell apart.
## Start / end flourishes are detected from state changes (so remote players get them too):
## each clone appears from its own cloud poof around the player and vanishes in one; a transformation morphs into
## the form (SkillData.form_morph) and morphs back when it ends (no cloud drawn over the ape); an eruption's crack
## gives way to its pillar of fire. All pixel-art strips from
## tools/sprites/generate.py (assets/fx), drawn at the characters' pixel scale.

const FX_DIR: String = "res://assets/fx/"
const POOF_BIG: Texture2D = preload(FX_DIR + "poof.png")
const POOF_SMALL: Texture2D = preload(FX_DIR + "poof_small.png")
const SMOKE_ART: Texture2D = preload(FX_DIR + "smoke.png")
const CRACK_ART: Texture2D = preload(FX_DIR + "eruption_crack.png")
const ERUPTION_ART: Texture2D = preload(FX_DIR + "eruption.png")
const CRACK_FPS: float = 8.0
## The crack's ring of embers is drawn for this blast radius (generate.py ERUPT_R); other radii scale it.
const ERUPTION_ART_RADIUS: float = 80.0
## Row of eruption.png the pillar rises from (generate.py ERUPT_BASE): it sits on the marked spot.
const ERUPTION_BASE_Y: float = 102.0
const ERUPTION_TIME: float = 0.9
## The strip starts this long before the blast lands, so its first frames (the floor bulging) lead into the burst.
const ERUPTION_LEAD: float = ERUPTION_TIME * 2.0 / 12.0
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


var _clones: Array[AnimatedSprite2D] = []
var _points := PackedVector2Array()
var _owner: Player
var _smoke_t: float = -1.0
var _smoke: CharacterSkill
var _poofs: Array[Poof] = []
var _was_cloning: bool = false
var _was_transformed: bool = false
var _erupt_started: bool = false
## The eruption slot while its crack shows (else null).
var _crack: CharacterSkill
var _last_points := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
## Seconds into the transformation morph (-1 = none); `_morph_back` plays it in reverse.
var _morph_t: float = -1.0
var _morph_back: bool = false
var _morph_art: Texture2D
var _morph_at: Vector2 = Vector2.ZERO
var _morph_flip: bool = false


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
	var eruption: CharacterSkill = _slot(p, SkillData.Kind.ERUPTION)
	var erupting: bool = eruption != null and eruption.is_active() and not p.dead
	if erupting and not _erupt_started and eruption.active_remaining <= ERUPTION_LEAD:  # the pillar comes up
		var lift: float = (ERUPTION_ART.get_height() * 0.5 - ERUPTION_BASE_Y) * Constants.SPRITE_SCALE
		_poof(eruption.anchor + Vector2(0.0, lift), ERUPTION_ART, ERUPTION_TIME)
	_erupt_started = erupting and (_erupt_started or eruption.active_remaining <= ERUPTION_LEAD)
	_crack = eruption if erupting and eruption.active_remaining > ERUPTION_LEAD * 0.5 else null
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
	_draw_flourishes()
	if _owner == null:
		return
	for i: int in _points.size():
		_draw_clone_weapon(_points[i], Vector2.LEFT if _clones[i].flip_h else Vector2.RIGHT, _clones[i].modulate.a)
	if _crack != null:
		var n: int = CRACK_ART.get_width() / CRACK_ART.get_height()
		var k: float = _crack.data.eruption_blast.splash_radius / ERUPTION_ART_RADIUS
		_draw_frame(CRACK_ART, int(_crack.elapsed() * CRACK_FPS) % n, CRACK_ART.get_height(), _crack.anchor,
			Constants.SPRITE_SCALE * k)
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
