extends GutTest
## Anime bust art in the character select: optional per fighter (only Apex has it so far).

const WUKONG: CharacterData = preload("res://data/characters/wukong.tres")
const EDEN: CharacterData = preload("res://data/characters/eden.tres")


func test_only_apex_has_a_bust() -> void:
	assert_true(WUKONG.has_bust())
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
	var stage := Vector2(2480.0, 820.0)
	var s: int = LobbyPanel.bust_scale(stage)
	assert_eq(s, 5)
	assert_lte(s * Constants.BUST_SIZE.y, stage.y)
	assert_eq(LobbyPanel.bust_scale(Vector2(100.0, 100.0)), 1, "never below x1")


func test_rise_plays_then_holds_the_last_frame() -> void:
	var sprite := AnimatedSprite2D.new()
	add_child_autofree(sprite)
	sprite.sprite_frames = WUKONG.bust_frames()
	sprite.play(&"rise")
	assert_eq(sprite.frame, 0)
	await get_tree().create_timer(8.0 / Constants.BUST_RISE_FPS + 0.4).timeout
	assert_eq(sprite.frame, 7, "stays on look C")
	assert_false(sprite.is_playing())
