class_name AimGuide
extends Node2D
## Local view only: while the thumb drags the attack button or a skill button, a translucent pixel strip runs from the
## player along that aim out to the weapon's / skill's reach (cut short by walls), a cone for spread weapons, and a landing
## circle for lobbed, splash and placed things. Lives in the arena world, under the players (z -1), never in the HUD.

const Z: int = -1
const DASH_LEN: float = 12.0
const DASH_GAP: float = 8.0
const DASH_WIDTH: float = 4.0
const CONE_RAYS: int = 9
## Narrower spreads than this read as a plain strip.
const MIN_CONE_DEG: float = 6.0
## Reach of a skill with no range of its own (a generic direction line).
const GENERIC_REACH: float = 240.0
## Lobbed shots with no splash still land on a small mark.
const MIN_LAND_RADIUS: float = 16.0
const CIRCLE_SEGMENTS: int = 40
const COLOR_LINE: Color = Color(1.0, 1.0, 1.0, 0.5)
const COLOR_FILL: Color = Color(1.0, 0.95, 0.7, 0.13)
const COLOR_EDGE: Color = Color(1.0, 0.95, 0.7, 0.55)
const COLOR_END: Color = Color(1.0, 0.82, 0.3, 0.9)

var input: LocalInput
var player: Player

var _query := PhysicsRayQueryParameters2D.new()
var _shape: Dictionary = {}


func _init() -> void:
	z_index = Z
	_query.collision_mask = Constants.LAYER_WALLS


func _process(_delta: float) -> void:
	var aim: Vector2 = input.guide_aim() if input != null else Vector2.ZERO
	if aim == Vector2.ZERO or player == null or not is_instance_valid(player) or player.dead:
		if not _shape.is_empty():
			_shape = {}
			queue_redraw()
		return
	show_guide(aim.normalized(), input.guide_slot)


## Shape the guide for the held weapon (`slot` -1) or skill `slot` aimed along `dir`.
func show_guide(dir: Vector2, slot: int) -> void:
	var w: WeaponData = player.held_weapon().data
	_shape = weapon_shape(w) if slot < 0 else skill_shape(player.skills[slot].data, player, dir)
	_shape["dir"] = dir
	_shape["from"] = player.shot_origin(w) if slot < 0 else player.global_position
	queue_redraw()


## What a weapon's guide looks like: {reach, cone (deg), land (radius, 0 = none)}.
static func weapon_shape(w: WeaponData) -> Dictionary:
	if w.kind == WeaponData.Kind.MELEE:
		return {"reach": w.melee_range, "cone": w.melee_arc_deg, "land": 0.0}
	var cone: float = 0.0
	if w.pellets > 1 or w.spread_deg > 0.0:
		cone = w.pellet_spread_deg + w.spread_deg
	var land: float = w.splash_radius
	if land <= 0.0 and w.lob_height > 0.0:
		land = MIN_LAND_RADIUS
	return {"reach": w.projectile_range, "cone": cone if cone >= MIN_CONE_DEG else 0.0, "land": land}


## Same for a skill. Placed skills put a circle at their spot (`spot`), directional ones a line of their reach.
static func skill_shape(d: SkillData, p: Player, dir: Vector2) -> Dictionary:
	match d.kind:
		SkillData.Kind.STORM, SkillData.Kind.RAIN:
			return {"spot": p.storm_spot(dir, d), "land": d.storm_radius}
		SkillData.Kind.ERUPTION:
			return {"spot": p.eruption_spot(dir, d),
				"land": d.eruption_blast.splash_radius if d.eruption_blast != null else MIN_LAND_RADIUS}
		SkillData.Kind.THUNDER, SkillData.Kind.QUAKE:
			return {"spot": p.spot_ahead(dir, d.thunder_distance, d.thunder_wall_margin),
				"land": d.thunder_blast.splash_radius if d.thunder_blast != null else MIN_LAND_RADIUS}
		SkillData.Kind.HOUND:
			return {"spot": p.hound_spot(dir, d), "land": d.hound_bite_radius}
		SkillData.Kind.GUST:
			return {"reach": d.gust_range, "cone": d.gust_half_angle_deg * 2.0, "land": 0.0}
		SkillData.Kind.VOLLEY, SkillData.Kind.SNARE:
			if d.volley_weapon != null:
				return weapon_shape(d.volley_weapon)
		SkillData.Kind.LIGHTNING:
			if d.beam_weapon != null:
				return {"reach": d.beam_weapon.projectile_range, "cone": 0.0, "land": 0.0}
		SkillData.Kind.DASH:
			return {"reach": d.dash_speed * d.duration, "cone": 0.0, "land": 0.0}
		SkillData.Kind.GRAPPLE:
			return {"reach": d.grapple_range, "cone": 0.0, "land": 0.0}
		SkillData.Kind.SWING:
			return {"reach": d.swing_range, "cone": 0.0, "land": 0.0}
		SkillData.Kind.TRAIL:
			return {"reach": d.trail_distance, "cone": 0.0, "land": 0.0}
		SkillData.Kind.PILLAR:
			return {"reach": d.pillar_length, "cone": 0.0, "land": 0.0, "width": d.pillar_width}
		SkillData.Kind.BIND:
			return {"reach": d.bind_range, "cone": 0.0, "land": 0.0}
	return {"reach": GENERIC_REACH, "cone": 0.0, "land": 0.0}


## Distance along `dir` from `from` to the first wall, at most `reach`.
func _clipped(from: Vector2, dir: Vector2, reach: float) -> float:
	_query.from = from
	_query.to = from + dir * reach
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(_query)
	return reach if hit.is_empty() else from.distance_to(hit.position)


func _draw() -> void:
	if _shape.is_empty():
		return
	var from: Vector2 = _shape["from"]
	var dir: Vector2 = _shape["dir"]
	if _shape.has("spot"):  # a placed skill: a strip to the spot, the circle on it
		var spot: Vector2 = _shape["spot"]
		_dashes(from, spot, DASH_WIDTH)
		_circle(spot, float(_shape["land"]))
		return
	var reach: float = float(_shape["reach"])
	var cone: float = float(_shape["cone"])
	var land: float = float(_shape["land"])
	var end: float = _clipped(from, dir, reach)
	if cone > 0.0:
		var pts := PackedVector2Array([from])
		for i: int in CONE_RAYS:
			var d: Vector2 = dir.rotated(deg_to_rad(cone) * (float(i) / (CONE_RAYS - 1) - 0.5))
			pts.append(from + d * _clipped(from, d, reach))
		draw_colored_polygon(pts, COLOR_FILL)
		_dashes(from, pts[1], DASH_WIDTH * 0.75, COLOR_EDGE)
		_dashes(from, pts[pts.size() - 1], DASH_WIDTH * 0.75, COLOR_EDGE)
	if cone <= 0.0 or land > 0.0:
		_dashes(from, from + dir * end, float(_shape.get("width", DASH_WIDTH)))
	if land > 0.0:
		_circle(from + dir * end, land)
	elif cone <= 0.0:
		draw_circle(from + dir * end, DASH_WIDTH, COLOR_END)


## A strip of square pixels from `a` to `b`.
func _dashes(a: Vector2, b: Vector2, width: float, color: Color = COLOR_LINE) -> void:
	var length: float = a.distance_to(b)
	if length < 1.0:
		return
	draw_set_transform(a, (b - a).angle())
	var t: float = DASH_GAP
	while t < length:
		draw_rect(Rect2(t, -width * 0.5, minf(DASH_LEN, length - t), width), color)
		t += DASH_LEN + DASH_GAP
	draw_set_transform(Vector2.ZERO)


func _circle(c: Vector2, r: float) -> void:
	var px: float = Constants.SPRITE_SCALE
	PixelShapes.disc(self, c, r, r, COLOR_FILL, px)
	PixelShapes.ring(self, c, r, r, DASH_WIDTH * 0.75, COLOR_EDGE, px)
	PixelShapes.disc(self, c, DASH_WIDTH, DASH_WIDTH, COLOR_END, px)
