class_name Player
extends CharacterBody2D
## A fighter in the arena. All gameplay goes through simulate(InputFrame, delta) so the
## same path can run on the server and for client-side prediction.

signal died(victim: Player, killer_id: int)

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
var display_color: Color = Color.WHITE
var is_local: bool = false
var stats := PlayerStats.new()
var loadout: Loadout
var dash := DashSkill.new()
var facing: Vector2 = Vector2.RIGHT
var controller: PlayerController
var projectiles: ProjectilePool
var rng := RandomNumberGenerator.new()
var dead: bool = false
var respawn_timer: float = 0.0
var last_input_seq: int = 0
## Set by the local player's input when this player is the current auto-aim target.
var targeted: bool = false

var _shape: CollisionShape2D
var _prev_skill: bool = false
var _prev_swap: bool = false
var _hit_flash: float = 0.0
var _recoil: float = 0.0


func setup(id: int, color: Color, weapons: Array[WeaponData], ctrl: PlayerController, pool: ProjectilePool, sim_seed: int) -> void:
	player_id = id
	display_color = color
	loadout = Loadout.new(weapons)
	controller = ctrl
	projectiles = pool
	rng.seed = sim_seed
	collision_layer = Constants.LAYER_PLAYERS
	collision_mask = Constants.LAYER_WALLS | Constants.LAYER_PLAYERS
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var circle := CircleShape2D.new()
	circle.radius = Constants.PLAYER_RADIUS
	_shape = CollisionShape2D.new()
	_shape.shape = circle
	add_child(_shape)


func _physics_process(delta: float) -> void:
	if dead:
		return
	simulate(controller.get_input(self, delta), delta)
	queue_redraw()


func simulate(input: InputFrame, delta: float) -> void:
	last_input_seq = input.seq
	stats.tick(delta)
	dash.tick(delta)
	loadout.tick(delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_recoil = maxf(0.0, _recoil - delta)

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
		_try_fire()


func _try_fire() -> void:
	var weapon: WeaponState = loadout.active()
	if not weapon.try_fire(stats):
		return
	var data: WeaponData = weapon.data
	var crit: bool = CombatRules.roll_crit(data, rng)
	var damage: int = CombatRules.damage_for(data, crit)
	var muzzle_dist: float = Constants.PLAYER_RADIUS + data.projectile_radius + Constants.MUZZLE_OFFSET
	for dir: Vector2 in CombatRules.shot_directions(facing, data, rng):
		projectiles.spawn(player_id, global_position, muzzle_dist, dir, data, damage, crit)
	_recoil = RECOIL_TIME


func can_be_hit() -> bool:
	return not dead and not stats.is_invulnerable()


## Authoritative damage entry point (server only once networked). Returns damage dealt.
func take_hit(damage: int, _crit: bool, knockback: Vector2, attacker_id: int) -> int:
	var dealt: int = stats.apply_damage(damage)
	if dealt <= 0:
		return 0
	velocity += knockback
	_hit_flash = Constants.HIT_FLASH_TIME
	if is_local:
		Input.vibrate_handheld(Constants.HAPTIC_HIT_MS)
	if stats.is_dead():
		_die(attacker_id)
	return dealt


func _die(killer_id: int) -> void:
	dead = true
	respawn_timer = Constants.RESPAWN_DELAY
	visible = false
	velocity = Vector2.ZERO
	_shape.set_deferred("disabled", true)
	died.emit(self, killer_id)


func respawn(at: Vector2) -> void:
	dead = false
	visible = true
	global_position = at
	velocity = Vector2.ZERO
	stats.reset()
	stats.invulnerable_time = Constants.RESPAWN_IFRAME_TIME
	dash.reset()
	loadout.reset_cooldowns()
	_shape.set_deferred("disabled", false)


func _draw() -> void:
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
