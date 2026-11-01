extends GutTest
## The lobby's default arena: random unless --arena was given.


func test_no_arena_arg_picks_random_valid_arenas() -> void:
	var a: CmdArgs = CmdArgs.parse(PackedStringArray(["--offline"]))
	assert_eq(a.arena_index, -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var seen: Dictionary = {}
	for i: int in 200:
		var idx: int = a.pick_arena(rng)
		assert_true(idx >= 0 and idx < ArenaLayouts.count())
		seen[idx] = true
	assert_eq(seen.size(), ArenaLayouts.count(), "every arena can come up")


func test_same_seed_same_pick() -> void:
	var a: CmdArgs = CmdArgs.parse(PackedStringArray(["--server"]))
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 7
	r2.seed = 7
	assert_eq(a.pick_arena(r1), a.pick_arena(r2))


func test_explicit_arena_wins() -> void:
	var rng := RandomNumberGenerator.new()
	for i: int in ArenaLayouts.count():
		var a: CmdArgs = CmdArgs.parse(PackedStringArray(["--arena", str(i)]))
		assert_eq(a.pick_arena(rng), i)
	assert_eq(CmdArgs.parse(PackedStringArray(["--arena", "99"])).pick_arena(rng), ArenaLayouts.count() - 1)
