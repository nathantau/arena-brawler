extends SceneTree
## Preview: the local fighter stands in the top-left spawn corner, under the HUD vitals block (shows the fade).
##   ... (window/size/viewport_width/height in override.cfg) --write-movie <dir>/f.png --fixed-fps 30 --quit-after 260 -s tools/hud_corner_preview.gd

var arena: Arena
var me: Player
var frames: int = 0


func _initialize() -> void:
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 2:
		var input := LocalInput.new()
		input.arena = arena
		me = arena.add_player(1, 0, input)
		arena.attach_local_view(me, input)
		arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
		arena.referee.set_ready(1, true)
	if frames == 430:
		var best: Vector2 = arena.map.spawns[0]
		for s: Vector2 in arena.map.spawns:
			if s.x + s.y < best.x + best.y:
				best = s
		me.global_position = best
		arena.camera.global_position = Arena.clamp_camera(best, arena._camera_view(), Rect2(Vector2.ZERO, arena.map.size))
		arena.camera.reset_smoothing()
