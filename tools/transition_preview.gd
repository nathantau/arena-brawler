extends SceneTree
## Preview of one special's transitions: a fighter presses a special once in a live offline arena (a passive bot far away)
## and the screen is recorded, e.g. (write a small window into override.cfg, see CLAUDE.md Commands, then):
##   godot --path . --write-movie /tmp/f.png --fixed-fps 60 --quit-after 330 -s tools/transition_preview.gd -- \
##     char=sakura special=petal_drift move=1,0 hold=0 press=1 aim=1,0
## Args: char, special (slot 1), move (stick while it runs), aim, press (extra presses at these seconds after the first
## after the run starts, comma separated, e.g. press=0,1.5 to start / end), fire (hold the weapon the whole time).

const START_FRAME: int = 420  # the match countdown is over
const PRESS_AT: int = 30  # frames after START_FRAME

var arena: Arena
var me: Player
var bot: Player
var frames: int = 0
var args: Dictionary = {}
var home: Vector2


class Runner extends LocalInput:
	var move: Vector2 = Vector2.ZERO
	var aim: Vector2 = Vector2.RIGHT
	var press: bool = false
	var fire: bool = false

	func get_input(p: Player, d: float) -> InputFrame:
		var f: InputFrame = super.get_input(p, d)
		f.move_vec = move
		f.fire = fire
		f.aim_vec = aim
		f.special = press
		return f


func _vec(key: String, fallback: Vector2) -> Vector2:
	if not args.has(key):
		return fallback
	var parts: PackedStringArray = String(args[key]).split(",")
	return Vector2(float(parts[0]), float(parts[1])).normalized() if parts.size() == 2 else fallback


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 2:
		var input := Runner.new()
		input.arena = arena
		me = arena.add_player(1, 0, input)
		arena.attach_local_view(me, input)
		bot = arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
		var st: MatchState = arena.match_state
		var phase: MatchState.Phase = st.phase
		st.phase = MatchState.Phase.LOBBY
		arena.select_character(me, StringName(args.get("char", "sakura")))
		arena.select_special(me, 1, StringName(args.get("special", "petal_drift")))
		st.phase = phase
		arena.referee.set_ready(1, true)
	if frames < START_FRAME - 5 or me == null:
		return
	if frames == START_FRAME - 4:
		home = me.global_position
	if bot != null and is_instance_valid(bot):  # passive and far away
		bot.controller = null
		bot.global_position = home + Vector2(2000.0, 2000.0)
	var runner: Runner = me.controller as Runner
	var n: int = frames - START_FRAME
	runner.aim = _vec("aim", Vector2.RIGHT)
	runner.move = _vec("move", Vector2.ZERO) if n >= PRESS_AT else Vector2.ZERO
	runner.fire = args.get("fire", "0") == "1"
	if n == PRESS_AT - 5:
		me.global_position = home
		for s: CharacterSkill in me.skills:
			s.cooldown_remaining = 0.0
	var presses: PackedStringArray = String(args.get("press", "0")).split(",")
	var hit: bool = false
	for pr: String in presses:
		if n - PRESS_AT == int(float(pr) * 60.0):
			hit = true
	runner.press = hit
