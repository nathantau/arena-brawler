class_name LanAddress
extends RefCounted
## Picks the address a friend on the same Wi-Fi should type to join this device.


## True for private IPv4 ranges: 192.168/16, 10/8, 172.16-31/12. Loopback and link-local are not.
static func is_private_ipv4(address: String) -> bool:
	var parts: PackedStringArray = address.split(".")
	if parts.size() != 4:
		return false
	var octets: Array[int] = []
	for part: String in parts:
		if not part.is_valid_int():
			return false
		var n: int = part.to_int()
		if n < 0 or n > 255:
			return false
		octets.append(n)
	return octets[0] == 10 or (octets[0] == 192 and octets[1] == 168) \
		or (octets[0] == 172 and octets[1] >= 16 and octets[1] <= 31)


## First private IPv4 in the list, or "" if none.
static func pick(addresses: PackedStringArray) -> String:
	for a: String in addresses:
		if is_private_ipv4(a):
			return a
	return ""


## This device's LAN address, or "" when not on a network.
static func local() -> String:
	return pick(IP.get_local_addresses())


const LAST_JOIN_PATH: String = "user://last_join.cfg"


## "192.168.1.42:7777" -> "192.168.1.42" (default port hidden); other ports stay.
static func friendly(host_address: String) -> String:
	var suffix: String = ":%d" % Constants.DEFAULT_PORT
	return host_address.trim_suffix(suffix)


## "192.168.1.42" -> "192.168.1." (what a friend on the same Wi-Fi shares); "" if not an IPv4.
static func subnet_prefix(address: String) -> String:
	var parts: PackedStringArray = address.split(".")
	if parts.size() != 4:
		return ""
	return "%s.%s.%s." % [parts[0], parts[1], parts[2]]


## What the join field starts with: the last address that worked, else this device's subnet.
static func prefill(last: String, local_address: String) -> String:
	if last.strip_edges() != "":
		return last.strip_edges()
	return subnet_prefix(local_address)


static func load_last(path: String = LAST_JOIN_PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return ""
	return str(cfg.get_value("join", "address", ""))


static func save_last(address: String, path: String = LAST_JOIN_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("join", "address", address.strip_edges())
	if cfg.save(path) != OK:
		push_warning("Could not save last join address")
