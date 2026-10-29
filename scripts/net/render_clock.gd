class_name RenderClock
extends RefCounted
## The tick at which remote entities are rendered. Advances one tick per physics frame and is
## nudged toward (latest server tick - interpolation delay); snaps if it drifts too far.

var render_tick: float = 0.0
var _started: bool = false


func advance(target: float) -> void:
	if not _started:
		render_tick = target
		_started = true
		return
	render_tick += 1.0
	var err: float = target - render_tick
	if absf(err) > Constants.CLOCK_SNAP_TICKS:
		render_tick = target
	else:
		render_tick += err * Constants.CLOCK_CORRECTION
