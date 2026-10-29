class_name ClientInputRecorder
extends PlayerController
## Wraps LocalInput for the networked local player: every frame is predicted locally,
## recorded for reconciliation, and every INPUT_SEND_INTERVAL_TICKS the newest
## INPUT_REDUNDANCY frames are sent to the server.

var inner: LocalInput
var history: InputHistory
## Callable(batch: Array) -> void
var send: Callable

var _frames_since_send: int = 0


func _init(p_inner: LocalInput, p_history: InputHistory, p_send: Callable) -> void:
	inner = p_inner
	history = p_history
	send = p_send


func get_input(player: Player, delta: float) -> InputFrame:
	var frame: InputFrame = inner.get_input(player, delta)
	history.record(frame)
	_frames_since_send += 1
	if _frames_since_send >= Constants.INPUT_SEND_INTERVAL_TICKS:
		_frames_since_send = 0
		send.call(history.encode_latest(Constants.INPUT_REDUNDANCY))
	return frame
