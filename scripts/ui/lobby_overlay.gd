class_name LobbyOverlay
extends RefCounted
## The character select's detail overlay: closed on the fighter grid, opened by tapping a fighter (it then shows that
## fighter's abilities and weapons), closed by the scrim, the back button or by locking in.
## Pure logic (no nodes) so the flow is unit-testable.

var is_open: bool = false
## The fighter the overlay was last opened for.
var fighter: StringName = &""


## A fighter card was tapped. Returns true when the overlay has to slide in (it was closed or closing); tapping
## another fighter while it is open only swaps the fighter.
func open_for(id: StringName) -> bool:
	var slides_in: bool = not is_open
	is_open = true
	fighter = id
	return slides_in


## Scrim or back button. Returns true when there was something to close.
func close() -> bool:
	var was_open: bool = is_open
	is_open = false
	return was_open


## READY / LOCK IN pressed: locking in closes the overlay back to the grid (your card turns gold); unlocking
## leaves it as it is.
func ready_pressed(will_be_ready: bool) -> void:
	if will_be_ready:
		is_open = false
