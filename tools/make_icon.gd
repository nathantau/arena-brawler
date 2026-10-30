extends SceneTree
## Renders the app icon (assets/icon.png, 1024x1024) from the Flicker sprite.
## Run: godot --path . --headless --script tools/make_icon.gd

const ICON_SIZE: int = 1024
const GRID: int = 20
const BG_TOP: Color = Color("2b2e40")
const BG_BOTTOM: Color = Color("16182a")
const ACCENT: Color = Color("ff4d6d")


func _init() -> void:
	var small := Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
	for y: int in GRID:
		small.fill_rect(Rect2i(0, y, GRID, 1), BG_TOP.lerp(BG_BOTTOM, float(y) / (GRID - 1)))
	var sprite: Image = PixelSprites.build_character(&"flicker", ACCENT, PixelSprites.Frame.IDLE)
	small.blend_rect(sprite, Rect2i(0, 0, PixelSprites.SIZE, PixelSprites.SIZE), Vector2i(2, 2))
	small.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_NEAREST)
	small.convert(Image.FORMAT_RGB8) # App Store icons must not have alpha.
	small.save_png("res://assets/icon.png")
	quit()
