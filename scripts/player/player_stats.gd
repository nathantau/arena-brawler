class_name PlayerStats
extends RefCounted
## HP / armor / energy / i-frames. Armor absorbs damage first and regenerates after
## Constants.ARMOR_REGEN_DELAY seconds without damage. HP never regenerates.

var max_hp: int
var max_armor: int
var max_energy: int
var hp: int
var armor: int
var energy: int
var time_since_damage: float = 0.0
var invulnerable_time: float = 0.0
## Fractional armor regen carried between ticks.
var regen_accum: float = 0.0


func _init(
	p_max_hp: int = Constants.PLAYER_MAX_HP,
	p_max_armor: int = Constants.PLAYER_MAX_ARMOR,
	p_max_energy: int = Constants.PLAYER_MAX_ENERGY,
) -> void:
	max_hp = p_max_hp
	max_armor = p_max_armor
	max_energy = p_max_energy
	reset()


func reset() -> void:
	hp = max_hp
	armor = max_armor
	energy = max_energy
	time_since_damage = Constants.ARMOR_REGEN_DELAY
	invulnerable_time = 0.0
	regen_accum = 0.0


func is_dead() -> bool:
	return hp <= 0


func is_invulnerable() -> bool:
	return invulnerable_time > 0.0


## Returns the total damage actually dealt (armor + hp). 0 if blocked.
func apply_damage(amount: int) -> int:
	if amount <= 0 or is_dead() or is_invulnerable():
		return 0
	var absorbed: int = mini(armor, amount)
	armor -= absorbed
	var to_hp: int = mini(hp, amount - absorbed)
	hp -= to_hp
	time_since_damage = 0.0
	regen_accum = 0.0
	return absorbed + to_hp


func tick(delta: float) -> void:
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	if is_dead():
		return
	var before: float = time_since_damage
	time_since_damage += delta
	if time_since_damage <= Constants.ARMOR_REGEN_DELAY or armor >= max_armor:
		return
	# Only the part of this tick past the delay counts toward regen.
	var regen_time: float = time_since_damage - maxf(before, Constants.ARMOR_REGEN_DELAY)
	regen_accum += Constants.ARMOR_REGEN_PER_SEC * regen_time
	var whole: int = int(regen_accum)
	if whole > 0:
		armor = mini(max_armor, armor + whole)
		regen_accum -= whole


func try_spend_energy(cost: int) -> bool:
	if cost <= 0:
		return true
	if energy < cost:
		return false
	energy -= cost
	return true


func add_energy(amount: int) -> void:
	energy = clampi(energy + amount, 0, max_energy)
