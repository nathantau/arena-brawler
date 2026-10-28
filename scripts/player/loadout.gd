class_name Loadout
extends RefCounted
## The weapons a player carries (Constants.LOADOUT_SLOTS) and which one is active.

var slots: Array[WeaponState] = []
var active_index: int = 0


func _init(weapons: Array[WeaponData]) -> void:
	for w: WeaponData in weapons.slice(0, Constants.LOADOUT_SLOTS):
		slots.append(WeaponState.new(w))


func active() -> WeaponState:
	return slots[active_index]


func swap() -> void:
	if slots.size() > 1:
		active_index = (active_index + 1) % slots.size()


## Replace the weapon in the active slot (pickups; dev weapon cycling for now).
func replace_active(weapon: WeaponData) -> void:
	slots[active_index] = WeaponState.new(weapon)


func tick(delta: float) -> void:
	for slot: WeaponState in slots:
		slot.tick(delta)


func reset_cooldowns() -> void:
	for slot: WeaponState in slots:
		slot.cooldown = 0.0
