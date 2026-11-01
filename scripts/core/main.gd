class_name Main
extends Node
## Entry point. Picks a role from the command line (server / client / offline) or shows
## the menu. The NetSession child must exist at /root/Main/Session on every peer.

var session: NetSession
var args: CmdArgs

var _offline_arena: Arena
var _server_arena: Arena
var _menu: MainMenu
## Picks the default arena of a new lobby (the server / offline host decides; clients just show it).
var _arena_rng := RandomNumberGenerator.new()


func _ready() -> void:
	InputSetup.ensure_actions()
	UiStyle.install()
	session = NetSession.new()
	session.name = "Session"
	add_child(session)
	session.client_disconnected.connect(_on_client_disconnected)

	GameSettings.ensure_loaded()
	if DisplayServer.get_name() != "headless":
		_add_audio()

	args = CmdArgs.parse(OS.get_cmdline_user_args())
	# Render at the sim rate: on 120 Hz phones, frames between sim ticks made moving sprites judder.
	Engine.max_fps = Constants.PHYSICS_FPS
	if args.server:
		_start_server()
	elif args.host:
		_start_host()
	elif args.connect_host != "":
		_join(args.connect_host, args.connect_port)
	elif args.offline:
		_start_offline()
	else:
		_show_menu("")


## Menu music + a click on every button (including ones built later, via node_added). Both keep working while paused.
func _add_audio() -> void:
	add_child(Music.new())
	var ui_sfx := Sfx.new()
	ui_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_sfx)
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is BaseButton:
			(n as BaseButton).pressed.connect(func() -> void: ui_sfx.play(&"ui_click")))


## Backgrounding the app (home button, call, lock) pauses an offline match instead of letting bots keep fighting.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED and what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	if _offline_arena == null or not is_instance_valid(_offline_arena):
		return
	for pm: Node in _offline_arena.find_children("*", "PauseMenu", true, false):
		if (pm as PauseMenu).button.visible:
			(pm as PauseMenu).open()


func _start_server() -> void:
	_arena_rng.randomize()
	Engine.max_fps = Constants.SERVER_MAX_FPS
	_server_arena = Arena.new(Arena.Mode.SERVER, randi(), args.match_mode, args.time_limit)
	_server_arena.match_state.arena_index = args.pick_arena(_arena_rng)
	add_child(_server_arena)
	var err: Error = session.start_server(_server_arena, args.port, args.bots, args.net_debug)
	if err != OK:
		push_error("[server] failed to listen on port %d: %s" % [args.port, error_string(err)])
		get_tree().quit(1)


## Listen server: the same NetServer as `--server`, plus this device plays as peer 1 (the
## server's own id, so it never clashes with a client) through a local view, like offline.
func _start_host() -> void:
	_arena_rng.randomize()
	_hide_menu()
	_server_arena = Arena.new(Arena.Mode.SERVER, randi(), args.match_mode, args.time_limit)
	_server_arena.match_state.arena_index = args.pick_arena(_arena_rng)
	add_child(_server_arena)
	var err: Error = session.start_server(_server_arena, args.port, args.bots, args.net_debug)
	if err != OK:
		_server_arena.queue_free()
		_server_arena = null
		_show_menu("Could not host on port %d: %s" % [args.port, error_string(err)])
		return
	var ip: String = LanAddress.local()
	_server_arena.host_address = "%s:%d" % [ip if ip != "" else "(no Wi-Fi)", args.port]
	print("[host] %s" % _server_arena.host_address)
	_server_arena.leave_requested.connect(_on_host_leave, CONNECT_DEFERRED)
	var input := LocalInput.new()
	input.autopilot = args.autopilot
	var me: Player = _server_arena.add_player(NetSession.HOST_ID, _server_arena.free_color_index(), input)
	_server_arena.attach_local_view(me, input)
	if args.character != &"":
		_server_arena.select_character(me, args.character)
	if args.weapon != &"":
		_server_arena.select_weapon(me, args.weapon)
	if args.special != &"":
		_server_arena.select_special(me, 1, args.special)
	if args.autopilot:
		_server_arena.referee.set_ready(me.player_id, true)


## Leave as host: shut the server down (clients see "Disconnected from server") and go back to the menu.
func _on_host_leave(_restart: bool) -> void:
	session.stop()
	_server_arena.queue_free()
	_server_arena = null
	_show_menu("")


func _start_offline() -> void:
	_arena_rng.randomize()
	_hide_menu()
	if _offline_arena != null:
		_offline_arena.queue_free()
	_offline_arena = Arena.new(Arena.Mode.OFFLINE, Constants.DEFAULT_MATCH_SEED, args.match_mode, args.time_limit)
	_offline_arena.match_state.arena_index = args.pick_arena(_arena_rng)
	add_child(_offline_arena)
	_offline_arena.leave_requested.connect(_on_offline_leave, CONNECT_DEFERRED)
	var input := LocalInput.new()
	input.autopilot = args.autopilot
	var me: Player = _offline_arena.add_player(1, 0, input)
	_offline_arena.attach_local_view(me, input)
	for i: int in Constants.BOT_COUNT:
		_offline_arena.add_bot(Constants.BOT_ID_BASE + i, _offline_arena.free_color_index())
	if args.character != &"":
		_offline_arena.select_character(me, args.character)
	if args.weapon != &"":
		_offline_arena.select_weapon(me, args.weapon)
	if args.special != &"":
		_offline_arena.select_special(me, 1, args.special)
	if args.autopilot:
		_offline_arena.referee.set_ready(me.player_id, true)


## Pause menu: Restart keeps the character (back to the lobby), Leave returns to the main menu.
func _on_offline_leave(restart: bool) -> void:
	if restart:
		args.character = _offline_arena.local_player.character.id
		_start_offline()
		return
	_offline_arena.queue_free()
	_offline_arena = null
	_show_menu("")


func _join(host: String, port: int) -> void:
	var err: Error = session.start_client(self, host, port, args.autopilot, args.net_debug, args.character,
		args.weapon, args.special)
	if err != OK:
		_on_client_disconnected("Could not start client: %s" % error_string(err))
		return
	_hide_menu()


func _on_client_disconnected(reason: String) -> void:
	print("[client] %s" % reason)
	session.stop()
	if args.connect_host != "" and DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	_show_menu(reason)


func _show_menu(status: String) -> void:
	if _menu != null:
		ScreenFade.play(self)
	if _menu == null:
		_menu = MainMenu.new()
		_menu.offline_pressed.connect(_start_offline)
		_menu.host_pressed.connect(_start_host)
		_menu.join_pressed.connect(func(address: String) -> void:
			var addr: Array = CmdArgs.parse_address(address)
			_join(addr[0], addr[1])
			if session.client != null:
				session.multiplayer.connected_to_server.connect(
					func() -> void: LanAddress.save_last(address), CONNECT_ONE_SHOT))
		add_child(_menu)
	_menu.visible = true
	_menu.set_status(status)


func _hide_menu() -> void:
	if not args.autopilot:
		SettingsPanel.show_howto_once(self)
	if _menu != null:
		ScreenFade.play(self)
		_menu.visible = false
