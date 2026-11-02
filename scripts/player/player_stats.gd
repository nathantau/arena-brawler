class_name PlayerStats
extends RefCounted
## HP / armor / energy / i-frames. Armor absorbs damage first and regenerates after
## Constants.ARMOR_REGEN_DELAY seconds without damage. Energy refills constantly. HP never regenerates.

var max_hp: int
var max_armor: int
var max_energy: int
var hp: int
var armor: int
var energy: int
var time_since_damage: float = 0.0
var invulnerable_time: float = 0.0
## Spawn protection: like invulnerable_time, but the first shot you fire ends it (Player._try_fire). Synced.
var spawn_protect: float = 0.0
## Fractional armor regen carried between ticks.
var regen_accum: float = 0.0
## Fractional energy regen carried between ticks.
var energy_accum: float = 0.0
## Snare: move speed is multiplied by slow_factor while slow_remaining > 0. Set only on the authority, synced.
var slow_remaining: float = 0.0
var slow_factor: float = 1.0
## Stun (Shadow Bind): can't move, fire or use specials while > 0. Set only on the authority, synced.
var stun_remaining: float = 0.0
## Soak (Splash Soaker): slowed by Constants.SOAK_SLOW, drips, can't burn while > 0. Set only on the authority, synced.
var soak_remaining: float = 0.0
## Bubble trap (Bubble Wand): can't move (can aim and shoot) while > 0, synced; `trap_cooldown` (authority only) is the
## per-target lockout (from the moment of the trap) before the next one.
var trap_remaining: float = 0.0
var trap_cooldown: float = 0.0
## Burn (Ember Palm): `burn_damage` every `burn_interval` while burn_remaining > 0; one burn at a time, a new hit
## refreshes it. Time is synced (it drives the ember flicker); the rest only matters to the authority.
var burn_remaining: float = 0.0
var burn_damage: int = 0
var burn_interval: float = 0.25
var burn_attacker: int = -1
## Burn ticks that fell due in the last tick() (the Player applies them on the authority).
var burn_due: int = 0


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
	spawn_protect = 0.0
	regen_accum = 0.0
	energy_accum = 0.0
	slow_remaining = 0.0
	slow_factor = 1.0
	stun_remaining = 0.0
	soak_remaining = 0.0
	trap_remaining = 0.0
	trap_cooldown = 0.0
	burn_remaining = 0.0
	burn_due = 0


func is_dead() -> bool:
	return hp <= 0


func is_invulnerable() -> bool:
	return invulnerable_time > 0.0 or spawn_protect > 0.0


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


## Restores hp (never past the max, nothing for the dead). Returns how much was healed.
func heal(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var gained: int = mini(max_hp - hp, amount)
	hp += gained
	return gained


func tick(delta: float) -> void:
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	spawn_protect = maxf(0.0, spawn_protect - delta)
	slow_remaining = maxf(0.0, slow_remaining - delta)
	stun_remaining = maxf(0.0, stun_remaining - delta)
	soak_remaining = maxf(0.0, soak_remaining - delta)
	trap_remaining = maxf(0.0, trap_remaining - delta)
	trap_cooldown = maxf(0.0, trap_cooldown - delta)
	var burn_before: float = burn_remaining
	burn_remaining = maxf(0.0, burn_remaining - delta)
	burn_due = ceili(burn_before / burn_interval) - ceili(burn_remaining / burn_interval)
	if is_dead():
		return
	if energy < max_energy:
		energy_accum += Constants.ENERGY_REGEN_PER_SEC * delta
		var gained: int = int(energy_accum)
		energy = mini(max_energy, energy + gained)
		energy_accum -= gained
	else:
		energy_accum = 0.0
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


## A new snare replaces the current one (refreshes it).
func apply_slow(time: float, factor: float) -> void:
	slow_remaining = time
	slow_factor = factor


## Sets the victim alight (refreshes a burn already running, never stacks).
func ignite(time: float, damage: int, interval: float, attacker_id: int) -> void:
	if soak_remaining > 0.0:  # wet things don't burn
		return
	burn_remaining = time
	burn_damage = damage
	burn_interval = interval
	burn_attacker = attacker_id


## Soaks the victim (refreshes) and puts out any burn.
func soak(time: float) -> void:
	soak_remaining = time
	burn_remaining = 0.0
	burn_due = 0


## Traps the victim in a bubble unless the per-target cooldown still runs. True if it caught.
func trap(time: float, cooldown: float) -> bool:
	if trap_cooldown > 0.0 or trap_remaining > 0.0:
		return false
	trap_remaining = time
	trap_cooldown = maxf(time, cooldown)
	return true


func is_trapped() -> bool:
	return trap_remaining > 0.0


## A new stun never shortens the current one.
func apply_stun(time: float) -> void:
	stun_remaining = maxf(stun_remaining, time)


func is_stunned() -> bool:
	return stun_remaining > 0.0


func speed_scale() -> float:
	var scale: float = slow_factor if slow_remaining > 0.0 else 1.0
	return minf(scale, Constants.SOAK_SLOW) if soak_remaining > 0.0 else scale


func try_spend_energy(cost: int) -> bool:
	if cost <= 0:
		return true
	if energy < cost:
		return false
	energy -= cost
	return true


func add_energy(amount: int) -> void:
	energy = clampi(energy + amount, 0, max_energy)
