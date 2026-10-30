extends GutTest
## Client prediction is only correct if replaying the same inputs from the same state gives
## the same result. These run real Player nodes with move_and_slide against walls.

const WALL_X: float = 400.0

var world: Node2D
var pool: ProjectilePool
var catalog: WeaponCatalog
var characters: CharacterCatalog


func before_each() -> void:
	world = Node2D.new()
	add_child_autofree(world)
	var wall := StaticBody2D.new()
	wall.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 2000)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	wall.add_child(cs)
	wall.position = Vector2(WALL_X, 0)
	world.add_child(wall)
	pool = ProjectilePool.new()
	world.add_child(pool)
	catalog = WeaponCatalog.load_all()
	characters = CharacterCatalog.load_all()


func _player(id: int, character: StringName = &"flicker") -> Player:
	var p := Player.new()
	var loadout: Array[WeaponData] = catalog.resolve([&"pistol", &"smg"] as Array[StringName])
	p.setup(id, 0, Color.WHITE, loadout, null, pool, 7, characters.get_character(character))
	world.add_child(p)
	return p


## Varied input: run into the wall, dash, swap, fire.
func _inputs(n: int) -> Array[InputFrame]:
	var out: Array[InputFrame] = []
	for i: int in n:
		var f := InputFrame.new()
		f.seq = i + 1
		f.move_vec = Vector2(1, sin(i * 0.1)).normalized()
		f.aim_vec = Vector2.UP.rotated(i * 0.05)
		f.skill = i % 40 < 3
		f.special = i % 50 > 45
		f.swap = i == 25
		f.fire = i % 3 != 0
		out.append(f)
	return out


func test_replay_from_captured_state_matches() -> void:
	await wait_physics_frames(2)  # let the wall register in the physics space
	for character: StringName in [&"flicker", &"warden", &"twinshot", &"wukong"]:
		await _check_replay(character)


func _check_replay(character: StringName) -> void:
	var a: Player = _player(1, character)
	var b: Player = _player(2, character)
	var inputs: Array[InputFrame] = _inputs(90)
	var snapshot: Array = []
	for i: int in inputs.size():
		a.simulate(inputs[i], Constants.PHYSICS_DT)
		if i == 39:
			snapshot = a.capture_state()
	# b = "client": adopt the state the server had after input 40, replay 41..90.
	assert_true(b.apply_state(snapshot, catalog, characters))
	for i: int in range(40, inputs.size()):
		b.simulate(inputs[i], Constants.PHYSICS_DT, true)
	assert_almost_eq(b.global_position.x, a.global_position.x, 0.01)
	assert_almost_eq(b.global_position.y, a.global_position.y, 0.01)
	assert_eq(b.stats.energy, a.stats.energy)
	assert_eq(b.loadout.active_index, a.loadout.active_index)
	assert_almost_eq(b.dash.cooldown_remaining, a.dash.cooldown_remaining, 0.0001)
	assert_almost_eq(b.special.cooldown_remaining, a.special.cooldown_remaining, 0.0001)
	assert_almost_eq(b.special.active_remaining, a.special.active_remaining, 0.0001)
	assert_eq(b.last_input_seq, a.last_input_seq)
	assert_true(a.global_position.x < WALL_X, "walls stopped the player")
	assert_eq(b.special.anchor, a.special.anchor, String(character))
	a.queue_free()
	b.queue_free()
	await wait_physics_frames(1)


func test_state_roundtrip() -> void:
	var a: Player = _player(1)
	a.global_position = Vector2(12, 34)
	a.velocity = Vector2(5, 6)
	a.stats.apply_damage(70)
	a.stats.energy = 33
	a.dash.try_activate(Vector2.LEFT, a.global_position, a.stats)
	a.special.try_activate(Vector2.LEFT, a.global_position, a.stats)
	a.loadout.swap()
	a.last_input_seq = 77
	var b: Player = _player(2)
	b.apply_state(a.capture_state(), catalog, characters)
	assert_eq(b.capture_state().slice(1), a.capture_state().slice(1), "everything but the id")


func test_replay_does_not_spawn_projectiles() -> void:
	await wait_physics_frames(1)
	var a: Player = _player(1)
	var f := InputFrame.new()
	f.seq = 1
	f.fire = true
	f.aim_vec = Vector2.LEFT
	a.simulate(f, Constants.PHYSICS_DT, true)
	assert_eq(pool.active_count(), 0)
	assert_false(a.loadout.active().is_ready(), "but cooldown is still predicted")


func test_fire_shot_is_reproducible_by_observers() -> void:
	await wait_physics_frames(1)
	var shotgun: WeaponData = catalog.get_weapon(&"shotgun")
	pool.fire_shot(1, 50, Vector2(0, 0), Vector2.LEFT, shotgun, 99)
	var first: Array = _active_velocities()
	pool.clear()
	pool.fire_shot(1, 50, Vector2(0, 0), Vector2.LEFT, shotgun, 99)
	assert_eq(_active_velocities(), first)
	assert_eq(first.size(), shotgun.pellets)


func _active_velocities() -> Array:
	var out: Array = []
	for s: ProjectilePool.Slot in pool.debug_slots():
		if s.active:
			out.append(s.vel)
	return out
