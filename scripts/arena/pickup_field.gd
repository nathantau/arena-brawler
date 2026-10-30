class_name PickupField
extends Node2D
## Energy and weapon pickups on respawn timers. Authoritative (offline / server) fields
## detect collection and run the timers; client fields only mirror availability sent by
## the server (to_array / apply_array) and draw. Spot positions come from the map, so they
## are identical on every peer and never go over the wire.

signal changed
## Cosmetic: a pickup was taken (authoritative: on collection; clients: when the server says so).
signal collected(at: Vector2, kind: Kind)

enum Kind { ENERGY, WEAPON }
## Wire format per spot: [available, weapon_id].
enum Field { AVAILABLE, WEAPON_ID, COUNT }

const ENERGY_COLOR: Color = Color(0.3, 0.6, 1.0)
const PAD_COLOR: Color = Color(1, 1, 1, 0.08)
const OUTLINE_COLOR: Color = Color(1, 1, 1, 0.7)
const OUTLINE_WIDTH: float = 2.0
const PAD_RADIUS_SCALE: float = 1.4
## Weapons the viewer's character can't carry are drawn faded.
const UNUSABLE_ALPHA: float = 0.3
const LABEL_FONT_SIZE: int = 11
const LABEL_OFFSET_Y: float = 24.0
const BOB_PX: float = 3.0
const BOB_SPEED: float = 3.0
const SEGMENTS: int = 20
const DIAMOND_WIDTH: float = 0.7


class Spot:
	var kind: Kind = Kind.ENERGY
	var pos: Vector2 = Vector2.ZERO
	var available: bool = true
	var timer: float = 0.0
	var weapon_id: StringName = &""


var authoritative: bool = true
## This device's player (cosmetic: fades weapons their character can't use).
var viewer: Player
var spots: Array[Spot] = []

var _catalog: WeaponCatalog
var _weapon_pool: Array[StringName] = []
var _rng := RandomNumberGenerator.new()
var _seed: int = 0
var _time: float = 0.0
## Reused so _draw doesn't allocate.
var _diamond := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func setup(map: ArenaMap, catalog: WeaponCatalog, weapon_pool: Array[StringName], p_seed: int) -> void:
	_catalog = catalog
	_weapon_pool = weapon_pool
	_seed = p_seed
	spots.clear()
	for pos: Vector2 in map.energy_spots:
		_add_spot(Kind.ENERGY, pos)
	for pos: Vector2 in map.weapon_spots:
		_add_spot(Kind.WEAPON, pos)
	reset()


## Everything available again with freshly rolled weapons (start of a match).
func reset() -> void:
	_rng.seed = _seed
	for s: Spot in spots:
		s.available = true
		s.timer = 0.0
		if s.kind == Kind.WEAPON:
			_roll_weapon(s)
	changed.emit()


## Applies a pickup's effect. Returns false if it would do nothing (energy full, weapon
## already carried or not usable by `character`); the pickup then stays on the floor.
static func apply_to(kind: Kind, weapon: WeaponData, stats: PlayerStats, loadout: Loadout,
		character: CharacterData = null) -> bool:
	match kind:
		Kind.ENERGY:
			if stats.energy >= stats.max_energy:
				return false
			stats.add_energy(Constants.ENERGY_PICKUP_AMOUNT)
			return true
		Kind.WEAPON:
			if weapon == null or (character != null and not character.can_use(weapon)):
				return false
			return loadout.give(weapon)
	return false


static func respawn_time(kind: Kind) -> float:
	return Constants.ENERGY_PICKUP_RESPAWN if kind == Kind.ENERGY else Constants.WEAPON_PICKUP_RESPAWN


func tick(delta: float, players: Array[Player]) -> void:
	if not authoritative:
		return
	var dirty: bool = false
	var reach_sq: float = (Constants.PLAYER_RADIUS + Constants.PICKUP_RADIUS) ** 2
	for s: Spot in spots:
		if not s.available:
			s.timer -= delta
			if s.timer <= 0.0:
				s.available = true
				if s.kind == Kind.WEAPON:
					_roll_weapon(s)
				dirty = true
			continue
		for p: Player in players:
			if p.dead or p.global_position.distance_squared_to(s.pos) > reach_sq:
				continue
			var weapon: WeaponData = _catalog.get_weapon(s.weapon_id) if s.kind == Kind.WEAPON else null
			if apply_to(s.kind, weapon, p.stats, p.loadout, p.character):
				s.available = false
				s.timer = respawn_time(s.kind)
				dirty = true
				collected.emit(s.pos, s.kind)
				break
	if dirty:
		changed.emit()


func to_array() -> Array:
	var out: Array = []
	for s: Spot in spots:
		out.append([s.available, s.weapon_id])
	return out


func apply_array(a: Array) -> void:
	for i: int in mini(a.size(), spots.size()):
		var row: Variant = a[i]
		if not row is Array or (row as Array).size() != Field.COUNT:
			continue
		var r: Array = row
		if typeof(r[Field.AVAILABLE]) == TYPE_BOOL:
			if spots[i].available and not r[Field.AVAILABLE]:
				collected.emit(spots[i].pos, spots[i].kind)
			spots[i].available = r[Field.AVAILABLE]
		if typeof(r[Field.WEAPON_ID]) == TYPE_STRING_NAME:
			spots[i].weapon_id = r[Field.WEAPON_ID]
	queue_redraw()


func _add_spot(kind: Kind, pos: Vector2) -> void:
	var s := Spot.new()
	s.kind = kind
	s.pos = pos
	spots.append(s)


func _roll_weapon(s: Spot) -> void:
	if not _weapon_pool.is_empty():
		s.weapon_id = _weapon_pool[_rng.randi_range(0, _weapon_pool.size() - 1)]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var bob: Vector2 = Vector2(0.0, sin(_time * BOB_SPEED) * BOB_PX)
	var r: float = Constants.PICKUP_RADIUS
	for s: Spot in spots:
		draw_circle(s.pos, r * PAD_RADIUS_SCALE, PAD_COLOR)
		if not s.available:
			continue
		var c: Vector2 = s.pos + bob
		if s.kind == Kind.ENERGY:
			_diamond[0] = c + Vector2(0, -r)
			_diamond[1] = c + Vector2(r * DIAMOND_WIDTH, 0)
			_diamond[2] = c + Vector2(0, r)
			_diamond[3] = c + Vector2(-r * DIAMOND_WIDTH, 0)
			draw_colored_polygon(_diamond, ENERGY_COLOR)
			draw_polyline(_diamond, OUTLINE_COLOR, OUTLINE_WIDTH)
			draw_line(_diamond[3], _diamond[0], OUTLINE_COLOR, OUTLINE_WIDTH)
		else:
			var w: WeaponData = _catalog.get_weapon(s.weapon_id) if _catalog != null else null
			if w == null:
				continue
			var tint := Color(1, 1, 1, 1)
			if viewer != null and not viewer.character.can_use(w):
				tint.a = UNUSABLE_ALPHA
			var scale_px: float = Constants.SPRITE_SCALE
			draw_set_transform(c, 0.0, Vector2(scale_px, scale_px))
			draw_texture(w.sprite, -w.sprite.get_size() * 0.5, tint)
			draw_set_transform(Vector2.ZERO)
			var label_color: Color = OUTLINE_COLOR * tint
			var tw: float = font.get_string_size(w.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
			draw_string(font, s.pos + Vector2(-tw * 0.5, -LABEL_OFFSET_Y), w.display_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, label_color)
