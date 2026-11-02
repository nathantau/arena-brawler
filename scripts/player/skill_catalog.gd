class_name SkillCatalog
extends RefCounted
## All SkillData resources in res://data/skills/, keyed by id (ids go over the wire).

const SKILL_DIR: String = "res://data/skills/"
## The generic Dash (default slot-1 pick).
const DASH_ID: StringName = &"dash"

## Listed first for every fighter, in this order.
const TOP_IDS: Array[StringName] = [&"dash", &"barrier"]

var _by_id: Dictionary[StringName, SkillData] = {}

static var _shared: SkillCatalog


## One catalog for everyone (players resolve their skills by id from it).
static func shared() -> SkillCatalog:
	if _shared == null:
		_shared = load_all()
	return _shared


static func load_all() -> SkillCatalog:
	var catalog := SkillCatalog.new()
	# list_directory() resolves export remaps, unlike DirAccess.
	for file: String in ResourceLoader.list_directory(SKILL_DIR):
		var s := load(SKILL_DIR + file) as SkillData
		if s != null:
			catalog._by_id[s.id] = s
	return catalog


func get_skill(id: StringName) -> SkillData:
	return _by_id.get(id)


func dash() -> SkillData:
	return _by_id[DASH_ID]


## Specials `c` may pick, in the order the loading room lists them (every peer agrees): the shared Dash and Barrier
## on top for every fighter, then its signature, then the rest by id. `Player.default_skills` does not depend on this order
## beyond "own specials before generic ones", so a fresh pick is still Dash, signature, next own special.
func specials_for(c: CharacterData) -> Array[SkillData]:
	var out: Array[SkillData] = []
	for s: SkillData in _by_id.values():
		if s.special and c.can_use_skill(s) and s != c.signature_skill and not TOP_IDS.has(s.id):
			out.append(s)
	out.sort_custom(func(a: SkillData, b: SkillData) -> bool: return String(a.id) < String(b.id))
	if c.signature_skill != null:
		out.push_front(c.signature_skill)
	for i: int in range(TOP_IDS.size() - 1, -1, -1):
		var top: SkillData = _by_id.get(TOP_IDS[i])
		if top != null and top.special and c.can_use_skill(top) and top != c.signature_skill:
			out.push_front(top)
	return out


func size() -> int:
	return _by_id.size()
