class_name PlayerProfile
extends RefCounted
## Local progression, saved to user://profile.cfg (same static pattern as GameSettings): lifetime totals plus
## per-fighter matches, wins and mastery XP. No backend; every match (offline too) feeds it via `record_match`.

const PATH: String = "user://profile.cfg"

## XP per match: played + win bonus + each kill + damage / DAMAGE_PER_XP.
const XP_PLAYED: int = 50
const XP_WIN: int = 50
const XP_KILL: int = 10
const DAMAGE_PER_XP: int = 100
## Mastery 1..MAX_LEVEL: reaching level L needs LEVEL_STEP * (L-1) * L / 2 XP in total (150, 450, 900 ... 6750).
const MAX_LEVEL: int = 10
const LEVEL_STEP: int = 150
## Gold per match (played + win + kills) and per mastery level gained; a profile with no [wallet] starts with START_GOLD.
const GOLD_PLAYED: int = 25
const GOLD_WIN: int = 25
const GOLD_KILL: int = 5
const GOLD_LEVEL_UP: int = 100
const START_GOLD: int = 150

static var path: String = PATH
static var matches: int = 0
static var wins: int = 0
static var kills: int = 0
static var damage: int = 0
## fighter id (String) -> {matches, wins, xp}
static var fighters: Dictionary = {}
static var gold: int = START_GOLD
## "skill:<id>" / "weapon:<id>" -> true: unlocked abilities and weapons (see Unlocks).
static var unlocked: Dictionary = {}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if not _loaded:
		load_from(path)


static func xp_for_match(won: bool, match_kills: int, match_damage: int) -> int:
	return XP_PLAYED + (XP_WIN if won else 0) + XP_KILL * maxi(match_kills, 0) + maxi(match_damage, 0) / DAMAGE_PER_XP


static func gold_for_match(won: bool, match_kills: int) -> int:
	return GOLD_PLAYED + (GOLD_WIN if won else 0) + GOLD_KILL * maxi(match_kills, 0)


## Pays `n` gold if the wallet has it (saves); false and no change otherwise.
static func spend_gold(n: int) -> bool:
	ensure_loaded()
	if n < 0 or n > gold:
		return false
	gold -= n
	save()
	return true


## Total XP needed to reach `level` (level 1 = 0).
static func xp_for_level(level: int) -> int:
	var l: int = clampi(level, 1, MAX_LEVEL)
	return LEVEL_STEP * (l - 1) * l / 2


static func level_for_xp(xp: int) -> int:
	var level: int = 1
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
	return level


## 0..1 progress through the current level (1 at max level).
static func level_fraction(xp: int) -> float:
	var level: int = level_for_xp(xp)
	if level >= MAX_LEVEL:
		return 1.0
	var from: int = xp_for_level(level)
	return float(xp - from) / float(xp_for_level(level + 1) - from)


static func xp_of(fighter: StringName) -> int:
	ensure_loaded()
	return int((fighters.get(String(fighter), {}) as Dictionary).get("xp", 0))


static func level_of(fighter: StringName) -> int:
	return level_for_xp(xp_of(fighter))


## Adds a finished match to the totals and the fighter's mastery; saves. Returns {xp, xp_before, xp_after,
## level_before, level_after, gold, gold_after} for the results panel (gold = match gold + level-up bonuses).
static func record_match(fighter: StringName, won: bool, match_kills: int, match_damage: int) -> Dictionary:
	ensure_loaded()
	var before: int = xp_of(fighter)
	var gained: int = xp_for_match(won, match_kills, match_damage)
	matches += 1
	wins += 1 if won else 0
	kills += match_kills
	damage += match_damage
	var f: Dictionary = fighters.get(String(fighter), {"matches": 0, "wins": 0, "xp": 0})
	f["matches"] = int(f["matches"]) + 1
	f["wins"] = int(f["wins"]) + (1 if won else 0)
	f["xp"] = before + gained
	fighters[String(fighter)] = f
	var level_before: int = level_for_xp(before)
	var level_after: int = level_for_xp(before + gained)
	var gold_gained: int = gold_for_match(won, match_kills) + GOLD_LEVEL_UP * (level_after - level_before)
	gold += gold_gained
	save()
	return {"xp": gained, "xp_before": before, "xp_after": before + gained,
		"level_before": level_before, "level_after": level_after, "gold": gold_gained, "gold_after": gold}


## Missing file or keys keep the defaults; negatives are clamped so a hand-edited file can't break the maths.
static func load_from(p: String) -> void:
	_loaded = true
	matches = 0
	wins = 0
	kills = 0
	damage = 0
	fighters = {}
	gold = START_GOLD
	unlocked = {}
	var cfg := ConfigFile.new()
	if cfg.load(p) != OK:
		return
	matches = maxi(int(cfg.get_value("totals", "matches", 0)), 0)
	wins = maxi(int(cfg.get_value("totals", "wins", 0)), 0)
	kills = maxi(int(cfg.get_value("totals", "kills", 0)), 0)
	damage = maxi(int(cfg.get_value("totals", "damage", 0)), 0)
	gold = maxi(int(cfg.get_value("wallet", "gold", START_GOLD)), 0)
	if cfg.has_section("unlocks"):
		for key: String in cfg.get_section_keys("unlocks"):
			if cfg.get_value("unlocks", key, false):
				unlocked[key] = true
	for section: String in cfg.get_sections():
		if section.begins_with("fighter:"):
			fighters[section.substr(8)] = {
				"matches": maxi(int(cfg.get_value(section, "matches", 0)), 0),
				"wins": maxi(int(cfg.get_value(section, "wins", 0)), 0),
				"xp": maxi(int(cfg.get_value(section, "xp", 0)), 0)}


static func save_to(p: String) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("totals", "matches", matches)
	cfg.set_value("totals", "wins", wins)
	cfg.set_value("totals", "kills", kills)
	cfg.set_value("totals", "damage", damage)
	cfg.set_value("wallet", "gold", gold)
	for key: String in unlocked:
		cfg.set_value("unlocks", key, true)
	for id: String in fighters:
		var f: Dictionary = fighters[id]
		for k: String in ["matches", "wins", "xp"]:
			cfg.set_value("fighter:" + id, k, f[k])
	return cfg.save(p)


static func save() -> void:
	if save_to(path) != OK:
		push_warning("Could not save profile")
