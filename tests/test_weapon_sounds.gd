extends GutTest
## The five newer shared weapons each fire their own synth sound; impacts and bursts have their own too.

const FIRE: Dictionary[StringName, StringName] = {
	&"confetti_popper": &"confetti_pop", &"cactus_cannon": &"cactus_thoomp", &"disc_launcher": &"disc_whirr",
	&"yoyo": &"yoyo_out", &"storm_jar": &"jar_clink",
}
const MAX_LEN: float = 0.35
const MAX_PEAK: float = 0.6


func test_each_weapon_fires_its_own_recipe() -> void:
	var catalog := WeaponCatalog.load_all()
	var seen: Dictionary = {}
	for id: StringName in FIRE:
		var w: WeaponData = catalog.get_weapon(id)
		assert_eq(w.sfx, FIRE[id], "%s fire sound" % id)
		assert_true(Sfx.RECIPES.has(w.sfx), "%s recipe exists" % id)
		assert_false(seen.has(w.sfx), "own sound")
		seen[w.sfx] = true


func test_follow_ups_impacts_and_bursts_resolve_to_recipes() -> void:
	for first: StringName in Sfx.FOLLOW_UPS:
		assert_true(Sfx.RECIPES.has(first) and Sfx.RECIPES.has(Sfx.FOLLOW_UPS[first][0]), str(first))
	assert_eq(Sfx.impact_sound(&"confetti_popper"), &"confetti_rustle")
	assert_eq(Sfx.impact_sound(&"pistol"), &"")
	assert_eq(Sfx.burst_sound(load("res://assets/fx/cactus_pop.png")), &"cactus_prickle")
	assert_eq(Sfx.burst_sound(load("res://assets/fx/jar_shatter.png")), &"jar_shatter")
	assert_eq(Sfx.burst_sound(null), &"")
	assert_eq(Sfx.FOLLOW_UPS[&"yoyo_out"][0], &"yoyo_back")
	assert_lt(Sfx.FOLLOW_UPS[&"yoyo_out"][1], 0.0, "the yo-yo's delay comes from its range / speed, not a constant")
	var yo: WeaponData = WeaponCatalog.load_all().get_weapon(&"yoyo")
	assert_almost_eq(yo.projectile_range / yo.projectile_speed, 0.52, 0.01)


func test_new_recipes_are_short_and_not_loud() -> void:
	var names: Array = FIRE.values() + [&"confetti_rustle", &"cactus_prickle", &"yoyo_back", &"jar_shatter", &"jar_crackle"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for n: StringName in names:
		var wav: AudioStreamWAV = Sfx.synthesize(Sfx.RECIPES[n], rng)
		assert_lte(wav.get_length(), MAX_LEN, "%s length" % n)
		var peak: float = 0.0
		for i: int in wav.data.size() / 2:
			peak = maxf(peak, absf(wav.data.decode_s16(i * 2) / 32768.0))
		assert_between(peak, 0.05, MAX_PEAK, "%s peak %.2f" % [n, peak])
