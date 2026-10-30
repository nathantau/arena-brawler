class_name PixelSprites
extends RefCounted
## Original 16x16 pixel-art characters and an 8x4 gun, built at runtime from the character
## grids below (no image assets). Palette letter "A"/"a" is the owning player's colour, so
## every fighter's scarf/plume/poncho shows who they are. Textures are cached per
## (character, colour, frame). Purely cosmetic: never touched by the simulation.

const SIZE: int = 16
const SCALE: float = 3.0
const GUN_W: int = 8
const GUN_H: int = 4
const ACCENT_DARKEN: float = 0.35

enum Frame { IDLE, BOB, STEP_A, STEP_B }

## Shared colours; per-character palettes override/extend these.
const BASE_PALETTE: Dictionary[String, Color] = {
	"K": Color("1a1c2c"), # outline
	"F": Color("f4c99b"), # skin
	"f": Color("c98b62"), # skin shade
	"E": Color("1a1c2c"), # eye
	"Y": Color("f2c14e"), # buckle
	"G": Color("5b3a29"), # boots
}

## Each character: 9 head rows, 3 body rows, then legs from LEGS_*. Faces right.
const CHARACTERS: Dictionary[StringName, Dictionary] = {
	&"flicker": {
		"palette": {
			"H": Color("2a9d8f"), "h": Color("1d6b63"), "L": Color("7fe3d4"),
			"B": Color("3a4a6b"), "b": Color("252f47"),
		},
		"rows": [
			"................",
			"....KKKKKKK.....",
			"...KLLHHHHHK....",
			"..KLHHHHHHHhK...",
			"..KHHKKKKKKhK...",
			"..KHKFFFFFFKK...",
			"..KHKFEFFEfKK...",
			"..KhKFFFFffKK...",
			"..aKAAAAAAAaK...",
			".aaKaABBBBBaK...",
			"..KFKBBYBBbKFK..",
			"...KKbBBBBbKK...",
		],
	},
	&"warden": {
		"palette": {
			"M": Color("b8c0d4"), "m": Color("6f7a94"), "L": Color("eef2fa"),
			"V": Color("7fe3d4"), "B": Color("6f7a94"), "b": Color("474f66"),
			"G": Color("474f66"),
		},
		"rows": [
			".....AAA........",
			"....KAaKKKK.....",
			"...KLMMMMMMK....",
			"..KLMMMMMMMmK...",
			"..KMMMMMMMMmK...",
			"..KMKKKKKKKmK...",
			"..KMKVKKKVKmK...",
			"..KmMMMMMMmmK...",
			"..KKmmmmmmmKK...",
			".KMMKAAAAAKMMK..",
			".KmMKAaYaAKMmK..",
			"..KKKBBBBBKKK...",
		],
	},
	&"twinshot": {
		"palette": {
			"H": Color("8a5a36"), "h": Color("5a3a22"),
			"B": Color("4a5a78"), "b": Color("2f3a52"),
		},
		"rows": [
			"................",
			"................",
			".....KKKKKK.....",
			"....KHHHHHhK....",
			"....KAAAAAaK....",
			"..KKHHHHHHHhKK..",
			".KhhhhhhhhhhhhK.",
			"...KFFEFFEfK....",
			"...KFFFFFffK....",
			"..KAaAAAAAAaK...",
			"..KFKAAYAAaKFK..",
			"...KKbBBBBbKK...",
		],
	},
}

const LEGS_IDLE: Array[String] = [
	"....KbBKKBbK....",
	"....KGGKKGGK....",
	"....KKKKKKKK....",
]
const LEGS_STEP_A: Array[String] = [
	"...KbBK.KBbK....",
	"...KGGK.KGGK....",
	"...KKKK..KKK....",
]
const LEGS_STEP_B: Array[String] = [
	"....KBbK.KbBK...",
	"....KGGK.KGGK...",
	"....KKK..KKKK...",
]
## Upper rows that bob down a pixel on BOB frames (legs stay planted).
const UPPER_ROWS: int = 12

## Light/dark gun body; tinted with the weapon's colour at draw time.
const GUN_ROWS: Array[String] = [
	"KKKKKKK.",
	"KWWWWWWK",
	"KwwKKKK.",
	"KwK.....",
]
const GUN_PALETTE: Dictionary[String, Color] = {
	"K": Color("1a1c2c"), "W": Color(1, 1, 1), "w": Color(0.6, 0.6, 0.6),
}

static var _cache: Dictionary[String, ImageTexture] = {}
static var _gun: ImageTexture


static func character_texture(id: StringName, accent: Color, frame: Frame) -> ImageTexture:
	var key: String = "%s:%s:%d" % [id, accent.to_html(), frame]
	var tex: ImageTexture = _cache.get(key)
	if tex == null:
		tex = ImageTexture.create_from_image(build_character(id, accent, frame))
		_cache[key] = tex
	return tex


static func gun_texture() -> ImageTexture:
	if _gun == null:
		_gun = ImageTexture.create_from_image(_paint(GUN_ROWS, GUN_PALETTE, GUN_W, GUN_H, 0, 0))
	return _gun


static func build_character(id: StringName, accent: Color, frame: Frame) -> Image:
	var def: Dictionary = CHARACTERS.get(id, CHARACTERS[&"flicker"])
	var palette: Dictionary[String, Color] = BASE_PALETTE.duplicate()
	palette.merge(def["palette"], true)
	palette["A"] = accent
	palette["a"] = accent.darkened(ACCENT_DARKEN)
	var rows: Array[String] = []
	rows.assign(def["rows"])
	match frame:
		Frame.STEP_A:
			rows.append_array(LEGS_STEP_A)
		Frame.STEP_B:
			rows.append_array(LEGS_STEP_B)
		_:
			rows.append_array(LEGS_IDLE)
	var bob: int = 1 if frame == Frame.BOB else 0
	return _paint(rows, palette, SIZE, SIZE, bob, UPPER_ROWS)


## Paints `rows` (one palette letter per pixel, "." = clear); rows above `shift_rows`
## move down by `shift` pixels.
static func _paint(rows: Array[String], palette: Dictionary, w: int, h: int, shift: int,
		shift_rows: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		var dy: int = shift if y < shift_rows else 0
		var line: String = rows[y]
		for x: int in mini(w, line.length()):
			var c: String = line[x]
			if palette.has(c) and y + dy < h:
				img.set_pixel(x, y + dy, palette[c])
	return img
