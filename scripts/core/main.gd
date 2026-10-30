class_name Main
extends Node
## Entry point. Picks a role from the command line (server / client / offline) or shows
## the menu. The NetSession child must exist at /root/Main/Session on every peer.

var session: NetSession
var args: CmdArgs

var _offline_arena: Arena
var _server_arena: Arena
var _menu: MainMenu


func _ready() -> void:
	InputSetup.ensure_actions()
	session = NetSession.new()
	session.name = "Session"
	add_child(session)
	session.client_disconnected.connect(_on_client_disconnected)

	args = CmdArgs.parse(OS.get_cmdline_user_args())
	if args.server:
		_start_server()
	elif args.connect_host != "":
		_join(args.connect_host, args.connect_port)
	elif args.offline:
		_start_offline()
	else:
		_show_menu("")


func _start_server() -> void:
	Engine.max_fps = Constants.SERVER_MAX_FPS
	_server_arena = Arena.new(Arena.Mode.SERVER, randi(), args.match_mode, args.time_limit)
	_server_arena.match_state.arena_index = args.arena_index
	add_child(_server_arena)
	var err: Error = session.start_server(_server_arena, args.port, args.bots, args.net_debug)
	if err != OK:
		push_error("[server] failed to listen on port %d: %s" % [args.port, error_string(err)])
		get_tree().quit(1)


func _start_offline() -> void:
	_hide_menu()
	if _offline_arena != null:
		_offline_arena.queue_free()
	_offline_arena = Arena.new(Arena.Mode.OFFLINE, Constants.DEFAULT_MATCH_SEED, args.match_mode, args.time_limit)
	_offline_arena.match_state.arena_index = args.arena_index
	add_child(_offline_arena)
	var input := LocalInput.new()
	input.autopilot = args.autopilot
	var me: Player = _offline_arena.add_player(1, 0, Arena.DEFAULT_LOADOUT, input)
	_offline_arena.attach_local_view(me, input)
	for i: int in Constants.BOT_COUNT:
		_offline_arena.add_bot(Constants.BOT_ID_BASE + i, _offline_arena.free_color_index())
	if args.character != &"":
		_offline_arena.select_character(me, args.character)
	if args.weapon != &"":
		_offline_arena.select_weapon(me, args.weapon)
	if args.autopilot:
		_offline_arena.referee.set_ready(me.player_id, true)


func _join(host: String, port: int) -> void:
	var err: Error = session.start_client(self, host, port, args.autopilot, args.net_debug, args.character,
		args.weapon)
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
	if _menu == null:
		_menu = MainMenu.new()
		_menu.offline_pressed.connect(_start_offline)
		_menu.join_pressed.connect(func(address: String) -> void:
			var addr: Array = CmdArgs.parse_address(address)
			_join(addr[0], addr[1]))
		add_child(_menu)
	_menu.visible = true
	_menu.set_status(status)


func _hide_menu() -> void:
	if _menu != null:
		_menu.visible = false
