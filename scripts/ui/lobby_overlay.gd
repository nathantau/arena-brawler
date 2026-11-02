class_name LobbyOverlay
extends RefCounted
## The character select's detail overlay: closed on the fighter grid, opened by tapping a fighter (it then shows that
## fighter's abilities and weapons), closed by the scrim, the back button or by locking in.
## Abilities are plain toggles: tapping an unequipped one fills the first empty slot, tapping an equipped one empties
## its slot, and nothing is ever replaced behind the player's back.
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


## What a tap on ability `id` does, given the slots (each an ability id, or &"" when empty):
## {"kind": "add", "slot": first empty slot}, {"kind": "remove", "slot": its slot} or {"kind": "full"} when every
## slot is taken by other abilities.
static func toggle(slots: Array, id: StringName) -> Dictionary:
	var held: int = slots.find(id)
	if held >= 0:
		return {"kind": "remove", "slot": held}
	var empty: int = slots.find(&"")
	if empty >= 0:
		return {"kind": "add", "slot": empty}
	return {"kind": "full"}
