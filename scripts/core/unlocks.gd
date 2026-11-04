class_name Unlocks
extends RefCounted
## Gold economy: abilities and fun weapons are locked until a box (BOX_PRICE gold) rolls them. Unlocks are local
## (PlayerProfile.unlocked); the server accepts any valid pick, so the lobby UI is what enforces them.
## Starter set per fighter, never in a box: Dash, Barrier, its default skills, signature skill + weapon, ultimate.

const BOX_PRICE: int = 100
const UNLOCK_CODE: String = "test"
## There is ONE global box: it rolls from ALL lockable items of every playable (in-rotation) fighter, shared weapons
## once. An owned result is a duplicate and refunds gold by rarity. After PITY_DUPES duplicates in a row (one global
## counter, saved in PlayerProfile.pity) the next box only rolls locked items. Keys are global, so a pulled weapon
## unlocks for every fighter that can use it.
const DUPE_REFUND: Array[int] = [30, 50, 80]
const PITY_DUPES: int = 3
## Odds per rarity tier (SkillData / WeaponData.rarity 0 common, 1 rare, 2 epic).
const RARITY_WEIGHTS: Array[int] = [60, 30, 10]
const RARITY_NAMES: Array[String] = ["Common", "Rare", "Epic"]
const RARITY_COLORS: Array[Color] = [Color8(154, 167, 194), Color8(176, 110, 255), Color8(255, 196, 64)]  # steel, violet, gold: the box art

## "+5% dmg" / "+10% dmg" for a rare / epic item (Constants.RARITY_DAMAGE_MULT), "" for common.
static func dmg_bonus_text(rarity: int) -> String:
	var pct: int = roundi((Constants.RARITY_DAMAGE_MULT[clampi(rarity, 0, Constants.RARITY_DAMAGE_MULT.size() - 1)] - 1.0) * 100.0)
	return "+%d%% dmg" % pct if pct > 0 else ""

static var _weapons: WeaponCatalog
## --unlock-all / tests: everything counts as unlocked without touching the profile.
static var all_unlocked: bool = false


static func key(kind: StringName, id: StringName) -> String:
	return "%s:%s" % [kind, id]


static func _weapon_catalog() -> WeaponCatalog:
	if _weapons == null:
		_weapons = WeaponCatalog.load_all()
	return _weapons


## Weapons `c` may fight with: its signature, then the shared pickup weapons it can use (same list as Arena.weapons_for).
static func weapons_for(c: CharacterData) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	if c.signature_weapon != null:
		out.append(c.signature_weapon)
	var wc: WeaponCatalog = _weapon_catalog()
	for id: StringName in wc.pickup_ids():
		if c.can_use(wc.get_weapon(id)):
			out.append(wc.get_weapon(id))
	return out


static func is_starter_skill(c: CharacterData, s: SkillData) -> bool:
	return SkillCatalog.TOP_IDS.has(s.id) or s == c.signature_skill or s == c.ultimate or Player.default_skills(c).has(s)


static func is_skill_unlocked(c: CharacterData, s: SkillData) -> bool:
	if all_unlocked or is_starter_skill(c, s):
		return true
	PlayerProfile.ensure_loaded()
	return PlayerProfile.unlocked.has(key(&"skill", s.id))


static func is_weapon_unlocked(c: CharacterData, w: WeaponData) -> bool:
	if all_unlocked or w == c.signature_weapon:
		return true
	PlayerProfile.ensure_loaded()
	return PlayerProfile.unlocked.has(key(&"weapon", w.id))


## Every ability and weapon the box can ever give, owned or not, over all playable fighters (benched ones skipped),
## deduped by key: [{kind, id, rarity}] (+ `fighter` = the first fighter's id for a skill), abilities first.
static func lockable_all() -> Array:
	var skills: Array = []
	var weapons: Array = []
	var seen: Dictionary = {}
	for c: CharacterData in CharacterCatalog.load_all().ordered:
		for s: SkillData in SkillCatalog.shared().specials_for(c):
			if not is_starter_skill(c, s) and not seen.has(key(&"skill", s.id)):
				seen[key(&"skill", s.id)] = true
				skills.append({"kind": &"skill", "id": s.id, "rarity": s.rarity, "fighter": c.id})
		for w: WeaponData in weapons_for(c):
			if w != c.signature_weapon and not seen.has(key(&"weapon", w.id)):
				seen[key(&"weapon", w.id)] = true
				weapons.append({"kind": &"weapon", "id": w.id, "rarity": w.rarity})
	return skills + weapons


static func is_owned(entry: Dictionary) -> bool:
	if all_unlocked:
		return true
	PlayerProfile.ensure_loaded()
	return PlayerProfile.unlocked.has(key(entry["kind"], entry["id"]))


## The still-locked part of lockable_all().
static func box_pool_all() -> Array:
	return lockable_all().filter(func(e: Dictionary) -> bool: return not is_owned(e))


static func refund_for(rarity: int) -> int:
	return DUPE_REFUND[clampi(rarity, 0, DUPE_REFUND.size() - 1)]


## Picks a rarity tier by weight among the tiers that still have entries, then an entry in it. {} for an empty pool.
static func roll(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for tier: int in RARITY_WEIGHTS.size():
		if not _in_tier(pool, tier).is_empty():
			total += RARITY_WEIGHTS[tier]
	if total == 0:
		return {}
	var r: int = rng.randi_range(0, total - 1)
	for tier: int in RARITY_WEIGHTS.size():
		var entries: Array = _in_tier(pool, tier)
		if entries.is_empty():
			continue
		if r < RARITY_WEIGHTS[tier]:
			return entries[rng.randi_range(0, entries.size() - 1)]
		r -= RARITY_WEIGHTS[tier]
	return {}


static func _in_tier(pool: Array, tier: int) -> Array:
	return pool.filter(func(e: Dictionary) -> bool: return clampi(e["rarity"], 0, RARITY_WEIGHTS.size() - 1) == tier)


## Pays BOX_PRICE for a roll from all lockable items (only the still-locked ones once the pity count is
## reached). A new item is unlocked; an owned one is a duplicate and refunds DUPE_REFUND. Returns the entry plus
## `dupe` and `refund`; {} if everything is unlocked or gold is short.
static func open_box(rng: RandomNumberGenerator = null) -> Dictionary:
	PlayerProfile.ensure_loaded()
	var locked: Array = box_pool_all()
	if locked.is_empty() or PlayerProfile.gold < BOX_PRICE:
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var pity: int = PlayerProfile.pity
	var got: Dictionary = roll(locked if pity >= PITY_DUPES else lockable_all(), rng).duplicate()
	if not PlayerProfile.spend_gold(BOX_PRICE):
		return {}
	var k: String = key(got["kind"], got["id"])
	got["dupe"] = not locked.any(func(e: Dictionary) -> bool: return key(e["kind"], e["id"]) == k)
	got["refund"] = refund_for(got["rarity"]) if got["dupe"] else 0
	if got["dupe"]:
		PlayerProfile.gold += got["refund"]
		PlayerProfile.pity = pity + 1
	else:
		PlayerProfile.unlocked[k] = true
		PlayerProfile.pity = 0
	PlayerProfile.save()
	return got


## Dev / tests: every pickable ability and weapon counts as unlocked (in memory only, nothing is saved).
static func unlock_all() -> void:
	all_unlocked = true


## Settings "Enter code": the unlock code permanently adds every lockable ability and weapon to the saved profile.
## Case-insensitive, whitespace trimmed. False (nothing changed) for any other code.
static func redeem(code: String) -> bool:
	if code.strip_edges().to_lower() != UNLOCK_CODE:
		return false
	PlayerProfile.ensure_loaded()
	for e: Dictionary in lockable_all():
		PlayerProfile.unlocked[key(e["kind"], e["id"])] = true
	PlayerProfile.save()
	return true
