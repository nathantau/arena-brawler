extends SceneTree
## Max damage ONE use of each ability deals to ONE standing target (every pellet / tick / summon bite landing), measured
## server-side in a bare world. The target stands still at 70 / 150 / 230 px
## along the aim, at body or hand height, and the best placement counts. Transforms: "form" = form weapon fired non-stop for the whole window (plain
## weapon fire, never capped). Run: godot --path . --headless --fixed-fps 60 -s tools/ability_damage.gd

const DT: float = 1.0 / 60.0
const RANGES: Array[float] = [70.0, 150.0, 230.0]
const BIG_HP: int = 100000


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var chars: CharacterCatalog = CharacterCatalog.load_all()
	var skills: SkillCatalog = SkillCatalog.shared()
	var rows: Array[String] = []
	for sk: SkillData in skills._by_id.values():
		if sk.kind == SkillData.Kind.DASH and sk.id == &"dash":
			continue
		var owner_id: StringName = sk.tags[0] if not sk.tags.is_empty() else &"shadow"
		var raw: int = 0
		var form: int = 0
		var ranges: Array[float] = RANGES.duplicate()
		if sk.kind == SkillData.Kind.STEP:  # the strike lands where he surfaces
			ranges.append(sk.step_speed_scale * 275.0 * sk.duration)
		for r: float in ranges:
			for dy: float in [0.0, Player.hand_offset(Vector2.RIGHT).y]:  # body height, and the hand's (beams)
				raw = maxi(raw, await _trial(chars, sk, owner_id, Vector2(r, dy), BIG_HP, false))
				if sk.kind == SkillData.Kind.TRANSFORM:
					form = maxi(form, await _trial(chars, sk, owner_id, Vector2(r, dy), BIG_HP, true))
		rows.append("%-16s %-10s max %4d%s" % [sk.id, owner_id, raw,
			(" | form weapon %d (%s)" % [form, sk.form_weapon.id if sk.form_weapon else "-"]) if sk.kind == SkillData.Kind.TRANSFORM else ""])
	for row: String in rows:
		print(row)
	print("ability damage done")
	quit()


func _trial(chars: CharacterCatalog, sk: SkillData, owner_id: StringName, off: Vector2, hp: int, fire_form: bool) -> int:
	var world := Node2D.new()
	root.add_child(world)
	var pool := ProjectilePool.new()
	world.add_child(pool)
	var weapons: Array[WeaponData] = WeaponCatalog.load_all().resolve([&"pistol"] as Array[StringName])
	var me := Player.new()
	me.setup(1, 0, Color.WHITE, weapons, null, pool, 3, chars.get_character(owner_id))
	world.add_child(me)
	me.set_skill(1, sk)
	me.global_position = Vector2(100, 300)
	var foe := Player.new()
	foe.setup(2, 1, Color.WHITE, weapons, null, pool, 3, chars.get_character(&"eden"))
	world.add_child(foe)
	foe.global_position = Vector2(100.0, 300.0) + off
	foe.stats.max_hp = hp
	foe.stats.hp = hp
	foe.stats.armor = 0
	foe.stats.max_armor = 0
	foe.stats.spawn_protect = 0.0
	pool.targets.append(me)
	pool.targets.append(foe)
	var frames: int = int((sk.duration + 2.0) * 60.0)
	for i: int in frames:
		var f := InputFrame.new()
		f.seq = 10 + i
		f.aim_vec = Vector2.RIGHT
		f.special = i == 1
		f.fire = fire_form and i > 1
		me.stats.energy = me.stats.max_energy
		me.simulate(f, DT)
		foe.stats.spawn_protect = 0.0
		await physics_frame
	var dealt: int = hp - foe.stats.hp
	world.queue_free()
	await physics_frame
	return dealt
