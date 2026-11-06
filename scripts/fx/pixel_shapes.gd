class_name PixelShapes
extends RefCounted
## Chunky pixel-grid ellipses for ground circles (shadows, team rings, pads, aim circle) so they match the pixel art
## instead of drawing smooth vector arcs. `px` is the art pixel size (Constants.SPRITE_SCALE). Rows are px tall; each row is
## one or two draw_rect spans, so a ring is ~2 rects per row. The centre snaps to the px grid; shapes are symmetric.


## Half-width in cells of the ellipse (rx, ry) on the row whose middle is `y` from the centre; -1 = row outside.
static func _half_cells(rx: float, ry: float, y: float, px: float) -> int:
	if ry <= 0.0 or rx <= 0.0 or absf(y) >= ry:
		return -1
	return maxi(1, roundi(rx * sqrt(1.0 - (y * y) / (ry * ry)) / px))


static func _rows(ry: float, px: float) -> int:
	return maxi(1, roundi(ry / px))


static func disc(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, px: float) -> void:
	for r: Rect2 in disc_spans(center, rx, ry, px):
		ci.draw_rect(r, color)


static func ring(ci: CanvasItem, center: Vector2, rx: float, ry: float, width: float, color: Color, px: float) -> void:
	for r: Rect2 in ring_spans(center, rx, ry, width, px):
		ci.draw_rect(r, color)


static func disc_spans(center: Vector2, rx: float, ry: float, px: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var c: Vector2 = center.snappedf(px)
	for j: int in range(-_rows(ry, px), _rows(ry, px)):
		var n: int = _half_cells(rx, ry, (j + 0.5) * px, px)
		if n > 0:
			out.append(Rect2(c.x - n * px, c.y + j * px, 2.0 * n * px, px))
	return out


static func ring_spans(center: Vector2, rx: float, ry: float, width: float, px: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var c: Vector2 = center.snappedf(px)
	var w: float = maxf(width, px)
	var irx: float = minf(rx - w, rx - px)
	var iry: float = minf(ry - w * ry / maxf(rx, 0.001), ry - px)
	for j: int in range(-_rows(ry, px), _rows(ry, px)):
		var y: float = (j + 0.5) * px
		var no: int = _half_cells(rx, ry, y, px)
		if no <= 0:
			continue
		var ni: int = _half_cells(irx, iry, y, px)
		var top: float = c.y + j * px
		if ni < 0:
			out.append(Rect2(c.x - no * px, top, 2.0 * no * px, px))
		else:
			ni = mini(ni, no - 1)
			var seg: float = (no - ni) * px
			out.append(Rect2(c.x - no * px, top, seg, px))
			out.append(Rect2(c.x + ni * px, top, seg, px))
	return out


## Part of a ring from angle a0 to a1 (radians, 0 = +x, clockwise on screen as in draw_arc). Cell by cell, so only for
## the occasional progress arc.
static func ring_arc(ci: CanvasItem, center: Vector2, rx: float, ry: float, width: float, color: Color, px: float,
		a0: float, a1: float) -> void:
	var c: Vector2 = center.snappedf(px)
	var w: float = maxf(width, px)
	var irx: float = minf(rx - w, rx - px)
	var iry: float = minf(ry - w * ry / maxf(rx, 0.001), ry - px)
	var span: float = a1 - a0
	for j: int in range(-_rows(ry, px), _rows(ry, px)):
		var y: float = (j + 0.5) * px
		var no: int = _half_cells(rx, ry, y, px)
		if no <= 0:
			continue
		var ni: int = _half_cells(irx, iry, y, px)
		ni = 0 if ni < 0 else mini(ni, no - 1)
		var run_start: int = 0
		var in_run: bool = false
		for i: int in range(-no, no + 1):  # i == no is a sentinel that closes a run
			var on: bool = false
			if i < no and (i if i >= 0 else -i - 1) >= ni:
				var x: float = (i + 0.5) * px
				on = fposmod(atan2(y / ry, x / rx) - a0, TAU) <= span
			if on and not in_run:
				run_start = i
				in_run = true
			elif not on and in_run:
				ci.draw_rect(Rect2(c.x + run_start * px, c.y + j * px, (i - run_start) * px, px), color)
				in_run = false
