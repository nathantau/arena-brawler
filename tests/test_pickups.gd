extends GutTest
## Pickup effects, loadout rules for weapon pickups, and pickups/match integration in an Arena.

var catalog: WeaponCatalog


func before_all() -> void:
	catalog = WeaponCatalog.load_all()


func _loadout(ids: Array[StringName]) -> Loadout:
	return Loadout.new(catalog.resolve(ids))


func test_energy_pickup_refills_and_clamps() -> void:
	var stats := PlayerStats.new()
	assert_false(PickupField.apply_to(PickupField.Kind.ENERGY, null, stats, null), "full energy: leave it")
	stats.energy = stats.max_energy - 10
	assert_true(PickupField.apply_to(PickupField.Kind.ENERGY, null, stats, null))
	assert_eq(stats.energy, stats.max_energy)
	stats.energy = 0
	PickupField.apply_to(PickupField.Kind.ENERGY, null, stats, null)
	assert_eq(stats.energy, Constants.ENERGY_PICKUP_AMOUNT)


func test_weapon_pickup_fills_empty_slot_and_activates() -> void:
	var l := _loadout([&"pistol"])
	assert_true(l.give(catalog.get_weapon(&"smg")))
	assert_eq(l.weapon_ids(), PackedStringArray(["pistol", "smg"]))
	assert_eq(l.active_index, 1)


func test_weapon_pickup_already_carried_is_left() -> void:
	var l := _loadout([&"pistol", &"smg"])
	assert_false(l.give(catalog.get_weapon(&"smg")))
	assert_false(l.give(catalog.get_weapon(&"pistol")))


func test_weapon_pickup_never_replaces_sidearm() -> void:
	var l := _loadout([&"pistol", &"smg"])
	l.active_index = Constants.SIDEARM_SLOT
	assert_true(l.give(catalog.get_weapon(&"shotgun")))
	assert_eq(l.weapon_ids(), PackedStringArray(["pistol", "shotgun"]))
	assert_eq(l.active_index, 1)


func test_weapon_pickup_replaces_active_non_sidearm() -> void:
	var l := _loadout([&"pistol", &"smg"])
	l.active_index = 1
	assert_true(l.give(catalog.get_weapon(&"shotgun")))
	assert_eq(l.weapon_ids(), PackedStringArray(["pistol", "shotgun"]))


func test_layout_has_symmetric_pickups() -> void:
	var map := ArenaMap.parse(ArenaLayouts.PIT, Constants.TILE_SIZE)
	assert_true(map.energy_spots.size() >= 2)
	assert_true(map.weapon_spots.size() >= 2)
	for spots: PackedVector2Array in [map.energy_spots, map.weapon_spots]:
		for p: Vector2 in spots:
			assert_true(spots.has(map.size - p), "180° mirror of %s" % p)


func test_parse_pickup_chars() -> void:
	var map := ArenaMap.parse(["#E.W#"] as Array[String], 10.0)
	assert_eq(map.energy_spots, PackedVector2Array([Vector2(15, 5)]))
	assert_eq(map.weapon_spots, PackedVector2Array([Vector2(35, 5)]))


# --- in an arena ------------------------------------------------------------

func _arena(match_mode: MatchRules.Mode = MatchRules.Mode.FFA) -> Arena:
	var arena := Arena.new(Arena.Mode.OFFLINE, Constants.DEFAULT_MATCH_SEED, match_mode)
	add_child_autofree(arena)
	return arena


func test_pickup_collected_then_respawns() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	var spot: PickupField.Spot = null
	for s: PickupField.Spot in arena.pickups.spots:
		if s.kind == PickupField.Kind.WEAPON:
			spot = s
			break
	assert_has(Arena.PICKUP_WEAPONS, spot.weapon_id)
	p.global_position = spot.pos
	arena.pickups.tick(Constants.PHYSICS_DT, arena.players)
	assert_false(spot.available)
	assert_eq(p.loadout.weapon_ids(), PackedStringArray(["pistol", String(spot.weapon_id)]))
	p.global_position = Vector2.ZERO
	arena.pickups.tick(Constants.WEAPON_PICKUP_RESPAWN + Constants.PHYSICS_DT, arena.players)
	assert_true(spot.available)


func test_pickup_state_mirrors_to_client_field() -> void:
	var arena := _arena()
	arena.pickups.spots[0].available = false
	var mirror := PickupField.new()
	mirror.authoritative = false
	add_child_autofree(mirror)
	mirror.setup(arena.map, arena.catalog, Arena.PICKUP_WEAPONS, 0)
	mirror.apply_array(arena.pickups.to_array())
	for i: int in mirror.spots.size():
		assert_eq(mirror.spots[i].available, arena.pickups.spots[i].available)
		assert_eq(mirror.spots[i].weapon_id, arena.pickups.spots[i].weapon_id)


func test_respawn_restores_default_loadout() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	p.loadout.give(catalog.get_weapon(&"smg"))
	p.respawn(Vector2(100, 100))
	assert_eq(p.loadout.weapon_ids(), PackedStringArray(["pistol"]))


func test_frozen_player_ignores_input() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	var start: Vector2 = p.global_position
	p.frozen = true
	var f := InputFrame.new()
	f.move_vec = Vector2.RIGHT
	f.fire = true
	for i: int in 10:
		f.seq = i + 1
		p.simulate(f, Constants.PHYSICS_DT)
	assert_eq(p.global_position, start)
	assert_eq(arena.projectiles.active_count(), 0)
	assert_eq(p.last_input_seq, 10, "inputs are still acked while frozen")


func test_duel_countdown_seats_two_and_benches_the_rest() -> void:
	var arena := _arena(MatchRules.Mode.DUEL)
	var me: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	for i: int in 3:
		arena.add_bot(Constants.BOT_ID_BASE + i, arena.free_color_index())
	arena.scores.register_kill(1, Constants.BOT_ID_BASE)
	arena.referee.set_ready(1, true)
	arena.referee.tick(Constants.PHYSICS_DT, [1] as Array[int], [10, 11, 12] as Array[int], arena.scores)
	assert_eq(arena.match_state.phase, MatchState.Phase.COUNTDOWN)
	assert_eq(arena.scores.kills_of(1), 0, "warm-up kills don't count")
	assert_false(me.dead)
	assert_true(me.frozen)
	assert_false(arena.get_player(Constants.BOT_ID_BASE).dead, "first bot fills the duel")
	assert_true(arena.get_player(Constants.BOT_ID_BASE + 1).dead, "others sit out")
	assert_true(arena.get_player(Constants.BOT_ID_BASE + 2).dead)
	assert_eq(arena.scores.deaths_of(Constants.BOT_ID_BASE + 1), 0, "sitting out isn't a death")
	assert_ne(me.global_position, arena.get_player(Constants.BOT_ID_BASE).global_position)
