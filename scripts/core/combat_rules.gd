class_name CombatRules
extends RefCounted
## Pure combat math shared by client prediction and the server. All randomness goes
## through a caller-provided seeded RNG.


## Deterministic per-shot RNG seed so client prediction, the server and every observer
## reproduce the same crit roll and pellet spread from just (owner, seq). Factors keep the
## products well inside int64 for 31-bit ids/seqs.
static func shot_seed(match_seed: int, owner_id: int, seq: int) -> int:
	return (match_seed * 73856093) ^ (owner_id * 19349663) ^ (seq * 83492791)


static func roll_crit(weapon: WeaponData, rng: RandomNumberGenerator) -> bool:
	if weapon.crit_chance <= 0.0:
		return false
	return rng.randf() < weapon.crit_chance


## Weapon damage after crit and the rarity bonus (`rarity` = the owning weapon's / ability's tier, `salt` see `scaled`).
static func damage_for(weapon: WeaponData, crit: bool, rarity: int = 0, salt: int = 0) -> int:
	return scaled(roundi(weapon.damage * weapon.crit_multiplier) if crit else weapon.damage, rarity, salt)


## `damage` x the rarity tier's multiplier (Constants.RARITY_DAMAGE_MULT). Rounded stochastically so small hits still
## average damage x mult (a 2-dmg epic hit is 2 or 3, mean 2.2): the fraction is compared with a deterministic hash of
## `salt` (owner / shot seq / tick the caller has at hand), so it is reproducible. A hit that did >= 1 stays >= 1; 0 stays 0.
static func scaled(damage: int, rarity: int, salt: int = 0) -> int:
	if damage <= 0:
		return damage
	var x: float = snappedf(damage * Constants.RARITY_DAMAGE_MULT[clampi(rarity, 0, Constants.RARITY_DAMAGE_MULT.size() - 1)], 0.000001)
	var whole: int = floori(x)
	if x - whole > unit_hash(salt):
		whole += 1
	return maxi(1, whole)


## Deterministic integer hash of `n` mapped to [0, 1).
static func unit_hash(n: int) -> float:
	var h: int = (n * 2654435761 + 0x9E3779B9) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 2246822519) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 3266489917) & 0xFFFFFFFF
	h ^= h >> 16
	return float(h) / 4294967296.0


## Directions for every pellet of one shot: an even fan across `pellet_spread_deg`
## plus random jitter within `spread_deg`.
static func shot_directions(aim: Vector2, weapon: WeaponData, rng: RandomNumberGenerator) -> PackedVector2Array:
	var dirs := PackedVector2Array()
	var base: Vector2 = aim.normalized()
	var count: int = maxi(1, weapon.pellets)
	var fan: float = deg_to_rad(weapon.pellet_spread_deg)
	var jitter: float = deg_to_rad(weapon.spread_deg) * 0.5
	for i: int in count:
		var t: float = 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var angle: float = t * fan
		if jitter > 0.0:
			angle += rng.randf_range(-jitter, jitter)
		dirs.append(base.rotated(angle))
	return dirs


## Blast damage at `dist` from the centre: full at 0, `edge_scale` of it at the edge.
static func splash_damage(base: int, dist: float, radius: float, edge_scale: float) -> int:
	if radius <= 0.0 or dist > radius:
		return 0
	return roundi(base * lerpf(1.0, edge_scale, clampf(dist / radius, 0.0, 1.0)))


## True if `to` lies inside the swing arc centred on `facing` (full angle `arc_deg`).
static func in_arc(origin: Vector2, facing: Vector2, to: Vector2, arc_deg: float) -> bool:
	var d: Vector2 = to - origin
	if d.length_squared() == 0.0:
		return true
	return absf(facing.angle_to(d)) <= deg_to_rad(arc_deg) * 0.5
