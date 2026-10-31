class_name NetSession
extends Node
## The RPC surface shared by server and client. Godot matches RPCs by node path and method
## list, so this node lives at the same path on every peer (/root/Main/Session) and holds
## every RPC; logic is delegated to NetServer / NetClient.
##
## Channels: snapshots and shots/hits are unreliable_ordered on their own channels so one
## lost packet never stalls another stream; join/leave/kill, match state and lobby
## requests are reliable.

signal client_disconnected(reason: String)

const CH_SNAPSHOT: int = 1
const CH_EVENTS: int = 2
const CH_SHOTS: int = 3
const CH_INPUT: int = 4

var server: NetServer
var client: NetClient


func _ready() -> void:
	# Run before players so snapshots/reconciliation apply at the start of each physics frame.
	process_physics_priority = -10


func start_server(arena: Arena, port: int, bot_count: int, debug: bool) -> Error:
	server = NetServer.new(self, arena, debug)
	return server.start(port, bot_count)


func start_client(world_parent: Node, host: String, port: int, autopilot: bool, debug: bool,
		character: StringName = &"", weapon: StringName = &"", special: StringName = &"") -> Error:
	client = NetClient.new(self, world_parent, autopilot, debug)
	client.wanted_character = character
	client.wanted_weapon = weapon
	client.wanted_special = special
	return client.start(host, port)


## See Constants.ENET_THROTTLE_DECELERATION.
static func disable_throttle(peer: ENetPacketPeer) -> void:
	if peer != null:
		peer.throttle_configure(Constants.ENET_THROTTLE_INTERVAL_MS, Constants.ENET_THROTTLE_ACCELERATION,
			Constants.ENET_THROTTLE_DECELERATION)


## Tear down whichever role is active and go back to offline.
func stop() -> void:
	if client != null:
		client.shutdown()
		client = null
	server = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _physics_process(_delta: float) -> void:
	if server != null:
		server.physics_tick()
	if client != null:
		client.physics_tick()


# --- client -> server -------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered", CH_INPUT)
func rpc_submit_inputs(batch: Array) -> void:
	if server != null:
		server.on_inputs(multiplayer.get_remote_sender_id(), batch)


@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func rpc_set_ready(is_ready: bool) -> void:
	if server != null:
		server.on_set_ready(multiplayer.get_remote_sender_id(), is_ready)


@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func rpc_request_mode(mode: int) -> void:
	if server != null:
		server.on_request_mode(multiplayer.get_remote_sender_id(), mode)


@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func rpc_request_arena(index: int) -> void:
	if server != null:
		server.on_request_arena(multiplayer.get_remote_sender_id(), index)


@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func rpc_select_character(id: StringName) -> void:
	if server != null:
		server.on_select_character(multiplayer.get_remote_sender_id(), id)


@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func rpc_select_special(slot: int, id: StringName) -> void:
	if server != null:
		server.on_select_special(multiplayer.get_remote_sender_id(), slot, id)


@rpc("any_peer", "call_remote", "reliable", CH_EVENTS)
func rpc_select_weapon(id: StringName) -> void:
	if server != null:
		server.on_select_weapon(multiplayer.get_remote_sender_id(), id)


# --- server -> client -------------------------------------------------------

@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func rpc_welcome(your_id: int, match_seed: int, tick: int, roster: Array) -> void:
	if client != null:
		client.on_welcome(your_id, match_seed, tick, roster)


@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func rpc_player_joined(id: int, color_index: int, is_bot: bool) -> void:
	if client != null:
		client.on_player_joined(id, color_index, is_bot)


@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func rpc_match_state(state: Array) -> void:
	if client != null:
		client.on_match_state(state)


@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func rpc_crates(hp: PackedInt32Array) -> void:
	if client != null:
		client.on_crates(hp)


@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func rpc_player_left(id: int) -> void:
	if client != null:
		client.on_player_left(id)


@rpc("authority", "call_remote", "reliable", CH_EVENTS)
func rpc_kill(killer_id: int, victim_id: int) -> void:
	if client != null:
		client.on_kill(killer_id, victim_id)


@rpc("authority", "call_remote", "unreliable_ordered", CH_SNAPSHOT)
func rpc_snapshot(tick: int, states: Array) -> void:
	if client != null:
		client.on_snapshot(tick, states)


@rpc("authority", "call_remote", "unreliable_ordered", CH_SHOTS)
func rpc_shot(owner_id: int, seq: int, origin: Vector2, facing: Vector2, weapon_id: StringName) -> void:
	if client != null:
		client.on_shot(owner_id, seq, origin, facing, weapon_id)


@rpc("authority", "call_remote", "unreliable_ordered", CH_SHOTS)
func rpc_hit(owner_id: int, shot_seq: int, pellet: int, victim_id: int, damage: int, crit: bool, at: Vector2) -> void:
	if client != null:
		client.on_hit(owner_id, shot_seq, pellet, victim_id, damage, crit, at)
