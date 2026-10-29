class_name Player
extends CharacterBody2D
## A fighter in the arena. All gameplay goes through simulate(InputFrame, delta) so the
## same path runs on the server, offline, and for client-side prediction/replay.
## Players collide with walls only (not each other), which keeps prediction exact.

signal died(victim: Player, killer_id: int)
signal shot_fired(shooter: Player, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName)

## Layout of capture_state() / apply_state() arrays sent in snapshots.
enum StateField {
	ID, POSITION, VELOCITY, FACING,
	HP, ARMOR, ENERGY, TIME_SINCE_DAMAGE, REGEN_ACCUM, INVULNERABLE,
	DASH_COOLDOWN, DASH_ACTIVE, DASH_DIRECTION,
	ACTIVE_SLOT, WEAPON_IDS, WEAPON_COOLDOWNS,
	PREV_SKILL, PREV_SWAP, DEAD, RESPAWN_TIMER, LAST_INPUT_SEQ,
	COUNT,
}

const OUTLINE_WIDTH: float = 2.0
const OUTLINE_DARKEN: float = 0.5
const CIRCLE_SEGMENTS: int = 24
const GUN_LENGTH: float = 14.0
const GUN_WIDTH: float = 6.0
const GUN_RECOIL_PX: float = 4.0
const RECOIL_TIME: float = 0.06
const INVULN_ALPHA: float = 0.45
const BAR_WIDTH: float = 40.0
const BAR_HEIGHT: float = 4.0
const BAR_GAP: float = 2.0
const BAR_OFFSET_Y: float = 10.0
const TARGET_RING_PAD: float = 8.0
const TARGET_RING_WIDTH: float = 2.0
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
var stats := PlayerStats.new()
var loadout: Loadout
## Loadout restored on every respawn (pickups are lost on death).
var default_weapons: Array[WeaponData] = []
var dash := DashSkill.new()
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
var _prev_skill: bool = false
var _prev_swap: bool = false
var _hit_flash: float = 0.0
var _recoil: float = 0.0


func setup(id: int, p_color_index: int, color: Color, weapons: Array[WeaponData], ctrl: PlayerController,
		pool: ProjectilePool, p_match_seed: int) -> void:
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
	queue_redraw()


## Advance this player by one input. `replay` = re-simulating already-predicted inputs
## during reconciliation: state changes happen, side effects (spawning shots) don't.
func simulate(input: InputFrame, delta: float, replay: bool = false) -> void:
	last_input_seq = input.seq
	if dead:
		return
	stats.tick(delta)
	dash.tick(delta)
	loadout.tick(delta)
	if frozen:
		# Keep edge state current so a button held through the countdown doesn't fire on release.
		_prev_swap = input.swap
		_prev_skill = input.skill
		velocity = Vector2.ZERO
		return

	if input.swap and not _prev_swap:
		loadout.swap()
	if input.skill and not _prev_skill:
		var dash_dir: Vector2 = input.move_vec if input.move_vec.length() > Constants.INPUT_DEADZONE else facing
		dash.try_activate(dash_dir, stats)
	_prev_swap = input.swap
	_prev_skill = input.skill

	velocity = MovementSim.step_velocity(velocity, input.move_vec, dash, delta)
	move_and_slide()

	if input.aim_vec.length_squared() > 0.0:
		facing = input.aim_vec.normalized()
	elif input.move_vec.length() > Constants.INPUT_DEADZONE:
		facing = input.move_vec.normalized()

	if input.fire and not dash.is_active():
		_try_fire(input.seq, replay)


func _try_fire(seq: int, replay: bool) -> void:
	var weapon: WeaponState = loadout.active()
	if not weapon.try_fire(stats) or replay:
		return
	var origin: Vector2 = global_position
	projectiles.fire_shot(player_id, seq, origin, facing, weapon.data, match_seed)
	play_recoil()
	shot_fired.emit(self, seq, origin, facing, weapon.data.id)


func play_recoil() -> void:
	_recoil = RECOIL_TIME


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
	dash.reset()
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
	s[StateField.DASH_COOLDOWN] = dash.cooldown_remaining
	s[StateField.DASH_ACTIVE] = dash.active_remaining
	s[StateField.DASH_DIRECTION] = dash.direction
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
func apply_state(s: Array, catalog: WeaponCatalog) -> bool:
	if s.size() != StateField.COUNT:
		return false
	global_position = s[StateField.POSITION]
	velocity = s[StateField.VELOCITY]
	facing = s[StateField.FACING]
	stats.hp = s[StateField.HP]
	stats.armor = s[StateField.ARMOR]
	stats.energy = s[StateField.ENERGY]
	stats.time_since_damage = s[StateField.TIME_SINCE_DAMAGE]
	stats.regen_accum = s[StateField.REGEN_ACCUM]
	stats.invulnerable_time = s[StateField.INVULNERABLE]
	dash.cooldown_remaining = s[StateField.DASH_COOLDOWN]
	dash.active_remaining = s[StateField.DASH_ACTIVE]
	dash.direction = s[StateField.DASH_DIRECTION]
	loadout.sync(s[StateField.WEAPON_IDS], s[StateField.WEAPON_COOLDOWNS], s[StateField.ACTIVE_SLOT], catalog)
	_prev_skill = s[StateField.PREV_SKILL]
	_prev_swap = s[StateField.PREV_SWAP]
	respawn_timer = s[StateField.RESPAWN_TIMER]
	last_input_seq = s[StateField.LAST_INPUT_SEQ]
	_set_dead(s[StateField.DEAD])
	return true


func _draw() -> void:
	draw_set_transform(visual_offset)
	var body: Color = Color.WHITE if _hit_flash > 0.0 else display_color
	if stats.is_invulnerable():
		body.a = INVULN_ALPHA
	var r: float = Constants.PLAYER_RADIUS
	var recoil_px: float = GUN_RECOIL_PX * (_recoil / RECOIL_TIME)
	var gun_start: Vector2 = facing * (r * 0.5 - recoil_px)
	var gun_end: Vector2 = facing * (r + GUN_LENGTH - recoil_px)
	draw_line(gun_start, gun_end, loadout.active().data.color, GUN_WIDTH)
	draw_circle(Vector2.ZERO, r, body)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, CIRCLE_SEGMENTS, display_color.darkened(OUTLINE_DARKEN), OUTLINE_WIDTH)
	if targeted:
		draw_arc(Vector2.ZERO, r + TARGET_RING_PAD, 0.0, TAU, CIRCLE_SEGMENTS, COLOR_TARGET, TARGET_RING_WIDTH)
	if not is_local:
		_draw_bars(r)


func _draw_bars(r: float) -> void:
	var top_left := Vector2(-BAR_WIDTH * 0.5, -r - BAR_OFFSET_Y - BAR_HEIGHT * 2.0 - BAR_GAP)
	var armor_frac: float = float(stats.armor) / float(maxi(1, stats.max_armor))
	var hp_frac: float = float(stats.hp) / float(maxi(1, stats.max_hp))
	draw_rect(Rect2(top_left, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BG)
	draw_rect(Rect2(top_left, Vector2(BAR_WIDTH * armor_frac, BAR_HEIGHT)), COLOR_ARMOR)
	var hp_pos: Vector2 = top_left + Vector2(0.0, BAR_HEIGHT + BAR_GAP)
	draw_rect(Rect2(hp_pos, Vector2(BAR_WIDTH, BAR_HEIGHT)), COLOR_BAR_BG)
	draw_rect(Rect2(hp_pos, Vector2(BAR_WIDTH * hp_frac, BAR_HEIGHT)), COLOR_HP)
