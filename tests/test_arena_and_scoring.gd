extends GutTest


func test_layout_rows_are_rectangular() -> void:
	for i: int in ArenaLayouts.count():
		for wide: bool in [false, true]:
			var rows: Array[String] = ArenaLayouts.get_layout(i, wide)
			var width: int = rows[0].length()
			for row: String in rows:
				assert_eq(row.length(), width, "%s: %s" % [ArenaLayouts.NAMES[i], row])


func test_layout_is_enclosed() -> void:
	for i: int in ArenaLayouts.count():
		for wide: bool in [false, true]:
			var rows: Array[String] = ArenaLayouts.get_layout(i, wide)
			assert_eq(rows[0], "#".repeat(rows[0].length()))
			assert_eq(rows[rows.size() - 1], "#".repeat(rows[0].length()))
			for row: String in rows:
				assert_eq(row[0], "#")
				assert_eq(row[row.length() - 1], "#")


func test_layout_has_spawns_for_ffa_and_is_symmetric() -> void:
	for i: int in ArenaLayouts.count():
		for wide: bool in [false, true]:
			var rows: Array[String] = ArenaLayouts.get_layout(i, wide)
			var map := ArenaMap.parse(rows, Constants.TILE_SIZE)
			assert_true(map.spawns.size() >= Constants.FFA_MAX_PLAYERS, ArenaLayouts.NAMES[i])
			for y: int in rows.size():
				for x: int in rows[y].length():
					assert_eq(rows[y][x], rows[rows.size() - 1 - y][rows[y].length() - 1 - x],
						"%s (wide %s) not 180° symmetric at %d,%d" % [ArenaLayouts.NAMES[i], wide, x, y])


func test_second_arena_has_crates() -> void:
	assert_eq(ArenaLayouts.count(), 3)
	assert_true(ArenaMap.parse(ArenaLayouts.FOUNDRY, Constants.TILE_SIZE).crate_spots.size() > 0)
	assert_true(ArenaMap.parse(ArenaLayouts.GYM, Constants.TILE_SIZE).crate_spots.size() > 0)


func test_every_layout_has_art_that_fits() -> void:
	assert_eq(ArenaLayouts.THEMES.size(), ArenaLayouts.count())
	for i: int in ArenaLayouts.count():
		var theme: StringName = ArenaLayouts.THEMES[i]
		var tiles: Texture2D = load(ArenaFloor.ART_DIR + "%s_tiles.png" % theme)
		assert_not_null(tiles, String(theme))
		assert_eq(tiles.get_width(), ArenaFloor.ART_TILE * ArenaFloor.Tile.size(), String(theme))
		for wide: bool in [false, true]:
			var decor: StringName = ArenaLayouts.decor_name(i, wide)
			var map := ArenaMap.parse(ArenaLayouts.get_layout(i, wide), Constants.TILE_SIZE)
			var art_px: float = Constants.TILE_SIZE / ArenaFloor.ART_TILE
			for kind: String in ["decal", "overlay"]:
				var path: String = ArenaFloor.ART_DIR + "%s_%s.png" % [decor, kind]
				if ResourceLoader.exists(path):
					assert_eq((load(path) as Texture2D).get_size() * art_px, map.size, "%s %s covers the arena" % [decor, kind])
			assert_true(ResourceLoader.exists(ArenaFloor.ART_DIR + "%s_decal.png" % decor), "%s has a decal" % decor)


func test_floor_tiles_pick_wall_faces_and_shadows() -> void:
	var rows: Array[String] = ["###", "#.#", "###"]
	assert_eq(ArenaFloor.tile_at(rows, 1, 0), ArenaFloor.Tile.WALL_FACE, "floor below: show the face")
	assert_eq(ArenaFloor.tile_at(rows, 0, 0), ArenaFloor.Tile.WALL_TOP)
	assert_eq(ArenaFloor.tile_at(rows, 1, 1), ArenaFloor.Tile.FLOOR_SHADOW)
	assert_eq(ArenaFloor.tile_at(rows, 1, 2), ArenaFloor.Tile.WALL_TOP, "bottom edge")


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


func test_teams_plays_the_wide_layouts_and_other_modes_the_standard_ones() -> void:
	for i: int in ArenaLayouts.count():
		assert_eq(ArenaLayouts.get_layout(i).size(), 24)
		assert_eq(ArenaLayouts.get_layout(i)[0].length(), 40)
		assert_eq(ArenaLayouts.get_layout(i, true).size(), 28)
		assert_eq(ArenaLayouts.get_layout(i, true)[0].length(), 56)
	assert_true(ArenaLayouts.is_wide(MatchRules.Mode.TEAMS))
	assert_false(ArenaLayouts.is_wide(MatchRules.Mode.FFA))
	assert_false(ArenaLayouts.is_wide(MatchRules.Mode.DUEL))
	var arena := Arena.new(Arena.Mode.OFFLINE, 1, MatchRules.Mode.TEAMS)
	add_child_autofree(arena)
	assert_eq(arena.map.size, Vector2(56, 28) * Constants.TILE_SIZE)
	arena.match_state.mode = MatchRules.Mode.FFA  # a lobby mode switch swaps the layout back
	arena._on_referee_changed()
	assert_eq(arena.map.size, Vector2(40, 24) * Constants.TILE_SIZE)


func test_wide_layouts_have_pickups_and_spread_lanes() -> void:
	for i: int in ArenaLayouts.count():
		var map := ArenaMap.parse(ArenaLayouts.get_layout(i, true), Constants.TILE_SIZE)
		assert_gte(map.energy_spots.size(), 6, ArenaLayouts.NAMES[i])
		assert_gte(map.weapon_spots.size(), 6, ArenaLayouts.NAMES[i])
		var base_a: Vector2 = map.flag_base(MatchRules.TEAM_A, Constants.TILE_SIZE)
		var base_b: Vector2 = map.flag_base(MatchRules.TEAM_B, Constants.TILE_SIZE)
		assert_gt(base_b.x - base_a.x, 45.0 * Constants.TILE_SIZE, "bases far apart")
