extends GutTest
## Settings "Enter code": the right code unlocks every lockable item, a wrong one changes nothing.

const TMP: String = "user://test_unlock_code_tmp.cfg"
var _old_path: String


func before_each() -> void:
	_old_path = PlayerProfile.path
	PlayerProfile.path = TMP
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	PlayerProfile.load_from(TMP)


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	PlayerProfile.path = _old_path
	PlayerProfile.load_from(TMP)


func test_code_unlocks_everything_and_saves() -> void:
	assert_true(Unlocks.redeem("  TeSt "))
	for c: CharacterData in CharacterCatalog.load_all().ordered:
		for e: Dictionary in Unlocks.lockable(c):
			assert_true(PlayerProfile.unlocked.has(Unlocks.key(e["kind"], e["id"])), "%s %s" % [c.id, e["id"]])
		assert_true(Unlocks.box_pool(c).is_empty(), "%s has nothing left to roll" % c.id)
	PlayerProfile.unlocked = {}
	PlayerProfile.load_from(TMP)
	assert_false(PlayerProfile.unlocked.is_empty(), "persisted to disk")
	assert_false(Unlocks.all_unlocked, "not the session flag")


func test_wrong_code_changes_nothing() -> void:
	assert_false(Unlocks.redeem("nope"))
	assert_false(Unlocks.redeem(""))
	assert_true(PlayerProfile.unlocked.is_empty())
	assert_false(FileAccess.file_exists(TMP))
