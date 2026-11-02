extends GutTest
## Character-select showcase backdrops: every fighter has a strip, drawn at a whole-number scale.


func test_every_character_has_a_backdrop_strip() -> void:
	for file: String in DirAccess.get_files_at("res://data/characters"):
		if not file.ends_with(".tres"):
			continue
		var c: CharacterData = load("res://data/characters/" + file)
		var tex: Texture2D = StageBackdrop.texture_for(c.id)
		assert_not_null(tex, "%s has a backdrop" % c.id)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(StageBackdrop.ART_W * StageBackdrop.FRAMES, StageBackdrop.ART_H), c.id)


func test_unknown_fighter_has_no_backdrop() -> void:
	assert_null(StageBackdrop.texture_for(&"nobody"))


func test_backdrop_uses_the_fighters_pixel_scale_when_it_reaches() -> void:
	var panel := Vector2(490, 620)
	var feet: float = 458.0
	assert_eq(StageBackdrop.fit_scale(panel, feet, 4), 4, "same pixel size as the fighter")
	assert_eq(StageBackdrop.fit_scale(Vector2(740, 620), 484.0, 5), 5)


func test_backdrop_grows_when_the_fighters_scale_would_not_cover_the_height() -> void:
	var s: int = StageBackdrop.fit_scale(Vector2(490, 900), 700.0, 2)
	assert_gte(StageBackdrop.FLOOR_ROW * s, 700.0)
	assert_gte((StageBackdrop.ART_H - StageBackdrop.FLOOR_ROW) * s, 200.0)
