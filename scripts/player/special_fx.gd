class_name SpecialFx
extends Node2D
## Cosmetic, on every peer: the smoke cloud and shadow clones of a player's special, rebuilt each
## frame from the synced skill state (Player calls sync()). Clones copy the owner's sprite,
## walk animation, weapon and hand so they're hard to tell apart.
## Start / end flourishes are detected from state changes (so remote players get them too):
## each clone appears from its own cloud poof around the player and vanishes in one; a transformation is struck by
## lightning in a burst of cloud, and ends in a dark puff. All pixel-art strips from
## tools/sprites/generate.py (assets/fx), drawn at the characters' pixel scale.

const FX_DIR: String = "res://assets/fx/"
const POOF_BIG: Texture2D = preload(FX_DIR + "poof.png")
const POOF_SMALL: Texture2D = preload(FX_DIR + "poof_small.png")
const POOF_DARK: Texture2D = preload(FX_DIR + "poof_dark.png")
const BOLT_ART: Texture2D = preload(FX_DIR + "bolt.png")
const SMOKE_ART: Texture2D = preload(FX_DIR + "smoke.png")
const POOF_FRAMES: int = 6
const POOF_TIME: float = 0.5
const BOLT_VARIANTS: int = 3
const BOLT_COUNT: int = 4
const BOLT_TIME: float = 0.35
const BOLT_SPREAD: Vector2 = Vector2(36, 14)
const SMOKE_FRAMES: int = 4
const SMOKE_FPS: float = 6.0
## smoke.png is drawn for this radius; other radii scale it.
const SMOKE_ART_RADIUS: float = 90.0
const SMOKE_ALPHA: float = 0.9
const FADE_TIME: float = 0.4
## Clones fade in inside their cloud while it's at its fullest (it plays slower than other poofs).
const APPEAR_DELAY: float = 0.08
const APPEAR_TIME: float = 0.2
const CLONE_POOF_TIME: float = 0.7


class Poof:
	var pos: Vector2 = Vector2.ZERO
	var art: Texture2D
	var t: float = 0.0
	var duration: float = POOF_TIME


class Bolt:
	var land: Vector2 = Vector2.ZERO
	var variant: int = 0


var _clones: Array[AnimatedSprite2D] = []
var _points := PackedVector2Array()
var _owner: Player
var _smoke_t: float = -1.0
var _poofs: Array[Poof] = []
var _bolt_t: float = -1.0
var _bolts: Array[Bolt] = []
var _was_cloning: bool = false
var _was_transformed: bool = false
var _last_points := PackedVector2Array()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	top_level = true
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func sync(p: Player) -> void:
	_owner = p
	_points = p.clone_points()
	var cloning: bool = p.special.is_cloning()
	if cloning and not _was_cloning:
		for at: Vector2 in _points:
			_poof(at, POOF_BIG, CLONE_POOF_TIME)
	elif _was_cloning and not cloning:
		for at: Vector2 in _last_points:
			_poof(at, POOF_SMALL)
	_was_cloning = cloning
	if cloning:
		_last_points = _points
	var transformed: bool = p.special.is_transformed()
	if transformed and not _was_transformed:
		_strike(p.global_position)
		_poof(p.global_position, POOF_BIG)
	elif _was_transformed and not transformed and not p.dead:
		_poof(p.global_position, POOF_DARK)
	_was_transformed = transformed
	var frames: SpriteFrames = p.character.sprite_frames()
	while _clones.size() < _points.size():
		var c := AnimatedSprite2D.new()
		c.scale = Vector2.ONE * Constants.SPRITE_SCALE
		c.show_behind_parent = true
		add_child(c)
		_clones.append(c)
	var alpha: float = minf(clampf(p.special.active_remaining / FADE_TIME, 0.0, 1.0),
		clampf((p.special.elapsed() - APPEAR_DELAY) / APPEAR_TIME, 0.0, 1.0))
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
		c.flip_h = _points[i].x < p.special.anchor.x
		c.modulate.a = alpha
	_smoke_t = p.special.elapsed() if p.special.is_smoking() else -1.0
	queue_redraw()


func _process(delta: float) -> void:
	for pf: Poof in _poofs:
		pf.t += delta
	_poofs = _poofs.filter(func(pf: Poof) -> bool: return pf.t < pf.duration)
	if _bolt_t >= 0.0:
		_bolt_t += delta
		if _bolt_t > BOLT_TIME:
			_bolt_t = -1.0


func _poof(at: Vector2, art: Texture2D, duration: float = POOF_TIME) -> void:
	var pf := Poof.new()
	pf.pos = at
	pf.art = art
	pf.duration = duration
	_poofs.append(pf)


## Bolts from above, landing around the player (cosmetic RNG, not the sim's).
func _strike(at: Vector2) -> void:
	_bolts.clear()
	for i: int in BOLT_COUNT:
		var b := Bolt.new()
		b.land = at + Vector2(_rng.randf_range(-BOLT_SPREAD.x, BOLT_SPREAD.x), _rng.randf_range(-BOLT_SPREAD.y, BOLT_SPREAD.y))
		b.variant = _rng.randi_range(0, BOLT_VARIANTS - 1)
		_bolts.append(b)
	_bolt_t = 0.0


## Frame `frame` of a horizontal strip of square frames, centred on `at`, at the sprite scale.
func _draw_frame(art: Texture2D, frame: int, frame_w: float, at: Vector2, scale_px: float, alpha: float = 1.0) -> void:
	var h: float = art.get_height()
	var size := Vector2(frame_w, h) * scale_px
	draw_texture_rect_region(art, Rect2(at - size * 0.5, size), Rect2(frame * frame_w, 0, frame_w, h),
		Color(1, 1, 1, alpha))


func _draw() -> void:
	_draw_flourishes()
	if _owner == null:
		return
	for i: int in _points.size():
		_draw_clone_weapon(_points[i], Vector2.LEFT if _clones[i].flip_h else Vector2.RIGHT, _clones[i].modulate.a)
	if _smoke_t >= 0.0:
		var frame: int = int(_smoke_t * SMOKE_FPS) % SMOKE_FRAMES
		var k: float = _owner.special.data.smoke_radius / SMOKE_ART_RADIUS
		_draw_frame(SMOKE_ART, frame, SMOKE_ART.get_height(), _owner.special.anchor, Constants.SPRITE_SCALE * k,
			SMOKE_ALPHA)

## The clone holds the owner's current weapon (and hand), pointing the way it runs.
func _draw_clone_weapon(at: Vector2, dir: Vector2, alpha: float) -> void:
	var w: WeaponData = _owner.held_weapon().data
	if w.sprite == null:
		return
	var flip_v: float = -1.0 if dir.x < 0.0 else 1.0
	var s: float = Constants.SPRITE_SCALE
	draw_set_transform(at + Vector2(0.0, Player.WEAPON_HAND_Y) + dir * Player.WEAPON_HOLD_DISTANCE, dir.angle(),
		Vector2(s, s * flip_v))
	var tint := Color(1, 1, 1, alpha)
	draw_texture(w.sprite, -Player.WEAPON_GRIP, tint)
	var hand: Texture2D = _owner.character.hand_sprite
	if hand != null:
		draw_texture(hand, -hand.get_size() * 0.5, tint)
	draw_set_transform(Vector2.ZERO)


## Poofs play their strip once; bolts flicker (every third frame off) and stand on their landing spot.
func _draw_flourishes() -> void:
	var px: float = Constants.SPRITE_SCALE
	for pf: Poof in _poofs:
		var frame: int = mini(int(pf.t / pf.duration * POOF_FRAMES), POOF_FRAMES - 1)
		_draw_frame(pf.art, frame, pf.art.get_height(), pf.pos, px)
	if _bolt_t >= 0.0 and int(_bolt_t * 30.0) % 3 != 2:
		var bw: float = BOLT_ART.get_width() / float(BOLT_VARIANTS)
		var bh: float = BOLT_ART.get_height()
		for b: Bolt in _bolts:
			_draw_frame(BOLT_ART, b.variant, bw, b.land - Vector2(0.0, bh * px * 0.5), px)
