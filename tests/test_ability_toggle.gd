extends GutTest
## Loading room abilities are toggled: tapping an equipped one empties its slot, an empty slot cannot be readied, and
## the server fills any gap left at match start.

var arena: Arena
var me: Player


func before_each() -> void:
	arena = Arena.new(Arena.Mode.OFFLINE)
	add_child_autofree(arena)
	me = arena.add_player(1, 0, null)


func _ids() -> Array:
	return me.skills.map(func(s: CharacterSkill) -> StringName: return s.data.id)


func test_empty_id_clears_a_slot_and_a_pick_refills_it() -> void:
	arena.select_special(me, 1, &"")
	assert_true(arena.match_state.slot_empty(1, 1))
	assert_false(arena.match_state.slot_empty(1, 0))
	arena.select_special(me, 1, &"barrier")
	assert_false(arena.match_state.has_gap(1))
	assert_eq(me.skills[1].data.id, &"barrier")


func test_clear_slot_is_validated() -> void:
	arena.select_special(me, 2, &"")  # the ultimate slot is not pickable
	arena.select_special(me, -1, &"")
	assert_false(arena.match_state.has_gap(1), "slot out of range")
	arena.match_state.phase = MatchState.Phase.PLAYING
	arena.select_special(me, 0, &"")
	assert_false(arena.match_state.has_gap(1), "lobby only")


func test_clearing_is_refused_once_locked_in_teams() -> void:
	var teams := Arena.new(Arena.Mode.OFFLINE, 1, MatchRules.Mode.TEAMS)
	add_child_autofree(teams)
	var p: Player = teams.add_player(1, 0, null)
	teams.try_ready(1, true)
	assert_true(teams.is_locked_in(p))
	teams.select_special(p, 0, &"")
	assert_false(teams.match_state.has_gap(1))


func test_ready_is_refused_while_a_slot_is_empty() -> void:
	arena.select_special(me, 1, &"")
	arena.try_ready(1, true)
	assert_false(arena.match_state.ready.has(1))
	arena.select_special(me, 1, &"barrier")
	arena.try_ready(1, true)
	assert_true(arena.match_state.ready.has(1))


func test_a_new_fighter_starts_with_every_slot_empty() -> void:
	arena.select_character(me, &"eden")
	for slot: int in Constants.PICKED_SLOTS:
		assert_true(arena.match_state.slot_empty(1, slot), "slot %d empty" % slot)
	arena.try_ready(1, true)
	assert_false(arena.match_state.ready.has(1), "pick two first")
	for slot: int in Constants.PICKED_SLOTS:
		arena.select_special(me, slot, Player.default_skills(me.character)[slot].id)
	assert_false(arena.match_state.has_gap(1))
	arena.try_ready(1, true)
	assert_true(arena.match_state.ready.has(1))


func test_the_first_pick_empties_slots_even_for_the_default_fighter() -> void:
	arena.select_character(me, me.character.id)
	assert_eq(arena.match_state.gaps.get(1, 0), 3)
	arena.select_special(me, 0, &"dash")
	arena.select_character(me, me.character.id)  # tapping the same fighter again keeps the picks
	assert_false(arena.match_state.slot_empty(1, 0))


func test_the_weapon_still_defaults_to_the_signature() -> void:
	arena.select_character(me, &"eden")
	assert_eq(me.chosen_weapon.id if me.chosen_weapon != null else me.character.signature_weapon.id, me.character.signature_weapon.id)


func test_bots_keep_their_default_abilities() -> void:
	var bot: Player = arena.add_bot(Constants.BOT_ID_BASE, 1)
	arena.select_character(bot, &"eden")
	assert_false(arena.match_state.has_gap(bot.player_id))


func test_picking_an_ability_held_by_an_empty_slot_swaps_cleanly() -> void:
	var before: Array = _ids()
	arena.select_special(me, 0, &"")  # slot 0 emptied, still remembers Dash
	arena.select_special(me, 1, before[0])  # Dash tapped again into slot 1: swaps with the stale slot 0
	assert_eq(me.skills[1].data.id, before[0])
	assert_eq(me.skills[0].data.id, before[1], "the old slot 1 ability takes the freed slot")
	assert_false(arena.match_state.has_gap(1), "both are filled again")


func test_safety_fill_gives_every_empty_slot_a_distinct_default() -> void:
	arena.select_special(me, 0, &"")
	arena.select_special(me, 1, &"")
	arena.fill_gaps(me)
	assert_false(arena.match_state.has_gap(1))
	var ids: Array = _ids()
	for id: StringName in ids:
		assert_eq(ids.count(id), 1, "no duplicates")


func test_gaps_survive_the_state_round_trip() -> void:
	arena.select_special(me, 1, &"")
	var copy := MatchState.new()
	assert_true(copy.apply_array(arena.match_state.to_array()))
	assert_true(copy.slot_empty(1, 1))
	assert_false(copy.slot_empty(1, 0))
