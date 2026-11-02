extends GutTest
## Depth sorting: fighters, wall blocks, crates and upright ability art live in one y-sorted layer, each placed by its
## foot line; and a fighter hidden behind a wall gets a clipped see-through ghost.

const DT: float = 1.0 / 60.0


func _arena() -> Arena:
	var a := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(a)
	return a


func test_arena_sorts_its_children_and_has_one_block_per_wall_run() -> void:
	var a: Arena = _arena()
	assert_true(a.y_sort_enabled)
	assert_true(a.crates.y_sort_enabled)
	assert_eq(a._wall_blocks.size(), a.map.walls.size())
	for b: ArtBlock in a._wall_blocks:
		assert_eq(b.get_parent(), a, "wall blocks share the players' parent")
		assert_almost_eq(b.global_position.y, b.rect.end.y - ArtBlock.SORT_LIFT, 0.01)
		assert_eq(b.base_y, b.rect.end.y)
	a.add_player(1, 0, PlayerController.new())
	assert_eq(a.players[0].get_parent(), a)


func test_crates_sort_by_their_base_line() -> void:
	var a: Arena = _arena()
	a._load_layout(1)  # Foundry has crates
	assert_gt(a.crates.crates.size(), 0)
	for c: Crate in a.crates.crates:
		assert_true(c.y_sort_enabled)
		var b: ArtBlock = c.art_block()
		assert_not_null(b)
		assert_almost_eq(b.global_position.y, c.global_position.y + c.size * 0.5 - ArtBlock.SORT_LIFT, 0.01)


func test_upright_ability_art_joins_the_players_sorted_layer() -> void:
	var a: Arena = _arena()
	var p: Player = a.add_player(1, 0, PlayerController.new())
	a.match_state.phase = MatchState.Phase.LOBBY
	a.select_character(p, &"bolt")
	a.select_special(p, 1, &"tesla_coil")
	var slot: CharacterSkill = p.skills[1]
	assert_true(slot.try_activate(Vector2.RIGHT, p.global_position, p.stats))
	slot.anchor = p.global_position + Vector2(0.0, Player.FOOT_RING_Y)
	p._special_fx.sync(p)
	var live: Array[ArtBlock] = []
	for b: ArtBlock in p._special_fx._blocks:
		if b.visible:
			live.append(b)
	assert_eq(live.size(), 1, "the coil is one sorted block")
	assert_eq(live[0].get_parent(), a)
	assert_almost_eq(live[0].global_position.y, slot.anchor.y - ArtBlock.SORT_LIFT, 0.01)
	p._special_fx.queue_free()
	await get_tree().process_frame


func test_ghost_is_clipped_to_the_wall_and_mirrored_with_the_sprite() -> void:
	var tex: Texture2D = load("res://assets/sprites/flicker.png")
	var info: Dictionary = {"texture": tex, "rect": Rect2(100, 100, 144, 144), "flip": false, "foot": 220.0}
	var clip := Rect2(90, 200, 200, 48)
	var e: Array = Arena._ghost_entry(info, clip, Color.WHITE)
	assert_eq(e.size(), 4)
	assert_eq(e[1], Rect2(100, 200, 144, 44), "dst is the sprite rect inside the wall")
	assert_almost_eq((e[2] as Rect2).position.y, 100.0 / 1.5, 0.01)
	info["flip"] = true
	var f: Array = Arena._ghost_entry(info, clip, Color.WHITE)
	assert_lt((f[1] as Rect2).size.x, 0.0, "a mirrored sprite is drawn with a negative width")
	assert_eq(Arena._ghost_entry(info, Rect2(0, 0, 10, 10), Color.WHITE), [], "no overlap, no ghost")


func test_fighter_behind_a_wall_is_ghosted_and_one_in_front_is_not() -> void:
	var a: Arena = _arena()
	var wall: Rect2 = a.map.walls[0]
	var behind: Player = a.add_player(1, 0, PlayerController.new())
	var front: Player = a.add_player(2, 1, PlayerController.new())
	behind.global_position = Vector2(wall.get_center().x, wall.end.y - 20.0) - Vector2(0.0, Player.FOOT_RING_Y)
	front.global_position = Vector2(wall.get_center().x, wall.end.y + 50.0) - Vector2(0.0, Player.FOOT_RING_Y)
	a._update_ghosts()
	var block: ArtBlock = a._wall_blocks[0]
	assert_gt(block.ghosts.size(), 0, "the one standing behind its base line shows through")
	assert_eq(block.ghosts.size(), 1, "the one in front draws over it and needs no ghost")
