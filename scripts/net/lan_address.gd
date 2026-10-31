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
