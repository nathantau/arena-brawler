class_name Arena
extends Node2D
## The game world: map, players, projectiles, pickups, crates, scoring, respawns and the
## match loop. Same class in every mode: OFFLINE (local vs bots), SERVER (authoritative,
## headless) and CLIENT (predicted view; match state, pickups and crates mirrored from the
## server). Effects, sound and camera shake exist only where there's a local view.

signal kill_registered(killer_id: int, victim_id: int)
## Match state or roster changed (UI refresh; the server re-broadcasts the state).
signal match_updated
## The local player pressed Ready / picked a mode in the lobby. Offline these go straight to
## the MatchController; online the client forwards them to the server.
signal ready_requested(is_ready: bool)
signal mode_requested(mode: MatchRules.Mode)
signal arena_requested(index: int)
signal character_requested(id: StringName)
signal weapon_requested(id: StringName)
signal shot_fired(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName, dual: bool)
## Authoritative damage (offline / server).
signal player_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, damage: int, crit: bool, at: Vector2)
## Cosmetic: damage landed, on every peer (authoritative from player_hit, clients from the server).
signal hit_landed(victim_id: int, damage: int, crit: bool, at: Vector2)

enum Mode { OFFLINE, SERVER, CLIENT }

## Everyone starts with just the free sidearm; better guns come from pickups.
const DEFAULT_LOADOUT: Array[StringName] = [&"pistol"]
const BOT_LOADOUT: Array[StringName] = [&"bot_blaster"]
const PLAYER_COLORS: Array[Color] = [
	Color(0.35, 0.75, 1.0), Color(0.95, 0.45, 0.4), Color(0.75, 0.5, 0.95),
	Color(0.5, 0.9, 0.45), Color(1.0, 0.8, 0.3), Color(0.3, 0.9, 0.85),
]
## Placeholder player names until accounts (M6).
const PLAYER_COLOR_NAMES: Array[String] = ["Blue", "Red", "Purple", "Green", "Yellow", "Teal"]
const PROJECTILE_Z: int = 1
const EFFECTS_Z: int = 2
## Camera shake: offset = SHAKE_MAX_OFFSET * trauma², trauma decays per second.
const SHAKE_MAX_OFFSET: float = 14.0
const SHAKE_DECAY: float = 2.5
const SHAKE_HURT_PER_DAMAGE: float = 0.012
const SHAKE_EXPLOSION: float = 0.6
const SHAKE_EXPLOSION_RANGE: float = 500.0
const HAPTIC_EXPLOSION_RANGE: float = 200.0
const BURST_HIT_COUNT: int = 6
const BURST_HIT_SPEED: float = 220.0
const BURST_DEATH_COUNT: int = 28
const BURST_DEATH_SPEED: float = 320.0
const BURST_EXPLOSION_COUNT: int = 30
const BURST_CRATE_COUNT: int = 16
const BURST_PICKUP_COUNT: int = 12
const BURST_SKILL_COUNT: int = 10
const BURST_MUZZLE_COUNT: int = 4
const BURST_MUZZLE_SPEED: float = 260.0
const BURST_MUZZLE_SPREAD: float = 0.8
const PARTICLE_SIZE: float = 4.0
const PARTICLE_LIFE: float = 0.35
const CRATE_DEBRIS_COLOR: Color = Color(0.55, 0.4, 0.25)
const BEAM_WIDTH_SCALE: float = 2.0
const THRUST_FX_WIDTH: float = 7.0

var mode: Mode
var match_seed: int
var map: ArenaMap
var players: Array[Player] = []
var local_player: Player
var projectiles: ProjectilePool
var pickups: PickupField
var crates: CrateField
var layout_index: int = -1
## Runs the match (null on clients, where the server does); match_state is always set.
var referee: MatchController
var match_state: MatchState
var catalog: WeaponCatalog
var characters: CharacterCatalog
var scores := ScoreBoard.new()
var camera: Camera2D
var hud: Hud
var effects: Effects
var sfx: Sfx

var _by_id: Dictionary[int, Player] = {}
var _threats := PackedVector2Array()
var _human_ids: Array[int] = []
var _bot_ids: Array[int] = []
var _walls: StaticBody2D
var _floor := ArenaFloor.new()
var _trauma: float = 0.0
var _shake_rng := RandomNumberGenerator.new()


func _init(p_mode: Mode = Mode.OFFLINE, p_match_seed: int = Constants.DEFAULT_MATCH_SEED,
		match_mode: MatchRules.Mode = MatchRules.Mode.FFA, time_limit: float = Constants.MATCH_TIME_LIMIT) -> void:
	mode = p_mode
	match_seed = p_match_seed
	name = "Arena"
	catalog = WeaponCatalog.load_all()
	characters = CharacterCatalog.load_all()
	projectiles = ProjectilePool.new()
	projectiles.name = "Projectiles"
	projectiles.authoritative = mode != Mode.CLIENT
	projectiles.z_index = PROJECTILE_Z
	pickups = PickupField.new()
	pickups.name = "Pickups"
	pickups.authoritative = mode != Mode.CLIENT
	crates = CrateField.new()
	crates.name = "Crates"
	if mode == Mode.CLIENT:
		match_state = MatchState.new()
	else:
		referee = MatchController.new()
		match_state = referee.state
		match_state.mode = match_mode
		match_state.time_limit = time_limit
		referee.changed.connect(_on_referee_changed)
		referee.phase_changed.connect(_on_phase_changed)
		ready_requested.connect(func(is_ready: bool) -> void:
			if local_player != null:
				referee.set_ready(local_player.player_id, is_ready))
		mode_requested.connect(referee.set_mode)
		arena_requested.connect(referee.set_arena)
		character_requested.connect(func(id: StringName) -> void:
			if local_player != null:
				select_character(local_player, id))
		weapon_requested.connect(func(id: StringName) -> void:
			if local_player != null:
				select_weapon(local_player, id))


func _ready() -> void:
	_floor.name = "Floor"
	add_child(_floor)
	add_child(crates)
	add_child(pickups)
	add_child(projectiles)
	projectiles.player_hit.connect(_on_projectile_hit)
	_load_layout(match_state.arena_index)


## Build walls, crates and pickups for a layout. Authoritative callers then respawn players.
func _load_layout(index: int) -> void:
	layout_index = index
	map = ArenaMap.parse(ArenaLayouts.get_layout(index), Constants.TILE_SIZE)
	if _walls != null:
		remove_child(_walls)
		_walls.queue_free()
	_build_walls()
	_floor.setup(map, ArenaLayouts.THEMES[index])
	crates.setup(map, _floor.tiles)
	pickups.setup(map, catalog, catalog.pickup_ids(), match_seed)
	projectiles.clear()
	if camera != null:
		_set_camera_limits()


func add_player(id: int, color_index: int, loadout_ids: Array[StringName], ctrl: PlayerController,
		is_bot: bool = false) -> Player:
	var p := Player.new()
	p.name = "Player%d" % id
	p.is_bot = is_bot
	var color: Color = PLAYER_COLORS[color_index % PLAYER_COLORS.size()]
	var character: CharacterData = characters.default_character()
	if is_bot:
		character = characters.ordered[id % characters.ordered.size()]
	p.setup(id, color_index, color, catalog.resolve(loadout_ids), ctrl, projectiles, match_seed, character)
	add_child(p)
	p.global_position = _pick_spawn_for(p)
	p.frozen = match_state.inputs_locked()
	if mode != Mode.CLIENT and not match_state.may_respawn(id):
		p.sit_out()
	p.died.connect(_on_player_died)
	p.shot_fired.connect(_on_player_shot)
	p.skill_used.connect(_on_skill_used)
	players.append(p)
	_by_id[id] = p
	if is_bot:
		_bot_ids.append(id)
	else:
		_human_ids.append(id)
	match_updated.emit()
	return p


func add_bot(id: int, color_index: int) -> Player:
	return add_player(id, color_index, BOT_LOADOUT, BotBrain.new(self, match_seed + id), true)


func remove_player(id: int) -> void:
	var p: Player = _by_id.get(id)
	if p == null:
		return
	_by_id.erase(id)
	players.erase(p)
	_human_ids.erase(id)
	_bot_ids.erase(id)
	if p == local_player:
		local_player = null
	p.queue_free()
	if referee != null:
		referee.remove_player(id, scores)
	match_updated.emit()


func get_player(id: int) -> Player:
	return _by_id.get(id)


func player_name(id: int) -> String:
	var p: Player = get_player(id)
	if p == null:
		return "(left)"
	var n: String = PLAYER_COLOR_NAMES[p.color_index % PLAYER_COLOR_NAMES.size()]
	return n + " bot" if p.is_bot else n


func player_color(id: int) -> Color:
	var p: Player = get_player(id)
	return p.display_color if p != null else Color.GRAY


## Lobby only (authoritative): switch a player's character. Takes effect immediately.
func select_character(p: Player, id: StringName) -> void:
	var c: CharacterData = characters.get_character(id)
	if c == null or c == p.character or match_state.phase != MatchState.Phase.LOBBY:
		return
	p.set_character(c)
	match_updated.emit()


## Lobby only (authoritative): the weapon a player starts with besides their signature one.
## Must be a pickup weapon their character can use.
func select_weapon(p: Player, id: StringName) -> void:
	var w: WeaponData = catalog.get_weapon(id)
	if w == null or not w.pickup or not p.character.can_use(w) or match_state.phase != MatchState.Phase.LOBBY:
		return
	p.set_starting_weapon(w)
	match_updated.emit()


## Weapons `c` may start with, in catalog order (what the loading room offers).
func starting_weapons_for(c: CharacterData) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for id: StringName in catalog.pickup_ids():
		if c.can_use(catalog.get_weapon(id)):
			out.append(catalog.get_weapon(id))
	return out


## Client: adopt the server's match state, running phase side effects on a phase change.
func apply_match_state(a: Array) -> void:
	var before: MatchState.Phase = match_state.phase
	if not match_state.apply_array(a):
		return
	if match_state.arena_index != layout_index:
		_load_layout(match_state.arena_index)
	if match_state.phase != before:
		_on_phase_changed(match_state.phase)
	match_updated.emit()


## Client: the server reported damage (cosmetic only).
func report_hit(victim_id: int, damage: int, crit: bool, at: Vector2) -> void:
	hit_landed.emit(victim_id, damage, crit, at)


## Client: the server reported a kill.
func report_kill(killer_id: int, victim_id: int) -> void:
	scores.register_kill(killer_id, victim_id)
	kill_registered.emit(killer_id, victim_id)


## Lowest palette index not used by a current player.
func free_color_index() -> int:
	var used: Array[int] = []
	for p: Player in players:
		used.append(p.color_index)
	var i: int = 0
	while used.has(i):
		i += 1
	return i


## Camera + HUD + touch controls for the player this device controls.
func attach_local_view(p: Player, input: LocalInput) -> void:
	local_player = p
	p.is_local = true
	pickups.viewer = p

	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * Constants.CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = Constants.CAMERA_SMOOTHING
	_set_camera_limits()
	add_child(camera)
	camera.global_position = p.global_position
	camera.reset_smoothing()

	var ui := CanvasLayer.new()
	ui.name = "UI"
	hud = Hud.new()
	hud.player = p
	hud.scores = scores
	hud.arena = self
	var touch := TouchControls.new()
	touch.player = p
	touch.visible = TouchControls.should_enable()
	hud.show_skill = not touch.visible
	var lobby := LobbyPanel.new()
	lobby.arena = self
	var results := ResultsPanel.new()
	results.arena = self
	touch.blockers = [lobby]
	add_child(ui)
	ui.add_child(hud)
	ui.add_child(touch)
	ui.add_child(lobby)
	ui.add_child(results)

	input.arena = self
	input.touch = touch
	_attach_effects()


func _set_camera_limits() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map.size.x)
	camera.limit_bottom = int(map.size.y)


func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _attach_effects() -> void:
	effects = Effects.new()
	effects.name = "Effects"
	effects.z_index = EFFECTS_Z
	add_child(effects)
	sfx = Sfx.new()
	sfx.name = "Sfx"
	sfx.listener = local_player
	add_child(sfx)
	projectiles.shot_spawned.connect(_fx_shot)
	projectiles.beam_drawn.connect(func(from: Vector2, to: Vector2, w: WeaponData) -> void:
		effects.beam(from, to, w.color, w.projectile_radius * BEAM_WIDTH_SCALE))
	projectiles.swung.connect(func(origin: Vector2, facing: Vector2, w: WeaponData) -> void:
		if w.thrust:
			var tip: Vector2 = origin + facing * (w.melee_range + Constants.PLAYER_RADIUS)
			effects.beam(origin + facing * Constants.PLAYER_RADIUS, tip, w.color, THRUST_FX_WIDTH)
		else:
			effects.swing(origin, facing, w.melee_range, w.melee_arc_deg, w.color))
	projectiles.exploded.connect(_fx_explosion)
	hit_landed.connect(_fx_hit)
	kill_registered.connect(_fx_kill)
	pickups.collected.connect(func(at: Vector2, _kind: PickupField.Kind) -> void:
		effects.burst(at, Color.WHITE, BURST_PICKUP_COUNT, BURST_HIT_SPEED, PARTICLE_SIZE, PARTICLE_LIFE)
		sfx.play(&"pickup", at))
	crates.destroyed.connect(func(at: Vector2) -> void:
		effects.burst(at, CRATE_DEBRIS_COLOR, BURST_CRATE_COUNT, BURST_DEATH_SPEED, PARTICLE_SIZE * 1.5, PARTICLE_LIFE * 1.5)
		sfx.play(&"crate", at))


func _fx_shot(owner_id: int, origin: Vector2, facing: Vector2, w: WeaponData) -> void:
	var muzzle: Vector2 = origin + facing * (Constants.PLAYER_RADIUS + Constants.MUZZLE_OFFSET)
	effects.burst(muzzle, w.color, BURST_MUZZLE_COUNT, BURST_MUZZLE_SPEED, PARTICLE_SIZE * 0.6, PARTICLE_LIFE * 0.4,
		facing, BURST_MUZZLE_SPREAD)
	sfx.play(w.sfx, origin)
	if local_player != null and owner_id == local_player.player_id:
		add_shake(w.screen_shake)


func _fx_explosion(at: Vector2, radius: float, color: Color) -> void:
	effects.ring(at, radius, color)
	effects.burst(at, color, BURST_EXPLOSION_COUNT, BURST_DEATH_SPEED, PARTICLE_SIZE * 1.5, PARTICLE_LIFE * 1.5)
	sfx.play(&"explosion", at)
	if local_player != null:
		var d: float = local_player.global_position.distance_to(at)
		add_shake(SHAKE_EXPLOSION * clampf(1.0 - d / SHAKE_EXPLOSION_RANGE, 0.0, 1.0))
		if d < HAPTIC_EXPLOSION_RANGE:
			Input.vibrate_handheld(Constants.HAPTIC_EXPLOSION_MS)


func _fx_hit(victim_id: int, damage: int, crit: bool, at: Vector2) -> void:
	var victim: Player = get_player(victim_id)
	var color: Color = victim.display_color if victim != null else Color.WHITE
	effects.burst(at, color, BURST_HIT_COUNT, BURST_HIT_SPEED, PARTICLE_SIZE, PARTICLE_LIFE)
	effects.damage_number(at, damage, crit)
	if victim != null and victim == local_player:
		sfx.play(&"hurt")
		add_shake(SHAKE_HURT_PER_DAMAGE * damage)
	else:
		sfx.play(&"crit" if crit else &"hit", at)


func _fx_kill(killer_id: int, victim_id: int) -> void:
	var victim: Player = get_player(victim_id)
	if victim != null:
		effects.burst(victim.global_position, victim.display_color, BURST_DEATH_COUNT, BURST_DEATH_SPEED,
			PARTICLE_SIZE * 1.5, PARTICLE_LIFE * 2.0)
		sfx.play(&"death", victim.global_position)
	if local_player != null and killer_id == local_player.player_id:
		Input.vibrate_handheld(Constants.HAPTIC_KILL_MS)


func _on_skill_used(user: Player) -> void:
	if effects == null:
		return
	effects.burst(user.global_position, user.display_color, BURST_SKILL_COUNT, BURST_HIT_SPEED, PARTICLE_SIZE,
		PARTICLE_LIFE)
	match user.character.skill:
		CharacterData.SkillKind.DASH:
			sfx.play(&"dash", user.global_position)
		CharacterData.SkillKind.SHIELD:
			sfx.play(&"shield", user.global_position)
		CharacterData.SkillKind.DUAL_WIELD:
			sfx.play(&"dual", user.global_position)


func _process(delta: float) -> void:
	if camera == null:
		return
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
	var amount: float = _trauma * _trauma * SHAKE_MAX_OFFSET
	camera.offset = Vector2(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0)) * amount


func _physics_process(delta: float) -> void:
	if mode != Mode.CLIENT:
		referee.tick(delta, _human_ids, _bot_ids, scores)
		pickups.tick(delta, players)
		_tick_respawns(delta)
	elif match_state.phase != MatchState.Phase.LOBBY:
		# Display only; the server sends the real value on every phase change.
		match_state.time_left = maxf(0.0, match_state.time_left - delta)
	if camera != null and local_player != null and not local_player.dead:
		camera.global_position = local_player.global_position + local_player.facing * Constants.CAMERA_LOOKAHEAD


func _tick_respawns(delta: float) -> void:
	for p: Player in players:
		if not p.dead:
			continue
		p.respawn_timer -= delta
		if p.respawn_timer <= 0.0 and match_state.may_respawn(p.player_id):
			p.respawn(_pick_spawn_for(p))


## Side effects of entering a phase, on every peer. Positions are authoritative-only; clients
## get them from snapshots.
func _on_phase_changed(phase: MatchState.Phase) -> void:
	match phase:
		MatchState.Phase.COUNTDOWN:
			scores.reset()
			projectiles.clear()
			if mode != Mode.CLIENT:
				pickups.reset()
				crates.reset()
				_place_participants()
		MatchState.Phase.RESULTS:
			projectiles.clear()
	if sfx != null:
		match phase:
			MatchState.Phase.COUNTDOWN:
				sfx.play(&"countdown")
			MatchState.Phase.PLAYING:
				sfx.play(&"go")
			MatchState.Phase.RESULTS:
				sfx.play(&"results")
	var locked: bool = match_state.inputs_locked()
	for p: Player in players:
		p.frozen = locked


## Start of a match: everyone off the field, then participants spawn one at a time so each
## picks the spawn farthest from those already placed.
func _place_participants() -> void:
	for p: Player in players:
		p.sit_out()
	for id: int in match_state.participants:
		var p: Player = get_player(id)
		if p != null:
			p.respawn(_pick_spawn_for(p))


func _pick_spawn_for(who: Player) -> Vector2:
	_threats.clear()
	for p: Player in players:
		if p != who and not p.dead:
			_threats.append(p.global_position)
	return ArenaMap.pick_spawn(map.spawns, _threats)


## Authoritative: re-broadcast, and switch layout (everyone respawns) if the lobby picked another.
func _on_referee_changed() -> void:
	if match_state.arena_index != layout_index:
		_load_layout(match_state.arena_index)
		for p: Player in players:
			p.sit_out()
	match_updated.emit()


func _on_projectile_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, damage: int, crit: bool,
		at: Vector2) -> void:
	player_hit.emit(owner_id, shot_seq, pellet, victim_id, damage, crit, at)
	hit_landed.emit(victim_id, damage, crit, at)


func _on_player_died(victim: Player, killer_id: int) -> void:
	scores.register_kill(killer_id, victim.player_id)
	kill_registered.emit(killer_id, victim.player_id)


func _on_player_shot(shooter: Player, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName,
		dual: bool) -> void:
	shot_fired.emit(shooter.player_id, seq, origin, facing, weapon_id, dual)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	_walls = body
	body.name = "Walls"
	body.collision_layer = Constants.LAYER_WALLS
	body.collision_mask = 0
	for rect: Rect2 in map.walls:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = rect.get_center()
		body.add_child(cs)
	add_child(body)
	queue_redraw()
