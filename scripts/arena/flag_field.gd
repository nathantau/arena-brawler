class_name FlagField
extends Node2D
## Capture the flag (Teams), view only: the base pads on the floor, each team's flag planted at its base, lying where
## it was dropped or riding on its carrier's back, plus the capture burst and the return poof. All state lives in
## MatchState (server-owned); this only draws it. Ally blue / enemy red are the VIEWER's side (Player.viewer_team).

const FPS: float = 8.0
const FRAMES: int = 6
## The pole's foot in a flag frame, and the pad's centre in a pad frame (art px).
const FLAG_FOOT: Vector2 = Vector2(15.0, 43.0)
const PAD_CENTER: Vector2 = Vector2(32.0, 38.0)
## A carried flag stands behind the carrier's back, a little above his feet.
const CARRY_BACK: float = 24.0
const CARRY_LIFT: float = 20.0
## A dropped flag blinks over its last seconds before it flies home.
const BLINK_SECONDS: float = 2.0
const BLINK_HZ: float = 6.0
const PAD_AWAY_ALPHA: float = 0.55
const CAPTURE_ART_RADIUS: float = 44.0
const RETURN_ART_RADIUS: float = 32.0
const TEAMS: Array[int] = [MatchRules.TEAM_A, MatchRules.TEAM_B]

var arena: Arena

var _tex: Dictionary[String, Texture2D] = {}
var _pads: Dictionary[int, Sprite2D] = {}
var _holders: Dictionary[int, Node2D] = {}
var _flags: Dictionary[int, Sprite2D] = {}
var _time: float = 0.0
var _prev_state: Array[int] = [0, 0, 0]
var _prev_carrier: Array[int] = [0, 0, 0]
var _prev_round: int = 0
var _prev_break: bool = false


func _ready() -> void:
	y_sort_enabled = true  # the flags sort with fighters and crates
	for name: String in ["flag_ally", "flag_enemy", "flag_pad_ally", "flag_pad_enemy", "flag_capture", "flag_return"]:
		_tex[name] = load("res://assets/fx/%s.png" % name)
	for t: int in TEAMS:
		var pad := Sprite2D.new()
		pad.z_index = Effects.GROUND_Z
		_setup(pad, PAD_CENTER, _tex["flag_pad_ally"])
		add_child(pad)
		_pads[t] = pad
		var holder := Node2D.new()
		add_child(holder)
		_holders[t] = holder
		var flag := Sprite2D.new()
		_setup(flag, FLAG_FOOT, _tex["flag_ally"])
		flag.position = Vector2(0.0, Player.FOOT_RING_Y)  # the holder sits a foot-ring above the foot line, like a fighter
		holder.add_child(flag)
		_flags[t] = flag


func _setup(s: Sprite2D, pivot: Vector2, tex: Texture2D) -> void:
	s.texture = tex
	s.hframes = FRAMES
	s.centered = false
	s.offset = -pivot
	s.scale = Vector2.ONE * Constants.SPRITE_SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_time += delta
	var st: MatchState = arena.match_state
	var on: bool = st.mode == MatchRules.Mode.TEAMS and st.phase != MatchState.Phase.LOBBY
	var viewer: int = Player.viewer_team if Player.viewer_team != 0 else MatchRules.TEAM_A
	var frame: int = int(_time * FPS) % FRAMES
	for t: int in TEAMS:
		var ally: bool = t == viewer
		var suffix: String = "ally" if ally else "enemy"
		var pad: Sprite2D = _pads[t]
		var flag: Sprite2D = _flags[t]
		var holder: Node2D = _holders[t]
		pad.visible = on
		holder.visible = false
		if not on:
			continue
		pad.texture = _tex["flag_pad_" + suffix]
		pad.frame = frame
		pad.position = arena.flag_base(t)
		pad.modulate.a = 1.0 if st.flag_state[t] == MatchState.Flag.HOME else PAD_AWAY_ALPHA
		flag.texture = _tex["flag_" + suffix]
		flag.frame = (frame + t) % FRAMES
		flag.modulate.a = 1.0
		flag.scale.x = Constants.SPRITE_SCALE  # a planted flag's cloth streams right; a carried one streams away from him
		var foot: Vector2
		match st.flag_state[t]:
			MatchState.Flag.HOME:
				foot = arena.flag_base(t)
			MatchState.Flag.DROPPED:
				foot = st.flag_pos[t]
				if st.flag_timer[t] < BLINK_SECONDS and int(_time * BLINK_HZ * 2.0) % 2 == 0:
					flag.modulate.a = 0.35
			_:
				var carrier: Player = arena.get_player(st.flag_carrier[t])
				if carrier == null or carrier.dead:
					continue
				var side: float = -1.0 if carrier.facing.x >= 0.0 else 1.0
				flag.scale.x = side * Constants.SPRITE_SCALE
				foot = carrier.global_position + carrier.visual_offset \
					+ Vector2(side * CARRY_BACK, Player.FOOT_RING_Y - CARRY_LIFT)
				foot.y -= 2.0  # sorts just behind him
		holder.global_position = foot - Vector2(0.0, Player.FOOT_RING_Y)
		holder.visible = true
	_play_events(st)


## Burst when a round is won by a capture, poof when a dropped flag flies home, pickup / return sounds.
func _play_events(st: MatchState) -> void:
	var fx: Effects = arena.effects
	var same_round: bool = st.round_number == _prev_round
	var on_break: bool = st.intermission > 0.0
	if fx != null and st.mode == MatchRules.Mode.TEAMS:
		if on_break and not _prev_break and st.round_reason == MatchRules.Reason.CAPTURE and st.round_winner != 0:
			var at: Vector2 = arena.flag_base(st.round_winner)
			fx.burst_strip(at, CAPTURE_ART_RADIUS * Constants.SPRITE_SCALE, _tex["flag_capture"], CAPTURE_ART_RADIUS)
			arena.sfx.play(&"results", at)
		for t: int in TEAMS:
			if _prev_state[t] == MatchState.Flag.DROPPED and st.flag_state[t] == MatchState.Flag.HOME and same_round \
					and not on_break:
				var base: Vector2 = arena.flag_base(t)
				fx.burst_strip(base, RETURN_ART_RADIUS * Constants.SPRITE_SCALE, _tex["flag_return"], RETURN_ART_RADIUS)
				arena.sfx.play(&"pickup_ready", base)
			elif _prev_state[t] != MatchState.Flag.CARRIED and st.flag_state[t] == MatchState.Flag.CARRIED and same_round:
				arena.sfx.play(&"pickup", arena.flag_base(t))
	for t: int in TEAMS:
		_prev_state[t] = st.flag_state[t]
		_prev_carrier[t] = st.flag_carrier[t]
	_prev_round = st.round_number
	_prev_break = on_break
