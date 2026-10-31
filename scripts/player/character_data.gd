class_name CharacterData
extends Resource
## Data-driven character definition. One .tres per character in res://data/characters/.
## Skills live in SkillData (everyone dashes; specials are picked by tag like weapons).

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: int = 100
@export var max_armor: int = 50
@export var max_energy: int = 200
@export var move_speed: float = 270.0
## Weapon and special classes this character can use (see WeaponData.tags / SkillData.tags);
## include the character's own id.
@export var weapon_tags: Array[StringName] = []
## Starting sidearm, never dropped (slot 0). Null = the shared default loadout.
@export var signature_weapon: WeaponData
## Default special. Null = the first special the character can use.
@export var signature_skill: SkillData
## false = benched: not offered in menus, the loading room or to bots (still loadable by id, e.g. --character).
@export var in_rotation: bool = true
## Horizontal sheet from tools/sprites/generate.py: idle frames, then hit-flash frames, then walk frames.
@export var sprite_sheet: Texture2D


var _portraits: Array[AtlasTexture] = []
var _sprite_frames: SpriteFrames



func can_use(weapon: WeaponData) -> bool:
	return _shares_tag(weapon.tags)


func can_use_skill(skill: SkillData) -> bool:
	return _shares_tag(skill.tags)


## Empty `tags` = anyone.
func _shares_tag(tags: Array[StringName]) -> bool:
	if tags.is_empty():
		return true
	for tag: StringName in tags:
		if weapon_tags.has(tag):
			return true
	return false


## Menu art: idle frame `i`, cropped from its cell to the body plus a little headroom (hair, flames).
func portrait(i: int = 0) -> Texture2D:
	if _portraits.is_empty():
		var cell: int = Constants.SPRITE_CELL_SIZE
		var r: Rect2 = Constants.SPRITE_PORTRAIT_RECT
		for k: int in Constants.SPRITE_IDLE_FRAMES:
			var t := AtlasTexture.new()
			t.atlas = sprite_sheet
			t.region = Rect2(r.position + Vector2(k * cell, 0), r.size)
			_portraits.append(t)
	return _portraits[i % _portraits.size()]


## "idle" (looping bob) + "hit" (one-shot flash) + "walk" (looping) + "die" (+ optional "attack") animations cut from
## sprite_sheet (whole cells, so art above the body box shows); built once, shared.
func sprite_frames() -> SpriteFrames:
	if _sprite_frames == null:
		_sprite_frames = frames_from_sheet(sprite_sheet)
	return _sprite_frames


static func frames_from_sheet(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, sheet, &"idle", 0, Constants.SPRITE_IDLE_FRAMES, Constants.SPRITE_IDLE_FPS, true)
	_add_animation(frames, sheet, &"hit", Constants.SPRITE_IDLE_FRAMES, Constants.SPRITE_HIT_FRAMES,
		Constants.SPRITE_HIT_FRAMES / Constants.HIT_FLASH_TIME, false)
	_add_animation(frames, sheet, &"walk", Constants.SPRITE_IDLE_FRAMES + Constants.SPRITE_HIT_FRAMES,
		Constants.SPRITE_WALK_FRAMES, Constants.SPRITE_WALK_FPS, true)
	_add_animation(frames, sheet, &"die", Constants.SPRITE_IDLE_FRAMES + Constants.SPRITE_HIT_FRAMES
		+ Constants.SPRITE_WALK_FRAMES, Constants.SPRITE_DIE_FRAMES, Constants.SPRITE_DIE_FPS, false)
	var attack_at: int = Constants.SPRITE_IDLE_FRAMES + Constants.SPRITE_HIT_FRAMES + Constants.SPRITE_WALK_FRAMES \
		+ Constants.SPRITE_DIE_FRAMES
	if sheet.get_width() >= (attack_at + Constants.SPRITE_ATTACK_FRAMES) * Constants.SPRITE_CELL_SIZE:
		_add_animation(frames, sheet, &"attack", attack_at, Constants.SPRITE_ATTACK_FRAMES,
			Constants.SPRITE_ATTACK_FPS, false)
	return frames


static func _add_animation(frames: SpriteFrames, sheet: Texture2D, anim: StringName, first: int, count: int,
		fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var size: int = Constants.SPRITE_CELL_SIZE
	for i: int in count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2((first + i) * size, 0, size, size)
		frames.add_frame(anim, frame)
