extends GutTest
## Spawn protection (flicker, ends on the first shot, synced), the energy pickup field (collect / timer / sync) and stun
## cutting channelled specials short.

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


func _player(world: Node2D, pool: ProjectilePool, who: StringName, special: StringName = &"dash", id: int = 1,
		at: Vector2 = Vector2(300, 300)) -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		characters.get_character(who))
	world.add_child(p)
	p.set_skill(1, skills.get_skill(special))
	p.global_position = at
	if pool != null:
		pool.targets.append(p)
	return p


func _run(p: Player, frames: int, fire: bool = false, replay: bool = false, move: Vector2 = Vector2.ZERO) -> void:
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 100 + i
		f.fire = fire
		f.move_vec = move
		p.simulate(f, DT, replay)


# --- spawn protection --------------------------------------------------------------------------------------------------

func test_respawn_protects_then_wears_off() -> void:
	var w: Array = _world()
	var p: Player = _player(w[0], w[1], &"flicker")
	p.respawn(Vector2(200, 200))
	assert_almost_eq(p.stats.spawn_protect, Constants.RESPAWN_IFRAME_TIME, 0.001)
	assert_false(p.can_be_hit(), "untouchable while protected")
	assert_eq(p.take_hit(30, false, Vector2.ZERO, 2), 0, "no damage")
	_run(p, ceili(Constants.RESPAWN_IFRAME_TIME / DT) + 2)
	assert_eq(p.stats.spawn_protect, 0.0)
	assert_true(p.can_be_hit())
	assert_gt(p.take_hit(10, false, Vector2.ZERO, 2), 0, "hurts again")


func test_first_shot_ends_protection() -> void:
	var w: Array = _world()
	var p: Player = _player(w[0], w[1], &"flicker")
	p.respawn(Vector2(200, 200))
	_run(p, 10)
	assert_gt(p.stats.spawn_protect, 0.0, "idle: still protected")
	_run(p, 1, true)
	assert_eq(p.stats.spawn_protect, 0.0, "firing ends it")
	assert_true(p.can_be_hit())


func test_replay_ends_protection_like_the_server() -> void:
	var w: Array = _world()
	var p: Player = _player(w[0], w[1], &"flicker")
	p.respawn(Vector2(200, 200))
	_run(p, 1, true, true)
	assert_eq(p.stats.spawn_protect, 0.0, "a replayed shot must end it too, or the prediction drifts")


func test_dash_iframes_do_not_count_as_spawn_protection() -> void:
	var w: Array = _world()
	var p: Player = _player(w[0], w[1], &"flicker")
	p.stats.invulnerable_time = 0.3
	assert_eq(p.stats.spawn_protect, 0.0)
	_run(p, 1, true)
	assert_gt(p.stats.invulnerable_time, 0.0, "firing doesn't cut dash i-frames")


func test_spawn_protection_is_synced_and_reset_by_death() -> void:
	var w: Array = _world()
	var a: Player = _player(w[0], null, &"flicker", &"dash", 1)
	var b: Player = _player(w[0], null, &"flicker", &"dash", 2)
	a.respawn(Vector2(200, 200))
	var state: Array = a.capture_state()
	assert_eq(state.size(), Player.StateField.COUNT)
	b.apply_state(state, WeaponCatalog.load_all(), characters)
	assert_almost_eq(b.stats.spawn_protect, a.stats.spawn_protect, 0.0001)
	a.stats.reset()
	assert_eq(a.stats.spawn_protect, 0.0)


func test_spawned_signal_on_coming_back() -> void:
	var w: Array = _world()
	var p: Player = _player(w[0], w[1], &"flicker")
	watch_signals(p)
	p.sit_out()
	assert_signal_not_emitted(p, "spawned")
	p.respawn(Vector2(200, 200))
	assert_signal_emit_count(p, "spawned", 1)


# --- pickups -------------------------------------------------------------------------------------------------------------

func _field() -> PickupField:
	var map := ArenaMap.parse(["#####", "#E.E#", "#####"] as Array[String], 48.0)
	var f := PickupField.new()
	add_child_autofree(f)
	f.setup(map)
	return f


func test_collect_gives_energy_and_starts_the_timer() -> void:
	var w: Array = _world()
	var f: PickupField = _field()
	var p: Player = _player(w[0], null, &"flicker", &"dash", 1, f.spots[0])
	p.stats.energy = 20
	watch_signals(f)
	f.collect([p] as Array[Player])
	assert_eq(p.stats.energy, 20 + Constants.ENERGY_PICKUP_AMOUNT)
	assert_almost_eq(f.timers[0], Constants.PICKUP_RESPAWN, 0.001)
	assert_false(f.is_ready(0))
	assert_true(f.is_ready(1), "the other pad is untouched")
	assert_signal_emitted(f, "collected")
	assert_eq(f.collectors[0], 1)


func test_full_energy_leaves_it_and_far_players_skip_it() -> void:
	var w: Array = _world()
	var f: PickupField = _field()
	var full: Player = _player(w[0], null, &"flicker", &"dash", 1, f.spots[0])
	f.collect([full] as Array[Player])
	assert_true(f.is_ready(0), "no room for energy: stays")
	var far: Player = _player(w[0], null, &"flicker", &"dash", 2, f.spots[0] + Vector2(Constants.PICKUP_RADIUS + 20.0, 0.0))
	far.stats.energy = 0
	f.collect([far] as Array[Player])
	assert_true(f.is_ready(0), "out of reach")
	assert_eq(far.stats.energy, 0)


func test_energy_never_exceeds_max() -> void:
	var w: Array = _world()
	var f: PickupField = _field()
	var p: Player = _player(w[0], null, &"flicker", &"dash", 1, f.spots[0])
	p.stats.energy = p.stats.max_energy - 5
	f.collect([p] as Array[Player])
	assert_eq(p.stats.energy, p.stats.max_energy)


func test_dead_players_do_not_collect() -> void:
	var w: Array = _world()
	var f: PickupField = _field()
	var p: Player = _player(w[0], null, &"flicker", &"dash", 1, f.spots[0])
	p.stats.energy = 0
	p.sit_out()
	f.collect([p] as Array[Player])
	assert_true(f.is_ready(0))


func test_timer_counts_down_and_pad_comes_back() -> void:
	var w: Array = _world()
	var f: PickupField = _field()
	var p: Player = _player(w[0], null, &"flicker", &"dash", 1, f.spots[0])
	p.stats.energy = 0
	f.collect([p] as Array[Player])
	watch_signals(f)
	f.tick(Constants.PICKUP_RESPAWN * 0.5)
	assert_almost_eq(f.fill_fraction(0), 0.5, 0.001, "half way: the ring is half full")
	assert_signal_not_emitted(f, "respawned")
	f.tick(Constants.PICKUP_RESPAWN * 0.5 + 0.01)
	assert_true(f.is_ready(0))
	assert_eq(f.fill_fraction(0), 1.0)
	assert_signal_emit_count(f, "respawned", 1)
	f.tick(1.0)
	assert_signal_emit_count(f, "respawned", 1, "only announced once")


func test_empty_pad_cannot_be_collected_until_back() -> void:
	var w: Array = _world()
	var f: PickupField = _field()
	var p: Player = _player(w[0], null, &"flicker", &"dash", 1, f.spots[0])
	p.stats.energy = 0
	f.collect([p] as Array[Player])
	var after: int = p.stats.energy
	f.collect([p] as Array[Player])
	assert_eq(p.stats.energy, after, "second grab while empty gives nothing")


func test_state_mirrors_to_clients_and_reset_refills() -> void:
	var w: Array = _world()
	var f: PickupField = _field()
	var mirror: PickupField = _field()
	var p: Player = _player(w[0], null, &"flicker", &"dash", 3, f.spots[1])
	p.stats.energy = 0
	f.collect([p] as Array[Player])
	watch_signals(mirror)
	mirror.apply_array(f.to_array())
	assert_signal_emitted(mirror, "collected")
	assert_false(mirror.is_ready(1))
	assert_eq(mirror.collectors[1], 3)
	assert_almost_eq(mirror.timers[1], Constants.PICKUP_RESPAWN, 0.001)
	f.reset()
	mirror.apply_array(f.to_array())
	assert_true(mirror.is_ready(1))
	assert_signal_emitted(mirror, "respawned")


# --- stun cuts channelled specials ---------------------------------------------------------------------------------------

func test_stun_stops_staff_whirl() -> void:
	var w: Array = _world()
	var p: Player = _player(w[0], w[1], &"wukong", &"staff_whirl")
	var f := InputFrame.new()
	f.seq = 5
	f.special = true
	p.simulate(f, DT)
	assert_true(p.skills[1].is_active(), "spinning")
	p.stats.apply_stun(0.5)
	_run(p, 1)
	assert_false(p.skills[1].is_active(), "stun ends the spin")
	assert_gt(p.skills[1].cooldown_remaining, 0.0, "cooldown stays spent")


func test_stun_ends_petal_drift_and_its_iframes() -> void:
	var w: Array = _world()
	var p: Player = _player(w[0], w[1], &"sakura", &"petal_drift")
	var f := InputFrame.new()
	f.seq = 5
	f.special = true
	p.simulate(f, DT)
	assert_true(p.skills[1].is_active())
	assert_true(p.stats.is_invulnerable())
	p.stats.apply_stun(0.5)
	_run(p, 1)
	assert_false(p.skills[1].is_active())
	assert_false(p.stats.is_invulnerable(), "no free i-frames from a cut-short drift")
	assert_false(p.is_hidden())


func test_stun_surfaces_shadow_step_on_free_floor_without_the_strike() -> void:
	var w: Array = _world()
	var p: Player = _player(w[0], w[1], &"shadow", &"shadow_step")
	var foe: Player = _player(w[0], w[1], &"flicker", &"dash", 2, Vector2(330, 300))
	var hp: int = foe.stats.hp + foe.stats.armor
	var f := InputFrame.new()
	f.seq = 5
	f.special = true
	p.simulate(f, DT)
	assert_true(p.skills[1].is_active())
	p.stats.apply_stun(0.5)
	_run(p, 1)
	assert_false(p.skills[1].is_active(), "the step ends")
	assert_false(p.is_hidden(), "he's back")
	assert_eq(p.collision_mask, Constants.LAYER_WALL_FEET, "normal collisions again")
	assert_eq(foe.stats.hp + foe.stats.armor, hp, "an interrupted step doesn't burst")


func test_stun_interrupt_is_the_same_on_replay() -> void:
	var w: Array = _world()
	var a: Player = _player(w[0], w[1], &"wukong", &"staff_whirl", 1)
	var b: Player = _player(w[0], w[1], &"wukong", &"staff_whirl", 2)
	var f := InputFrame.new()
	f.seq = 5
	f.special = true
	a.simulate(f, DT)
	b.simulate(f, DT, true)
	a.stats.apply_stun(0.5)
	b.stats.apply_stun(0.5)
	_run(a, 3)
	_run(b, 3, false, true)
	assert_eq(a.skills[1].active_remaining, b.skills[1].active_remaining)
	assert_eq(a.global_position, b.global_position)
