extends GutTest
## Bolt's godspeed look: the powered-up sheet is worn while any of his abilities is active and for GODSPEED_LINGER after,
## derived from synced skill state (so remote peers show it too). Abilities themselves are untouched.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()


func _bolt(who: StringName = &"bolt") -> Player:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(who))
	world.add_child(p)
	return p


func test_linger_refills_while_active_then_runs_down() -> void:
	assert_eq(Player.godspeed_linger(0.0, true, DT), Player.GODSPEED_LINGER)
	assert_almost_eq(Player.godspeed_linger(Player.GODSPEED_LINGER, false, 0.2), Player.GODSPEED_LINGER - 0.2, 0.0001)
	assert_eq(Player.godspeed_linger(0.1, false, 0.5), 0.0, "never below zero")
	assert_eq(Player.godspeed_linger(0.1, true, 0.5), Player.GODSPEED_LINGER, "active again: back to full")


func test_bolt_has_a_matching_godspeed_sheet() -> void:
	var bolt: CharacterData = characters.get_character(&"bolt")
	assert_true(bolt.has_godspeed())
	assert_eq(bolt.godspeed_sheet.get_width(), bolt.sprite_sheet.get_width(), "same layout, so the animations line up")
	var normal: SpriteFrames = bolt.sprite_frames()
	var god: SpriteFrames = bolt.godspeed_frames()
	assert_ne(normal, god)
	for anim: StringName in [&"idle", &"hit", &"walk", &"die"]:
		assert_eq(god.get_frame_count(anim), normal.get_frame_count(anim), String(anim))


func test_other_fighters_have_no_godspeed_sheet() -> void:
	assert_false(characters.get_character(&"shadow").has_godspeed())


func test_godspeed_follows_any_active_ability_and_lingers() -> void:
	var p: Player = _bolt()
	p._process(DT)
	assert_false(p.godspeed, "idle: normal look")
	p.skills[0].active_remaining = 1.0  # any ability: here whatever sits in slot 0
	p._process(DT)
	assert_true(p.godspeed)
	p.skills[0].active_remaining = 0.0  # it ends: still powered up for the linger
	p._process(DT)
	assert_true(p.godspeed)
	p._process(Player.GODSPEED_LINGER + DT)
	assert_false(p.godspeed, "back to normal after the linger")


func test_godspeed_ends_on_death_and_never_for_others() -> void:
	var p: Player = _bolt()
	p.skills[1].active_remaining = 1.0
	p._process(DT)
	assert_true(p.godspeed)
	p.dead = true
	p._process(DT)
	assert_false(p.godspeed)
	var other: Player = _bolt(&"shadow")
	other.skills[0].active_remaining = 1.0
	other._process(DT)
	assert_false(other.godspeed, "only fighters with a powered-up sheet")


func test_power_level_eases_up_and_down_through_the_stages() -> void:
	var level: float = 0.0
	var seen: Array[int] = []
	for i: int in 40:  # rising: every in-between stage is shown, none skipped
		level = Player.god_level_step(level, true, DT)
		var st: int = Player.god_stage(level)
		if seen.is_empty() or seen[-1] != st:
			seen.append(st)
	assert_eq(seen, [1, 2, 3, 4] as Array[int], "0.3 s rise passes stages 1, 2, 3 then full")
	assert_eq(level, 1.0)
	seen.clear()
	for i: int in 40:
		level = Player.god_level_step(level, false, DT)
		var st: int = Player.god_stage(level)
		if seen.is_empty() or seen[-1] != st:
			seen.append(st)
	assert_eq(seen, [4, 3, 2, 1, 0] as Array[int], "and back down again")
	assert_eq(level, 0.0)
	assert_eq(Player.god_stage(0.0), 0)


func test_bolt_has_a_sheet_for_every_in_between_stage() -> void:
	var bolt: CharacterData = characters.get_character(&"bolt")
	assert_eq(bolt.power_sheets.size(), CharacterData.POWER_STAGES - 1)
	for st: int in range(CharacterData.POWER_STAGES + 1):
		assert_eq(bolt.stage_frames(st).get_frame_count(&"walk"), bolt.sprite_frames().get_frame_count(&"walk"), "stage %d" % st)
	assert_eq(bolt.stage_frames(0), bolt.sprite_frames())
	assert_eq(bolt.stage_frames(CharacterData.POWER_STAGES), bolt.godspeed_frames())
	assert_ne(bolt.stage_frames(2), bolt.stage_frames(3))
	assert_eq(characters.get_character(&"shadow").stage_frames(3), characters.get_character(&"shadow").sprite_frames(), "others stay normal")


func test_godspeed_swap_is_gradual_on_a_player() -> void:
	var p: Player = _bolt()
	p.skills[0].active_remaining = 5.0
	p._process(DT)
	assert_true(p.god_level > 0.0 and p.god_level < 0.1, "starts rising, not a jump")
	assert_ne(p._sprite.sprite_frames, p.character.godspeed_frames(), "not yet full godspeed after one frame")
	for i: int in 30:
		p._process(DT)
	assert_eq(p._sprite.sprite_frames, p.character.godspeed_frames())
	p.skills[0].active_remaining = 0.0
	for i: int in int(Player.GODSPEED_LINGER / DT) + 40:
		p._process(DT)
	assert_eq(p._sprite.sprite_frames, p.character.sprite_frames(), "back to normal after the linger and the fall")
	assert_eq(p.god_level, 0.0)
