extends GutTest
## Shop: button state / reason, odds line, strip frame counts and that opening through the panel's handler spends gold
## and unlocks exactly one item. Always on a temp profile path.

const TMP: String = "user://test_shop_tmp.cfg"
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


func test_open_state_reasons() -> void:
	assert_eq(ShopPanel.open_state(500, 3), "")
	assert_eq(ShopPanel.open_state(Unlocks.BOX_PRICE, 1), "")
	assert_eq(ShopPanel.open_state(Unlocks.BOX_PRICE - 1, 3), "Not enough gold")
	assert_eq(ShopPanel.open_state(500, 0), "All unlocked")
	assert_eq(ShopPanel.open_state(0, 0), "All unlocked", "an empty pool wins over no gold")


func test_odds_line_matches_the_weights() -> void:
	assert_eq(ShopPanel.odds_text(), "Common 60% · Rare 30% · Epic 10%")


func test_frames_from_strip_size() -> void:
	assert_eq(BoxOpening.frames_of(Vector2(512, 64)), 8)
	assert_eq(BoxOpening.frames_of(Vector2(1920, 160)), 12)
	assert_eq(BoxOpening.frames_of(Vector2(1024, 128)), 8)
	for r: String in ["common", "rare", "epic"]:
		assert_eq(BoxOpening.frames_of((load("res://assets/fx/box_%s_open.png" % r) as Texture2D).get_size()), 12)
		assert_eq(BoxOpening.frames_of((load("res://assets/fx/box_%s_shake.png" % r) as Texture2D).get_size()), 8)


func test_every_pool_entry_has_card_info() -> void:
	for c: CharacterData in CharacterCatalog.load_all().ordered:
		for e: Dictionary in ShopPanel.lockable(c):
			var info: Dictionary = ShopPanel.item_info(e)
			assert_ne(info["name"], "", "%s %s" % [c.id, e["id"]])
			assert_not_null(info["icon"], "%s %s icon" % [c.id, e["id"]])
			assert_eq(info["rarity"], e["rarity"])


func test_opening_via_the_panel_spends_gold_and_unlocks_one_item() -> void:
	PlayerProfile.gold = 250
	var panel: ShopPanel = ShopPanel.new()
	panel.rng = RandomNumberGenerator.new()
	panel.rng.seed = 3
	add_child_autofree(panel)
	var c: CharacterData = panel._fighter
	var before: int = Unlocks.box_pool(c).size()
	var got: Dictionary = panel._on_open()
	assert_false(got.is_empty())
	assert_eq(PlayerProfile.gold, 150)
	assert_eq(Unlocks.box_pool(c).size(), before - 1)
	assert_eq(PlayerProfile.unlocked.size(), 1)
	assert_true(PlayerProfile.unlocked.has(Unlocks.key(got["kind"], got["id"])))
	assert_not_null(panel._opening, "the reveal plays")
	assert_true(panel._on_open().is_empty(), "no second box while one is opening")
	assert_eq(PlayerProfile.gold, 150)


func test_cannot_open_without_gold() -> void:
	PlayerProfile.gold = Unlocks.BOX_PRICE - 1
	var panel: ShopPanel = ShopPanel.new()
	add_child_autofree(panel)
	assert_true(panel._open_button.disabled)
	assert_eq(panel._reason.text, "Not enough gold")
	assert_true(panel._on_open().is_empty())
	assert_eq(PlayerProfile.gold, Unlocks.BOX_PRICE - 1)
	assert_true(PlayerProfile.unlocked.is_empty())


func test_opening_timeline_orders_and_skip() -> void:
	var info: Dictionary = ShopPanel.item_info({"kind": &"skill", "id": &"dash", "rarity": 1})
	var o := BoxOpening.new(info, false)
	add_child_autofree(o)
	o.frozen = true
	assert_lt(o.shake_time(), o.burst_time())
	assert_lt(o.burst_time(), o.card_time())
	assert_lt(o.card_time(), o.settled_time())
	o.tap()
	assert_almost_eq(o._t, o.burst_time(), 0.001)
	o.tap()
	assert_almost_eq(o._t, o.settled_time(), 0.001)
