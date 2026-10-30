extends SceneTree
# godot --path . --write-movie <dir>/f.png --fixed-fps 30 --quit-after 30 -s tools/fx_preview.gd
# Dev preview: fires each effect side by side on a wood background, for --write-movie.
var fx: Effects
var t: float = 0.0
var fired: int = -1

func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.69, 0.44, 0.28)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	fx = Effects.new()
	root.add_child(fx)

func _process(delta: float) -> bool:
	t += delta
	var n: int = int(t / 1.0)
	if n != fired:
		fired = n
		fx.blast(Vector2(220, 260), 90.0, false)
		fx.blast(Vector2(560, 260), 62.0, true)
		fx.swing(Vector2(860, 260), Vector2.RIGHT, 70.0, 140.0, Color(0.85, 0.95, 1))
		fx.swing(Vector2(1100, 260), Vector2.LEFT, 56.0, 160.0, Color(1, 0.85, 0.35))
		fx.beam(Vector2(100, 560), Vector2(700, 520), Color(0.95, 0.4, 1), 12.0)
		fx.burst(Vector2(950, 560), Color(1, 0.4, 0.2), 30, 400.0, 6.0, 0.5)
	return false
