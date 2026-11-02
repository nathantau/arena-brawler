class_name LobbyOverlay
extends RefCounted
## The character select's detail overlay: closed on the fighter grid, opened by tapping a fighter (it then shows that
## fighter's abilities and weapons), closed by the scrim, the back button or by locking in.
## Pure logic (no nodes) so the flow is unit-testable.

var is_open: bool = false
## The fighter the overlay was last opened for.
var fighter: StringName = &""
## The ability slot (0-based) the next tapped ability goes into: the gold-outlined card. Starts on the second slot
## (the first holds Dash by default) and moves on to the next slot after each placement.
var target_slot: int = DEFAULT_TARGET

const DEFAULT_TARGET: int = 1


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


## A slot card was tapped: the next ability goes there.
func set_target(slot: int, slots: int = Constants.SKILL_SLOTS) -> void:
	target_slot = clampi(slot, 0, slots - 1)


## An ability is being placed: returns the slot it goes into and moves the target on to the next slot.
func take_slot(slots: int = Constants.SKILL_SLOTS) -> int:
	var slot: int = target_slot
	target_slot = (slot + 1) % slots
	return slot


## The fighter changed: the slots are theirs again, so the target starts over.
func reset_target() -> void:
	target_slot = DEFAULT_TARGET
