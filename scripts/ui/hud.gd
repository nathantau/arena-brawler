class_name Hud
extends Control
## Top-left stat bars, weapon info, kill count, respawn message. Drawn with primitives.

const MARGIN: Vector2 = Vector2(20, 20)
const BAR_SIZE: Vector2 = Vector2(220, 16)
const BAR_GAP: float = 6.0
const FONT_SIZE: int = 14
const BIG_FONT_SIZE: int = 28
const TEXT_PAD: float = 4.0
const COLOR_BG: Color = Color(0, 0, 0, 0.55)
const COLOR_HP: Color = Color(0.9, 0.25, 0.25)
const COLOR_ARMOR: Color = Color(0.7, 0.75, 0.85)
const COLOR_ENERGY: Color = Color(0.3, 0.6, 1.0)
const COLOR_TEXT: Color = Color(1, 1, 1, 0.95)
const COLOR_DIM: Color = Color(1, 1, 1, 0.5)

var player: Player
var scores: ScoreBoard


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var font: Font = ThemeDB.fallback_font
	var s: PlayerStats = player.stats
	var pos: Vector2 = MARGIN
	_bar(font, pos, float(s.hp) / s.max_hp, COLOR_HP, "%d / %d" % [s.hp, s.max_hp])
	pos.y += BAR_SIZE.y + BAR_GAP
	_bar(font, pos, float(s.armor) / s.max_armor, COLOR_ARMOR, "%d / %d" % [s.armor, s.max_armor])
	pos.y += BAR_SIZE.y + BAR_GAP
	_bar(font, pos, float(s.energy) / s.max_energy, COLOR_ENERGY, "%d / %d" % [s.energy, s.max_energy])
	pos.y += BAR_SIZE.y + BAR_GAP + FONT_SIZE

	for i: int in player.loadout.slots.size():
		var w: WeaponData = player.loadout.slots[i].data
		var active: bool = i == player.loadout.active_index
		var label: String = "%s %s  (%d energy)" % ["▶" if active else " ", w.display_name, w.energy_cost]
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT if active else COLOR_DIM)
		pos.y += FONT_SIZE + TEXT_PAD

	var dash_text: String = "Dash ready" if player.dash.is_ready() else "Dash %.1fs" % player.dash.cooldown_remaining
	draw_string(font, pos, dash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT if player.dash.is_ready() else COLOR_DIM)

	var kd: String = "Kills %d   Deaths %d" % [scores.kills_of(player.player_id), scores.deaths_of(player.player_id)]
	draw_string(font, Vector2(0.0, MARGIN.y + BIG_FONT_SIZE), kd, HORIZONTAL_ALIGNMENT_CENTER, size.x, BIG_FONT_SIZE, COLOR_TEXT)

	if player.dead:
		var msg: String = "Respawning in %.1f" % maxf(0.0, player.respawn_timer)
		draw_string(font, Vector2(0.0, size.y * 0.5), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, BIG_FONT_SIZE, COLOR_TEXT)


func _bar(font: Font, pos: Vector2, frac: float, color: Color, text: String) -> void:
	draw_rect(Rect2(pos, BAR_SIZE), COLOR_BG)
	draw_rect(Rect2(pos, Vector2(BAR_SIZE.x * clampf(frac, 0.0, 1.0), BAR_SIZE.y)), color)
	var baseline: Vector2 = pos + Vector2(TEXT_PAD, BAR_SIZE.y - TEXT_PAD * 0.5)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2, COLOR_TEXT)
