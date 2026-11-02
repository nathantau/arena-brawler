class_name StageBackdrop
extends Control
## The pixel-art scene behind the fighter in the character select showcase (assets/backdrops/<character id>.png,
## tools/sprites/backdrops.py): a looping strip of FRAMES frames, drawn at a whole-number scale with its floor row on
## the fighter's feet. Switching theme crossfades over FADE_TIME.

const ART_W: int = 128
const ART_H: int = 184
const FLOOR_ROW: int = 128
const FRAMES: int = 24
const FPS: float = 12.0
const FADE_TIME: float = 0.25
const DIR: String = "res://assets/backdrops/"

## Screen y (in this control) of the fighter's feet: the picture's floor row is drawn there.
var floor_y: float = 0.0:
	set(v):
		floor_y = v
		queue_redraw()

var _tex: Texture2D
var _prev: Texture2D
## 0..1: how much of the new picture shows over the old one.
var _fade: float = 1.0
var _fade_tween: Tween
var _clock: float = 0.0
## The fighter's displayed pixel scale; the picture is drawn at the same one when it fits.
var art_scale: int = 1:
	set(v):
		art_scale = v
		queue_redraw()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The strip for a fighter, or null (a new fighter without a backdrop just shows the plain panel).
static func texture_for(id: StringName) -> Texture2D:
	var path: String = "%s%s.png" % [DIR, id]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Whole-number scale of the picture in a `size` panel with its floor row on `floor_y`: the fighter's own pixel
## scale (`fighter_scale`, so both show the same pixel size) unless the picture would not reach the top or bottom.
## Any width the picture does not cover is filled by stretching its (dark) edge columns.
static func fit_scale(size: Vector2, floor_y: float, fighter_scale: int = 1) -> int:
	var need: float = maxf(floor_y / FLOOR_ROW, (size.y - floor_y) / (ART_H - FLOOR_ROW))
	return maxi(maxi(1, fighter_scale), ceili(need))


## Switch to `tex`; the old picture fades out underneath. Quick successive switches replace the fade in flight.
func show_theme(tex: Texture2D, animate: bool = true) -> void:
	if tex == _tex:
		return
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	_prev = _tex if animate else null
	_tex = tex
	_fade = 0.0 if animate and _prev != null else 1.0
	if _fade < 1.0 and is_inside_tree():
		_fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fade_tween.tween_property(self, "_fade", 1.0, FADE_TIME)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _tex == null:
		return
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if _prev != null and _fade < 1.0:
		_draw_strip(_prev, 1.0)
	if _tex != null:
		_draw_strip(_tex, _fade)


func _draw_strip(tex: Texture2D, alpha: float) -> void:
	var s: int = fit_scale(size, floor_y, art_scale)
	var frame: int = int(_clock * FPS) % FRAMES
	var tint := Color(1.0, 1.0, 1.0, alpha)
	var dest := Rect2((size.x - ART_W * s) * 0.5, floor_y - FLOOR_ROW * s, ART_W * s, ART_H * s)
	draw_texture_rect_region(tex, dest, Rect2(frame * ART_W, 0, ART_W, ART_H), tint)
	if dest.position.x > 0.0:  # wider panel than picture: stretch the edge columns outwards
		draw_texture_rect_region(tex, Rect2(0.0, dest.position.y, dest.position.x, dest.size.y),
			Rect2(frame * ART_W, 0, 1, ART_H), tint)
		draw_texture_rect_region(tex, Rect2(dest.end.x, dest.position.y, size.x - dest.end.x, dest.size.y),
			Rect2(frame * ART_W + ART_W - 1, 0, 1, ART_H), tint)
