extends SceneTree
## Smoke test: every in-rotation fighter x every special they can pick (slot 2) and every weapon they can use,
## pressed in a live offline arena with the local view (HUD, touch controls, effects) against a bot.
## Needs a window so drawing runs; launch it without stealing focus (see CLAUDE.md Commands) and grep the log:
##   ... --log-file <log> -s tools/smoke_specials.gd   then   grep -c "SCRIPT ERROR" <log>   (must be 0)
## Prints "smoke done <n> combos" at the end.

const FRAMES_PER_COMBO: int = 90
const WARMUP_FRAMES: int = 250

var arena: Arena
var frames: int = 0
var me: Player
var combos: Array = []
var idx: int = -1


class Presser extends LocalInput:
	var n: int = 0

	func get_input(p: Player, d: float) -> InputFrame:
		var f: InputFrame = super.get_input(p, d)
		n += 1
		f.special = n % FRAMES_PER_COMBO == 10
		f.skill = n % FRAMES_PER_COMBO == 40
		return f


func _initialize() -> void:
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	for c: CharacterData in CharacterCatalog.load_all().ordered:
		if not c.in_rotation:
			continue
		for sk: SkillData in SkillCatalog.shared().specials_for(c):
			combos.append([c.id, sk.id, &""])
		for w: WeaponData in arena.weapons_for(c):
			combos.append([c.id, &"", w.id])
	physics_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 2:
		var input := Presser.new()
		input.autopilot = true
		input.arena = arena
		me = arena.add_player(1, 0, input)
		arena.attach_local_view(me, input)
		arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
		arena.referee.set_ready(1, true)
	if frames > WARMUP_FRAMES and frames % FRAMES_PER_COMBO == 0:
		idx += 1
		if idx >= combos.size():
			print("smoke done %d combos" % combos.size())
			quit()
			return
		var st: MatchState = arena.match_state
		var phase: MatchState.Phase = st.phase
		st.phase = MatchState.Phase.LOBBY  # picks are lobby-only
		arena.select_character(me, combos[idx][0])
		if combos[idx][1] != &"":
			arena.select_special(me, 1, combos[idx][1])
		if combos[idx][2] != &"":
			arena.select_weapon(me, combos[idx][2])
		st.phase = phase
