extends GutTest
## Match stats (ScoreBoard), MVP pick, XP formula / level curve and the profile save round trip.


func test_damage_and_accuracy_accumulate() -> void:
	var sb := ScoreBoard.new()
	sb.register_shot(1, 10)
	sb.register_shot(1, 11)
	sb.register_shot(1, 12)
	sb.register_shot(1, 13)
	sb.register_damage(1, 2, 10, 20)
	sb.register_damage(1, 2, 11, 5)
	sb.register_damage(1, 2, 11, 5)  # second pellet of the same shot: damage yes, hit no
	assert_eq(sb.damage_of(1), 30)
	assert_eq(sb.shots_of(1), 4)
	assert_eq(sb.hits_of(1), 2)
	assert_eq(ScoreBoard.accuracy(sb.hits_of(1), sb.shots_of(1)), 50)
	assert_eq(ScoreBoard.accuracy(0, 0), 0)


func test_ability_damage_counts_damage_not_hits_and_self_is_ignored() -> void:
	var sb := ScoreBoard.new()
	sb.register_damage(1, 2, 999, 40)  # no matching shot (an ability)
	sb.register_damage(1, 1, 5, 40)  # self
	sb.register_damage(0, 2, 5, 40)  # environment
	assert_eq(sb.damage_of(1), 40)
	assert_eq(sb.hits_of(1), 0)
	sb.reset()
	assert_eq(sb.damage_of(1), 0)


func test_results_rows_carry_stats_and_mvp() -> void:
	var sb := ScoreBoard.new()
	sb.register_shot(1, 1)
	sb.register_damage(1, 2, 1, 50)
	sb.register_damage(2, 1, 0, 80)
	sb.register_capture(1)
	var mc := MatchController.new()
	mc.state.participants = [1, 2]
	mc._end(sb)
	var by_id: Dictionary = {}
	for row: Array in mc.state.results:
		by_id[row[MatchState.ResultField.ID]] = row
	assert_eq(by_id[1][MatchState.ResultField.DAMAGE], 50)
	assert_eq(by_id[1][MatchState.ResultField.HITS], 1)
	assert_eq(by_id[1][MatchState.ResultField.CAPTURES], 1)
	assert_eq(MatchRules.mvp(mc.state.results), 2)  # most damage
	by_id[1][MatchState.ResultField.DAMAGE] = 80
	assert_eq(MatchRules.mvp([by_id[2], by_id[1]]), 1)  # tie on damage: the capture wins


func test_xp_formula() -> void:
	assert_eq(PlayerProfile.xp_for_match(false, 0, 0), PlayerProfile.XP_PLAYED)
	assert_eq(PlayerProfile.xp_for_match(true, 3, 450),
		PlayerProfile.XP_PLAYED + PlayerProfile.XP_WIN + 3 * PlayerProfile.XP_KILL + 4)


func test_level_curve() -> void:
	assert_eq(PlayerProfile.level_for_xp(0), 1)
	assert_eq(PlayerProfile.level_for_xp(PlayerProfile.xp_for_level(2) - 1), 1)
	assert_eq(PlayerProfile.level_for_xp(PlayerProfile.xp_for_level(2)), 2)
	assert_eq(PlayerProfile.level_for_xp(PlayerProfile.xp_for_level(PlayerProfile.MAX_LEVEL)), PlayerProfile.MAX_LEVEL)
	assert_eq(PlayerProfile.level_for_xp(10_000_000), PlayerProfile.MAX_LEVEL)
	assert_eq(PlayerProfile.level_fraction(10_000_000), 1.0)
	assert_almost_eq(PlayerProfile.level_fraction(PlayerProfile.xp_for_level(2) + 150), 150.0 / 300.0, 0.001)


func test_profile_round_trip_and_level_up() -> void:
	var tmp: String = "user://test_profile_tmp.cfg"
	var old_path: String = PlayerProfile.path
	PlayerProfile.path = tmp
	PlayerProfile.load_from(tmp)  # nothing there: zeroes
	assert_eq(PlayerProfile.matches, 0)
	var info: Dictionary = PlayerProfile.record_match(&"bolt", true, 5, 1000)
	assert_eq(info["xp"], PlayerProfile.xp_for_match(true, 5, 1000))
	assert_eq(info["level_before"], 1)
	assert_gt(info["level_after"], 1)  # 50 + 50 + 50 + 10 = 160 >= 150
	PlayerProfile.record_match(&"bolt", false, 1, 0)
	PlayerProfile.load_from(tmp)
	assert_eq(PlayerProfile.matches, 2)
	assert_eq(PlayerProfile.wins, 1)
	assert_eq(PlayerProfile.kills, 6)
	assert_eq(PlayerProfile.damage, 1000)
	assert_eq(PlayerProfile.fighters["bolt"]["matches"], 2)
	assert_eq(PlayerProfile.level_of(&"bolt"), 2)
	assert_eq(PlayerProfile.level_of(&"eden"), 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	PlayerProfile.path = old_path
	PlayerProfile.load_from(tmp)  # leave zeroed totals, not the temp file's
