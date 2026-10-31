class_name SkillData
extends Resource
## Data-driven skill. One .tres per skill in res://data/skills/. Every player has the shared
## Dash (`special = false`) plus one special picked in the loading room. Like weapons, who may
## pick a special is decided by tags (CharacterData.weapon_tags); a character's own id as the
## only tag makes it that character's signature.

## DASH: burst of speed with i-frames. SHIELD: a barrier in front that blocks enemy shots.
## TRANSFORM: a stronger form for a while
## (own sprite sheet, damage taken scaled, own weapon instead of the loadout, speed scaled).
## SMOKE: a cloud where you stand; inside it
## enemy auto-aim and bots can't lock on. VOLLEY: fires `volley_weapon` once (e.g. a ring of
## kunai). CLONES: decoys run out from where you stand; harmless, but auto-aim and bots go for them.
## WARD: a ring round you that moves with you and catches enemy projectiles (not beams or melee).
## GRAPPLE: a kunai on a chain thrown along the aim; if it bites a wall you're pulled straight to it.
## SWING: swing on a vine along the aim to the farthest free floor in range, over walls and crates.
## ERUPTION: marks a spot on the floor ahead along the aim (short of walls); when `duration` (the telegraph) runs out,
## `eruption_blast` goes off there.
## SNARE: fires `volley_weapon` once (a single projectile); whoever it hits is slowed (WeaponData.snare_*).
## WHIRL: spins a staff round you for `duration`: enemies within `whirl_radius` take damage every `whirl_interval`,
## enemy projectiles touching the spin are sent back, you move slower and can't fire.
## TRAIL: dash along the aim (stopped by walls) leaving a burning trail on the floor for the rest of `duration`.
## DRIFT: dissolve into petals and glide (faster, steerable, walls still stop you), untargetable and unhittable, can't fire.
## PILLAR: plants the staff, which shoots out along the aim (stopped by walls) and, after `pillar_windup`, slams down
## on that line: everyone along it takes damage and is thrown sideways.
## Values are stored in data/skills/*.tres, so they're explicit (3 was Blink, removed).
enum Kind { DASH, SHIELD, TRANSFORM, SMOKE = 4, VOLLEY = 5, CLONES = 6, SWING = 7, GRAPPLE = 8, ERUPTION = 9, WARD = 10, WHIRL = 11, TRAIL = 12, SNARE = 13, PILLAR = 14, DRIFT = 15 }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.DASH
## Pickable in the loading room's special slot (false for the shared Dash).
@export var special: bool = true
@export var tags: Array[StringName] = []
@export var cooldown: float = 2.0
## How long it stays active (dash burst, barrier up, transformation).
@export var duration: float = 0.2
## UI icon (assets/ui/icon_*.png).
@export var icon: Texture2D
## Shown on the loading-room card.
@export var blurb: String = ""

@export_group("Dash")
@export var dash_speed: float = 950.0
@export var dash_iframes: float = 0.22

@export_group("Shield")
## Length of the deployed barrier and how far in front of the player it appears.
@export var shield_width: float = 110.0
@export var shield_distance: float = 44.0

@export_group("Grapple")
## How far the kunai flies, how fast the chain pulls you, and how long it takes to bite before the pull starts.
@export var grapple_range: float = 420.0
@export var grapple_speed: float = 1100.0
@export var grapple_bite_time: float = 0.08
## Cooldown charged instead of `cooldown` when the kunai hits nothing.
@export var grapple_miss_cooldown: float = 1.5


@export_group("Swing")
## Lands on the farthest free floor along the aim up to swing_range; nothing past swing_min_range = no swing
## (and no cooldown). Takes `duration` in the air; i-frames only at takeoff.
@export var swing_range: float = 360.0
@export var swing_min_range: float = 80.0
@export var swing_iframes: float = 0.15

@export_group("Smoke")
@export var smoke_radius: float = 90.0

@export_group("Ward")
## Enemy projectiles crossing into this radius round the player are caught.
@export var ward_radius: float = 70.0

@export_group("Whirl")
@export var whirl_radius: float = 70.0
@export var whirl_damage: int = 8
## Seconds between damage ticks (the first lands on the press).
@export var whirl_interval: float = 0.25
## Push outward from him per tick.
@export var whirl_knockback: float = 120.0
@export var whirl_speed_scale: float = 0.75

@export_group("Volley")
@export var volley_weapon: WeaponData

@export_group("Clones")
@export var clone_count: int = 3
@export var clone_speed: float = 220.0
## How far clones run out before milling about.
@export var clone_reach: float = 260.0
## Angle between neighbouring clones' paths.
@export var clone_spread_deg: float = 55.0

@export_group("Eruption")
## How far ahead along the aim the spot is marked.
@export var eruption_distance: float = 260.0
## A wall in the way pulls the spot back this far off it, so the blast's sight lines start in the open.
@export var eruption_wall_margin: float = 8.0
## The pillar of fire: a `blast` weapon (damage, splash radius + falloff, knockback).
@export var eruption_blast: WeaponData

@export_group("Drift")
## Move speed multiplier while drifting (i-frames last the whole `duration`).
@export var drift_speed_scale: float = 1.6


@export_group("Pillar")
## Line length and width; `duration` is the whole animation, the slam lands `pillar_windup` after the press (he can't move until then).
@export var pillar_length: float = 320.0
@export var pillar_width: float = 36.0
@export var pillar_windup: float = 0.25
@export var pillar_damage: int = 30
## Push away from the line (sideways).
@export var pillar_knockback: float = 260.0

@export_group("Trail")
## The dash covers up to trail_distance in trail_dash_time; the trail (takeoff -> where he stopped) burns until `duration` ends.
@export var trail_distance: float = 300.0
@export var trail_dash_time: float = 0.3
## Enemies within trail_radius of the trail take trail_damage every trail_tick seconds.
@export var trail_radius: float = 22.0
@export var trail_damage: int = 6
@export var trail_tick: float = 0.3

@export_group("Transform")
## Sheet laid out like a character's (idle, hit, walk); drawn `form_scale` x the usual size.
@export var form_sprite_sheet: Texture2D
@export var form_scale: float = 1.0
## Optional strip of square frames played as the form takes over, and backwards when it ends
## (SpecialFx), at the normal sprite scale (growth to form_scale is drawn into it). The real sprite is
## hidden meanwhile.
@export var form_morph: Texture2D
## Fired instead of the loadout while transformed (its cooldown lives on the skill).
@export var form_weapon: WeaponData
## Incoming damage is multiplied by this while transformed.
@export_range(0.0, 1.0) var form_damage_scale: float = 1.0
@export var form_speed_scale: float = 1.0

var _form_frames: SpriteFrames


func form_frames() -> SpriteFrames:
	if _form_frames == null and form_sprite_sheet != null:
		_form_frames = CharacterData.frames_from_sheet(form_sprite_sheet)
	return _form_frames
