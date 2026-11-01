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
