extends SceneTree
## Preview: the local player walks onto an energy pad (pickup FX + on-pad respawn timer), then dies and respawns
## (spawn protection flicker + pop). Focus-safe like the smoke test (CLAUDE.md Commands):
##   ... --resolution 2532x1170 --write-movie <dir>/f.png --fixed-fps 30 --quit-after 900 -s tools/respawn_preview.gd

const START: int = 420  ## the countdown is over by here
const DIE_AT: int = 150  ## frames after START

var arena: Arena
var me: Player
var frames: int = 0
var pad: Vector2


class Walker extends LocalInput:
	var target: Vector2 = Vector2.INF

	func get_input(p: Player, d: float) -> InputFrame:
		var f: InputFrame = super.get_input(p, d)
		f.fire = false
		f.aim_vec = Vector2.ZERO
		f.move_vec = Vector2.ZERO
		if target != Vector2.INF and p.global_position.distance_to(target) > 6.0:
			f.move_vec = (target - p.global_position).normalized()
		return f


func _initialize() -> void:
	InputSetup.ensure_actions()
	arena = Arena.new(Arena.Mode.OFFLINE)
	root.add_child(arena)
	physics_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 2:
		var input := Walker.new()
		input.arena = arena
		me = arena.add_player(1, 0, input)
		arena.attach_local_view(me, input)
		arena.add_bot(Constants.BOT_ID_BASE, arena.free_color_index())
		arena.referee.set_ready(1, true)
	if frames == START:
		for spot: Vector2 in arena.map.energy_spots:  # one well away from the HUD
			if spot.y > 200.0:
				pad = spot
				break
		me.global_position = pad + Vector2(-170, 0)
		me.stats.energy = 20
		(me.controller as Walker).target = pad
	if frames == START + DIE_AT:
		(me.controller as Walker).target = Vector2.INF
		me.stats.spawn_protect = 0.0
		me.stats.invulnerable_time = 0.0
		me.take_hit(100000, false, Vector2.ZERO, Constants.BOT_ID_BASE)
