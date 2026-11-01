extends GutTest
## Bugs found by the second bug sweep (networking edges, match edges, held buttons).


func _frame(seq: int, skill: bool = false, special: bool = false) -> InputFrame:
	var f := InputFrame.new()
	f.seq = seq
	f.skill = skill
	f.special = special
	return f


## A special button pressed (or still held) while dead used to fire on the very frame of the respawn: the press edge
## was only tracked while alive, so the stale "not pressed" state turned a held button into a fresh press.
func test_button_held_through_death_does_not_fire_on_respawn() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var p: Player = arena.add_player(1, 0, null)
	p.frozen = false
	p.take_hit(9999, false, Vector2.ZERO, 0)
	assert_true(p.dead)
	p.simulate(_frame(1, true, true), Constants.PHYSICS_DT)
	p.simulate(_frame(2, true, true), Constants.PHYSICS_DT)
	p.respawn(Vector2(300, 300))
	p.frozen = false
	p.simulate(_frame(3, true, true), Constants.PHYSICS_DT)
	assert_false(p.skills[0].is_active(), "dash did not fire from a button held since before the respawn")
	assert_false(p.skills[1].is_active(), "nor did the special")
	p.simulate(_frame(4), Constants.PHYSICS_DT)
	p.simulate(_frame(5, true), Constants.PHYSICS_DT)
	assert_true(p.skills[0].is_active(), "a fresh press after the respawn still works")


## The host plays too, so it takes one of the MAX_CLIENTS seats: a fifth human could connect but never start a match
## (the lobby blocks on "Too many players"). A dedicated server keeps all of them.
func test_listen_server_leaves_a_seat_for_the_host() -> void:
	var main := Main.new()
	add_child_autofree(main)
	await wait_physics_frames(2)
	main.args.port = 47311
	main._start_host()
	await wait_physics_frames(2)
	var clients: Array[ENetMultiplayerPeer] = []
	for i: int in Constants.MAX_CLIENTS:
		var c := ENetMultiplayerPeer.new()
		assert_eq(c.create_client("127.0.0.1", 47311, Constants.NET_CHANNEL_COUNT), OK)
		clients.append(c)
	for frame: int in 90:
		for c: ENetMultiplayerPeer in clients:
			c.poll()
		await wait_physics_frames(1)
	var connected: int = 0
	for c: ENetMultiplayerPeer in clients:
		if c.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			connected += 1
	assert_eq(connected, Constants.MAX_CLIENTS - 1, "the host's seat is not for a client")
	assert_eq(main.session.multiplayer.get_peers().size(), Constants.MAX_CLIENTS - 1)
	for c: ENetMultiplayerPeer in clients:
		c.close()
	main._on_host_leave(false)


## A 4-player snapshot (~1.8 KB) went out as one packet, above ENet's MTU (the engine even warns), so it was fragmented
## and one lost fragment dropped everybody's update. Now it is split into MTU-sized packets sharing the tick.
func test_snapshot_packets_fit_the_mtu() -> void:
	var arena := Arena.new(Arena.Mode.SERVER)
	add_child_autofree(arena)
	for i: int in 7:
		arena.add_player(100 + i, i, null)
	var states: Array = []
	for p: Player in arena.players:
		states.append(p.capture_state())
	var packets: Array[Array] = NetServer.snapshot_packets(states)
	var total: int = 0
	for packet: Array in packets:
		total += packet.size()
		assert_lt(var_to_bytes([1, packet]).size(), 1392 - 100, "fits one datagram with room for headers")
	assert_eq(total, states.size(), "everybody is in exactly one packet")
	assert_eq(NetServer.snapshot_packets([]).size(), 0)


## Packets of one snapshot share its tick: the client keeps them all, and still drops older ticks.
func test_client_merges_snapshot_packets_of_one_tick() -> void:
	var session := NetSession.new()
	add_child_autofree(session)
	var client := NetClient.new(session, self, false, false)
	client.arena = Arena.new(Arena.Mode.CLIENT, 1)
	add_child_autofree(client.arena)
	client.local_id = 7
	var a: Player = client.arena.add_player(1, 0, null)
	var b: Player = client.arena.add_player(2, 1, null)
	client._buffers[1] = SnapshotBuffer.new()
	client._buffers[2] = SnapshotBuffer.new()
	var sa: Array = a.capture_state()
	var sb: Array = b.capture_state()
	client.on_snapshot(10, [sa])
	client.on_snapshot(10, [sb])
	assert_eq(client._pending_states.size(), 2, "both packets of tick 10 are applied")
	client.on_snapshot(9, [sa])
	assert_eq(client._pending_states.size(), 2, "an older tick is ignored")
	client.on_snapshot(11, [sb])
	assert_eq(client._pending_states.size(), 1, "a newer tick replaces the pending states")
	assert_eq((client._buffers[1] as SnapshotBuffer).count(), 1)
	assert_eq((client._buffers[2] as SnapshotBuffer).count(), 2)
