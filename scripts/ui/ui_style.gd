class_name UiStyle
extends RefCounted
## The shared look of every screen: Pixelify Sans (OFL, assets/fonts), pixel-art 9-slices and
## icons from assets/ui (tools/sprites/generate.py), palette colours, text sizes that stay
## readable on a phone, outlined text for drawing over the game, and safe-area insets.

const FONT: FontFile = preload("res://assets/fonts/PixelifySans.ttf")
const UI_DIR: String = "res://assets/ui/"
## 9-slice margins of the pre-scaled kit (generate.py, x UI_SLICE_SCALE 2): 3 art px of edge and
## bevel, and up to 5 at the bottom where the button lip sits (so the lip never stretches).
const SLICE: int = 6
const SLICE_BOTTOM: int = 10
const BOLD_WEIGHT: float = 700.0

## Canvas is 720 units tall; on a phone in landscape that's ~400 pt, so 1 unit ~ 0.56 pt.
## SMALL (18) ~ 10 pt is the floor for anything you need to read mid-fight.
const SIZE_TINY: int = 16
const SIZE_SMALL: int = 18
const SIZE_BODY: int = 22
const SIZE_HEADING: int = 30
const SIZE_TITLE: int = 56
const SIZE_HUGE: int = 120
const TEXT_OUTLINE: int = 6
## Thumb-sized buttons: ~44 pt on a phone is ~78 canvas units; 72 is the compromise that still fits a stack of four.
const TOUCH_MIN_H: float = 72.0

## Palette (tools/sprites/palette.py).
const C_OUTLINE: Color = Color8(27, 26, 46)
const C_SHADOW: Color = Color8(58, 58, 92)
const C_NAVY: Color = Color8(43, 58, 107)
const C_STEEL_D: Color = Color8(93, 107, 138)
const C_STEEL: Color = Color8(154, 167, 194)
const C_WHITE: Color = Color8(242, 240, 230)
const C_RED: Color = Color8(217, 71, 75)
const C_MAROON: Color = Color8(122, 46, 56)
const C_YELLOW: Color = Color8(245, 210, 86)
const C_ORANGE: Color = Color8(240, 138, 62)
const C_TEAL: Color = Color8(47, 158, 147)
const C_TEAL_L: Color = Color8(126, 224, 207)
const C_DIM: Color = Color(0.95, 0.94, 0.9, 0.6)

## Minimum gap to the screen edge; mobile adds the device's safe-area insets on top.
const MIN_EDGE: float = 16.0
## `--notch`: fake an iPhone 16 Pro's landscape insets (62/62/21 pt) on desktop for layout checks.
const NOTCH_FLAG: String = "--notch"
const NOTCH_INSETS: Vector4 = Vector4(111, 0, 111, 38)

static var _bold: FontVariation
static var _textures: Dictionary[String, Texture2D] = {}


static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = FONT
		_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): BOLD_WEIGHT}
		_bold.opentype_features = _no_ligatures()
	return _bold


## Pixelify Sans' "fi" ligature draws as a broken glyph ("fighter" -> "Aghter"): spell every letter out.
static func _no_ligatures() -> Dictionary:
	return {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}


static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(UI_DIR + name + ".png")
	return _textures[name]


static func slice(name: String, pad_x: float = 12.0, pad_y: float = 8.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.set_texture_margin_all(SLICE)
	sb.texture_margin_bottom = SLICE_BOTTOM
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y + SLICE_BOTTOM - SLICE
	return sb


## Makes the UI theme the default for every Control (our UI hangs off plain Nodes and
## CanvasLayers, which don't pass a Window theme down) and the pixel font the fallback for
## world-space text (damage numbers, pickup labels).
static func install() -> void:
	var base: Theme = ThemeDB.get_default_theme()
	var ours: Theme = build_theme()
	base.merge_with(ours)
	base.default_font = ours.default_font
	base.default_font_size = ours.default_font_size
	ThemeDB.fallback_font = FONT
	ThemeDB.fallback_font_size = SIZE_BODY


## The UI theme (installed by Main). Variations: PrimaryButton,
## Card / CardSelected / CardGold (selectable tiles), HeaderLabel, DimLabel.
static func build_theme() -> Theme:
	var t := Theme.new()
	var font: FontFile = FONT  # (a const can't be assigned to, but the resource itself can)
	font.opentype_feature_overrides = _no_ligatures()
	t.default_font = FONT
	t.default_font_size = SIZE_BODY
	_button_styles(t, &"Button", "button", "button_pressed")
	t.set_color(&"font_color", &"Button", C_WHITE)
	t.set_color(&"font_hover_color", &"Button", C_WHITE)
	t.set_color(&"font_pressed_color", &"Button", C_STEEL)
	t.set_color(&"font_disabled_color", &"Button", C_STEEL_D)
	t.set_stylebox(&"disabled", &"Button", slice("button_disabled"))
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	t.set_type_variation(&"PrimaryButton", &"Button")
	_button_styles(t, &"PrimaryButton", "button_primary", "button_primary_pressed")
	t.set_font(&"font", &"PrimaryButton", bold())
	for v: StringName in [&"Card", &"CardSelected", &"CardGold"]:
		t.set_type_variation(v, &"Button")
	_button_styles(t, &"Card", "card", "card_selected", 10.0)
	_button_styles(t, &"CardSelected", "card_selected", "card_selected", 10.0)
	_button_styles(t, &"CardGold", "card_gold", "card_gold", 10.0)
	t.set_stylebox(&"disabled", &"CardGold", slice("card_gold", 10.0, 10.0))
	t.set_stylebox(&"panel", &"PanelContainer", slice("panel", 18.0, 14.0))
	t.set_stylebox(&"normal", &"LineEdit", slice("field"))
	t.set_stylebox(&"focus", &"LineEdit", slice("field"))
	t.set_color(&"font_color", &"LineEdit", C_WHITE)
	t.set_color(&"font_color", &"Label", C_WHITE)
	t.set_type_variation(&"HeaderLabel", &"Label")
	t.set_font(&"font", &"HeaderLabel", bold())
	t.set_font_size(&"font_size", &"HeaderLabel", SIZE_HEADING)
	t.set_type_variation(&"DimLabel", &"Label")
	t.set_color(&"font_color", &"DimLabel", C_DIM)
	t.set_font_size(&"font_size", &"DimLabel", SIZE_SMALL)
	return t


static func _button_styles(t: Theme, type: StringName, normal: String, pressed: String, pad: float = 16.0) -> void:
	t.set_stylebox(&"normal", type, slice(normal, pad, pad * 0.6))
	t.set_stylebox(&"hover", type, slice(normal, pad, pad * 0.6))
	t.set_stylebox(&"pressed", type, slice(pressed, pad, pad * 0.6))


## Text with a dark outline so it reads over any arena. Right-aligned text with no `width`
## ends at `pos` (Godot only aligns within a given width).
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, font_size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, heavy: bool = false) -> void:
	var font: Font = bold() if heavy else FONT
	if align == HORIZONTAL_ALIGNMENT_RIGHT and width < 0.0:
		pos.x -= text_width(text, font_size, heavy)
		align = HORIZONTAL_ALIGNMENT_LEFT
	var outline := Color(C_OUTLINE, color.a)
	ci.draw_string_outline(font, pos, text, align, width, font_size, TEXT_OUTLINE, outline)
	ci.draw_string(font, pos, text, align, width, font_size, color)


static func text_width(text: String, font_size: int, heavy: bool = false) -> float:
	var font: Font = bold() if heavy else FONT
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Largest font size <= `size` (never below `min_size`) at which `text` fits in `max_w`; labels also clip with an
## ellipsis as the last resort.
static func fit_size(text: String, max_w: float, size: int, min_size: int = SIZE_TINY - 2, heavy: bool = false) -> int:
	var s: int = size
	while s > min_size and text_width(text, s, heavy) > max_w:
		s -= 1
	return s


## Sets `label`'s text, shrinking the font to fit `max_w` and clipping with "..." if even the smallest doesn't.
static func fit_label(label: Label, text: String, max_w: float, size: int, min_size: int = SIZE_TINY - 2,
		heavy: bool = false) -> void:
	label.text = text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", fit_size(text, max_w, size, min_size, heavy))


## A pixel-art texture centred on `center`, scaled by a whole number so pixels stay square.
static func draw_icon(ci: CanvasItem, art: Texture2D, center: Vector2, scale_px: float, tint: Color = Color.WHITE) -> void:
	if art == null:  # e.g. form weapons (Great Ape's fists, Inferno's beam) have no sprite
		return
	var s: Vector2 = art.get_size() * scale_px
	ci.draw_texture_rect(art, Rect2(center - s * 0.5, s), false, tint)


## Left / top / right / bottom insets (canvas units) that keep UI clear of notches, the
## Dynamic Island and the home bar, never less than MIN_EDGE.
static func safe_insets(vp: Viewport) -> Vector4:
	var insets := Vector4.ZERO
	if OS.get_cmdline_user_args().has(NOTCH_FLAG):
		insets = NOTCH_INSETS
	elif OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var k: Vector2 = vp.get_visible_rect().size / win
		insets = Vector4(safe.position.x * k.x, safe.position.y * k.y,
			(win.x - safe.end.x) * k.x, (win.y - safe.end.y) * k.y)
	return Vector4(maxf(insets.x, MIN_EDGE), maxf(insets.y, MIN_EDGE), maxf(insets.z, MIN_EDGE), maxf(insets.w, MIN_EDGE))


## Full-rect control inset to the safe area; follows window size changes.
static func fit_to_safe_area(c: Control) -> void:
	var apply := func() -> void:
		var i: Vector4 = safe_insets(c.get_viewport())
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = i.x
		c.offset_top = i.y
		c.offset_right = -i.z
		c.offset_bottom = -i.w
	apply.call()
	c.get_viewport().size_changed.connect(apply)
