class_name CmdArgs
extends RefCounted
## User args (after `--`):
##   --server [--port N] [--bots N]   headless authoritative server
##   --connect host[:port]            join a server directly
##   --offline                        local sandbox vs bots, skip the menu
##   --autopilot                      (client) drive + fire automatically, for testing
##   --net-debug                      print net stats periodically
##   --touch                          show touch controls on desktop

var server: bool = false
var port: int = Constants.DEFAULT_PORT
var bots: int = 0
var connect_host: String = ""
var connect_port: int = Constants.DEFAULT_PORT
var offline: bool = false
var autopilot: bool = false
var net_debug: bool = false


static func parse(args: PackedStringArray) -> CmdArgs:
	var a := CmdArgs.new()
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match arg:
			"--server":
				a.server = true
			"--port":
				a.port = next.to_int()
				i += 1
			"--bots":
				a.bots = maxi(0, next.to_int())
				i += 1
			"--connect":
				var addr: Array = parse_address(next)
				a.connect_host = addr[0]
				a.connect_port = addr[1]
				i += 1
			"--offline":
				a.offline = true
			"--autopilot":
				a.autopilot = true
			"--net-debug":
				a.net_debug = true
		i += 1
	return a


## "host[:port]" -> [host, port]. Missing/invalid port falls back to DEFAULT_PORT.
static func parse_address(text: String) -> Array:
	var t: String = text.strip_edges()
	var host: String = t
	var p: int = Constants.DEFAULT_PORT
	var colon: int = t.rfind(":")
	if colon > 0:
		host = t.substr(0, colon)
		var port_text: String = t.substr(colon + 1)
		if port_text.is_valid_int() and port_text.to_int() > 0:
			p = port_text.to_int()
	return [host, p]
