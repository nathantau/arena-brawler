extends GutTest
## Teams 3v3: team balancing, no friendly fire, round flow (2 lives, elimination, timeout tiebreak, first to 5,
## reset between rounds) and Smoke Bomb visibility for allies.

const A: int = MatchRules.TEAM_A
const B: int = MatchRules.TEAM_B
const DT: float = 1.0 / 60.0
const HUMANS: Array[int] = [1]
const BOTS: Array[int] = [10, 11, 12, 13, 14]


func after_each() -> void:
	Player.viewer_team = 0


## A controller already in round 1 of a Teams match (human 1 picked team A, bots 10..14 balance the rest).
func _playing_controller() -> MatchController:
	var c := MatchController.new()
	c.set_mode(MatchRules.Mode.TEAMS)
	var sb := ScoreBoard.new()
	c.set_team(1, A)
	c.set_ready(1, true)
	c.tick(DT, HUMANS, BOTS, sb)
	assert_eq(c.state.phase, MatchState.Phase.COUNTDOWN)
	c.tick(Constants.MATCH_COUNTDOWN + 0.1, HUMANS, BOTS, sb)
	assert_eq(c.state.phase, MatchState.Phase.PLAYING)
	return c


func _kill_team(c: MatchController, team: int) -> void:
	for id: int in MatchRules.members(c.state.teams, team):
		c.on_death(id)
		c.on_death(id)


func _tick(c: MatchController, secs: float) -> void:
	c.tick(secs, HUMANS, BOTS, ScoreBoard.new())


# --- team assignment --------------------------------------------------------

func test_unassigned_players_are_balanced_3v3() -> void:
	var ids: Array[int] = [1, 10, 11, 12, 13, 14]
	var t: Dictionary[int, int] = MatchRules.assign_teams(ids, {1: B})
	assert_eq(t[1], B, "the pick is kept")
	assert_eq(MatchRules.members(t, A).size(), 3)
	assert_eq(MatchRules.members(t, B).size(), 3)


func test_lopsided_picks_never_leave_a_team_empty() -> void:
	var ids: Array[int] = [1, 2]
	var t: Dictionary[int, int] = MatchRules.assign_teams(ids, {1: A, 2: A})
	assert_eq(t[1], A)
	assert_eq(t[2], B, "half the roster per team at most")
	var four: Array[int] = [1, 2, 3, 4]
	var u: Dictionary[int, int] = MatchRules.assign_teams(four, {})
	assert_eq(MatchRules.members(u, A).size(), 2)


func test_lobby_pick_and_full_team() -> void:
	var c := MatchController.new()
	c.set_mode(MatchRules.Mode.TEAMS)
	for id: int in [1, 2, 3]:
		c.set_team(id, A)
	c.set_team(4, A)
	assert_eq(c.state.team_of(4), 0, "a team holds %d" % Constants.TEAM_SIZE)
	c.set_team(1, 0)
	c.set_team(4, A)
	assert_eq(c.state.team_of(4), A)


func test_match_start_locks_in_teams_and_lives() -> void:
	var c := _playing_controller()
	assert_eq(MatchRules.members(c.state.teams, A).size(), 3)
	assert_eq(MatchRules.members(c.state.teams, B).size(), 3)
	assert_eq(c.state.team_of(1), A)
	assert_eq(c.state.round_number, 1)
	for id: int in c.state.teams:
		assert_eq(c.state.lives_of(id), Constants.TEAMS_LIVES)


func test_state_roundtrip_carries_teams_and_round_score() -> void:
	var c := _playing_controller()
	c.state.round_scores = [0, 2, 1]
	c.state.intermission = 1.5
	c.state.round_winner = A
	var b := MatchState.new()
	assert_true(b.apply_array(c.state.to_array()))
	assert_eq(b.teams, c.state.teams)
	assert_eq(b.lives, c.state.lives)
	assert_eq(b.round_scores, [0, 2, 1] as Array[int])
	assert_eq(b.round_number, 1)
	assert_eq(b.round_winner, A)
	assert_almost_eq(b.intermission, 1.5, 0.001)
	var bad: Array = c.state.to_array()
	bad[MatchState.Field.ROUND_SCORES] = PackedInt32Array([1])
	assert_false(b.apply_array(bad))


# --- rounds -----------------------------------------------------------------

func test_two_lives_per_round() -> void:
	var c := _playing_controller()
	c.on_death(1)
	assert_eq(c.state.lives_of(1), 1)
	assert_true(c.state.may_respawn(1), "one respawn mid-round")
	c.on_death(1)
	assert_eq(c.state.lives_of(1), 0)
	assert_false(c.state.may_respawn(1), "out until the next round")
	assert_eq(c.state.round_number, 1, "the round goes on: their team still has players in")


func test_round_ends_when_a_team_is_out() -> void:
	var c := _playing_controller()
	var b_id: int = MatchRules.members(c.state.teams, B)[0]
	_kill_team(c, B)
	_tick(c, DT)
	assert_eq(c.state.round_scores[A], 1)
	assert_eq(c.state.round_scores[B], 0)
	assert_eq(c.state.round_winner, A)
	assert_gt(c.state.intermission, 0.0)
	assert_true(c.state.inputs_locked(), "frozen between rounds")
	assert_false(c.state.may_respawn(b_id), "no respawns during the intermission")


func test_one_survivor_keeps_the_round_alive() -> void:
	var c := _playing_controller()
	var b: Array[int] = MatchRules.members(c.state.teams, B)
	c.on_death(b[0])
	c.on_death(b[0])
	c.on_death(b[1])
	c.on_death(b[1])
	c.on_death(b[2])
	_tick(c, DT)
	assert_eq(c.state.round_scores[A], 0, "the last one still has a life")
	c.on_death(b[2])
	_tick(c, DT)
	assert_eq(c.state.round_scores[A], 1)


func test_timeout_more_players_alive_wins() -> void:
	var c := _playing_controller()
	var a: Array[int] = MatchRules.members(c.state.teams, A)
	var b: Array[int] = MatchRules.members(c.state.teams, B)
	c.living_hp = func() -> Dictionary: return {a[0]: 10, a[1]: 10, b[0]: 500}
	_tick(c, Constants.TEAMS_ROUND_TIME + 1.0)
	assert_eq(c.state.round_winner, A, "2 alive beat 1 alive however much HP")
	assert_eq(c.state.round_scores[A], 1)


func test_timeout_then_total_hp_then_tie() -> void:
	assert_eq(MatchRules.timeout_winner({1: A, 2: B}, {1: 40, 2: 70}), B, "equal alive: more total HP")
	assert_eq(MatchRules.timeout_winner({1: A, 2: B}, {1: 70, 2: 70}), 0, "full tie: no point")
	var c := _playing_controller()
	c.living_hp = func() -> Dictionary: return {1: 50, 11: 50}
	var b_first: int = MatchRules.members(c.state.teams, B)[0]
	c.living_hp = func() -> Dictionary: return {1: 50, b_first: 50}
	_tick(c, Constants.TEAMS_ROUND_TIME + 1.0)
	assert_eq(c.state.round_winner, 0)
	assert_eq(c.state.round_scores, [0, 0, 0] as Array[int])
	assert_gt(c.state.intermission, 0.0, "a tied round still moves on")


func test_next_round_resets_lives_and_clock_after_intermission() -> void:
	var c := _playing_controller()
	watch_signals(c)
	_kill_team(c, B)
	_tick(c, DT)
	_tick(c, Constants.TEAMS_INTERMISSION - 0.5)
	assert_signal_not_emitted(c, "round_started")
	_tick(c, 1.0)
	assert_signal_emitted(c, "round_started")
	assert_eq(c.state.round_number, 2)
	assert_eq(c.state.intermission, 0.0)
	assert_almost_eq(c.state.time_left, Constants.TEAMS_ROUND_TIME, 0.01)
	for id: int in c.state.teams:
		assert_eq(c.state.lives_of(id), Constants.TEAMS_LIVES)
	assert_eq(c.state.round_scores[A], 1, "score carries over")
	assert_true(c.state.may_respawn(MatchRules.members(c.state.teams, B)[0]))


func test_first_to_five_takes_the_match() -> void:
	var c := _playing_controller()
	for round_no: int in Constants.TEAMS_ROUND_TARGET - 1:
		_kill_team(c, B)
		_tick(c, DT)
		assert_eq(c.state.phase, MatchState.Phase.PLAYING, "%d wins is not enough" % (round_no + 1))
		_tick(c, Constants.TEAMS_INTERMISSION + 0.1)
	_kill_team(c, B)
	_tick(c, DT)
	assert_eq(c.state.round_scores[A], Constants.TEAMS_ROUND_TARGET)
	assert_eq(c.state.phase, MatchState.Phase.RESULTS)
	assert_eq(c.state.round_winner, A, "round_winner is the match winner at RESULTS")


func test_ties_do_not_count_toward_five() -> void:
	var c := _playing_controller()
	c.living_hp = func() -> Dictionary: return {}
	for i: int in Constants.TEAMS_ROUND_TARGET + 2:
		_tick(c, Constants.TEAMS_ROUND_TIME + 1.0)
		_tick(c, Constants.TEAMS_INTERMISSION + 0.1)
	assert_eq(c.state.phase, MatchState.Phase.PLAYING)
	assert_eq(c.state.round_scores, [0, 0, 0] as Array[int])


func test_back_to_lobby_clears_the_teams() -> void:
	var c := _playing_controller()
	c.state.round_scores = [0, Constants.TEAMS_ROUND_TARGET - 1, 0]
	_kill_team(c, B)
	_tick(c, DT)
	assert_eq(c.state.phase, MatchState.Phase.RESULTS)
	_tick(c, Constants.MATCH_RESULTS_TIME + 0.1)
	assert_eq(c.state.phase, MatchState.Phase.LOBBY)
	assert_true(c.state.teams.is_empty())
	assert_eq(c.state.round_scores, [0, 0, 0] as Array[int])
	assert_eq(c.state.round_number, 0)


func test_a_team_with_nobody_left_ends_the_match() -> void:
	var c := _playing_controller()
	var sb := ScoreBoard.new()
	for id: int in MatchRules.members(c.state.teams, B):
		c.remove_player(id, sb, HUMANS)
	assert_eq(c.state.phase, MatchState.Phase.RESULTS)


# --- arena: sides, no friendly fire, reset ----------------------------------

func _vitals(p: Player) -> int:
	return p.stats.hp + p.stats.armor


func _arena_with(count: int) -> Arena:
	var arena := Arena.new(Arena.Mode.SERVER, 1, MatchRules.Mode.TEAMS)  # no offline bots joining in
	add_child_autofree(arena)
	for i: int in count:
		var id: int = i + 1
		arena.match_state.teams[id] = A if i < count - 1 else B
		var p: Player = arena.add_player(id, i, BotBrain.new(arena, id), true)
		p.global_position = Vector2(150.0 + 100.0 * i, 72.0)  # the open top row of the Pit
	return arena


func test_no_friendly_fire_but_enemies_are_hurt() -> void:
	var arena: Arena = _arena_with(3)  # 1, 2 on A; 3 on B
	await wait_physics_frames(2)
	var pool: ProjectilePool = arena.projectiles
	var ally: Player = arena.get_player(2)
	var enemy: Player = arena.get_player(3)
	ally.stats.spawn_protect = 0.0
	enemy.stats.spawn_protect = 0.0
	var ally_hp: int = _vitals(ally)
	var enemy_hp: int = _vitals(enemy)
	pool.strike(1, 1, Vector2(200, 72), 250.0, 20, 0.0)
	assert_eq(_vitals(ally), ally_hp, "area ability ignores the teammate")
	assert_lt(_vitals(enemy), enemy_hp, "...and hits the enemy")
	pool.burn_segment(1, 2, Vector2(150, 72), Vector2(450, 72), 40.0, 15)
	assert_eq(_vitals(ally), ally_hp, "placed fire ignores the teammate")
	assert_true(pool._ally(1, ally))
	assert_false(pool._ally(1, enemy))


func test_shots_pass_through_allies_and_hit_enemies() -> void:
	var arena: Arena = _arena_with(3)
	await wait_physics_frames(2)
	var ally: Player = arena.get_player(2)
	var enemy: Player = arena.get_player(3)
	ally.stats.spawn_protect = 0.0
	enemy.stats.spawn_protect = 0.0
	arena.get_player(1).global_position = Vector2(150, 72)
	ally.global_position = Vector2(250, 72)
	enemy.global_position = Vector2(350, 72)
	await wait_physics_frames(1)
	var ally_hp: int = _vitals(ally)
	var enemy_hp: int = _vitals(enemy)
	var w: WeaponData = arena.catalog.get_weapon(&"pistol")
	arena.projectiles.fire_shot(1, 1, Vector2(150, 72), Vector2.RIGHT, w, 7)
	await wait_physics_frames(60)
	assert_eq(_vitals(ally), ally_hp, "the bullet flew through the teammate")
	assert_lt(_vitals(enemy), enemy_hp, "and hit the enemy behind")


func test_bots_never_target_teammates() -> void:
	var arena: Arena = _arena_with(3)
	await wait_physics_frames(2)
	arena.get_player(3).global_position = Vector2(1500, 1000)  # out of sight
	var brain := BotBrain.new(arena, 1)
	assert_eq(brain._nearest_visible_enemy(arena.get_player(1)), null, "the only one in sight is a teammate")
	assert_true(arena.get_player(1).is_ally(arena.get_player(2)))
	assert_false(arena.get_player(1).is_ally(arena.get_player(3)))


func test_teams_spawn_on_opposite_sides_and_round_reset_restores_everyone() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE, 1, MatchRules.Mode.TEAMS)
	add_child_autofree(arena)
	var me: Player = arena.add_player(1, 0, BotBrain.new(arena, 1))
	await wait_physics_frames(2)
	assert_eq(arena.players.size(), Constants.TEAMS_MAX_PLAYERS, "offline fills with bots")
	arena.referee.set_team(1, A)
	arena.referee.set_ready(1, true)
	await wait_physics_frames(2)
	arena.match_state.time_left = 0.05
	await wait_physics_frames(4)
	assert_eq(arena.match_state.phase, MatchState.Phase.PLAYING)
	var half: float = arena.map.size.x * 0.5
	for p: Player in arena.players:
		assert_ne(p.team, 0)
		assert_eq(p.global_position.x < half, p.team == A, "team %d starts on its own side" % p.team)
		p.stats.spawn_protect = 0.0
	# 2 lives: the first death respawns on the team's side, the second keeps them out for the round.
	me.take_hit(9999, false, Vector2.ZERO, 11)
	assert_true(me.dead)
	assert_eq(arena.match_state.lives_of(1), 1)
	me.respawn_timer = 0.01
	await wait_physics_frames(3)
	assert_false(me.dead, "respawned")
	assert_lt(me.global_position.x, half)
	me.stats.spawn_protect = 0.0
	me.take_hit(9999, false, Vector2.ZERO, 11)
	me.respawn_timer = 0.01
	await wait_physics_frames(3)
	assert_true(me.dead, "out for the rest of the round")
	# Round reset: full HP, back on their side, alive.
	var other: Player = arena.get_player(Constants.BOT_ID_BASE)
	other.stats.hp = 5
	other.global_position = Vector2(half * 1.5, 300.0)
	arena._on_round_started()
	assert_false(me.dead)
	assert_eq(other.stats.hp, other.stats.max_hp)
	assert_eq(other.global_position.x < half, other.team == A)


# --- Smoke Bomb ---------------------------------------------------------------

func test_allies_still_see_a_vanished_teammate_enemies_do_not() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p := Player.new()
	var chars: CharacterCatalog = CharacterCatalog.load_all()
	p.setup(2, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		chars.get_character(&"flicker"))
	world.add_child(p)
	p.team = A
	p.set_skill(1, SkillCatalog.shared().get_skill(&"smoke_bomb"))
	var f := InputFrame.new()
	f.seq = 5
	f.aim_vec = Vector2.RIGHT
	f.special = true
	p.simulate(f, DT)
	assert_true(p.is_vanished())
	Player.viewer_team = B
	assert_true(p.is_concealed(), "an enemy sees nothing")
	Player.viewer_team = A
	assert_false(p.is_concealed(), "a teammate still sees her (faded)")
	assert_true(p.is_hidden(), "but she is still untargetable")
