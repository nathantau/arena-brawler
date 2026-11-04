extends GutTest
## Gold wallet, the unlock set, box pools / rolls and opening a box. Always on a temp profile path.

const TMP: String = "user://test_unlocks_tmp.cfg"
var _old_path: String
var _old_all: bool


func before_each() -> void:
	_old_path = PlayerProfile.path
	_old_all = Unlocks.all_unlocked
	Unlocks.all_unlocked = false
	PlayerProfile.path = TMP
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	PlayerProfile.load_from(TMP)


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	PlayerProfile.path = _old_path
	PlayerProfile.load_from(TMP)
	Unlocks.all_unlocked = _old_all


func _fighters() -> Array[CharacterData]:
	return CharacterCatalog.load_all().ordered


func test_starter_set_is_unlocked_and_defaults_are_unlocked_for_every_fighter() -> void:
	for c: CharacterData in _fighters():
		for s: SkillData in Player.default_skills(c):
			assert_true(Unlocks.is_skill_unlocked(c, s), "%s default %s" % [c.id, s.id])
		assert_true(Unlocks.is_skill_unlocked(c, SkillCatalog.shared().get_skill(&"dash")))
		assert_true(Unlocks.is_skill_unlocked(c, SkillCatalog.shared().get_skill(&"barrier")))
		assert_true(Unlocks.is_weapon_unlocked(c, c.signature_weapon))
		if c.ultimate != null:
			assert_true(Unlocks.is_skill_unlocked(c, c.ultimate))


func test_pool_excludes_starters_ultimates_and_unlocked() -> void:
	for c: CharacterData in _fighters():
		var pool: Array = Unlocks.box_pool(c)
		assert_false(pool.is_empty(), str(c.id))
		for e: Dictionary in pool:
			if e["kind"] == &"skill":
				var s: SkillData = SkillCatalog.shared().get_skill(e["id"])
				assert_false(Unlocks.is_starter_skill(c, s), "%s %s" % [c.id, e["id"]])
				assert_false(SkillCatalog.shared().is_ultimate(s))
			else:
				assert_ne(e["id"], c.signature_weapon.id)
	var c: CharacterData = _fighters()[0]
	var first: Dictionary = Unlocks.box_pool(c)[0]
	PlayerProfile.unlocked[Unlocks.key(first["kind"], first["id"])] = true
	for e: Dictionary in Unlocks.box_pool(c):
		assert_ne(e["id"], first["id"])


func test_fun_weapons_are_rare_or_epic() -> void:
	var c: CharacterData = _fighters()[0]
	var w: Array = Unlocks.box_pool(c).filter(func(e: Dictionary) -> bool: return e["kind"] == &"weapon")
	assert_eq(w.size(), 5)
	for e: Dictionary in w:
		assert_gte(e["rarity"], 1)


func test_roll_respects_weights_and_empty_tiers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert_eq(Unlocks.roll([], rng), {})
	var pool: Array = [{"kind": &"skill", "id": &"a", "rarity": 0}, {"kind": &"skill", "id": &"b", "rarity": 1},
		{"kind": &"skill", "id": &"c", "rarity": 2}]
	var counts: Array[int] = [0, 0, 0]
	for i: int in 3000:
		counts[Unlocks.roll(pool, rng)["rarity"]] += 1
	assert_almost_eq(counts[0] / 3000.0, 0.6, 0.04)
	assert_almost_eq(counts[1] / 3000.0, 0.3, 0.04)
	assert_almost_eq(counts[2] / 3000.0, 0.1, 0.03)
	var only_epic: Array = [pool[2]]  # missing tiers renormalise: the epic always comes
	for i: int in 20:
		assert_eq(Unlocks.roll(only_epic, rng)["id"], &"c")
	var no_rare: Array = [pool[0], pool[2]]
	var epics: int = 0
	for i: int in 3000:
		epics += 1 if Unlocks.roll(no_rare, rng)["rarity"] == 2 else 0
	assert_almost_eq(epics / 3000.0, 10.0 / 70.0, 0.03)


func test_open_box_spends_refuses_and_never_repeats_until_exhausted() -> void:
	var c: CharacterData = _fighters()[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var size: int = Unlocks.box_pool(c).size()
	PlayerProfile.gold = Unlocks.BOX_PRICE - 1
	assert_eq(Unlocks.open_box(c, rng), {})
	assert_eq(PlayerProfile.gold, Unlocks.BOX_PRICE - 1)
	PlayerProfile.gold = Unlocks.BOX_PRICE * (size + 2)
	var seen: Dictionary = {}
	for i: int in size:
		var got: Dictionary = Unlocks.open_box(c, rng)
		assert_false(got.is_empty())
		var key: String = Unlocks.key(got["kind"], got["id"])
		assert_false(seen.has(key), "duplicate " + key)
		seen[key] = true
		assert_true(PlayerProfile.unlocked.has(key))
	assert_eq(PlayerProfile.gold, Unlocks.BOX_PRICE * 2)
	assert_true(Unlocks.box_pool(c).is_empty())
	assert_eq(Unlocks.open_box(c, rng), {})  # exhausted: nothing is charged
	assert_eq(PlayerProfile.gold, Unlocks.BOX_PRICE * 2)
	PlayerProfile.load_from(TMP)  # saved
	assert_eq(PlayerProfile.unlocked.size(), size)


func test_unlock_all_flag() -> void:
	var c: CharacterData = _fighters()[0]
	Unlocks.unlock_all()
	assert_true(Unlocks.box_pool(c).is_empty())


func test_gold_from_matches_and_level_ups() -> void:
	assert_eq(PlayerProfile.gold, PlayerProfile.START_GOLD)
	assert_eq(PlayerProfile.gold_for_match(false, 0), PlayerProfile.GOLD_PLAYED)
	assert_eq(PlayerProfile.gold_for_match(true, 3), 25 + 25 + 15)
	var info: Dictionary = PlayerProfile.record_match(&"bolt", true, 5, 1000)  # 160 xp: level 1 -> 2
	assert_eq(info["gold"], PlayerProfile.gold_for_match(true, 5) + PlayerProfile.GOLD_LEVEL_UP)
	assert_eq(info["gold_after"], PlayerProfile.START_GOLD + info["gold"])
	var again: Dictionary = PlayerProfile.record_match(&"bolt", false, 0, 0)
	assert_eq(again["gold"], PlayerProfile.GOLD_PLAYED)
	PlayerProfile.load_from(TMP)
	assert_eq(PlayerProfile.gold, again["gold_after"])


func test_spend_gold_refuses_when_short() -> void:
	PlayerProfile.gold = 50
	assert_false(PlayerProfile.spend_gold(60))
	assert_eq(PlayerProfile.gold, 50)
	assert_true(PlayerProfile.spend_gold(50))
	assert_eq(PlayerProfile.gold, 0)


func test_load_clamps_and_old_profiles_get_start_gold() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("totals", "matches", 4)
	cfg.save(TMP)
	PlayerProfile.load_from(TMP)
	assert_eq(PlayerProfile.gold, PlayerProfile.START_GOLD)  # no [wallet]
	cfg.set_value("wallet", "gold", -40)
	cfg.set_value("unlocks", "skill:x", true)
	cfg.set_value("unlocks", "weapon:y", false)
	cfg.save(TMP)
	PlayerProfile.load_from(TMP)
	assert_eq(PlayerProfile.gold, 0)
	assert_true(PlayerProfile.unlocked.has("skill:x"))
	assert_false(PlayerProfile.unlocked.has("weapon:y"))
