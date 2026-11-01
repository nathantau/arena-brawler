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
## Fraction of a strip's run (at its end) over which it fades out.
const STRIP_TAIL_FADE: float = 0.15
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
## Held beams (WeaponData.held_beam): fire rolling down in segments this long, layered red / orange / yellow /
## white-hot core (width fractions), surging and flaring every frame.
const HELD_BEAM_SEGMENT: float = 10.0
const HELD_BEAM_LAYERS: Array = [[UiStyle.C_RED, 1.0], [UiStyle.C_ORANGE, 0.72], [UiStyle.C_YELLOW, 0.45],
	[UiStyle.C_WHITE, 0.2]]
const HELD_BEAM_FIRE: Array[Color] = [UiStyle.C_RED, UiStyle.C_ORANGE, UiStyle.C_YELLOW]
## Flame wisps peeling off a held beam's edges per frame, rising and cooling (yellow, orange, red) as they shrink.
const WISP_POOL: int = 128
const WISPS_PER_FRAME: int = 3
const WISP_LIFE: float = 0.5
const WISP_RISE: Vector2 = Vector2(0.0, -110.0)
const SWING_TIME: float = 0.18
const RING_TIME: float = 0.5
const SLAM_TIME: float = 0.4
const BLAST_ART: Texture2D = preload("res://assets/fx/blast.png")
const SLAM_ART: Texture2D = preload("res://assets/fx/slam.png")
const SLASH_ART: Texture2D = preload("res://assets/fx/slash.png")
## Art px the fireball / slam reaches and the slash arc's radius (generate.py BLAST_R, SLASH_R).
const BLAST_ART_RADIUS: float = 56.0
const SLASH_ART_RADIUS: float = 46.0
## Melee slams (floor cracks, dust) are drawn on this absolute z: above the floor (Arena.FLOOR_Z), under players
## and their weapons.
const GROUND_Z: int = -1


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


class Wisp:
	var life: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var size: float = 4.0


class HeldBeam:
	var shooter: Player
	var weapon: WeaponData
	var length: float = 0.0
	var life: float = 0.0


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
	## Art px from the strip's centre to the radius (BLAST_ART_RADIUS for the fireball).
	var art_radius: float = BLAST_ART_RADIUS


var _particles: Array[Particle] = []
var _numbers: Array[DamageNumber] = []
var _beams: Array[Beam] = []
var _held: Dictionary = {}  # player_id -> HeldBeam
var _wisps: Array[Wisp] = []
var _wc: int = 0
var _swings: Array[Swing] = []
var _rings: Array[Ring] = []
var _pc: int = 0
var _nc: int = 0
var _bc: int = 0
var _sc: int = 0
var _rc: int = 0
var _rng := RandomNumberGenerator.new()


var _ground := Node2D.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.z_as_relative = false
	_ground.z_index = GROUND_Z
	_ground.draw.connect(_draw_slams)
	add_child(_ground)
	for i: int in PARTICLE_POOL:
		_particles.append(Particle.new())
	for i: int in NUMBER_POOL:
		_numbers.append(DamageNumber.new())
	for i: int in BEAM_POOL:
		_beams.append(Beam.new())
	for i: int in WISP_POOL:
		_wisps.append(Wisp.new())
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


## Keeps `shooter`'s beam lit, drawn every frame from their fist along their current aim, `length` long (the last
## tick's raycast). Each damage tick renews it for two ticks, so it stays lit between them instead of flashing.
func hold_beam(shooter: Player, w: WeaponData, length: float) -> void:
	var b: HeldBeam = _held.get(shooter.player_id)
	if b == null:
		b = HeldBeam.new()
		_held[shooter.player_id] = b
	b.shooter = shooter
	b.weapon = w
	b.length = length
	b.life = w.fire_interval * 2.0


func _held_ends(b: HeldBeam) -> PackedVector2Array:
	var p: Player = b.shooter
	var from: Vector2 = p.global_position + p.visual_offset + Player.hand_offset(p.facing) \
		+ p.facing * b.weapon.muzzle_distance()
	return PackedVector2Array([from, from + p.facing * b.length])


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
	r.art_radius = BLAST_ART_RADIUS


## A weapon's own burst strip (WeaponData.burst_art), scaled so `art_radius` art px reach `radius`.
func burst_strip(at: Vector2, radius: float, art: Texture2D, art_radius: float) -> void:
	blast(at, radius, false)
	var r: Ring = _rings[(_rc + _rings.size() - 1) % _rings.size()]
	r.art = art
	r.art_radius = art_radius


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
	for id: int in _held.keys():
		var h: HeldBeam = _held[id]
		h.life -= delta
		if h.life <= 0.0 or not is_instance_valid(h.shooter) or h.shooter.dead:
			_held.erase(id)
			continue
		var ends: PackedVector2Array = _held_ends(h)
		var dir: Vector2 = h.shooter.facing
		burst(ends[1], HELD_BEAM_FIRE.pick_random(), 2, 260.0, 5.0, 0.35, -dir, 2.6)  # blaze spraying off the hit
		var along: Vector2 = ends[0].lerp(ends[1], _rng.randf())
		burst(along, HELD_BEAM_FIRE.pick_random(), 1, 140.0, 4.0, 0.3, dir.orthogonal() * signf(_rng.randf() - 0.5), 0.8)
		for k: int in WISPS_PER_FRAME:  # wisps peeling off its edges
			var side: Vector2 = dir.orthogonal() * signf(_rng.randf() - 0.5) * h.weapon.projectile_radius * 0.8
			var w: Wisp = _wisps[_wc]
			_wc = (_wc + 1) % _wisps.size()
			w.life = WISP_LIFE * _rng.randf_range(0.6, 1.0)
			w.pos = ends[0].lerp(ends[1], _rng.randf()) + side
			w.vel = WISP_RISE * _rng.randf_range(0.6, 1.2) + side * 2.0 + dir * _rng.randf_range(-30.0, 30.0)
			w.size = _rng.randf_range(4.0, 8.0)
	for w: Wisp in _wisps:
		if w.life > 0.0:
			w.life -= delta
			w.pos += w.vel * delta
	for s: Swing in _swings:
		s.life -= delta
	for r: Ring in _rings:
		r.life -= delta
	queue_redraw()
	_ground.queue_redraw()


func _draw() -> void:
	var px: float = Constants.SPRITE_SCALE
	for r: Ring in _rings:
		if r.life > 0.0 and r.art != SLAM_ART:
			_draw_strip(self, r.art, 1.0 - r.life / r.duration, r.pos, 0.0, r.radius / r.art_radius, Color.WHITE)
	for s: Swing in _swings:
		if s.life <= 0.0:
			continue
		_draw_strip(self, SLASH_ART, 1.0 - s.life / SWING_TIME, s.origin, s.angle, s.radius / SLASH_ART_RADIUS,
			s.color.lightened(0.3))
	for b: Beam in _beams:
		if b.life <= 0.0:
			continue
		# Narrows in whole art pixels instead of fading.
		var w: float = maxf(px, snappedf(b.width * b.life / BEAM_TIME, px))
		draw_line(b.from, b.to, b.color, w)
		if w > px:
			draw_line(b.from, b.to, BEAM_CORE_COLOR, maxf(px, snappedf(w * BEAM_CORE_SCALE, px)))
	_draw_held_beams(px)
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


func _draw_slams() -> void:
	for r: Ring in _rings:
		if r.life > 0.0 and r.art == SLAM_ART:
			_draw_strip(_ground, r.art, 1.0 - r.life / r.duration, r.pos, 0.0, r.radius / r.art_radius, Color.WHITE)


## Frame `t` (0..1) of a strip of square frames, centred on `at`, rotated and scaled, drawn on `ci`.
func _draw_strip(ci: CanvasItem, art: Texture2D, t: float, at: Vector2, angle: float, scale_px: float,
		tint: Color) -> void:
	var h: float = art.get_height()
	var n: int = int(art.get_width() / h)
	var k: int = mini(int(t * n), n - 1)
	ci.draw_set_transform(at, angle, Vector2(scale_px, scale_px))
	tint.a *= clampf((1.0 - t) / STRIP_TAIL_FADE, 0.0, 1.0)  # the last sparks ease out instead of vanishing
	ci.draw_texture_rect_region(art, Rect2(-h * 0.5, -h * 0.5, h, h), Rect2(k * h, 0, h, h), tint)
	ci.draw_set_transform(Vector2.ZERO)


func _draw_held_beams(px: float) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	for h: HeldBeam in _held.values():
		var ends: PackedVector2Array = _held_ends(h)
		var dir: Vector2 = h.shooter.facing
		var base: float = h.weapon.projectile_radius * 2.0
		var n: int = maxi(1, ceili(h.length / HELD_BEAM_SEGMENT))
		var pulse: float = 1.0 + 0.15 * sin(time * 30.0)
		for layer: Array in HELD_BEAM_LAYERS:
			var color: Color = layer[0]
			for i: int in n:
				# surges of fire rolling down the beam, in whole art pixels
				var surge: float = 1.0 + 0.22 * sin(time * 40.0 - i * 1.3) + 0.12 * sin(time * 67.0 + i * 2.9)
				var w: float = maxf(px, snappedf(base * layer[1] * surge, px))
				draw_line(ends[0] + dir * (h.length * i / n), ends[0] + dir * (h.length * (i + 1) / n), color, w)
			draw_circle(ends[0], maxf(px, snappedf(base * 0.6 * layer[1] * pulse, px)), color)  # flare at the fist
			draw_circle(ends[1], maxf(px, snappedf(base * 0.8 * layer[1] * (2.0 - pulse), px)), color)  # blaze at the hit
	for w: Wisp in _wisps:  # little flames rising off it: a teardrop pointing up, shrinking and cooling
		if w.life <= 0.0:
			continue
		var f: float = w.life / WISP_LIFE
		var r: float = maxf(px, snappedf(w.size * f, px))
		var at: Vector2 = (w.pos / px).floor() * px
		draw_colored_polygon(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(0, -r * 2.5), at + Vector2(r, 0),
			at + Vector2(0, r)]), UiStyle.C_YELLOW if f > 0.66 else UiStyle.C_ORANGE if f > 0.33 else UiStyle.C_RED)
