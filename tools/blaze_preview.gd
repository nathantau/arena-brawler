extends SceneTree
## Preview: Flint runs Blaze Run in set directions (right, down-right, down, up-right, up, left), one every RUN_FRAMES,
## back at his spawn each time. Windowed and focus-safe like the smoke test (CLAUDE.md Commands):
##   ... --write-movie <dir>/f.png --fixed-fps 30 --quit-after 780 -s tools/blaze_preview.gd

const RUN_FRAMES: int = 240
const DIRS: Array[Vector2] = [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(1, -1), Vector2(0, -1), Vector2(-1, 0)]

var arena: Arena
var me: Player
var home: Vector2
var frames: int = 0


class Runner extends LocalInput:
	var dir: Vector2 = Vector2.ZERO
	var press: bool = false

	func get_input(p: Player, d: float) -> InputFrame:
		var f: InputFrame = super.get_input(p, d)
		f.move_vec = Vector2.ZERO
		f.fire = false
		f.aim_vec = dir
		f.special = press
		return f


func _initialize() -> void:
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
		arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
		var st: MatchState = arena.match_state
		var phase: MatchState.Phase = st.phase
		st.phase = MatchState.Phase.LOBBY
		arena.select_character(me, &"flint")
		arena.select_special(me, 1, &"blaze_run")
		st.phase = phase
		arena.referee.set_ready(1, true)
	if frames == 420:
		home = me.global_position
	if frames > 420:
		var n: int = (frames - 420) % RUN_FRAMES
		var runner: Runner = me.controller as Runner
		if n == 1:
			me.global_position = home
			runner.dir = DIRS[((frames - 420) / RUN_FRAMES) % DIRS.size()].normalized()
			for s: CharacterSkill in me.skills:
				s.cooldown_remaining = 0.0
		runner.press = n == 5
