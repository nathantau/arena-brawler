extends GutTest

const TMP: String = "user://test_settings.cfg"

var _saved: Array = []


func before_each() -> void:
	_saved = [GameSettings.music, GameSettings.sfx, GameSettings.haptics, GameSettings.howto_seen, GameSettings.mode]


func after_each() -> void:
	GameSettings.music = _saved[0]
	GameSettings.sfx = _saved[1]
	GameSettings.haptics = _saved[2]
	GameSettings.howto_seen = _saved[3]
	GameSettings.mode = _saved[4]
	DirAccess.remove_absolute(TMP)


func test_round_trip() -> void:
	GameSettings.music = 0.25
	GameSettings.sfx = 0.5
	GameSettings.haptics = false
	GameSettings.howto_seen = true
	assert_eq(GameSettings.save_to(TMP), OK)
	GameSettings.music = 1.0
	GameSettings.sfx = 1.0
	GameSettings.haptics = true
	GameSettings.howto_seen = false
	GameSettings.load_from(TMP)
	assert_almost_eq(GameSettings.music, 0.25, 0.001)
	assert_almost_eq(GameSettings.sfx, 0.5, 0.001)
	assert_false(GameSettings.haptics)
	assert_true(GameSettings.howto_seen)


func test_missing_file_keeps_values() -> void:
	GameSettings.music = 0.3
	GameSettings.load_from("user://does_not_exist.cfg")
	assert_almost_eq(GameSettings.music, 0.3, 0.001)


func test_out_of_range_is_clamped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", 9.0)
	cfg.set_value("audio", "sfx", -2.0)
	cfg.save(TMP)
	GameSettings.load_from(TMP)
	assert_eq(GameSettings.music, 1.0)
	assert_eq(GameSettings.sfx, 0.0)


func test_to_db() -> void:
	assert_eq(GameSettings.to_db(0.0), GameSettings.SILENT_DB)
	assert_almost_eq(GameSettings.to_db(1.0), 0.0, 0.001)
	assert_lt(GameSettings.to_db(0.5), 0.0)


func test_every_skill_kind_has_a_real_sound() -> void:
	for kind: int in SkillData.Kind.values():
		assert_true(Sfx.RECIPES.has(Sfx.skill_sound(kind)), "kind %d" % kind)


func test_music_loop_is_seamless_length() -> void:
	var wav: AudioStreamWAV = Music.synthesize()
	assert_eq(wav.loop_end * 2, wav.data.size())
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)


func test_the_home_screen_mode_is_remembered() -> void:
	GameSettings.mode = MatchRules.Mode.TEAMS
	assert_eq(GameSettings.save_to(TMP), OK)
	GameSettings.mode = MatchRules.Mode.DUEL
	GameSettings.load_from(TMP)
	assert_eq(GameSettings.mode, MatchRules.Mode.TEAMS)


func test_a_bad_saved_mode_is_clamped() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "mode", 99)
	cfg.save(TMP)
	GameSettings.load_from(TMP)
	assert_eq(GameSettings.mode, MatchRules.Mode.size() - 1)


func test_every_mode_has_a_home_screen_rule() -> void:
	assert_eq(MainMenu.MODE_RULES.size(), MatchRules.Mode.size())
	for m: int in MatchRules.Mode.size():
		assert_true((MainMenu.MODE_RULES[m] % MatchRules.kill_target(m as MatchRules.Mode)).length() > 0)
