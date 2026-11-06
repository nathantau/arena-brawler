extends SceneTree
## Preview: the drag-aim guide in the arena (straight gun, cone, lobbed circle, a dragged special) and the touch knob, as PNGs.
## Needs a window; run without stealing focus (override.cfg as in CLAUDE.md Commands, plus viewport_width=2532 /
## viewport_height=1170 for a phone-shaped shot):
##   open -g -W -n -a /Applications/Godot.app --args --path "$PWD" --log-file /tmp/aim.log -s tools/aim_guide_preview.gd \
##       -- --touch out=/tmp/aim_preview
## Writes <out>/aim_<name>.png. Never touches the real settings or profile.

var out: String = "/tmp/aim_preview"
var arena: Arena
var me: Player
var input: LocalInput
var frames: int = 0
var step: int = 0

## name, weapon id, skill slot (-1 = attack button), skill id, drag vector
const SHOTS: Array = [
	["straight", &"pistol", -1, &"", Vector2(1, -0.35)],
	["cone", &"shotgun", -1, &"", Vector2(1, 0.2)],
	["lob", &"cactus_cannon", -1, &"", Vector2(1, -0.1)],
	["special", &"pistol", 1, &"storm_cloud", Vector2(1, 0.25)],
]


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_actions()
	PlayerProfile.path = "user://aim_preview.cfg"
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 2:
		input = LocalInput.new()
		input.arena = arena
		me = arena.add_player(1, 0, input)
		arena.attach_local_view(me, input)
		arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
		arena.referee.set_ready(1, true)
		input.touch.visible = true
	if frames == 120:
		var c: Vector2 = arena.map.size * 0.5
		me.global_position = c
		for p: Player in arena.players:
			if p != me:
				p.global_position = c + Vector2(-1500, 0)  # parked far away so only the guide is on show
		arena.camera.global_position = c + Vector2(110, 0)
		arena.camera.reset_smoothing()
	if frames >= 130 and (frames - 130) % 20 == 0 and step < SHOTS.size() * 2:
		_shoot()


func _shoot() -> void:
	var tc: TouchControls = input.touch
	var i: int = step / 2
	var s: Array = SHOTS[i]
	if step % 2 == 0:
		tc.release_all()
		me.weapon = WeaponState.new(WeaponCatalog.load_all().get_weapon(s[1]))
		var drag: Vector2 = (s[4] as Vector2).normalized() * 60.0
		if s[2] < 0:
			tc._on_press(0, tc._attack_center())
			tc._on_drag(0, tc._attack_center() + drag)
		else:
			me.skills[s[2]] = CharacterSkill.new(SkillCatalog.shared().get_skill(s[3]))
			tc._on_press(0, tc._slot_center(s[2]))
			tc._on_drag(0, tc._slot_center(s[2]) + drag)
	else:
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png("%s/aim_%s.png" % [out, s[0]])
		if i == 0:  # the knob on the fire button: a crop of the bottom-right controls
			img.get_region(Rect2i(img.get_width() - 760, img.get_height() - 560, 760, 560)).save_png("%s/aim_touch.png" % out)
		if i == SHOTS.size() - 1:
			quit()
	step += 1
