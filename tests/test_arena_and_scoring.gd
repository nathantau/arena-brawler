extends GutTest


func test_layout_rows_are_rectangular() -> void:
	var width: int = ArenaLayouts.PIT[0].length()
	for row: String in ArenaLayouts.PIT:
		assert_eq(row.length(), width, row)


func test_layout_is_enclosed() -> void:
	var rows: Array[String] = ArenaLayouts.PIT
	assert_eq(rows[0], "#".repeat(rows[0].length()))
	assert_eq(rows[rows.size() - 1], "#".repeat(rows[0].length()))
	for row: String in rows:
		assert_eq(row[0], "#")
		assert_eq(row[row.length() - 1], "#")


func test_layout_has_spawns_for_ffa() -> void:
	var map := ArenaMap.parse(ArenaLayouts.PIT, Constants.TILE_SIZE)
	assert_true(map.spawns.size() >= 4)


func test_parse_merges_wall_runs_and_finds_spawns() -> void:
	var rows: Array[String] = ["####", "#S.#", "####"]
	var map := ArenaMap.parse(rows, 10.0)
	assert_eq(map.size, Vector2(40, 30))
	assert_eq(map.walls.size(), 4, "top run, two side tiles, bottom run")
	assert_eq(map.walls[0], Rect2(0, 0, 40, 10))
	assert_eq(map.spawns, PackedVector2Array([Vector2(15, 15)]))


func test_pick_spawn_farthest_from_threats() -> void:
	var spawns := PackedVector2Array([Vector2(0, 0), Vector2(500, 0), Vector2(1000, 0)])
	var threats := PackedVector2Array([Vector2(900, 0), Vector2(100, 0)])
	assert_eq(ArenaMap.pick_spawn(spawns, threats), Vector2(500, 0))


func test_pick_spawn_without_threats() -> void:
	var spawns := PackedVector2Array([Vector2(7, 7), Vector2(9, 9)])
	assert_eq(ArenaMap.pick_spawn(spawns, PackedVector2Array()), Vector2(7, 7))


func test_kill_scoring() -> void:
	var sb := ScoreBoard.new()
	sb.register_kill(1, 2)
	sb.register_kill(1, 3)
	sb.register_kill(3, 1)
	assert_eq(sb.kills_of(1), 2)
	assert_eq(sb.kills_of(3), 1)
	assert_eq(sb.deaths_of(1), 1)
	assert_eq(sb.deaths_of(2), 1)
	assert_eq(sb.kills_of(99), 0)


func test_no_credit_for_suicide_or_environment() -> void:
	var sb := ScoreBoard.new()
	sb.register_kill(2, 2)
	sb.register_kill(0, 2)
	assert_eq(sb.kills_of(2), 0)
	assert_eq(sb.deaths_of(2), 2)


func test_input_frame_sanitize() -> void:
	var f := InputFrame.new()
	f.move_vec = Vector2(10, 0)
	f.aim_vec = Vector2(0, -3)
	f.sanitize()
	assert_almost_eq(f.move_vec.length(), 1.0, 0.0001)
	assert_eq(f.aim_vec, Vector2.UP)
	f.move_vec = Vector2(NAN, 1)
	f.sanitize()
	assert_eq(f.move_vec, Vector2.ZERO)


func test_input_frame_roundtrip_rejects_bad_types() -> void:
	var f := InputFrame.from_dict({"seq": 5, "move": "evil", "aim": Vector2(2, 0), "fire": true})
	assert_eq(f.seq, 5)
	assert_eq(f.move_vec, Vector2.ZERO)
	assert_eq(f.aim_vec, Vector2.RIGHT)
	assert_true(f.fire)
