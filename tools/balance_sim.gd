extends SceneTree
## Headless bot-vs-bot balance sim. Duels (first to 5 kills or time limit) between two bots, each with a chosen
## fighter / special / weapon, in a real offline Arena. Bots are not humans: they target anything, strafe, fire
## constantly and press the special whenever it is ready and an enemy is in sight. Trust it for outliers only.
##   godot --path . --headless --fixed-fps 60 -s tools/balance_sim.gd -- mode=fighters n=6 [slice=0/4] [seed=1]
## mode: fighters (default loadouts round robin) | specials (each fighter x each special vs the default pool)
##       | weapons (each fighter x each weapon vs the default pool).
## Prints one summary row per config: win% (draws = half), avg damage dealt/taken per match, avg match seconds.

const MAX_FRAMES: int = 60 * 100
const KILL_TARGET: int = 5

var jobs: Array = []  # [[char, skill, weapon], [char, skill, weapon], label]
var results: Dictionary = {}  # label -> [wins, games, dealt, taken, seconds]
var job_idx: int = -1
var arena: Arena
var frames: int = 0
var dmg: Dictionary = {}
var kills: Dictionary = {}
var n_per: int = 4
var base_seed: int = 1
var kit_rotates: bool = true  # off in specials mode: each row tests one special (fighters with several signature specials otherwise rotate)
var prev_hp: Array[int] = [0, 0]


class SimBot extends BotBrain:
	var seen: Variant = null

	func _init(p_arena: Arena, bot_seed: int) -> void:
		super(p_arena, bot_seed)

	func get_input(player: Player, delta: float) -> InputFrame:
		var f: InputFrame = super.get_input(player, delta)
		if f.fire and player.skills[1].is_ready() and seen != null \
				and special_useful(player, player.global_position.distance_to(seen as Vector2)):
			f.special = rng.randf() < 1.5 * delta
		if seen != null:
			var w: WeaponData = player.held_weapon().data
			var reach: float = 300.0
			if w.kind == WeaponData.Kind.MELEE:
				reach = maxf(w.melee_range, w.splash_radius) * 0.8
			elif w.kind == WeaponData.Kind.BEAM:
				reach = 0.8 * w.projectile_range
			var to: Vector2 = (seen as Vector2) - player.global_position
			var dir: Vector2 = to.normalized()
			var radial: Vector2 = dir if to.length() > reach else -dir
			var mv: Vector2 = radial * Constants.BOT_RADIAL_WEIGHT + dir.orthogonal() * _strafe_sign * Constants.BOT_STRAFE_WEIGHT
			f.move_vec = mv.normalized() * Constants.BOT_MOVE_SCALE
		return f

	func _nearest_visible_enemy(player: Player) -> Variant:
		var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
		var best: Variant = null
		var best_sq: float = Constants.BOT_SIGHT_RANGE * Constants.BOT_SIGHT_RANGE
		for p: Player in arena.players:
			if p == player or p.dead:
				continue
			var spots: PackedVector2Array = p.clone_points()
			if not p.is_hidden():
				spots.append(p.global_position)
			for at: Vector2 in spots:
				var d: float = player.global_position.distance_squared_to(at)
				if d <= 0.0 or d >= best_sq:
					continue
				var spot: Variant = AutoAim.visible_point(space, _query, player.global_position, at)
				if spot != null:
					best = spot
					best_sq = d
		seen = best
		return best


func _initialize() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	n_per = int(args.get("n", "4"))
	base_seed = int(args.get("seed", "1"))
	kit_rotates = String(args.get("mode", "fighters")) != "specials"
	_build_jobs(String(args.get("mode", "fighters")), String(args.get("only", "")))
	if args.has("slice"):
		var ab: PackedStringArray = String(args["slice"]).split("/")
		var k: int = int(ab[0])
		var m: int = int(ab[1])
		var mine: Array = []
		for i: int in jobs.size():
			if i % m == k:
				mine.append(jobs[i])
		jobs = mine
	physics_frame.connect(_tick)


func _default(c: CharacterData) -> Array:
	var sk: SkillData = Player.default_skills(c)[1]
	return [c.id, sk.id, c.signature_weapon.id if c.signature_weapon != null else &"pistol"]


func _build_jobs(mode: String, only: String) -> void:
	var cat: CharacterCatalog = CharacterCatalog.load_all()
	var skills: SkillCatalog = SkillCatalog.shared()
	var tmp := Arena.new()
	var defaults: Array = []
	for c: CharacterData in cat.ordered:
		defaults.append(_default(c))
	var subjects: Array = []
	match mode:
		"fighters":
			subjects = defaults
		"specials":
			for c: CharacterData in cat.ordered:
				if c.in_rotation and (only == "" or String(c.id) == only):
					for sk: SkillData in skills.specials_for(c):
						subjects.append([c.id, sk.id, _default(c)[2]])
		"weapons":
			for c: CharacterData in cat.ordered:
				if c.in_rotation and (only == "" or String(c.id) == only):
					for w: WeaponData in tmp.weapons_for(c):
						subjects.append([c.id, _default(c)[1], w.id])
	tmp.free()
	for s: Array in subjects:
		for d: Array in defaults:
			if d[0] == s[0] and mode != "specials" and mode != "weapons":
				continue
			for i: int in n_per:
				jobs.append([s, d, "%s|%s|%s" % [s[0], s[1], s[2]]])


func _tick() -> void:
	frames += 1
	if arena != null and job_idx >= 0:
		for k: int in 2:
			var me: Player = arena.get_player(10 + k)
			var foe: Player = arena.get_player(11 - k)
			var hp: int = me.stats.hp + me.stats.armor
			if not me.dead and prev_hp[k] > hp and prev_hp[k] < 9999 and not foe.dead:
				dmg[11 - k] += prev_hp[k] - hp
			prev_hp[k] = hp
	if job_idx >= 0 and arena != null:
		var st: MatchState = arena.match_state
		if st.phase == MatchState.Phase.RESULTS or frames >= MAX_FRAMES:
			_finish()
	if arena == null and frames > 3:
		_next()


func _next() -> void:
	job_idx += 1
	if job_idx >= jobs.size():
		_report()
		quit()
		return
	var job: Array = jobs[job_idx]
	arena = Arena.new(Arena.Mode.OFFLINE, base_seed * 1000 + job_idx, MatchRules.Mode.DUEL, 999.0)
	root.add_child(arena)
	frames = 0
	dmg = {10: 0, 11: 0}
	kills = {10: 0, 11: 0}
	var flip: bool = job_idx % 2 == 1  # who gets which spawn
	for k: int in 2:
		var cfg: Array = job[k]
		var id: int = 10 + k
		var bot := SimBot.new(arena, base_seed * 7919 + job_idx * 13 + id)
		bot.rotates_kit = kit_rotates
		var p: Player = arena.add_player(id, k, bot, true)
		p.set_character(arena.characters.get_character(cfg[0]))
		p.set_skill(1, SkillCatalog.shared().get_skill(cfg[1]))
		p.set_weapon(arena.catalog.get_weapon(cfg[2]))
	arena.kill_registered.connect(func(killer: int, _v: int) -> void:
		if kills.has(killer):
			kills[killer] += 1)
	prev_hp = [9999, 9999]
	var st: MatchState = arena.match_state
	var order: Array[int] = [10, 11]
	if flip:
		order = [11, 10]
	st.participants = order
	st.phase = MatchState.Phase.PLAYING
	st.time_left = 999.0
	arena._place_participants()
	for p: Player in arena.players:
		p.frozen = false
		p.stats.invulnerable_time = 0.0


func _finish() -> void:
	var job: Array = jobs[job_idx]
	var label: String = job[2]
	var r: Array = results.get(label, [0.0, 0, 0.0, 0.0, 0.0])
	var win: float = 0.5
	if kills[10] > kills[11]:
		win = 1.0
	elif kills[10] < kills[11]:
		win = 0.0
	r[0] += win
	r[1] += 1
	r[2] += dmg[10]
	r[3] += dmg[11]
	r[4] += frames / 60.0
	results[label] = r
	arena.queue_free()
	arena = null
	frames = 0


func _report() -> void:
	var labels: Array = results.keys()
	labels.sort()
	print("config\twin%\tdealt\ttaken\tsecs\tgames")
	for l: String in labels:
		var r: Array = results[l]
		var g: float = float(r[1])
		print("%s\t%d\t%d\t%d\t%.0f\t%d" % [l, roundi(100.0 * r[0] / g), roundi(r[2] / g), roundi(r[3] / g), r[4] / g, r[1]])
