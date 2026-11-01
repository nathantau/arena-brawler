extends SceneTree
## Preview: Bolt uses Lightning Beam on a stationary Bolt 280 px away, then Thunder Strike on the same spot. Windowed and focus-safe
## like the smoke test (CLAUDE.md Commands):
##   ... --write-movie <dir>/f.png --fixed-fps 30 --quit-after 400 -s tools/bolt_beam_preview.gd
## (override.cfg with window/size/viewport_width/height for 2532x1170; a movie frame = 2 physics frames).

const START: int = 420  ## the countdown is over by here
const BEAM_AT: int = 40
const THUNDER_AT: int = 200
const GAP: float = 280.0

var arena: Arena
var me: Player
var buddy: Player
var home: Vector2
var frames: int = 0


class Runner extends LocalInput:
	var press: bool = false

	func get_input(p: Player, d: float) -> InputFrame:
		var f: InputFrame = super.get_input(p, d)
		f.move_vec = Vector2.ZERO
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
		arena.select_special(me, 1, &"lightning_beam")
		st.phase = phase
		arena.referee.set_ready(1, true)
		arena.referee.set_ready(2, true)
	if frames == START:
		home = arena.map.energy_spots[0]
		for spot: Vector2 in arena.map.energy_spots:  # an open patch of floor near the middle of the top
			if absf(spot.x - arena.play_area().get_center().x) < absf(home.x - arena.play_area().get_center().x) \
					and spot.y < arena.play_area().get_center().y:
				home = spot
		home += Vector2(-100, 90)
		me.global_position = home
		buddy.global_position = home + Vector2(GAP, 22.0)  # level with his hand, where the beam runs
	var n: int = frames - START
	if n < 0:
		return
	if n == THUNDER_AT - 4:
		me.set_skill(1, SkillCatalog.shared().get_skill(&"thunder_strike"))
		for s: CharacterSkill in me.skills:
			s.cooldown_remaining = 0.0
	(me.controller as Runner).press = n == BEAM_AT or n == THUNDER_AT
