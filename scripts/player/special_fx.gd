class_name SpecialFx
extends Node2D
## Cosmetic, on every peer: the smoke cloud and shadow clones of a player's special, rebuilt each
## frame from the synced skill state (Player calls sync()). Clones copy the owner's sprite,
## walk animation, weapon and hand so they're hard to tell apart.
## Start / end flourishes are detected from state changes (so remote players get them too):
## clones appear in a white cloud poof and vanish in poofs; a transformation is struck by
## lightning in a burst of cloud, and ends in a dark puff.

const SMOKE_PUFFS: int = 10
const SMOKE_SPIN: float = 0.5
const SMOKE_PULSE: float = 2.0
const SMOKE_COLOR: Color = Color(0.2, 0.2, 0.3, 0.82)
const SMOKE_EDGE: Color = Color(0.32, 0.32, 0.46, 0.9)
const FADE_TIME: float = 0.4
const POOF_TIME: float = 0.55
const POOF_PUFFS: int = 7
const POOF_START_R: float = 6.0
const POOF_COLOR: Color = Color(0.96, 0.95, 0.9)
const POOF_DARK: Color = Color(0.2, 0.2, 0.3)
const BOLT_TIME: float = 0.35
const BOLT_COUNT: int = 4
const BOLT_SEGMENTS: int = 6
const BOLT_HEIGHT: float = 170.0
const BOLT_JAG: float = 16.0
const BOLT_WIDTH: float = 6.0
const BOLT_CORE: Color = Color(1, 1, 0.95)
const BOLT_GLOW: Color = Color(0.96, 0.82, 0.34)


class Poof:
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 30.0
	var t: float = 0.0
	var color: Color = Color.WHITE


var _clones: Array[AnimatedSprite2D] = []
var _points := PackedVector2Array()
var _owner: Player
var _smoke_t: float = -1.0
var _poofs: Array[Poof] = []
var _bolt_t: float = -1.0
var _bolts: Array[PackedVector2Array] = []
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
		_poof(p.special.anchor, 64.0, POOF_COLOR)
	elif _was_cloning and not cloning:
		for at: Vector2 in _last_points:
			_poof(at, 30.0, POOF_COLOR)
	_was_cloning = cloning
	if cloning:
		_last_points = _points
	var transformed: bool = p.special.is_transformed()
	if transformed and not _was_transformed:
		_strike(p.global_position)
		_poof(p.global_position, 60.0, POOF_COLOR)
	elif _was_transformed and not transformed and not p.dead:
		_poof(p.global_position, 44.0, POOF_DARK)
	_was_transformed = transformed
	var frames: SpriteFrames = p.character.sprite_frames()
	while _clones.size() < _points.size():
		var c := AnimatedSprite2D.new()
		c.scale = Vector2.ONE * Constants.SPRITE_SCALE
		c.show_behind_parent = true
		add_child(c)
		_clones.append(c)
	var alpha: float = clampf(p.special.active_remaining / FADE_TIME, 0.0, 1.0)
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
	_poofs = _poofs.filter(func(pf: Poof) -> bool: return pf.t < POOF_TIME)
	if _bolt_t >= 0.0:
		_bolt_t += delta
		if _bolt_t > BOLT_TIME:
			_bolt_t = -1.0


func _poof(at: Vector2, radius: float, color: Color) -> void:
	var pf := Poof.new()
	pf.pos = at
	pf.radius = radius
	pf.color = color
	_poofs.append(pf)


## Jagged bolts from above, landing around the player (cosmetic RNG, not the sim's).
func _strike(at: Vector2) -> void:
	_bolts.clear()
	for b: int in BOLT_COUNT:
		var land: Vector2 = at + Vector2(_rng.randf_range(-36.0, 36.0), _rng.randf_range(-8.0, 20.0))
		var bolt := PackedVector2Array()
		for i: int in BOLT_SEGMENTS + 1:
			var k: float = float(i) / BOLT_SEGMENTS
			var jag: float = 0.0 if i == BOLT_SEGMENTS else _rng.randf_range(-BOLT_JAG, BOLT_JAG)
			bolt.append(land + Vector2(jag, -BOLT_HEIGHT * (1.0 - k)))
		_bolts.append(bolt)
	_bolt_t = 0.0


func _draw() -> void:
	_draw_flourishes()
	if _owner == null:
		return
	for i: int in _points.size():
		_draw_clone_weapon(_points[i], Vector2.LEFT if _clones[i].flip_h else Vector2.RIGHT, _clones[i].modulate.a)
	if _smoke_t >= 0.0:
		var anchor: Vector2 = _owner.special.anchor
		var r: float = _owner.special.data.smoke_radius
		draw_circle(anchor, r * 0.7, SMOKE_COLOR)
		for i: int in SMOKE_PUFFS:
			var angle: float = TAU * i / SMOKE_PUFFS + _smoke_t * SMOKE_SPIN
			var reach: float = r * (0.55 + 0.15 * sin(_smoke_t * SMOKE_PULSE + i))
			var puff: Vector2 = anchor + Vector2.RIGHT.rotated(angle) * reach
			draw_circle(puff, r * 0.38, SMOKE_EDGE if i % 3 == 0 else SMOKE_COLOR)


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


## Poofs: a ring of puffs swelling outward and fading. Bolts: glow then core, flickering out.
func _draw_flourishes() -> void:
	for pf: Poof in _poofs:
		var k: float = pf.t / POOF_TIME
		var c: Color = pf.color
		c.a = 1.0 - k * k
		draw_circle(pf.pos, lerpf(POOF_START_R, pf.radius * 0.55, k), c)
		for i: int in POOF_PUFFS:
			var dir: Vector2 = Vector2.RIGHT.rotated(TAU * i / POOF_PUFFS + 0.4)
			draw_circle(pf.pos + dir * pf.radius * k, lerpf(POOF_START_R, pf.radius * 0.4, k), c)
	if _bolt_t >= 0.0 and int(_bolt_t * 30.0) % 3 != 2:
		for bolt: PackedVector2Array in _bolts:
			draw_polyline(bolt, BOLT_GLOW, BOLT_WIDTH)
			draw_polyline(bolt, BOLT_CORE, BOLT_WIDTH * 0.4)
		draw_circle(_bolts[0][_bolts[0].size() - 1], 34.0 * (1.0 - _bolt_t / BOLT_TIME), Color(1, 1, 0.9, 0.6))
