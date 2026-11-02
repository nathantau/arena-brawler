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


func test_scale_is_whole_and_covers_the_panel() -> void:
	for panel: Vector2 in [Vector2(490, 620), Vector2(600, 620), Vector2(380, 560)]:
		var feet: float = panel.y * 0.77
		var s: int = StageBackdrop.fit_scale(panel, feet)
		assert_gte(StageBackdrop.ART_W * s, panel.x, "wide enough")
		assert_gte(StageBackdrop.FLOOR_ROW * s, feet, "covers above the floor")
		assert_gte((StageBackdrop.ART_H - StageBackdrop.FLOOR_ROW) * s, panel.y - feet, "covers below the floor")
