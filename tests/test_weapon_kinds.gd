extends GutTest
## Weapon behaviours in a real physics world: splash, bounce, beam, melee + reflect,
## shields, dual-wield volleys and crates.

const SHOOTER: int = 1
const TARGET: int = 2
const SEED: int = 5

var world: Node2D
var pool: ProjectilePool
var catalog: WeaponCatalog
var characters: CharacterCatalog


func before_each() -> void:
	world = Node2D.new()
	add_child_autofree(world)
	pool = ProjectilePool.new()
	world.add_child(pool)
	catalog = WeaponCatalog.load_all()
	characters = CharacterCatalog.load_all()


func _player(id: int, at: Vector2, character: StringName = &"flicker") -> Player:
	var p := Player.new()
	p.setup(id, 0, Color.WHITE, catalog.resolve([&"pistol"] as Array[StringName]), null, pool, SEED,
		characters.get_character(character))
	world.add_child(p)
	p.global_position = at
	return p


func _wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	world.add_child(body)


func _crate(center: Vector2) -> Crate:
	var c := Crate.new()
	c.setup(0, center, Constants.TILE_SIZE)
	world.add_child(c)
	return c


func _w(id: StringName) -> WeaponData:
	return catalog.get_weapon(id)


func _active() -> Array[ProjectilePool.Slot]:
	var out: Array[ProjectilePool.Slot] = []
	for s: ProjectilePool.Slot in pool.debug_slots():
		if s.active:
			out.append(s)
	return out


# --- data -------------------------------------------------------------------

func test_catalog_has_the_mvp_eight() -> void:
	for id: StringName in [&"pistol", &"smg", &"shotgun", &"sniper", &"rocket", &"laser", &"sword", &"grenade"]:
		var w: WeaponData = _w(id)
		assert_not_null(w, String(id))
		if w != null:
			assert_ne(w.display_name, "", String(id))
			assert_true(w.fire_interval > 0.0, String(id))
	assert_eq(_w(&"laser").kind, WeaponData.Kind.BEAM)
	assert_eq(_w(&"sword").kind, WeaponData.Kind.MELEE)
	assert_true(_w(&"sword").reflects)
	assert_true(_w(&"rocket").splash_radius > 0.0)
	assert_true(_w(&"grenade").bounces > 0 and _w(&"grenade").splash_radius > 0.0)
	assert_eq(_w(&"pistol").energy_cost, 0, "the sidearm is free")
	var pickups: Array[StringName] = catalog.pickup_ids()
	assert_false(pickups.has(&"pistol"), "sidearm isn't a pickup")
	assert_false(pickups.has(&"bot_blaster"))
	assert_eq(pickups.size(), 7, "signature weapons are not pickups")
	for w: WeaponData in catalog._by_id.values():
		if w.kind == WeaponData.Kind.PROJECTILE:
			assert_not_null(w.projectile_sprite, "%s has bullet art" % w.id)
		if w.kind != WeaponData.Kind.MELEE and w.sprite != null and w.held_art:
			# Shots leave the barrel tip, past the hand.
			assert_gt(w.muzzle_x, Player.WEAPON_GRIP.x, "%s has its barrel tip set" % w.id)
			assert_lt(w.muzzle_x, float(w.sprite.get_width()), w.id)


func test_splash_damage_falloff() -> void:
	assert_eq(CombatRules.splash_damage(40, 0.0, 100.0, 0.5), 40)
	assert_eq(CombatRules.splash_damage(40, 50.0, 100.0, 0.5), 30)
	assert_eq(CombatRules.splash_damage(40, 100.0, 100.0, 0.5), 20)
	assert_eq(CombatRules.splash_damage(40, 101.0, 100.0, 0.5), 0, "outside the blast")


func test_in_arc() -> void:
	assert_true(CombatRules.in_arc(Vector2.ZERO, Vector2.RIGHT, Vector2(10, 5), 90.0))
	assert_false(CombatRules.in_arc(Vector2.ZERO, Vector2.RIGHT, Vector2(-10, 0), 90.0))
	assert_false(CombatRules.in_arc(Vector2.ZERO, Vector2.RIGHT, Vector2(1, 10), 90.0))


# --- splash -----------------------------------------------------------------

func test_rocket_splashes_target_but_not_shooter() -> void:
	var shooter: Player = _player(SHOOTER, Vector2(100, 300))
	var target: Player = _player(TARGET, Vector2(300, 300))
	await wait_physics_frames(2)
	var hits: Array = []
	pool.player_hit.connect(func(_o: int, _s: int, _p: int, victim: int, dmg: int, _c: bool, _a: Vector2) -> void:
		hits.append([victim, dmg]))
	pool.fire_shot(SHOOTER, 1, shooter.global_position, Vector2.RIGHT, _w(&"rocket"), SEED)
	await wait_physics_frames(30)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0][0], TARGET)
	assert_true(target.stats.armor + target.stats.hp < target.stats.max_armor + target.stats.max_hp)
	assert_eq(shooter.stats.hp, shooter.stats.max_hp)


func test_splash_blocked_by_walls() -> void:
	_player(SHOOTER, Vector2(100, 300))
	var hidden: Player = _player(TARGET, Vector2(300, 380))
	_wall(Vector2(300, 345), Vector2(200, 20))
	_wall(Vector2(320, 300), Vector2(20, 60))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"rocket"), SEED)
	await wait_physics_frames(30)
	assert_eq(hidden.stats.armor, hidden.stats.max_armor, "rocket hit the wall; target was behind another wall")


func test_grenade_bounces_off_walls() -> void:
	_wall(Vector2(260, 300), Vector2(20, 400))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"grenade"), SEED)
	await wait_physics_frames(25)
	var live: Array[ProjectilePool.Slot] = _active()
	assert_eq(live.size(), 1, "still flying after hitting the wall")
	assert_true(live[0].vel.x < 0.0, "bounced back")
	assert_eq(live[0].bounces_left, _w(&"grenade").bounces - 1)


# --- beam / melee -----------------------------------------------------------

func test_beam_hits_first_player_instantly() -> void:
	var near: Player = _player(TARGET, Vector2(250, 300))
	var far: Player = _player(3, Vector2(400, 300))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"laser"), SEED)
	assert_lt(near.stats.armor, near.stats.max_armor)
	assert_eq(far.stats.armor, far.stats.max_armor)
	assert_eq(pool.active_count(), 0, "no projectile")


func test_beam_blocked_by_wall() -> void:
	var target: Player = _player(TARGET, Vector2(300, 300))
	_wall(Vector2(200, 300), Vector2(20, 200))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"laser"), SEED)
	assert_eq(target.stats.armor, target.stats.max_armor)


func test_sword_hits_in_front_only() -> void:
	var front: Player = _player(TARGET, Vector2(160, 300))
	var behind: Player = _player(3, Vector2(40, 300))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"sword"), SEED)
	assert_lt(front.stats.armor, front.stats.max_armor)
	assert_eq(behind.stats.armor, behind.stats.max_armor)


func test_sword_reflects_enemy_projectiles() -> void:
	await wait_physics_frames(1)
	pool.fire_shot(TARGET, 1, Vector2(400, 300), Vector2.LEFT, _w(&"pistol"), SEED)
	var bullet: ProjectilePool.Slot = _active()[0]
	bullet.pos = Vector2(150, 300)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"sword"), SEED)
	assert_eq(bullet.attacker_id, SHOOTER, "reflected bullet now belongs to the swinger")
	assert_eq(bullet.owner_id, TARGET, "but keeps its key so server hit events still match")
	assert_true(bullet.vel.x > 0.0)


func test_sword_ignores_own_projectiles() -> void:
	await wait_physics_frames(1)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"pistol"), SEED)
	var bullet: ProjectilePool.Slot = _active()[0]
	var vel: Vector2 = bullet.vel
	pool.fire_shot(SHOOTER, 2, Vector2(100, 300), Vector2.LEFT, _w(&"sword"), SEED)
	assert_eq(bullet.vel, vel)


# --- shields / dual / crates ------------------------------------------------

func test_shield_blocks_enemy_shots_not_own() -> void:
	var warden: Player = _player(SHOOTER, Vector2(100, 300), &"warden")
	var target: Player = _player(TARGET, Vector2(400, 300))
	warden.special.try_activate(Vector2.RIGHT, warden.global_position, warden.stats)
	warden._shield.sync(warden.special, false)
	await wait_physics_frames(2)
	# Enemy fires at the warden: stopped by the barrier.
	pool.fire_shot(TARGET, 1, target.global_position, Vector2.LEFT, _w(&"pistol"), SEED)
	await wait_physics_frames(25)
	assert_eq(warden.stats.armor, warden.stats.max_armor)
	# Warden fires through their own barrier.
	pool.fire_shot(SHOOTER, 1, warden.global_position, Vector2.RIGHT, _w(&"pistol"), SEED)
	await wait_physics_frames(25)
	assert_lt(target.stats.armor, target.stats.max_armor)


func test_dual_wield_fires_two_keyed_volleys() -> void:
	await wait_physics_frames(1)
	var shotgun: WeaponData = _w(&"shotgun")
	pool.fire_shot(SHOOTER, 7, Vector2(100, 300), Vector2.RIGHT, shotgun, SEED, true, 9.0)
	var live: Array[ProjectilePool.Slot] = _active()
	assert_eq(live.size(), shotgun.pellets * 2)
	var keys: Dictionary = {}
	for s: ProjectilePool.Slot in live:
		keys[s.pellet] = true
	assert_eq(keys.size(), shotgun.pellets * 2, "every pellet has a distinct key")


func test_projectiles_damage_and_destroy_crates() -> void:
	var crate: Crate = _crate(Vector2(300, 300))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"pistol"), SEED)
	await wait_physics_frames(20)
	assert_eq(crate.hp, Constants.CRATE_HP - _w(&"pistol").damage)
	assert_true(crate.take_damage(Constants.CRATE_HP))
	assert_false(crate.is_intact())
	await wait_physics_frames(2)
	var target: Player = _player(TARGET, Vector2(400, 300))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 2, Vector2(100, 300), Vector2.RIGHT, _w(&"pistol"), SEED)
	await wait_physics_frames(25)
	assert_lt(target.stats.armor, target.stats.max_armor, "shots pass where the crate was")


func test_client_pool_never_damages() -> void:
	pool.authoritative = false
	var target: Player = _player(TARGET, Vector2(200, 300))
	var crate: Crate = _crate(Vector2(100, 420))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"rocket"), SEED)
	pool.fire_shot(SHOOTER, 2, Vector2(100, 300), Vector2.DOWN, _w(&"sword"), SEED)
	pool.fire_shot(SHOOTER, 3, Vector2(100, 300), Vector2.RIGHT, _w(&"laser"), SEED)
	await wait_physics_frames(20)
	assert_eq(target.stats.armor, target.stats.max_armor)
	assert_eq(crate.hp, Constants.CRATE_HP)


# --- character weapons (many-to-many) -----------------------------------------

func test_every_weapon_has_a_sprite() -> void:
	for id: StringName in [&"pistol", &"bot_blaster", &"smg", &"shotgun", &"sniper", &"rocket", &"grenade",
			&"laser", &"sword", &"flicker_kunai", &"warden_hammer", &"twinshot_revolver", &"wukong_staff"]:
		assert_not_null(_w(id).sprite, String(id))


func test_signature_weapons_belong_to_their_character_only() -> void:
	for c: CharacterData in characters.ordered:
		var sig: WeaponData = c.signature_weapon
		assert_not_null(sig, String(c.id))
		assert_false(sig.pickup, "signatures never drop")
		assert_eq(sig.energy_cost, 0, "signatures are free sidearms")
		for other: CharacterData in characters.ordered:
			assert_eq(other.can_use(sig), other == c, "%s using %s" % [other.id, sig.id])


func test_pickup_weapons_are_many_to_many() -> void:
	var users_per_weapon: Dictionary[StringName, int] = {}
	for c: CharacterData in characters.all():  # the roster's data, benched characters too
		var usable: int = 0
		for id: StringName in catalog.pickup_ids():
			if c.can_use(_w(id)):
				usable += 1
				users_per_weapon[id] = users_per_weapon.get(id, 0) + 1
		assert_between(usable, 2, catalog.pickup_ids().size() - 1, "%s: some weapons, not all" % c.id)
	for id: StringName in catalog.pickup_ids():
		assert_true(users_per_weapon.get(id, 0) >= 2, "%s is shared by 2+ characters" % id)


func test_untagged_weapons_are_universal() -> void:
	for c: CharacterData in characters.ordered:
		assert_true(c.can_use(_w(&"pistol")), String(c.id))


# --- signature weapon behaviours ----------------------------------------------

func test_kunai_pierce_one_player() -> void:
	var first: Player = _player(TARGET, Vector2(220, 300))
	var second: Player = _player(3, Vector2(320, 300))
	var third: Player = _player(4, Vector2(420, 300))
	await wait_physics_frames(2)
	var kunai: WeaponData = _w(&"flicker_kunai").duplicate()
	kunai.pellets = 1
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, kunai, SEED)
	await wait_physics_frames(30)
	assert_lt(first.stats.armor, first.stats.max_armor)
	assert_lt(second.stats.armor, second.stats.max_armor, "passed through the first")
	assert_eq(third.stats.armor, third.stats.max_armor, "stopped after one pierce")


func test_hammer_slams_at_the_tip_hitting_everyone_near_it() -> void:
	var front: Player = _player(TARGET, Vector2(170, 300))
	var beside: Player = _player(3, Vector2(170, 350))
	var behind: Player = _player(4, Vector2(40, 300))
	var swinger: Player = _player(SHOOTER, Vector2(100, 300))
	await wait_physics_frames(2)
	var blasts: Array = []
	pool.exploded.connect(func(at: Vector2, _r: float, _c: Color, _slam: bool) -> void: blasts.append(at))
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"warden_hammer"), SEED)
	assert_eq(blasts.size(), 1)
	assert_almost_eq(blasts[0].x, 100.0 + _w(&"warden_hammer").melee_range, 0.1)
	assert_lt(front.stats.armor, front.stats.max_armor)
	assert_lt(beside.stats.armor, beside.stats.max_armor, "splash, not just the arc")
	assert_eq(behind.stats.armor, behind.stats.max_armor)
	assert_eq(swinger.stats.armor, swinger.stats.max_armor, "no self-damage")


func test_hammer_slam_does_not_land_behind_a_wall() -> void:
	var hidden: Player = _player(TARGET, Vector2(175, 300))
	_wall(Vector2(140, 300), Vector2(10, 200))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"warden_hammer"), SEED)
	assert_eq(hidden.stats.armor, hidden.stats.max_armor)


func test_ricochet_hits_after_bouncing_off_a_wall() -> void:
	_wall(Vector2(300, 300), Vector2(20, 400))
	var target: Player = _player(TARGET, Vector2(150, 300))
	await wait_physics_frames(2)
	# Fired away from the target, comes back off the wall.
	pool.fire_shot(SHOOTER, 1, Vector2(200, 300), Vector2.RIGHT, _w(&"twinshot_revolver"), SEED)
	await wait_physics_frames(30)
	assert_lt(target.stats.armor, target.stats.max_armor)
	assert_eq(pool.active_count(), 0, "a ricochet stops on the player it hits (no splash)")


func test_staff_thrust_is_long_and_narrow() -> void:
	var far: Player = _player(TARGET, Vector2(220, 300))
	var side: Player = _player(3, Vector2(130, 340))
	await wait_physics_frames(2)
	pool.fire_shot(SHOOTER, 1, Vector2(100, 300), Vector2.RIGHT, _w(&"wukong_staff"), SEED)
	assert_lt(far.stats.armor, far.stats.max_armor, "beyond sword reach")
	assert_eq(side.stats.armor, side.stats.max_armor, "outside the narrow cone")


func test_petal_storm_homes_in_on_enemies() -> void:
	var target: Player = _player(TARGET, Vector2(500, 300))
	var me: Player = _player(SHOOTER, Vector2(200, 300))
	pool.targets = [target, me] as Array[Player]
	await wait_physics_frames(2)
	var storm: WeaponData = _w(&"petal_storm")
	pool.fire_shot(SHOOTER, 1, me.global_position, Vector2.RIGHT, storm, SEED)
	await wait_physics_frames(150)
	var taken: int = target.stats.max_armor - target.stats.armor + target.stats.max_hp - target.stats.hp
	# Flying straight, only the 1-2 petals aimed at it would land; homing brings most of the ring around.
	assert_gt(taken, storm.damage * storm.pellets / 2, "most petals curve onto the target")
	assert_eq(me.stats.hp, me.stats.max_hp, "never the shooter")


func test_aim_at_sends_shots_through_the_target() -> void:
	var p: Player = _player(SHOOTER, Vector2.ZERO)
	var w: WeaponData = p.held_weapon().data
	for target: Vector2 in [Vector2(200, 0), Vector2(-200, 40), Vector2(150, -150), Vector2(-120, 160), Vector2(60, 220)]:
		p.facing = p.aim_at(target)
		var from_hand: Vector2 = target - p.shot_origin(w)
		var miss: float = absf(from_hand.cross(p.facing))  # distance from the target to the shot's line
		assert_lt(miss, 1.0, "aiming at %s" % target)
		assert_gt(from_hand.dot(p.facing), 0.0, "and towards it")
