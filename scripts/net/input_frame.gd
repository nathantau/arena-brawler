class_name InputFrame
extends RefCounted
## The only thing a client is allowed to send: {seq, move_vec, aim_vec, fire, skill, swap}.
## Buttons are held states; the simulation derives press edges itself so a dropped
## packet can't eat a dash.

var seq: int = 0
var move_vec: Vector2 = Vector2.ZERO
var aim_vec: Vector2 = Vector2.ZERO
var fire: bool = false
var skill: bool = false
var swap: bool = false


## Clamp untrusted values into legal ranges (server must call this on received input).
func sanitize() -> void:
	if not move_vec.is_finite():
		move_vec = Vector2.ZERO
	if not aim_vec.is_finite():
		aim_vec = Vector2.ZERO
	move_vec = move_vec.limit_length(1.0)
	aim_vec = aim_vec.normalized() if aim_vec.length_squared() > 0.0 else Vector2.ZERO


func to_dict() -> Dictionary:
	return {"seq": seq, "move": move_vec, "aim": aim_vec, "fire": fire, "skill": skill, "swap": swap}


static func from_dict(d: Dictionary) -> InputFrame:
	var f := InputFrame.new()
	f.seq = int(d.get("seq", 0))
	f.move_vec = d.get("move", Vector2.ZERO) if d.get("move") is Vector2 else Vector2.ZERO
	f.aim_vec = d.get("aim", Vector2.ZERO) if d.get("aim") is Vector2 else Vector2.ZERO
	f.fire = bool(d.get("fire", false))
	f.skill = bool(d.get("skill", false))
	f.swap = bool(d.get("swap", false))
	f.sanitize()
	return f
