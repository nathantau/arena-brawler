class_name Hud
extends Control
## In-match HUD inside the safe area, drawn with the pixel UI kit (UiStyle):
## - top-left: HP / armor / energy bars with icons, then the carried weapons as slots
##   (sprite, energy cost; the active one framed in gold), and the skill when there's no touch button
## - top-centre: kills / deaths, and the match clock under it
## - top-right: status line (ping etc. when online)
## - centre: countdown, respawn / spectating messages.

const PANEL_PAD: Vector2 = Vector2(14, 12)
const ICON_SCALE: float = 2.0
const ROW_H: float = 30.0
const ROW_GAP: float = 6.0
const BAR_W: float = 200.0
const BAR_H: float = 22.0
const BAR_TEXT_PAD: float = 6.0
const SLOT_SIZE: Vector2 = Vector2(118, 72)
const SLOT_GAP: float = 8.0
const SLOT_ART_SCALE: float = 2.0
const SECTION_GAP: float = 10.0
const PILL_H: float = 46.0
const PILL_PAD: float = 18.0
const PILL_ITEM_GAP: float = 26.0
const MESSAGE_Y: float = 0.62
const COUNTDOWN_Y: float = 0.45
## Kill feed: newest at the bottom, top-right under the pause button.
const FEED_MAX: int = 4
const FEED_TIME: float = 4.0
const FEED_TOP: float = 104.0
const FEED_ROW_H: float = 26.0
## The status line stops short of the pause button (which sits in the same corner).
const STATUS_RIGHT_MARGIN: float = UiStyle.TOUCH_MIN_H + 12.0
const BANNER_TIME: float = 1.1
const BANNER_Y: float = 0.28
const BANNER_POP_TIME: float = 0.14
## Last seconds of a match: the clock turns red, pulses and ticks.
const FLAG_LINE_Y: float = 118.0
const FLAG_ARROW_INSET: float = 46.0
const FLAG_ARROW_SIZE: float = 15.0
const COLOR_FLAG_ENEMY: Color = Color(1.0, 0.35, 0.3)
const COLOR_ARROW_OUTLINE: Color = Color(0.1, 0.1, 0.18)
const COLOR_FLAG_ALLY: Color = Color(0.4, 0.7, 1.0)
const URGENT_SECONDS: int = 10
const COLOR_URGENT: Color = Color(1.0, 0.45, 0.4)
## Red edge glow at low HP (stepped bands, pixel style): fraction of max HP it starts at, band count and width.
const LOW_HP_FRACTION: float = 0.3
const VIGNETTE_BANDS: int = 4
const VIGNETTE_BAND_W: float = 18.0
const HURT_PULSE_TIME: float = 0.3
const EMPTY_FLASH_TIME: float = 0.3
const EMPTY_CLICK_GAP: float = 0.35
const GLINT_TIME: float = 0.6
## Vitals / score blocks fade to this alpha while a fighter stands under them (over FADE_TIME).
const FADED_ALPHA: float = 0.3
const FADE_TIME: float = 0.15
## A fighter's on-screen box in world units, centred FIGHTER_CENTER off the body origin (sprite is drawn above the feet).
const FIGHTER_BOX: Vector2 = Vector2(64, 96)
const FIGHTER_CENTER: Vector2 = Vector2(0, -8)

var player: Player
var arena: Arena
var scores: ScoreBoard
## Free-form line at the top right (e.g. ping when online).
var status_text: String = ""
## Desktop has no skill button: show the skill under the weapons instead.
var show_skill: bool = false
## The local input source (for "holding fire with no energy"); null on a view without one.
var input: LocalInput

class FeedRow:
	var killer: String
	var killer_color: Color
	var victim: String
	var victim_color: Color
	var mine: bool  # you were involved
	var life: float = FEED_TIME

class Banner:
	var text: String
	var color: Color
	var life: float = BANNER_TIME
	var row: int = 0

var _feed: Array[FeedRow] = []
var _banners: Array[Banner] = []
var _hurt: float = 0.0
var _empty_flash: float = 0.0
var _empty_click: float = 0.0
var _glint: float = 0.0
var _last_armor: int = -1
var _last_count: int = -1
var _last_second: int = -1
var _vitals_layer: Control
var _score_layer: Control

var _panel: StyleBoxTexture = UiStyle.slice("panel")
var _slot: StyleBoxTexture = UiStyle.slice("card")
var _slot_active: StyleBoxTexture = UiStyle.slice("card_gold")


func _ready() -> void:
	UiStyle.fit_to_safe_area(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_layer = _add_layer(_draw_vitals)
	_score_layer = _add_layer(_draw_score)


## A full-rect child that draws one HUD block, so its modulate can fade just that block.
func _add_layer(draw_fn: Callable) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(func() -> void:
		if player != null and is_instance_valid(player):
			draw_fn.call(layer))
	add_child(layer)
	return layer


## Alpha for a HUD block: faded while any fighter's screen rect (HUD-local) is under it.
static func fade_target(block: Rect2, fighters: Array[Rect2]) -> float:
	for f: Rect2 in fighters:
		if block.intersects(f):
			return FADED_ALPHA
	return 1.0


## Screen-space (HUD-local) boxes of the fighters you could be missing: alive and visible to the local view.
func _fighter_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var inv: Transform2D = get_global_transform().affine_inverse()
	for p: Player in arena.players:
		if p.dead or p.is_concealed():
			continue
		var xf: Transform2D = p.get_global_transform_with_canvas()
		var half: Vector2 = FIGHTER_BOX * 0.5 * xf.get_scale()
		var c: Vector2 = inv * (xf * (p.visual_offset + FIGHTER_CENTER))
		out.append(Rect2(c - half, half * 2.0))
	return out


func _fade_blocks(delta: float) -> void:
	if arena == null:
		return
	var fighters: Array[Rect2] = _fighter_rects()
	var k: float = 1.0 - exp(-delta / FADE_TIME * 3.0)
	for pair: Array in [[_vitals_layer, _vitals_rect()], [_score_layer, _score_rect()]]:
		var layer: Control = pair[0]
		layer.modulate.a = lerpf(layer.modulate.a, fade_target(pair[1], fighters), k)
		layer.queue_redraw()


func _vitals_rect() -> Rect2:
	var panel_h: float = PANEL_PAD.y * 2.0 + 3 * ROW_H + 2 * ROW_GAP
	var h: float = panel_h + SECTION_GAP + SLOT_SIZE.y + UiStyle.SIZE_SMALL + 4.0
	if show_skill:
		h += 3.0 * (UiStyle.SIZE_SMALL + 6.0)
	return Rect2(Vector2.ZERO, Vector2(PANEL_PAD.x * 2.0 + ROW_H + BAR_W, h))


## The kills / deaths pill plus the clock line under it.
func _score_rect() -> Rect2:
	var r: Rect2 = _score_pill()
	return Rect2(r.position, Vector2(r.size.x, PILL_H + UiStyle.SIZE_SMALL + 10.0))


func _process(delta: float) -> void:
	_hurt = maxf(0.0, _hurt - delta)
	_empty_flash = maxf(0.0, _empty_flash - delta)
	_empty_click = maxf(0.0, _empty_click - delta)
	_glint = maxf(0.0, _glint - delta)
	for row: FeedRow in _feed:
		row.life -= delta
	while not _feed.is_empty() and _feed[0].life <= 0.0:
		_feed.pop_front()
	for b: Banner in _banners:
		b.life -= delta
	while not _banners.is_empty() and _banners[0].life <= 0.0:
		_banners.pop_front()
	if player != null and is_instance_valid(player):
		_watch_player()
		_fade_blocks(delta)
	queue_redraw()


## Armor refilling glints its bar; holding fire without the energy for the shot flashes the energy bar + clicks.
func _watch_player() -> void:
	var s: PlayerStats = player.stats
	if _last_armor >= 0 and s.armor > _last_armor and s.armor < s.max_armor + 1:
		_glint = GLINT_TIME
	_last_armor = s.armor
	if input != null and input.fire_held and not player.dead and arena.match_state.phase == MatchState.Phase.PLAYING:
		var cost: int = player.held_weapon().data.energy_cost
		if cost > 0 and s.energy < cost:
			_empty_flash = EMPTY_FLASH_TIME
			if _empty_click <= 0.0 and arena.sfx != null:
				_empty_click = EMPTY_CLICK_GAP
				arena.sfx.play(&"empty")


func hurt_pulse() -> void:
	_hurt = HURT_PULSE_TIME


## Kill feed row; `killer` empty = no credit (environment).
func add_kill_feed(killer: String, killer_color: Color, victim: String, victim_color: Color, killer_is_me: bool,
		victim_is_me: bool) -> void:
	var r := FeedRow.new()
	r.killer = killer
	r.killer_color = killer_color
	r.victim = victim
	r.victim_color = victim_color
	r.mine = killer_is_me or victim_is_me
	_feed.append(r)
	while _feed.size() > FEED_MAX:
		_feed.pop_front()


## Big centre text that punches in and fades (KO, kill streaks, FIGHT!). `row` stacks a second line below.
func banner(text: String, color: Color, row: int = 0) -> void:
	var b := Banner.new()
	b.text = text
	b.color = color
	b.row = row
	_banners.append(b)


## Forget everything transient (new match / back to the lobby).
func clear_transients() -> void:
	_feed.clear()
	_banners.clear()
	_hurt = 0.0
	_empty_flash = 0.0
	_glint = 0.0
	_last_armor = -1
	_last_count = -1
	_last_second = -1


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	_draw_vignette()
	if status_text != "":
		UiStyle.draw_text(self, Vector2(0.0, UiStyle.SIZE_TINY), status_text, UiStyle.SIZE_TINY, UiStyle.C_DIM,
			HORIZONTAL_ALIGNMENT_RIGHT, size.x - STATUS_RIGHT_MARGIN)
	_draw_feed()
	_draw_messages()
	_draw_flags()
	_draw_banners()


## Red glow round the screen edge at low HP (pulsing, faster when critical) and a flash when you're hit.
func _draw_vignette() -> void:
	if player.dead:
		return
	var s: PlayerStats = player.stats
	var frac: float = float(s.hp) / float(maxi(1, s.max_hp))
	var strength: float = 0.0
	if frac <= LOW_HP_FRACTION and arena.match_state.phase != MatchState.Phase.RESULTS:
		var rate: float = 9.0 if frac <= 0.15 else 5.0
		strength = (1.0 - frac / LOW_HP_FRACTION) * 0.5 + 0.2
		strength *= 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * rate)
	strength = maxf(strength, _hurt / HURT_PULSE_TIME * 0.5)
	if strength <= 0.01:
		return
	var full := Rect2(-position, get_viewport_rect().size)  # the whole screen, not just the safe area
	for i: int in VIGNETTE_BANDS:
		var inset: float = i * VIGNETTE_BAND_W
		var c := Color(UiStyle.C_RED, strength * (1.0 - float(i) / VIGNETTE_BANDS) * 0.55)
		var r: Rect2 = full.grow(-inset)
		draw_rect(Rect2(r.position, Vector2(r.size.x, VIGNETTE_BAND_W)), c)
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - VIGNETTE_BAND_W), Vector2(r.size.x, VIGNETTE_BAND_W)), c)
		draw_rect(Rect2(r.position + Vector2(0, VIGNETTE_BAND_W), Vector2(VIGNETTE_BAND_W, r.size.y - VIGNETTE_BAND_W * 2.0)), c)
		draw_rect(Rect2(Vector2(r.end.x - VIGNETTE_BAND_W, r.position.y + VIGNETTE_BAND_W),
			Vector2(VIGNETTE_BAND_W, r.size.y - VIGNETTE_BAND_W * 2.0)), c)


func _draw_feed() -> void:
	var y: float = FEED_TOP
	for row: FeedRow in _feed:
		var a: float = clampf(row.life / 0.5, 0.0, 1.0)
		var f: int = UiStyle.SIZE_SMALL
		var victim_w: float = UiStyle.text_width(row.victim, f)
		var x_end: float = size.x
		if row.mine:
			draw_rect(Rect2(x_end - UiStyle.text_width(row.killer + " > " + row.victim, f) - 16.0, y - f, 
				UiStyle.text_width(row.killer + " > " + row.victim, f) + 16.0, f + 8.0), Color(UiStyle.C_OUTLINE, 0.6 * a))
		UiStyle.draw_text(self, Vector2(x_end - victim_w - 6.0, y), row.victim, f, Color(row.victim_color, a))
		var mid_w: float = UiStyle.text_width(" > ", f)
		UiStyle.draw_text(self, Vector2(x_end - victim_w - 6.0 - mid_w, y), " > ", f, Color(UiStyle.C_DIM, a * 0.8))
		if row.killer != "":
			var kw: float = UiStyle.text_width(row.killer, f)
			UiStyle.draw_text(self, Vector2(x_end - victim_w - 6.0 - mid_w - kw, y), row.killer, f, Color(row.killer_color, a))
		y += FEED_ROW_H


func _draw_banners() -> void:
	for b: Banner in _banners:
		var age: float = BANNER_TIME - b.life
		var k: float = clampf(age / BANNER_POP_TIME, 0.0, 1.0)
		var font: int = roundi(UiStyle.SIZE_TITLE * lerpf(1.5, 1.0, k))
		var a: float = clampf(b.life / 0.3, 0.0, 1.0)
		var y: float = size.y * BANNER_Y + b.row * (UiStyle.SIZE_TITLE + 8.0)
		UiStyle.draw_text(self, Vector2(0.0, y), b.text, font, Color(b.color, a), HORIZONTAL_ALIGNMENT_CENTER, size.x, true)


func _draw_vitals(c: CanvasItem) -> void:
	var s: PlayerStats = player.stats
	var rows: int = 3
	var panel := Rect2(Vector2.ZERO, PANEL_PAD * 2.0 + Vector2(ROW_H + BAR_W, rows * ROW_H + (rows - 1) * ROW_GAP))
	c.draw_style_box(_panel, panel)
	var pos: Vector2 = PANEL_PAD
	_bar(c, pos, "icon_hp", s.hp, s.max_hp, UiStyle.C_RED, UiStyle.C_MAROON)
	pos.y += ROW_H + ROW_GAP
	_bar(c, pos, "icon_armor", s.armor, s.max_armor, UiStyle.C_STEEL, UiStyle.C_STEEL_D, _glint / GLINT_TIME)
	pos.y += ROW_H + ROW_GAP
	var shake := Vector2.ZERO
	var flash: float = _empty_flash / EMPTY_FLASH_TIME
	if flash > 0.0:  # out of energy for this shot: the bar shudders and blinks red
		shake.x = 3.0 * sin(Time.get_ticks_msec() * 0.06)
	_bar(c, pos + shake, "icon_energy", s.energy, s.max_energy, UiStyle.C_TEAL_L, UiStyle.C_TEAL, 0.0,
		UiStyle.C_RED if flash > 0.0 and int(Time.get_ticks_msec() / 70) % 2 == 0 else Color.TRANSPARENT)

	# The one weapon (or the form's), with its energy cost per shot.
	var w: WeaponData = player.held_weapon().data
	var r := Rect2(Vector2(0.0, panel.end.y + SECTION_GAP), SLOT_SIZE)
	c.draw_style_box(_slot_active, r)
	UiStyle.draw_icon(c, w.sprite, r.get_center() - Vector2(0, 6), SLOT_ART_SCALE)
	var cost: String = "free" if w.energy_cost == 0 else str(w.energy_cost)
	var badge := Vector2(r.end.x - 10.0, r.end.y - 10.0)
	UiStyle.draw_text(c, badge, cost, UiStyle.SIZE_TINY, UiStyle.C_TEAL_L if w.energy_cost > 0 else UiStyle.C_DIM,
		HORIZONTAL_ALIGNMENT_RIGHT, -1.0)
	if w.energy_cost > 0:
		var tw: float = UiStyle.text_width(cost, UiStyle.SIZE_TINY)
		UiStyle.draw_icon(c, UiStyle.tex("icon_energy"), badge + Vector2(-tw - 10.0, -6.0), 1.0)
	var active_w: WeaponData = w
	var name_y: float = panel.end.y + SECTION_GAP + SLOT_SIZE.y + UiStyle.SIZE_SMALL + 4.0
	UiStyle.draw_text(c, Vector2(2.0, name_y), active_w.display_name, UiStyle.SIZE_SMALL, UiStyle.C_YELLOW)
	if show_skill:
		var y: float = name_y
		for pair: Array in [[player.skills[0], "Space", 0], [player.skills[1], "E", 1], [player.skills[2], "Q", 2]]:
			var sk: CharacterSkill = pair[0]
			var ult: bool = pair[2] == Constants.ULT_SLOT
			if ult and sk.data == Player.NO_ULT:
				continue
			var text: String = "%s [%s]" % [sk.data.display_name, pair[1]]
			var ready: bool = player.ult_ready() if ult else sk.is_ready()
			if player.skill_locked(pair[2] as int):
				text += " · locked"
			elif sk.is_active():
				text += " · active"
			elif ult and not ready:
				text += " · %d%%" % floori(player.ult_charge * 100.0)
			elif not ready:
				text += " · %.1fs" % sk.cooldown_remaining
			y += UiStyle.SIZE_SMALL + 6.0
			UiStyle.draw_text(c, Vector2(2.0, y), text, UiStyle.SIZE_SMALL,
				UiStyle.C_WHITE if ready and not player.skill_locked(pair[2] as int) else UiStyle.C_DIM)


## Icon, then a pixel bar (outline, dark well, two-tone fill, highlight) with "value / max" inside.
func _bar(c: CanvasItem, pos: Vector2, icon: String, value: int, max_value: int, fill: Color, shade: Color, glint: float = 0.0,
		warn: Color = Color.TRANSPARENT) -> void:
	UiStyle.draw_icon(c, UiStyle.tex(icon), pos + Vector2(ROW_H, ROW_H) * 0.5, ICON_SCALE)
	var r := Rect2(pos + Vector2(ROW_H + 4.0, (ROW_H - BAR_H) * 0.5), Vector2(BAR_W - 4.0, BAR_H))
	c.draw_rect(r, UiStyle.C_OUTLINE)
	var inner: Rect2 = r.grow(-2.0)
	c.draw_rect(inner, UiStyle.C_SHADOW)
	var frac: float = clampf(float(value) / float(maxi(1, max_value)), 0.0, 1.0)
	if frac > 0.0:
		var f := Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y))
		c.draw_rect(f, fill)
		c.draw_rect(Rect2(f.position + Vector2(0, f.size.y * 0.6), Vector2(f.size.x, f.size.y * 0.4)), shade)
		c.draw_rect(Rect2(f.position, Vector2(f.size.x, 2.0)), Color(1, 1, 1, 0.35))
		if glint > 0.0:  # a bright band sweeps along the filled part while it refills
			var gx: float = f.position.x + f.size.x * (1.0 - glint)
			c.draw_rect(Rect2(gx - 10.0, f.position.y, 20.0, f.size.y).intersection(f), Color(1, 1, 1, 0.55))
	if warn.a > 0.0:
		c.draw_rect(inner, Color(warn, 0.45))
	UiStyle.draw_text(c, Vector2(inner.end.x - BAR_TEXT_PAD, inner.end.y - 4.0), "%d/%d" % [value, max_value],
		UiStyle.SIZE_TINY, UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_RIGHT, -1.0)


## Top-centre pills: kills and deaths, then the clock (or warm-up) and the kill target.
func _score_pill() -> Rect2:
	var st: MatchState = arena.match_state
	if _teams_hud(st):
		var w: float = UiStyle.text_width(_round_score_text(), UiStyle.SIZE_HEADING, true) + PILL_PAD * 2.0
		return Rect2(Vector2((size.x - w) * 0.5, 0.0), Vector2(w, PILL_H))
	var id: int = player.player_id
	var item_w: float = ROW_H + 4.0
	var w: float = PILL_PAD * 2.0 + item_w * 2.0 + UiStyle.text_width(str(scores.kills_of(id)), UiStyle.SIZE_HEADING, true) \
		+ UiStyle.text_width(str(scores.deaths_of(id)), UiStyle.SIZE_HEADING, true) + PILL_ITEM_GAP
	return Rect2(Vector2((size.x - w) * 0.5, 0.0), Vector2(w, PILL_H))


func _teams_hud(st: MatchState) -> bool:
	return st.mode == MatchRules.Mode.TEAMS and st.phase != MatchState.Phase.LOBBY


## Teams: "2 – 1", your team first.
func _round_score_text() -> String:
	var st: MatchState = arena.match_state
	var mine: int = player.team if player.team != 0 else MatchRules.TEAM_A
	return "%d – %d" % [st.round_scores[mine], st.round_scores[MatchRules.other_team(mine)]]


## "2 – 1": your team's score in blue first, the enemy's in red.
func _draw_round_score(c: CanvasItem, r: Rect2) -> void:
	var st: MatchState = arena.match_state
	var mine: int = MatchRules.viewer_of(player.team)
	var parts: Array = [[str(st.round_scores[mine]), UiStyle.C_BLUE], [" – ", UiStyle.C_WHITE],
		[str(st.round_scores[MatchRules.other_team(mine)]), UiStyle.C_RED]]
	var total: float = UiStyle.text_width(_round_score_text(), UiStyle.SIZE_HEADING, true)
	var x: float = r.get_center().x - total * 0.5
	var y: float = r.get_center().y + UiStyle.SIZE_HEADING * 0.35
	for part: Array in parts:
		UiStyle.draw_text(c, Vector2(x, y), part[0], UiStyle.SIZE_HEADING, part[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
		x += UiStyle.text_width(part[0], UiStyle.SIZE_HEADING, true)


func _draw_score(c: CanvasItem) -> void:
	var st: MatchState = arena.match_state
	var r: Rect2 = _score_pill()
	c.draw_style_box(_panel, r)
	var clock: String = ""
	var urgent: bool = false
	if _teams_hud(st):
		_draw_round_score(c, r)
		if st.phase == MatchState.Phase.PLAYING:
			clock = "Round %d · %d:%02d" % [st.round_number, ceili(st.time_left) / 60, ceili(st.time_left) % 60]
			urgent = st.intermission <= 0.0 and _tick_clock(st)
		_draw_clock(c, r, st, clock, urgent)
		return
	var id: int = player.player_id
	var kills: String = str(scores.kills_of(id))
	var deaths: String = str(scores.deaths_of(id))
	var item_w: float = ROW_H + 4.0
	var x: float = r.position.x + PILL_PAD
	var mid: float = r.position.y + PILL_H * 0.5
	for pair: Array in [["icon_kills", kills, UiStyle.C_WHITE], ["icon_deaths", deaths, UiStyle.C_STEEL]]:
		UiStyle.draw_icon(c, UiStyle.tex(pair[0]), Vector2(x + ROW_H * 0.5, mid), ICON_SCALE)
		x += item_w
		UiStyle.draw_text(c, Vector2(x, mid + UiStyle.SIZE_HEADING * 0.35), pair[1], UiStyle.SIZE_HEADING, pair[2],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
		x += UiStyle.text_width(pair[1], UiStyle.SIZE_HEADING, true) + PILL_ITEM_GAP
	if st.phase == MatchState.Phase.PLAYING:
		clock = "%d:%02d · first to %d" % [ceili(st.time_left) / 60, ceili(st.time_left) % 60, MatchRules.kill_target(st.mode)]
		urgent = _tick_clock(st)
	elif st.phase == MatchState.Phase.LOBBY:
		clock = "Warm-up"
	_draw_clock(c, r, st, clock, urgent)


## Last-seconds tick sound once per second; true while the clock is urgent.
func _tick_clock(st: MatchState) -> bool:
	var t: int = ceili(st.time_left)
	var urgent: bool = t <= URGENT_SECONDS
	if urgent and t != _last_second and arena.sfx != null:
		arena.sfx.play(&"tick")
	_last_second = t
	return urgent


func _draw_clock(c: CanvasItem, r: Rect2, st: MatchState, clock: String, urgent: bool) -> void:
	if clock != "":
		var y: float = r.end.y + UiStyle.SIZE_SMALL + 6.0
		var cw: float = UiStyle.text_width(clock, UiStyle.SIZE_SMALL)
		UiStyle.draw_icon(c, UiStyle.tex("icon_clock"), Vector2((size.x - cw) * 0.5 - 20.0, y - 6.0), 1.0)
		var cf: int = UiStyle.SIZE_SMALL
		var cc: Color = UiStyle.C_WHITE
		if urgent:  # last seconds: bigger, red, throbbing once a second
			var beat: float = 1.0 - fposmod(st.time_left, 1.0)
			cf = roundi(UiStyle.SIZE_BODY * (1.0 + 0.25 * maxf(0.0, 1.0 - beat * 4.0)))
			cc = COLOR_URGENT
			y += (cf - UiStyle.SIZE_SMALL) * 0.5
		UiStyle.draw_text(c, Vector2(0.0, y), clock, cf, cc, HORIZONTAL_ALIGNMENT_CENTER, size.x)


## Capture the flag (Teams): a status line under the clock, and an arrow on the screen edge toward the enemy flag when it
## is off screen (toward your own base while you carry it).
func _draw_flags() -> void:
	var st: MatchState = arena.match_state
	if st.mode != MatchRules.Mode.TEAMS or st.phase != MatchState.Phase.PLAYING or player.team == 0:
		return
	var own: int = player.team
	var enemy: int = MatchRules.other_team(own)
	var line: String = ""
	var color: Color = UiStyle.C_WHITE
	var target := Vector2.INF
	var target_color: Color = COLOR_FLAG_ENEMY
	if player.flag_carrier:
		line = "You have the flag! Run to your base"
		color = UiStyle.C_YELLOW
		target = arena.flag_base(own)
		target_color = UiStyle.C_YELLOW
	else:
		if st.flag_state[own] == MatchState.Flag.CARRIED:
			line = "Your flag taken!"
			color = COLOR_FLAG_ENEMY
		elif st.flag_state[own] == MatchState.Flag.DROPPED:
			line = "Your flag dropped: touch it to return it"
			color = UiStyle.C_YELLOW
		elif st.flag_state[enemy] == MatchState.Flag.CARRIED:
			line = "Your team has the flag!"
			color = COLOR_FLAG_ALLY
		elif st.flag_state[enemy] == MatchState.Flag.DROPPED:
			line = "Enemy flag dropped!"
			color = UiStyle.C_YELLOW
		if st.flag_state[enemy] != MatchState.Flag.CARRIED or st.flag_carrier[enemy] != player.player_id:
			target = _flag_spot(st, enemy)
	if line != "" and st.intermission <= 0.0:
		UiStyle.draw_text(self, Vector2(0.0, FLAG_LINE_Y), line, UiStyle.SIZE_BODY, color, HORIZONTAL_ALIGNMENT_CENTER, size.x, true)
	if target != Vector2.INF and st.intermission <= 0.0:
		_draw_edge_arrow(target, target_color)


## Where a team's flag is now: carried (on its carrier), lying, or at its base.
func _flag_spot(st: MatchState, team: int) -> Vector2:
	match st.flag_state[team]:
		MatchState.Flag.CARRIED:
			var carrier: Player = arena.get_player(st.flag_carrier[team])
			return carrier.global_position if carrier != null else arena.flag_base(team)
		MatchState.Flag.DROPPED:
			return st.flag_pos[team]
	return arena.flag_base(team)


## A triangle on the screen edge pointing at the world point `at`, only while it is off screen.
func _draw_edge_arrow(at: Vector2, color: Color) -> void:
	var inv: Transform2D = get_global_transform().affine_inverse()
	var local: Vector2 = inv * (arena.get_global_transform_with_canvas() * at)
	var box := Rect2(Vector2.ZERO, size).grow(-FLAG_ARROW_INSET)
	if box.has_point(local):
		return
	var centre: Vector2 = size * 0.5
	var dir: Vector2 = (local - centre).normalized()
	# Where the ray from the centre leaves the box, so the arrow keeps pointing at the target.
	var t: float = INF
	if absf(dir.x) > 0.001:
		t = minf(t, ((box.end.x if dir.x > 0.0 else box.position.x) - centre.x) / dir.x)
	if absf(dir.y) > 0.001:
		t = minf(t, ((box.end.y if dir.y > 0.0 else box.position.y) - centre.y) / dir.y)
	var spot: Vector2 = centre + dir * t
	var side: Vector2 = dir.orthogonal()
	var tip: Vector2 = spot + dir * FLAG_ARROW_SIZE
	var back: Vector2 = spot - dir * FLAG_ARROW_SIZE * 0.5
	var pts := PackedVector2Array([tip, back + side * FLAG_ARROW_SIZE * 0.8, back - side * FLAG_ARROW_SIZE * 0.8])
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), COLOR_ARROW_OUTLINE, 5.0)
	draw_colored_polygon(pts, color)


func _draw_messages() -> void:
	var st: MatchState = arena.match_state
	if st.phase == MatchState.Phase.COUNTDOWN:
		UiStyle.draw_text(self, Vector2(0.0, size.y * COUNTDOWN_Y - UiStyle.SIZE_HUGE * 0.6), "GET READY",
			UiStyle.SIZE_HEADING, UiStyle.C_YELLOW, HORIZONTAL_ALIGNMENT_CENTER, size.x, true)
		var count: int = maxi(1, ceili(st.time_left))
		if count != _last_count:
			if _last_count > 0 and arena.sfx != null:  # the first beep plays with the phase change
				arena.sfx.play(&"countdown")
			_last_count = count
		# Each number slams in big and settles, then holds.
		var pop: float = clampf((fposmod(st.time_left, 1.0) - 0.75) / 0.25, 0.0, 1.0)
		UiStyle.draw_text(self, Vector2(0.0, size.y * COUNTDOWN_Y + UiStyle.SIZE_HUGE * 0.35),
			str(count), roundi(UiStyle.SIZE_HUGE * (1.0 + 0.4 * pop)), UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x, true)
	else:
		_last_count = -1
	if player.dead and st.phase != MatchState.Phase.RESULTS:
		var msg: String
		if st.may_respawn(player.player_id) or (st.mode == MatchRules.Mode.TEAMS and st.is_participant(player.player_id)):
			msg = "RESPAWN IN %d" % maxi(1, ceili(player.respawn_timer))
		else:
			msg = "Spectating · you'll play next match"
		var w: float = UiStyle.text_width(msg, UiStyle.SIZE_HEADING, true) + PILL_PAD * 2.0
		var r := Rect2(Vector2((size.x - w) * 0.5, size.y * MESSAGE_Y), Vector2(w, PILL_H + 8.0))
		draw_style_box(_panel, r)
		UiStyle.draw_text(self, Vector2(r.position.x, r.get_center().y + UiStyle.SIZE_HEADING * 0.35), msg,
			UiStyle.SIZE_HEADING, UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, true)
