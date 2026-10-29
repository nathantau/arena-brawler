class_name InputHistory
extends RefCounted
## Client-side record of inputs that were predicted but not yet acknowledged by the server.
## Fixed ring of preallocated frames so recording every physics frame doesn't allocate.

var _ring: Array[InputFrame] = []
var _start: int = 0
var _count: int = 0


func _init(capacity: int = Constants.INPUT_HISTORY_MAX) -> void:
	for i: int in capacity:
		_ring.append(InputFrame.new())


func record(frame: InputFrame) -> void:
	if _count == _ring.size():
		# Full: drop the oldest. Only happens if the server stops acking for seconds.
		_start = (_start + 1) % _ring.size()
		_count -= 1
	_ring[(_start + _count) % _ring.size()].copy_from(frame)
	_count += 1


## Forget every input the server has processed (seq <= acked_seq).
func ack(acked_seq: int) -> void:
	while _count > 0 and _ring[_start].seq <= acked_seq:
		_start = (_start + 1) % _ring.size()
		_count -= 1


func count() -> int:
	return _count


## i = 0 is the oldest unacked input.
func at(i: int) -> InputFrame:
	return _ring[(_start + i) % _ring.size()]


## Wire batch of the newest `n` inputs (redundant re-sends cover packet loss).
func encode_latest(n: int) -> Array:
	var out: Array = []
	for i: int in range(maxi(0, _count - n), _count):
		out.append(at(i).to_array())
	return out
