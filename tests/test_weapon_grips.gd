extends GutTest
## A held weapon is drawn with its art pixel Player.WEAPON_GRIP on the hand, so the art must be
## opaque around that pixel or the hand shows through / the gun floats.

const MIN_OPAQUE: int = 20  # of the 5x5 square around the grip pixel


func test_every_held_weapon_covers_the_hand() -> void:
	var grip := Vector2i(Player.WEAPON_GRIP)
	var checked: int = 0
	for file: String in ResourceLoader.list_directory(WeaponCatalog.WEAPON_DIR):
		var w := load(WeaponCatalog.WEAPON_DIR + file) as WeaponData
		if w == null or not w.held_art or w.sprite == null:
			continue
		if w.upright:
			continue  # Ember Palm: a fireball floating over the palm by design (drawn from held_frames)
		if w.tether:
			continue  # the yo-yo is only a finger ring at the grip: the hand is meant to show through
		var img: Image = w.sprite.get_image()
		var opaque: int = 0
		for y: int in range(grip.y - 2, grip.y + 3):
			for x: int in range(grip.x - 2, grip.x + 3):
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_gte(opaque, MIN_OPAQUE, "%s: only %d/25 opaque pixels around the grip" % [w.id, opaque])
		checked += 1
	assert_gt(checked, 20, "checked the whole weapon set")
