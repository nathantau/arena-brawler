class_name NetServer
extends RefCounted
## Authoritative dedicated server. Owns the only authoritative Arena: consumes client
## inputs, runs the sim at PHYSICS_FPS, detects hits, and broadcasts snapshots at the
## network tick (PHYSICS_FPS / SNAPSHOT_INTERVAL_TICKS).

var session: NetSession
var arena: Arena
var tick: int = 0
var debug: bool = false

var _queues: Dictionary[int, NetInputQueue] = {}
var _debug_timer: float = 0.0
var _rejected_batches: int = 0


func _init(p_session: NetSession, p_arena: Arena, p_debug: bool) -> void:
	session = p_session
	arena = p_arena
	debug = p_debug


func start(port: int, bot_count: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, Constants.MAX_CLIENTS, Constants.NET_CHANNEL_COUNT)
	if err != OK:
		return err
	session.multiplayer.multiplayer_peer = peer
	session.multiplayer.peer_connected.connect(_on_peer_connected)
	session.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	arena.kill_registered.connect(_on_kill)
	arena.shot_fired.connect(_on_shot)
	arena.player_hit.connect(_on_hit)
	for i: int in bot_count:
		arena.add_bot(Constants.BOT_ID_BASE + i, arena.free_color_index())
	print("[server] listening on UDP %d (seed %d, %d bots)" % [port, arena.match_seed, bot_count])
	return OK


func physics_tick() -> void:
	tick += 1
	if tick % Constants.SNAPSHOT_INTERVAL_TICKS == 0 and not session.multiplayer.get_peers().is_empty():
		var states: Array = []
		for p: Player in arena.players:
			states.append(p.capture_state())
		session.rpc_snapshot.rpc(tick, states)
	if debug:
		_debug_timer += Constants.PHYSICS_DT
		if _debug_timer >= Constants.NET_DEBUG_INTERVAL:
			_debug_timer = 0.0
			_print_debug()


func on_inputs(peer_id: int, batch: Array) -> void:
	var queue: NetInputQueue = _queues.get(peer_id)
	if queue == null:
		return
	if batch.size() > Constants.INPUT_BATCH_MAX:
		_rejected_batches += 1
		return
	for item: Variant in batch:
		var frame: InputFrame = InputFrame.from_array(item)
		if frame != null:
			queue.push(frame)


func _on_peer_connected(id: int) -> void:
	var queue := NetInputQueue.new()
	_queues[id] = queue
	var p: Player = arena.add_player(id, arena.free_color_index(), Arena.DEFAULT_LOADOUT, queue)
	session.rpc_welcome.rpc_id(id, id, arena.match_seed, tick, _roster())
	for peer: int in session.multiplayer.get_peers():
		if peer != id:
			session.rpc_player_joined.rpc_id(peer, id, p.color_index)
	print("[server] peer %d joined (%d players)" % [id, arena.players.size()])


func _on_peer_disconnected(id: int) -> void:
	_queues.erase(id)
	arena.remove_player(id)
	session.rpc_player_left.rpc(id)
	print("[server] peer %d left" % id)


func _roster() -> Array:
	var roster: Array = []
	for p: Player in arena.players:
		roster.append([p.player_id, p.color_index, arena.scores.kills_of(p.player_id), arena.scores.deaths_of(p.player_id)])
	return roster


func _on_shot(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName) -> void:
	# The shooter already predicted this shot locally.
	for peer: int in session.multiplayer.get_peers():
		if peer != owner_id:
			session.rpc_shot.rpc_id(peer, owner_id, seq, origin, facing, weapon_id)


func _on_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, damage: int, crit: bool, at: Vector2) -> void:
	session.rpc_hit.rpc(owner_id, shot_seq, pellet, victim_id, damage, crit, at)


func _on_kill(killer_id: int, victim_id: int) -> void:
	session.rpc_kill.rpc(killer_id, victim_id)
	if debug:
		print("[server] %d killed %d" % [killer_id, victim_id])


func _print_debug() -> void:
	var parts: PackedStringArray = []
	for id: int in _queues:
		var p: Player = arena.get_player(id)
		parts.append("%d: seq=%d buf=%d hp=%d ar=%d k=%d" % [id, p.last_input_seq, _queues[id].size(), p.stats.hp, p.stats.armor, arena.scores.kills_of(id)])
	print("[server] tick=%d bullets=%d rejected=%d | %s" % [tick, arena.projectiles.active_count(), _rejected_batches, " | ".join(parts)])
