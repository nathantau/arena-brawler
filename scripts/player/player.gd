class_name Player
extends CharacterBody2D
## A fighter in the arena. All gameplay goes through simulate(InputFrame, delta) so the
## same path runs on the server, offline, and for client-side prediction/replay.
## Players collide with walls only (not each other), which keeps prediction exact.

signal died(victim: Player, killer_id: int)
signal shot_fired(shooter: Player, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName, dual: bool)
## Predicted/authoritative skill activation (not emitted during replay). For effects/SFX.
signal skill_used(user: Player)

## Layout of capture_state() / apply_state() arrays sent in snapshots.
enum StateField {
	ID, POSITION, VELOCITY, FACING,
	HP, ARMOR, ENERGY, TIME_SINCE_DAMAGE, REGEN_ACCUM, INVULNERABLE,
	CHARACTER, SKILL_COOLDOWN, SKILL_ACTIVE, SKILL_DIRECTION, SKILL_ANCHOR,
	ACTIVE_SLOT, WEAPON_IDS, WEAPON_COOLDOWNS,
	PREV_SKILL, PREV_SWAP, DEAD, RESPAWN_TIMER, LAST_INPUT_SEQ,
	COUNT,
}

## Weapon art (WeaponData.sprite) is drawn at the character's pixel scale, pivoting on its grip.
const WEAPON_GRIP: Vector2 = Vector2(6, 12)
const WEAPON_HOLD_DISTANCE: float = 14.0
## Hands sit below the sprite's centre.
const WEAPON_HAND_Y: float = 12.0
const GUN_RECOIL_PX: float = 4.0
const GUN_KICK_DEG: float = 14.0
const RECOIL_TIME: float = 0.06
## Melee animation: a sweep across the arc (or a stab out and back), starting from a raised guard.
const MELEE_ANIM_TIME: float = 0.16
const MELEE_REST_DEG: float = 35.0
const THRUST_REACH: float = 0.6
const INVULN_ALPHA: float = 0.45
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
var skill := CharacterSkill.new()
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
var _prev_skill: bool = false
var _prev_swap: bool = false
var _hit_flash: float = 0.0
## Attack animation time left, and its full length (depends on the weapon used).
var _recoil: float = 0.0
var _recoil_len: float = RECOIL_TIME
var _sprite := AnimatedSprite2D.new()
## Drawn after the sprite: the gun when it's in front of the body, and health bars.
var _overlay := Node2D.new()


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
	collision_mask = Constants.LAYER_WALLS
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
	set_character(p_character)


## Switch character (lobby pick or a snapshot saying so): new stat maxes, fresh skill.
func set_character(data: CharacterData) -> void:
	character = data
	stats = PlayerStats.new(data.max_hp, data.max_armor, data.max_energy)
	skill = CharacterSkill.new(data)
	_shield.sync(skill, dead)
	_sprite.sprite_frames = data.sprite_frames()
	_sprite.play(&"idle")
	if starting_weapon != null and not data.can_use(starting_weapon):
		starting_weapon = null
	_reset_loadout()


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
	var anim: StringName = &"idle"
	if _hit_flash > 0.0:
		anim = &"hit"
	elif velocity.length() > Constants.SPRITE_WALK_MIN_SPEED:
		anim = &"walk"
	if _sprite.animation != anim:
		_sprite.play(anim)
	_sprite.position = visual_offset
	_sprite.flip_h = facing.x < 0.0
	_sprite.modulate.a = INVULN_ALPHA if stats.is_invulnerable() else 1.0
	queue_redraw()
	_overlay.queue_redraw()


## Advance this player by one input. `replay` = re-simulating already-predicted inputs
## during reconciliation: state changes happen, side effects (spawning shots) don't.
func simulate(input: InputFrame, delta: float, replay: bool = false) -> void:
	last_input_seq = input.seq
	if dead:
		return
	stats.tick(delta)
	skill.tick(delta)
	loadout.tick(delta)
	if frozen:
		# Keep edge state current so a button held through the countdown doesn't fire on release.
		_prev_swap = input.swap
		_prev_skill = input.skill
		velocity = Vector2.ZERO
		_shield.sync(skill, dead)
		return

	if input.swap and not _prev_swap:
		loadout.swap()
	if input.skill and not _prev_skill:
		if skill.try_activate(_skill_direction(input), global_position, stats) and not replay:
			skill_used.emit(self)
	_prev_swap = input.swap
	_prev_skill = input.skill

	velocity = MovementSim.step_velocity(velocity, input.move_vec, skill, character.move_speed, delta)
	move_and_slide()
	_shield.sync(skill, dead)

	if input.aim_vec.length_squared() > 0.0:
		facing = input.aim_vec.normalized()
	elif input.move_vec.length() > Constants.INPUT_DEADZONE:
		facing = input.move_vec.normalized()

	if input.fire and not skill.is_dashing():
		_try_fire(input.seq, replay)


## Dash goes where you're moving (else where you face); the barrier goes where you aim.
func _skill_direction(input: InputFrame) -> Vector2:
	if character.skill == CharacterData.SkillKind.DASH and input.move_vec.length() > Constants.INPUT_DEADZONE:
		return input.move_vec
	if input.aim_vec.length_squared() > 0.0:
		return input.aim_vec
	return facing


func _try_fire(seq: int, replay: bool) -> void:
	var weapon: WeaponState = loadout.active()
	if not weapon.try_fire(stats) or replay:
		return
	var origin: Vector2 = global_position
	var dual: bool = skill.is_dual_wielding()
	projectiles.fire_shot(player_id, seq, origin, facing, weapon.data, match_seed, dual, character.dual_offset)
	play_recoil()
	shot_fired.emit(self, seq, origin, facing, weapon.data.id, dual)


func play_recoil() -> void:
	_recoil_len = MELEE_ANIM_TIME if loadout.active().data.kind == WeaponData.Kind.MELEE else RECOIL_TIME
	_recoil = _recoil_len


func flash() -> void:
	_hit_flash = Constants.HIT_FLASH_TIME
	if is_local:
		Input.vibrate_handheld(Constants.HAPTIC_HIT_MS)


func can_be_hit() -> bool:
	return not dead and not stats.is_invulnerable()


## Authoritative damage entry point (offline / server only). Returns damage dealt.
func take_hit(damage: int, _crit: bool, knockback: Vector2, attacker_id: int) -> int:
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
	skill.reset()
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
	visible = not value
	_shape.set_deferred("disabled", value)
	_shield.sync(skill, dead)


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
	s[StateField.SKILL_COOLDOWN] = skill.cooldown_remaining
	s[StateField.SKILL_ACTIVE] = skill.active_remaining
	s[StateField.SKILL_DIRECTION] = skill.direction
	s[StateField.SKILL_ANCHOR] = skill.anchor
	s[StateField.ACTIVE_SLOT] = loadout.active_index
	s[StateField.WEAPON_IDS] = loadout.weapon_ids()
	s[StateField.WEAPON_COOLDOWNS] = loadout.cooldowns()
	s[StateField.PREV_SKILL] = _prev_skill
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
	skill.cooldown_remaining = s[StateField.SKILL_COOLDOWN]
	skill.active_remaining = s[StateField.SKILL_ACTIVE]
	skill.direction = s[StateField.SKILL_DIRECTION]
	skill.anchor = s[StateField.SKILL_ANCHOR]
	loadout.sync(s[StateField.WEAPON_IDS], s[StateField.WEAPON_COOLDOWNS], s[StateField.ACTIVE_SLOT], catalog)
	_prev_skill = s[StateField.PREV_SKILL]
	_prev_swap = s[StateField.PREV_SWAP]
	respawn_timer = s[StateField.RESPAWN_TIMER]
	last_input_seq = s[StateField.LAST_INPUT_SEQ]
	_set_dead(s[StateField.DEAD])
	_shield.sync(skill, dead)
	return true


## Ground layer (under the sprite child): shadow, player-colour foot ring, rings, gun when aiming up.
func _draw() -> void:
	var r: float = Constants.PLAYER_RADIUS
	var gun_color: Color = loadout.active().data.color
	draw_set_transform(visual_offset + Vector2(0.0, FOOT_RING_Y), 0.0, Vector2(1.0, FOOT_RING_SQUASH))
	draw_circle(Vector2.ZERO, r, SHADOW_COLOR)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, CIRCLE_SEGMENTS, display_color, RING_WIDTH)
	if skill.is_dual_wielding():
		draw_arc(Vector2.ZERO, r + DUAL_GLOW_PAD, 0.0, TAU, CIRCLE_SEGMENTS, gun_color, RING_WIDTH)
	if targeted:
		draw_arc(Vector2.ZERO, r + TARGET_RING_PAD, 0.0, TAU, CIRCLE_SEGMENTS, COLOR_TARGET, RING_WIDTH)
	if facing.y < 0.0:
		_draw_guns(self)


func _draw_overlay() -> void:
	if facing.y >= 0.0:
		_draw_guns(_overlay)
	_overlay.draw_set_transform(visual_offset)
	if not is_local:
		_draw_bars(Constants.PLAYER_RADIUS)


func _draw_guns(ci: CanvasItem) -> void:
	if skill.is_dual_wielding():
		var side: Vector2 = facing.orthogonal() * character.dual_offset
		_draw_gun(ci, side)
		_draw_gun(ci, -side)
	else:
		_draw_gun(ci, Vector2.ZERO)


func _draw_gun(ci: CanvasItem, offset: Vector2) -> void:
	var w: WeaponData = loadout.active().data
	# Mirror vertically when aiming left so the grip stays below the barrel.
	var flip_v: float = -1.0 if facing.x < 0.0 else 1.0
	var t: float = _recoil / _recoil_len  # 1 the moment the attack starts, 0 at rest
	var angle: float = facing.angle()
	var hold: float = WEAPON_HOLD_DISTANCE
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
	ci.draw_set_transform(visual_offset + offset + Vector2(0.0, WEAPON_HAND_Y) + facing * hold, angle, Vector2(scale_px, scale_px * flip_v))
	ci.draw_texture(w.sprite, -WEAPON_GRIP, Color(1, 1, 1, _sprite.modulate.a))


func _draw_bars(r: float) -> void:
	var top_left := Vector2(-BAR_WIDTH * 0.5, -r - BAR_OFFSET_Y - BAR_HEIGHT * 2.0 - BAR_GAP)
	var armor_frac: float = float(stats.armor) / float(maxi(1, stats.max_armor))
	var hp_frac: float = float(stats.hp) / float(maxi(1, stats.max_hp))
	_overlay.draw_rect(Rect2(top_left, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BG)
	_overlay.draw_rect(Rect2(top_left, Vector2(BAR_WIDTH * armor_frac, BAR_HEIGHT)), COLOR_ARMOR)
	var hp_pos: Vector2 = top_left + Vector2(0.0, BAR_HEIGHT + BAR_GAP)
	_overlay.draw_rect(Rect2(hp_pos, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BG)
	_overlay.draw_rect(Rect2(hp_pos, Vector2(BAR_WIDTH * hp_frac, BAR_HEIGHT)), COLOR_HP)
