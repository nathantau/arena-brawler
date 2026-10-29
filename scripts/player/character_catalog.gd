class_name CharacterCatalog
extends RefCounted
## All CharacterData resources in res://data/characters/, keyed by id (ids go over the wire).

const CHARACTER_DIR: String = "res://data/characters/"
const DEFAULT_ID: StringName = &"flicker"

var _by_id: Dictionary[StringName, CharacterData] = {}
## Sorted by id so every peer agrees on the order (lobby cycling).
var ordered: Array[CharacterData] = []


static func load_all() -> CharacterCatalog:
	var catalog := CharacterCatalog.new()
	# list_directory() resolves export remaps, unlike DirAccess.
	for file: String in ResourceLoader.list_directory(CHARACTER_DIR):
		var c := load(CHARACTER_DIR + file) as CharacterData
		if c != null:
			catalog._by_id[c.id] = c
			catalog.ordered.append(c)
	catalog.ordered.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.id < b.id)
	return catalog


func get_character(id: StringName) -> CharacterData:
	return _by_id.get(id)


func default_character() -> CharacterData:
	return _by_id.get(DEFAULT_ID)


## The character after `id` in `ordered` (wraps).
func next_after(id: StringName) -> CharacterData:
	for i: int in ordered.size():
		if ordered[i].id == id:
			return ordered[(i + 1) % ordered.size()]
	return default_character()
