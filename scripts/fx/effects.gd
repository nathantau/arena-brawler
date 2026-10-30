class_name Effects
extends Node2D
## Cosmetic-only effects in world space: particle bursts, damage numbers, beam lines, sword
## swings and blasts. Fixed-size pools, one _draw for everything, no per-frame
## allocation. Uses its own RNG (never the shared sim's).
## Pixel art throughout: blasts / slams / slashes play strips from tools/sprites/generate.py
## (assets/fx), particles and beams are hard-edged and snapped to the art-pixel grid
## (Constants.SPRITE_SCALE), shrinking instead of fading.

const PARTICLE_POOL: int = 384
const NUMBER_POOL: int = 40
const BEAM_POOL: int = 32
const SWING_POOL: int = 16
const RING_POOL: int = 24
const PARTICLE_DRAG: float = 6.0
const NUMBER_TIME: float = 0.7
const NUMBER_RISE: float = 50.0
const NUMBER_FONT_SIZE: int = 18
const NUMBER_CRIT_FONT_SIZE: int = 26
const NUMBER_SPREAD_PX: float = 10.0
const COLOR_NUMBER: Color = Color(1, 1, 1)
const COLOR_NUMBER_CRIT: Color = UiStyle.C_YELLOW
const BEAM_TIME: float = 0.07
const BEAM_CORE_COLOR: Color = Color(1, 1, 1, 0.9)
const BEAM_CORE_SCALE: float = 0.4
const SWING_TIME: float = 0.18
const RING_TIME: float = 0.5
const SLAM_TIME: float = 0.4
const BLAST_ART: Texture2D = preload("res://assets/fx/blast.png")
const SLAM_ART: Texture2D = preload("res://assets/fx/slam.png")
const SLASH_ART: Texture2D = preload("res://assets/fx/slash.png")
## Art px the fireball / slam reaches and the slash arc's radius (generate.py BLAST_R, SLASH_R).
const BLAST_ART_RADIUS: float = 56.0
const SLASH_ART_RADIUS: float = 46.0


class Particle:
	var life: float = 0.0
	var max_life: float = 1.0
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var size: float = 2.0
	var color: Color = Color.WHITE


class DamageNumber:
	var life: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var text: String = ""
	var crit: bool = false


class Beam:
	var life: float = 0.0
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var width: float = 1.0
	var color: Color = Color.WHITE


class Swing:
	var life: float = 0.0
	var origin: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	var radius: float = 0.0
	var arc: float = 0.0
	var color: Color = Color.WHITE


class Ring:
	var life: float = 0.0
	var duration: float = RING_TIME
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var art: Texture2D


var _particles: Array[Particle] = []
var _numbers: Array[DamageNumber] = []
var _beams: Array[Beam] = []
var _swings: Array[Swing] = []
var _rings: Array[Ring] = []
var _pc: int = 0
var _nc: int = 0
var _bc: int = 0
var _sc: int = 0
var _rc: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i: int in PARTICLE_POOL:
		_particles.append(Particle.new())
	for i: int in NUMBER_POOL:
		_numbers.append(DamageNumber.new())
	for i: int in BEAM_POOL:
		_beams.append(Beam.new())
	for i: int in SWING_POOL:
		_swings.append(Swing.new())
	for i: int in RING_POOL:
		_rings.append(Ring.new())


## `dir` zero = all directions, else a cone of `spread` radians around it.
func burst(at: Vector2, color: Color, count: int, speed: float, size: float, life: float,
		dir: Vector2 = Vector2.ZERO, spread: float = TAU) -> void:
	for i: int in count:
		var p: Particle = _particles[_pc]
		_pc = (_pc + 1) % _particles.size()
		var angle: float = _rng.randf() * TAU if dir == Vector2.ZERO \
			else dir.angle() + _rng.randf_range(-spread, spread) * 0.5
		p.pos = at
		p.vel = Vector2.RIGHT.rotated(angle) * speed * _rng.randf_range(0.4, 1.0)
		p.max_life = life * _rng.randf_range(0.6, 1.0)
		p.life = p.max_life
		p.size = size * _rng.randf_range(0.6, 1.0)
		p.color = color


func damage_number(at: Vector2, amount: int, crit: bool) -> void:
	var n: DamageNumber = _numbers[_nc]
	_nc = (_nc + 1) % _numbers.size()
	n.life = NUMBER_TIME
	n.pos = at + Vector2(_rng.randf_range(-NUMBER_SPREAD_PX, NUMBER_SPREAD_PX), -NUMBER_SPREAD_PX)
	n.text = str(amount)
	n.crit = crit


func beam(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var b: Beam = _beams[_bc]
	_bc = (_bc + 1) % _beams.size()
	b.life = BEAM_TIME
	b.from = from
	b.to = to
	b.width = width
	b.color = color


func swing(origin: Vector2, facing: Vector2, radius: float, arc_deg: float, color: Color) -> void:
	var s: Swing = _swings[_sc]
	_sc = (_sc + 1) % _swings.size()
	s.life = SWING_TIME
	s.origin = origin
	s.angle = facing.angle()
	s.radius = radius
	s.arc = deg_to_rad(arc_deg)
	s.color = color


## Explosion (fireball) or melee slam (dust ring + cracks) sized to `radius`.
func blast(at: Vector2, radius: float, slam: bool) -> void:
	var r: Ring = _rings[_rc]
	_rc = (_rc + 1) % _rings.size()
	r.duration = SLAM_TIME if slam else RING_TIME
	r.life = r.duration
	r.pos = at
	r.radius = radius
	r.art = SLAM_ART if slam else BLAST_ART


func _process(delta: float) -> void:
	var damp: float = exp(-PARTICLE_DRAG * delta)
	for p: Particle in _particles:
		if p.life > 0.0:
			p.life -= delta
			p.pos += p.vel * delta
			p.vel *= damp
	for n: DamageNumber in _numbers:
		if n.life > 0.0:
			n.life -= delta
			n.pos.y -= NUMBER_RISE * delta
	for b: Beam in _beams:
		b.life -= delta
	for s: Swing in _swings:
		s.life -= delta
	for r: Ring in _rings:
		r.life -= delta
	queue_redraw()


func _draw() -> void:
	var px: float = Constants.SPRITE_SCALE
	for r: Ring in _rings:
		if r.life <= 0.0:
			continue
		_draw_strip(r.art, 1.0 - r.life / r.duration, r.pos, 0.0, r.radius / BLAST_ART_RADIUS, Color.WHITE)
	for s: Swing in _swings:
		if s.life <= 0.0:
			continue
		_draw_strip(SLASH_ART, 1.0 - s.life / SWING_TIME, s.origin, s.angle, s.radius / SLASH_ART_RADIUS,
			s.color.lightened(0.3))
	for b: Beam in _beams:
		if b.life <= 0.0:
			continue
		# Narrows in whole art pixels instead of fading.
		var w: float = maxf(px, snappedf(b.width * b.life / BEAM_TIME, px))
		draw_line(b.from, b.to, b.color, w)
		if w > px:
			draw_line(b.from, b.to, BEAM_CORE_COLOR, maxf(px, snappedf(w * BEAM_CORE_SCALE, px)))
	for p: Particle in _particles:
		if p.life <= 0.0:
			continue
		var size: float = maxf(px, snappedf(p.size * p.life / p.max_life, px))
		draw_rect(Rect2((p.pos / px).floor() * px - Vector2(size, size) * 0.5, Vector2(size, size)), p.color)
	for n: DamageNumber in _numbers:
		if n.life <= 0.0:
			continue
		var nc: Color = COLOR_NUMBER_CRIT if n.crit else COLOR_NUMBER
		nc.a = clampf(n.life / NUMBER_TIME * 2.0, 0.0, 1.0)
		var font_size: int = NUMBER_CRIT_FONT_SIZE if n.crit else NUMBER_FONT_SIZE
		var w: float = UiStyle.text_width(n.text, font_size, true)
		UiStyle.draw_text(self, n.pos - Vector2(w * 0.5, 0.0), n.text, font_size, nc, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


## Frame `t` (0..1) of a strip of square frames, centred on `at`, rotated and scaled.
func _draw_strip(art: Texture2D, t: float, at: Vector2, angle: float, scale_px: float, tint: Color) -> void:
	var h: float = art.get_height()
	var n: int = int(art.get_width() / h)
	var k: int = mini(int(t * n), n - 1)
	draw_set_transform(at, angle, Vector2(scale_px, scale_px))
	draw_texture_rect_region(art, Rect2(-h * 0.5, -h * 0.5, h, h), Rect2(k * h, 0, h, h), tint)
	draw_set_transform(Vector2.ZERO)
