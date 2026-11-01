extends SceneTree
## Preview: two Bolts side by side. One stands (normal look), the other walks up, then uses Overdrive (godspeed: flash, powered-up
## sheet, linger, power-down). Windowed and focus-safe like the smoke test (CLAUDE.md Commands):
##   ... --write-movie <dir>/f.png --fixed-fps 30 --quit-after 780 -s tools/bolt_preview.gd
## (override.cfg with window/size/viewport_width/height for 2532x1170; a movie frame = 2 physics frames).

const START: int = 420  ## the countdown is over by here
const WALK_AT: int = 40
const WALK_FRAMES: int = 24
const PRESS_AT: int = 120

var arena: Arena
var me: Player
var buddy: Player
var home: Vector2
var frames: int = 0


class Runner extends LocalInput:
	var move: Vector2 = Vector2.ZERO
	var press: bool = false

	func get_input(p: Player, d: float) -> InputFrame:
		var f: InputFrame = super.get_input(p, d)
		f.move_vec = move
		f.fire = false
		f.aim_vec = Vector2.RIGHT
		f.special = press
		return f


func _initialize() -> void:
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)


func _bolt(id: int, color: int, view: bool) -> Player:
	var input := Runner.new()
	input.arena = arena
	var p: Player = arena.add_player(id, color, input)
	if view:
		arena.attach_local_view(p, input)
	return p


func _tick() -> void:
	frames += 1
	if frames == 2:
		me = _bolt(1, 0, true)
		buddy = _bolt(2, 1, false)
		var st: MatchState = arena.match_state
		var phase: MatchState.Phase = st.phase
		st.phase = MatchState.Phase.LOBBY
		arena.select_character(me, &"bolt")
		arena.select_character(buddy, &"bolt")
		arena.select_special(me, 1, &"overdrive")
		st.phase = phase
		arena.referee.set_ready(1, true)
		arena.referee.set_ready(2, true)
	if frames == START:
		home = arena.map.energy_spots[0]
		for spot: Vector2 in arena.map.energy_spots:  # an open patch of floor near the middle of the top
			if absf(spot.x - arena.play_area().get_center().x) < absf(home.x - arena.play_area().get_center().x) \
					and spot.y < arena.play_area().get_center().y:
				home = spot
		home += Vector2(0, 70)
		me.global_position = home + Vector2(-130, 0)
		buddy.global_position = home + Vector2(110, 0)
	var n: int = frames - START
	if n < 0:
		return
	var runner: Runner = me.controller as Runner
	runner.move = Vector2.RIGHT if n >= WALK_AT and n < WALK_AT + WALK_FRAMES else Vector2.ZERO
	if n == PRESS_AT - 2:
		for s: CharacterSkill in me.skills:
			s.cooldown_remaining = 0.0
	runner.press = n == PRESS_AT
