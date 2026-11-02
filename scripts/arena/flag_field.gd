class_name FlagField
extends Node2D
## Capture the flag (Teams), view only: the base pads on the floor, each team's flag planted at its base, lying where
## it was dropped or hovering over its carrier's head, plus the capture burst and the return poof. All state lives in
## MatchState (server-owned); this only draws it. Ally blue / enemy red are the VIEWER's side (Player.viewer_team).

const FPS: float = 8.0
const FRAMES: int = 6
## The strips are delivered at x2 (generate.py `up2`), so they play 1:1: no sprite scaling, every art px is a screen px.
const ART_SCALE: float = 1.0
## The pole's foot in a flag / carried-flag frame, and the pad's centre in a pad frame (art px).
const FLAG_FOOT: Vector2 = Vector2(30.0, 86.0)
const HOVER_FOOT: Vector2 = Vector2(32.0, 42.0)
const PAD_CENTER: Vector2 = Vector2(64.0, 76.0)
## A carried flag hovers HOVER_GAP above the carrier's HP bar (so it never covers it), bobbing HOVER_BOB px every
## HOVER_PERIOD s over a soft team-coloured glow HOVER_GLOW_DROP below it; drawn above walls and fighters (HOVER_Z).
const HOVER_GAP: float = 20.0
const HOVER_BOB: float = 2.5
const HOVER_PERIOD: float = 1.2
const HOVER_GLOW_DROP: float = 8.0
const HOVER_GLOW_ALPHA: float = 0.45
const HOVER_Z: int = 1
const GLOW_ALLY: Color = Color(0.35, 0.6, 1.0)
const GLOW_ENEMY: Color = Color(1.0, 0.35, 0.3)
## A dropped flag blinks over its last seconds before it flies home.
const BLINK_SECONDS: float = 2.0
const BLINK_HZ: float = 6.0
const PAD_AWAY_ALPHA: float = 0.55
## The ring in the capture strip reaches 58 art px from a centre 16 px below the frame's middle; the poof frame is 96 px.
const CAPTURE_ART_RADIUS: float = 58.0
const CAPTURE_CENTER_DROP: float = 16.0
const RETURN_ART_RADIUS: float = 48.0
const TEAMS: Array[int] = [MatchRules.TEAM_A, MatchRules.TEAM_B]

var arena: Arena

var _tex: Dictionary[String, Texture2D] = {}
var _pads: Dictionary[int, Sprite2D] = {}
var _holders: Dictionary[int, Node2D] = {}
var _flags: Dictionary[int, Sprite2D] = {}
var _carried: Dictionary[int, Sprite2D] = {}
var _glows: Dictionary[int, Sprite2D] = {}
var _time: float = 0.0
var _prev_state: Array[int] = [0, 0, 0]
var _prev_carrier: Array[int] = [0, 0, 0]
var _prev_round: int = 0
var _prev_break: bool = false


func _ready() -> void:
	y_sort_enabled = true  # the flags sort with fighters and crates
	for name: String in ["flag_ally", "flag_enemy", "flag_pad_ally", "flag_pad_enemy", "flag_hover_ally", "flag_hover_enemy", "flag_hover_glow",
			"flag_capture_ally", "flag_capture_enemy", "flag_return"]:
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
		var carried := Sprite2D.new()
		_setup(carried, HOVER_FOOT, _tex["flag_hover_ally"])
		var glow := Sprite2D.new()  # under the banner, added first so the banner draws over it
		glow.texture = _tex["flag_hover_glow"]
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder.add_child(glow)
		_glows[t] = glow
		holder.add_child(carried)
		_carried[t] = carried


func _setup(s: Sprite2D, pivot: Vector2, tex: Texture2D) -> void:
	s.texture = tex
	s.hframes = FRAMES
	s.centered = false
	s.offset = -pivot
	s.scale = Vector2.ONE * ART_SCALE
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
		holder.z_index = 0
		if not on:
			continue
		pad.texture = _tex["flag_pad_" + suffix]
		pad.frame = frame
		pad.position = arena.flag_base(t)
		pad.modulate.a = 1.0 if st.flag_state[t] == MatchState.Flag.HOME else PAD_AWAY_ALPHA
		flag.texture = _tex["flag_" + suffix]
		flag.frame = (frame + t) % FRAMES
		flag.modulate.a = 1.0
		var carried: Sprite2D = _carried[t]
		flag.visible = true
		carried.visible = false
		_glows[t].visible = false
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
				if carrier == null or carrier.dead or not carrier.visible:  # a dying carrier's flag has dropped already
					continue
				flag.visible = false
				carried.visible = true
				carried.texture = _tex["flag_hover_" + suffix]
				carried.frame = (frame + t) % FRAMES
				var up: float = Constants.PLAYER_RADIUS + Player.BAR_OFFSET_Y + Player.BAR_HEIGHT * 2.0 + Player.BAR_GAP \
					+ HOVER_GAP
				var bob: float = roundf(sin(_time * TAU / HOVER_PERIOD) * HOVER_BOB)
				carried.position = Vector2(0.0, -up + bob)
				var glow: Sprite2D = _glows[t]
				glow.visible = true
				glow.position = Vector2(0.0, -up + HOVER_GLOW_DROP)
				glow.modulate = Color(GLOW_ALLY if ally else GLOW_ENEMY, HOVER_GLOW_ALPHA)
				holder.z_index = HOVER_Z
				holder.global_position = carrier.global_position + carrier.visual_offset
				holder.visible = true
				continue
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
			var viewer: int = Player.viewer_team if Player.viewer_team != 0 else MatchRules.TEAM_A
			var art: Texture2D = _tex["flag_capture_ally" if st.round_winner == viewer else "flag_capture_enemy"]
			fx.burst_strip(at - Vector2(0.0, CAPTURE_CENTER_DROP), CAPTURE_ART_RADIUS * ART_SCALE, art, CAPTURE_ART_RADIUS)
			arena.sfx.play(&"results", at)
		for t: int in TEAMS:
			if _prev_state[t] == MatchState.Flag.DROPPED and st.flag_state[t] == MatchState.Flag.HOME and same_round \
					and not on_break:
				var base: Vector2 = arena.flag_base(t)
				fx.burst_strip(base, RETURN_ART_RADIUS * ART_SCALE, _tex["flag_return"], RETURN_ART_RADIUS)
				arena.sfx.play(&"pickup_ready", base)
			elif _prev_state[t] != MatchState.Flag.CARRIED and st.flag_state[t] == MatchState.Flag.CARRIED and same_round:
				arena.sfx.play(&"pickup", arena.flag_base(t))
	for t: int in TEAMS:
		_prev_state[t] = st.flag_state[t]
		_prev_carrier[t] = st.flag_carrier[t]
	_prev_round = st.round_number
	_prev_break = on_break
