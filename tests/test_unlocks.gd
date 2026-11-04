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


func test_fun_weapons_span_every_rarity() -> void:
	var c: CharacterData = _fighters()[0]
	var w: Array = Unlocks.box_pool(c).filter(func(e: Dictionary) -> bool: return e["kind"] == &"weapon")
	assert_eq(w.size(), 10, "five fun weapons and five more")
	var tiers: Array[int] = []
	for e: Dictionary in w:
		if not tiers.has(e["rarity"]):
			tiers.append(e["rarity"])
	tiers.sort()
	assert_eq(tiers, [0, 1, 2] as Array[int])


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


## Marks every lockable item of `c` as owned except the last `keep` ones; returns the ones left locked.
func _own_all_but(c: CharacterData, keep: int) -> Array:
	var all: Array = Unlocks.lockable(c)
	for i: int in all.size() - keep:
		PlayerProfile.unlocked[Unlocks.key(all[i]["kind"], all[i]["id"])] = true
	return all.slice(all.size() - keep)


func _rng(seed_: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	return rng


func test_open_box_spends_and_refuses_when_short() -> void:
	var c: CharacterData = _fighters()[0]
	PlayerProfile.gold = Unlocks.BOX_PRICE - 1
	assert_eq(Unlocks.open_box(c, _rng(3)), {})
	assert_eq(PlayerProfile.gold, Unlocks.BOX_PRICE - 1)
	PlayerProfile.gold = 500
	var got: Dictionary = Unlocks.open_box(c, _rng(3))  # nothing owned yet: always new
	assert_false(got.is_empty())
	assert_false(got["dupe"])
	assert_eq(got["refund"], 0)
	assert_eq(PlayerProfile.gold, 500 - Unlocks.BOX_PRICE)
	assert_true(PlayerProfile.unlocked.has(Unlocks.key(got["kind"], got["id"])))
	assert_eq(PlayerProfile.pity_of(c.id), 0)
	PlayerProfile.load_from(TMP)  # saved
	assert_eq(PlayerProfile.unlocked.size(), 1)


func test_boxes_roll_duplicates_and_refund_by_rarity() -> void:
	var c: CharacterData = _fighters()[0]
	var locked: Array = _own_all_but(c, 5)
	var seen: Dictionary = {}
	for s: int in 60:
		PlayerProfile.gold = 1000
		PlayerProfile.pity.clear()
		var got: Dictionary = Unlocks.open_box(c, _rng(s))
		assert_true(got.has("dupe") and got.has("refund"))
		if got["dupe"]:
			assert_eq(got["refund"], Unlocks.DUPE_REFUND[got["rarity"]])
			assert_eq(PlayerProfile.gold, 1000 - Unlocks.BOX_PRICE + got["refund"])
			assert_eq(PlayerProfile.pity_of(c.id), 1)
			seen[got["rarity"]] = true
		else:
			assert_eq(got["refund"], 0)
			assert_eq(PlayerProfile.gold, 1000 - Unlocks.BOX_PRICE)
			PlayerProfile.unlocked.erase(Unlocks.key(got["kind"], got["id"]))  # keep 5 locked
	assert_gte(seen.size(), 2, "dupes of several rarities show up")
	assert_eq(locked.size(), 5)
	assert_eq(Unlocks.DUPE_REFUND, [30, 50, 80] as Array[int])


func test_pity_forces_a_new_item_after_three_duplicates_and_resets() -> void:
	var c: CharacterData = _fighters()[0]
	var locked: Array = _own_all_but(c, 4)
	var found: bool = false
	for s: int in 80:
		PlayerProfile.pity.clear()
		PlayerProfile.pity[String(c.id)] = Unlocks.PITY_DUPES - 1
		PlayerProfile.gold = 1000
		for e: Dictionary in locked:
			PlayerProfile.unlocked.erase(Unlocks.key(e["kind"], e["id"]))
		if not Unlocks.open_box(c, _rng(s))["dupe"]:
			continue
		found = true
		assert_eq(PlayerProfile.pity_of(c.id), Unlocks.PITY_DUPES, "the third duplicate in a row")
		var got: Dictionary = Unlocks.open_box(c, _rng(s))  # at the cap the box only rolls locked items
		assert_false(got["dupe"])
		assert_eq(PlayerProfile.pity_of(c.id), 0, "a new unlock resets it")
		break
	assert_true(found)


func test_pity_run_never_exceeds_three_duplicates() -> void:
	var c: CharacterData = _fighters()[0]
	var locked: Array = _own_all_but(c, 1)  # one item left: dupes are very likely until it comes
	PlayerProfile.gold = 100000
	var rng: RandomNumberGenerator = _rng(5)
	var run: int = 0
	while not Unlocks.box_pool(c).is_empty():
		var got: Dictionary = Unlocks.open_box(c, rng)
		if got["dupe"]:
			run += 1
			assert_lte(run, Unlocks.PITY_DUPES)
		else:
			assert_eq(got["id"], locked[0]["id"])
	assert_eq(PlayerProfile.pity_of(c.id), 0)


func test_pity_is_per_fighter_and_saved_loaded_clamped() -> void:
	PlayerProfile.pity["eden"] = 2
	PlayerProfile.pity["bolt"] = 1
	PlayerProfile.save()
	PlayerProfile.load_from(TMP)
	assert_eq(PlayerProfile.pity_of(&"eden"), 2)
	assert_eq(PlayerProfile.pity_of(&"bolt"), 1)
	assert_eq(PlayerProfile.pity_of(&"shadow"), 0)
	var cfg := ConfigFile.new()
	cfg.set_value("pity", "eden", 99)
	cfg.set_value("pity", "bolt", -4)
	cfg.save(TMP)
	PlayerProfile.load_from(TMP)
	assert_eq(PlayerProfile.pity_of(&"eden"), Unlocks.PITY_DUPES)
	assert_eq(PlayerProfile.pity_of(&"bolt"), 0)


func test_everything_unlocked_still_refuses_and_pool_counts_locked_only() -> void:
	var c: CharacterData = _fighters()[0]
	var all: int = Unlocks.lockable(c).size()
	assert_eq(Unlocks.box_pool(c).size(), all)
	_own_all_but(c, 2)
	assert_eq(Unlocks.box_pool(c).size(), 2)
	_own_all_but(c, 0)
	assert_true(Unlocks.box_pool(c).is_empty())
	PlayerProfile.gold = 500
	assert_eq(Unlocks.open_box(c, _rng(1)), {})
	assert_eq(PlayerProfile.gold, 500)


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


func test_load_survives_non_numeric_wallet_and_pity_values() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("wallet", "gold", [1, 2])
	cfg.set_value("pity", "flint", {"a": 1})
	cfg.set_value("pity", "eden", 2)
	cfg.save(TMP)
	PlayerProfile.load_from(TMP)
	assert_eq(PlayerProfile.gold, PlayerProfile.START_GOLD, "a bad value falls back instead of erroring")
	assert_false(PlayerProfile.pity.has("flint"))
	assert_eq(PlayerProfile.pity_of(&"eden"), 2)
