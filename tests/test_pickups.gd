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
	assert_has(arena.catalog.pickup_ids(), spot.weapon_id)
	spot.weapon_id = &"sword"  # one the default character can carry
	p.global_position = spot.pos
	arena.pickups.tick(Constants.PHYSICS_DT, arena.players)
	assert_false(spot.available)
	assert_eq(p.loadout.weapon_ids(), PackedStringArray([String(p.character.signature_weapon.id), "sword"]))
	p.global_position = Vector2.ZERO
	arena.pickups.tick(Constants.WEAPON_PICKUP_RESPAWN + Constants.PHYSICS_DT, arena.players)
	assert_true(spot.available)


func test_pickup_state_mirrors_to_client_field() -> void:
	var arena := _arena()
	arena.pickups.spots[0].available = false
	var mirror := PickupField.new()
	mirror.authoritative = false
	add_child_autofree(mirror)
	mirror.setup(arena.map, arena.catalog, arena.catalog.pickup_ids(), 0)
	mirror.apply_array(arena.pickups.to_array())
	for i: int in mirror.spots.size():
		assert_eq(mirror.spots[i].available, arena.pickups.spots[i].available)
		assert_eq(mirror.spots[i].weapon_id, arena.pickups.spots[i].weapon_id)


func test_respawn_restores_default_loadout() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	p.loadout.give(catalog.get_weapon(&"smg"))
	p.respawn(Vector2(100, 100))
	assert_eq(p.loadout.weapon_ids(), PackedStringArray([String(p.character.signature_weapon.id)]))


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


func test_lobby_arena_switch_rebuilds_and_respawns() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	assert_eq(arena.crates.crates.size(), 0, "Pit has no crates")
	arena.referee.set_arena(1)
	assert_eq(arena.layout_index, 1)
	assert_true(arena.crates.crates.size() > 0)
	assert_true(p.dead, "off the field until respawned on the new map")
	await wait_physics_frames(2)
	assert_false(p.dead)
	assert_true(arena.map.spawns.has(p.global_position))


func test_character_pick_only_in_lobby() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	arena.select_character(p, &"warden")
	assert_eq(p.character.id, &"warden")
	arena.match_state.phase = MatchState.Phase.PLAYING
	arena.select_character(p, &"twinshot")
	assert_eq(p.character.id, &"warden")


func test_crates_reset_at_countdown() -> void:
	var arena := _arena(MatchRules.Mode.DUEL)
	arena.referee.set_arena(1)
	arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	arena.add_bot(Constants.BOT_ID_BASE, 1)
	var crate: Crate = arena.crates.crates[0]
	crate.take_damage(Constants.CRATE_HP)
	assert_false(crate.is_intact())
	arena.referee.set_ready(1, true)
	arena.referee.tick(Constants.PHYSICS_DT, [1] as Array[int], [Constants.BOT_ID_BASE] as Array[int], arena.scores)
	assert_true(crate.is_intact())


func test_weapon_pickup_needs_a_shared_tag() -> void:
	var chars := CharacterCatalog.load_all()
	var flicker: CharacterData = chars.get_character(&"flicker")
	var stats := PlayerStats.new()
	var l: Loadout = _loadout([&"flicker_kunai"])
	assert_false(PickupField.apply_to(PickupField.Kind.WEAPON, catalog.get_weapon(&"rocket"), stats, l, flicker),
		"Flicker can't carry heavy/explosive weapons")
	assert_eq(l.slots.size(), 1)
	assert_true(PickupField.apply_to(PickupField.Kind.WEAPON, catalog.get_weapon(&"sniper"), stats, l, flicker))


func test_unusable_pickup_stays_on_the_floor() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	var spot: PickupField.Spot = null
	for s: PickupField.Spot in arena.pickups.spots:
		if s.kind == PickupField.Kind.WEAPON:
			spot = s
			break
	spot.weapon_id = &"rocket"
	p.global_position = spot.pos
	arena.pickups.tick(Constants.PHYSICS_DT, arena.players)
	assert_true(spot.available)
	assert_eq(p.loadout.slots.size(), 1)


# --- loading room: starting weapon ---------------------------------------------

func test_starting_weapon_joins_the_signature_and_survives_respawn() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	arena.select_weapon(p, &"sniper")
	var expected := PackedStringArray([String(p.character.signature_weapon.id), "sniper"])
	assert_eq(p.loadout.weapon_ids(), expected)
	p.loadout.give(catalog.get_weapon(&"smg"))
	p.respawn(Vector2(100, 100))
	assert_eq(p.loadout.weapon_ids(), expected, "back to the picked loadout, pickups lost")


func test_starting_weapon_must_be_a_usable_pickup() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	for bad: StringName in [&"rocket", &"pistol", &"warden_hammer", &"nope"]:
		arena.select_weapon(p, bad)
		assert_eq(p.loadout.slots.size(), 1, String(bad))
	for w: WeaponData in arena.starting_weapons_for(p.character):
		assert_true(w.pickup and p.character.can_use(w), String(w.id))


func test_switching_character_drops_an_unusable_starting_weapon() -> void:
	var arena := _arena()
	var p: Player = arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, null)
	arena.select_weapon(p, &"sword")
	arena.select_character(p, &"twinshot")
	assert_null(p.starting_weapon, "Twinshot can't carry blades")
	assert_eq(p.loadout.weapon_ids(), PackedStringArray(["twinshot_revolver"]))
	arena.select_weapon(p, &"shotgun")
	arena.select_character(p, &"warden")
	assert_eq(p.loadout.weapon_ids(), PackedStringArray(["warden_hammer", "shotgun"]), "kept: Warden uses heavy")
