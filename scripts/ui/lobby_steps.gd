class_name LobbySteps
extends RefCounted
## Which panel of the character select is showing: Fighter -> Abilities -> Weapon. Picking a fighter opens the
## abilities, picking the third special opens the weapons, and any earlier step can be revisited at will.
## Pure logic (no nodes) so the flow is unit-testable.

enum Step { FIGHTER, ABILITIES, WEAPON }

var step: Step = Step.FIGHTER
## Specials the player has actively picked since the fighter last changed.
var specials_picked: int = 0


## A fighter was tapped: its abilities come next. `changed` = it differs from the one picked before (the count resets).
func pick_fighter(changed: bool) -> void:
	if changed:
		specials_picked = 0
	step = Step.ABILITIES


## A new special was equipped (tapping an equipped one does not count). The third pick opens the weapons.
func pick_special(slots: int) -> void:
	specials_picked += 1
	if step == Step.ABILITIES and specials_picked >= slots:
		step = Step.WEAPON


## The "next" button / a breadcrumb tab / tapping the preview.
func go(to: Step) -> void:
	step = to


func next() -> void:
	step = mini(step + 1, Step.WEAPON) as Step
