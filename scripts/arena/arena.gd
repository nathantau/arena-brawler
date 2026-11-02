class_name Arena
extends Node2D
## The game world: map, players, projectiles, crates, scoring, respawns and the
## match loop. Same class in every mode: OFFLINE (local vs bots), SERVER (authoritative,
## headless) and CLIENT (predicted view; match state and crates mirrored from the
## server). Effects, sound and camera shake exist only where there's a local view.

signal kill_registered(killer_id: int, victim_id: int)
## Match state or roster changed (UI refresh; the server re-broadcasts the state).
signal match_updated
## The local player pressed Ready / picked a mode in the lobby. Offline these go straight to
## the MatchController; online the client forwards them to the server.
signal ready_requested(is_ready: bool)
signal mode_requested(mode: MatchRules.Mode)
## Lobby (Teams): the local player picked a team (0 = auto).
signal team_requested(team: int)
## Teams: the lock-in was refused, a teammate (this id) already holds the fighter.
signal lock_refused(holder_id: int)
signal arena_requested(index: int)
signal character_requested(id: StringName)
signal weapon_requested(id: StringName)
signal special_requested(slot: int, id: StringName)
## The local player chose Leave (or Restart, offline) in the pause menu.
signal leave_requested(restart: bool)
signal shot_fired(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName)
## Authoritative damage (offline / server).
signal player_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, damage: int, crit: bool, at: Vector2)
## Cosmetic: damage landed, on every peer (authoritative from player_hit, clients from the server).
signal hit_landed(victim_id: int, damage: int, crit: bool, at: Vector2)

enum Mode { OFFLINE, SERVER, CLIENT }

## Only used by characters without a signature weapon.
const FALLBACK_WEAPON: StringName = &"pistol"
const PLAYER_COLORS: Array[Color] = [
	Color(0.35, 0.75, 1.0), Color(0.95, 0.45, 0.4), Color(0.75, 0.5, 0.95),
	Color(0.5, 0.9, 0.45), Color(1.0, 0.8, 0.3), Color(0.3, 0.9, 0.85),
]
## Placeholder player names until accounts (M6).
const PLAYER_COLOR_NAMES: Array[String] = ["Blue", "Red", "Purple", "Green", "Yellow", "Teal"]
const PROJECTILE_Z: int = 1
## Floor and walls sit under everything, below ground effects (Effects.GROUND_Z).
const FLOOR_Z: int = -2
const EFFECTS_Z: int = 2
## Fighters, crates, wall blocks and upright ability art are y-sorted children of the Arena (z 0), each sorted by its
## foot line (a fighter's node sits Player.FOOT_RING_Y above it: ArtBlock.SORT_LIFT). Flat marks (z -1) sit under all of
## that; projectiles (z 1) and Effects (z 2) over it.
## A fighter hidden behind a wall shows through as a ghost: his colour lightened by GHOST_WHITEN at GHOST_ALPHA.
const GHOST_ALPHA: float = 0.65
const GHOST_WHITEN: float = 0.45
## Only the part of him above his feet can be hidden; his body box for the test (half width, height above the feet).
const GHOST_BODY_HALF_W: float = 22.0
const GHOST_BODY_H: float = 96.0
## Camera shake: offset = SHAKE_MAX_OFFSET * trauma², trauma decays per second.
const SHAKE_MAX_OFFSET: float = 16.0
const SHAKE_DECAY: float = 2.5
const SHAKE_HURT_PER_DAMAGE: float = 0.03
## Every hit on you shakes at least this much (small hits used to be invisible: trauma is squared).
const SHAKE_HURT_MIN: float = 0.2
const SHAKE_DEATH: float = 0.7
const SHAKE_DEALT_KILL: float = 0.3
## Camera look-ahead eases toward the aim direction at this rate (1/s), so flicking the aim doesn't snap the view.
const CAMERA_LOOK_EASE: float = 6.0
## Heartbeat while at or below this fraction of max HP, once per HEARTBEAT_PERIOD (faster when lower).
const LOW_HP_FRACTION: float = 0.3
const HEARTBEAT_PERIOD: float = 0.9
const HEARTBEAT_PERIOD_CRITICAL: float = 0.55
const CRITICAL_HP_FRACTION: float = 0.15
## A dealt hit that crits or kills buzzes the phone; plain hits only tick (SMGs would buzz non-stop).
const RECOIL_KICK: float = 40.0
const HAPTIC_DEATH_MS: int = 90
const FIGHT_BANNER_TIME: float = 0.9
const STREAK_NAMES: Array[String] = ["", "", "DOUBLE KILL", "TRIPLE KILL", "RAMPAGE", "UNSTOPPABLE"]
const SHAKE_SPAWN: float = 0.12
const PICKUP_COLOR: Color = Color(0.4, 1.0, 0.9)
const PICKUP_LABEL_LIFT: float = 30.0
const BURST_PICKUP_COUNT: int = 14
const BURST_PICKUP_SPREAD: float = 1.6
const SHAKE_EXPLOSION: float = 0.6
const SHAKE_EXPLOSION_RANGE: float = 500.0
const HAPTIC_EXPLOSION_RANGE: float = 200.0
const BURST_HIT_COUNT: int = 6
const BURST_HIT_SPEED: float = 220.0
const BURST_DEATH_COUNT: int = 28
const BURST_DEATH_SPEED: float = 320.0
const BURST_EXPLOSION_COUNT: int = 30
const BURST_CRATE_COUNT: int = 16
const BURST_SKILL_COUNT: int = 10
const BURST_MUZZLE_COUNT: int = 4
const BURST_MUZZLE_SPEED: float = 260.0
const BURST_MUZZLE_SPREAD: float = 0.8
const PARTICLE_SIZE: float = 4.0
## Embers rise off a burning fighter from about the waist (px below the node origin).
const EMBER_BODY_Y: float = 6.0
const PARTICLE_LIFE: float = 0.35
const CRATE_DEBRIS_COLOR: Color = Color(0.55, 0.4, 0.25)
const BEAM_WIDTH_SCALE: float = 2.0

var mode: Mode
var match_seed: int
var map: ArenaMap
var players: Array[Player] = []
var local_player: Player
## Lobby (authoritative side): humans who have picked a fighter; the first pick, even of the default one, empties their slots.
var _picked: Dictionary[int, bool] = {}
## Set on a listen-server host: "ip:port" shown in the loading room so friends can join.
var host_address: String = ""
var projectiles: ProjectilePool
var crates: CrateField
var pickups: PickupField
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
var _wall_blocks: Array[ArtBlock] = []
var _ghosted: Array[ArtBlock] = []
var _trauma: float = 0.0
var _look: Vector2 = Vector2.ZERO
var _heartbeat: float = 0.0
var _hit_owner: int = 0
var _streak: int = 0
var _fx_phase: MatchState.Phase = MatchState.Phase.LOBBY
var _fx_round: int = 0
var _flag_bases: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var flags: FlagField
var _client_break: bool = false
var _fx_break: bool = false
var _input: LocalInput
var _shake_rng := RandomNumberGenerator.new()


func _init(p_mode: Mode = Mode.OFFLINE, p_match_seed: int = Constants.DEFAULT_MATCH_SEED,
		match_mode: MatchRules.Mode = MatchRules.Mode.FFA, time_limit: float = Constants.MATCH_TIME_LIMIT) -> void:
	mode = p_mode
	match_seed = p_match_seed
	Player.viewer_team = 0
	name = "Arena"
	y_sort_enabled = true
	catalog = WeaponCatalog.load_all()
	characters = CharacterCatalog.load_all()
	projectiles = ProjectilePool.new()
	projectiles.name = "Projectiles"
	projectiles.authoritative = mode != Mode.CLIENT
	projectiles.targets = players
	projectiles.z_index = PROJECTILE_Z
	crates = CrateField.new()
	crates.name = "Crates"
	pickups = PickupField.new()
	pickups.name = "Pickups"
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
				var holder: int = try_ready(local_player.player_id, is_ready)
				if holder != 0:
					lock_refused.emit(holder))
		mode_requested.connect(referee.set_mode)
		team_requested.connect(func(team: int) -> void:
			if local_player != null:
				referee.set_team(local_player.player_id, team))
		referee.round_started.connect(_on_round_started)
		referee.round_ended.connect(func(_winner: int, _reason: int) -> void: projectiles.clear())
		arena_requested.connect(referee.set_arena)
		character_requested.connect(func(id: StringName) -> void:
			if local_player != null:
				select_character(local_player, id))
		weapon_requested.connect(func(id: StringName) -> void:
			if local_player != null:
				select_weapon(local_player, id))
		special_requested.connect(func(slot: int, id: StringName) -> void:
			if local_player != null:
				select_special(local_player, slot, id))


func _ready() -> void:
	_floor.name = "Floor"
	_floor.z_index = FLOOR_Z
	add_child(_floor)
	add_child(crates)
	add_child(pickups)
	add_child(projectiles)
	projectiles.player_hit.connect(_on_projectile_hit)
	_load_layout(match_state.arena_index)


## Build walls and crates for a layout. Authoritative callers then respawn players.
func _load_layout(index: int) -> void:
	layout_index = index
	map = ArenaMap.parse(ArenaLayouts.get_layout(index), Constants.TILE_SIZE)
	if _walls != null:
		remove_child(_walls)
		_walls.queue_free()
	_build_walls()
	_floor.setup(map, ArenaLayouts.THEMES[index])
	for b: ArtBlock in _wall_blocks:
		b.queue_free()
	_ghosted.clear()
	_wall_blocks = _floor.build_walls(self, map)
	for t: int in [MatchRules.TEAM_A, MatchRules.TEAM_B]:
		_flag_bases[t] = map.flag_base(t, Constants.TILE_SIZE)
	crates.setup(map, _floor.tiles)
	pickups.setup(map)
	projectiles.clear()
	for p: Player in players:
		p.arena_bounds = play_area()


## Where team `team`'s flag stands (and its capture pad).
func flag_base(team: int) -> Vector2:
	return _flag_bases[team]


## The floor inside the border walls (one tile thick in every layout).
func play_area() -> Rect2:
	return Rect2(Vector2.ZERO, map.size).grow(-Constants.TILE_SIZE)


func add_player(id: int, color_index: int, ctrl: PlayerController,
		is_bot: bool = false) -> Player:
	var p := Player.new()
	p.name = "Player%d" % id
	p.is_bot = is_bot
	var color: Color = PLAYER_COLORS[color_index % PLAYER_COLORS.size()]
	var character: CharacterData = characters.default_character()
	if is_bot:
		character = characters.ordered[id % characters.ordered.size()]
	p.setup(id, color_index, color, catalog.resolve([FALLBACK_WEAPON]), ctrl, projectiles, match_seed, character)
	add_child(p)
	p.arena_bounds = play_area()
	p.global_position = _pick_spawn_for(p)
	p.frozen = match_state.inputs_locked()
	p.team = _team_for(id)
	if mode != Mode.CLIENT and not match_state.may_respawn(id):
		p.sit_out()
	p.died.connect(_on_player_died)
	p.shot_fired.connect(_on_player_shot)
	p.skill_used.connect(_on_skill_used)
	p.spawned.connect(_fx_spawn)
	p.burning.connect(func(who: Player) -> void:
		if effects != null:
			effects.ember(who.global_position + who.visual_offset + Vector2(0.0, EMBER_BODY_Y)))
	p.dripping.connect(func(who: Player) -> void:
		if effects != null:
			effects.drip(who.global_position + who.visual_offset + Vector2(0.0, EMBER_BODY_Y)))
	p.trap_popped.connect(func(at: Vector2) -> void:
		if effects != null:
			effects.bubble_pop(at))
	p.healed.connect(func(user: Player, amount: int) -> void:
		if effects != null:
			effects.heal_number(user.global_position + user.visual_offset - Vector2(0.0, Constants.HEAL_NUMBER_RISE), amount))
	players.append(p)
	_by_id[id] = p
	if is_bot:
		_bot_ids.append(id)
	else:
		_human_ids.append(id)
	match_updated.emit()
	_apply_teams()
	return p


func add_bot(id: int, color_index: int) -> Player:
	return add_player(id, color_index, BotBrain.new(self, match_seed + id), true)


func remove_player(id: int) -> void:
	_picked.erase(id)
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
		referee.remove_player(id, scores, _human_ids)
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


## Authoritative: READY from a player; in Teams it locks their current fighter. Returns the teammate who already
## holds that fighter (the lock is refused), else 0.
func try_ready(id: int, is_ready: bool) -> int:
	var p: Player = get_player(id)
	return referee.set_ready(id, is_ready, p.character.id if p != null else &"")


## Teams: a locked-in player's fighter, weapon and specials are fixed.
func is_locked_in(p: Player) -> bool:
	return match_state.mode == MatchRules.Mode.TEAMS and match_state.locked.has(p.player_id) \
		and match_state.ready.has(p.player_id)


## Lobby only (authoritative): switch a player's character. Takes effect immediately.
func select_character(p: Player, id: StringName) -> void:
	var c: CharacterData = characters.get_character(id)
	if c == null or match_state.phase != MatchState.Phase.LOBBY or is_locked_in(p):
		return
	var first_pick: bool = referee != null and not p.is_bot and not _picked.has(p.player_id)
	if c == p.character and not first_pick:
		return
	p.set_character(c)
	if referee != null and not p.is_bot:  # a human's new fighter starts with every ability slot empty (bots keep defaults)
		_picked[p.player_id] = true
		referee.set_gap_mask(p.player_id, (1 << Constants.SKILL_SLOTS) - 1)
	match_updated.emit()


## Lobby only (authoritative): the one weapon a player fights with. Must be one of weapons_for(character).
func select_weapon(p: Player, id: StringName) -> void:
	var w: WeaponData = catalog.get_weapon(id)
	if w == null or not weapons_for(p.character).has(w) or match_state.phase != MatchState.Phase.LOBBY or is_locked_in(p):
		return
	p.set_weapon(w)
	match_updated.emit()


## Lobby only (authoritative): the special in skill slot `slot`. Must be a special their character can use; an empty
## `id` empties the slot (READY is refused until it is filled again).
func select_special(p: Player, slot: int, id: StringName) -> void:
	if slot < 0 or slot >= Constants.SKILL_SLOTS or match_state.phase != MatchState.Phase.LOBBY or is_locked_in(p) \
			or referee == null:
		return
	var mask: int = match_state.gaps.get(p.player_id, 0)
	if id == &"":
		referee.set_gap_mask(p.player_id, mask | (1 << slot))
		match_updated.emit()
		return
	var s: SkillData = SkillCatalog.shared().get_skill(id)
	if s == null or not s.special or not p.character.can_use_skill(s):
		return
	for other: int in p.skills.size():  # set_skill swaps with a slot already holding it: the gaps travel too
		if other != slot and p.skills[other].data == s:
			var a: int = (mask >> slot) & 1
			var b: int = (mask >> other) & 1
			mask = (mask & ~((1 << slot) | (1 << other))) | (b << slot) | (a << other)
	p.set_skill(slot, s)
	referee.set_gap_mask(p.player_id, mask & ~(1 << slot))
	match_updated.emit()


## Authoritative safety net: any emptied slot gets the first of the fighter's default specials not already equipped.
## READY is refused while a slot is empty, so this only matters if a match starts some other way.
func fill_gaps(p: Player) -> void:
	var mask: int = match_state.gaps.get(p.player_id, 0)
	if mask == 0:
		return
	var taken: Array[SkillData] = []
	for i: int in p.skills.size():
		if (mask >> i) & 1 == 0:
			taken.append(p.skills[i].data)
	for i: int in p.skills.size():
		if (mask >> i) & 1 == 0:
			continue
		for d: SkillData in Player.default_skills(p.character) + Player.specials_pool(p.character):
			if not taken.has(d):
				p.set_skill(i, d)
				taken.append(d)
				break
	match_state.gaps.erase(p.player_id)


## Weapons `c` may fight with: its signature, then the shared weapons it can use in catalog order.
func weapons_for(c: CharacterData) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	if c.signature_weapon != null:
		out.append(c.signature_weapon)
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
	_apply_teams()
	if match_state.intermission > 0.0 and not _client_break:
		projectiles.clear()
	_client_break = match_state.intermission > 0.0
	_apply_freeze()
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

	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * _zoom()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = Constants.CAMERA_SMOOTHING
	# Follow in step with the sim (the target moves in _physics_process), so the player doesn't shake on screen.
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.global_position = clamp_camera(p.global_position, _camera_view(), Rect2(Vector2.ZERO, map.size))
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
	var pause := PauseMenu.new()
	pause.arena = self
	add_child(ui)
	ui.add_child(hud)
	ui.add_child(touch)
	ui.add_child(lobby)
	ui.add_child(results)
	ui.add_child(pause)
	touch.blockers = [lobby, pause.button, pause.menu]

	input.arena = self
	input.touch = touch
	_input = input
	hud.input = input
	touch.ready_sfx = func() -> void: sfx.play(&"ready")
	_attach_effects()
	flags = FlagField.new()
	flags.name = "Flags"
	flags.arena = self
	add_child(flags)
	_apply_teams()


## Where the camera may sit so the view (`view` world units) stays inside `bounds`; an arena smaller than
## the view on an axis is centred on it instead (no empty void around the map).
static func clamp_camera(target: Vector2, view: Vector2, bounds: Rect2) -> Vector2:
	var out: Vector2 = target
	for axis: int in 2:
		var half: float = view[axis] * 0.5
		var lo: float = bounds.position[axis] + half
		var hi: float = bounds.end[axis] - half
		out[axis] = bounds.get_center()[axis] if lo >= hi else clampf(target[axis], lo, hi)
	return out


## The UI's content scale shrinks the canvas on phones; dividing it out keeps the same slice of arena in view.
func _zoom() -> float:
	return Constants.CAMERA_ZOOM / UiStyle.ui_scale


func _camera_view() -> Vector2:
	return get_viewport().get_visible_rect().size / _zoom()


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
	projectiles.beam_drawn.connect(func(owner_id: int, from: Vector2, to: Vector2, w: WeaponData) -> void:
		var shooter: Player = get_player(owner_id)
		if w.held_beam and shooter != null:
			effects.hold_beam(shooter, w, from.distance_to(to))
		else:
			effects.beam(from, to, w.color, w.projectile_radius * BEAM_WIDTH_SCALE))
	projectiles.swung.connect(func(origin: Vector2, facing: Vector2, w: WeaponData) -> void:
		if w.thrust:
			for p: Player in players:
				if p.global_position.distance_squared_to(origin) < 1.0 and p.held_weapon().data == w:
					effects.thrust(p)
					break
		else:
			effects.swing(origin, facing, w.melee_range, w.melee_arc_deg, w.color))
	projectiles.chained.connect(func(from: Vector2, to: Vector2, color: Color) -> void:
		effects.chain_arc(from, to, color)
		sfx.play(&"laser", to))
	projectiles.deflected.connect(effects.deflect)
	projectiles.exploded.connect(_fx_explosion)
	projectiles.burst_shown.connect(effects.burst_strip)
	projectiles.fx_spawned.connect(effects.fun_impact)
	hit_landed.connect(_fx_hit)
	match_updated.connect(_on_match_updated)
	kill_registered.connect(_fx_kill)
	pickups.collected.connect(_fx_pickup_taken)
	pickups.respawned.connect(_fx_pickup_back)
	crates.destroyed.connect(func(at: Vector2) -> void:
		effects.burst(at, CRATE_DEBRIS_COLOR, BURST_CRATE_COUNT, BURST_DEATH_SPEED, PARTICLE_SIZE * 1.5, PARTICLE_LIFE * 1.5)
		sfx.play(&"crate", at))


## Spawn pop: a ring and sparkles on the floor, a rising shimmer and a chime.
func _fx_spawn(who: Player) -> void:
	if effects == null:
		return
	var feet: Vector2 = who.global_position + Vector2(0.0, Player.FOOT_RING_Y)
	effects.spawn_pop(feet, who.display_color)
	sfx.play(&"spawn", who.global_position)
	if who == local_player:
		add_shake(SHAKE_SPAWN)


func _fx_pickup_taken(_index: int, at: Vector2, collector_id: int) -> void:
	effects.burst(at, PICKUP_COLOR, BURST_PICKUP_COUNT, BURST_HIT_SPEED, PARTICLE_SIZE, PARTICLE_LIFE * 1.5,
		Vector2.UP, BURST_PICKUP_SPREAD)
	effects.label_number(at + Vector2(0.0, -PICKUP_LABEL_LIFT), "+%d" % Constants.ENERGY_PICKUP_AMOUNT, PICKUP_COLOR)
	var mine: bool = local_player != null and collector_id == local_player.player_id
	sfx.play(&"pickup", at)
	if mine:
		GameSettings.vibrate(Constants.HAPTIC_HIT_MS)


func _fx_pickup_back(_index: int, at: Vector2) -> void:
	effects.burst(at, PICKUP_COLOR, BURST_PICKUP_COUNT / 2, BURST_HIT_SPEED * 0.5, PARTICLE_SIZE, PARTICLE_LIFE,
		Vector2.UP, BURST_PICKUP_SPREAD)
	sfx.play(&"pickup_ready", at)


func _fx_shot(owner_id: int, origin: Vector2, facing: Vector2, w: WeaponData) -> void:
	var muzzle: Vector2 = origin + facing * w.muzzle_distance()
	effects.burst(muzzle, w.color, BURST_MUZZLE_COUNT, BURST_MUZZLE_SPEED, PARTICLE_SIZE * 0.6, PARTICLE_LIFE * 0.4,
		facing, BURST_MUZZLE_SPREAD)
	sfx.play(w.sfx, origin)
	if local_player != null and owner_id == local_player.player_id:
		add_shake(w.screen_shake)
		# Recoil: nudge the view back against the shot, a touch on top of the random shake.
		_look -= facing * w.screen_shake * RECOIL_KICK


func _fx_explosion(at: Vector2, radius: float, color: Color, slam: bool, art: bool) -> void:
	if art:
		effects.blast(at, radius, slam)
	effects.burst(at, color, BURST_EXPLOSION_COUNT, BURST_DEATH_SPEED, PARTICLE_SIZE * 1.5, PARTICLE_LIFE * 1.5)
	sfx.play(&"explosion", at)
	if local_player != null:
		var d: float = local_player.global_position.distance_to(at)
		add_shake(SHAKE_EXPLOSION * clampf(1.0 - d / SHAKE_EXPLOSION_RANGE, 0.0, 1.0))
		if d < HAPTIC_EXPLOSION_RANGE:
			GameSettings.vibrate(Constants.HAPTIC_EXPLOSION_MS)


func _fx_hit(victim_id: int, damage: int, crit: bool, at: Vector2) -> void:
	var victim: Player = get_player(victim_id)
	var color: Color = victim.display_color if victim != null else Color.WHITE
	effects.burst(at, color, BURST_HIT_COUNT, BURST_HIT_SPEED, PARTICLE_SIZE, PARTICLE_LIFE)
	effects.damage_number(at, damage, crit)
	if victim != null and victim == local_player:
		sfx.play(&"hurt")
		add_shake(maxf(SHAKE_HURT_MIN, SHAKE_HURT_PER_DAMAGE * damage))
		hud.hurt_pulse()
	else:
		sfx.play(&"crit" if crit else &"hit", at)
		if local_player != null and _hit_owner == local_player.player_id and victim != null:
			# Hit marker on whoever you hit, so a connecting shot reads even in a crowd of bullets.
			var dead: bool = victim.dead or victim.stats.hp <= 0
			effects.hit_marker(victim.global_position + victim.visual_offset, crit or dead)
			sfx.play(&"marker_kill" if dead else &"marker")
			if crit or dead:
				GameSettings.vibrate(Constants.HAPTIC_DEALT_MS)


func _fx_kill(killer_id: int, victim_id: int) -> void:
	var victim: Player = get_player(victim_id)
	if victim != null:
		effects.burst(victim.global_position, victim.display_color, BURST_DEATH_COUNT, BURST_DEATH_SPEED,
			PARTICLE_SIZE * 1.5, PARTICLE_LIFE * 2.0)
		sfx.play(&"death", victim.global_position)
	hud.add_kill_feed(player_name(killer_id) if killer_id > 0 else "", player_color(killer_id),
		player_name(victim_id), player_color(victim_id), killer_id == local_player_id(), victim_id == local_player_id())
	if local_player != null and killer_id == local_player.player_id and victim_id != killer_id:
		GameSettings.vibrate(Constants.HAPTIC_KILL_MS)
		_streak += 1
		add_shake(SHAKE_DEALT_KILL)
		hud.banner("KO  " + player_name(victim_id).to_upper(), UiStyle.C_YELLOW)
		if _streak >= 2:
			hud.banner(STREAK_NAMES[mini(_streak, STREAK_NAMES.size() - 1)], UiStyle.C_ORANGE, 1)
			sfx.play(&"streak")
	elif local_player != null and victim_id == local_player.player_id:
		_streak = 0
		add_shake(SHAKE_DEATH)
		GameSettings.vibrate(HAPTIC_DEATH_MS)


func local_player_id() -> int:
	return local_player.player_id if local_player != null else -1


func _on_match_updated() -> void:
	# New match / back to the lobby: nothing from the last round may linger on screen.
	if match_state.phase == MatchState.Phase.COUNTDOWN or match_state.phase == MatchState.Phase.LOBBY:
		if match_state.phase != _fx_phase:
			effects.clear()
			hud.clear_transients()
			_streak = 0
			_trauma = 0.0
	_fx_phase = match_state.phase
	_round_banners()


## Teams: "Round N" when a round starts, who won it when it ends (once each, from the synced state).
func _round_banners() -> void:
	var st: MatchState = match_state
	if st.mode != MatchRules.Mode.TEAMS or st.phase != MatchState.Phase.PLAYING:
		_fx_round = 0
		_fx_break = false
		return
	if st.round_number != _fx_round and st.intermission <= 0.0:
		_fx_round = st.round_number
		hud.banner("Round %d" % st.round_number, UiStyle.C_WHITE)
	var on_break: bool = st.intermission > 0.0
	if on_break and not _fx_break:
		var text: String = MatchRules.round_banner_text(st.round_winner, st.round_reason, Player.viewer_team)
		if st.round_winner == 0:
			hud.banner(text, UiStyle.C_STEEL)
		else:
			hud.banner(text, UiStyle.C_YELLOW if st.round_winner == MatchRules.viewer_of(Player.viewer_team) \
				else UiStyle.C_WHITE)
	_fx_break = on_break


func _on_skill_used(user: Player, skill: SkillData) -> void:
	if effects == null:
		return
	effects.burst(user.global_position, user.display_color, BURST_SKILL_COUNT, BURST_HIT_SPEED, PARTICLE_SIZE,
		PARTICLE_LIFE)
	sfx.play(Sfx.skill_sound(skill.kind), user.global_position)
	match skill.kind:
		SkillData.Kind.TRANSFORM:
			effects.burst(user.global_position, Color.WHITE, BURST_EXPLOSION_COUNT, BURST_DEATH_SPEED,
				PARTICLE_SIZE * 2.0, PARTICLE_LIFE * 2.0)
			if user == local_player:
				add_shake(SHAKE_EXPLOSION)


func _process(delta: float) -> void:
	if camera == null:
		return
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
	var amount: float = _trauma * _trauma * SHAKE_MAX_OFFSET
	camera.offset = Vector2(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0)) * amount
	if effects != null:
		var lock: bool = _input != null and _input.shows_aim_marker()
		effects.aim_marker = _input.auto_aim_point if lock else Vector2.INF
		if lock:
			var tf: CharacterSkill = _input.auto_target.form()
			effects.aim_scale = tf.data.form_scale if tf != null else 1.0
	_tick_heartbeat(delta)
	_update_ghosts()


## A fighter standing behind a wall block or crate (its base line below his feet) while part of his body is under it:
## draw him through it, tinted and half see-through, clipped to the block, so nobody vanishes behind cover.
func _update_ghosts() -> void:
	var blocks: Array[ArtBlock] = _wall_blocks.duplicate()
	for c: Crate in crates.crates:
		if c.is_intact():
			blocks.append(c.art_block())
	var lists: Dictionary = {}
	for p: Player in players:
		if p.is_concealed():  # vanished (Smoke Bomb): no see-through silhouette either
			continue
		var info: Dictionary = p.ghost_info()
		if info.is_empty():
			continue
		var foot: float = info["foot"]
		var body := Rect2(Vector2(p.global_position.x - GHOST_BODY_HALF_W, foot - GHOST_BODY_H),
			Vector2(GHOST_BODY_HALF_W * 2.0, GHOST_BODY_H))
		var tint: Color = p.display_color.lerp(Color.WHITE, GHOST_WHITEN)
		tint.a = GHOST_ALPHA
		for b: ArtBlock in blocks:
			if b == null or b.base_y <= foot or not b.rect.intersects(body):
				continue
			var entry: Array = _ghost_entry(info, b.rect, tint)
			if not entry.is_empty():
				if not lists.has(b):
					lists[b] = []
				lists[b].append(entry)
	for b: ArtBlock in _ghosted:
		if is_instance_valid(b) and not lists.has(b):
			b.set_ghosts([])
	_ghosted.clear()
	for b: ArtBlock in lists:
		b.set_ghosts(lists[b])
		_ghosted.append(b)


## [texture, dst, src, tint] for the part of the sprite (info from Player.ghost_info) inside `clip`, or [].
static func _ghost_entry(info: Dictionary, clip: Rect2, tint: Color) -> Array:
	var full: Rect2 = info["rect"]
	var tex: Texture2D = info["texture"]
	var part: Rect2 = full.intersection(clip)
	if part.size.x <= 0.0 or part.size.y <= 0.0:
		return []
	var k: Vector2 = tex.get_size() / full.size
	var src_y: float = (part.position.y - full.position.y) * k.y
	var src_h: float = part.size.y * k.y
	if info["flip"]:
		var src_x: float = (full.end.x - part.end.x) * k.x
		return [tex, Rect2(part.end.x, part.position.y, -part.size.x, part.size.y),
			Rect2(src_x, src_y, part.size.x * k.x, src_h), tint]
	return [tex, part, Rect2((part.position.x - full.position.x) * k.x, src_y, part.size.x * k.x, src_h), tint]


func _tick_heartbeat(delta: float) -> void:
	if local_player == null or local_player.dead or sfx == null or match_state.inputs_locked():
		_heartbeat = 0.0
		return
	var frac: float = float(local_player.stats.hp) / float(maxi(1, local_player.stats.max_hp))
	if frac > LOW_HP_FRACTION:
		_heartbeat = 0.0
		return
	_heartbeat -= delta
	if _heartbeat <= 0.0:
		_heartbeat = HEARTBEAT_PERIOD_CRITICAL if frac <= CRITICAL_HP_FRACTION else HEARTBEAT_PERIOD
		sfx.play(&"heartbeat")


func _physics_process(delta: float) -> void:
	pickups.tick(delta)
	if mode != Mode.CLIENT:
		if mode == Mode.OFFLINE:
			_fill_teams_bots()
		_resolve_bot_fighters()
		referee.tick(delta, _human_ids, _bot_ids, scores)
		_tick_flags()
		_tick_respawns(delta)
		if not match_state.inputs_locked():
			pickups.collect(players)
	elif match_state.phase != MatchState.Phase.LOBBY:
		# Display only; the server sends the real value on every phase change.
		for t: int in [MatchRules.TEAM_A, MatchRules.TEAM_B]:  # display only, like the clock
			if match_state.flag_state[t] == MatchState.Flag.DROPPED:
				match_state.flag_timer[t] = maxf(0.0, match_state.flag_timer[t] - delta)
		if match_state.intermission > 0.0:
			match_state.intermission = maxf(0.0, match_state.intermission - delta)
			if match_state.intermission == 0.0:
				_apply_freeze()
		else:
			match_state.time_left = maxf(0.0, match_state.time_left - delta)
	if camera != null and local_player != null and not local_player.dead:
		_look = _look.lerp(local_player.facing * Constants.CAMERA_LOOKAHEAD, 1.0 - exp(-CAMERA_LOOK_EASE * delta))
		camera.zoom = Vector2.ONE * _zoom()
		camera.global_position = clamp_camera(local_player.global_position + _look, _camera_view(),
			Rect2(Vector2.ZERO, map.size))


func _tick_respawns(delta: float) -> void:
	for p: Player in players:
		if not p.dead:
			continue
		p.respawn_timer -= delta
		if p.respawn_timer <= 0.0 and match_state.may_respawn(p.player_id):
			p.respawn(_pick_spawn_for(p))


## Teams lobby (authoritative): bots count as locked at once, never share a fighter with a teammate, and give way
## to a human who locked theirs (the bot moves to the next free fighter in catalog order).
func _resolve_bot_fighters() -> void:
	var st: MatchState = match_state
	if st.phase != MatchState.Phase.LOBBY:
		return
	var now: Dictionary[int, StringName] = {}
	if st.mode == MatchRules.Mode.TEAMS:
		var teams: Dictionary[int, int] = referee.lobby_teams()
		for id: int in st.locked:  # humans keep their lock while they stay ready
			if not _bot_ids.has(id) and st.ready.has(id):
				now[id] = st.locked[id]
		for team: int in [MatchRules.TEAM_A, MatchRules.TEAM_B]:
			var taken: Array[StringName] = []
			for id: int in now:
				if teams.get(id, 0) == team:
					taken.append(now[id])
			for id: int in st.participants:
				var b: Player = get_player(id)
				if b == null or not b.is_bot or teams.get(id, 0) != team:
					continue
				if taken.has(b.character.id):
					b.set_character(_free_fighter(b.character, taken))
				taken.append(b.character.id)
				now[id] = b.character.id
	if now != st.locked:
		st.locked = now
		referee.changed.emit()
		match_updated.emit()


## The first fighter after `from` (catalog order, wrapping) that isn't in `taken`.
func _free_fighter(from: CharacterData, taken: Array[StringName]) -> CharacterData:
	var i: int = characters.ordered.find(from)
	for step: int in range(1, characters.ordered.size() + 1):
		var c: CharacterData = characters.ordered[(i + step) % characters.ordered.size()]
		if not taken.has(c.id):
			return c
	return from


## Offline Teams needs five bots around the player; the other modes use fewer, extra ones just sit out.
func _fill_teams_bots() -> void:
	if match_state.mode != MatchRules.Mode.TEAMS or match_state.phase != MatchState.Phase.LOBBY:
		return
	while _bot_ids.size() < Constants.TEAMS_MAX_PLAYERS - 1:
		add_bot(Constants.BOT_ID_BASE + _bot_ids.size(), free_color_index())


## Authoritative, Teams: touching flags. An enemy picks up a flag at its base or where it lies, the owner's touch sends
## a dropped flag home, and a carrier reaching their own base pad captures (the referee ends the round).
func _tick_flags() -> void:
	var st: MatchState = match_state
	if st.mode != MatchRules.Mode.TEAMS or st.phase != MatchState.Phase.PLAYING or st.intermission > 0.0:
		return
	var r: float = Constants.FLAG_TOUCH_RADIUS
	for p: Player in players:
		if p.dead or p.team == 0 or not st.is_participant(p.player_id):
			continue
		var enemy: int = MatchRules.other_team(p.team)
		if st.carried_flag_of(p.player_id) == 0:
			var at := Vector2.INF
			if st.flag_state[enemy] == MatchState.Flag.HOME:
				at = _flag_bases[enemy]
			elif st.flag_state[enemy] == MatchState.Flag.DROPPED:
				at = st.flag_pos[enemy]
			if at != Vector2.INF and p.global_position.distance_to(at) <= r:
				referee.flag_pickup(p.player_id, enemy)
		if st.flag_state[p.team] == MatchState.Flag.DROPPED and p.global_position.distance_to(st.flag_pos[p.team]) <= r:
			referee.flag_return(p.team)
		if st.carried_flag_of(p.player_id) != 0 and p.global_position.distance_to(_flag_bases[p.team]) <= r:
			referee.flag_capture(p.player_id, scores)
			return


func _team_for(id: int) -> int:
	return match_state.team_of(id) if match_state.mode == MatchRules.Mode.TEAMS else 0


## Every player's team (and the viewer's, for ally/enemy colours) follows the match state.
func _apply_teams() -> void:
	var hp_scale: float = Constants.TEAMS_HP_SCALE if match_state.mode == MatchRules.Mode.TEAMS else 1.0
	_floor.set_midline(match_state.mode == MatchRules.Mode.TEAMS)
	for p: Player in players:
		p.team = _team_for(p.player_id)
		p.flag_carrier = p.team != 0 and match_state.carried_flag_of(p.player_id) != 0
		p.set_hp_scale(hp_scale)
	Player.viewer_team = local_player.team if local_player != null else 0


func _apply_freeze() -> void:
	var locked: bool = match_state.inputs_locked()
	for p: Player in players:
		p.frozen = locked


## Teams, authoritative: the next round begins. Everyone back at their team's spawns with full HP and cooldowns.
func _on_round_started() -> void:
	projectiles.clear()
	crates.reset()
	pickups.reset()
	_place_participants()
	_apply_freeze()


## Side effects of entering a phase, on every peer. Positions are authoritative-only; clients
## get them from snapshots.
func _on_phase_changed(phase: MatchState.Phase) -> void:
	_apply_teams()
	match phase:
		MatchState.Phase.COUNTDOWN:
			scores.reset()
			projectiles.clear()
			if mode != Mode.CLIENT:
				for p: Player in players:
					fill_gaps(p)
				crates.reset()
				pickups.reset()
				_place_participants()
		MatchState.Phase.RESULTS:
			projectiles.clear()
	if sfx != null:
		match phase:
			MatchState.Phase.COUNTDOWN:
				sfx.play(&"countdown")
			MatchState.Phase.PLAYING:
				sfx.play(&"go")
				if match_state.mode != MatchRules.Mode.TEAMS:
					hud.banner("FIGHT!", UiStyle.C_WHITE)
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
		if p != who and not p.dead and (who.team == 0 or p.team == who.team):
			_threats.append(p.global_position)
	if who.team != 0:  # Teams: around own flag base, away from teammates
		return ArenaMap.pick_spawn(map.base_spawns(who.team, Constants.TILE_SIZE), _threats)
	return ArenaMap.pick_spawn(map.spawns, _threats)


## Authoritative: re-broadcast, and switch layout (everyone respawns) if the lobby picked another.
func _on_referee_changed() -> void:
	_apply_teams()
	_apply_freeze()
	if match_state.arena_index != layout_index:
		_load_layout(match_state.arena_index)
		for p: Player in players:
			p.sit_out()
	match_updated.emit()


func _on_projectile_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, damage: int, crit: bool,
		at: Vector2) -> void:
	player_hit.emit(owner_id, shot_seq, pellet, victim_id, damage, crit, at)
	_hit_owner = owner_id
	hit_landed.emit(victim_id, damage, crit, at)
	_hit_owner = 0


func _on_player_died(victim: Player, killer_id: int) -> void:
	if referee != null:
		referee.on_death(victim.player_id, victim.global_position, killer_id)
		if mode != Mode.CLIENT and match_state.mode == MatchRules.Mode.TEAMS and match_state.phase == MatchState.Phase.PLAYING:
			victim.respawn_timer = Constants.TEAMS_RESPAWN_DELAY  # clients read it from the snapshot
	scores.register_kill(killer_id, victim.player_id)
	kill_registered.emit(killer_id, victim.player_id)


func _on_player_shot(shooter: Player, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName) -> void:
	shot_fired.emit(shooter.player_id, seq, origin, facing, weapon_id)


## Players-only copy of each rect shifted up by WALL_FEET_STRIP (Constants.LAYER_WALL_FEET), in the parent's space.
static func feet_strip(rects: Array[Rect2]) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALL_FEET
	body.collision_mask = 0
	for rect: Rect2 in rects:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = rect.get_center() - Vector2(0.0, Constants.WALL_FEET_STRIP)
		body.add_child(cs)
	return body


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
	body.add_child(Arena.feet_strip(map.walls))
	add_child(body)
	queue_redraw()
