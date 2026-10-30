extends SceneTree
# godot --path . --write-movie <dir>/f.png --fixed-fps 30 --quit-after 30 -s tools/fx_preview.gd
# Dev preview: fires each effect side by side on a wood background, for --write-movie.
# Top: blast, slam, sword + hammer slashes. Middle: beam, sparks. Bottom: every gun's bullet,
# plain on the left half, forced crit on the right.
const BULLET_ROW_Y: float = 440.0
const BULLET_ROW_STEP: float = 28.0
const CRIT_SEQ: int = 1000

var fx: Effects
var pool: ProjectilePool
var guns: Array[WeaponData] = []
var t: float = 0.0
var fired: int = -1


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.69, 0.44, 0.28)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	fx = Effects.new()
	root.add_child(fx)
	pool = ProjectilePool.new()
	pool.authoritative = false
	root.add_child(pool)
	var catalog := WeaponCatalog.load_all()
	for id: StringName in [&"pistol", &"smg", &"shotgun", &"sniper", &"rocket", &"grenade", &"flicker_kunai",
			&"twinshot_revolver", &"bot_blaster"]:
		guns.append(catalog.get_weapon(id))


func _process(delta: float) -> bool:
	t += delta
	var n: int = int(t / 1.0)
	if n != fired:
		fired = n
		fx.blast(Vector2(220, 160), 90.0, false)
		fx.blast(Vector2(560, 160), 62.0, true)
		fx.swing(Vector2(860, 160), Vector2.RIGHT, 70.0, 140.0, Color(0.85, 0.95, 1))
		fx.swing(Vector2(1100, 160), Vector2.LEFT, 56.0, 160.0, Color(1, 0.85, 0.35))
		fx.beam(Vector2(100, 330), Vector2(600, 310), Color(0.95, 0.4, 1), 12.0)
		fx.burst(Vector2(900, 320), Color(1, 0.4, 0.2), 30, 400.0, 6.0, 0.5)
		for i: int in guns.size():
			var y: float = BULLET_ROW_Y + i * BULLET_ROW_STEP
			pool.fire_shot(1, i, Vector2(40, y), Vector2.RIGHT, guns[i], 7)
			pool.fire_shot(1, CRIT_SEQ + i, Vector2(680, y), Vector2.RIGHT, guns[i], 7)
		for s: ProjectilePool.Slot in pool.debug_slots():
			if s.active and s.shot_seq >= CRIT_SEQ:
				s.crit = true
	return false
