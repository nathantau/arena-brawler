class_name Arena
extends Node2D
## M1 local sandbox: builds the map, one local player and dummy bots, camera and UI.

const WEAPON_CATALOG_PATHS: Array[String] = [
	"res://data/weapons/pistol.tres",
	"res://data/weapons/smg.tres",
	"res://data/weapons/shotgun.tres",
]
const BOT_WEAPON_PATH: String = "res://data/weapons/bot_blaster.tres"
const LOCAL_PLAYER_ID: int = 1
const LOCAL_COLOR: Color = Color(0.35, 0.75, 1.0)
const BOT_COLORS: Array[Color] = [Color(0.95, 0.45, 0.4), Color(0.75, 0.5, 0.95), Color(0.5, 0.9, 0.45)]
const FLOOR_COLOR: Color = Color(0.13, 0.14, 0.17)
const FLOOR_GRID_COLOR: Color = Color(0.16, 0.17, 0.21)
const WALL_COLOR: Color = Color(0.32, 0.34, 0.42)
const WALL_TOP_COLOR: Color = Color(0.42, 0.45, 0.55)
const WALL_TOP_INSET: float = 4.0
const GRID_LINE_WIDTH: float = 1.0
const TOUCH_FLAG: String = "--touch"

var map: ArenaMap
var players: Array[Player] = []
var local_player: Player
var projectiles: ProjectilePool
var weapon_catalog: Array[WeaponData] = []
var scores := ScoreBoard.new()
var camera: Camera2D

var _local_input: LocalInput
var _threats := PackedVector2Array()


func _ready() -> void:
	InputSetup.ensure_actions()
	for path: String in WEAPON_CATALOG_PATHS:
		weapon_catalog.append(load(path) as WeaponData)
	map = ArenaMap.parse(ArenaLayouts.PIT, Constants.TILE_SIZE)
	_build_walls()

	projectiles = ProjectilePool.new()
	projectiles.name = "Projectiles"

	var ui := CanvasLayer.new()
	ui.name = "UI"
	var touch := TouchControls.new()
	touch.visible = _touch_enabled()
	var hud := Hud.new()

	_local_input = LocalInput.new()
	_local_input.arena = self
	_local_input.touch = touch
	var local_loadout: Array[WeaponData] = [weapon_catalog[0], weapon_catalog[2]]
	local_player = _spawn_player(LOCAL_PLAYER_ID, LOCAL_COLOR, local_loadout, _local_input)
	local_player.is_local = true

	var bot_weapon: WeaponData = load(BOT_WEAPON_PATH) as WeaponData
	var bot_loadout: Array[WeaponData] = [bot_weapon]
	for i: int in Constants.BOT_COUNT:
		var id: int = LOCAL_PLAYER_ID + 1 + i
		var brain := BotBrain.new(self, Constants.DEFAULT_MATCH_SEED + id)
		_spawn_player(id, BOT_COLORS[i % BOT_COLORS.size()], bot_loadout, brain)

	add_child(projectiles)  # after players so bullets draw on top

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = Constants.CAMERA_SMOOTHING
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map.size.x)
	camera.limit_bottom = int(map.size.y)
	add_child(camera)
	camera.global_position = local_player.global_position
	camera.reset_smoothing()

	touch.player = local_player
	hud.player = local_player
	hud.scores = scores
	add_child(ui)
	ui.add_child(hud)
	ui.add_child(touch)


func _touch_enabled() -> bool:
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		return true
	if OS.get_cmdline_user_args().has(TOUCH_FLAG):
		Input.emulate_touch_from_mouse = true
		return true
	return false


func _spawn_player(id: int, color: Color, weapons: Array[WeaponData], ctrl: PlayerController) -> Player:
	var p := Player.new()
	p.name = "Player%d" % id
	p.setup(id, color, weapons, ctrl, projectiles, Constants.DEFAULT_MATCH_SEED * id)
	add_child(p)
	p.global_position = map.spawns[(id - 1) % map.spawns.size()]
	p.died.connect(_on_player_died)
	players.append(p)
	return p


func _physics_process(delta: float) -> void:
	for p: Player in players:
		if not p.dead:
			continue
		p.respawn_timer -= delta
		if p.respawn_timer <= 0.0:
			p.respawn(_pick_spawn_for(p))
	if local_player != null and not local_player.dead:
		camera.global_position = local_player.global_position + local_player.facing * Constants.CAMERA_LOOKAHEAD


func _pick_spawn_for(who: Player) -> Vector2:
	_threats.clear()
	for p: Player in players:
		if p != who and not p.dead:
			_threats.append(p.global_position)
	return ArenaMap.pick_spawn(map.spawns, _threats)


func _on_player_died(victim: Player, killer_id: int) -> void:
	scores.register_kill(killer_id, victim.player_id)


## Dev-only (M1, no pickups yet): cycle the active slot through the weapon catalog.
func dev_cycle_weapon(p: Player) -> void:
	var current: WeaponData = p.loadout.active().data
	var idx: int = weapon_catalog.find(current)
	p.loadout.replace_active(weapon_catalog[(idx + 1) % weapon_catalog.size()])


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
