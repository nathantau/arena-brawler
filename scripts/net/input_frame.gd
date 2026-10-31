class_name InputFrame
extends RefCounted
## The only thing a client is allowed to send: {seq, move_vec, aim_vec, fire, skill (slot 0), special (slot 1)}.
## Buttons are held states; the simulation derives press edges itself so a dropped
## packet can't eat a dash. Wire format: [seq, move_vec, aim_vec, flags].

const FLAG_FIRE: int = 1
const FLAG_SKILL: int = 2
const FLAG_SPECIAL: int = 8
const WIRE_SIZE: int = 4

var seq: int = 0
var move_vec: Vector2 = Vector2.ZERO
var aim_vec: Vector2 = Vector2.ZERO
var fire: bool = false
var skill: bool = false
var special: bool = false


## Clamp untrusted values into legal ranges (server must call this on received input).
func sanitize() -> void:
	seq = maxi(seq, 0)
	if not move_vec.is_finite():
		move_vec = Vector2.ZERO
	if not aim_vec.is_finite():
		aim_vec = Vector2.ZERO
	move_vec = move_vec.limit_length(1.0)
	aim_vec = aim_vec.normalized() if aim_vec.length_squared() > 0.0 else Vector2.ZERO


func copy_from(other: InputFrame) -> void:
	seq = other.seq
	move_vec = other.move_vec
	aim_vec = other.aim_vec
	fire = other.fire
	skill = other.skill
	special = other.special


func to_array() -> Array:
	var flags: int = (FLAG_FIRE if fire else 0) | (FLAG_SKILL if skill else 0) | (FLAG_SPECIAL if special else 0)
	return [seq, move_vec, aim_vec, flags]


## Parses untrusted wire data. Returns null if malformed.
static func from_array(data: Variant) -> InputFrame:
	if not data is Array:
		return null
	var a: Array = data
	if a.size() != WIRE_SIZE or typeof(a[0]) != TYPE_INT or not a[1] is Vector2 \
			or not a[2] is Vector2 or typeof(a[3]) != TYPE_INT:
		return null
	var f := InputFrame.new()
	f.seq = a[0]
	f.move_vec = a[1]
	f.aim_vec = a[2]
	var flags: int = a[3]
	f.fire = flags & FLAG_FIRE != 0
	f.skill = flags & FLAG_SKILL != 0
	f.special = flags & FLAG_SPECIAL != 0
	f.sanitize()
	return f
