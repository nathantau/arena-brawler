class_name ScreenFade
extends ColorRect
## Dip from the game's dark colour: covers the screen at once, then fades out. Hides scene swaps.

const LAYER: int = 128
const DURATION: float = 0.4
const COLOR: Color = Color8(27, 26, 46)


static func play(host: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	var rect := ScreenFade.new()
	rect.color = COLOR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	host.add_child(layer)
	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, DURATION).from(1.0)
	tw.tween_callback(layer.queue_free)
