extends SceneTree
## Preview: ground circles (team ring, spawn-protect ring, shadow, pickup pads, aim landing circle) zoomed up.
##   open -g -W -n -a /Applications/Godot.app --args --path "$PWD" --log-file /tmp/px.log -s tools/pixel_rings_preview.gd \
##       -- out=/tmp/pixel_rings.png
## (override.cfg no-focus setup as in CLAUDE.md Commands). Writes one PNG.

var out: String = "/tmp/pixel_rings.png"
var arena: Arena
var me: Player
var input: LocalInput
var frames: int = 0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
	InputSetup.ensure_actions()
	PlayerProfile.path = "user://pixel_rings_preview.cfg"
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
		me.team = 1
		for p: Player in arena.players:
			if p != me:
				p.global_position = c + Vector2(-1500, 0)
		arena.pickups.spots = PackedVector2Array([c + Vector2(-150, -10), c + Vector2(150, -10), c + Vector2(260, -10)])
		arena.pickups.timers = PackedFloat32Array([0.0, 6.0, 12.0])
		arena.pickups._flash = PackedFloat32Array([0.0, 0.0, 0.0])
		arena.camera.global_position = c + Vector2(60, 0)
		arena.camera.reset_smoothing()
		me.weapon = WeaponState.new(WeaponCatalog.load_all().get_weapon(&"cactus_cannon"))
		me.stats.spawn_protect = 60.0
		input.touch._on_press(0, input.touch._attack_center())
		input.touch._on_drag(0, input.touch._attack_center() + Vector2(1, -0.1).normalized() * 60.0)
	if frames == 135:
		var img: Image = root.get_viewport().get_texture().get_image()
		var w: int = img.get_width()
		var h: int = img.get_height()
		var crop: Image = img.get_region(Rect2i(w / 2 - 330, h / 2 - 150, 660, 300))
		crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(out)
		quit()
