extends GutTest


func _info() -> Dictionary:
	return {"name": "Alice", "port": 7777, "mode": MatchRules.Mode.FFA, "arena": 0, "players": 2, "max": 4, "playing": false}


func test_round_trip() -> void:
	var got: Dictionary = LanDiscovery.decode(LanDiscovery.encode(_info()))
	assert_eq(got["name"], "Alice")
	assert_eq(got["port"], 7777)
	assert_eq(got["players"], 2)
	assert_true(got["compatible"])
	assert_eq(LanDiscovery.label(got), "Alice · FFA · Pit · 2/4")


func test_playing_label() -> void:
	var i: Dictionary = _info()
	i["playing"] = true
	i["mode"] = MatchRules.Mode.DUEL
	assert_eq(LanDiscovery.label(LanDiscovery.decode(LanDiscovery.encode(i))), "Alice · Duel · Pit · 2/4 · playing")


func test_garbage_and_bad_magic_rejected() -> void:
	assert_true(LanDiscovery.decode(PackedByteArray()).is_empty())
	assert_true(LanDiscovery.decode("hello".to_utf8_buffer()).is_empty())
	assert_true(LanDiscovery.decode('{"magic":"NOPE","v":1,"port":1}'.to_utf8_buffer()).is_empty())
	assert_true(LanDiscovery.decode("[1,2]".to_utf8_buffer()).is_empty())


func test_version_mismatch_is_incompatible() -> void:
	var s: String = '{"magic":"%s","v":%d,"port":7777,"name":"Old"}' % [LanDiscovery.MAGIC, LanDiscovery.VERSION + 1]
	var got: Dictionary = LanDiscovery.decode(s.to_utf8_buffer())
	assert_false(got.is_empty())
	assert_false(got["compatible"])


func test_upsert_and_expiry() -> void:
	var t: Dictionary = {}
	LanDiscovery.upsert(t, LanDiscovery.decode(LanDiscovery.encode(_info())), "192.168.1.5", 10.0)
	LanDiscovery.upsert(t, LanDiscovery.decode(LanDiscovery.encode(_info())), "192.168.1.5", 11.0)
	assert_eq(t.size(), 1)
	assert_false(LanDiscovery.prune(t, 13.5))
	assert_true(LanDiscovery.prune(t, 14.5))
	assert_true(t.is_empty())


func test_directed_broadcast() -> void:
	assert_eq(LanDiscovery.directed_broadcast("192.168.1.42"), "192.168.1.255")
	assert_eq(LanDiscovery.directed_broadcast(""), "")
