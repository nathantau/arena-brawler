extends GutTest
## Anime bust art in the character select: optional per fighter (Apex, Flint, Sakura and Bolt have it).

const WUKONG: CharacterData = preload("res://data/characters/wukong.tres")
const FLINT: CharacterData = preload("res://data/characters/flint.tres")
const SAKURA: CharacterData = preload("res://data/characters/sakura.tres")
const BOLT: CharacterData = preload("res://data/characters/bolt.tres")
const EDEN: CharacterData = preload("res://data/characters/eden.tres")


func test_four_fighters_have_a_bust() -> void:
	for c: CharacterData in [WUKONG, FLINT, SAKURA, BOLT]:
		assert_true(c.has_bust(), "%s has a bust" % c.id)
		var f: SpriteFrames = c.bust_frames()
		assert_eq(f.get_frame_count(&"idle"), Constants.BUST_IDLE_FRAMES)
		assert_gte(f.get_frame_count(&"rise"), 8, "%s rise strip" % c.id)
		var last: AtlasTexture = f.get_frame_texture(&"rise", f.get_frame_count(&"rise") - 1)
		assert_eq(last.region.size, Vector2(Constants.BUST_SIZE))
	assert_false(EDEN.has_bust(), "no bust: the old presentation")


func test_bust_frames_are_whole_cells() -> void:
	var f: SpriteFrames = WUKONG.bust_frames()
	assert_eq(f.get_frame_count(&"idle"), Constants.BUST_IDLE_FRAMES)
	assert_eq(f.get_frame_count(&"rise"), 8)
	assert_true(f.get_animation_loop(&"idle"))
	assert_false(f.get_animation_loop(&"rise"), "plays once")
	assert_eq(WUKONG.bust_frames(), f, "built once")
	var last: AtlasTexture = f.get_frame_texture(&"rise", 7)
	assert_eq(last.region.size, Vector2(Constants.BUST_SIZE))


func test_bust_scale_is_whole_and_fits() -> void:
	var s: int = LobbyPanel.bust_scale(1100.0, 1000.0)
	assert_eq(s, 6)
	assert_lte(s * Constants.BUST_SIZE.y, 1100.0)
	assert_eq(LobbyPanel.bust_scale(100.0, 100.0), 1, "never below x1")


func test_rise_plays_then_holds_the_last_frame() -> void:
	var sprite := AnimatedSprite2D.new()
	add_child_autofree(sprite)
	sprite.sprite_frames = WUKONG.bust_frames()
	sprite.play(&"rise")
	assert_eq(sprite.frame, 0)
	var rise: float = 8.0 / Constants.BUST_RISE_FPS
	await get_tree().create_timer(rise + Constants.BUST_RISE_HOLD * 0.5).timeout
	assert_eq(sprite.frame, 7)
	assert_true(sprite.is_playing(), "still lingering on the held look")
	await get_tree().create_timer(Constants.BUST_RISE_HOLD).timeout
	assert_eq(sprite.frame, 7, "stays on look C")
	assert_false(sprite.is_playing())
