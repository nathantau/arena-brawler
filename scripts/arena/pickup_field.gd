class_name PickupField
extends Node2D
## Energy pickups on the layout's "E" spots. The authority (offline / server) decides who collects; clients mirror
## the state (to_array / apply_array) and count the respawn down on their own for the on-pad timer.
## Drawn on the ground layer: a pad, a bobbing crystal with a glow while ready, a filling ring + seconds while empty.

## Someone collected spot `index` (every peer; clients when the synced state shows it).
signal collected(index: int, at: Vector2, collector_id: int)
## Spot `index` is back.
signal respawned(index: int, at: Vector2)
## Authority: state changed, so the server re-broadcasts it.
signal changed

const PAD_ART: Texture2D = preload("res://assets/arenas/pad.png")
const CRYSTAL_ART: Texture2D = preload("res://assets/arenas/energy.png")
const BOB_PX: float = 4.0
const BOB_HZ: float = 0.8
const GLOW_COLOR: Color = Color(0.4, 1.0, 0.9)
const RING_COLOR: Color = Color(0.45, 0.95, 1.0)
const RING_BACK: Color = Color(0.0, 0.0, 0.0, 0.45)
const RING_RADIUS: float = 30.0
const RING_WIDTH: float = 5.0
const EMPTY_TINT: Color = Color(0.55, 0.6, 0.7)
const TIMER_FONT_SIZE: int = 18
const PAD_LIFT: float = 6.0
const READY_FLASH_TIME: float = 0.5

var spots: PackedVector2Array = PackedVector2Array()
## Seconds until each spot is back (0 = ready).
var timers: PackedFloat32Array = PackedFloat32Array()
## Who collected each spot last (cosmetic: whose "+energy" it was).
var collectors: PackedInt32Array = PackedInt32Array()
var _flash: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = Effects.GROUND_Z
	z_as_relative = false


func setup(map: ArenaMap) -> void:
	spots = map.energy_spots.duplicate()
	timers.resize(spots.size())
	collectors.resize(spots.size())
	_flash.resize(spots.size())
	reset()


## Everything ready (new match).
func reset() -> void:
	for i: int in spots.size():
		timers[i] = 0.0
		collectors[i] = 0
		_flash[i] = 0.0
	changed.emit()


func is_ready(i: int) -> bool:
	return timers[i] <= 0.0


## 0..1 of the way back (1 = ready).
func fill_fraction(i: int) -> float:
	return 1.0 - clampf(timers[i] / Constants.PICKUP_RESPAWN, 0.0, 1.0)


## A pickup only helps (and is only used up) when there is room for the energy.
static func wants(stats: PlayerStats) -> bool:
	return not stats.is_dead() and stats.energy < stats.max_energy


## Count the empty spots down; announces the ones that come back.
func tick(delta: float) -> void:
	for i: int in spots.size():
		_flash[i] = maxf(0.0, _flash[i] - delta)
		if timers[i] > 0.0:
			timers[i] = maxf(0.0, timers[i] - delta)
			if timers[i] <= 0.0:
				_flash[i] = READY_FLASH_TIME
				respawned.emit(i, spots[i])
				changed.emit()


## Authority: the first living player standing on a ready spot (with room for energy) takes it.
func collect(players: Array[Player]) -> void:
	for i: int in spots.size():
		if not is_ready(i):
			continue
		for p: Player in players:
			if p.dead or not PickupField.wants(p.stats) or p.global_position.distance_to(spots[i]) > Constants.PICKUP_RADIUS:
				continue
			p.stats.add_energy(Constants.ENERGY_PICKUP_AMOUNT)
			timers[i] = Constants.PICKUP_RESPAWN
			collectors[i] = p.player_id
			collected.emit(i, spots[i], p.player_id)
			changed.emit()
			break


## x = seconds left, y = collector id.
func to_array() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in spots.size():
		out.append(Vector2(timers[i], collectors[i]))
	return out


func apply_array(a: PackedVector2Array) -> void:
	for i: int in mini(a.size(), spots.size()):
		var was_ready: bool = is_ready(i)
		timers[i] = clampf(a[i].x, 0.0, Constants.PICKUP_RESPAWN)
		collectors[i] = int(a[i].y)
		if was_ready and not is_ready(i):
			collected.emit(i, spots[i], collectors[i])
		elif not was_ready and is_ready(i):
			_flash[i] = READY_FLASH_TIME
			respawned.emit(i, spots[i])


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var px: float = Constants.SPRITE_SCALE
	var t: float = Time.get_ticks_msec() * 0.001
	for i: int in spots.size():
		var at: Vector2 = spots[i]
		var pad_size: Vector2 = PAD_ART.get_size() * px
		var ready_now: bool = is_ready(i)
		var pad_at: Vector2 = at + Vector2(0.0, PAD_LIFT)
		draw_texture_rect(PAD_ART, Rect2(pad_at - pad_size * 0.5, pad_size), false, Color.WHITE if ready_now else EMPTY_TINT)
		if ready_now:
			var pulse: float = 0.5 + 0.5 * sin(t * TAU * 1.2 + i)
			var glow: Color = GLOW_COLOR
			glow.a = 0.10 + 0.10 * pulse
			draw_circle(pad_at, RING_RADIUS * (1.0 + 0.2 * pulse), glow)
			glow.a = 0.18 + 0.12 * pulse
			draw_circle(pad_at, RING_RADIUS * 0.6, glow)
			var bob: float = sin(t * TAU * BOB_HZ + i * 1.7) * BOB_PX
			var c_size: Vector2 = CRYSTAL_ART.get_size() * px
			draw_texture_rect(CRYSTAL_ART, Rect2(at + Vector2(-c_size.x * 0.5, -c_size.y * 0.5 - 8.0 + bob), c_size), false)
			if _flash[i] > 0.0:  # just came back: an expanding ring
				var k: float = 1.0 - _flash[i] / READY_FLASH_TIME
				var flash: Color = Color.WHITE
				flash.a = 1.0 - k
				draw_arc(pad_at, RING_RADIUS * (1.0 + k), 0.0, TAU, 32, flash, 3.0)
		else:
			draw_arc(pad_at, RING_RADIUS, 0.0, TAU, 32, RING_BACK, RING_WIDTH)
			var f: float = fill_fraction(i)
			if f > 0.0:
				draw_arc(pad_at, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * f, 32, RING_COLOR, RING_WIDTH)
			var label: String = str(ceili(timers[i]))
			var w: float = UiStyle.text_width(label, TIMER_FONT_SIZE, true)
			UiStyle.draw_text(self, pad_at + Vector2(-w * 0.5, TIMER_FONT_SIZE * 0.35), label, TIMER_FONT_SIZE,
				Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
