extends SceneTree
## Quick bot-vs-bot behaviour check (not a balance sweep): duels between two BotBrains using each fighter's signature loadout,
## with bots allowed to hunt bots. Prints damage landed (both bots together), kills, time alive per life, path length,
## floor cells visited and time stuck (asked to move but not moving) per duel.
##   godot --path . --headless --fixed-fps 60 -s tools/bot_sim.gd -- n=8 [secs=40] [skill=0.5] [seed=1]

const CELL: float = 48.0
const STUCK_SPEED: float = 10.0

var n_duels: int = 8
var secs: float = 40.0
var skill_arg: float = -1.0
var base_seed: int = 1
var idx: int = -1
var arena: Arena
var frames: int = 0
var prev_hp: Array[int] = [0, 0]
var prev_pos: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var cells: Array[Dictionary] = [{}, {}]
var stat: Dictionary = {"dealt": 0.0, "deaths": 0.0, "path": 0.0, "cells": 0.0, "stuck": 0.0, "alive": 0.0, "duels": 0.0}
var stuck_run: Array[float] = [0.0, 0.0]
var chars: Array = []


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"n": n_duels = int(kv[1])
				"secs": secs = float(kv[1])
				"skill": skill_arg = float(kv[1])
				"seed": base_seed = int(kv[1])
	chars = CharacterCatalog.load_all().ordered.duplicate()
	physics_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if arena == null:
		if frames > 3:
			_next()
		return
	var dt: float = 1.0 / 60.0
	for k: int in 2:
		var me: Player = arena.get_player(10 + k)
		var foe: Player = arena.get_player(11 - k)
		var hp: int = me.stats.hp + me.stats.armor
		if not me.dead and prev_hp[k] > hp and prev_hp[k] < 9999 and not foe.dead:
			stat["dealt"] += prev_hp[k] - hp
		prev_hp[k] = hp
		if not me.dead:
			stat["alive"] += dt
			stat["path"] += me.global_position.distance_to(prev_pos[k])
			cells[k][Vector2i((me.global_position / CELL).floor())] = true
			var f: InputFrame = me.controller.get("_frame") as InputFrame
			var moving: bool = f != null and f.move_vec.length() > 0.3
			if moving and me.global_position.distance_to(prev_pos[k]) < STUCK_SPEED * dt:
				stuck_run[k] += dt
				if stuck_run[k] > 0.5:
					stat["stuck"] += dt
			else:
				stuck_run[k] = 0.0
		prev_pos[k] = me.global_position
	if frames >= secs * 60.0:
		_finish()


func _next() -> void:
	idx += 1
	if idx >= n_duels:
		_report()
		quit()
		return
	arena = Arena.new(Arena.Mode.OFFLINE, base_seed * 1000 + idx, MatchRules.Mode.DUEL, 999.0)
	root.add_child(arena)
	frames = 0
	for k: int in 2:
		var c: CharacterData = chars[(idx * 2 + k) % chars.size()]
		var bot := BotBrain.new(arena, base_seed * 7919 + idx * 13 + 10 + k)
		bot.set("rotates_kit", false)
		if skill_arg >= 0.0:
			bot.set("skill", skill_arg)
		var p: Player = arena.add_player(10 + k, k, bot, true)
		p.set_character(c)
		p.set_weapon(arena.catalog.get_weapon(c.signature_weapon.id if c.signature_weapon != null else &"pistol"))
		cells[k] = {}
		stuck_run[k] = 0.0
	arena.kill_registered.connect(func(_killer: int, _victim: int) -> void:
		stat["deaths"] += 1.0)
	prev_hp = [9999, 9999]
	var st: MatchState = arena.match_state
	st.participants = [10, 11]
	st.phase = MatchState.Phase.PLAYING
	st.time_left = 999.0
	arena._place_participants()
	for p: Player in arena.players:
		p.frozen = false
		p.stats.invulnerable_time = 0.0
		prev_pos[p.player_id - 10] = p.global_position


func _finish() -> void:
	stat["duels"] += 1.0
	stat["cells"] += (cells[0].size() + cells[1].size()) * 0.5
	arena.queue_free()
	arena = null
	frames = 0


func _report() -> void:
	var d: float = stat["duels"]
	print("duels=%d secs=%.0f dmg_landed/duel=%.0f kills/duel=%.1f secs_per_life=%.1f path_px/bot/duel=%.0f cells_visited/bot=%.1f stuck_s/duel=%.2f" % [
		d, secs, stat["dealt"] / d, stat["deaths"] / d, stat["alive"] / (stat["deaths"] + 2.0 * d) , stat["path"] / d / 2.0, stat["cells"] / d, stat["stuck"] / d])
