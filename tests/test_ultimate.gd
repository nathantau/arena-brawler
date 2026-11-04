extends GutTest
## Charged ultimates: slot 2 is fixed per fighter, charge fills with time and damage dealt, using it empties it.

const DT: float = 1.0 / 60.0

var characters: CharacterCatalog


func before_all() -> void:
	characters = CharacterCatalog.load_all()


func _duo(who: StringName = &"wukong") -> Array[Player]:
	var world := Node2D.new()
	add_child_autofree(world)
	var pool := ProjectilePool.new()
	pool.authoritative = true
	world.add_child(pool)
	var out: Array[Player] = []
	for id: int in [1, 2]:
		var p := Player.new()
		p.setup(id, id - 1, Color.WHITE, WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName]), null, pool, 3,
			characters.get_character(who))
		world.add_child(p)
		p.global_position = Vector2(300 + 200 * id, 300)
		out.append(p)
		pool.targets.append(p)
	return out


func _step(p: Player, press: bool = false, seq: int = 1) -> void:
	var f := InputFrame.new()
	f.seq = seq
	f.aim_vec = Vector2.RIGHT
	f.special2 = press
	p.simulate(f, DT)


func test_starts_empty_and_fills_in_sixty_seconds() -> void:
	var p: Player = _duo()[0]
	assert_eq(p.ult_charge, 0.0)
	for i: int in 30 * 60:
		_step(p, false, i)
	assert_almost_eq(p.ult_charge, 0.5, 0.01, "half after 30 s")
	for i: int in 31 * 60:
		_step(p, false, i)
	assert_eq(p.ult_charge, 1.0, "capped at full")


func test_damage_dealt_to_an_enemy_charges_it() -> void:
	var duo: Array[Player] = _duo()
	var pool: ProjectilePool = duo[0].projectiles
	pool._damage_player(duo[1], 1, 1, 0, 30, false, Vector2.ZERO, Vector2.ZERO)
	assert_almost_eq(duo[0].ult_charge, 30.0 / Constants.ULT_DAMAGE_PER_CHARGE, 0.0001)
	assert_eq(duo[1].ult_charge, 0.0, "the victim gains nothing")
	pool._damage_player(duo[0], 1, 2, 0, 20, false, Vector2.ZERO, Vector2.ZERO)  # hitting yourself does not count
	assert_almost_eq(duo[0].ult_charge, 30.0 / Constants.ULT_DAMAGE_PER_CHARGE, 0.0001)
	for i: int in 10:
		pool._damage_player(duo[1], 1, 3 + i, 0, 1, false, Vector2.ZERO, Vector2.ZERO)
	assert_lt(duo[0].ult_charge, 1.0)
	duo[0].add_ult_damage(int(Constants.ULT_DAMAGE_PER_CHARGE))
	assert_eq(duo[0].ult_charge, 1.0, "300 damage = a full charge, capped")


func test_not_authoritative_pool_does_not_charge() -> void:
	var duo: Array[Player] = _duo()
	duo[0].projectiles.authoritative = false
	duo[0].projectiles.credit_damage(1, duo[1], 50)
	assert_eq(duo[0].ult_charge, 0.0, "clients only predict the passive part")


func test_press_is_refused_when_not_full() -> void:
	var p: Player = _duo()[0]
	p.ult_charge = 0.9
	_step(p, true)
	assert_false(p.skills[2].is_active())
	assert_almost_eq(p.ult_charge, 0.9, 0.01, "nothing spent")


func test_press_when_full_uses_it_and_empties_the_charge() -> void:
	var p: Player = _duo()[0]
	p.ult_charge = 1.0
	_step(p, true)
	assert_true(p.skills[2].is_active(), "Great Ape is on")
	assert_lt(p.ult_charge, 0.01)
	assert_eq(p.skills[2].cooldown_remaining, 0.0, "the ultimate's own cooldown is ignored")
	p.skills[2].active_remaining = 0.0
	_step(p, false, 2)
	_step(p, true, 3)
	assert_false(p.skills[2].is_active(), "empty again: refused")


func test_charge_survives_death_and_respawn() -> void:
	var p: Player = _duo()[0]
	p.ult_charge = 0.6
	p.take_hit(10000, false, Vector2.ZERO, 2)
	assert_true(p.dead)
	assert_almost_eq(p.ult_charge, 0.6, 0.0001)
	p.respawn(Vector2(300, 300))
	assert_almost_eq(p.ult_charge, 0.6, 0.0001, "not reset on death")


func test_match_start_resets_the_charge_but_a_new_round_keeps_it() -> void:
	var arena := Arena.new(Arena.Mode.OFFLINE, 1, MatchRules.Mode.TEAMS)
	add_child_autofree(arena)
	var p: Player = arena.add_player(1, 0, null)
	p.ult_charge = 0.8
	arena._on_round_started()
	assert_eq(p.ult_charge, 0.8, "new Teams round keeps it")
	arena._on_phase_changed(MatchState.Phase.COUNTDOWN)
	assert_eq(p.ult_charge, 0.0, "new match")


func test_a_fighter_without_an_ultimate_has_a_locked_slot() -> void:
	var p: Player = _duo(&"warden")[0]  # benched, no ultimate
	assert_eq(p.skills[2].data, Player.NO_ULT)
	p.ult_charge = 1.0
	assert_false(p.ult_ready())
	_step(p, true)
	assert_eq(p.ult_charge, 1.0, "pressing does nothing")
	assert_false(p.skills[2].is_active())
	var copy: Player = _duo(&"warden")[1]
	assert_true(copy.apply_state(p.capture_state(), WeaponCatalog.load_all(), characters), "snapshot works")


func test_ultimates_are_not_pickable_by_anyone() -> void:
	for c: CharacterData in characters.all():
		if c.ultimate == null:
			continue
		assert_true(SkillCatalog.shared().is_ultimate(c.ultimate))
		for other: CharacterData in characters.all():
			assert_false(SkillCatalog.shared().specials_for(other).has(c.ultimate), "%s for %s" % [c.ultimate.id, other.id])
			assert_false(Player.specials_pool(other).has(c.ultimate))


func test_ultimate_assignments() -> void:
	assert_eq(characters.get_character(&"wukong").ultimate.id, &"great_ape")
	assert_eq(characters.get_character(&"flint").ultimate.id, &"inferno")
	assert_eq(characters.get_character(&"flicker").ultimate.id, &"shadow_clones")
	assert_eq(characters.get_character(&"sakura").ultimate.id, &"hanami_tempest")
	assert_eq(characters.get_character(&"bolt").ultimate.id, &"thunderstorm")
	assert_eq(characters.get_character(&"eden").ultimate.id, &"world_tree")
	assert_eq(characters.get_character(&"shadow").ultimate.id, &"eclipse")
	assert_null(characters.get_character(&"warden").ultimate)


func test_one_ability_rules_still_gate_the_ultimate() -> void:
	var p: Player = _duo(&"flicker")[0]
	p.set_skill(0, SkillCatalog.shared().dash())
	p.ult_charge = 1.0
	var f := InputFrame.new()
	f.seq = 1
	f.aim_vec = Vector2.RIGHT
	f.move_vec = Vector2.RIGHT
	f.skill = true
	p.simulate(f, DT)
	assert_true(p.skills[0].is_active(), "dash running")
	_step(p, true, 2)
	assert_false(p.skills[2].is_active(), "locked while the dash blocks")
	assert_eq(p.ult_charge, 1.0, "no charge spent")
	p.stats.apply_stun(1.0)
	p.skills[0].active_remaining = 0.0
	_step(p, true, 3)
	assert_false(p.skills[2].is_active(), "stunned")


func test_a_flag_carrier_can_still_ult() -> void:
	var p: Player = _duo(&"shadow")[0]  # Eclipse is a SMOKE kind, which carriers can't use as a normal pick
	p.flag_carrier = true
	p.ult_charge = 1.0
	assert_false(p.skill_locked(Constants.ULT_SLOT))
	_step(p, true)
	assert_lt(p.ult_charge, 0.01, "fired")
