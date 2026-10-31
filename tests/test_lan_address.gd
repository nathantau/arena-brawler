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
