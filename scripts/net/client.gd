class_name NetClient
extends RefCounted
## Networked client: predicts the local player, reconciles against server snapshots, and
## interpolates everyone else ~100 ms in the past. Never applies damage itself.

var session: NetSession
var world_parent: Node
var arena: Arena
var local_id: int = 0
var local_player: Player
var autopilot: bool = false
var debug: bool = false

var _history := InputHistory.new()
var _clock := RenderClock.new()
var _buffers: Dictionary[int, SnapshotBuffer] = {}
var _latest_tick: int = 0
var _pending_states: Array = []
var _has_pending: bool = false
var _send_cb: Callable = _send_inputs

# Reconciliation stats (debug / HUD).
var _corrections: int = 0
var _correction_sum: float = 0.0
var _correction_max: float = 0.0
var _debug_timer: float = 0.0


func _init(p_session: NetSession, p_world_parent: Node, p_autopilot: bool, p_debug: bool) -> void:
	session = p_session
	world_parent = p_world_parent
	autopilot = p_autopilot
	debug = p_debug


func start(host: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(host, port, Constants.NET_CHANNEL_COUNT)
	if err != OK:
		return err
	session.multiplayer.multiplayer_peer = peer
	session.multiplayer.connection_failed.connect(_on_connection_failed)
	session.multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("[client] connecting to %s:%d" % [host, port])
	return OK


func shutdown() -> void:
	if session.multiplayer.connection_failed.is_connected(_on_connection_failed):
		session.multiplayer.connection_failed.disconnect(_on_connection_failed)
	if session.multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		session.multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if arena != null:
		arena.queue_free()
		arena = null


func _on_connection_failed() -> void:
	session.client_disconnected.emit("Could not connect to server")


func _on_server_disconnected() -> void:
	session.client_disconnected.emit("Disconnected from server")


# --- events from server -----------------------------------------------------

func on_welcome(your_id: int, match_seed: int, tick: int, roster: Array) -> void:
	local_id = your_id
	_latest_tick = tick
	arena = Arena.new(Arena.Mode.CLIENT, match_seed)
	world_parent.add_child(arena)
	for entry: Array in roster:
		_add_player(entry[0], entry[1])
		arena.scores.kills[entry[0]] = entry[2]
		arena.scores.deaths[entry[0]] = entry[3]
	print("[client] joined as %d (%d players)" % [local_id, arena.players.size()])


func on_player_joined(id: int, color_index: int) -> void:
	if arena != null:
		_add_player(id, color_index)


func on_player_left(id: int) -> void:
	if arena != null:
		arena.remove_player(id)
		_buffers.erase(id)


func on_kill(killer_id: int, victim_id: int) -> void:
	if arena != null:
		arena.scores.register_kill(killer_id, victim_id)
		if debug:
			print("[client %d] kill: %d -> %d (my k/d %d/%d)" % [local_id, killer_id, victim_id,
				arena.scores.kills_of(local_id), arena.scores.deaths_of(local_id)])


func on_snapshot(tick: int, states: Array) -> void:
	if arena == null or tick <= _latest_tick:
		return
	_latest_tick = tick
	for s: Variant in states:
		if not s is Array or (s as Array).size() != Player.StateField.COUNT:
			continue
		var state: Array = s
		var buf: SnapshotBuffer = _buffers.get(state[Player.StateField.ID])
		if buf != null:
			buf.push(tick, state[Player.StateField.POSITION], state[Player.StateField.FACING])
	# Applied at the start of the next physics frame, before the local player simulates.
	_pending_states = states
	_has_pending = true


func on_shot(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName) -> void:
	if arena == null:
		return
	var weapon: WeaponData = arena.catalog.get_weapon(weapon_id)
	if weapon == null:
		return
	arena.projectiles.fire_shot(owner_id, seq, origin, facing, weapon, arena.match_seed)
	var shooter: Player = arena.get_player(owner_id)
	if shooter != null:
		shooter.play_recoil()


func on_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, _damage: int, _crit: bool, at: Vector2) -> void:
	if arena == null:
		return
	arena.projectiles.kill_shot(owner_id, shot_seq, pellet, at)
	var victim: Player = arena.get_player(victim_id)
	if victim != null:
		victim.flash()


# --- per frame --------------------------------------------------------------

func physics_tick() -> void:
	if arena == null:
		return
	_clock.advance(_latest_tick - Constants.INTERP_DELAY_TICKS)
	if _has_pending:
		_has_pending = false
		_apply_snapshot(_pending_states)
	for id: int in _buffers:
		var p: Player = arena.get_player(id)
		var buf: SnapshotBuffer = _buffers[id]
		if p != null and buf.sample(_clock.render_tick):
			p.global_position = buf.out_position
			p.facing = buf.out_facing
	_debug_timer += Constants.PHYSICS_DT
	if _debug_timer >= Constants.NET_DEBUG_INTERVAL:
		_debug_timer = 0.0
		_report_stats()


func _apply_snapshot(states: Array) -> void:
	for s: Variant in states:
		if not s is Array:
			continue
		var state: Array = s
		if state.size() != Player.StateField.COUNT:
			continue
		var p: Player = arena.get_player(state[Player.StateField.ID])
		if p == null:
			continue
		if p == local_player:
			_reconcile(state)
		else:
			p.apply_state(state, arena.catalog)


## Rewind the local player to the server's state for the last input it processed, then
## replay every input the server hasn't seen yet. Small differences are hidden by
## visual_offset; big ones (respawn, knockback surprises) snap.
func _reconcile(state: Array) -> void:
	var acked: int = state[Player.StateField.LAST_INPUT_SEQ]
	_history.ack(acked)
	var before: Vector2 = local_player.global_position
	local_player.apply_state(state, arena.catalog)
	for i: int in _history.count():
		local_player.simulate(_history.at(i), Constants.PHYSICS_DT, true)
	var error: Vector2 = before - local_player.global_position
	var err_len: float = error.length()
	if err_len > 0.0:
		_corrections += 1
		_correction_sum += err_len
		_correction_max = maxf(_correction_max, err_len)
	if err_len <= Constants.CORRECTION_SMOOTH_MAX:
		local_player.visual_offset += error
	if debug and err_len > 1.0:
		print("[client %d] correction %.1f px: acked=%d replayed=%d server_pos=%s server_vel=%s hp=%d armor=%d" % [
			local_id, err_len, acked, _history.count(), state[Player.StateField.POSITION],
			state[Player.StateField.VELOCITY], state[Player.StateField.HP], state[Player.StateField.ARMOR]])


func _add_player(id: int, color_index: int) -> void:
	if arena.get_player(id) != null:
		return
	if id == local_id:
		var input := LocalInput.new()
		input.autopilot = autopilot
		var recorder := ClientInputRecorder.new(input, _history, _send_cb)
		local_player = arena.add_player(id, color_index, Arena.DEFAULT_LOADOUT, recorder)
		arena.attach_local_view(local_player, input)
	else:
		arena.add_player(id, color_index, Arena.DEFAULT_LOADOUT, null)
		_buffers[id] = SnapshotBuffer.new()


func _send_inputs(batch: Array) -> void:
	session.rpc_submit_inputs.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, batch)


func ping_ms() -> int:
	var peer := session.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return -1
	var server_peer: ENetPacketPeer = peer.get_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	if server_peer == null:
		return -1
	return int(server_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


func _report_stats() -> void:
	var avg: float = _correction_sum / _corrections if _corrections > 0 else 0.0
	var line: String = "ping %d ms · unacked %d · corrections %d (avg %.2f px, max %.1f px)" % [
		ping_ms(), _history.count(), _corrections, avg, _correction_max]
	if arena.hud != null:
		arena.hud.status_text = line
	if debug:
		print("[client %d] %s" % [local_id, line])
	_corrections = 0
	_correction_sum = 0.0
	_correction_max = 0.0
