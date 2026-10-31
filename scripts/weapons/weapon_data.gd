class_name WeaponData
extends Resource
## Data-driven weapon definition. One .tres per weapon in res://data/weapons/.

## PROJECTILE: pooled bullets (optionally splash / bouncing). BEAM: instant hitscan line.
## MELEE: arc hit around the wielder that can also reflect enemy projectiles.
enum Kind { PROJECTILE, BEAM, MELEE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.PROJECTILE
## Can appear on weapon pickup pads.
@export var pickup: bool = true
@export var damage: int = 10
## Seconds between shots (1 / fire rate).
@export var fire_interval: float = 0.25
## Total random cone (degrees) applied to each pellet.
@export var spread_deg: float = 0.0
@export var pellets: int = 1
## Even fan (degrees) that pellets are distributed across.
@export var pellet_spread_deg: float = 0.0
@export var projectile_speed: float = 900.0
## Travel distance (projectiles: range / speed = lifetime, i.e. a grenade's fuse). Beam length.
@export var projectile_range: float = 700.0
@export var projectile_radius: float = 4.0
@export var energy_cost: int = 0
@export_range(0.0, 1.0) var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export var knockback: float = 0.0
@export var color: Color = Color.WHITE
## Camera shake (0..1) for the shooter when firing.
@export var screen_shake: float = 0.0
## Sound id in Sfx.
@export var sfx: StringName = &"shot"
## Pixel art from tools/sprites/generate.py, pointing right, held at Player.WEAPON_GRIP.
@export var sprite: Texture2D
## Optional in-world loop (generate.py WEAPON_ANIMS): a strip of `sprite`-sized frames played instead of `sprite`
## while held; the HUD and loading room keep the still `sprite`.
@export var held_frames: Texture2D
## Drawn upright instead of turned with the aim (mirrored when facing left): an orb whose flames rise.
@export var upright: bool = false
## Bullet art (tools/sprites/generate.py PROJECTILES): a 2-frame strip of square frames pointing
## right, rotated to the flight direction. Null = a plain circle of `color`.
@export var projectile_sprite: Texture2D
## Melee: the hit lands this long after the attack starts (the attack animation winds up first); 0 = at once.
@export var windup: float = 0.0
## Barrel tip, sprite px along the barrel (x): shots spawn there. 0 = no gun art (skill volleys): just outside
## the body.
@export var muzzle_x: float = 0.0
## Drawn floating in front of the wielder; false = the character's own art is the weapon (Flint's fiery fists),
## the sprite only shows in the HUD and loading room.
@export var held_art: bool = true
## BEAM: drawn as one constant fiery beam from the hand while firing (Effects.hold_beam), not a flash per tick.
@export var held_beam: bool = false
## Who may carry it: any character sharing a tag (CharacterData.weapon_tags). Empty = everyone.
## A character's own id as the only tag makes a signature weapon.
@export var tags: Array[StringName] = []
## Projectiles pass through this many players before stopping (damaging each).
@export var pierce: int = 0

@export_group("Splash")
## > 0: explodes on impact / at end of life, damaging everyone (but the shooter) in range.
@export var splash_radius: float = 0.0
## Damage multiplier at the edge of the blast (1.0 at the centre).
@export_range(0.0, 1.0) var splash_edge_scale: float = 0.4
## Goes off right where it's fired, no flight or muzzle (a skill's blast, e.g. Flint's Eruption).
@export var blast: bool = false

@export_group("Bounce")
## Wall bounces before the projectile stops. Bouncing projectiles explode on players or
## when their fuse (range / speed) runs out.
@export var bounces: int = 0
## Speed kept after each bounce.
@export_range(0.0, 1.0) var bounce_damping: float = 0.7
## Exponential slow-down per second (rolling grenades).
@export var drag: float = 0.0
## Turn rate (rad/s) toward the nearest enemy; 0 = flies straight (Sakura's petal storm).
@export var homing: float = 0.0

@export_group("Melee")
@export var melee_range: float = 64.0
@export var melee_arc_deg: float = 120.0
## Swinging sends enemy projectiles inside the arc back the way you face.
@export var reflects: bool = false
## Animate (and draw the hit) as a straight stab instead of a sweep.
@export var thrust: bool = false
## With splash_radius > 0 a melee hit is a slam: one blast at the tip of the reach instead of the arc.


const HELD_FPS: float = 8.0


## Draws the held art with its grip at the transform's origin, looping `held_frames` when set.
func draw_held(ci: CanvasItem, grip: Vector2, tint: Color) -> void:
	if held_frames == null:
		ci.draw_texture(sprite, -grip, tint)
		return
	var size: Vector2 = sprite.get_size()
	var count: int = maxi(1, int(held_frames.get_width() / size.x))
	var frame: int = int(Time.get_ticks_msec() / 1000.0 * HELD_FPS) % count
	ci.draw_texture_rect_region(held_frames, Rect2(-grip, size), Rect2(Vector2(frame * size.x, 0.0), size), tint)


## How far along the aim shots spawn from their origin (the hand holding the gun, Player.shot_origin()).
func muzzle_distance() -> float:
	if muzzle_x <= 0.0:
		return Constants.PLAYER_RADIUS + projectile_radius + Constants.MUZZLE_OFFSET
	return (muzzle_x - Player.WEAPON_GRIP.x) * Constants.SPRITE_SCALE
