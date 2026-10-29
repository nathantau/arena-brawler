class_name NetInputQueue
extends PlayerController
## Server-side controller for a remote player. Buffers received InputFrames (dropping
## duplicates from redundant packets and stale seqs) and releases them against a credit
## budget: one credit per server physics frame, banked up to INPUT_CATCHUP_MAX. After a
## network hitch the burst of late inputs is processed over a few frames instead of being
## dropped (which would cause a misprediction), but over time a client can never advance
## faster than real time, so sending extra inputs doesn't speed-hack.

var newest_seq: int = 0
var _queue: Array[InputFrame] = []
var _credit: float = 0.0


func push(frame: InputFrame) -> void:
	if frame.seq <= newest_seq:
		return
	newest_seq = frame.seq
	_queue.append(frame)
	while _queue.size() > Constants.INPUT_BUFFER_MAX:
		_queue.pop_front()


func size() -> int:
	return _queue.size()


func get_input(_player: Player, _delta: float) -> InputFrame:
	_credit = minf(_credit + 1.0, Constants.INPUT_CATCHUP_MAX)
	return next_extra_input()


func next_extra_input() -> InputFrame:
	if _queue.is_empty() or _credit < 1.0:
		return null
	_credit -= 1.0
	return _queue.pop_front()
