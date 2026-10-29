class_name Arena
extends Node2D
## The game world: map, players, projectiles, pickups, scoring, respawns and the match loop.
## Same class in every mode: OFFLINE (local vs bots), SERVER (authoritative, headless) and
## CLIENT (predicted view; match state and pickups mirrored from the server).

signal kill_registered(killer_id: int, victim_id: int)
## Match state or roster changed (UI refresh; the server re-broadcasts the state).
signal match_updated
## The local player pressed Ready / picked a mode in the lobby. Offline these go straight to
## the MatchController; online the client forwards them to the server.
signal ready_requested(is_ready: bool)
signal mode_requested(mode: MatchRules.Mode)
signal shot_fired(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName)
signal player_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, damage: int, crit: bool, at: Vector2)

enum Mode { OFFLINE, SERVER, CLIENT }

## Everyone starts with just the free sidearm; better guns come from pickups.
const DEFAULT_LOADOUT: Array[StringName] = [&"pistol"]
const BOT_LOADOUT: Array[StringName] = [&"bot_blaster"]
const PICKUP_WEAPONS: Array[StringName] = [&"smg", &"shotgun"]
const PLAYER_COLORS: Array[Color] = [
	Color(0.35, 0.75, 1.0), Color(0.95, 0.45, 0.4), Color(0.75, 0.5, 0.95),
	Color(0.5, 0.9, 0.45), Color(1.0, 0.8, 0.3), Color(0.3, 0.9, 0.85),
]
## Placeholder player names until accounts (M6).
const PLAYER_COLOR_NAMES: Array[String] = ["Blue", "Red", "Purple", "Green", "Yellow", "Teal"]
const FLOOR_COLOR: Color = Color(0.13, 0.14, 0.17)
const FLOOR_GRID_COLOR: Color = Color(0.16, 0.17, 0.21)
const WALL_COLOR: Color = Color(0.32, 0.34, 0.42)
const WALL_TOP_COLOR: Color = Color(0.42, 0.45, 0.55)
const WALL_TOP_INSET: float = 4.0
const GRID_LINE_WIDTH: float = 1.0
const PROJECTILE_Z: int = 1

var mode: Mode
var match_seed: int
var map: ArenaMap
var players: Array[Player] = []
var local_player: Player
var projectiles: ProjectilePool
var pickups: PickupField
## Runs the match (null on clients, where the server does); match_state is always set.
var referee: MatchController
var match_state: MatchState
var catalog: WeaponCatalog
var scores := ScoreBoard.new()
var camera: Camera2D
var hud: Hud

var _by_id: Dictionary[int, Player] = {}
var _threats := PackedVector2Array()
var _human_ids: Array[int] = []
var _bot_ids: Array[int] = []


func _init(p_mode: Mode = Mode.OFFLINE, p_match_seed: int = Constants.DEFAULT_MATCH_SEED,
		match_mode: MatchRules.Mode = MatchRules.Mode.FFA, time_limit: float = Constants.MATCH_TIME_LIMIT) -> void:
	mode = p_mode
	match_seed = p_match_seed
	name = "Arena"
	catalog = WeaponCatalog.load_all()
	map = ArenaMap.parse(ArenaLayouts.PIT, Constants.TILE_SIZE)
	projectiles = ProjectilePool.new()
	projectiles.name = "Projectiles"
	projectiles.authoritative = mode != Mode.CLIENT
	projectiles.z_index = PROJECTILE_Z
	pickups = PickupField.new()
	pickups.name = "Pickups"
	pickups.authoritative = mode != Mode.CLIENT
	pickups.setup(map, catalog, PICKUP_WEAPONS, match_seed)
	if mode == Mode.CLIENT:
		match_state = MatchState.new()
	else:
		referee = MatchController.new()
		match_state = referee.state
		match_state.mode = match_mode
		match_state.time_limit = time_limit
		referee.changed.connect(match_updated.emit)
		referee.phase_changed.connect(_on_phase_changed)
		ready_requested.connect(func(is_ready: bool) -> void:
			if local_player != null:
				referee.set_ready(local_player.player_id, is_ready))
		mode_requested.connect(referee.set_mode)


func _ready() -> void:
	_build_walls()
	add_child(pickups)
	add_child(projectiles)
	projectiles.player_hit.connect(player_hit.emit)


func add_player(id: int, color_index: int, loadout_ids: Array[StringName], ctrl: PlayerController,
		is_bot: bool = false) -> Player:
	var p := Player.new()
	p.name = "Player%d" % id
	p.is_bot = is_bot
	var color: Color = PLAYER_COLORS[color_index % PLAYER_COLORS.size()]
	p.setup(id, color_index, color, catalog.resolve(loadout_ids), ctrl, projectiles, match_seed)
	add_child(p)
	p.global_position = _pick_spawn_for(p)
	p.frozen = match_state.inputs_locked()
	if mode != Mode.CLIENT and not match_state.may_respawn(id):
		p.sit_out()
	p.died.connect(_on_player_died)
	p.shot_fired.connect(_on_player_shot)
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


## Client: adopt the server's match state, running phase side effects on a phase change.
func apply_match_state(a: Array) -> void:
	var before: MatchState.Phase = match_state.phase
	if not match_state.apply_array(a):
		return
	if match_state.phase != before:
		_on_phase_changed(match_state.phase)
	match_updated.emit()


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

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = Constants.CAMERA_SMOOTHING
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map.size.x)
	camera.limit_bottom = int(map.size.y)
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
				_place_participants()
		MatchState.Phase.RESULTS:
			projectiles.clear()
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


func _on_player_died(victim: Player, killer_id: int) -> void:
	scores.register_kill(killer_id, victim.player_id)
	kill_registered.emit(killer_id, victim.player_id)


func _on_player_shot(shooter: Player, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName) -> void:
	shot_fired.emit(shooter.player_id, seq, origin, facing, weapon_id)


func _build_walls() -> void:
	var body := StaticBody2D.new()
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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, map.size), FLOOR_COLOR)
	var tile: float = Constants.TILE_SIZE
	var x: float = 0.0
	while x <= map.size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, map.size.y), FLOOR_GRID_COLOR, GRID_LINE_WIDTH)
		x += tile
	var y: float = 0.0
	while y <= map.size.y:
		draw_line(Vector2(0.0, y), Vector2(map.size.x, y), FLOOR_GRID_COLOR, GRID_LINE_WIDTH)
		y += tile
	for rect: Rect2 in map.walls:
		draw_rect(rect, WALL_COLOR)
		draw_rect(rect.grow(-WALL_TOP_INSET), WALL_TOP_COLOR)
