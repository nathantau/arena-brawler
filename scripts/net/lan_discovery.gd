class_name LanDiscovery
extends Node
## Same-Wi-Fi game discovery over UDP broadcast. HOST mode announces the hosted game ~1/s;
## BROWSE mode listens and keeps a live list of games (entries expire after EXPIRY_S of silence).
## Encode/decode/upsert/prune are static and pure so they are unit-tested without sockets.

signal games_changed

enum Mode { OFF, HOST, BROWSE }

const MAGIC: String = "BRWL"
## Bump when the net protocol changes: other versions are listed greyed-out ("different version").
const VERSION: int = 1
const DISCOVERY_PORT: int = 7778
const ANNOUNCE_INTERVAL_S: float = 1.0
const EXPIRY_S: float = 3.0
const MAX_PACKET_BYTES: int = 512
## Browse mode also sweeps the local /24 with unicast probes (works without the iOS multicast entitlement).
const PROBE_INTERVAL_S: float = 1.5
const SWEEP_SENDS_PER_FRAME: int = 32

var mode: Mode = Mode.OFF
## Browse mode: key "ip:port" -> {info: Dictionary, ip: String, seen: float (seconds)}.
var games: Dictionary = {}

var _udp: PacketPeerUDP
var _arena: Arena
var _port: int = Constants.DEFAULT_PORT
var _timer: float = 0.0
var _prober: PacketPeerUDP  # browse: unbound socket (ephemeral port) the probes go out from and replies come back to
var _sweep: PackedStringArray = []
var _sweep_pos: int = 0
var _sweep_wait: float = 0.0
## Debug: host skips the broadcast (replies to probes only); browser also probes its own address.
var broadcast_enabled: bool = true
var sweep_self: bool = false


## Packet body for a hosted game. `info` keys: name, port, mode, arena, players, max, playing.
static func encode(info: Dictionary) -> PackedByteArray:
	var d: Dictionary = info.duplicate()
	d["magic"] = MAGIC
	d["v"] = VERSION
	return JSON.stringify(d).to_utf8_buffer()


## {} if not one of ours (bad magic/garbage); else the info plus `compatible: bool` (same VERSION).
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() == 0 or bytes.size() > MAX_PACKET_BYTES:
		return {}
	if bytes[0] != 0x7B:  # '{'; stray UDP on this port must not make the JSON parser log errors
		return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return {}
	var d: Dictionary = json.data
	if d.get("magic", "") != MAGIC or not d.has("v") or not d.has("port"):
		return {}
	return {
		"name": str(d.get("name", "Host")).left(24),
		"port": int(d["port"]),
		"mode": int(d.get("mode", MatchRules.Mode.FFA)),
		"arena": int(d.get("arena", 0)),
		"players": int(d.get("players", 1)),
		"max": int(d.get("max", Constants.FFA_MAX_PLAYERS)),
		"playing": bool(d.get("playing", false)),
		"compatible": int(d["v"]) == VERSION,
	}


static func encode_probe() -> PackedByteArray:
	return JSON.stringify({"magic": MAGIC, "v": VERSION, "probe": true}).to_utf8_buffer()


static func is_probe(bytes: PackedByteArray) -> bool:
	if bytes.size() == 0 or bytes.size() > MAX_PACKET_BYTES or bytes[0] != 0x7B:
		return false
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return false
	var d: Dictionary = json.data
	return d.get("magic", "") == MAGIC and d.get("probe", false) == true


## Every host address of the /24 around `ip` except .0, .255 and (unless `include_self`) `ip` itself.
static func sweep_targets(ip: String, include_self: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	var prefix: String = LanAddress.subnet_prefix(ip)
	if prefix == "":
		return out
	for i: int in range(1, 255):
		var a: String = "%s%d" % [prefix, i]
		if include_self or a != ip:
			out.append(a)
	return out


static func upsert(table: Dictionary, info: Dictionary, ip: String, now: float) -> void:
	table["%s:%d" % [ip, info["port"]]] = {"info": info, "ip": ip, "seen": now}


## Drops entries silent for more than EXPIRY_S. True if anything was removed.
static func prune(table: Dictionary, now: float) -> bool:
	var dead: Array = []
	for k: Variant in table:
		if now - float((table[k] as Dictionary)["seen"]) > EXPIRY_S:
			dead.append(k)
	for k: Variant in dead:
		table.erase(k)
	return not dead.is_empty()


## "Alice · FFA · Pit · 2/4" (+ " · playing" when in a match).
static func label(info: Dictionary) -> String:
	var mode_name: String = "Duel" if int(info["mode"]) == MatchRules.Mode.DUEL else "FFA"
	var a: int = int(info["arena"])
	var arena_name: String = ArenaLayouts.NAMES[a] if a >= 0 and a < ArenaLayouts.count() else "?"
	var s: String = "%s · %s · %s · %d/%d" % [info["name"], mode_name, arena_name, info["players"], info["max"]]
	return s + " · playing" if info["playing"] else s


## The directed broadcast of a /24 LAN ("192.168.1.42" -> "192.168.1.255"); "" if not IPv4.
static func directed_broadcast(ip: String) -> String:
	var p: String = LanAddress.subnet_prefix(ip)
	return p + "255" if p != "" else ""


static func device_name() -> String:
	var n: String = OS.get_model_name()
	return "Host" if n == "" or n == "GenericDevice" else n


## Announce `arena`'s game (listening on `port`) until stop().
func start_host(arena: Arena, port: int) -> void:
	stop()
	mode = Mode.HOST
	_arena = arena
	_port = port
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	if _udp.bind(DISCOVERY_PORT) != OK:
		push_warning("LanDiscovery: can't listen on %d, announcing by broadcast only" % DISCOVERY_PORT)
	_timer = 0.0


## Listen for announcements. Returns the bind error (OK on success).
func start_browse() -> Error:
	stop()
	_udp = PacketPeerUDP.new()
	var err: Error = _udp.bind(DISCOVERY_PORT)
	if err != OK:
		_udp = null  # broadcasts can't be heard, the probe sweep still works
	_prober = PacketPeerUDP.new()
	mode = Mode.BROWSE
	_sweep = sweep_targets(LanAddress.local(), sweep_self)
	_sweep_pos = _sweep.size()
	_sweep_wait = 0.0
	return err


func stop() -> void:
	if _udp != null:
		_udp.close()
	_udp = null
	if _prober != null:
		_prober.close()
	_prober = null
	_arena = null
	mode = Mode.OFF
	if not games.is_empty():
		games.clear()
		games_changed.emit()


func _process(delta: float) -> void:
	if mode == Mode.HOST:
		_answer_probes()
		_timer -= delta
		if _timer <= 0.0:
			_timer = ANNOUNCE_INTERVAL_S
			_announce()
	elif mode == Mode.BROWSE:
		_send_probes(delta)
		_poll()


func _announce() -> void:
	var bytes: PackedByteArray = _packet()
	if bytes.is_empty() or not broadcast_enabled:
		return
	var targets: Array[String] = ["255.255.255.255"]
	var directed: String = directed_broadcast(LanAddress.local())
	if directed != "":
		targets.append(directed)
	for t: String in targets:
		_udp.set_dest_address(t, DISCOVERY_PORT)
		_udp.put_packet(bytes)


## Unicast reply to whoever probed: the same packet as the broadcast.
func _answer_probes() -> void:
	while _udp.is_bound() and _udp.get_available_packet_count() > 0:
		var probe: PackedByteArray = _udp.get_packet()
		var ip: String = _udp.get_packet_ip()
		var port: int = _udp.get_packet_port()
		var bytes: PackedByteArray = _packet()
		if is_probe(probe) and not bytes.is_empty():
			_udp.set_dest_address(ip, port)
			_udp.put_packet(bytes)


func _send_probes(delta: float) -> void:
	if _sweep_pos >= _sweep.size():
		_sweep_wait -= delta
		if _sweep_wait > 0.0:
			return
		_sweep_pos = 0
		_sweep_wait = PROBE_INTERVAL_S
	var probe: PackedByteArray = encode_probe()
	var end: int = mini(_sweep_pos + SWEEP_SENDS_PER_FRAME, _sweep.size())
	while _sweep_pos < end:
		_prober.set_dest_address(_sweep[_sweep_pos], DISCOVERY_PORT)
		_prober.put_packet(probe)
		_sweep_pos += 1


func _packet() -> PackedByteArray:
	if _arena == null or not is_instance_valid(_arena):
		return PackedByteArray()
	var st: MatchState = _arena.match_state
	var info: Dictionary = {
		"name": device_name(), "port": _port, "mode": st.mode, "arena": st.arena_index,
		"players": _arena.players.size(),
		"max": Constants.DUEL_PLAYERS if st.mode == MatchRules.Mode.DUEL else Constants.FFA_MAX_PLAYERS,
		"playing": st.phase != MatchState.Phase.LOBBY,
	}
	return encode(info)


func _poll() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var changed: bool = false
	for sock: PacketPeerUDP in [_udp, _prober]:
		if sock != null:
			changed = _drain(sock, now) or changed
	if prune(games, now):
		changed = true
	if changed:
		games_changed.emit()


## Reads every waiting packet (broadcast or probe reply alike) into `games`; true if the list changed.
func _drain(sock: PacketPeerUDP, now: float) -> bool:
	var changed: bool = false
	while sock.get_available_packet_count() > 0:
		var bytes: PackedByteArray = sock.get_packet()
		var ip: String = sock.get_packet_ip()
		var info: Dictionary = decode(bytes)
		if info.is_empty():
			continue
		var key: String = "%s:%d" % [ip, info["port"]]
		changed = changed or not games.has(key) or (games[key] as Dictionary)["info"] != info
		upsert(games, info, ip, now)
	return changed
