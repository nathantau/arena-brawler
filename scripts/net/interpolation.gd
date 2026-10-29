class_name SnapshotBuffer
extends RefCounted
## Per-remote-entity ring of (tick, position, facing) from server snapshots, sampled at a
## render tick ~100 ms in the past so motion is smooth despite 30 Hz updates and jitter.

## Results of the last successful sample().
var out_position: Vector2 = Vector2.ZERO
var out_facing: Vector2 = Vector2.RIGHT

var _ticks := PackedInt64Array()
var _positions := PackedVector2Array()
var _facings := PackedVector2Array()
var _head: int = 0
var _count: int = 0


func _init(capacity: int = Constants.INTERP_BUFFER_SIZE) -> void:
	_ticks.resize(capacity)
	_positions.resize(capacity)
	_facings.resize(capacity)


func push(tick: int, pos: Vector2, facing: Vector2) -> void:
	if _count > 0 and tick <= _ticks[_idx(_count - 1)]:
		return
	_ticks[_head] = tick
	_positions[_head] = pos
	_facings[_head] = facing
	_head = (_head + 1) % _ticks.size()
	_count = mini(_count + 1, _ticks.size())


func count() -> int:
	return _count


## i = 0 is the oldest entry.
func _idx(i: int) -> int:
	var n: int = _ticks.size()
	return (_head - _count + i + n) % n


## Interpolate at render_tick. Clamps to the oldest/newest entry outside the buffered range
## (no extrapolation). Jumps longer than TELEPORT_DISTANCE hold the old position until the
## new tick is reached instead of sliding across the map.
func sample(render_tick: float) -> bool:
	if _count == 0:
		return false
	var newest: int = _idx(_count - 1)
	if render_tick >= _ticks[newest]:
		_set_out(newest)
		return true
	for i: int in range(_count - 2, -1, -1):
		var a: int = _idx(i)
		if _ticks[a] > render_tick:
			continue
		var b: int = _idx(i + 1)
		var pa: Vector2 = _positions[a]
		var pb: Vector2 = _positions[b]
		if pa.distance_to(pb) > Constants.TELEPORT_DISTANCE:
			_set_out(a)
			return true
		var t: float = (render_tick - _ticks[a]) / float(_ticks[b] - _ticks[a])
		out_position = pa.lerp(pb, t)
		out_facing = _facings[a].slerp(_facings[b], t)
		return true
	_set_out(_idx(0))
	return true


func _set_out(i: int) -> void:
	out_position = _positions[i]
	out_facing = _facings[i]
