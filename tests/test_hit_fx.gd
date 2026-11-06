extends GutTest
## Hit confirmation FX for hits the local player deals: marker only for the local attacker, kill marker upgrade,
## rapid-hit merging, bigger local damage numbers.


func _arena() -> Array:
	var arena := Arena.new(Arena.Mode.OFFLINE, 1, MatchRules.Mode.FFA)
	add_child_autofree(arena)
	var input := LocalInput.new()
	var me: Player = arena.add_player(1, 0, input)
	arena.attach_local_view(me, input)
	var foe: Player = arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
	var other: Player = arena.add_bot(Constants.BOT_ID_BASE + 1, arena.free_color_index())
	return [arena, me, foe, other]


func _live_markers(fx: Effects) -> int:
	var n: int = 0
	for m: Effects.Marker in fx._markers:
		if m.life > 0.0:
			n += 1
	return n


func test_marker_only_for_hits_the_local_player_dealt() -> void:
	var a: Array = _arena()
	var arena: Arena = a[0]
	var me: Player = a[1]
	var foe: Player = a[2]
	var other: Player = a[3]
	arena._on_projectile_hit(other.player_id, 1, 0, foe.player_id, 5, false, foe.global_position)
	assert_eq(_live_markers(arena.effects), 0, "someone else's hit: no marker")
	assert_false(arena.is_local_dealt(other.player_id))
	arena._on_projectile_hit(me.player_id, 2, 0, foe.player_id, 5, false, foe.global_position)
	assert_eq(_live_markers(arena.effects), 1, "my hit: marker")
	assert_true(arena.is_local_dealt(me.player_id))


func test_client_hit_events_carry_the_attacker() -> void:
	var a: Array = _arena()
	var arena: Arena = a[0]
	arena.report_hit(a[2].player_id, 4, false, a[2].global_position, a[3].player_id)
	assert_eq(_live_markers(arena.effects), 0)
	arena.report_hit(a[2].player_id, 4, false, a[2].global_position, a[1].player_id)
	assert_eq(_live_markers(arena.effects), 1)


func test_rapid_hits_merge_and_a_kill_upgrades() -> void:
	var fx := Effects.new()
	add_child_autofree(fx)
	assert_true(fx.hit_marker(Vector2(100, 100), false))
	for i: int in 5:
		assert_false(fx.hit_marker(Vector2(104, 98), false), "merged")
	assert_eq(_live_markers(fx), 1)
	assert_true(fx.hit_marker(Vector2(100, 100), true, true), "kill upgrades the live marker")
	assert_eq(_live_markers(fx), 1)
	var m: Effects.Marker = fx._markers[0]
	assert_true(m.kill)
	assert_almost_eq(m.life, Effects.MARKER_KILL_TIME, 0.001)
	assert_true(fx.hit_marker(Vector2(400, 100), false), "a different spot is its own marker")
	assert_eq(_live_markers(fx), 2)


func test_local_numbers_are_flagged_and_clear_resets() -> void:
	var fx := Effects.new()
	add_child_autofree(fx)
	fx.damage_number(Vector2.ZERO, 7, false, true)
	fx.damage_number(Vector2.ZERO, 7, false)
	assert_true(fx._numbers[0].local)
	assert_false(fx._numbers[1].local)
	fx.clear()
	for m: Effects.Marker in fx._markers:
		assert_lte(m.life, 0.0)
