extends GutTest
## Duel / FFA lobby: bots never share a fighter with a human (or each other) while enough fighters exist, switch when
## a human picks theirs, and fall back to repeats when there are more players than fighters. Teams keeps its own rules.

const POOL: Array[StringName] = [&"a", &"b", &"c", &"d"]


func _server(mode: MatchRules.Mode) -> Arena:
	var arena := Arena.new(Arena.Mode.SERVER, 1, mode)
	add_child_autofree(arena)
	return arena


func test_pure_rule_moves_a_clashing_bot_to_a_free_fighter() -> void:
	var out: Array[StringName] = MatchRules.distinct_bot_picks(POOL, [&"a"], [&"a", &"b"])
	assert_eq(out, [&"b" as StringName, &"c" as StringName] as Array[StringName], "bot 1 -> next free b, bot 2 had b so -> c")


func test_pure_rule_keeps_a_clean_pick() -> void:
	var out: Array[StringName] = MatchRules.distinct_bot_picks(POOL, [&"a"], [&"c", &"d"])
	assert_eq(out, [&"c" as StringName, &"d" as StringName] as Array[StringName])


func test_pure_rule_falls_back_when_there_are_not_enough_fighters() -> void:
	# 4 fighters, 1 human + 4 bots: bots avoid the human, then repeat each other.
	var out: Array[StringName] = MatchRules.distinct_bot_picks(POOL, [&"a"], [&"a", &"a", &"a", &"a"])
	for pick: StringName in out:
		assert_ne(pick, &"a", "never the human's")
	# more humans than fighters: nothing to avoid, bots keep what they have
	var all: Array[StringName] = MatchRules.distinct_bot_picks([&"a"], [&"a"], [&"a"])
	assert_eq(all, [&"a" as StringName] as Array[StringName])


func test_human_picking_the_bots_fighter_makes_the_bot_switch() -> void:
	for mode: MatchRules.Mode in [MatchRules.Mode.DUEL, MatchRules.Mode.FFA]:
		var arena: Arena = _server(mode)
		var human: Player = arena.add_player(1, 0, BotBrain.new(arena, 1))
		var bot: Player = arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
		var target: CharacterData = bot.character
		await wait_physics_frames(2)
		arena.select_character(human, target.id)
		await wait_physics_frames(2)
		assert_eq(human.character, target)
		assert_ne(bot.character, target, "bot gave way (mode %d)" % mode)
		assert_true(arena.characters.ordered.has(bot.character), "in rotation")
		assert_eq(bot.skills.size(), Constants.SKILL_SLOTS, "abilities follow the new fighter")
		assert_true(bot.character.can_use_skill(bot.skills[0].data))
		arena.queue_free()


func test_bots_never_duplicate_humans_or_each_other_with_enough_fighters() -> void:
	var arena: Arena = _server(MatchRules.Mode.FFA)
	var humans: Array[Player] = [arena.add_player(1, 0, BotBrain.new(arena, 1)), arena.add_player(2, 1, BotBrain.new(arena, 2))]
	var bots: Array[Player] = []
	for i: int in 3:
		bots.append(arena.add_bot(Constants.BOT_ID_BASE + i, arena.free_color_index()))
	var fighters: Array[CharacterData] = arena.characters.ordered
	assert_gte(fighters.size(), humans.size() + bots.size())
	# the humans try every fighter in turn
	for c: CharacterData in fighters:
		arena.select_character(humans[0], c.id)
		arena.select_character(humans[1], fighters[(fighters.find(c) + 1) % fighters.size()].id)
		await wait_physics_frames(2)
		var seen: Array[StringName] = []
		for p: Player in humans + bots:
			assert_false(seen.has(p.character.id), "%s is unique" % p.character.id)
			seen.append(p.character.id)


func test_more_players_than_fighters_allows_repeats_without_flapping() -> void:
	var arena: Arena = _server(MatchRules.Mode.FFA)
	var human: Player = arena.add_player(1, 0, BotBrain.new(arena, 1))
	var n: int = arena.characters.ordered.size()
	var bots: Array[Player] = []
	for i: int in n + 1:
		bots.append(arena.add_bot(Constants.BOT_ID_BASE + i, arena.free_color_index()))
	await wait_physics_frames(3)
	var before: Array[StringName] = []
	for b: Player in bots:
		assert_ne(b.character, human.character, "still avoids the human")
		before.append(b.character.id)
	await wait_physics_frames(3)
	for i: int in bots.size():
		assert_eq(bots[i].character.id, before[i], "stable")


func test_teams_still_yields_only_to_locked_humans() -> void:
	var arena: Arena = _server(MatchRules.Mode.TEAMS)
	var human: Player = arena.add_player(1, 0, BotBrain.new(arena, 1))
	for i: int in 2:
		arena.add_bot(Constants.BOT_ID_BASE + i, arena.free_color_index())
	var snapshot: Array[StringName] = []
	await wait_physics_frames(3)
	for b: Player in arena.players:
		snapshot.append(b.character.id)
	arena.select_character(human, arena.players[1].character.id)  # a bare pick, not a lock
	await wait_physics_frames(3)
	assert_eq(arena.players[1].character.id, snapshot[1], "Teams: a hover does not move a bot")
