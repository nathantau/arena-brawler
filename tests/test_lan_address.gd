extends GutTest


func test_private_ranges() -> void:
	for a: String in ["192.168.1.42", "10.0.0.5", "172.16.0.1", "172.31.255.1"]:
		assert_true(LanAddress.is_private_ipv4(a), a)


func test_rejects_other_addresses() -> void:
	for a: String in ["127.0.0.1", "169.254.3.4", "172.15.0.1", "172.32.0.1", "8.8.8.8", "fe80::1", "::1", "192.168.1", "192.168.1.999", "a.b.c.d", ""]:
		assert_false(LanAddress.is_private_ipv4(a), a)


func test_pick_skips_loopback_linklocal_and_v6() -> void:
	var list := PackedStringArray(["::1", "fe80::abcd", "127.0.0.1", "169.254.9.9", "192.168.1.42", "10.0.0.2"])
	assert_eq(LanAddress.pick(list), "192.168.1.42")


func test_pick_none() -> void:
	assert_eq(LanAddress.pick(PackedStringArray(["127.0.0.1", "::1"])), "")


func test_friendly_hides_default_port_only() -> void:
	assert_eq(LanAddress.friendly("192.168.1.42:7777"), "192.168.1.42")
	assert_eq(LanAddress.friendly("192.168.1.42:9000"), "192.168.1.42:9000")


func test_subnet_prefix() -> void:
	assert_eq(LanAddress.subnet_prefix("192.168.1.42"), "192.168.1.")
	assert_eq(LanAddress.subnet_prefix(""), "")


func test_prefill_prefers_last_then_subnet() -> void:
	assert_eq(LanAddress.prefill("10.0.0.7", "192.168.1.42"), "10.0.0.7")
	assert_eq(LanAddress.prefill("", "192.168.1.42"), "192.168.1.")
	assert_eq(LanAddress.prefill("", ""), "")


func test_last_join_roundtrip_and_missing() -> void:
	var path: String = "user://test_last_join.cfg"
	assert_eq(LanAddress.load_last("user://does_not_exist.cfg"), "")
	LanAddress.save_last(" 192.168.1.9 ", path)
	assert_eq(LanAddress.load_last(path), "192.168.1.9")
	DirAccess.remove_absolute(path)


func test_parse_address_port_optional() -> void:
	assert_eq(CmdArgs.parse_address("192.168.1.9"), ["192.168.1.9", Constants.DEFAULT_PORT])
	assert_eq(CmdArgs.parse_address("192.168.1.9:9000"), ["192.168.1.9", 9000])
