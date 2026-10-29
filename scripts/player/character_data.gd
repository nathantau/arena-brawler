class_name CharacterData
extends Resource
## Data-driven character definition. One .tres per character in res://data/characters/.

enum SkillKind { DASH, SHIELD, DUAL_WIELD }

@export var id: StringName = &""
@export var display_name: String = ""
@export var skill_name: String = ""
@export var max_hp: int = 100
@export var max_armor: int = 50
@export var max_energy: int = 200
@export var move_speed: float = 270.0
@export var skill: SkillKind = SkillKind.DASH
@export var skill_cooldown: float = 1.8
## How long the skill stays active (dash burst, shield up, dual-wield window).
@export var skill_duration: float = 0.16

@export_group("Dash")
@export var dash_speed: float = 950.0
@export var dash_iframes: float = 0.22

@export_group("Shield")
## Length of the deployed barrier and how far in front of the player it appears.
@export var shield_width: float = 110.0
@export var shield_distance: float = 44.0

@export_group("Dual wield")
## Sideways offset of each gun's muzzle while dual-wielding.
@export var dual_offset: float = 9.0
