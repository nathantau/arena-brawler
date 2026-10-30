class_name SpecialFx
extends Node2D
## Cosmetic, on every peer: the smoke cloud and shadow clones of a player's special, rebuilt each
## frame from the synced skill state (Player.sync calls sync()). Clones copy the owner's sprite,
## walk animation, weapon and hand so they're hard to tell apart; they fade out at the end.

const SMOKE_PUFFS: int = 10
const SMOKE_SPIN: float = 0.5
const SMOKE_PULSE: float = 2.0
const SMOKE_COLOR: Color = Color(0.2, 0.2, 0.3, 0.82)
const SMOKE_EDGE: Color = Color(0.32, 0.32, 0.46, 0.9)
const FADE_TIME: float = 0.4

var _clones: Array[AnimatedSprite2D] = []
var _points := PackedVector2Array()
var _owner: Player
var _smoke_t: float = -1.0


func _init() -> void:
	top_level = true
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func sync(p: Player) -> void:
	_owner = p
	_points = p.clone_points()
	var frames: SpriteFrames = p.character.sprite_frames()
	while _clones.size() < _points.size():
		var c := AnimatedSprite2D.new()
		c.scale = Vector2.ONE * Constants.SPRITE_SCALE
		c.show_behind_parent = true
		add_child(c)
		_clones.append(c)
	var alpha: float = clampf(p.special.active_remaining / FADE_TIME, 0.0, 1.0)
	for i: int in _clones.size():
		var c: AnimatedSprite2D = _clones[i]
		c.visible = i < _points.size()
		if not c.visible:
			continue
		if c.sprite_frames != frames:
			c.sprite_frames = frames
		if c.animation != &"walk" or not c.is_playing():
			c.play(&"walk")
		c.position = _points[i]
		c.flip_h = _points[i].x < p.special.anchor.x
		c.modulate.a = alpha
	_smoke_t = p.special.elapsed() if p.special.is_smoking() else -1.0
	queue_redraw()


func _draw() -> void:
	if _owner == null:
		return
	for i: int in _points.size():
		_draw_clone_weapon(_points[i], Vector2.LEFT if _clones[i].flip_h else Vector2.RIGHT, _clones[i].modulate.a)
	if _smoke_t >= 0.0:
		var anchor: Vector2 = _owner.special.anchor
		var r: float = _owner.special.data.smoke_radius
		draw_circle(anchor, r * 0.7, SMOKE_COLOR)
		for i: int in SMOKE_PUFFS:
			var angle: float = TAU * i / SMOKE_PUFFS + _smoke_t * SMOKE_SPIN
			var reach: float = r * (0.55 + 0.15 * sin(_smoke_t * SMOKE_PULSE + i))
			var puff: Vector2 = anchor + Vector2.RIGHT.rotated(angle) * reach
			draw_circle(puff, r * 0.38, SMOKE_EDGE if i % 3 == 0 else SMOKE_COLOR)


## The clone holds the owner's current weapon (and hand), pointing the way it runs.
func _draw_clone_weapon(at: Vector2, dir: Vector2, alpha: float) -> void:
	var w: WeaponData = _owner.held_weapon().data
	if w.sprite == null:
		return
	var flip_v: float = -1.0 if dir.x < 0.0 else 1.0
	var s: float = Constants.SPRITE_SCALE
	draw_set_transform(at + Vector2(0.0, Player.WEAPON_HAND_Y) + dir * Player.WEAPON_HOLD_DISTANCE, dir.angle(),
		Vector2(s, s * flip_v))
	var tint := Color(1, 1, 1, alpha)
	draw_texture(w.sprite, -Player.WEAPON_GRIP, tint)
	var hand: Texture2D = _owner.character.hand_sprite
	if hand != null:
		draw_texture(hand, -hand.get_size() * 0.5, tint)
	draw_set_transform(Vector2.ZERO)
