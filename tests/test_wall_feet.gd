extends GutTest
## Players move against walls / crates shifted up by WALL_FEET_STRIP, so feet (drawn below the collision circle)
## stop at a wall's top edge and one-tile gaps fit.


func test_spawns_clear_of_feet_strips() -> void:
	for i: int in ArenaLayouts.count():
		var map := ArenaMap.parse(ArenaLayouts.get_layout(i), Constants.TILE_SIZE)
		var blocks: Array[Rect2] = map.walls.duplicate()
		for c: Vector2 in map.crate_spots:
			blocks.append(Rect2(c - Vector2.ONE * Constants.TILE_SIZE * 0.5, Vector2.ONE * Constants.TILE_SIZE))
		for s: Vector2 in map.spawns:
			for r: Rect2 in blocks:
				var strip := Rect2(r.position - Vector2(0.0, Constants.WALL_FEET_STRIP), r.size)
				var nearest := s.clamp(strip.position, strip.end)
				assert_true(s.distance_to(nearest) >= Constants.PLAYER_RADIUS,
					"layout %d spawn %s overlaps the strip above %s" % [i, s, r])


func test_player_stops_with_feet_at_wall_top() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	var wall: Rect2 = arena.map.walls[arena.map.walls.size() - 1]  # bottom border
	p.global_position = Vector2(wall.get_center().x, wall.position.y - 100.0)
	await wait_physics_frames(2)
	for i: int in 120:
		p.velocity = Vector2(0, 400)
		p.move_and_slide()
	var feet: float = p.global_position.y + Constants.PLAYER_RADIUS + Constants.WALL_FEET_STRIP
	assert_almost_eq(feet, wall.position.y, 2.0)


func test_fits_through_one_tile_gap() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	var t: float = Constants.TILE_SIZE
	# a one-tile corridor running sideways: a wall above, a wall below, one floor row between
	var corridor_y: float = -2000.0
	var walls := StaticBody2D.new()
	walls.add_child(Arena.feet_strip([Rect2(0, corridor_y - t, 4 * t, t), Rect2(0, corridor_y + t, 4 * t, t)] as Array[Rect2]))
	arena.add_child(walls)
	# the feet ring sits in the floor row (the circle's centre WALL_FEET_STRIP above it)
	p.global_position = Vector2(-t, corridor_y + t * 0.5 - Constants.WALL_FEET_STRIP)
	await wait_physics_frames(2)
	for i: int in 60:
		p.velocity = Vector2(400, 0)
		p.move_and_slide()
	assert_gt(p.global_position.x, 4 * t, "walked through the corridor")
