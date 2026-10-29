class_name CrateField
extends Node2D
## All crates of the current layout. Authoritative fields apply damage and announce changes;
## clients mirror hp (to_array / apply_array). Crates come back at the start of every match.

signal changed
signal destroyed(at: Vector2)

var crates: Array[Crate] = []


func setup(map: ArenaMap) -> void:
	for c: Crate in crates:
		remove_child(c)
		c.queue_free()
	crates.clear()
	for i: int in map.crate_spots.size():
		var c := Crate.new()
		c.setup(i, map.crate_spots[i], Constants.TILE_SIZE)
		c.damaged.connect(_on_damaged)
		add_child(c)
		crates.append(c)


func reset() -> void:
	for c: Crate in crates:
		c.set_hp(Constants.CRATE_HP)
	changed.emit()


func to_array() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c: Crate in crates:
		out.append(c.hp)
	return out


func apply_array(a: PackedInt32Array) -> void:
	for i: int in mini(a.size(), crates.size()):
		var c: Crate = crates[i]
		var was_intact: bool = c.is_intact()
		c.set_hp(a[i])
		if was_intact and not c.is_intact():
			destroyed.emit(c.global_position)


func _on_damaged(c: Crate) -> void:
	if not c.is_intact():
		destroyed.emit(c.global_position)
	changed.emit()
