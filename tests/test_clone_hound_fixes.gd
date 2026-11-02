extends GutTest
## Shade's Shadow Clones stop at walls / crates as a player-sized body (no sinking into corners), and Shadow's Gloom
## Hound is drawn (its depth-sorted ArtBlock is live and paints with its own art, offset-corrected for the block).

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog
var skills: SkillCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()
	skills = SkillCatalog.shared()


func _world() -> Array:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	return [world, pool]


func _fighter(world: Node2D, pool: ProjectilePool, who: StringName, special: StringName, at: Vector2) -> Player:
	var p := Player.new()
	p.setup(1, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(who))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(special))
	p.global_position = at
	pool.targets.append(p)
	return p


func _block(world: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALL_FEET
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = rect.get_center()
	world.add_child(body)


func _press(p: Player, aim: Vector2) -> void:
	var f := InputFrame.new()
	f.seq = 10
	f.aim_vec = aim
	f.special = true
	p.simulate(f, DT)


func _run(p: Player, frames: int) -> void:
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 100 + i
		p.simulate(f, DT)


func _overlaps_wall(p: Player, at: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = Constants.PLAYER_RADIUS - 0.5
	q.shape = c
	q.collision_mask = Constants.LAYER_WALL_FEET
	q.transform = Transform2D(0.0, at)
	return not p.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func test_clones_never_sink_into_walls_or_corners() -> void:
	var w: Array = _world()
	_block(w[0], Rect2(320, 345, 20, 20))  # a corner just off a clone's straight path
	_block(w[0], Rect2(300, 150, 20, 120))  # and a wall ahead above
	_block(w[0], Rect2(280, 300, 14, 14))  # a crate right at the caster's spawn ring
	var p: Player = _fighter(w[0], w[1], &"flicker", &"shadow_clones", Vector2(260, 300))
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	for step: int in 40:
		_run(p, 6)
		var pts: PackedVector2Array = p.clone_points()
		assert_eq(pts.size(), 4, "four clones")
		for pt: Vector2 in pts:
			assert_false(_overlaps_wall(p, pt), "clone at %s is inside an obstacle (t=%d)" % [pt, step])


func test_clones_in_the_open_still_run_out() -> void:
	var w: Array = _world()
	var p: Player = _fighter(w[0], w[1], &"flicker", &"shadow_clones", Vector2(260, 300))
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	_run(p, 90)
	for pt: Vector2 in p.clone_points():
		assert_gt(pt.distance_to(Vector2(260, 300)), 100.0, "free to run out")


func test_hound_is_drawn_as_a_visible_block_with_art() -> void:
	var w: Array = _world()
	var p: Player = _fighter(w[0], w[1], &"shadow", &"gloom_hound", Vector2(100, 300))
	await wait_physics_frames(2)
	_press(p, Vector2.RIGHT)
	_run(p, 40)
	await wait_frames(3)
	var live: Array[ArtBlock] = []
	for c: Node in w[0].get_children():
		if c is ArtBlock and (c as ArtBlock).visible:
			live.append(c)
	assert_eq(live.size(), 1, "the hound's depth-sorted block is live")
	for tex: Texture2D in [SpecialFx.HOUND_RISE_ART, SpecialFx.HOUND_RUN_ART, SpecialFx.HOUND_BITE_ART, SpecialFx.HOUND_MELT_ART]:
		assert_not_null(tex)
		assert_gt(tex.get_width() / tex.get_height(), 0, "has frames")
