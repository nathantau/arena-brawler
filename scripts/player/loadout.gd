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


func weapon_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for slot: WeaponState in slots:
		ids.append(String(slot.data.id))
	return ids


func cooldowns() -> Array[float]:
	var out: Array[float] = []
	for slot: WeaponState in slots:
		out.append(slot.cooldown)
	return out


## Adopt authoritative loadout state (from a server snapshot).
func sync(ids: PackedStringArray, slot_cooldowns: Array, active: int, catalog: WeaponCatalog) -> void:
	if ids != weapon_ids():
		var weapons: Array[WeaponData] = []
		for id: String in ids:
			var w: WeaponData = catalog.get_weapon(StringName(id))
			if w != null:
				weapons.append(w)
		if not weapons.is_empty():
			slots.clear()
			for w: WeaponData in weapons:
				slots.append(WeaponState.new(w))
	for i: int in mini(slots.size(), slot_cooldowns.size()):
		slots[i].cooldown = slot_cooldowns[i]
	active_index = clampi(active, 0, slots.size() - 1)
