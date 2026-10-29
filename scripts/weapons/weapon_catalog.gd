class_name WeaponCatalog
extends RefCounted
## All WeaponData resources in res://data/weapons/, keyed by id (ids go over the wire).

const WEAPON_DIR: String = "res://data/weapons/"

var _by_id: Dictionary[StringName, WeaponData] = {}


static func load_all() -> WeaponCatalog:
	var catalog := WeaponCatalog.new()
	# list_directory() resolves export remaps, unlike DirAccess.
	for file: String in ResourceLoader.list_directory(WEAPON_DIR):
		var w := load(WEAPON_DIR + file) as WeaponData
		if w != null:
			catalog._by_id[w.id] = w
	return catalog


func get_weapon(id: StringName) -> WeaponData:
	return _by_id.get(id)


func resolve(ids: Array[StringName]) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for id: StringName in ids:
		var w: WeaponData = get_weapon(id)
		if w != null:
			out.append(w)
	return out


func size() -> int:
	return _by_id.size()
