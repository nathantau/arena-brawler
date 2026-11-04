extends SceneTree
## Preview: the Shop screen and the box-opening sequence as PNGs (shop idle, mid shake, burst frame, reveal card for a
## common ability and an epic weapon, plus the main menu with the gold chip). Needs a window; run it without stealing
## focus (override.cfg as in CLAUDE.md Commands, plus `window/size/viewport_width=2532` / `viewport_height=1170`):
##   open -g -W -n -a /Applications/Godot.app --args --path "$PWD" --log-file /tmp/shop.log -s tools/shop_preview.gd \
##       -- --touch --notch --pixel-ratio=3 out=/tmp/shop [gold=450] [fighter=eden]
## Writes <out>/<W>x<H>_<name>.png and uses a temp profile, so the real save is never touched.

const PROFILE: String = "user://shop_preview.cfg"
const SETTLE_FRAMES: int = 24

var out: String = "/tmp/shop_preview"
var gold: int = 450
var fighter: StringName = &""


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"out": out = kv[1]
				"gold": gold = int(kv[1])
				"fighter": fighter = StringName(kv[1])
	DirAccess.make_dir_recursive_absolute(out)
	UiStyle.install()
	UiStyle.install_scaling(root)
	PlayerProfile.path = PROFILE
	PlayerProfile.load_from(PROFILE)
	PlayerProfile.gold = gold
	run.call_deferred()


func run() -> void:
	var menu := MainMenu.new()
	root.add_child(menu)
	await _frames(SETTLE_FRAMES + 120)  # the intro splash first
	_shoot("menu")
	menu.queue_free()
	await _frames(2)

	var panel := ShopPanel.new()
	panel.rng = RandomNumberGenerator.new()
	root.add_child(panel)
	await _frames(SETTLE_FRAMES)
	if fighter != &"":
		panel._select(fighter)
		await _frames(4)
	_shoot("shop_idle")
	var c: CharacterData = panel._fighter
	# a few unlocked, so the collection shows both states
	var pool: Array = Unlocks.box_pool(c)
	for k: int in mini(2, pool.size()):
		PlayerProfile.unlocked[Unlocks.key(pool[k]["kind"], pool[k]["id"])] = true
	panel._refresh()
	await _frames(4)
	_shoot("shop_collection")

	var picks: Dictionary[String, Dictionary] = {"common": _entry(0, &"skill"), "rare": _entry(1, &"weapon"),
		"epic": _entry(2, &"weapon")}
	for name: String in picks:
		var o := BoxOpening.new(ShopPanel.item_info(picks[name]), true)
		o.frozen = true
		panel.add_child(o)
		await _frames(2)
		o.jump_to(o.shake_time() * 0.85)
		await _frames(3)
		_shoot("%s_shake" % name)
		o.jump_to(o.burst_time() + 0.02)
		await _frames(3)
		_shoot("%s_burst" % name)
		o.jump_to(o.burst_time() + 0.2)
		await _frames(3)
		_shoot("%s_rising" % name)
		o.jump_to(o.settled_time() + 0.6)
		await _frames(3)
		_shoot("%s_reveal" % name)
		o.queue_free()
		await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	quit()


## A box-pool-style entry of `rarity` and `kind` from any fighter's lockable set (any kind if none matches).
func _entry(rarity: int, kind: StringName) -> Dictionary:
	var any: Dictionary = {}
	for c: CharacterData in CharacterCatalog.load_all().ordered:
		for e: Dictionary in ShopPanel.lockable(c):
			if e["rarity"] == rarity:
				if e["kind"] == kind:
					return e
				any = e
	return any


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shoot(name: String) -> void:
	var size: Vector2i = root.get_viewport().get_visible_rect().size
	var win: Vector2i = root.size
	root.get_viewport().get_texture().get_image().save_png("%s/%dx%d_%s.png" % [out, win.x, win.y, name])
	if size.x == 0:
		push_warning("empty viewport")
