class_name ShieldWall
extends StaticBody2D
## The barrier bubble, or (`is_ward`) the Blossom Ward ring. Both are a circle on LAYER_SHIELDS that is a child of the
## owner, so it is centred on and follows them (identical on server, predictor and observers, interpolated remote players
## too): projectiles from anyone but the owner stop on it; players and line-of-sight ignore it.
## The barrier reflects shots back as the owner's (`reflects`) and has a hit budget (`absorb`); a ward only stops
## projectiles (beams pass) and pops them without a blast (ProjectilePool). Both are drawn by SpecialFx.

## A shot was caught on the ward at `at` (every peer, for the petal pop).
signal caught(at: Vector2)
## A shot hit the barrier bubble at `at` (every peer, for the ripple).
signal struck(at: Vector2)

var owner_id: int = 0
var is_ward: bool = false
## Shots that hit it are sent back as the owner's (barrier with `shield_reflect`).
var reflects: bool = false

var _circle := CircleShape2D.new()
var _cs := CollisionShape2D.new()
var _up: bool = false
var _skill: CharacterSkill


func _init(ward: bool = false) -> void:
	is_ward = ward
	collision_layer = Constants.LAYER_SHIELDS
	collision_mask = 0
	_cs.shape = _circle
	_cs.disabled = true
	add_child(_cs)
	visible = false


func is_up() -> bool:
	return _up


## Follow the skill state; called after every simulate / apply_state.
func sync(skill: CharacterSkill, dead: bool) -> void:
	_skill = skill
	var up: bool = (skill.is_warding() if is_ward else skill.is_shielding()) and not dead
	if up:
		_circle.radius = skill.data.ward_radius if is_ward else skill.data.shield_radius
		reflects = not is_ward and skill.data.shield_reflect
	if up != _up:
		_up = up
		_cs.set_deferred("disabled", not up)


## The barrier took a shot at `at` (every peer: the ripple). The authoritative pool also spends the hit budget; the last hit
## breaks the bubble at once (snapshots carry the broken state to the clients).
func absorb(at: Vector2, count: bool) -> void:
	struck.emit(at)
	if count and _skill != null and _skill.absorb_hit():
		sync(_skill, false)
