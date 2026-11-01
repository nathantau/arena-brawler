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

var player: Player
var arena: Arena
var scores: ScoreBoard
## Free-form line at the top right (e.g. ping when online).
var status_text: String = ""
## Desktop has no skill button: show the skill under the weapons instead.
var show_skill: bool = false

var _panel: StyleBoxTexture = UiStyle.slice("panel")
var _slot: StyleBoxTexture = UiStyle.slice("card")
var _slot_active: StyleBoxTexture = UiStyle.slice("card_gold")


func _ready() -> void:
	UiStyle.fit_to_safe_area(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	_draw_vitals()
	_draw_score()
	if status_text != "":
		UiStyle.draw_text(self, Vector2(0.0, UiStyle.SIZE_TINY), status_text, UiStyle.SIZE_TINY, UiStyle.C_DIM,
			HORIZONTAL_ALIGNMENT_RIGHT, size.x)
	_draw_messages()


func _draw_vitals() -> void:
	var s: PlayerStats = player.stats
	var rows: int = 3
	var panel := Rect2(Vector2.ZERO, PANEL_PAD * 2.0 + Vector2(ROW_H + BAR_W, rows * ROW_H + (rows - 1) * ROW_GAP))
	draw_style_box(_panel, panel)
	var pos: Vector2 = PANEL_PAD
	_bar(pos, "icon_hp", s.hp, s.max_hp, UiStyle.C_RED, UiStyle.C_MAROON)
	pos.y += ROW_H + ROW_GAP
	_bar(pos, "icon_armor", s.armor, s.max_armor, UiStyle.C_STEEL, UiStyle.C_STEEL_D)
	pos.y += ROW_H + ROW_GAP
	_bar(pos, "icon_energy", s.energy, s.max_energy, UiStyle.C_TEAL_L, UiStyle.C_TEAL)

	# The one weapon (or the form's), with its energy cost per shot.
	var w: WeaponData = player.held_weapon().data
	var r := Rect2(Vector2(0.0, panel.end.y + SECTION_GAP), SLOT_SIZE)
	draw_style_box(_slot_active, r)
	UiStyle.draw_icon(self, w.sprite, r.get_center() - Vector2(0, 6), SLOT_ART_SCALE)
	var cost: String = "free" if w.energy_cost == 0 else str(w.energy_cost)
	var badge := Vector2(r.end.x - 10.0, r.end.y - 10.0)
	UiStyle.draw_text(self, badge, cost, UiStyle.SIZE_TINY, UiStyle.C_TEAL_L if w.energy_cost > 0 else UiStyle.C_DIM,
		HORIZONTAL_ALIGNMENT_RIGHT, -1.0)
	if w.energy_cost > 0:
		var tw: float = UiStyle.text_width(cost, UiStyle.SIZE_TINY)
		UiStyle.draw_icon(self, UiStyle.tex("icon_energy"), badge + Vector2(-tw - 10.0, -6.0), 1.0)
	var active_w: WeaponData = w
	var name_y: float = panel.end.y + SECTION_GAP + SLOT_SIZE.y + UiStyle.SIZE_SMALL + 4.0
	UiStyle.draw_text(self, Vector2(2.0, name_y), active_w.display_name, UiStyle.SIZE_SMALL, UiStyle.C_YELLOW)
	if show_skill:
		var y: float = name_y
		for pair: Array in [[player.skills[0], "Space", 0], [player.skills[1], "E", 1]]:
			var sk: CharacterSkill = pair[0]
			var text: String = "%s [%s]" % [sk.data.display_name, pair[1]]
			if player.skill_locked(pair[2] as int):
				text += " · locked"
			elif sk.is_active():
				text += " · active"
			elif not sk.is_ready():
				text += " · %.1fs" % sk.cooldown_remaining
			y += UiStyle.SIZE_SMALL + 6.0
			UiStyle.draw_text(self, Vector2(2.0, y), text, UiStyle.SIZE_SMALL,
				UiStyle.C_WHITE if sk.is_ready() and not player.skill_locked(pair[2] as int) else UiStyle.C_DIM)


## Icon, then a pixel bar (outline, dark well, two-tone fill, highlight) with "value / max" inside.
func _bar(pos: Vector2, icon: String, value: int, max_value: int, fill: Color, shade: Color) -> void:
	UiStyle.draw_icon(self, UiStyle.tex(icon), pos + Vector2(ROW_H, ROW_H) * 0.5, ICON_SCALE)
	var r := Rect2(pos + Vector2(ROW_H + 4.0, (ROW_H - BAR_H) * 0.5), Vector2(BAR_W - 4.0, BAR_H))
	draw_rect(r, UiStyle.C_OUTLINE)
	var inner: Rect2 = r.grow(-2.0)
	draw_rect(inner, UiStyle.C_SHADOW)
	var frac: float = clampf(float(value) / float(maxi(1, max_value)), 0.0, 1.0)
	if frac > 0.0:
		var f := Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y))
		draw_rect(f, fill)
		draw_rect(Rect2(f.position + Vector2(0, f.size.y * 0.6), Vector2(f.size.x, f.size.y * 0.4)), shade)
		draw_rect(Rect2(f.position, Vector2(f.size.x, 2.0)), Color(1, 1, 1, 0.35))
	UiStyle.draw_text(self, Vector2(inner.end.x - BAR_TEXT_PAD, inner.end.y - 4.0), "%d/%d" % [value, max_value],
		UiStyle.SIZE_TINY, UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_RIGHT, -1.0)


## Top-centre pills: kills and deaths, then the clock (or warm-up) and the kill target.
func _draw_score() -> void:
	var id: int = player.player_id
	var kills: String = str(scores.kills_of(id))
	var deaths: String = str(scores.deaths_of(id))
	var item_w: float = ROW_H + 4.0
	var w: float = PILL_PAD * 2.0 + item_w * 2.0 + UiStyle.text_width(kills, UiStyle.SIZE_HEADING, true) \
		+ UiStyle.text_width(deaths, UiStyle.SIZE_HEADING, true) + PILL_ITEM_GAP
	var r := Rect2(Vector2((size.x - w) * 0.5, 0.0), Vector2(w, PILL_H))
	draw_style_box(_panel, r)
	var x: float = r.position.x + PILL_PAD
	var mid: float = r.position.y + PILL_H * 0.5
	for pair: Array in [["icon_kills", kills, UiStyle.C_WHITE], ["icon_deaths", deaths, UiStyle.C_STEEL]]:
		UiStyle.draw_icon(self, UiStyle.tex(pair[0]), Vector2(x + ROW_H * 0.5, mid), ICON_SCALE)
		x += item_w
		UiStyle.draw_text(self, Vector2(x, mid + UiStyle.SIZE_HEADING * 0.35), pair[1], UiStyle.SIZE_HEADING, pair[2],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
		x += UiStyle.text_width(pair[1], UiStyle.SIZE_HEADING, true) + PILL_ITEM_GAP

	var st: MatchState = arena.match_state
	var clock: String
	if st.phase == MatchState.Phase.PLAYING:
		var t: int = ceili(st.time_left)
		clock = "%d:%02d · first to %d" % [t / 60, t % 60, MatchRules.kill_target(st.mode)]
	elif st.phase == MatchState.Phase.LOBBY:
		clock = "Warm-up"
	if clock != "":
		var y: float = r.end.y + UiStyle.SIZE_SMALL + 6.0
		var cw: float = UiStyle.text_width(clock, UiStyle.SIZE_SMALL)
		UiStyle.draw_icon(self, UiStyle.tex("icon_clock"), Vector2((size.x - cw) * 0.5 - 20.0, y - 6.0), 1.0)
		UiStyle.draw_text(self, Vector2(0.0, y), clock, UiStyle.SIZE_SMALL, UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_messages() -> void:
	var st: MatchState = arena.match_state
	if st.phase == MatchState.Phase.COUNTDOWN:
		UiStyle.draw_text(self, Vector2(0.0, size.y * COUNTDOWN_Y - UiStyle.SIZE_HUGE * 0.6), "GET READY",
			UiStyle.SIZE_HEADING, UiStyle.C_YELLOW, HORIZONTAL_ALIGNMENT_CENTER, size.x, true)
		UiStyle.draw_text(self, Vector2(0.0, size.y * COUNTDOWN_Y + UiStyle.SIZE_HUGE * 0.35),
			str(maxi(1, ceili(st.time_left))), UiStyle.SIZE_HUGE, UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x, true)
	if player.dead and st.phase != MatchState.Phase.RESULTS:
		var msg: String
		if st.may_respawn(player.player_id):
			msg = "Respawning in %.1f" % maxf(0.0, player.respawn_timer)
		else:
			msg = "Spectating · you'll play next match"
		var w: float = UiStyle.text_width(msg, UiStyle.SIZE_HEADING, true) + PILL_PAD * 2.0
		var r := Rect2(Vector2((size.x - w) * 0.5, size.y * MESSAGE_Y), Vector2(w, PILL_H + 8.0))
		draw_style_box(_panel, r)
		UiStyle.draw_text(self, Vector2(r.position.x, r.get_center().y + UiStyle.SIZE_HEADING * 0.35), msg,
			UiStyle.SIZE_HEADING, UiStyle.C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, true)
