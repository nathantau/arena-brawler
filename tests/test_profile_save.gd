extends GutTest
## Atomic profile save: a corrupted profile.cfg falls back to the .bak of the last good save.

const TMP: String = "user://test_profile_save_tmp.cfg"
var _old_path: String


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + suffix))


func before_each() -> void:
	_old_path = PlayerProfile.path
	PlayerProfile.path = TMP
	_clean()
	PlayerProfile.load_from(TMP)


func after_each() -> void:
	_clean()
	PlayerProfile.path = _old_path
	PlayerProfile.load_from(TMP)


func _corrupt(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_corrupt_profile_loads_gold_and_unlocks_from_bak() -> void:
	PlayerProfile.gold = 777
	PlayerProfile.unlocked = {"weapon:disc_launcher": true}
	assert_eq(PlayerProfile.save_to(TMP), OK)
	assert_eq(PlayerProfile.save_to(TMP), OK, "second save keeps the first as .bak")
	assert_false(FileAccess.file_exists(TMP + ".tmp"), "temp file is renamed away")
	_corrupt("\u0001 garbage [[[ = = {")
	PlayerProfile.load_from(TMP)
	assert_engine_error_count(1, "the corrupt file logs a parse error")
	assert_eq(PlayerProfile.gold, 777)
	assert_true(PlayerProfile.unlocked.has("weapon:disc_launcher"))


func test_corrupt_profile_without_bak_falls_back_to_defaults() -> void:
	_corrupt("[[[ nonsense")
	PlayerProfile.load_from(TMP)
	assert_engine_error_count(1)
	assert_eq(PlayerProfile.gold, PlayerProfile.START_GOLD)
	assert_true(PlayerProfile.unlocked.is_empty())
