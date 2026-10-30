extends GutTest


func _frame(seq: int, move: Vector2 = Vector2.ZERO, fire: bool = false) -> InputFrame:
	var f := InputFrame.new()
	f.seq = seq
	f.move_vec = move
	f.fire = fire
	return f


# --- InputFrame wire format ---

func test_input_roundtrip() -> void:
	var f := _frame(42, Vector2(0.5, -0.5), true)
	f.aim_vec = Vector2.UP
	f.skill = true
	f.special = true
	var g: InputFrame = InputFrame.from_array(f.to_array())
	assert_eq(g.seq, 42)
	assert_eq(g.move_vec, Vector2(0.5, -0.5))
	assert_eq(g.aim_vec, Vector2.UP)
	assert_true(g.fire)
	assert_true(g.skill)
	assert_true(g.special)
	assert_false(g.swap)


func test_input_rejects_malformed() -> void:
	assert_null(InputFrame.from_array("nope"))
	assert_null(InputFrame.from_array([1, 2, 3]))
	assert_null(InputFrame.from_array(["1", Vector2.ZERO, Vector2.ZERO, 0]))
	assert_null(InputFrame.from_array([1, "evil", Vector2.ZERO, 0]))


func test_input_sanitizes_cheaty_values() -> void:
	var g: InputFrame = InputFrame.from_array([-5, Vector2(50, 0), Vector2(0, 9), 0])
	assert_eq(g.seq, 0)
	assert_almost_eq(g.move_vec.length(), 1.0, 0.0001, "no speed hack via long move vector")
	assert_eq(g.aim_vec, Vector2.DOWN)
	var h: InputFrame = InputFrame.from_array([1, Vector2(NAN, 0), Vector2(INF, 0), 0])
	assert_eq(h.move_vec, Vector2.ZERO)
	assert_eq(h.aim_vec, Vector2.ZERO)


# --- Server input queue ---

func _drain(q: NetInputQueue) -> Array[int]:
	## Seqs a server player would simulate in one physics frame.
	var seqs: Array[int] = []
	var f: InputFrame = q.get_input(null, 0.0)
	while f != null:
		seqs.append(f.seq)
		f = q.next_extra_input()
	return seqs


func test_queue_dedupes_redundant_frames() -> void:
	var q := NetInputQueue.new()
	for s: int in [1, 2, 3]:
		q.push(_frame(s))
	for s: int in [2, 3, 4]:  # next packet re-sends 2 and 3
		q.push(_frame(s))
	assert_eq(q.size(), 4)


func test_queue_steady_state_one_per_frame() -> void:
	var q := NetInputQueue.new()
	q.push(_frame(1))
	q.push(_frame(2))
	assert_eq(_drain(q), [1] as Array[int])
	assert_eq(_drain(q), [2] as Array[int])
	assert_eq(_drain(q), [] as Array[int], "empty queue = player doesn't advance")


func test_queue_drops_stale_and_out_of_order() -> void:
	var q := NetInputQueue.new()
	q.push(_frame(5))
	q.push(_frame(3))
	assert_eq(q.size(), 1)


func test_queue_catches_up_after_hitch_without_dropping() -> void:
	var q := NetInputQueue.new()
	# 5 server frames pass with nothing arriving, then a burst of 5 inputs lands.
	for i: int in 5:
		assert_eq(_drain(q), [] as Array[int])
	for s: int in range(1, 6):
		q.push(_frame(s))
	assert_eq(_drain(q), [1, 2, 3, 4, 5] as Array[int], "banked credit lets the server catch up")


func test_queue_cannot_outrun_real_time() -> void:
	var q := NetInputQueue.new()
	var processed: int = 0
	var seq: int = 0
	# Cheater sends 3 inputs per frame for 10 seconds.
	for frame: int in 600:
		for k: int in 3:
			seq += 1
			q.push(_frame(seq))
		processed += _drain(q).size()
	assert_eq(processed, 600, "never more than one input per server frame on average")


func test_queue_catchup_is_bounded() -> void:
	var q := NetInputQueue.new()
	for i: int in 100:  # long idle: credit must not bank beyond the cap
		_drain(q)
	for s: int in range(1, 15):
		q.push(_frame(s))
	assert_eq(_drain(q).size(), int(Constants.INPUT_CATCHUP_MAX))


func test_queue_buffer_cap_keeps_newest() -> void:
	var q := NetInputQueue.new()
	for s: int in range(1, 50):
		q.push(_frame(s))
	assert_eq(q.size(), Constants.INPUT_BUFFER_MAX)
	assert_eq(_drain(q)[0], 49 - Constants.INPUT_BUFFER_MAX + 1)


# --- Client input history ---

func test_history_ack_and_pending() -> void:
	var h := InputHistory.new(8)
	for s: int in range(1, 6):
		h.record(_frame(s))
	h.ack(3)
	assert_eq(h.count(), 2)
	assert_eq(h.at(0).seq, 4)
	assert_eq(h.at(1).seq, 5)


func test_history_copies_frames() -> void:
	var h := InputHistory.new(8)
	var f := _frame(1, Vector2.RIGHT)
	h.record(f)
	f.seq = 99
	f.move_vec = Vector2.LEFT
	assert_eq(h.at(0).seq, 1, "reused frames from LocalInput must not alias history")
	assert_eq(h.at(0).move_vec, Vector2.RIGHT)


func test_history_ring_overflow_drops_oldest() -> void:
	var h := InputHistory.new(4)
	for s: int in range(1, 8):
		h.record(_frame(s))
	assert_eq(h.count(), 4)
	assert_eq(h.at(0).seq, 4)
	assert_eq(h.at(3).seq, 7)


func test_history_encode_latest() -> void:
	var h := InputHistory.new(16)
	for s: int in range(1, 11):
		h.record(_frame(s))
	var batch: Array = h.encode_latest(3)
	assert_eq(batch.size(), 3)
	assert_eq(InputFrame.from_array(batch[0]).seq, 8)
	assert_eq(InputFrame.from_array(batch[2]).seq, 10)


# --- Interpolation ---

func test_interp_lerps_between_snapshots() -> void:
	var b := SnapshotBuffer.new()
	b.push(10, Vector2(0, 0), Vector2.RIGHT)
	b.push(12, Vector2(100, 0), Vector2.RIGHT)
	assert_true(b.sample(11.0))
	assert_almost_eq(b.out_position.x, 50.0, 0.001)


func test_interp_clamps_outside_range() -> void:
	var b := SnapshotBuffer.new()
	b.push(10, Vector2(0, 0), Vector2.RIGHT)
	b.push(12, Vector2(100, 0), Vector2.RIGHT)
	b.sample(5.0)
	assert_eq(b.out_position, Vector2(0, 0))
	b.sample(50.0)
	assert_eq(b.out_position, Vector2(100, 0), "no extrapolation")


func test_interp_does_not_slide_across_teleports() -> void:
	var b := SnapshotBuffer.new()
	b.push(10, Vector2(0, 0), Vector2.RIGHT)
	b.push(12, Vector2(Constants.TELEPORT_DISTANCE * 5.0, 0), Vector2.RIGHT)
	b.sample(11.5)
	assert_eq(b.out_position, Vector2(0, 0))


func test_interp_ignores_old_ticks_and_wraps() -> void:
	var b := SnapshotBuffer.new(4)
	assert_false(b.sample(0.0))
	for t: int in range(0, 20, 2):
		b.push(t, Vector2(t, 0), Vector2.RIGHT)
	b.push(3, Vector2(-999, 0), Vector2.RIGHT)
	assert_eq(b.count(), 4)
	b.sample(15.0)
	assert_almost_eq(b.out_position.x, 15.0, 0.001)


func test_render_clock_tracks_target() -> void:
	var c := RenderClock.new()
	c.advance(100.0)
	assert_eq(c.render_tick, 100.0)
	c.advance(101.0)
	assert_almost_eq(c.render_tick, 101.0, 0.001)
	c.advance(500.0)
	assert_eq(c.render_tick, 500.0, "snaps when far off")


func test_render_clock_converges_on_drift() -> void:
	var c := RenderClock.new()
	c.advance(0.0)
	var target: float = 0.0
	for i: int in 300:
		target += 1.0
		c.advance(target + 10.0)  # server clock is 10 ticks ahead of us
	assert_almost_eq(c.render_tick, target + 10.0, 0.5)


# --- Deterministic shots ---

func test_shot_seed_deterministic_and_distinct() -> void:
	assert_eq(CombatRules.shot_seed(1, 2, 3), CombatRules.shot_seed(1, 2, 3))
	assert_ne(CombatRules.shot_seed(1, 2, 3), CombatRules.shot_seed(1, 2, 4))
	assert_ne(CombatRules.shot_seed(1, 2, 3), CombatRules.shot_seed(1, 3, 3))
	assert_ne(CombatRules.shot_seed(1, 2, 3), CombatRules.shot_seed(2, 2, 3))


func test_shot_seed_no_overflow_for_large_ids() -> void:
	var s: int = CombatRules.shot_seed(2147483647, 2147483647, 2147483647)
	assert_eq(s, CombatRules.shot_seed(2147483647, 2147483647, 2147483647))


func test_cmd_args() -> void:
	var a := CmdArgs.parse(PackedStringArray(["--server", "--port", "9000", "--bots", "2", "--net-debug"]))
	assert_true(a.server)
	assert_eq(a.port, 9000)
	assert_eq(a.bots, 2)
	assert_true(a.net_debug)
	var c := CmdArgs.parse(PackedStringArray(["--connect", "10.0.0.5:7000", "--autopilot"]))
	assert_eq(c.connect_host, "10.0.0.5")
	assert_eq(c.connect_port, 7000)
	assert_true(c.autopilot)
	assert_eq(CmdArgs.parse_address("myhost"), ["myhost", Constants.DEFAULT_PORT])
	assert_eq(CmdArgs.parse_address("myhost:abc"), ["myhost", Constants.DEFAULT_PORT])


func test_cmd_args_match_options() -> void:
	var a := CmdArgs.parse(PackedStringArray(["--server", "--mode", "duel", "--time-limit", "45"]))
	assert_eq(a.match_mode, MatchRules.Mode.DUEL)
	assert_eq(a.time_limit, 45.0)
	var d := CmdArgs.parse(PackedStringArray(["--time-limit", "-3"]))
	assert_eq(d.match_mode, MatchRules.Mode.FFA)
	assert_eq(d.time_limit, Constants.MATCH_TIME_LIMIT)
