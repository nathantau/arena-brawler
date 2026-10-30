class_name PixelSprites
extends RefCounted
## The 8x4 gun sprite, built at runtime from the grid below and tinted with the weapon's
## colour at draw time. (Characters are PNG sheets from tools/sprites/generate.py.)

const SCALE: float = 5.0
const GUN_W: int = 8
const GUN_H: int = 4

const GUN_ROWS: Array[String] = [
	"KKKKKKK.",
	"KWWWWWWK",
	"KwwKKKK.",
	"KwK.....",
]
const GUN_PALETTE: Dictionary[String, Color] = {
	"K": Color("1b1a2e"), "W": Color(1, 1, 1), "w": Color(0.6, 0.6, 0.6),
}

static var _gun: ImageTexture


static func gun_texture() -> ImageTexture:
	if _gun == null:
		var img := Image.create(GUN_W, GUN_H, false, Image.FORMAT_RGBA8)
		for y: int in GUN_ROWS.size():
			for x: int in GUN_W:
				var c: String = GUN_ROWS[y][x]
				if GUN_PALETTE.has(c):
					img.set_pixel(x, y, GUN_PALETTE[c])
		_gun = ImageTexture.create_from_image(img)
	return _gun
