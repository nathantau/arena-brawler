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
const COLOR_NUMBER_HEAL: Color = Color8(150, 224, 96)
const BEAM_TIME: float = 0.07
const BEAM_CORE_COLOR: Color = Color(1, 1, 1, 0.9)
const BEAM_CORE_SCALE: float = 0.4
## Held beams (WeaponData.held_beam): fire rolling down in segments this long, layered red / orange / yellow /
## white-hot core (width fractions), surging and flaring every frame.
const HELD_BEAM_SEGMENT: float = 10.0
const HELD_BEAM_LAYERS: Array = [[UiStyle.C_RED, 1.0], [UiStyle.C_ORANGE, 0.72], [UiStyle.C_YELLOW, 0.45],
	[UiStyle.C_WHITE, 0.2]]
const HELD_BEAM_FIRE: Array[Color] = [UiStyle.C_RED, UiStyle.C_ORANGE, UiStyle.C_YELLOW]
## Lightning beams (WeaponData.lightning), all drawn as art-pixel rects: a white-hot jagged core (yellow edge) that re-rolls
## LIGHTNING_HZ times a second (seeded by the beam's age, so a frame is stable), two thinner arcs braiding round it, forks that
## retract, a dithered cyan / blue glow band, a crackling orb at the hand and a splash + scorch ring where it lands. It grows out
## of the hand over LIGHTNING_GROW and fizzles out over LIGHTNING_END (the hand's start-up flash lasts LIGHTNING_CHARGE).
const LIGHTNING_STEP: float = 14.0
const LIGHTNING_JITTER: float = 8.0
const LIGHTNING_HZ: float = 24.0
const LIGHTNING_GROW: float = 0.1
const LIGHTNING_END: float = 0.22
const LIGHTNING_CHARGE: float = 0.18
const LIGHTNING_SPARK_SPEED: float = 190.0
const LIGHTNING_SPARK_SIZE: float = 4.0
const LIGHTNING_SPARK_LIFE: float = 0.26
const LIGHTNING_BLUE: Color = Color8(60, 111, 209)
const LIGHTNING_CYAN: Color = UiStyle.C_TEAL_L
## Chain lightning (Arc Zapper): a short jagged arc between two fighters, built from the lightning beam's pieces.
const ARC_POOL: int = 12
const ARC_TIME: float = 0.2
const ARC_JITTER: float = 7.0
const ARC_SPARKS: int = 5
## Parry flash (Arc Blade): a ring flaring out from the contact point behind a four-point glint.
const FLASH_POOL: int = 8
const FLASH_TIME: float = 0.22
const FLASH_RADIUS: float = 30.0
const FLASH_RAYS: float = 26.0
const FLASH_SPARKS: int = 8
## Embers shed by a burning fighter (Ember Palm).
const EMBER_COLORS: Array[Color] = [UiStyle.C_YELLOW, UiStyle.C_ORANGE, UiStyle.C_RED]
const EMBER_COUNT: int = 2
const EMBER_SPREAD_X: float = 14.0
const EMBER_SPREAD_Y: float = 16.0
const EMBER_SPEED: float = 90.0
const EMBER_SIZE: float = 6.0
const EMBER_LIFE: float = 0.6
## Flame wisps peeling off a held beam's edges per frame, rising and cooling (yellow, orange, red) as they shrink.
const WISP_POOL: int = 128
const WISPS_PER_FRAME: int = 3
const WISP_LIFE: float = 0.5
const WISP_RISE: Vector2 = Vector2(0.0, -110.0)
const SWING_TIME: float = 0.18
## Thrust trail (Cloud Staff): rides the staff itself for this long, easing in over the first THRUST_IN of it and
## out over the rest; the staff is THRUST_LEN art px long from the grip to the tip.
const THRUST_TIME: float = 0.24
const THRUST_IN: float = 0.3
const THRUST_LEN: float = 41.0
const THRUST_GOLD: Color = Color8(255, 226, 120)
const THRUST_ORANGE: Color = Color8(240, 150, 60)
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
const SPAWN_RING_TIME: float = 0.55
const SPAWN_RING_RADIUS: float = 62.0
const SPAWN_RING_SQUASH: float = 0.5
const SPAWN_SPARKLES: int = 12
const SPAWN_SPARKLE_SPEED: float = 260.0
const SPAWN_SPARKLE_LIFE: float = 0.6
const PARTICLE_SPARKLE: float = 4.0
## Hit marker: four ticks around the victim that spread out and shrink; bigger and gold on crits and kills.
const MARKER_POOL: int = 8
const MARKER_TIME: float = 0.18
const MARKER_SIZE: float = 20.0
const MARKER_GAP: float = 14.0
## Auto-aim reticle: four corner brackets that ease in and tighten around the locked target, then pulse gently.
const AIM_HALF: float = 24.0  ## half side of the bracket box around a normal-sized fighter
const AIM_LEG: float = 8.0
const AIM_EASE_TIME: float = 0.22
const AIM_START_SPREAD: float = 1.0  ## extra box size at the moment of locking (x AIM_HALF)
const AIM_PULSE: float = 2.0
const COLOR_AIM: Color = UiStyle.C_YELLOW
## Damage numbers pop to this scale as they appear.
const NUMBER_POP_TIME: float = 0.12
const NUMBER_POP_SCALE: float = 1.45


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
	var heal: bool = false
	var tinted: bool = false
	var color: Color = Color.WHITE


class Marker:
	var life: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var strong: bool = false


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
	var age: float = 0.0  ## seconds since it lit (lightning: drives growth, jitter seeds)
	var ending: bool = false  ## lightning only: no longer renewed, fizzling out
	var end_t: float = 0.0


class Arc:
	var life: float = 0.0
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var seed: int = 0


class Flash:
	var life: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var color: Color = Color.WHITE


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


class Thrust:
	var life: float = 0.0
	var shooter: Player


class Ring:
	var life: float = 0.0
	var duration: float = RING_TIME
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var art: Texture2D
	## Art px from the strip's centre to the radius (BLAST_ART_RADIUS for the fireball).
	var art_radius: float = BLAST_ART_RADIUS
	## art == null: a plain expanding floor ring in this colour (spawn pop).
	var color: Color = Color.WHITE


var _particles: Array[Particle] = []
var _numbers: Array[DamageNumber] = []
var _beams: Array[Beam] = []
var _arcs: Array[Arc] = []
var _flashes: Array[Flash] = []
var _fc: int = 0
var _ac: int = 0
var _thrusts: Array[Thrust] = []
var _held: Dictionary = {}  # player_id -> HeldBeam
var _wisps: Array[Wisp] = []
var _wc: int = 0
var _markers: Array[Marker] = []
var _mc: int = 0
## World position of the auto-aim reticle (Vector2.INF = hidden); set by the Arena every frame.
var aim_marker: Vector2 = Vector2.INF
## Size of the locked target relative to a normal fighter (form_scale), set with `aim_marker`.
var aim_scale: float = 1.0
var _aim_prev: Vector2 = Vector2.INF
var _aim_since: float = 0.0
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
	for i: int in ARC_POOL:
		_arcs.append(Arc.new())
	for i: int in FLASH_POOL:
		_flashes.append(Flash.new())
	for i: int in 8:
		_thrusts.append(Thrust.new())
	for i: int in MARKER_POOL:
		_markers.append(Marker.new())
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


## Drop everything in flight (new match, back to the lobby) so nothing from the last round lingers.
func clear() -> void:
	for p: Particle in _particles:
		p.life = 0.0
	for n: DamageNumber in _numbers:
		n.life = 0.0
	for b: Beam in _beams:
		b.life = 0.0
	for w: Wisp in _wisps:
		w.life = 0.0
	for s: Swing in _swings:
		s.life = 0.0
	for t: Thrust in _thrusts:
		t.life = 0.0
	for r: Ring in _rings:
		r.life = 0.0
	for m: Marker in _markers:
		m.life = 0.0
	_held.clear()


func hit_marker(at: Vector2, strong: bool) -> void:
	var m: Marker = _markers[_mc]
	_mc = (_mc + 1) % _markers.size()
	m.life = MARKER_TIME
	m.pos = at
	m.strong = strong


func damage_number(at: Vector2, amount: int, crit: bool) -> void:
	var n: DamageNumber = _numbers[_nc]
	_nc = (_nc + 1) % _numbers.size()
	n.life = NUMBER_TIME
	n.pos = at + Vector2(_rng.randf_range(-NUMBER_SPREAD_PX, NUMBER_SPREAD_PX), -NUMBER_SPREAD_PX)
	n.text = str(amount)
	n.crit = crit
	n.heal = false
	n.tinted = false


## A floating label in `color` (pickup "+80").
func label_number(at: Vector2, text: String, color: Color) -> void:
	damage_number(at, 0, false)
	var n: DamageNumber = _numbers[(_nc + _numbers.size() - 1) % _numbers.size()]
	n.text = text
	n.color = color
	n.tinted = true


## Respawn pop on the floor at `feet`: a ring swelling out, sparkles flying up and a few motes in the player's colour.
func spawn_pop(feet: Vector2, color: Color) -> void:
	var r: Ring = _rings[_rc]
	_rc = (_rc + 1) % _rings.size()
	r.duration = SPAWN_RING_TIME
	r.life = r.duration
	r.pos = feet
	r.radius = SPAWN_RING_RADIUS
	r.art = null
	r.color = color
	burst(feet, Color.WHITE, SPAWN_SPARKLES, SPAWN_SPARKLE_SPEED, PARTICLE_SPARKLE, SPAWN_SPARKLE_LIFE, Vector2.UP, 2.4)
	burst(feet, color.lightened(0.4), SPAWN_SPARKLES, SPAWN_SPARKLE_SPEED * 0.6, PARTICLE_SPARKLE, SPAWN_SPARKLE_LIFE)


## A small green "+N" where something was healed.
func heal_number(at: Vector2, amount: int) -> void:
	damage_number(at, amount, false)
	var n: DamageNumber = _numbers[(_nc + _numbers.size() - 1) % _numbers.size()]
	n.text = "+%d" % amount
	n.heal = true


## Chain lightning leaping from `from` to `to`, with sparks where it lands.
func chain_arc(from: Vector2, to: Vector2, color: Color) -> void:
	var a: Arc = _arcs[_ac]
	_ac = (_ac + 1) % _arcs.size()
	a.life = ARC_TIME
	a.from = from
	a.to = to
	a.seed = _rng.randi()
	burst(to, color.lerp(UiStyle.C_WHITE, 0.5), ARC_SPARKS, LIGHTNING_SPARK_SPEED, LIGHTNING_SPARK_SIZE, LIGHTNING_SPARK_LIFE)


## A bright deflect flash where a parry met a shot.
func deflect(at: Vector2, color: Color) -> void:
	var f: Flash = _flashes[_fc]
	_fc = (_fc + 1) % _flashes.size()
	f.life = FLASH_TIME
	f.pos = at
	f.color = color
	burst(at, color.lerp(UiStyle.C_WHITE, 0.6), FLASH_SPARKS, LIGHTNING_SPARK_SPEED, LIGHTNING_SPARK_SIZE, LIGHTNING_SPARK_LIFE)


## A single ember rising off a burning fighter at `at`.
func ember(at: Vector2) -> void:
	for i: int in EMBER_COUNT:
		var from: Vector2 = at + Vector2(_rng.randf_range(-EMBER_SPREAD_X, EMBER_SPREAD_X), _rng.randf_range(-EMBER_SPREAD_Y, EMBER_SPREAD_Y))
		burst(from, EMBER_COLORS[_rng.randi() % EMBER_COLORS.size()], 1, EMBER_SPEED, EMBER_SIZE, EMBER_LIFE, Vector2.UP, 0.9)


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
	if w.lightning:
		if b.ending:  # renewed mid-fizzle: pick up where it is
			b.ending = false
			b.end_t = 0.0
		elif b.age == 0.0:  # just lit: the screen feels the zap
			var arena := get_parent() as Arena
			if arena != null and arena.local_player == shooter:
				arena.add_shake(0.08)
		var at: Vector2 = _held_ends(b)[1]  # a pop of sparks at the end every tick
		burst(at, LIGHTNING_CYAN, 2, LIGHTNING_SPARK_SPEED, LIGHTNING_SPARK_SIZE, LIGHTNING_SPARK_LIFE)
		burst(at, UiStyle.C_WHITE, 1, LIGHTNING_SPARK_SPEED * 0.6, LIGHTNING_SPARK_SIZE, LIGHTNING_SPARK_LIFE)


func _held_ends(b: HeldBeam) -> PackedVector2Array:
	var p: Player = b.shooter
	var from: Vector2 = p.global_position + p.visual_offset + Player.hand_offset(p.facing) \
		+ p.facing * b.weapon.muzzle_distance()
	return PackedVector2Array([from, from + p.facing * b.length])


## A stab with a staff: a gold streak and tip glint that ride the staff (they follow the shooter every frame).
func thrust(shooter: Player) -> void:
	for t: Thrust in _thrusts:
		if t.life <= 0.0:
			t.life = THRUST_TIME
			t.shooter = shooter
			return


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
	for a: Arc in _arcs:
		a.life -= delta
	for f: Flash in _flashes:
		f.life -= delta
	for id: int in _held.keys():
		var h: HeldBeam = _held[id]
		h.life -= delta
		h.age += delta
		if not is_instance_valid(h.shooter) or h.shooter.dead:
			_held.erase(id)
			continue
		if h.weapon.lightning:
			_lightning_sparks(h, delta)
			if h.life <= 0.0 and not h.ending:
				h.ending = true
				h.end_t = 0.0
			if h.ending:
				h.end_t += delta
				if h.end_t >= LIGHTNING_END:
					_held.erase(id)
			continue
		if h.life <= 0.0:
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
	for t: Thrust in _thrusts:
		t.life -= delta
	for r: Ring in _rings:
		r.life -= delta
	for m: Marker in _markers:
		m.life -= delta
	queue_redraw()
	_ground.queue_redraw()


func _draw() -> void:
	var px: float = Constants.SPRITE_SCALE
	for r: Ring in _rings:
		if r.life > 0.0 and r.art != SLAM_ART and r.art != null:
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
	for t: Thrust in _thrusts:
		if t.life > 0.0 and is_instance_valid(t.shooter):
			_draw_thrust(t, px)
	for a: Arc in _arcs:
		if a.life > 0.0:
			_draw_arc(a, px)
	for f: Flash in _flashes:
		if f.life > 0.0:
			_draw_flash(f, px)
	_draw_held_beams(px)
	_draw_aim_marker(px)
	for p: Particle in _particles:
		if p.life <= 0.0:
			continue
		var size: float = maxf(px, snappedf(p.size * p.life / p.max_life, px))
		draw_rect(Rect2((p.pos / px).floor() * px - Vector2(size, size) * 0.5, Vector2(size, size)), p.color)
	_draw_markers(px)
	for n: DamageNumber in _numbers:
		if n.life <= 0.0:
			continue
		var nc: Color = n.color if n.tinted else COLOR_NUMBER_HEAL if n.heal else COLOR_NUMBER_CRIT if n.crit else COLOR_NUMBER
		nc.a = clampf(n.life / NUMBER_TIME * 2.0, 0.0, 1.0)
		var font_size: int = NUMBER_CRIT_FONT_SIZE if n.crit else NUMBER_FONT_SIZE
		var age: float = NUMBER_TIME - n.life
		if age < NUMBER_POP_TIME:  # punch in: starts big and settles
			font_size = roundi(font_size * lerpf(NUMBER_POP_SCALE, 1.0, age / NUMBER_POP_TIME))
		var w: float = UiStyle.text_width(n.text, font_size, true)
		UiStyle.draw_text(self, n.pos - Vector2(w * 0.5, 0.0), n.text, font_size, nc, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


func _draw_slams() -> void:
	for r: Ring in _rings:
		if r.life > 0.0 and r.art == null:
			var k: float = 1.0 - r.life / r.duration
			var c: Color = r.color
			c.a = (1.0 - k) * 0.9
			var rad: float = r.radius * (1.0 - pow(1.0 - k, 2.0))
			_ground.draw_set_transform(r.pos, 0.0, Vector2(1.0, SPAWN_RING_SQUASH))
			_ground.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 40, c, 4.0 * (1.0 - k) + 1.0)
			c = Color.WHITE
			c.a = (1.0 - k) * 0.5
			_ground.draw_arc(Vector2.ZERO, rad * 0.65, 0.0, TAU, 40, c, 2.0)
			_ground.draw_set_transform(Vector2.ZERO)
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


func _snap_rect(at: Vector2, size: float, color: Color) -> void:
	draw_rect(Rect2((at / size).floor() * size - Vector2(size, size) * 0.5, Vector2(size, size)), color)


## Streak along the staff's own axis (so it sits on the staff, mirrored with the facing): a tapered gold wedge from
## where the stab started out to the tip, then a four-point glint at the tip. Eases in then out over several frames.
func _draw_thrust(t: Thrust, px: float) -> void:
	var p: Player = t.shooter
	var u: float = 1.0 - t.life / THRUST_TIME
	var env: float = smoothstep(0.0, THRUST_IN, u) * (1.0 - smoothstep(THRUST_IN, 1.0, u))
	if env <= 0.02:
		return
	var dir: Vector2 = p.facing
	var base: Vector2 = p.global_position + p.visual_offset + Player.hand_offset(dir)
	var tip_len: float = THRUST_LEN * px
	var hold: float = p.thrust_hold()
	var tip: Vector2 = base + dir * (hold + tip_len)
	var tail: Vector2 = base + dir * (tip_len * 0.15)  # the streak starts back on the shaft and runs out past the tip
	var side: Vector2 = dir.orthogonal()
	var steps: int = int(tail.distance_to(tip) / px)
	for i: int in steps:
		var k: float = float(i) / maxf(1.0, steps - 1.0)  # 0 at the tail, 1 at the tip
		var half: int = roundi(lerpf(0.0, 3.0, k) * env)  # whole art pixels either side of the axis
		var at: Vector2 = tail.lerp(tip, k)
		var col: Color = THRUST_ORANGE if k < 0.5 else THRUST_GOLD
		col.a = env * lerpf(0.45, 1.0, k)
		for j: int in range(-half, half + 1):
			_snap_rect(at + side * (j * px), px, col)
		if half > 0:
			_snap_rect(at, px, Color(1, 1, 1, env * k))
	var r: int = roundi(4.0 * env)  # tip glint: a plus
	for j: int in range(1, r + 1):
		var c: Color = THRUST_GOLD if j < r else THRUST_ORANGE
		c.a = env
		for d: Vector2 in [dir, -dir, side, -side]:
			_snap_rect(tip + d * (j * px), px, c)
	_snap_rect(tip, px, Color(1, 1, 1, env))


func _draw_held_beams(px: float) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	for h: HeldBeam in _held.values():
		var ends: PackedVector2Array = _held_ends(h)
		if h.weapon.lightning:
			_draw_lightning_beam(h, ends, px)
			continue
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


## Per-frame sparks off a lightning beam: scattering from where it lands, popping off the hand, and trailing along it as it fizzles.
func _lightning_sparks(h: HeldBeam, delta: float) -> void:
	var ends: PackedVector2Array = _held_ends(h)
	var dir: Vector2 = h.shooter.facing
	var cols: Array[Color] = [UiStyle.C_WHITE, UiStyle.C_YELLOW, LIGHTNING_CYAN]
	if h.ending:
		for i: int in 2:
			burst(ends[0].lerp(ends[1], _rng.randf()), cols.pick_random(), 1, 150.0, 3.0, 0.3)
		return
	if _lightning_hit(h) and _rng.randf() < 60.0 * delta * 0.6:
		burst(ends[1], cols.pick_random(), 1, LIGHTNING_SPARK_SPEED, LIGHTNING_SPARK_SIZE, LIGHTNING_SPARK_LIFE, -dir, 3.2)
	if _rng.randf() < 60.0 * delta * 0.25:
		burst(ends[0], cols.pick_random(), 1, 110.0, 3.0, 0.2)


func _lightning_hit(h: HeldBeam) -> bool:
	return h.length < h.weapon.projectile_range - 2.0


## The enemy the beam is on, if its end is on one (the arcs crawl over them).
func _lightning_target(h: HeldBeam, at: Vector2) -> Player:
	var arena := get_parent() as Arena
	if arena == null:
		return null
	for p: Player in arena.players:
		if not h.shooter.is_ally(p) and not p.dead and (p.global_position + p.visual_offset).distance_to(at) < Constants.PLAYER_RADIUS + 10.0:
			return p
	return null


## Rects of `size` art px along a -> b (one per art px of length), snapped to the art-pixel grid.
func _pline(a: Vector2, b: Vector2, color: Color, size: int, px: float) -> void:
	var n: int = maxi(1, ceili(a.distance_to(b) / px))
	var half: float = floorf(size * 0.5) * px
	var sz := Vector2(size * px, size * px)
	for i: int in n + 1:
		var at: Vector2 = a.lerp(b, float(i) / n)
		draw_rect(Rect2((at / px).floor() * px - Vector2(half, half), sz), color)


func _ppoly(pts: PackedVector2Array, color: Color, size: int, px: float, from_i: int = 0) -> void:
	for i: int in range(from_i, pts.size() - 1):
		_pline(pts[i], pts[i + 1], color, size, px)


## A filled pixel disc (r in art px); `dither` keeps only a checkerboard of it.
func _pdisc(c: Vector2, r: float, color: Color, px: float, dither: bool = false) -> void:
	var o: Vector2 = (c / px).floor()
	var ri: int = ceili(r)
	for dy: int in range(-ri, ri + 1):
		for dx: int in range(-ri, ri + 1):
			if dx * dx + dy * dy <= r * r and (not dither or (dx + dy) & 1 == 0):
				draw_rect(Rect2((o + Vector2(dx, dy)) * px, Vector2(px, px)), color)


## A one-art-pixel ring (a floor shockwave), flattened vertically like the top-down floor.
func _pring(c: Vector2, r: float, color: Color, px: float, dither: bool) -> void:
	var o: Vector2 = (c / px).floor()
	var ri: int = ceili(r)
	for dy: int in range(-ri, ri + 1):
		for dx: int in range(-ri, ri + 1):
			var d: float = Vector2(dx, dy * 1.5).length()
			if absf(d - r) < 0.75 and (not dither or (dx + dy) & 1 == 0):
				draw_rect(Rect2((o + Vector2(dx, dy)) * px, Vector2(px, px)), color)


## Short crackling spikes round a point (re-rolled per `rng`), a white tip on a cyan stem.
func _pspikes(c: Vector2, count: int, reach_min: float, reach_max: float, rng: RandomNumberGenerator, px: float,
		base: float = 0.0, spread: float = TAU) -> void:
	for i: int in count:
		var a: float = base + rng.randf_range(-spread, spread) * 0.5
		var len_px: float = rng.randf_range(reach_min, reach_max)
		var mid: Vector2 = c + Vector2.RIGHT.rotated(a + rng.randf_range(-0.5, 0.5)) * len_px * 0.5
		var tip: Vector2 = c + Vector2.RIGHT.rotated(a) * len_px
		_pline(c, mid, LIGHTNING_CYAN, 1, px)
		_pline(mid, tip, UiStyle.C_WHITE if rng.randf() < 0.6 else UiStyle.C_YELLOW, 1, px)


## Lightning beam, drawn from the hand every frame along the shooter's current aim (so it follows aim, mirroring and
## interpolation) out to the last tick's raycast length (so it stops exactly where the damage does).
func _draw_lightning_beam(h: HeldBeam, ends: PackedVector2Array, px: float) -> void:
	var dir: Vector2 = h.shooter.facing
	var side: Vector2 = dir.orthogonal()
	var grow: float = clampf(h.age / LIGHTNING_GROW, 0.0, 1.0)
	var out_k: float = clampf(h.end_t / LIGHTNING_END, 0.0, 1.0) if h.ending else 0.0
	var reach: float = h.length * (1.0 - pow(1.0 - grow, 3.0))
	var hand: Vector2 = ends[0]
	var tip: Vector2 = hand + dir * reach
	var life_k: float = 1.0 - out_k  # thins to nothing while fizzling
	var tick: int = int(h.age * LIGHTNING_HZ)
	var frac: float = h.age * LIGHTNING_HZ - tick  # 0 -> 1 within a jitter tick
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([h.shooter.player_id, tick])
	var n: int = maxi(2, ceili(reach / LIGHTNING_STEP))
	var base: PackedVector2Array = PackedVector2Array()
	var pts := PackedVector2Array([hand])
	for i: int in range(1, n):
		var taper: float = pow(sin(PI * float(i) / n), 0.7)
		var b: Vector2 = hand + dir * (reach * i / n)
		base.append(b)
		pts.append(b + side * rng.randf_range(-1.0, 1.0) * LIGHTNING_JITTER * taper)
	pts.append(tip)
	var start_i: int = int(out_k * (pts.size() - 1))  # the fizzle eats the beam from the hand outwards
	if out_k > 0.0 and (int(h.end_t * 40.0) & 1) == 1 and out_k < 0.85:
		start_i = mini(pts.size() - 2, start_i + 1)  # stutter
	# 1. glow band: dithered blue, then cyan nearer the core, widening as it grows
	var glow_r: int = int(round(6.0 * life_k * (1.0 + 0.12 * sin(h.age * 50.0))))
	var samples: PackedVector2Array = PackedVector2Array()
	for i: int in range(start_i, pts.size() - 1):
		var a: Vector2 = pts[i]
		var steps: int = maxi(1, ceili(a.distance_to(pts[i + 1]) / px))
		for k: int in steps:
			samples.append(a.lerp(pts[i + 1], float(k) / steps))
	for sp: Vector2 in samples:
		for k: int in range(-glow_r, glow_r + 1):
			var cell: Vector2 = ((sp + side * k * px) / px).floor()
			var checker: bool = (int(cell.x) + int(cell.y)) & 1 == 0
			if absi(k) <= 2:
				if checker or absi(k) <= 1:
					draw_rect(Rect2(cell * px, Vector2(px, px)), LIGHTNING_CYAN if absi(k) <= 1 else LIGHTNING_BLUE)
			elif checker and (absi(k) < glow_r or (int(cell.x) & 1) == 0):
				draw_rect(Rect2(cell * px, Vector2(px, px)), LIGHTNING_BLUE)
	# 2. two thinner arcs braiding round the core, a half tick out of step with it
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = hash([h.shooter.player_id, int(h.age * LIGHTNING_HZ + 0.5), 7])
	for arc: int in 2:
		var ap := PackedVector2Array([hand])
		var ph: float = h.age * 38.0 + arc * PI
		for i: int in base.size():
			var taper: float = pow(sin(PI * float(i + 1) / n), 0.7)
			var off: float = (sin(ph + i * 1.15) * 8.0 + rng2.randf_range(-2.5, 2.5)) * taper * life_k
			ap.append(base[i] + side * off)
		ap.append(tip)
		_ppoly(ap, LIGHTNING_CYAN if arc == 0 else UiStyle.C_WHITE, 2 if arc == 0 else 1, px, mini(start_i, ap.size() - 2))
	# 3. forks that branch off and fade (retracting) over the tick
	if out_k < 0.5 and pts.size() > 4:
		var forks: int = rng.randi_range(0, 2)
		for f: int in forks:
			var ri: int = rng.randi_range(2, pts.size() - 2)
			var a: float = dir.angle() + rng.randf_range(0.45, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var segs: int = rng.randi_range(3, 6)
			var shown: int = maxi(1, ceili(segs * (1.0 - 0.7 * frac)))
			var fk := PackedVector2Array([pts[ri]])
			for k: int in shown:
				a += rng.randf_range(-0.55, 0.55)
				fk.append(fk[fk.size() - 1] + Vector2.RIGHT.rotated(a) * 9.0)
			_ppoly(fk, UiStyle.C_YELLOW, 1, px)
			_pline(fk[fk.size() - 2], fk[fk.size() - 1], UiStyle.C_WHITE, 1, px)
	# 4. the core: a yellow edge round a white-hot line
	var wide: int = 3 if life_k > 0.4 else 1
	_ppoly(pts, UiStyle.C_YELLOW, wide, px, start_i)
	_ppoly(pts, UiStyle.C_WHITE, 2 if (tick & 3) != 0 else 1, px, start_i)
	# 5. the end of the beam
	if reach >= h.length * 0.98 and out_k < 0.9:
		_lightning_impact(h, ends[1], tip, dir, rng, frac, px, life_k)
	elif grow < 1.0:  # still growing: a bright head
		_pdisc(tip, 2.0, UiStyle.C_WHITE, px)
		_pdisc(tip, 3.5, LIGHTNING_CYAN, px, true)
	# 6. the hand: start-up flash, then a crackling orb
	_lightning_orb(h, hand, rng, px, life_k)


func _draw_flash(f: Flash, px: float) -> void:
	var k: float = 1.0 - f.life / FLASH_TIME
	var ring := PackedVector2Array()
	for i: int in 17:
		ring.append(f.pos + Vector2.RIGHT.rotated(TAU * i / 16.0) * lerpf(6.0, FLASH_RADIUS, 1.0 - pow(1.0 - k, 2.0)))
	_ppoly(ring, f.color, 2 if k < 0.6 else 1, px)
	_ppoly(ring, UiStyle.C_WHITE if k < 0.4 else f.color, 1, px)
	var ray: float = FLASH_RAYS * (1.0 - k)
	for d: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:  # a four-point glint
		_pline(f.pos, f.pos + d * ray, UiStyle.C_WHITE, 2 if k < 0.5 else 1, px)
	_pdisc(f.pos, 4.0 * (1.0 - k) + 1.0, UiStyle.C_WHITE, px)


## The same layers as the lightning beam (dithered glow, yellow edge, white-hot core), re-rolled LIGHTNING_HZ times a second,
## thinning out as the arc dies.
func _draw_arc(a: Arc, px: float) -> void:
	var k: float = a.life / ARC_TIME
	var dir: Vector2 = (a.to - a.from).normalized()
	var side: Vector2 = dir.orthogonal()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([a.seed, int((1.0 - k) * ARC_TIME * LIGHTNING_HZ)])
	var n: int = maxi(2, ceili(a.from.distance_to(a.to) / LIGHTNING_STEP))
	var pts := PackedVector2Array([a.from])
	for i: int in range(1, n):
		var taper: float = pow(sin(PI * float(i) / n), 0.7)
		pts.append(a.from.lerp(a.to, float(i) / n) + side * rng.randf_range(-1.0, 1.0) * ARC_JITTER * taper)
	pts.append(a.to)
	_ppoly(pts, LIGHTNING_BLUE, 5 if k > 0.5 else 3, px)
	_ppoly(pts, LIGHTNING_CYAN, 3, px)
	_ppoly(pts, UiStyle.C_YELLOW, 2, px)
	_ppoly(pts, UiStyle.C_WHITE, 1, px)
	_pdisc(a.to, 2.0 + 2.0 * k, UiStyle.C_WHITE, px)
	_pdisc(a.to, 4.0 * k + 1.0, LIGHTNING_CYAN, px, true)


func _lightning_orb(h: HeldBeam, hand: Vector2, rng: RandomNumberGenerator, px: float, life_k: float) -> void:
	var charge: float = clampf(1.0 - h.age / LIGHTNING_CHARGE, 0.0, 1.0)  # 1 -> 0 over the start-up
	var r: float = (4.0 + rng.randf_range(0.0, 1.2) + charge * 4.0) * (0.4 + 0.6 * life_k)
	_pdisc(hand, r + 1.5, LIGHTNING_BLUE, px, true)
	_pdisc(hand, r + 0.5, LIGHTNING_CYAN, px)
	_pdisc(hand, r - 0.8, UiStyle.C_WHITE if charge > 0.0 or rng.randf() < 0.7 else UiStyle.C_YELLOW, px)
	_pspikes(hand, 4 + int(charge * 4.0), 7.0 + charge * 10.0, 12.0 + charge * 14.0, rng, px)
	if charge > 0.0:  # crackling ring expanding off the flash
		_pring(hand, 4.0 + (1.0 - charge) * 9.0, UiStyle.C_WHITE, px, false)


## Splash where the beam lands (rays, bright core, scorch ring on the floor) and arcs crawling over an enemy it's on.
func _lightning_impact(h: HeldBeam, at: Vector2, tip: Vector2, dir: Vector2, rng: RandomNumberGenerator,
		frac: float, px: float, life_k: float) -> void:
	if not _lightning_hit(h):
		_pdisc(tip, 2.5 * life_k, LIGHTNING_CYAN, px, true)  # fires into open air: a fading tip
		_pdisc(tip, 1.5 * life_k, UiStyle.C_WHITE, px)
		return
	var scorch: float = 6.0 + 2.0 * life_k
	_pdisc(tip, scorch, UiStyle.C_OUTLINE, px, true)  # scorch mark, dithered dark
	_pring(tip, 5.0 + frac * 8.0, LIGHTNING_CYAN if frac < 0.6 else LIGHTNING_BLUE, px, frac > 0.3)  # shockwave ring
	_pspikes(tip, 9, 12.0, 28.0, rng, px, (-dir).angle(), 3.8)  # splash scattering back off the hit
	_pdisc(tip, (4.0 + rng.randf_range(0.0, 1.5)) * life_k, UiStyle.C_YELLOW, px)
	_pdisc(tip, (2.4 + rng.randf_range(0.0, 1.0)) * life_k, UiStyle.C_WHITE, px)
	var target: Player = _lightning_target(h, at)
	if target != null:  # arcs crawling over them
		var c: Vector2 = target.global_position + target.visual_offset
		for k: int in 3:
			var a: float = rng.randf() * TAU
			var q := PackedVector2Array([tip])
			for s: int in 4:
				a += rng.randf_range(-0.9, 0.9)
				var nxt: Vector2 = q[q.size() - 1] + Vector2.RIGHT.rotated(a) * 8.0
				var away: Vector2 = nxt - c
				if away.length() > 22.0:  # kept on the body
					nxt = c + away.normalized() * 22.0
				q.append(nxt)
			_ppoly(q, LIGHTNING_CYAN, 2, px)
			_ppoly(q, UiStyle.C_WHITE, 1, px)


func _draw_markers(px: float) -> void:
	for m: Marker in _markers:
		if m.life <= 0.0:
			continue
		var k: float = 1.0 - m.life / MARKER_TIME  # 0 -> 1
		var gap: float = MARKER_GAP * (1.0 + 0.6 * k) * (1.3 if m.strong else 1.0)
		var len_px: float = snappedf(MARKER_SIZE * (1.0 - 0.5 * k) * (1.3 if m.strong else 1.0), px)
		var color: Color = UiStyle.C_YELLOW if m.strong else UiStyle.C_WHITE
		var w: float = px * 2.0 if m.strong else px
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var a: Vector2 = m.pos + d.normalized() * gap
			draw_line(a, a + d.normalized() * len_px, UiStyle.C_OUTLINE, w + px * 2.0)
			draw_line(a, a + d.normalized() * len_px, color, w)


func _draw_aim_marker(px: float) -> void:
	if aim_marker == Vector2.INF:
		_aim_prev = Vector2.INF
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	if _aim_prev == Vector2.INF or aim_marker.distance_to(_aim_prev) > AIM_HALF * 3.0:
		_aim_since = t  # new lock: ease in again
	_aim_prev = aim_marker
	var k: float = clampf((t - _aim_since) / AIM_EASE_TIME, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - k, 3.0)
	var half: float = AIM_HALF * aim_scale * (1.0 + AIM_START_SPREAD * (1.0 - eased)) + AIM_PULSE * sin(t * 6.0) * eased
	half = roundf(half / px) * px
	var leg: float = AIM_LEG * minf(aim_scale, 1.5)
	var c: Vector2 = aim_marker.snapped(Vector2(px, px))
	var col := Color(COLOR_AIM, 0.35 + 0.65 * eased)
	var dark := Color(UiStyle.C_OUTLINE, col.a)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner: Vector2 = c + Vector2(sx, sy) * half
			var h_end: Vector2 = corner - Vector2(sx * leg, 0.0)
			var v_end: Vector2 = corner - Vector2(0.0, sy * leg)
			# 1 px dark outline around each 1.5 px bracket leg.
			draw_line(corner + Vector2(sx * px, 0.0), h_end - Vector2(sx * px, 0.0), dark, px * 3.5)
			draw_line(corner + Vector2(0.0, sy * px), v_end - Vector2(0.0, sy * px), dark, px * 3.5)
			draw_line(corner, h_end, col, px * 1.5)
			draw_line(corner, v_end, col, px * 1.5)