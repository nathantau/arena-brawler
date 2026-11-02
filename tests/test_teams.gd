extends GutTest
## Teams 3v3: team balancing, no friendly fire, round flow (unlimited 10 s respawns, timeout goes to the team with more kills, first to 5,
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


## `winner` takes one kill off the other team, then the round clock runs out.
func _win_round(c: MatchController, winner: int) -> void:
	var loser: int = MatchRules.other_team(winner)
	c.on_death(MatchRules.members(c.state.teams, loser)[0], Vector2.ZERO, MatchRules.members(c.state.teams, winner)[0])
	_tick(c, Constants.TEAMS_ROUND_TIME + 1.0)


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


func test_match_start_locks_in_teams() -> void:
	var c := _playing_controller()
	assert_eq(MatchRules.members(c.state.teams, A).size(), 3)
	assert_eq(MatchRules.members(c.state.teams, B).size(), 3)
	assert_eq(c.state.team_of(1), A)
	assert_eq(c.state.round_number, 1)


func test_state_roundtrip_carries_teams_and_round_score() -> void:
	var c := _playing_controller()
	c.state.round_scores = [0, 2, 1]
	c.state.intermission = 1.5
	c.state.round_winner = A
	var b := MatchState.new()
	assert_true(b.apply_array(c.state.to_array()))
	assert_eq(b.teams, c.state.teams)
	assert_eq(b.round_scores, [0, 2, 1] as Array[int])
	assert_eq(b.round_number, 1)
	assert_eq(b.round_winner, A)
	assert_almost_eq(b.intermission, 1.5, 0.001)
	var bad: Array = c.state.to_array()
	bad[MatchState.Field.ROUND_SCORES] = PackedInt32Array([1])
	assert_false(b.apply_array(bad))


# --- rounds -----------------------------------------------------------------

func test_teams_respawn_waits_10_s_and_never_runs_out() -> void:
	var c := _playing_controller()
	assert_eq(Constants.TEAMS_RESPAWN_DELAY, 10.0)
	for i: int in 20:
		c.on_death(1)
		assert_true(c.state.may_respawn(1), "death %d: still allowed back" % (i + 1))
	assert_eq(c.state.round_number, 1, "a wipe doesn't end the round")
	for id: int in MatchRules.members(c.state.teams, B):
		c.on_death(id)
	_tick(c, DT)
	assert_eq(c.state.round_scores, [0, 0, 0] as Array[int], "a whole team dead is not a round result")
	assert_eq(c.state.intermission, 0.0)


func test_no_respawns_during_the_intermission() -> void:
	var c := _playing_controller()
	_win_round(c, A)
	assert_gt(c.state.intermission, 0.0)
	assert_true(c.state.inputs_locked(), "frozen between rounds")
	assert_false(c.state.may_respawn(MatchRules.members(c.state.teams, B)[0]))


func test_timeout_goes_to_the_team_with_more_kills() -> void:
	var c := _playing_controller()
	var a: Array[int] = MatchRules.members(c.state.teams, A)
	var b: Array[int] = MatchRules.members(c.state.teams, B)
	c.on_death(b[0], Vector2.ZERO, a[0])
	c.on_death(b[1], Vector2.ZERO, a[1])
	c.on_death(a[0], Vector2.ZERO, b[0])
	c.on_death(a[2], Vector2.ZERO, a[1])  # a team kill and a suicide count for nobody
	c.on_death(a[2], Vector2.ZERO, a[2])
	_tick(c, Constants.TEAMS_ROUND_TIME - 1.0)
	assert_eq(c.state.round_scores, [0, 0, 0] as Array[int], "the clock is still running")
	_tick(c, 2.0)
	assert_eq(c.state.round_winner, A, "2 kills beat 1")
	assert_eq(c.state.round_reason, MatchRules.Reason.TIMEOUT)
	assert_eq(c.state.round_scores[A], 1)


func test_timeout_tie_scores_nobody() -> void:
	assert_eq(MatchRules.timeout_winner([0, 3, 1] as Array[int]), A)
	assert_eq(MatchRules.timeout_winner([0, 1, 3] as Array[int]), B)
	assert_eq(MatchRules.timeout_winner([0, 2, 2] as Array[int]), 0, "equal kills: nobody")
	var c := _playing_controller()
	_tick(c, Constants.TEAMS_ROUND_TIME + 1.0)
	assert_eq(c.state.round_winner, 0)
	assert_eq(c.state.round_scores, [0, 0, 0] as Array[int])
	assert_gt(c.state.intermission, 0.0, "a tied round still moves on")


func test_round_kills_reset_for_the_next_round() -> void:
	var c := _playing_controller()
	var a: Array[int] = MatchRules.members(c.state.teams, A)
	var b: Array[int] = MatchRules.members(c.state.teams, B)
	c.on_death(b[0], Vector2.ZERO, a[0])
	_tick(c, Constants.TEAMS_ROUND_TIME + 1.0)
	_tick(c, Constants.TEAMS_INTERMISSION + 0.1)
	assert_eq(c.state.round_number, 2)
	_tick(c, Constants.TEAMS_ROUND_TIME + 1.0)
	assert_eq(c.state.round_winner, 0, "round 1's kill doesn't carry over")


func test_next_round_resets_the_clock_after_intermission() -> void:
	var c := _playing_controller()
	watch_signals(c)
	_win_round(c, A)
	_tick(c, Constants.TEAMS_INTERMISSION - 0.5)
	assert_signal_not_emitted(c, "round_started")
	_tick(c, 1.0)
	assert_signal_emitted(c, "round_started")
	assert_eq(c.state.round_number, 2)
	assert_eq(c.state.intermission, 0.0)
	assert_almost_eq(c.state.time_left, Constants.TEAMS_ROUND_TIME, 0.01)
	assert_eq(c.state.round_scores[A], 1, "score carries over")
	assert_true(c.state.may_respawn(MatchRules.members(c.state.teams, B)[0]))


func test_first_to_five_takes_the_match() -> void:
	var c := _playing_controller()
	for round_no: int in Constants.TEAMS_ROUND_TARGET - 1:
		_win_round(c, A)
		assert_eq(c.state.phase, MatchState.Phase.PLAYING, "%d wins is not enough" % (round_no + 1))
		_tick(c, Constants.TEAMS_INTERMISSION + 0.1)
	_win_round(c, A)
	assert_eq(c.state.round_scores[A], Constants.TEAMS_ROUND_TARGET)
	assert_eq(c.state.phase, MatchState.Phase.RESULTS)
	assert_eq(c.state.round_winner, A, "round_winner is the match winner at RESULTS")


func test_ties_do_not_count_toward_five() -> void:
	var c := _playing_controller()
	for i: int in Constants.TEAMS_ROUND_TARGET + 2:
		_tick(c, Constants.TEAMS_ROUND_TIME + 1.0)
		_tick(c, Constants.TEAMS_INTERMISSION + 0.1)
	assert_eq(c.state.phase, MatchState.Phase.PLAYING)
	assert_eq(c.state.round_scores, [0, 0, 0] as Array[int])


func test_back_to_lobby_clears_the_teams() -> void:
	var c := _playing_controller()
	c.state.round_scores = [0, Constants.TEAMS_ROUND_TARGET - 1, 0]
	_win_round(c, A)
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
	# Unlimited respawns after 10 s, on the team's side.
	me.take_hit(9999, false, Vector2.ZERO, 11)
	assert_true(me.dead)
	assert_eq(me.respawn_timer, Constants.TEAMS_RESPAWN_DELAY, "the countdown the HUD shows (clients get it in the snapshot)")
	me.respawn_timer = 0.01
	await wait_physics_frames(3)
	assert_false(me.dead, "respawned")
	assert_lt(me.global_position.x, half)
	me.stats.spawn_protect = 0.0
	me.take_hit(9999, false, Vector2.ZERO, 11)
	me.respawn_timer = 0.01
	await wait_physics_frames(3)
	assert_false(me.dead, "and again: never out")
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


# --- capture the flag ---------------------------------------------------------

func _thief(c: MatchController) -> int:
	return MatchRules.members(c.state.teams, B)[0]


func test_enemy_picks_up_the_flag_and_only_enemies_do() -> void:
	var c := _playing_controller()
	var a_id: int = MatchRules.members(c.state.teams, A)[0]
	c.flag_pickup(a_id, A)
	assert_eq(c.state.flag_state[A], MatchState.Flag.HOME, "an owner can't pick up their own flag")
	var thief: int = _thief(c)
	c.flag_pickup(thief, A)
	assert_eq(c.state.flag_state[A], MatchState.Flag.CARRIED)
	assert_eq(c.state.flag_carrier[A], thief)
	assert_eq(c.state.carried_flag_of(thief), A)
	var other: int = MatchRules.members(c.state.teams, B)[1]
	c.flag_pickup(other, A)
	assert_eq(c.state.flag_carrier[A], thief, "already carried")


func test_capture_wins_the_round_at_once() -> void:
	var c := _playing_controller()
	var thief: int = _thief(c)
	c.flag_pickup(thief, A)
	c.flag_capture(thief, ScoreBoard.new())
	assert_eq(c.state.round_scores[B], 1)
	assert_eq(c.state.round_winner, B)
	assert_eq(c.state.round_reason, MatchRules.Reason.CAPTURE)
	assert_gt(c.state.intermission, 0.0)
	assert_eq(c.state.flag_state[A], MatchState.Flag.HOME)
	var nobody: int = MatchRules.members(c.state.teams, A)[0]
	c.state.intermission = 0.0
	c.flag_capture(nobody, ScoreBoard.new())
	assert_eq(c.state.round_scores[A], 0, "no flag, no capture")


func test_capture_works_while_your_own_flag_is_away() -> void:
	var c := _playing_controller()
	var a: Array[int] = MatchRules.members(c.state.teams, A)
	var b: Array[int] = MatchRules.members(c.state.teams, B)
	c.flag_pickup(a[0], B)  # their flag is carried off...
	c.flag_pickup(b[0], A)
	c.flag_capture(b[0], ScoreBoard.new())
	assert_eq(c.state.round_scores[B], 1, "...and the capture still counts")


func test_flag_drops_where_the_carrier_dies() -> void:
	var c := _playing_controller()
	var thief: int = _thief(c)
	c.flag_pickup(thief, A)
	c.on_death(thief, Vector2(321, 654))
	assert_eq(c.state.flag_state[A], MatchState.Flag.DROPPED)
	assert_eq(c.state.flag_pos[A], Vector2(321, 654))
	assert_eq(c.state.flag_carrier[A], 0)
	assert_almost_eq(c.state.flag_timer[A], Constants.FLAG_RETURN_TIME, 0.001)
	var again: int = MatchRules.members(c.state.teams, B)[1]
	c.flag_pickup(again, A)
	assert_eq(c.state.flag_state[A], MatchState.Flag.CARRIED, "an enemy touching it picks it up again")


func test_owner_returns_a_dropped_flag() -> void:
	var c := _playing_controller()
	var thief: int = _thief(c)
	c.flag_pickup(thief, A)
	c.on_death(thief, Vector2(100, 100))
	c.flag_return(A)
	assert_eq(c.state.flag_state[A], MatchState.Flag.HOME)
	assert_eq(c.state.flag_timer[A], 0.0)


func test_dropped_flag_flies_home_after_8_seconds() -> void:
	var c := _playing_controller()
	var thief: int = _thief(c)
	c.flag_pickup(thief, A)
	c.on_death(thief, Vector2(100, 100))
	_tick(c, Constants.FLAG_RETURN_TIME - 1.0)
	assert_eq(c.state.flag_state[A], MatchState.Flag.DROPPED, "still lying after 7 s")
	_tick(c, 1.5)
	assert_eq(c.state.flag_state[A], MatchState.Flag.HOME)


func test_a_carrier_who_leaves_sends_the_flag_home() -> void:
	var c := _playing_controller()
	var thief: int = _thief(c)
	c.flag_pickup(thief, A)
	c.remove_player(thief, ScoreBoard.new(), HUMANS)
	assert_eq(c.state.flag_state[A], MatchState.Flag.HOME)


func test_flags_reset_for_the_next_round_and_survive_state_sync() -> void:
	var c := _playing_controller()
	var thief: int = _thief(c)
	c.flag_pickup(thief, A)
	c.on_death(thief, Vector2(12, 34))
	c.state.flag_timer[A] = 5.5
	var copy := MatchState.new()
	assert_true(copy.apply_array(c.state.to_array()))
	assert_eq(copy.flag_state[A], MatchState.Flag.DROPPED)
	assert_eq(copy.flag_pos[A], Vector2(12, 34))
	assert_almost_eq(copy.flag_timer[A], 5.5, 0.01)
	_win_round(c, B)
	_tick(c, Constants.TEAMS_INTERMISSION + 0.1)
	assert_eq(c.state.flag_state[A], MatchState.Flag.HOME)


func _flag_arena() -> Arena:
	var arena: Arena = _arena_with(3)  # 1, 2 on A; 3 on B
	var st: MatchState = arena.match_state
	st.phase = MatchState.Phase.PLAYING
	st.participants = [1, 2, 3]
	st.time_left = 60.0
	st.round_number = 1
	return arena


func test_touching_flags_picks_up_returns_and_captures() -> void:
	var arena: Arena = _flag_arena()
	var st: MatchState = arena.match_state
	var thief: Player = arena.get_player(3)
	thief.global_position = arena.flag_base(A)
	arena._tick_flags()
	assert_eq(st.flag_state[A], MatchState.Flag.CARRIED, "walking over the enemy flag picks it up")
	assert_true(thief.flag_carrier, "and the player knows")
	assert_ne(arena.flag_base(A), arena.flag_base(B))
	assert_lt(arena.flag_base(A).x, arena.map.size.x * 0.5, "A's base is on A's side")
	thief.global_position = arena.flag_base(B)
	arena._tick_flags()
	assert_eq(st.round_scores[B], 1, "bringing it to their own pad captures")
	assert_eq(st.round_reason, MatchRules.Reason.CAPTURE)


func test_owner_touching_a_dropped_flag_returns_it() -> void:
	var arena: Arena = _flag_arena()
	var st: MatchState = arena.match_state
	st.flag_state[A] = MatchState.Flag.DROPPED
	st.flag_pos[A] = Vector2(300, 72)
	st.flag_timer[A] = 5.0
	arena.get_player(1).global_position = Vector2(300, 72)
	arena.get_player(3).global_position = Vector2(1500, 1000)
	arena._tick_flags()
	assert_eq(st.flag_state[A], MatchState.Flag.HOME, "the owner's touch returns it instantly")


func test_carrier_is_slower_cannot_dash_and_is_never_concealed() -> void:
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
	p.global_position = Vector2(300, 300)
	p.set_skill(1, SkillCatalog.shared().get_skill(&"smoke_bomb"))
	var f := InputFrame.new()
	f.aim_vec = Vector2.RIGHT
	f.move_vec = Vector2.RIGHT
	for i: int in 40:
		f.seq += 1
		p.simulate(f, DT)
	var free_speed: float = p.velocity.length()
	p.velocity = Vector2.ZERO
	p.flag_carrier = true
	for i: int in 40:
		f.seq += 1
		p.simulate(f, DT)
	assert_almost_eq(p.velocity.length() / free_speed, Constants.FLAG_CARRIER_SPEED_SCALE, 0.02, "0.85x speed")
	assert_true(p.skill_locked(0), "Dash is locked")
	f.move_vec = Vector2.ZERO
	f.skill = true
	f.seq += 1
	p.simulate(f, DT)
	assert_null(p.active_skill(SkillData.Kind.DASH), "no dash while carrying")
	assert_true(p.skills[0].is_ready(), "and no cooldown spent")
	f.skill = false
	f.special = true  # Smoke Bomb: allowed to cast, but it does not hide a carrier
	f.seq += 1
	p.simulate(f, DT)
	Player.viewer_team = B
	assert_false(p.is_concealed(), "a carrier is never concealed")
	assert_false(p.is_hidden(), "and can be targeted")


func test_every_movement_special_is_locked_for_a_carrier() -> void:
	for kind: SkillData.Kind in [SkillData.Kind.DASH, SkillData.Kind.SWING, SkillData.Kind.GRAPPLE, SkillData.Kind.STEP,
			SkillData.Kind.DRIFT, SkillData.Kind.TRAIL]:
		assert_true(Player.CARRIER_BLOCKED_KINDS.has(kind), "kind %d" % kind)


func test_one_and_a_half_times_hp_only_in_teams() -> void:
	var teams := Arena.new(Arena.Mode.SERVER, 1, MatchRules.Mode.TEAMS)
	add_child_autofree(teams)
	var a: Player = teams.add_player(1, 0, BotBrain.new(teams, 1))
	var ffa := Arena.new(Arena.Mode.SERVER, 1, MatchRules.Mode.FFA)
	add_child_autofree(ffa)
	var b: Player = ffa.add_player(1, 0, BotBrain.new(ffa, 1))
	var duel := Arena.new(Arena.Mode.SERVER, 1, MatchRules.Mode.DUEL)
	add_child_autofree(duel)
	var c: Player = duel.add_player(1, 0, BotBrain.new(duel, 1))
	assert_eq(a.stats.max_hp, roundi(a.character.max_hp * Constants.TEAMS_HP_SCALE))
	assert_eq(a.stats.hp, a.stats.max_hp, "spawns full")
	assert_eq(b.stats.max_hp, b.character.max_hp)
	assert_eq(c.stats.max_hp, c.character.max_hp)
	a.stats.hp = 10
	a.stats.heal(1000)
	assert_eq(a.stats.hp, a.stats.max_hp, "heals cap at the new maximum")
	teams.match_state.mode = MatchRules.Mode.FFA
	teams._apply_teams()
	assert_eq(a.stats.max_hp, a.character.max_hp, "switching the mode back restores it")


func test_carried_flag_rides_the_carrier_and_hides_when_he_dies() -> void:
	var arena: Arena = _flag_arena()
	var field := FlagField.new()
	field.arena = arena
	arena.add_child(field)
	var st: MatchState = arena.match_state
	var thief: Player = arena.get_player(3)
	st.flag_state[A] = MatchState.Flag.CARRIED
	st.flag_carrier[A] = 3
	await wait_process_frames(2)
	assert_true(field._holders[A].visible, "the flag shows on the carrier")
	assert_true(field._carried[A].visible, "as the hovering banner")
	var bar_top: float = thief.global_position.y - Constants.PLAYER_RADIUS - Player.BAR_OFFSET_Y \
		- Player.BAR_HEIGHT * 2.0 - Player.BAR_GAP
	var flag_bottom: float = field._carried[A].global_position.y
	assert_lt(flag_bottom, bar_top - FlagField.HOVER_GAP + FlagField.HOVER_BOB + 0.5, "floats above the HP bar")
	assert_eq(field._holders[A].z_index, FlagField.HOVER_Z, "drawn above walls and fighters")
	assert_almost_eq(field._carried[A].global_position.x, thief.global_position.x, 0.5, "centred over his head")
	assert_false(field._flags[A].visible, "not the planted one")
	thief.respawn_timer = 99.0
	thief._set_dead(true)  # dying: the referee drops the flag a frame later, the view must not draw it meanwhile
	await wait_process_frames(2)
	assert_false(field._holders[A].visible, "no flag on a dead carrier: it has dropped")
	st.flag_state[A] = MatchState.Flag.DROPPED
	st.flag_pos[A] = Vector2(500, 72)
	await wait_process_frames(2)
	assert_true(field._flags[A].visible, "the dropped flag stands where it fell")
	assert_false(field._carried[A].visible)


func test_team_picker_is_hidden_offline_and_shown_on_lan() -> void:
	assert_false(LobbyPanel.shows_team_picker(MatchRules.Mode.TEAMS, Arena.Mode.OFFLINE), "offline: auto-placed")
	assert_true(LobbyPanel.shows_team_picker(MatchRules.Mode.TEAMS, Arena.Mode.SERVER), "friends group up on a LAN")
	assert_true(LobbyPanel.shows_team_picker(MatchRules.Mode.TEAMS, Arena.Mode.CLIENT))
	assert_false(LobbyPanel.shows_team_picker(MatchRules.Mode.FFA, Arena.Mode.SERVER), "no teams in FFA")


func test_round_banner_and_result_text_are_viewer_relative() -> void:
	var cap: int = MatchRules.Reason.CAPTURE
	var wipe: int = MatchRules.Reason.TIMEOUT
	for viewer: int in [A, B]:
		var other: int = MatchRules.other_team(viewer)
		assert_eq(MatchRules.round_banner_text(viewer, cap, viewer), "Your team captured the flag!")
		assert_eq(MatchRules.round_banner_text(other, cap, viewer), "Enemies captured your flag!")
		assert_eq(MatchRules.round_banner_text(viewer, wipe, viewer), "Your team wins the round!")
		assert_eq(MatchRules.round_banner_text(other, wipe, viewer), "Enemy team wins the round")
		assert_eq(MatchRules.result_title(viewer, viewer), "VICTORY!")
		assert_eq(MatchRules.result_title(other, viewer), "DEFEAT")
	assert_eq(MatchRules.round_banner_text(0, wipe, A), "Round drawn")
	assert_eq(MatchRules.result_title(0, B), "DRAW")
	for t: String in [MatchRules.round_banner_text(A, cap, B), MatchRules.result_title(B, A)]:
		assert_false(t.contains("Team A") or t.contains("Team B"), "no letters shown to the player")


func test_every_weapon_hook_fits_its_lobby_card() -> void:
	var avail: float = LobbyPanel.WEAPON_TEXT_W
	for file: String in DirAccess.get_files_at("res://data/weapons"):
		if not file.ends_with(".tres"):
			continue
		var w: WeaponData = load("res://data/weapons/" + file)
		if w == null or w.hook == "":
			continue
		assert_lte(UiStyle.body_font().get_string_size(w.hook, HORIZONTAL_ALIGNMENT_LEFT, -1, LobbyPanel.LIST_TEXT_SIZE).x, avail, "%s hook fits the card: %s" % [file, w.hook])


# --- team spawns around the flag base ---------------------------------------
func test_team_spawns_cluster_at_own_flag_base() -> void:
	var tile: float = Constants.TILE_SIZE
	for i: int in ArenaLayouts.count():
		var map: ArenaMap = ArenaMap.parse(ArenaLayouts.get_layout(i), tile)
		for team: int in [A, B]:
			var base: Vector2 = map.flag_base(team, tile)
			var pts: PackedVector2Array = map.base_spawns(team, tile)
			assert_gte(pts.size(), 3, "layout %d team %d has spawns" % [i, team])
			for p: Vector2 in pts:
				assert_lte(p.distance_to(base), 4.0 * tile, "near base")
				assert_eq(p.x < map.size.x * 0.5, team == A, "own half")
				var r: Rect2 = Rect2(p - Vector2.ONE * Constants.PLAYER_RADIUS, Vector2.ONE * Constants.PLAYER_RADIUS * 2.0)
				for w: Rect2 in map.walls:
					assert_false(w.intersects(r), "spawn %s overlaps wall" % p)


func test_duel_respawn_is_still_2_s() -> void:
	assert_eq(Constants.RESPAWN_DELAY, 2.0)
	var arena := Arena.new(Arena.Mode.OFFLINE, 1, MatchRules.Mode.DUEL)
	add_child_autofree(arena)
	var me: Player = arena.add_player(1, 0, BotBrain.new(arena, 1))
	await wait_physics_frames(2)
	me.stats.spawn_protect = 0.0
	me.take_hit(9999, false, Vector2.ZERO, 11)
	assert_true(me.dead)
	assert_eq(me.respawn_timer, 2.0)


# --- Team readability (ring + bar colour by relation) -------------------------

func _reader(id: int, team_id: int) -> Player:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
		CharacterCatalog.load_all().get_character(&"flicker"))
	world.add_child(p)
	p.team = team_id
	return p


func test_ring_and_bar_colour_follow_the_viewer_relation() -> void:
	Player.viewer_team = A
	var ally: Player = _reader(2, A)
	var enemy: Player = _reader(3, B)
	var me: Player = _reader(4, A)
	me.is_local = true
	assert_eq(ally.team_ring_color(), Player.COLOR_ALLY)
	assert_eq(enemy.team_ring_color(), Player.COLOR_ENEMY)
	assert_eq(me.team_ring_color(), Player.COLOR_ME)
	assert_eq(ally.bar_color(), Player.COLOR_BAR_ALLY)
	assert_eq(enemy.bar_color(), Player.COLOR_BAR_ENEMY)
	enemy.team = 0  # no teams: no ring, rivals have red bars
	assert_eq(enemy.team_ring_color().a, 0.0)
	assert_eq(enemy.bar_color(), Player.COLOR_BAR_ENEMY)
	Player.viewer_team = 0


func test_hidden_enemy_has_no_ring_but_hidden_ally_does() -> void:
	Player.viewer_team = A
	var enemy: Player = _reader(3, B)
	enemy.set_skill(1, SkillCatalog.shared().get_skill(&"smoke_bomb"))
	var f := InputFrame.new()
	f.seq = 5
	f.aim_vec = Vector2.RIGHT
	f.special = true
	enemy.simulate(f, DT)
	assert_true(enemy.is_hidden())
	assert_eq(enemy.team_ring_color().a, 0.0, "a hiding enemy must not reveal itself")
	enemy.team = A
	assert_gt(enemy.team_ring_color().a, 0.0)
	Player.viewer_team = 0
