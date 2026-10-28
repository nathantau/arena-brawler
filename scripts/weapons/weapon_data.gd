class_name WeaponData
extends Resource
## Data-driven weapon definition. One .tres per weapon in res://data/weapons/.

@export var id: StringName = &""
@export var display_name: String = ""
@export var damage: int = 10
## Seconds between shots (1 / fire rate).
@export var fire_interval: float = 0.25
## Total random cone (degrees) applied to each pellet.
@export var spread_deg: float = 0.0
@export var pellets: int = 1
## Even fan (degrees) that pellets are distributed across.
@export var pellet_spread_deg: float = 0.0
@export var projectile_speed: float = 900.0
@export var projectile_range: float = 700.0
@export var projectile_radius: float = 4.0
@export var energy_cost: int = 0
@export_range(0.0, 1.0) var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export var knockback: float = 0.0
@export var color: Color = Color.WHITE
