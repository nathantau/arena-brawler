class_name Arena
extends Node2D
## The game world: map, players, projectiles, scoring and respawns. Same class in every mode:
## OFFLINE (local sandbox), SERVER (authoritative, headless) and CLIENT (predicted view).

signal kill_registered(killer_id: int, victim_id: int)
signal shot_fired(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName)
signal player_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, damage: int, crit: bool, at: Vector2)

enum Mode { OFFLINE, SERVER, CLIENT }

const DEFAULT_LOADOUT: Array[StringName] = [&"pistol", &"shotgun"]
const BOT_LOADOUT: Array[StringName] = [&"bot_blaster"]
## Dev-only weapon cycling order (offline, until pickups exist).
const DEV_CYCLE_WEAPONS: Array[StringName] = [&"pistol", &"smg", &"shotgun"]
const PLAYER_COLORS: Array[Color] = [
	Color(0.35, 0.75, 1.0), Color(0.95, 0.45, 0.4), Color(0.75, 0.5, 0.95),
	Color(0.5, 0.9, 0.45), Color(1.0, 0.8, 0.3), Color(0.3, 0.9, 0.85),
]
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
var catalog: WeaponCatalog
var scores := ScoreBoard.new()
var camera: Camera2D
var hud: Hud

var _by_id: Dictionary[int, Player] = {}
var _threats := PackedVector2Array()


func _init(p_mode: Mode = Mode.OFFLINE, p_match_seed: int = Constants.DEFAULT_MATCH_SEED) -> void:
	mode = p_mode
	match_seed = p_match_seed
	name = "Arena"
	catalog = WeaponCatalog.load_all()
	map = ArenaMap.parse(ArenaLayouts.PIT, Constants.TILE_SIZE)
	projectiles = ProjectilePool.new()
	projectiles.name = "Projectiles"
	projectiles.authoritative = mode != Mode.CLIENT
	projectiles.z_index = PROJECTILE_Z


func _ready() -> void:
	_build_walls()
	add_child(projectiles)
	projectiles.player_hit.connect(player_hit.emit)


func add_player(id: int, color_index: int, loadout_ids: Array[StringName], ctrl: PlayerController) -> Player:
	var p := Player.new()
	p.name = "Player%d" % id
	var color: Color = PLAYER_COLORS[color_index % PLAYER_COLORS.size()]
	p.setup(id, color_index, color, catalog.resolve(loadout_ids), ctrl, projectiles, match_seed)
	add_child(p)
	p.global_position = _pick_spawn_for(p)
	p.died.connect(_on_player_died)
	p.shot_fired.connect(_on_player_shot)
	players.append(p)
	_by_id[id] = p
	return p


func add_bot(id: int, color_index: int) -> Player:
	return add_player(id, color_index, BOT_LOADOUT, BotBrain.new(self, match_seed + id))


func remove_player(id: int) -> void:
	var p: Player = _by_id.get(id)
	if p == null:
		return
	_by_id.erase(id)
	players.erase(p)
	if p == local_player:
		local_player = null
	p.queue_free()


func get_player(id: int) -> Player:
	return _by_id.get(id)


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
	var touch := TouchControls.new()
	touch.player = p
	touch.show_dev_button = mode == Mode.OFFLINE
	touch.visible = TouchControls.should_enable()
	add_child(ui)
	ui.add_child(hud)
	ui.add_child(touch)

	input.arena = self
	input.touch = touch


func _physics_process(delta: float) -> void:
	if mode != Mode.CLIENT:
		_tick_respawns(delta)
	if camera != null and local_player != null and not local_player.dead:
		camera.global_position = local_player.global_position + local_player.facing * Constants.CAMERA_LOOKAHEAD


func _tick_respawns(delta: float) -> void:
	for p: Player in players:
		if not p.dead:
			continue
		p.respawn_timer -= delta
		if p.respawn_timer <= 0.0:
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


## Dev-only (offline, no pickups yet): cycle the active slot through DEV_CYCLE_WEAPONS.
func dev_cycle_weapon(p: Player) -> void:
	if mode != Mode.OFFLINE:
		return
	var idx: int = DEV_CYCLE_WEAPONS.find(p.loadout.active().data.id)
	var next: WeaponData = catalog.get_weapon(DEV_CYCLE_WEAPONS[(idx + 1) % DEV_CYCLE_WEAPONS.size()])
	p.loadout.replace_active(next)


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
