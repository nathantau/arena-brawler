class_name PlayerController
extends RefCounted
## Produces one InputFrame per physics frame for a Player (local input, bot, or network).


## Implementations return a reused frame; callers must not keep a reference across frames.
func get_input(_player: Player, _delta: float) -> InputFrame:
	return InputFrame.new()
