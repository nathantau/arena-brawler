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
## Bullet art (tools/sprites/generate.py PROJECTILES): a 2-frame strip of square frames pointing
## right, rotated to the flight direction. Null = a plain circle of `color`.
@export var projectile_sprite: Texture2D
## Where the second hand holds it (sprite px, like Player.WEAPON_GRIP); zero = one-handed.
@export var off_hand: Vector2 = Vector2.ZERO
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

@export_group("Bounce")
## Wall bounces before the projectile stops. Bouncing projectiles explode on players or
## when their fuse (range / speed) runs out.
@export var bounces: int = 0
## Speed kept after each bounce.
@export_range(0.0, 1.0) var bounce_damping: float = 0.7
## Exponential slow-down per second (rolling grenades).
@export var drag: float = 0.0

@export_group("Melee")
@export var melee_range: float = 64.0
@export var melee_arc_deg: float = 120.0
## Swinging sends enemy projectiles inside the arc back the way you face.
@export var reflects: bool = false
## Animate (and draw the hit) as a straight stab instead of a sweep.
@export var thrust: bool = false
## With splash_radius > 0 a melee hit is a slam: one blast at the tip of the reach instead of the arc.
