class_name Player
extends CharacterBody2D
## A fighter in the arena. All gameplay goes through simulate(InputFrame, delta) so the
## same path runs on the server, offline, and for client-side prediction/replay.
## Players collide with walls only (not each other), which keeps prediction exact.

signal died(victim: Player, killer_id: int)
signal shot_fired(shooter: Player, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName, dual: bool)
## Predicted/authoritative skill activation (not emitted during replay). For effects/SFX.
signal skill_used(user: Player, skill: SkillData)

## Layout of capture_state() / apply_state() arrays sent in snapshots.
enum StateField {
	ID, POSITION, VELOCITY, FACING,
	HP, ARMOR, ENERGY, TIME_SINCE_DAMAGE, REGEN_ACCUM, INVULNERABLE,
	CHARACTER, DASH_COOLDOWN, DASH_ACTIVE, DASH_DIRECTION,
	SPECIAL_ID, SPECIAL_COOLDOWN, SPECIAL_ACTIVE, SPECIAL_DIRECTION, SPECIAL_ANCHOR, SPECIAL_WEAPON_COOLDOWN,
	ACTIVE_SLOT, WEAPON_IDS, WEAPON_COOLDOWNS,
	PREV_DASH, PREV_SPECIAL, PREV_SWAP, DEAD, RESPAWN_TIMER, LAST_INPUT_SEQ,
	COUNT,
}

## Weapon art (WeaponData.sprite) is drawn at the character's pixel scale, pivoting on its grip.
const WEAPON_GRIP: Vector2 = Vector2(6, 12)
## The front hand (generate.py arm() at ARM_X[1]) in local px, mirrored when facing left: weapon grips sit on it.
const WEAPON_HAND: Vector2 = Vector2(20, 22)
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
## Volley shots get their own key space so they never collide with the same frame's normal shot.
const VOLLEY_SEQ_OFFSET: int = 1 << 24
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
const RING_WIDTH: float = 2.0
const TARGET_RING_PAD: float = 8.0
const DUAL_GLOW_PAD: float = 3.0
## Coloured ellipse under the feet: the player's colour, squashed for a top-down look.
const FOOT_RING_SQUASH: float = 0.45
const FOOT_RING_Y: float = 40.0
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.3)
const CIRCLE_SEGMENTS: int = 24
const COLOR_HP: Color = Color(0.9, 0.25, 0.25)
const COLOR_ARMOR: Color = Color(0.7, 0.75, 0.85)
const COLOR_BAR_BG: Color = Color(0, 0, 0, 0.5)
const COLOR_TARGET: Color = Color(1, 0.3, 0.3, 0.9)

var player_id: int = 0
var color_index: int = 0
var display_color: Color = Color.WHITE
var is_local: bool = false
var is_bot: bool = false
## Countdown / results screen: inputs are ignored (timers still run).
var frozen: bool = false
var character: CharacterData
var stats := PlayerStats.new()
var loadout: Loadout
## Loadout restored on every respawn (pickups are lost on death).
var default_weapons: Array[WeaponData] = []
## Picked in the loading room: carried next to the signature weapon from every spawn.
var starting_weapon: WeaponData
## The shared Dash and the special picked in the loading room.
var dash: CharacterSkill
var special: CharacterSkill
var facing: Vector2 = Vector2.RIGHT
## Null for client-side remote players (they are positioned by interpolation).
var controller: PlayerController
var projectiles: ProjectilePool
var match_seed: int = 0
var dead: bool = false
var respawn_timer: float = 0.0
var last_input_seq: int = 0
## Set by the local player's input when this player is the current auto-aim target.
var targeted: bool = false
## Render-only offset that hides small reconciliation corrections; decays to zero.
var visual_offset: Vector2 = Vector2.ZERO

var _shape: CollisionShape2D
var _shield := ShieldWall.new()
var _prev_dash: bool = false
var _prev_special: bool = false
var _prev_swap: bool = false
var _hit_flash: float = 0.0
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
var _clone_query := PhysicsRayQueryParameters2D.new()


func setup(id: int, p_color_index: int, color: Color, weapons: Array[WeaponData], ctrl: PlayerController,
		pool: ProjectilePool, p_match_seed: int, p_character: CharacterData) -> void:
	player_id = id
	color_index = p_color_index
	display_color = color
	default_weapons = weapons
	loadout = Loadout.new(weapons)
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
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * Constants.SPRITE_SCALE
	add_child(_sprite)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	add_child(_special_fx)
	_clone_query.collision_mask = Constants.LAYER_WALLS
	set_character(p_character)


## Switch character (lobby pick or a snapshot saying so): new stat maxes, fresh skills. Keeps
## the picked special and starting weapon if the new character can use them.
func set_character(data: CharacterData) -> void:
	character = data
	stats = PlayerStats.new(data.max_hp, data.max_armor, data.max_energy)
	dash = CharacterSkill.new(SkillCatalog.shared().dash())
	var keep: SkillData = special.data if special != null and data.can_use_skill(special.data) else null
	set_special(keep if keep != null else SkillCatalog.shared().specials_for(data)[0])
	_sprite.sprite_frames = data.sprite_frames()
	_sprite.play(&"idle")
	if starting_weapon != null and not data.can_use(starting_weapon):
		starting_weapon = null
	_reset_loadout()


func set_special(data: SkillData) -> void:
	special = CharacterSkill.new(data)
	_shield.sync(special, dead)


func set_starting_weapon(weapon: WeaponData) -> void:
	starting_weapon = weapon
	_reset_loadout()


## Bots keep the loadout they were set up with.
func _reset_loadout() -> void:
	if is_bot or character.signature_weapon == null:
		return
	default_weapons = [character.signature_weapon]
	if starting_weapon != null:
		default_weapons.append(starting_weapon)
	loadout = Loadout.new(default_weapons)


func _physics_process(delta: float) -> void:
	if controller == null:
		return
	var input: InputFrame = controller.get_input(self, delta)
	while input != null:
		simulate(input, delta)
		input = controller.next_extra_input()


func _process(delta: float) -> void:
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
	var frames: SpriteFrames = special.data.form_frames() if special.is_transformed() else character.sprite_frames()
	if _sprite.sprite_frames != frames:
		_sprite.sprite_frames = frames
		_sprite.scale = Vector2.ONE * Constants.SPRITE_SCALE * (special.data.form_scale if special.is_transformed() else 1.0)
		_sprite.play(anim)
	if _sprite.animation != anim:
		_sprite.play(anim)
	_sprite.position = visual_offset
	_sprite.flip_h = facing.x < 0.0
	_special_fx.sync(self)
	_sprite.modulate.a = 0.0 if _special_fx.is_morphing() else \
		INVULN_ALPHA if stats.is_invulnerable() or is_hidden() else 1.0
	queue_redraw()
	_overlay.queue_redraw()


## Advance this player by one input. `replay` = re-simulating already-predicted inputs
## during reconciliation: state changes happen, side effects (spawning shots) don't.
func simulate(input: InputFrame, delta: float, replay: bool = false) -> void:
	last_input_seq = input.seq
	if dead:
		return
	stats.tick(delta)
	dash.tick(delta)
	special.tick(delta)
	loadout.tick(delta)
	if frozen:
		# Keep edge state current so a button held through the countdown doesn't fire on release.
		_prev_swap = input.swap
		_prev_dash = input.skill
		_prev_special = input.special
		velocity = Vector2.ZERO
		_shield.sync(special, dead)
		return

	if input.swap and not _prev_swap:
		loadout.swap()
	if input.skill and not _prev_dash:
		_activate(dash, input, replay)
	if input.special and not _prev_special:
		_activate(special, input, replay)
	_prev_swap = input.swap
	_prev_dash = input.skill
	_prev_special = input.special

	var mover: CharacterSkill = special if special.is_dashing() else dash
	var speed: float = character.move_speed * (special.data.form_speed_scale if special.is_transformed() else 1.0)
	velocity = MovementSim.step_velocity(velocity, input.move_vec, mover, speed, delta)
	move_and_slide()
	_shield.sync(special, dead)

	if input.aim_vec.length_squared() > 0.0:
		facing = input.aim_vec.normalized()
	elif input.move_vec.length() > Constants.INPUT_DEADZONE:
		facing = input.move_vec.normalized()

	if _windup_left >= 0.0 and not replay:  # replays re-run inputs already counted: don't land it early
		_windup_left -= delta
		if _windup_left <= 0.0:
			_windup_left = -1.0
			_release_shot(_windup_seq, _windup_weapon)
	if input.fire and not is_dashing():
		_try_fire(input.seq, replay)


func _activate(slot: CharacterSkill, input: InputFrame, replay: bool) -> void:
	if not slot.try_activate(_skill_direction(slot.data, input), global_position, stats):
		return
	match slot.data.kind:
		SkillData.Kind.BLINK:
			move_and_collide(slot.direction * slot.data.blink_distance)  # walls stop the hop
		SkillData.Kind.VOLLEY:
			if not replay:
				var seq: int = input.seq + VOLLEY_SEQ_OFFSET
				projectiles.fire_shot(player_id, seq, global_position, slot.direction, slot.data.volley_weapon, match_seed)
				shot_fired.emit(self, seq, global_position, slot.direction, slot.data.volley_weapon.id, false)
	if not replay:
		skill_used.emit(self, slot.data)


## Inside your own smoke: enemy auto-aim and bots can't lock on.
func is_hidden() -> bool:
	return special.is_smoking() and global_position.distance_to(special.anchor) <= special.data.smoke_radius


## Where this player's shadow clones are right now (empty unless cloning). A pure function of the
## synced special state and the walls, so every peer (and the server's bots) sees the same clones.
func clone_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	if dead or not special.is_cloning():
		return out
	var d: SkillData = special.data
	var t: float = maxf(0.0, special.elapsed() - CLONE_EMERGE_TIME)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for k: int in d.clone_count:
		var angle: float = special.direction.angle() + deg_to_rad(d.clone_spread_deg) * (k - (d.clone_count - 1) * 0.5)
		var run: Vector2 = Vector2.RIGHT.rotated(angle)
		var target: Vector2 = special.anchor + run * minf(CLONE_START_DISTANCE + t * d.clone_speed, d.clone_reach) \
			+ run.orthogonal() * sin(t * CLONE_WOBBLE_SPEED) * CLONE_WOBBLE_PX
		_clone_query.from = special.anchor
		_clone_query.to = target
		var hit: Dictionary = space.intersect_ray(_clone_query)
		if not hit.is_empty():
			target = hit.position - run * Constants.PLAYER_RADIUS
		out.append(target)
	return out


func is_dashing() -> bool:
	return dash.is_dashing() or special.is_dashing()


func is_dual_wielding() -> bool:
	return special.is_dual_wielding()


## The weapon FIRE uses: the transformed form's own weapon, else the loadout's active one.
func held_weapon() -> WeaponState:
	return special.form_weapon if special.is_transformed() else loadout.active()


## Dash goes where you're moving (else where you face); the barrier goes where you aim.
func _skill_direction(data: SkillData, input: InputFrame) -> Vector2:
	var moves: bool = data.kind == SkillData.Kind.DASH or data.kind == SkillData.Kind.BLINK
	if moves and input.move_vec.length() > Constants.INPUT_DEADZONE:
		return input.move_vec
	if input.aim_vec.length_squared() > 0.0:
		return input.aim_vec
	return facing


func _try_fire(seq: int, replay: bool) -> void:
	var weapon: WeaponState = held_weapon()
	if _windup_left >= 0.0 or not weapon.try_fire(stats) or replay:
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
	var dual: bool = is_dual_wielding()
	projectiles.fire_shot(player_id, seq, origin, facing, w, match_seed, dual, character.dual_offset)
	shot_fired.emit(self, seq, origin, facing, w.id, dual)


## Guns fire from the hand holding them (shots then spawn at the barrel tip, WeaponData.muzzle_distance);
## melee swings stay centred on the body.
func shot_origin(w: WeaponData) -> Vector2:
	return global_position + (Vector2.ZERO if w.kind == WeaponData.Kind.MELEE else hand_offset(facing))


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
		Input.vibrate_handheld(Constants.HAPTIC_HIT_MS)


func can_be_hit() -> bool:
	return not dead and not stats.is_invulnerable()


## Authoritative damage entry point (offline / server only). Returns damage dealt.
func take_hit(damage: int, _crit: bool, knockback: Vector2, attacker_id: int) -> int:
	if special.is_transformed():
		damage = maxi(1, roundi(damage * special.data.form_damage_scale))
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
	stats.invulnerable_time = Constants.RESPAWN_IFRAME_TIME
	dash.reset()
	special.reset()
	loadout = Loadout.new(default_weapons)
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
	# A real death (sitting out has no respawn timer) leaves the fall animation behind; on every peer.
	if value and respawn_timer > 0.0 and is_inside_tree():
		_spawn_corpse()
	visible = not value
	_shape.set_deferred("disabled", value)
	_shield.sync(special, dead)


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
	s[StateField.TIME_SINCE_DAMAGE] = stats.time_since_damage
	s[StateField.REGEN_ACCUM] = stats.regen_accum
	s[StateField.INVULNERABLE] = stats.invulnerable_time
	s[StateField.CHARACTER] = character.id
	s[StateField.DASH_COOLDOWN] = dash.cooldown_remaining
	s[StateField.DASH_ACTIVE] = dash.active_remaining
	s[StateField.DASH_DIRECTION] = dash.direction
	s[StateField.SPECIAL_ID] = special.data.id
	s[StateField.SPECIAL_COOLDOWN] = special.cooldown_remaining
	s[StateField.SPECIAL_ACTIVE] = special.active_remaining
	s[StateField.SPECIAL_DIRECTION] = special.direction
	s[StateField.SPECIAL_ANCHOR] = special.anchor
	s[StateField.SPECIAL_WEAPON_COOLDOWN] = special.form_weapon.cooldown if special.form_weapon != null else 0.0
	s[StateField.ACTIVE_SLOT] = loadout.active_index
	s[StateField.WEAPON_IDS] = loadout.weapon_ids()
	s[StateField.WEAPON_COOLDOWNS] = loadout.cooldowns()
	s[StateField.PREV_DASH] = _prev_dash
	s[StateField.PREV_SPECIAL] = _prev_special
	s[StateField.PREV_SWAP] = _prev_swap
	s[StateField.DEAD] = dead
	s[StateField.RESPAWN_TIMER] = respawn_timer
	s[StateField.LAST_INPUT_SEQ] = last_input_seq
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
	stats.time_since_damage = s[StateField.TIME_SINCE_DAMAGE]
	stats.regen_accum = s[StateField.REGEN_ACCUM]
	stats.invulnerable_time = s[StateField.INVULNERABLE]
	if s[StateField.SPECIAL_ID] != special.data.id:
		var sd: SkillData = SkillCatalog.shared().get_skill(s[StateField.SPECIAL_ID])
		if sd != null:
			set_special(sd)
	dash.cooldown_remaining = s[StateField.DASH_COOLDOWN]
	dash.active_remaining = s[StateField.DASH_ACTIVE]
	dash.direction = s[StateField.DASH_DIRECTION]
	special.cooldown_remaining = s[StateField.SPECIAL_COOLDOWN]
	special.active_remaining = s[StateField.SPECIAL_ACTIVE]
	special.direction = s[StateField.SPECIAL_DIRECTION]
	special.anchor = s[StateField.SPECIAL_ANCHOR]
	if special.form_weapon != null:
		special.form_weapon.cooldown = s[StateField.SPECIAL_WEAPON_COOLDOWN]
	loadout.sync(s[StateField.WEAPON_IDS], s[StateField.WEAPON_COOLDOWNS], s[StateField.ACTIVE_SLOT], catalog)
	_prev_dash = s[StateField.PREV_DASH]
	_prev_special = s[StateField.PREV_SPECIAL]
	_prev_swap = s[StateField.PREV_SWAP]
	respawn_timer = s[StateField.RESPAWN_TIMER]
	last_input_seq = s[StateField.LAST_INPUT_SEQ]
	_set_dead(s[StateField.DEAD])
	_shield.sync(special, dead)
	return true


## Ground layer (under the sprite child): shadow, player-colour foot ring, rings.
func _draw() -> void:
	var r: float = Constants.PLAYER_RADIUS
	var gun_color: Color = loadout.active().data.color
	draw_set_transform(visual_offset + Vector2(0.0, FOOT_RING_Y), 0.0, Vector2(1.0, FOOT_RING_SQUASH))
	draw_circle(Vector2.ZERO, r, SHADOW_COLOR)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, CIRCLE_SEGMENTS, display_color, RING_WIDTH)
	if is_dual_wielding():
		draw_arc(Vector2.ZERO, r + DUAL_GLOW_PAD, 0.0, TAU, CIRCLE_SEGMENTS, gun_color, RING_WIDTH)
	if targeted:
		draw_arc(Vector2.ZERO, r + TARGET_RING_PAD, 0.0, TAU, CIRCLE_SEGMENTS, COLOR_TARGET, RING_WIDTH)


func _draw_overlay() -> void:
	if held_weapon().data.sprite != null and held_weapon().data.held_art:
		_draw_guns(_overlay)
		_draw_head_over_weapon()
	_overlay.draw_set_transform(visual_offset)
	if not is_local:
		_draw_bars(Constants.PLAYER_RADIUS)


func _draw_head_over_weapon() -> void:
	var tex: Texture2D = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null or not _sprite.visible:
		return
	var cell: Vector2 = tex.get_size()
	_overlay.draw_set_transform(_sprite.position, 0.0, _sprite.scale * Vector2(-1.0 if _sprite.flip_h else 1.0, 1.0))
	_overlay.draw_texture_rect_region(tex, Rect2(-cell * 0.5, Vector2(cell.x, SPRITE_HEAD_ROWS)),
		Rect2(0, 0, cell.x, SPRITE_HEAD_ROWS), _sprite.modulate)


func _draw_guns(ci: CanvasItem) -> void:
	if is_dual_wielding():
		var side: Vector2 = facing.orthogonal() * character.dual_offset
		_draw_gun(ci, side)
		_draw_gun(ci, -side)
	else:
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
	var tint := Color(1, 1, 1, _sprite.modulate.a)
	ci.draw_set_transform(hand_at, angle, Vector2(scale_px, scale_px * flip_v))
	ci.draw_texture(w.sprite, -WEAPON_GRIP, tint)


func _draw_bars(r: float) -> void:
	var top_left := Vector2(-BAR_WIDTH * 0.5, -r - BAR_OFFSET_Y - BAR_HEIGHT * 2.0 - BAR_GAP)
	var armor_frac: float = float(stats.armor) / float(maxi(1, stats.max_armor))
	var hp_frac: float = float(stats.hp) / float(maxi(1, stats.max_hp))
	_overlay.draw_rect(Rect2(top_left, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BG)
	_overlay.draw_rect(Rect2(top_left, Vector2(BAR_WIDTH * armor_frac, BAR_HEIGHT)), COLOR_ARMOR)
	var hp_pos: Vector2 = top_left + Vector2(0.0, BAR_HEIGHT + BAR_GAP)
	_overlay.draw_rect(Rect2(hp_pos, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BG)
	_overlay.draw_rect(Rect2(hp_pos, Vector2(BAR_WIDTH * hp_frac, BAR_HEIGHT)), COLOR_HP)
