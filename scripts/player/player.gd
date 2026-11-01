class_name Player
extends CharacterBody2D
## A fighter in the arena. All gameplay goes through simulate(InputFrame, delta) so the
## same path runs on the server, offline, and for client-side prediction/replay.
## Players collide with walls only (not each other), which keeps prediction exact.

signal died(victim: Player, killer_id: int)
signal shot_fired(shooter: Player, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName)
## Predicted/authoritative skill activation (not emitted during replay). For effects/SFX.
signal skill_used(user: Player, skill: SkillData)
## Verdant Bloom healed this player by `amount` (seen from the synced hp, so on every peer).
signal healed(user: Player, amount: int)
## Came back from dead / sitting out (every peer, from the synced dead flag): spawn pop FX.
signal spawned(user: Player)

## Layout of capture_state() / apply_state() arrays sent in snapshots.
enum StateField {
	ID, POSITION, VELOCITY, FACING,
	HP, ARMOR, ENERGY, ENERGY_ACCUM, TIME_SINCE_DAMAGE, REGEN_ACCUM, INVULNERABLE,
	CHARACTER, SKILL_IDS, SKILL_COOLDOWNS, SKILL_ACTIVE, SKILL_DIRECTIONS, SKILL_ANCHORS, SKILL_WEAPON_COOLDOWNS,
	WEAPON_ID, WEAPON_COOLDOWN, PREV_SKILLS, DEAD, RESPAWN_TIMER, LAST_INPUT_SEQ, SLOW_REMAINING, SLOW_FACTOR,
	STUN_REMAINING, SPAWN_PROTECT,
	COUNT,
}

## Weapon art (WeaponData.sprite) is drawn at the character's pixel scale, pivoting on its grip.
const WEAPON_GRIP: Vector2 = Vector2(6, 12)
## The front hand (generate.py arm() at ARM_X[1]) in local px, mirrored when facing left: weapon grips sit on it.
const WEAPON_HAND: Vector2 = Vector2(20, 22)
const AIM_SEARCH_STEPS: int = 72
const AIM_REFINE_STEPS: int = 7
## Sheet cell rows from the top down to the chin (generate.py PAD + FACE bottom + UPPER_DY, + outline and bob): redrawn over a
## front weapon so it sits in front of the body but behind the head.
const SPRITE_HEAD_ROWS: int = 56
const GUN_RECOIL_PX: float = 4.0
const GUN_KICK_DEG: float = 14.0
const RECOIL_TIME: float = 0.06
## Melee animation: a sweep across the arc (or a stab out and back), starting from a raised guard.
const MELEE_ANIM_TIME: float = 0.16
const MELEE_REST_DEG: float = 35.0
const THRUST_REACH: float = 0.35
const INVULN_ALPHA: float = 0.45
## The held weapon fades out / back in over this long as a pose takes over from him and hands back.
const GUN_FADE_TIME: float = 0.12
## Spawn protection look: flicker rate (Hz, doubled for the last SPAWN_WARN_TIME s), low alpha, shimmer rate, ground ring.
const SPAWN_BLINK_HZ: float = 8.0
const SPAWN_WARN_TIME: float = 0.4
const SPAWN_ALPHA_LOW: float = 0.4
const SPAWN_SHIMMER_HZ: float = 2.5
const SPAWN_RING_COLOR: Color = Color(0.55, 0.9, 1.0)
## Volley shots get their own key space so they never collide with the same frame's normal shot.
const VOLLEY_SEQ_OFFSET: int = 1 << 24
## Eruptions go off frames after the press, so they get theirs too (a volley can be fired the frame one goes off).
const ERUPTION_SEQ_OFFSET: int = 1 << 25
## Key of a Staff Whirl damage tick (no bullet to match, only the hit event's identity).
const WHIRL_SEQ_OFFSET: int = 1 << 26
## Trail burn ticks are keyed too (several can land in one input).
const TRAIL_SEQ_OFFSET: int = 1 << 27
## Sky Pillar slams are keyed too.
const PILLAR_SEQ_OFFSET: int = 1 << 28
## Flare Burst blasts are keyed too.
const NOVA_SEQ_OFFSET: int = 1 << 30
## Cherry Sapling shots are keyed too (below the volley offset).
const SAPLING_SEQ_OFFSET: int = 1 << 22
## Leaf Gust hits are keyed too.
const GUST_SEQ_OFFSET: int = 1 << 21
## Storm Cloud lightning strikes are keyed too.
const STORM_SEQ_OFFSET: int = 1 << 29
## Shadow Step emergence strikes and Gloom Hound bites are keyed too (above 32 bits, clear of the offsets above).
const STEP_SEQ_OFFSET: int = 1 << 31
## Where a puddle that ends inside a wall comes up: rings of SURFACE_DIRECTIONS spots every SURFACE_RING_STEP px.
const SURFACE_RINGS: int = 12
const SURFACE_RING_STEP: float = 12.0
const SURFACE_DIRECTIONS: int = 16
const HOUND_SEQ_OFFSET: int = 1 << 32
## The Gloom Hound's body radius against the feet-level walls.
const HOUND_RADIUS: float = 14.0
## Shadow clones weave side to side as they run.
const CLONE_WOBBLE_PX: float = 26.0
const CLONE_WOBBLE_SPEED: float = 4.0
## Clones pop into being this far out around you (each in its own cloud), wait there while the
## cloud clears, then run.
const CLONE_START_DISTANCE: float = 48.0
const CLONE_EMERGE_TIME: float = 0.3
const BAR_WIDTH: float = 40.0
const BAR_HEIGHT: float = 4.0
const BAR_GAP: float = 2.0
const BAR_OFFSET_Y: float = 28.0
## Shadow ellipse under the feet, squashed for a top-down look.
const FOOT_RING_SQUASH: float = 0.45
const FOOT_RING_Y: float = 40.0
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.3)
const COLOR_HP: Color = Color(0.9, 0.25, 0.25)
const COLOR_ARMOR: Color = Color(0.7, 0.75, 0.85)
const COLOR_BAR_BG: Color = Color(0, 0, 0, 0.5)

var player_id: int = 0
var color_index: int = 0
var display_color: Color = Color.WHITE
var is_local: bool = false
var is_bot: bool = false
## Countdown / results screen: inputs are ignored (timers still run).
var frozen: bool = false
var character: CharacterData
var stats := PlayerStats.new()
## The one weapon carried (picked in the loading room from the character's options, the signature by default).
## It costs energy per shot; energy refills over time.
var weapon: WeaponState
var chosen_weapon: WeaponData
## Used when the character has no signature weapon (setup's list, e.g. tests and bots).
var fallback_weapon: WeaponData
## The two specials picked in the loading room (the character's own or generic ones, Dash among them): the first
## special button (InputFrame.skill) fires slot 0, the second (InputFrame.special) slot 1.
var skills: Array[CharacterSkill] = []
var facing: Vector2 = Vector2.RIGHT
## Null for client-side remote players (they are positioned by interpolation).
var controller: PlayerController
var projectiles: ProjectilePool
var match_seed: int = 0
var dead: bool = false
var respawn_timer: float = 0.0
var last_input_seq: int = 0
## Render-only offset that hides small reconciliation corrections; decays to zero.
var visual_offset: Vector2 = Vector2.ZERO
## Floor inside the arena's border walls (set by the Arena): Vine Swing never lands outside it. Empty = no limit.
var arena_bounds: Rect2 = Rect2()

var _shape: CollisionShape2D
var _shield := ShieldWall.new()
var _ward := ShieldWall.new(true)
var _prev_skills: Array[bool] = [false, false]
var _hit_flash: float = 0.0
## 0..1: how much of the held weapon shows (fades while a pose replaces him, see _gun_suppressed).
var _gun_fade: float = 1.0
var _gun_alpha: float = 1.0
## Attack animation time left, and its full length (depends on the weapon used).
var _recoil: float = 0.0
var _recoil_len: float = RECOIL_TIME
## Time left on the sprite's "attack" animation (sheets that have one, e.g. the Great Ape).
var _attack_anim: float = 0.0
## A wound-up attack (WeaponData.windup) waiting to land: seconds left (< 0 = none), its seq and weapon.
var _windup_left: float = -1.0
var _windup_seq: int = 0
var _windup_weapon: WeaponData
var _sprite := AnimatedSprite2D.new()
## Drawn after the sprite: the gun when it's in front of the body, and health bars.
var _overlay := Node2D.new()
## Smoke clouds and shadow clones (cosmetic, from the synced special state).
var _special_fx := SpecialFx.new()
var _feet_ray := PhysicsRayQueryParameters2D.new()
var _swing_query := PhysicsShapeQueryParameters2D.new()
var _sight_query := PhysicsRayQueryParameters2D.new()


func setup(id: int, p_color_index: int, color: Color, weapons: Array[WeaponData], ctrl: PlayerController,
		pool: ProjectilePool, p_match_seed: int, p_character: CharacterData) -> void:
	player_id = id
	color_index = p_color_index
	display_color = color
	fallback_weapon = weapons[0] if not weapons.is_empty() else null
	controller = ctrl
	projectiles = pool
	match_seed = p_match_seed
	collision_layer = Constants.LAYER_PLAYERS
	collision_mask = Constants.LAYER_WALL_FEET  # walls shifted up to the feet, see Constants
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var circle := CircleShape2D.new()
	circle.radius = Constants.PLAYER_RADIUS
	_shape = CollisionShape2D.new()
	_shape.shape = circle
	add_child(_shape)
	_shield.owner_id = id
	_shield.color = color
	add_child(_shield)
	_ward.owner_id = id
	add_child(_ward)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * Constants.SPRITE_SCALE
	add_child(_sprite)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	add_child(_special_fx)
	_ward.caught.connect(_special_fx.petal_pop)
	_special_fx.healed.connect(func(amount: int) -> void: healed.emit(self, amount))
	# The walls players move against (shifted to the feet): standing under a wall puts the centre inside the wall
	# itself, and a ray starting inside a wall misses it, so clones ran out through it (even past the border).
	# Grapple Kunai casts against them too, so it only bites walls she can stand against.
	_feet_ray.collision_mask = Constants.LAYER_WALL_FEET
	_swing_query.collision_mask = Constants.LAYER_WALL_FEET  # where a player can stand
	_swing_query.shape = circle
	_sight_query.collision_mask = Constants.LAYER_WALLS
	set_character(p_character)


## Switch character (lobby pick or a snapshot saying so): new stat maxes, fresh skills. Keeps the picked specials
## and weapon if the new character can use them.
func set_character(data: CharacterData) -> void:
	character = data
	stats = PlayerStats.new(data.max_hp, data.max_armor, data.max_energy)
	var defaults: Array[SkillData] = default_skills(data)
	var kept: Array[SkillData] = []
	for i: int in Constants.SKILL_SLOTS:
		var old: SkillData = skills[i].data if i < skills.size() else null
		kept.append(old if old != null and data.can_use_skill(old) else defaults[i])
	if kept[0] == kept[1]:
		kept[1] = defaults[1] if defaults[1] != kept[0] else defaults[0]
	skills.clear()
	for sd: SkillData in kept:
		skills.append(CharacterSkill.new(sd))
	_sync_shields()
	_sprite.sprite_frames = data.sprite_frames()
	_sprite.play(&"idle")
	if chosen_weapon != null and not data.can_use(chosen_weapon) and chosen_weapon != data.signature_weapon:
		chosen_weapon = null
	_reset_weapon()


## A fresh pick: Dash on the skill button, the character's signature special (or its next one) on the special button.
static func default_skills(data: CharacterData) -> Array[SkillData]:
	var pool: Array[SkillData] = SkillCatalog.shared().specials_for(data)
	var dash: SkillData = SkillCatalog.shared().dash()
	return [dash, pool[0] if pool[0] != dash else pool[1]]


## Put `data` in skill slot `slot`; if the other slot already has it, the two swap.
func set_skill(slot: int, data: SkillData) -> void:
	var other: int = 1 - slot
	var old: SkillData = skills[slot].data
	if skills[other].data == data:
		skills[other] = CharacterSkill.new(old)
	skills[slot] = CharacterSkill.new(data)
	_sync_shields()


func set_weapon(w: WeaponData) -> void:
	chosen_weapon = w
	_reset_weapon()


func _reset_weapon() -> void:
	var w: WeaponData = chosen_weapon
	if w == null:
		w = character.signature_weapon if character.signature_weapon != null else fallback_weapon
	weapon = WeaponState.new(w)


func _physics_process(delta: float) -> void:
	if controller == null:
		return
	var input: InputFrame = controller.get_input(self, delta)
	while input != null:
		simulate(input, delta)
		input = controller.next_extra_input()


func _process(delta: float) -> void:
	if controller == null:  # a remote (interpolated) copy doesn't simulate: clear the same shots the server's gust did
		var remote_gust: CharacterSkill = active_skill(SkillData.Kind.GUST)
		if remote_gust != null and projectiles != null:
			_gust(remote_gust, 0, false)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_recoil = maxf(0.0, _recoil - delta)
	visual_offset *= exp(-Constants.CORRECTION_DECAY * delta)
	_attack_anim = maxf(0.0, _attack_anim - delta)
	var anim: StringName = &"idle"
	if _attack_anim > 0.0:
		anim = &"attack"
	elif _hit_flash > 0.0:
		anim = &"hit"
	elif velocity.length() > Constants.SPRITE_WALK_MIN_SPEED:
		anim = &"walk"
	var tf: CharacterSkill = form()
	var frames: SpriteFrames = tf.data.form_frames() if tf != null else character.sprite_frames()
	if anim == &"attack" and not frames.has_animation(anim):  # the form ended mid-swing
		_attack_anim = 0.0
		anim = &"idle"
	if _sprite.sprite_frames != frames:
		_sprite.sprite_frames = frames
		_sprite.scale = Vector2.ONE * Constants.SPRITE_SCALE * (tf.data.form_scale if tf != null else 1.0)
		_sprite.play(anim)
	if _sprite.animation != anim:
		_sprite.play(anim)
	_sprite.position = visual_offset
	_sprite.flip_h = facing.x < 0.0
	_special_fx.sync(self)
	_gun_fade = move_toward(_gun_fade, 0.0 if _gun_suppressed() else 1.0, delta / GUN_FADE_TIME)
	_gun_alpha = INVULN_ALPHA if stats.invulnerable_time > 0.0 or is_hidden() else 1.0  # (the weapon fades on its own, not with the body)
	_sprite.modulate.a = 0.0 if _special_fx.is_swinging() else _special_fx.owner_alpha() * _gun_alpha
	_sprite.modulate = Color(1, 1, 1, _sprite.modulate.a)
	if stats.spawn_protect > 0.0 and _sprite.modulate.a > 0.0:
		# Spawn protection: flickers (faster as it runs out) with a cool shimmer sweeping through the tint.
		var phase: float = Time.get_ticks_msec() * 0.001
		var blink: float = SPAWN_BLINK_HZ * (2.0 if stats.spawn_protect < SPAWN_WARN_TIME else 1.0)
		var shimmer: float = 0.5 + 0.5 * sin(phase * TAU * SPAWN_SHIMMER_HZ)
		_sprite.modulate = Color(1.0 + 0.3 * shimmer, 1.0 + 0.3 * shimmer, 1.0 + 0.5 * shimmer,
			SPAWN_ALPHA_LOW if fmod(phase * blink, 1.0) < 0.5 else 1.0)
		_gun_alpha = _sprite.modulate.a
	queue_redraw()
	_overlay.queue_redraw()


## Advance this player by one input. `replay` = re-simulating already-predicted inputs
## during reconciliation: state changes happen, side effects (spawning shots) don't.
func simulate(input: InputFrame, delta: float, replay: bool = false) -> void:
	last_input_seq = input.seq
	if dead:
		_prev_skills = [input.skill, input.special]  # a button held (or tapped) while dead must not fire on the respawn frame
		return
	stats.tick(delta)
	if stats.is_stunned():
		_interrupt_channels()
	# Caught before the tick so the frame it runs out still puts him exactly on the landing spot.
	var swing: CharacterSkill = active_skill(SkillData.Kind.SWING)
	var erupting: CharacterSkill = active_skill(SkillData.Kind.ERUPTION)
	var burning: CharacterSkill = active_skill(SkillData.Kind.TRAIL)
	var burn_before: float = burning.elapsed() if burning != null else 0.0
	var pillar: CharacterSkill = active_skill(SkillData.Kind.PILLAR)
	var pillar_before: float = pillar.elapsed() if pillar != null else 0.0
	var nova: CharacterSkill = active_skill(SkillData.Kind.NOVA)
	var nova_before: float = nova.elapsed() if nova != null else 0.0
	var sapling_before: Array[float] = []
	var storm: CharacterSkill = active_skill(SkillData.Kind.STORM)
	var storm_before: float = storm.elapsed() if storm != null else 0.0
	var bloom_before: Array[float] = []
	var step_was: CharacterSkill = active_skill(SkillData.Kind.STEP)
	var hound_before: float = -1.0
	var hound_was: CharacterSkill = active_skill(SkillData.Kind.HOUND)
	if hound_was != null:
		hound_before = hound_was.elapsed()
	for slot: CharacterSkill in skills:
		sapling_before.append(slot.elapsed() if slot.is_active() else -1.0)
		bloom_before.append(slot.elapsed() if slot.is_active() else -1.0)
		slot.tick(delta)
	if not replay:
		for i: int in skills.size():
			if sapling_before[i] >= 0.0 and skills[i].sapling_shot_due(sapling_before[i]):
				_sapling_shoot(skills[i], input.seq)
			if projectiles != null and bloom_before[i] >= 0.0 and skills[i].bloom_tick_due(bloom_before[i]):
				projectiles.bloom(player_id, skills[i].anchor, skills[i].data.bloom_radius, skills[i].data.bloom_heal)
	if step_was != null and not step_was.is_active():
		_surface()  # rises from under whatever he slid through, onto the nearest floor, then strikes from there
	_shadow_tick(step_was, hound_was, hound_before, input.seq, delta, replay)
	if storm != null and not replay and storm.storm_tick_due(storm_before):
		var sd: SkillData = storm.data
		projectiles.strike(player_id, input.seq + STORM_SEQ_OFFSET, storm.anchor, sd.storm_radius, sd.storm_damage,
			sd.storm_knockback)
	if burning != null and not replay:
		_burn_trail(burning, burn_before, input.seq)
	if pillar != null and not replay and pillar.pillar_slammed(pillar_before):
		var d: SkillData = pillar.data
		projectiles.line_hit(player_id, input.seq + PILLAR_SEQ_OFFSET, pillar.anchor, pillar.anchor + pillar.direction,
			d.pillar_width * 0.5, d.pillar_damage, d.pillar_knockback)
	if nova != null and not replay and nova.nova_burst(nova_before):
		var key: int = input.seq + NOVA_SEQ_OFFSET
		projectiles.fire_shot(player_id, key, global_position, nova.direction, nova.data.nova_blast, match_seed)
		shot_fired.emit(self, key, global_position, nova.direction, nova.data.nova_blast.id)
	var charged: CharacterSkill = active_skill(SkillData.Kind.OVERDRIVE)
	weapon.tick(delta * (charged.data.overdrive_fire_scale if charged != null else 1.0))
	var pressed: Array[bool] = [input.skill, input.special]
	if frozen:
		# Keep edge state current so a button held through the countdown doesn't fire on release.
		_prev_skills = pressed
		_end_abilities(swing)
		velocity = Vector2.ZERO
		_sync_shields()
		return

	if erupting != null and not erupting.is_active() and not replay:
		_erupt(erupting, input.seq)
	for i: int in Constants.SKILL_SLOTS:
		if pressed[i] and not _prev_skills[i] and not skill_locked(i) and not stats.is_stunned():  # one ability at a time
			_activate(skills[i], input, replay)
	_prev_skills = pressed

	var grapple: CharacterSkill = active_skill(SkillData.Kind.GRAPPLE)
	var whirl: CharacterSkill = active_skill(SkillData.Kind.WHIRL)
	var drift: CharacterSkill = active_skill(SkillData.Kind.DRIFT)
	var overdrive: CharacterSkill = active_skill(SkillData.Kind.OVERDRIVE)
	var stepping: CharacterSkill = active_skill(SkillData.Kind.STEP)
	var planting: CharacterSkill = active_skill(SkillData.Kind.PILLAR)  # just pressed counts
	var flaring: CharacterSkill = active_skill(SkillData.Kind.NOVA)
	var rooted: bool = (planting != null and planting.pillar_winding()) or (flaring != null and flaring.nova_charging()) \
		or stats.is_stunned()
	if swing == null:
		swing = active_skill(SkillData.Kind.SWING)  # just pressed
	if swing != null:  # in the air: placed along the arc, over whatever is in between
		global_position = swing.anchor + swing.direction * swing.swing_progress()
		velocity = Vector2.ZERO
	elif grapple != null:
		_pull(grapple, delta)
	elif rooted:
		velocity = Vector2.ZERO
	elif _trail_dash(delta) != null:  # runs the burning line, walls were measured at takeoff
		var run: CharacterSkill = _trail_dash(delta)
		global_position = run.anchor + run.direction * run.trail_progress()
		velocity = Vector2.ZERO
	else:
		var mover: CharacterSkill = active_skill(SkillData.Kind.DASH)
		var tf: CharacterSkill = form()
		var speed: float = character.move_speed * (tf.data.form_speed_scale if tf != null else 1.0) \
			* stats.speed_scale()
		if whirl != null:
			speed *= whirl.data.whirl_speed_scale
		if overdrive != null:
			speed *= overdrive.data.overdrive_speed_scale
		if stepping != null:  # a puddle gliding on its own way until the stick says otherwise
			speed *= stepping.data.step_speed_scale
		var smoke: CharacterSkill = active_skill(SkillData.Kind.SMOKE)
		if smoke != null and is_hidden():
			speed *= smoke.data.smoke_speed_scale
		var steer: Vector2 = input.move_vec
		if drift != null:  # glides on its own way until the stick says otherwise
			speed *= drift.data.drift_speed_scale
			if steer.length() < Constants.INPUT_DEADZONE:
				steer = drift.direction
		elif stepping != null and steer.length() < Constants.INPUT_DEADZONE:
			steer = stepping.direction
		velocity = MovementSim.step_velocity(velocity, steer, mover if mover != null else skills[0], speed, delta)
		if stepping != null:  # a puddle slides under walls and crates; only the arena edge stops it
			collision_mask = 0
		move_and_slide()
		collision_mask = Constants.LAYER_WALL_FEET
		if stepping != null and arena_bounds.has_area():
			global_position = global_position.clamp(arena_bounds.position + Vector2.ONE * Constants.PLAYER_RADIUS,
				arena_bounds.end - Vector2.ONE * Constants.PLAYER_RADIUS)
	_sync_shields()
	if whirl != null:
		_whirl(whirl, input.seq, delta, replay)
	var gust: CharacterSkill = active_skill(SkillData.Kind.GUST)
	if gust != null:
		_gust(gust, input.seq, replay)

	if input.aim_vec.length_squared() > 0.0:
		facing = input.aim_vec.normalized()
	elif input.move_vec.length() > Constants.INPUT_DEADZONE:
		facing = input.move_vec.normalized()

	if _windup_left >= 0.0 and not replay:  # replays re-run inputs already counted: don't land it early
		_windup_left -= delta
		if _windup_left <= 0.0:
			_windup_left = -1.0
			_release_shot(_windup_seq, _windup_weapon)
	if input.fire and not is_dashing() and grapple == null and whirl == null and drift == null and stepping == null and not rooted:  # both hands on the chain
		_try_fire(input.seq, replay)


## A stun cuts channelled self-abilities short (Staff Whirl, Petal Drift, Shadow Step): they end cleanly, cooldown stays, and a
## stepping Shadow surfaces on free floor without his strike. Runs in the shared sim, so prediction and replay agree.
func _interrupt_channels() -> void:
	for slot: CharacterSkill in skills:
		if not slot.is_active():
			continue
		match slot.data.kind:
			SkillData.Kind.WHIRL:
				slot.active_remaining = 0.0
			SkillData.Kind.DRIFT:
				slot.active_remaining = 0.0
				stats.invulnerable_time = 0.0
			SkillData.Kind.STEP:
				slot.active_remaining = 0.0
				stats.invulnerable_time = 0.0
				_surface()


## Countdown / results freeze the player: whatever he was doing ends here. A swing lands where it was going (not mid-air,
## possibly over a wall) and a burning-trail dash finishes at the end of its line.
func _end_abilities(swing: CharacterSkill) -> void:
	if swing != null:
		global_position = swing.anchor + swing.direction
	var stepping: bool = false
	for slot: CharacterSkill in skills:
		if slot.data.kind == SkillData.Kind.TRAIL and slot.trail_dashing(0.0):
			global_position = slot.anchor + slot.direction
		stepping = stepping or slot.is_stepping()
		slot.active_remaining = 0.0
	if stepping:
		_surface()  # a puddle under a wall comes up on free floor, not stuck in the wall for the whole results screen


## True while the other slot is in a phase that blocks this one (see CharacterSkill.blocks_other): the press is ignored.
func skill_locked(slot: int) -> bool:
	for i: int in skills.size():
		if i != slot and skills[i].blocks_other():
			return true
	return false


func _activate(slot: CharacterSkill, input: InputFrame, replay: bool) -> void:
	var dir: Vector2 = _skill_direction(slot.data, input)
	var landing := Vector2.INF
	if slot.data.kind == SkillData.Kind.SWING:
		if not slot.is_ready():
			return
		landing = swing_landing(dir, slot.data)
		if landing == Vector2.INF:
			return  # nowhere to land: no swing, no cooldown
	if not slot.try_activate(dir, global_position, stats):
		return
	match slot.data.kind:
		SkillData.Kind.SWING:
			slot.direction = landing - global_position
		SkillData.Kind.TRAIL:  # how far he gets before a wall (measured, not moved: the dash does that)
			var hit: KinematicCollision2D = move_and_collide(slot.direction * slot.data.trail_distance, true)
			slot.direction = hit.get_travel() if hit != null else slot.direction * slot.data.trail_distance
		SkillData.Kind.PILLAR:  # the line is fixed now: up to its length, short of the first wall
			slot.anchor = global_position
			_sight_query.from = global_position
			_sight_query.to = global_position + slot.direction * slot.data.pillar_length
			var wall: Dictionary = get_world_2d().direct_space_state.intersect_ray(_sight_query)
			slot.direction = (wall.position if not wall.is_empty() else _sight_query.to) - global_position
		SkillData.Kind.GRAPPLE:
			_throw_grapple(slot)
		SkillData.Kind.SAPLING, SkillData.Kind.BLOOM:
			slot.anchor = global_position + Vector2(0.0, FOOT_RING_Y)
		SkillData.Kind.ERUPTION:
			slot.anchor = eruption_spot(slot.direction, slot.data)
		SkillData.Kind.STORM:
			slot.anchor = storm_spot(slot.direction, slot.data)
		SkillData.Kind.HOUND:
			slot.anchor = hound_spot(slot.direction, slot.data)
		SkillData.Kind.BIND:
			slot.direction *= bind_length(slot.direction, slot.data)
			if slot.direction.is_zero_approx():  # a wall at his feet: no line at all (a zero heading would catch anyone)
				slot.active_remaining = 0.0
		SkillData.Kind.VOLLEY, SkillData.Kind.SNARE:
			if not replay:
				var seq: int = input.seq + VOLLEY_SEQ_OFFSET
				projectiles.fire_shot(player_id, seq, global_position, slot.direction, slot.data.volley_weapon, match_seed)
				shot_fired.emit(self, seq, global_position, slot.direction, slot.data.volley_weapon.id)
	if not replay:
		skill_used.emit(self, slot.data)


## The staff is spinning: shots touching it go back, and a damage tick lands when due. Replay changes nothing.
func _whirl(slot: CharacterSkill, seq: int, delta: float, replay: bool) -> void:
	if replay or projectiles == null:
		return
	var d: SkillData = slot.data
	projectiles.whirl(player_id, seq + WHIRL_SEQ_OFFSET, global_position, d.whirl_radius,
		d.whirl_damage if slot.whirl_tick_due(delta) else 0, d.whirl_knockback)


## The leaf gust: enemy shots in the cone are destroyed on every step it lasts (so ones flying into it die too); the hit
## (damage + push) lands once, on the press. Replay changes nothing. Remote copies call it from `_process` (the
## press isn't visible there, `gust_just_pressed` is false for them in practice, and the pool only damages when authoritative).
func _gust(slot: CharacterSkill, seq: int, replay: bool) -> void:
	if replay or projectiles == null:
		return
	var d: SkillData = slot.data
	projectiles.gust(player_id, seq + GUST_SEQ_OFFSET, global_position, slot.direction, d.gust_range,
		deg_to_rad(d.gust_half_angle_deg), d.gust_damage if slot.gust_just_pressed() else 0, d.gust_knockback)


## The tree shoots one petal at the nearest visible enemy in range (shadow clones count, smoked ones don't). Ties go
## to the earlier player, so the choice is the same on every peer that simulates it.
func _sapling_shoot(slot: CharacterSkill, seq: int) -> void:
	var d: SkillData = slot.data
	var muzzle: Vector2 = slot.anchor - Vector2(0.0, d.sapling_muzzle_height)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var best: float = d.sapling_range * d.sapling_range
	var aim := Vector2.INF
	for p: Player in projectiles.targets:
		if p == self or p.dead:
			continue
		var spots: PackedVector2Array = p.clone_points()
		if not p.is_hidden():
			spots.append(p.global_position)
		for spot: Vector2 in spots:
			var dist: float = muzzle.distance_squared_to(spot)
			if dist >= best:
				continue
			for at: Vector2 in [spot, spot + Vector2(0.0, Constants.PLAYER_RADIUS * AutoAim.LOW_SPOT)]:
				if AutoAim.has_line_of_sight(space, _sight_query, muzzle, at):
					best = dist
					aim = at
					break
	if aim == Vector2.INF:
		return
	var dir: Vector2 = (aim - muzzle).normalized()
	var key: int = seq + SAPLING_SEQ_OFFSET
	projectiles.fire_shot(player_id, key, muzzle, dir, d.sapling_weapon, match_seed)
	shot_fired.emit(self, key, muzzle, dir, d.sapling_weapon.id)


# --- Shadow: Shadow Step, Gloom Hound, Shadow Bind --------------------------------------------------------------

## Per step: a Shadow Step that just ended strikes where he emerges; a hound moves and bites; a bind stretches and may catch
## someone. All authoritative-ish and non-replay (the hound only moves and bites on the authority; clients get it from snapshots).
func _shadow_tick(step_was: CharacterSkill, hound_was: CharacterSkill, hound_before: float, seq: int, delta: float,
		replay: bool) -> void:
	if replay or projectiles == null:
		return
	if step_was != null and not step_was.is_active():
		var d: SkillData = step_was.data
		projectiles.strike(player_id, seq + STEP_SEQ_OFFSET, global_position, d.step_radius, d.step_damage,
			d.step_knockback)
	if hound_was != null and hound_was.is_active():
		_hound_step(hound_was, hound_before, seq, delta)
	var binding: CharacterSkill = active_skill(SkillData.Kind.BIND)
	if binding != null:
		_bind_step(binding)


## Where a hound called along `dir` rises: `hound_distance` ahead in the feet-level walls' space (like the clones), pulled back
## off the first wall by its margin and radius.
func hound_spot(dir: Vector2, d: SkillData) -> Vector2:
	_feet_ray.from = global_position
	_feet_ray.to = global_position + dir * d.hound_distance
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(_feet_ray)
	if hit.is_empty():
		return _feet_ray.to
	return hit.position + hit.normal * (HOUND_RADIUS + d.hound_wall_margin)


## The nearest enemy the hound can see from `from` within `sight` (not smoked or stepping, not dead), or null.
func hound_target(from: Vector2, sight: float) -> Player:
	var best: Player = null
	var best_sq: float = sight * sight
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for p: Player in projectiles.targets:
		if p == self or p.dead or p.is_hidden():
			continue
		var d_sq: float = from.distance_squared_to(p.global_position)
		if d_sq < best_sq and AutoAim.has_line_of_sight(space, _sight_query, from, p.global_position):
			best = p
			best_sq = d_sq
	return best


## The hound runs at the nearest visible enemy (stopping at walls) and bites whoever it touches when a bite falls due.
func _hound_step(slot: CharacterSkill, before: float, seq: int, delta: float) -> void:
	var d: SkillData = slot.data
	if slot.elapsed() < d.hound_rise_time or not projectiles.authoritative:
		return  # clients don't run the hound: it comes from snapshots (drawn smoothed), so prediction can't jitter it
	var target: Player = hound_target(slot.anchor, d.hound_sight)
	if target != null:
		var to: Vector2 = target.global_position - slot.anchor
		var dir: Vector2 = to.normalized()
		slot.direction = dir
		var move: float = minf(d.hound_speed * delta, maxf(0.0, to.length() - d.hound_bite_radius * 0.85))
		_feet_ray.from = slot.anchor
		_feet_ray.to = slot.anchor + dir * (move + HOUND_RADIUS)
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(_feet_ray)
		slot.anchor += dir * (maxf(0.0, hit.position.distance_to(slot.anchor) - HOUND_RADIUS) if not hit.is_empty() else move)
	var interval: float = d.hound_bite_interval
	var bites: int = floori((slot.elapsed() - d.hound_rise_time + CharacterSkill.WHIRL_EPSILON) / interval)
	var bites_before: int = floori((before - d.hound_rise_time + CharacterSkill.WHIRL_EPSILON) / interval)
	if (before >= d.hound_rise_time and bites > bites_before) or before < d.hound_rise_time:  # the first bite is on rising
		projectiles.strike(player_id, seq + HOUND_SEQ_OFFSET, slot.anchor, d.hound_bite_radius, d.hound_damage,
			d.hound_knockback)


## How long the bind's line is, in units of the aim vector (the aim is a unit vector): up to `bind_range`, short of a wall.
func bind_length(dir: Vector2, d: SkillData) -> float:
	_feet_ray.from = global_position
	_feet_ray.to = global_position + dir * d.bind_range
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(_feet_ray)
	if hit.is_empty():
		return d.bind_range
	return maxf(0.0, hit.position.distance_to(global_position) - Constants.PLAYER_RADIUS)


## The shadow's head advances; the first enemy within its width (authority only) is stunned and the line ends on them.
func _bind_step(slot: CharacterSkill) -> void:
	var d: SkillData = slot.data
	if slot.active_remaining <= d.bind_stun + CharacterSkill.WHIRL_EPSILON or not projectiles.authoritative:
		return  # already caught someone (tether time left), or only the server decides
	var head: float = slot.bind_head()
	var along: Vector2 = slot.direction.normalized()
	var best: Player = null
	var best_at: float = INF
	for p: Player in projectiles.targets:
		if p == self or p.dead or not p.can_be_hit():
			continue
		var rel: Vector2 = p.global_position - slot.anchor
		var at: float = rel.dot(along)
		if at < 0.0 or at > head + Constants.PLAYER_RADIUS or absf(rel.cross(along)) > d.bind_width * 0.5 + Constants.PLAYER_RADIUS:
			continue
		if at < best_at:
			best = p
			best_at = at
	if best != null:
		best.stats.apply_stun(d.bind_stun)
		best.velocity = Vector2.ZERO
		slot.direction = along * minf(best_at, slot.direction.length())
		slot.active_remaining = d.bind_stun
	elif head >= slot.direction.length():
		slot.active_remaining = 0.0


## The Blaze Run trail burns whoever stands within `trail_radius` of its line on every `trail_tick` (no self-damage).
func _burn_trail(slot: CharacterSkill, before: float, seq: int) -> void:
	var d: SkillData = slot.data
	var tick_now: int = floori(slot.elapsed() / d.trail_tick + 0.0001)
	if tick_now > floori(before / d.trail_tick + 0.0001):
		projectiles.burn_segment(player_id, seq + TRAIL_SEQ_OFFSET, slot.anchor, slot.anchor + slot.direction,
			d.trail_radius, d.trail_damage)


func _trail_dash(delta: float) -> CharacterSkill:
	for slot: CharacterSkill in skills:
		if slot.trail_dashing(delta):
			return slot
	return null


## The telegraph ran out: the pillar of fire goes off at the marked spot.
func _erupt(slot: CharacterSkill, seq: int) -> void:
	var key: int = seq + ERUPTION_SEQ_OFFSET
	projectiles.fire_shot(player_id, key, slot.anchor, slot.direction, slot.data.eruption_blast, match_seed)
	shot_fired.emit(self, key, slot.anchor, slot.direction, slot.data.eruption_blast.id)


## Where an eruption aimed along `dir` is marked: on the floor `eruption_distance` ahead, pulled back off the first
## wall in the way. Measured from the feet, not the centre: standing under a wall puts the centre inside it (a ray
## from inside misses it, so the spot would land beyond), but the feet are always in the open (Constants.WALL_FEET_STRIP).
func eruption_spot(dir: Vector2, d: SkillData) -> Vector2:
	return spot_ahead(dir, d.eruption_distance, d.eruption_wall_margin)


## Where Storm Cloud aimed along `dir` puts its cloud (same rule as the eruption's mark).
func storm_spot(dir: Vector2, d: SkillData) -> Vector2:
	return spot_ahead(dir, d.storm_distance, d.storm_wall_margin)


func spot_ahead(dir: Vector2, distance: float, margin: float) -> Vector2:
	var from: Vector2 = global_position + Vector2(0.0, Constants.WALL_FEET_STRIP)
	_sight_query.from = from
	_sight_query.to = from + dir * distance
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(_sight_query)
	if hit.is_empty():
		return _sight_query.to
	return hit.position - dir * minf(margin, from.distance_to(hit.position))


## The first skill slot of `kind` that is active right now, or null.
func active_skill(kind: SkillData.Kind) -> CharacterSkill:
	for slot: CharacterSkill in skills:
		if slot.data.kind == kind and slot.is_active():
			return slot
	return null


## The transformation in progress, or null.
func form() -> CharacterSkill:
	return active_skill(SkillData.Kind.TRANSFORM)


func is_transformed() -> bool:
	return form() != null


## The barrier and the ward follow their slots (slot 0 when neither special is one: then they stay down).
func _sync_shields() -> void:
	_shield.sync(_slot_of(SkillData.Kind.SHIELD), dead)
	_ward.sync(_slot_of(SkillData.Kind.WARD), dead)


func _slot_of(kind: SkillData.Kind) -> CharacterSkill:
	for slot: CharacterSkill in skills:
		if slot.data.kind == kind:
			return slot
	return skills[0]


## The Blossom Ward ring while it's up, else null. Shots that reach the player inside it (fired from within the
## ring, or the ring moved onto them) are caught too.
func ward() -> ShieldWall:
	return _ward if _ward.is_up() else null


## Inside your own smoke or drifting as petals: enemy auto-aim and bots can't lock on.
func is_hidden() -> bool:
	if active_skill(SkillData.Kind.DRIFT) != null or active_skill(SkillData.Kind.STEP) != null:
		return true
	var smoke: CharacterSkill = active_skill(SkillData.Kind.SMOKE)
	return smoke != null and global_position.distance_to(smoke.anchor) <= smoke.data.smoke_radius


## Where this player's shadow clones are right now (empty unless cloning). A pure function of the
## synced special state and the walls, so every peer (and the server's bots) sees the same clones.
func clone_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	var clones: CharacterSkill = active_skill(SkillData.Kind.CLONES)
	if dead or clones == null:
		return out
	var d: SkillData = clones.data
	var t: float = maxf(0.0, clones.elapsed() - CLONE_EMERGE_TIME)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for k: int in d.clone_count:
		var angle: float = clones.direction.angle() + deg_to_rad(d.clone_spread_deg) * (k - (d.clone_count - 1) * 0.5)
		var run: Vector2 = Vector2.RIGHT.rotated(angle)
		var target: Vector2 = clones.anchor + run * minf(CLONE_START_DISTANCE + t * d.clone_speed, d.clone_reach) \
			+ run.orthogonal() * sin(t * CLONE_WOBBLE_SPEED) * CLONE_WOBBLE_PX
		_feet_ray.from = clones.anchor
		_feet_ray.to = target
		var hit: Dictionary = space.intersect_ray(_feet_ray)
		if not hit.is_empty():
			target = hit.position + hit.normal * Constants.PLAYER_RADIUS  # as close as a player can stand
		out.append(target)
	return out


## Casts the kunai once, at activation: a bite stores where she'll stop (`anchor`, a player radius short of the wall,
## so it's snapshotted and replays don't depend on walls changing later); a miss ends it at once on the short cooldown.
func _throw_grapple(slot: CharacterSkill) -> void:
	_feet_ray.from = global_position
	_feet_ray.to = global_position + slot.direction * slot.data.grapple_range
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(_feet_ray)
	if hit.is_empty():
		slot.active_remaining = 0.0
		slot.cooldown_remaining = slot.data.grapple_miss_cooldown
		return
	slot.anchor = hit.position + hit.normal * (Constants.PLAYER_RADIUS + Constants.GRAPPLE_STANDOFF)
	stats.invulnerable_time = maxf(stats.invulnerable_time, slot.data.grapple_iframes)
	velocity = Vector2.ZERO


## Held still while the kunai bites, then pulled straight at `anchor`; arriving or hitting a wall on the way ends it.
func _pull(slot: CharacterSkill, delta: float) -> void:
	velocity = Vector2.ZERO
	if slot.elapsed() < slot.data.grapple_bite_time:
		return
	var to: Vector2 = slot.anchor - global_position
	var step: float = slot.data.grapple_speed * delta
	var arrived: bool = to.length() <= step
	if move_and_collide(to if arrived else to.normalized() * step) != null or arrived:
		slot.active_remaining = 0.0


## Vine Swing's landing: the farthest spot along `dir` (up to swing_range, not nearer than swing_min_range) where a
## player fits on the floor inside the arena, whatever is in between. Vector2.INF if there is none.
func swing_landing(dir: Vector2, d: SkillData) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.INF
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var inside: Rect2 = arena_bounds.grow(-Constants.PLAYER_RADIUS)
	var dist: float = d.swing_range
	while dist >= d.swing_min_range:
		var at: Vector2 = global_position + dir.normalized() * dist
		if not arena_bounds.has_area() or inside.has_point(at):
			_swing_query.transform = Transform2D(0.0, at)
			if space.intersect_shape(_swing_query, 1).is_empty():
				return at
		dist -= Constants.SWING_SAMPLE_STEP
	return Vector2.INF


## Shadow Step ended: if he is inside a wall or crate, move him to the nearest free spot (rings outwards, deterministic).
func _surface() -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var inside: Rect2 = arena_bounds.grow(-Constants.PLAYER_RADIUS)
	for ring: int in SURFACE_RINGS + 1:
		var dist: float = ring * SURFACE_RING_STEP
		for k: int in (1 if ring == 0 else SURFACE_DIRECTIONS):
			var at: Vector2 = global_position + Vector2.RIGHT.rotated(TAU * k / SURFACE_DIRECTIONS) * dist
			if arena_bounds.has_area() and not inside.has_point(at):
				continue
			_swing_query.transform = Transform2D(0.0, at)
			if space.intersect_shape(_swing_query, 1).is_empty():
				global_position = at
				return


func is_dashing() -> bool:
	return active_skill(SkillData.Kind.DASH) != null


## The weapon FIRE uses: the transformed form's own weapon, else the one carried.
func held_weapon() -> WeaponState:
	var tf: CharacterSkill = form()
	return tf.form_weapon if tf != null else weapon


## Dash goes where you're moving (else where you face); the barrier goes where you aim.
func _skill_direction(data: SkillData, input: InputFrame) -> Vector2:
	var moves: bool = data.kind == SkillData.Kind.DASH or data.kind == SkillData.Kind.DRIFT \
		or data.kind == SkillData.Kind.STEP
	if moves and input.move_vec.length() > Constants.INPUT_DEADZONE:
		return input.move_vec
	if input.aim_vec.length_squared() > 0.0:
		return input.aim_vec
	return facing


func _try_fire(seq: int, replay: bool) -> void:
	var weapon: WeaponState = held_weapon()
	if _windup_left >= 0.0 or not weapon.try_fire(stats):
		return
	stats.spawn_protect = 0.0  # shooting ends spawn protection (replay too: prediction must match the server)
	if replay:
		return
	play_recoil()
	if weapon.data.windup > 0.0:  # the attack animation winds up; the hit lands when it comes down
		_windup_left = weapon.data.windup
		_windup_seq = seq
		_windup_weapon = weapon.data
		return
	_release_shot(seq, weapon.data)


## Fire from where the player is (and faces) now.
func _release_shot(seq: int, w: WeaponData) -> void:
	var origin: Vector2 = shot_origin(w)
	projectiles.fire_shot(player_id, seq, origin, facing, w, match_seed)
	shot_fired.emit(self, seq, origin, facing, w.id)


## Guns fire from the hand holding them (shots then spawn at the barrel tip, WeaponData.muzzle_distance);
## melee swings stay centred on the body.
func shot_origin(w: WeaponData) -> Vector2:
	return global_position + (Vector2.ZERO if w.kind == WeaponData.Kind.MELEE else hand_offset(facing))


## Aim direction that sends shots through `target`: guns fire from the front hand (shot_origin), not the body's
## centre, so aiming centre-to-centre would pass up to ~30 px beside it, wider than a player. The hand changes with
## the aim (it jumps sides past vertical), so search the angles around the target for the shot line passing
## closest, then refine it.
func aim_at(target: Vector2) -> Vector2:
	var to: Vector2 = target - global_position
	if held_weapon().data.kind == WeaponData.Kind.MELEE or to == Vector2.ZERO:
		return to.normalized()
	var best: float = to.angle()
	var best_miss: float = INF
	var step: float = TAU / AIM_SEARCH_STEPS
	for i: int in range(-AIM_SEARCH_STEPS / 2, AIM_SEARCH_STEPS / 2 + 1):
		var miss: float = _aim_miss(target, to.angle() + i * step)
		if miss < best_miss:
			best_miss = miss
			best = to.angle() + i * step
	for k: int in AIM_REFINE_STEPS:
		step *= 0.5
		for a: float in [best - step, best + step]:
			var miss: float = _aim_miss(target, a)
			if miss < best_miss:
				best_miss = miss
				best = a
	return Vector2.from_angle(best) if best_miss < INF else to.normalized()


## How far a shot fired at `angle` passes from `target` (INF if it flies away from it).
func _aim_miss(target: Vector2, angle: float) -> float:
	var dir: Vector2 = Vector2.from_angle(angle)
	var rel: Vector2 = target - (global_position + hand_offset(dir))
	return absf(rel.cross(dir)) if rel.dot(dir) > 0.0 else INF


## Where the front hand is for a character facing `dir` (the sprite flips when facing left, so it's on the aim side).
static func hand_offset(dir: Vector2) -> Vector2:
	return Vector2(-WEAPON_HAND.x if dir.x < 0.0 else WEAPON_HAND.x, WEAPON_HAND.y)


## `skip` seconds into the attack animation: remote peers only hear of a wound-up hit when it lands.
func play_recoil(skip: float = 0.0) -> void:
	_recoil_len = MELEE_ANIM_TIME if held_weapon().data.kind == WeaponData.Kind.MELEE else RECOIL_TIME
	_recoil = _recoil_len
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"attack"):
		_attack_anim = Constants.SPRITE_ATTACK_FRAMES / Constants.SPRITE_ATTACK_FPS - skip
		_sprite.play(&"attack")
		_sprite.frame = roundi(skip * Constants.SPRITE_ATTACK_FPS)  # restart on every swing


func flash() -> void:
	_hit_flash = Constants.HIT_FLASH_TIME
	if is_local:
		GameSettings.vibrate(Constants.HAPTIC_HIT_MS)


func can_be_hit() -> bool:
	return not dead and not stats.is_invulnerable()


## Authoritative damage entry point (offline / server only). Returns damage dealt.
func take_hit(damage: int, _crit: bool, knockback: Vector2, attacker_id: int) -> int:
	var tf: CharacterSkill = form()
	if tf != null:
		damage = maxi(1, roundi(damage * tf.data.form_damage_scale))
	var bark: CharacterSkill = active_skill(SkillData.Kind.BARK_SKIN)
	if bark != null:
		damage = maxi(1, roundi(damage * bark.data.bark_damage_scale))
	var dealt: int = stats.apply_damage(damage)
	if dealt <= 0:
		return 0
	velocity += knockback
	flash()
	if stats.is_dead():
		_die(attacker_id)
	return dealt


func _die(killer_id: int) -> void:
	respawn_timer = Constants.RESPAWN_DELAY
	velocity = Vector2.ZERO
	_set_dead(true)
	died.emit(self, killer_id)


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	stats.reset()
	stats.spawn_protect = Constants.RESPAWN_IFRAME_TIME
	for slot: CharacterSkill in skills:
		slot.reset()
	_reset_weapon()
	_set_dead(false)


## Leave the arena without dying (not playing this match): invisible, no collision, no
## death counted. Respawns as soon as the match state allows it.
func sit_out() -> void:
	respawn_timer = 0.0
	velocity = Vector2.ZERO
	_set_dead(true)


func _set_dead(value: bool) -> void:
	if value == dead:
		return
	dead = value
	_windup_left = -1.0
	if value:  # every ability ends with the player (a dead / sat-out player isn't ticked, so it would hang there)
		for slot: CharacterSkill in skills:
			slot.active_remaining = 0.0
	# A real death (sitting out has no respawn timer) leaves the fall animation behind; on every peer.
	if value and respawn_timer > 0.0 and is_inside_tree():
		_spawn_corpse()
	visible = not value
	_shape.set_deferred("disabled", value)
	_sync_shields()
	if not value and is_inside_tree():
		spawned.emit(self)


## Plays the current sheet's (form's, if transformed) "die" animation where we fell, then frees itself.
func _spawn_corpse() -> void:
	var corpse := AnimatedSprite2D.new()
	corpse.sprite_frames = _sprite.sprite_frames
	corpse.scale = _sprite.scale
	corpse.flip_h = _sprite.flip_h
	corpse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	corpse.global_position = global_position + visual_offset
	corpse.animation_finished.connect(corpse.queue_free)
	get_parent().add_child(corpse)
	corpse.play(&"die")


func capture_state() -> Array:
	var s: Array = []
	s.resize(StateField.COUNT)
	s[StateField.ID] = player_id
	s[StateField.POSITION] = global_position
	s[StateField.VELOCITY] = velocity
	s[StateField.FACING] = facing
	s[StateField.HP] = stats.hp
	s[StateField.ARMOR] = stats.armor
	s[StateField.ENERGY] = stats.energy
	s[StateField.ENERGY_ACCUM] = stats.energy_accum
	s[StateField.TIME_SINCE_DAMAGE] = stats.time_since_damage
	s[StateField.REGEN_ACCUM] = stats.regen_accum
	s[StateField.INVULNERABLE] = stats.invulnerable_time
	s[StateField.CHARACTER] = character.id
	var ids: Array[StringName] = []
	var cds: Array[float] = []
	var act: Array[float] = []
	var dirs: Array[Vector2] = []
	var anchors: Array[Vector2] = []
	var form_cds: Array[float] = []
	for slot: CharacterSkill in skills:
		ids.append(slot.data.id)
		cds.append(slot.cooldown_remaining)
		act.append(slot.active_remaining)
		dirs.append(slot.direction)
		anchors.append(slot.anchor)
		form_cds.append(slot.form_weapon.cooldown if slot.form_weapon != null else 0.0)
	s[StateField.SKILL_IDS] = ids
	s[StateField.SKILL_COOLDOWNS] = cds
	s[StateField.SKILL_ACTIVE] = act
	s[StateField.SKILL_DIRECTIONS] = dirs
	s[StateField.SKILL_ANCHORS] = anchors
	s[StateField.SKILL_WEAPON_COOLDOWNS] = form_cds
	s[StateField.WEAPON_ID] = weapon.data.id
	s[StateField.WEAPON_COOLDOWN] = weapon.cooldown
	s[StateField.PREV_SKILLS] = _prev_skills.duplicate()
	s[StateField.DEAD] = dead
	s[StateField.RESPAWN_TIMER] = respawn_timer
	s[StateField.LAST_INPUT_SEQ] = last_input_seq
	s[StateField.SLOW_REMAINING] = stats.slow_remaining
	s[StateField.SLOW_FACTOR] = stats.slow_factor
	s[StateField.STUN_REMAINING] = stats.stun_remaining
	s[StateField.SPAWN_PROTECT] = stats.spawn_protect
	return s


## Adopt authoritative state from the server. Snapshots only come from the server
## (authority RPC), so this checks shape, not trust.
func apply_state(s: Array, catalog: WeaponCatalog, characters: CharacterCatalog) -> bool:
	if s.size() != StateField.COUNT:
		return false
	if s[StateField.CHARACTER] != character.id:
		var c: CharacterData = characters.get_character(s[StateField.CHARACTER])
		if c != null:
			set_character(c)
	global_position = s[StateField.POSITION]
	velocity = s[StateField.VELOCITY]
	facing = s[StateField.FACING]
	stats.hp = s[StateField.HP]
	stats.armor = s[StateField.ARMOR]
	stats.energy = s[StateField.ENERGY]
	stats.energy_accum = s[StateField.ENERGY_ACCUM]
	stats.time_since_damage = s[StateField.TIME_SINCE_DAMAGE]
	stats.regen_accum = s[StateField.REGEN_ACCUM]
	stats.invulnerable_time = s[StateField.INVULNERABLE]
	var ids: Array = s[StateField.SKILL_IDS]
	for i: int in mini(ids.size(), skills.size()):
		if ids[i] != skills[i].data.id:
			var sd: SkillData = SkillCatalog.shared().get_skill(ids[i])
			if sd != null:
				skills[i] = CharacterSkill.new(sd)
		var slot: CharacterSkill = skills[i]
		slot.cooldown_remaining = s[StateField.SKILL_COOLDOWNS][i]
		slot.active_remaining = s[StateField.SKILL_ACTIVE][i]
		slot.direction = s[StateField.SKILL_DIRECTIONS][i]
		slot.anchor = s[StateField.SKILL_ANCHORS][i]
		if slot.form_weapon != null:
			slot.form_weapon.cooldown = s[StateField.SKILL_WEAPON_COOLDOWNS][i]
	if s[StateField.WEAPON_ID] != weapon.data.id:
		var w: WeaponData = catalog.get_weapon(s[StateField.WEAPON_ID])
		if w != null:
			chosen_weapon = w
			weapon = WeaponState.new(w)
	weapon.cooldown = s[StateField.WEAPON_COOLDOWN]
	var prev: Array = s[StateField.PREV_SKILLS]
	for i: int in mini(prev.size(), _prev_skills.size()):
		_prev_skills[i] = prev[i]
	respawn_timer = s[StateField.RESPAWN_TIMER]
	last_input_seq = s[StateField.LAST_INPUT_SEQ]
	stats.slow_remaining = s[StateField.SLOW_REMAINING]
	stats.slow_factor = s[StateField.SLOW_FACTOR]
	stats.stun_remaining = s[StateField.STUN_REMAINING]
	stats.spawn_protect = s[StateField.SPAWN_PROTECT]
	_set_dead(s[StateField.DEAD])
	_sync_shields()
	return true


## Ground layer (under the sprite child): the shadow under the feet.
func _draw() -> void:
	draw_set_transform(visual_offset + Vector2(0.0, FOOT_RING_Y), 0.0, Vector2(1.0, FOOT_RING_SQUASH))
	draw_circle(Vector2.ZERO, Constants.PLAYER_RADIUS, SHADOW_COLOR)
	if stats.spawn_protect > 0.0:  # a pulsing ring on the floor round the protected player
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * TAU * SPAWN_SHIMMER_HZ)
		var ring_color: Color = SPAWN_RING_COLOR
		ring_color.a = 0.5 + 0.4 * pulse
		draw_arc(Vector2.ZERO, Constants.PLAYER_RADIUS * (1.35 + 0.15 * pulse), 0.0, TAU, 32, ring_color, 3.0)


func _draw_overlay() -> void:
	if _gun_fade > 0.0 and held_weapon().data.sprite != null and held_weapon().data.held_art:
		_draw_guns(_overlay)
		_draw_head_over_weapon()
	_overlay.draw_set_transform(visual_offset)
	if not is_local:
		_draw_bars(Constants.PLAYER_RADIUS)


## The held weapon is left out while a pose replaces him: morph, grapple zip, swing, staff whirl / plant, petals, flare, step
## (the staff is in the spin / plant pose).
func _gun_suppressed() -> bool:
	return _special_fx.hides_owner() or _special_fx.is_swinging() or active_skill(SkillData.Kind.WHIRL) != null \
		or active_skill(SkillData.Kind.PILLAR) != null or _special_fx.is_petals() or _special_fx.is_flaring() \
		or _special_fx.is_stepping()


func _draw_head_over_weapon() -> void:
	var tex: Texture2D = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null or not _sprite.visible:
		return
	var cell: Vector2 = tex.get_size()
	_overlay.draw_set_transform(_sprite.position, 0.0, _sprite.scale * Vector2(-1.0 if _sprite.flip_h else 1.0, 1.0))
	_overlay.draw_texture_rect_region(tex, Rect2(-cell * 0.5, Vector2(cell.x, SPRITE_HEAD_ROWS)),
		Rect2(0, 0, cell.x, SPRITE_HEAD_ROWS), _sprite.modulate)


func _draw_guns(ci: CanvasItem) -> void:
	_draw_gun(ci, Vector2.ZERO)


func _draw_gun(ci: CanvasItem, offset: Vector2) -> void:
	var w: WeaponData = held_weapon().data
	if w.sprite == null or not w.held_art:
		return  # e.g. a transformed form's fists
	# Mirror vertically when aiming left so the grip stays below the barrel.
	var flip_v: float = -1.0 if facing.x < 0.0 else 1.0
	var t: float = _recoil / _recoil_len  # 1 the moment the attack starts, 0 at rest
	var angle: float = facing.angle()
	var hold: float = 0.0
	if w.kind != WeaponData.Kind.MELEE:
		hold -= GUN_RECOIL_PX * t
		angle -= deg_to_rad(GUN_KICK_DEG) * t * flip_v
	elif w.thrust:
		hold += w.melee_range * THRUST_REACH * sin(t * PI)
	elif _recoil > 0.0:
		angle += deg_to_rad(w.melee_arc_deg) * (0.5 - t) * flip_v
	else:
		angle -= deg_to_rad(MELEE_REST_DEG) * flip_v
	var scale_px: float = Constants.SPRITE_SCALE
	var hand_at: Vector2 = visual_offset + offset + hand_offset(facing) + facing * hold
	var tint := Color(1, 1, 1, _gun_alpha * _gun_fade)
	if w.upright:  # an orb: not turned with the aim, so its flames rise; mirrored to face the aim
		ci.draw_set_transform(hand_at, 0.0, Vector2(scale_px * flip_v, scale_px))
	else:
		ci.draw_set_transform(hand_at, angle, Vector2(scale_px, scale_px * flip_v))
	w.draw_held(ci, WEAPON_GRIP, tint)


func _draw_bars(r: float) -> void:
	var top_left := Vector2(-BAR_WIDTH * 0.5, -r - BAR_OFFSET_Y - BAR_HEIGHT * 2.0 - BAR_GAP)
	var armor_frac: float = float(stats.armor) / float(maxi(1, stats.max_armor))
	var hp_frac: float = float(stats.hp) / float(maxi(1, stats.max_hp))
	_overlay.draw_rect(Rect2(top_left, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BG)
	_overlay.draw_rect(Rect2(top_left, Vector2(BAR_WIDTH * armor_frac, BAR_HEIGHT)), COLOR_ARMOR)
	var hp_pos: Vector2 = top_left + Vector2(0.0, BAR_HEIGHT + BAR_GAP)
	_overlay.draw_rect(Rect2(hp_pos, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BG)
	_overlay.draw_rect(Rect2(hp_pos, Vector2(BAR_WIDTH * hp_frac, BAR_HEIGHT)), COLOR_HP)
