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
## Horizontal sheet from tools/sprites/generate.py: idle frames, then hit-flash frames, then walk frames.
@export var sprite_sheet: Texture2D

var _sprite_frames: SpriteFrames

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


## "idle" (looping bob) + "hit" (one-shot flash) + "walk" (looping) animations cut from sprite_sheet; built once, shared.
func sprite_frames() -> SpriteFrames:
	if _sprite_frames != null:
		return _sprite_frames
	_sprite_frames = SpriteFrames.new()
	_sprite_frames.remove_animation(&"default")
	_add_animation(&"idle", 0, Constants.SPRITE_IDLE_FRAMES, Constants.SPRITE_IDLE_FPS, true)
	_add_animation(&"hit", Constants.SPRITE_IDLE_FRAMES, Constants.SPRITE_HIT_FRAMES,
		Constants.SPRITE_HIT_FRAMES / Constants.HIT_FLASH_TIME, false)
	_add_animation(&"walk", Constants.SPRITE_IDLE_FRAMES + Constants.SPRITE_HIT_FRAMES,
		Constants.SPRITE_WALK_FRAMES, Constants.SPRITE_WALK_FPS, true)
	return _sprite_frames


func _add_animation(anim: StringName, first: int, count: int, fps: float, loop: bool) -> void:
	_sprite_frames.add_animation(anim)
	_sprite_frames.set_animation_speed(anim, fps)
	_sprite_frames.set_animation_loop(anim, loop)
	var size: int = Constants.SPRITE_FRAME_SIZE
	for i: int in count:
		var frame := AtlasTexture.new()
		frame.atlas = sprite_sheet
		frame.region = Rect2((first + i) * size, 0, size, size)
		_sprite_frames.add_frame(anim, frame)
