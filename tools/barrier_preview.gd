extends SceneTree
## Preview of the barrier bubble: a fighter presses Barrier, an enemy shoots it from behind and the side until it breaks
## (break=0: it times out instead, after two hits), recorded with e.g.
##   godot --path . --write-movie /tmp/b.png --fixed-fps 60 --quit-after 520 -s tools/barrier_preview.gd -- char=flicker break=1
## (small window in override.cfg, see CLAUDE.md Commands).

const START_FRAME: int = 420
const PRESS_AT: int = 70

var arena: Arena
var me: Player
var bot: Player
var frames: int = 0
var args: Dictionary = {}
var home: Vector2
var seq: int = 1


class Runner extends LocalInput:
	var press: bool = false

	func get_input(p: Player, d: float) -> InputFrame:
		var f: InputFrame = super.get_input(p, d)
		f.aim_vec = Vector2.RIGHT
		f.special = press
		return f


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)


func _shoot(from: Vector2) -> void:
	var dir: Vector2 = (me.global_position - from).normalized()
	arena.projectiles.fire_shot(bot.player_id, seq, from, dir, arena.catalog.get_weapon(&"pistol"), 7 + seq)
	seq += 1


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
		arena.select_character(me, StringName(args.get("char", "flicker")))
		arena.select_special(me, 1, &"barrier")
		st.phase = phase
		arena.referee.set_ready(1, true)
	if frames < START_FRAME - 5 or me == null:
		return
	if frames == START_FRAME - 4:
		home = arena.play_area().get_center() + Vector2(0, 40)
	bot.controller = null
	bot.global_position = home + Vector2(2000.0, 2000.0)
	var n: int = frames - START_FRAME
	var runner: Runner = me.controller as Runner
	if n == 2:
		me.global_position = home
		for s: CharacterSkill in me.skills:
			s.cooldown_remaining = 0.0
	runner.press = n == PRESS_AT
	var hits: Array[int] = [PRESS_AT + 50, PRESS_AT + 85, PRESS_AT + 120, PRESS_AT + 155]
	var spots: Array[Vector2] = [Vector2(-130, 10), Vector2(90, -110), Vector2(130, 60), Vector2(-110, -70)]
	var count: int = 4 if args.get("break", "1") == "1" else 2
	for i: int in count:
		if n == hits[i]:
			_shoot(me.global_position + spots[i])
