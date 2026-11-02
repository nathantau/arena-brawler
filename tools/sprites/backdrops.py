"""Character-select backdrops: one looping pixel-art strip per fighter (assets/backdrops/<character id>.png).

Each strip is FRAMES frames of W x H art pixels side by side. The floor line sits on row FLOOR (the game aligns it
with the fighter's feet and draws the soft contact shadow itself), the middle of the picture stays calm so the fighter
reads in front of it, and everything is darker / lower contrast than the sprites: palette colours only (shade and
highlight steps come from palette.DARKER / LIGHTER, dithered with a 4x4 Bayer matrix), a vignette, and a dark gradient
across the top where the name and stats sit. Motion is gentle and loops perfectly over FRAMES: drifting particles that
fade in and out (leaves, embers, petals, rain, dust), layers that sway on a sine, flickering glows.

  python backdrops.py [out_dir]      (generate.py also calls main())
"""

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from palette import (BLUE, BROWN, CHESTNUT_D, DARKER, GREEN, GREEN_D, GREEN_L, LIGHTER, MAROON, NAVY, OCHRE, OCHRE_D,
                     OLIVE, OLIVE_D, OLIVE_L, ORANGE, OUTLINE, PALETTE, PINK, PINK_L, RED, SHADOW, STEEL, STEEL_D,
                     TEAL, VIOLET, VIOLET_D, VIOLET_L, WALNUT, WALNUT_D, WHITE, YELLOW)

W, H = 128, 184
FLOOR = 128  # row the fighter's feet stand on
FRAMES = 24
FPS = 12
TEXT_ROWS = 60  # rows darkened for the name / stats
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
OUT = Path(__file__).resolve().parents[2] / "assets" / "backdrops"
PAL = set(PALETTE)


def bay(x: int, y: int) -> float:
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


def step(c: tuple, k: int) -> tuple:
    ramp = LIGHTER if k > 0 else DARKER
    for _ in range(abs(k)):
        c = ramp[c]
    return c


def _up(frac: float, x: int, y: int) -> bool:
    """Crisp banding: solid below / above, a one-pixel checker only where two bands meet."""
    return frac > 0.62 or (frac > 0.38 and (x + y) % 2 == 0)


def dith(c: tuple, t: float, x: int, y: int) -> tuple:
    """`c` shifted t palette steps (negative = darker); the steps are bands with a checker seam, not noise."""
    k = math.floor(t)
    if _up(t - k, x, y):
        k += 1
    return step(c, k)


def mix(a: tuple, b: tuple, t: float, x: int, y: int) -> tuple:
    return b if _up(t, x, y) else a


class Layer:
    """A transparent RGBA picture that is painted with palette colours only."""

    def __init__(self) -> None:
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.px = self.img.load()
        self.d = ImageDraw.Draw(self.img)

    def put(self, x: int, y: int, c: tuple) -> None:
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = c + (255,)

    def get(self, x: int, y: int) -> tuple | None:
        if 0 <= x < W and 0 <= y < H and self.px[x, y][3]:
            return self.px[x, y][:3]
        return None

    def gradient(self, y0: int, y1: int, stops: list) -> None:
        """Vertical bands between consecutive stops, dithered across each."""
        n = len(stops) - 1
        for y in range(y0, y1):
            u = (y - y0) / max(1, y1 - y0 - 1) * n
            i = min(int(u), n - 1)
            t = u - i
            for x in range(W):
                self.put(x, y, mix(stops[i], stops[i + 1], t, x, y))

    def fade_fill(self, y0: int, y1: int, c: tuple, power: float = 1.0, top: float = 0.0, bottom: float = 1.0) -> None:
        """Ordered-dither `c` over rows y0..y1, coverage easing from `top` to `bottom` (a soft glow without banding)."""
        for y in range(y0, y1):
            a = top + (bottom - top) * ((y - y0) / max(1, y1 - y0 - 1)) ** power
            for x in range(W):
                if a > bay(x, y):
                    self.put(x, y, c)

    def shape(self, mask_fn, color_fn, alpha_fn=None) -> None:
        """Paint where `mask_fn(ImageDraw)` draws, each pixel coloured by color_fn(x, y)."""
        m = Image.new("L", (W, H), 0)
        mask_fn(ImageDraw.Draw(m))
        mp = m.load()
        for y in range(H):
            for x in range(W):
                if mp[x, y] and (alpha_fn is None or alpha_fn(x, y) > bay(x, y)):
                    self.put(x, y, color_fn(x, y))

    def poly(self, pts: list, color_fn, alpha_fn=None) -> None:
        self.shape(lambda d: d.polygon(pts, fill=255), color_fn, alpha_fn)

    def ellipse(self, box: tuple, color_fn) -> None:
        self.shape(lambda d: d.ellipse(box, fill=255), color_fn)

    def rect(self, box: tuple, color_fn) -> None:
        self.shape(lambda d: d.rectangle(box, fill=255), color_fn)

    def lighten(self, cx: float, cy: float, rx: float, ry: float, strength: float, power: float = 1.5) -> None:
        """A dithered radial glow over what is already painted."""
        for y in range(max(0, int(cy - ry)), min(H, int(cy + ry) + 1)):
            for x in range(max(0, int(cx - rx)), min(W, int(cx + rx) + 1)):
                d = math.hypot((x - cx) / rx, (y - cy) / ry)
                c = self.get(x, y)
                if d < 1 and c is not None:
                    self.put(x, y, dith(c, strength * (1 - d) ** power, x, y))

    def shade_rows(self, y0: int, y1: int, t0: float, t1: float) -> None:
        for y in range(max(0, y0), min(H, y1)):
            t = t0 + (t1 - t0) * (y - y0) / max(1, y1 - y0 - 1)
            for x in range(W):
                c = self.get(x, y)
                if c is not None:
                    self.put(x, y, dith(c, t, x, y))


def flat(c: tuple):
    return lambda x, y: c


def lit(c: tuple, top: float, bottom: float, steps: float = 1.2, bias: float = 0.0):
    """Lighter toward `top`, darker toward `bottom`."""
    def fn(x: int, y: int) -> tuple:
        u = (y - top) / max(1.0, bottom - top)
        return dith(c, (0.5 - u) * steps * 2 + bias, x, y)
    return fn


def disc(layer: Layer, x: float, y: float, c: tuple, r: int = 0) -> None:
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r + (1 if r else 0):
                layer.put(round(x) + dx, round(y) + dy, c)


class Scene:
    """Static layers (back to front), animated overlays, and a per-frame glow hook."""

    def __init__(self, seed: int) -> None:
        self.rng = random.Random(seed)
        self.layers: list[tuple[Layer, float, float]] = []  # layer, sway x amplitude, phase
        self.motion = []  # callables (frame, canvas Layer)
        self.glow = None  # callable (frame, composited Image) -> None, pixel-level
        self.dim = 0.0

    def add(self, layer: Layer, sway: float = 0.0, phase: float = 0.0) -> Layer:
        self.layers.append((layer, sway, phase))
        return layer

    def particles(self, n: int, region: tuple, travel: tuple, colors: list, size: int = 1, sway: float = 3.0,
                  kind: str = "dot") -> None:
        """n particles that drift `travel` (dx, dy) over the loop, each fading in and out (darker steps at the ends)."""
        rng = self.rng
        items = [(rng.uniform(region[0], region[2]), rng.uniform(region[1], region[3]), rng.random(),
                  rng.uniform(0.6, 1.4), rng.choice(colors), rng.random() * math.tau) for _ in range(n)]

        def draw(frame: int, cv: Layer) -> None:
            for x0, y0, ph, speed, col, sw in items:
                u = (frame / FRAMES + ph) % 1.0
                x = x0 + travel[0] * u * speed + math.sin(math.tau * (frame / FRAMES) + sw) * sway
                y = y0 + travel[1] * u * speed
                fade = math.sin(math.pi * u)
                c = step(col, 0 if fade > 0.66 else -1 if fade > 0.33 else -2)
                if kind == "streak":
                    for k in range(size):
                        cv.put(round(x - travel[0] * 0.02 * k), round(y - k), c)
                elif kind == "leaf":
                    cv.put(round(x), round(y), c)
                    cv.put(round(x) + (1 if int(u * 6) % 2 else -1), round(y) + 1, c)
                else:
                    disc(cv, x, y, c, size - 1 if size > 1 else 0)
        self.motion.append(draw)

    def frame(self, f: int) -> Image.Image:
        canvas = Layer()
        base = Image.new("RGBA", (W, H), OUTLINE + (255,))
        for layer, amp, phase in self.layers:
            dx = round(amp * math.sin(math.tau * (f / FRAMES + phase)))
            base.alpha_composite(layer.img, (dx, 0))
        for m in self.motion:
            m(f, canvas)
        base.alpha_composite(canvas.img)
        if self.glow:
            self.glow(f, base)
        return finish(base, self.dim)


def finish(img: Image.Image, dim: float) -> Image.Image:
    """Vignette, the dark band under the text, optional overall dimming; keeps every pixel on the palette."""
    px = img.load()
    for y in range(H):
        for x in range(W):
            c = px[x, y][:3]
            dx = abs(x - W / 2) / (W / 2)
            dy = (y - FLOOR * 0.62) / (H * 0.62)
            v = max(0.0, math.hypot(dx * 0.8, dy * 0.9) - 0.78)
            t = -v * 1.6 - dim
            if y > FLOOR + 8:  # the floor is a pool of light round the fighter's feet that falls off into the dark
                t -= min(2.4, (y - FLOOR - 8) / 12)
            if y < TEXT_ROWS:
                t -= 1.3 * (1 - y / TEXT_ROWS) ** 1.2
            if t < -0.01:
                c = dith(c, t, x, y)
            px[x, y] = c + (255,)
    return img


def glow_points(points: list, floor_only: bool = False):
    """Per-frame glow hook: points = (cx, cy, rx, ry, strength, flicker) with flicker the sine depth (0..1)."""
    def hook(f: int, img: Image.Image) -> None:
        px = img.load()
        for cx, cy, rx, ry, strength, flick in points:
            s = strength * (1 - flick * 0.5 + flick * 0.5 * math.sin(math.tau * f / FRAMES * 2 + cx))
            for y in range(max(0, int(cy - ry)), min(H, int(cy + ry) + 1)):
                for x in range(max(0, int(cx - rx)), min(W, int(cx + rx) + 1)):
                    d = math.hypot((x - cx) / rx, (y - cy) / ry)
                    if d < 1:
                        px[x, y] = dith(px[x, y][:3], s * (1 - d) ** 1.5, x, y) + (255,)
    return hook


# --------------------------------------------------------------------------------------------------------------
# scenes
# --------------------------------------------------------------------------------------------------------------

def ground(layer: Layer, stops: list, y0: int = FLOOR, lines: tuple | None = None, line_c: tuple | None = None,
           rim: tuple | None = None) -> None:
    """The floor under the fighter: banded gradient, a lit rim on the horizon and optional receding plank lines."""
    layer.gradient(y0, H, stops)
    if rim:
        for x in range(W):
            layer.put(x, y0, rim)
    if lines and line_c:  # (spacing, converge): horizontal seams that thin out towards the horizon
        y = y0 + 3
        gap = lines[0]
        while y < H:
            for x in range(W):
                if (x + y) % 2 == 0:
                    layer.put(x, y, line_c)
            y += gap
            gap += lines[1]


def tree(layer: Layer, x: int, top: int, bottom: int, w: int, c: tuple, rim: tuple | None = None) -> None:
    layer.poly([(x, bottom), (x + w, bottom), (x + w - 1, top), (x + 1, top)], flat(c))
    if rim:
        layer.rect((x + 1, top, x + 1, bottom), flat(rim))


def puffs(layer: Layer, rng: random.Random, boxes: list, base: tuple, top: tuple, bottom_dark: int = -1) -> None:
    """Rounded foliage / cloud masses: flat base with a lit top edge (one palette step) and a darker underside."""
    for cx, cy, rx, ry in boxes:
        layer.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), lambda x, y, cy=cy, ry=ry: (
            top if y < cy - ry * 0.45 else step(base, bottom_dark) if y > cy + ry * 0.55 else base))


def leaf_clusters(layer: Layer, rng: random.Random, centers: list, base: tuple, light: tuple) -> None:
    """Round leaf clumps: a flat base disc with a lit upper-left rim (clean 1-2 px edge, no dither)."""
    for cx, cy, r in centers:
        layer.ellipse((cx - r, cy - r, cx + r, cy + r), lambda x, y, cx=cx, cy=cy, r=r: (
            light if (x - cx) + (y - cy) < -r * 0.9 else base))


def eden() -> Scene:
    s = Scene(11)
    sky = Layer()  # a calm glade: dark canopy overhead, a warm green glow at the horizon
    sky.gradient(0, FLOOR, [SHADOW, SHADOW, GREEN_D, GREEN_D])
    s.add(sky)
    shafts = Layer()  # three soft shafts of light behind the trunks
    for x0, wd, run in ((22, 8, 24), (60, 6, 20), (92, 9, 24)):
        shafts.poly([(x0, 10), (x0 + wd, 10), (x0 + wd + run, FLOOR), (x0 + run - 6, FLOOR)], flat(OLIVE_D))
    s.add(shafts, 3.0, 0.0)
    far = Layer()  # distant trunks: thin and blue
    for i, x in enumerate(range(6, W, 19)):
        far.rect((x, 30 + (i * 7) % 18, x + 3, FLOOR - 2), flat(NAVY))
    s.add(far, 1.0, 0.0)
    mid = Layer()  # mid trunks, dark with a lit left edge
    for x, top, w in ((14, 20, 7), (50, 26, 6), (78, 22, 7), (104, 28, 6)):
        mid.rect((x, top, x + w, FLOOR), flat(OUTLINE))
        mid.rect((x, top, x, FLOOR), flat(GREEN_D))
    s.add(mid, 1.5, 0.1)
    canopy = Layer()  # the canopy edge: scalloped leaf clusters
    canopy.rect((0, 0, W, 14), flat(OUTLINE))
    centers = [(x + (i % 2) * 6, 14 + (i * 5) % 9, 9 + (i * 3) % 5) for i, x in enumerate(range(-4, W + 12, 14))]
    leaf_clusters(canopy, s.rng, centers, OUTLINE, step(GREEN_D, -1))
    leaf_clusters(canopy, s.rng, [(6, 34, 8), (18, 44, 6), (118, 36, 9), (108, 48, 6)], OUTLINE, step(GREEN_D, -1))
    tree(canopy, -6, 0, FLOOR + 4, 20, OUTLINE, GREEN_D)  # the two foreground trunks
    tree(canopy, 114, 0, FLOOR + 4, 22, OUTLINE, GREEN_D)
    s.add(canopy, 2.0, 0.25)
    floor = Layer()
    ground(floor, [GREEN_D, GREEN_D, step(GREEN_D, -1)], rim=GREEN)
    for x in range(8, W, 17):  # grass tufts, then a few flowers
        y = FLOOR + 8 + (x * 7) % 36
        for dx, dy in ((-2, 0), (0, -2), (2, 0), (-1, -1), (1, -1)):
            floor.put(x + dx, y + dy, GREEN_L if dy else GREEN)
    for x, y, c in ((22, FLOOR + 22, PINK_L), (50, FLOOR + 34, YELLOW), (90, FLOOR + 18, PINK_L), (108, FLOOR + 40, WHITE), (38, FLOOR + 46, YELLOW)):
        floor.put(x, y, c)
        floor.put(x, y + 1, GREEN)
        floor.put(x, y + 2, GREEN)
    s.add(floor)
    s.particles(14, (6, 0, W - 6, 100), (-16, 52), [OLIVE_L, GREEN_L, GREEN], kind="leaf", sway=5)
    s.particles(8, (10, 70, W - 10, 150), (6, -18), [YELLOW, GREEN_L], size=1, sway=4)
    return s


def flint() -> Scene:
    s = Scene(12)
    back = Layer()  # inside the arch: warm bands rising from the lava
    back.gradient(0, FLOOR, [OUTLINE, OUTLINE, MAROON, MAROON, RED])
    s.add(back)
    arch = Layer()  # a dark rock arch framing the scene
    ring = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(ring)
    d.rectangle((0, 0, W, FLOOR), fill=255)
    d.ellipse((14, 18, W - 14, 220), fill=0)  # the opening
    mp = ring.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y]:
                arch.put(x, y, OUTLINE)
    for x in range(W):  # a lit rim along the inside of the arch, picked out by the lava
        for y in range(H):
            if arch.get(x, y) is not None and any(arch.get(x + dx, y + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1)) if 0 < y + dy < FLOOR):
                arch.put(x, y, MAROON if y > 40 else step(MAROON, -1))
    for x, ln in ((36, 14), (50, 22), (64, 12), (78, 20), (92, 12)):  # stalactites hanging in the opening
        arch.poly([(x - 4, 14), (x + 4, 14), (x, 18 + ln)], flat(OUTLINE))
    s.add(arch, 1.0, 0.0)
    pool = Layer()  # a lava pool behind him: nested bands, hottest in the middle
    for (rx, ry, c) in ((58, 12, MAROON), (52, 10, RED), (42, 8, ORANGE), (28, 5, YELLOW)):
        pool.ellipse((64 - rx, FLOOR - 4 - ry, 64 + rx, FLOOR - 4 + ry), flat(c))
    s.add(pool, 2.0, 0.0)
    floor = Layer()
    ground(floor, [step(MAROON, 0), step(MAROON, 0), OUTLINE], rim=RED)
    for x0 in (14, 38, 90, 112):  # glowing cracks
        x, y = x0, FLOOR + 8
        for _ in range(9):
            floor.put(x, y, ORANGE)
            x += s.rng.choice((-1, 0, 1))
            y += 2
    s.add(floor)
    s.particles(18, (10, FLOOR - 10, W - 10, FLOOR + 10), (6, -96), [ORANGE, YELLOW, RED], sway=4)

    def pulse(f: int, img: Image.Image) -> None:  # a slow breath of heat over the pool
        px = img.load()
        a = 0.9 + 0.5 * math.sin(math.tau * f / FRAMES)
        for y in range(FLOOR - 40, FLOOR + 6):
            for x in range(14, W - 14):
                d = math.hypot((x - 64) / 70, (y - (FLOOR - 4)) / 38)
                if d < 1 and px[x, y][:3] in (MAROON, RED, ORANGE, OUTLINE):
                    px[x, y] = dith(px[x, y][:3], a * (1 - d) ** 1.2, x, y) + (255,)
    s.glow = pulse
    return s


def bolt() -> Scene:
    s = Scene(13)
    sky = Layer()
    sky.gradient(0, FLOOR, [OUTLINE, NAVY, NAVY, SHADOW])
    s.add(sky)
    far = Layer()
    puffs(far, s.rng, [(18, 34, 34, 11), (76, 22, 44, 13), (120, 46, 30, 11), (50, 62, 38, 10)], NAVY, SHADOW, -1)
    s.add(far, 4.0, 0.0)
    near = Layer()
    puffs(near, s.rng, [(100, 12, 44, 13), (6, 58, 42, 13), (92, 88, 44, 11), (26, 100, 40, 10)], SHADOW, STEEL_D, -1)
    s.add(near, 7.0, 0.5)
    ridge = Layer()
    ridge.poly([(0, FLOOR), (0, 112), (18, 104), (36, 114), (58, 106), (84, 116), (106, 104), (W, 112), (W, FLOOR)], flat(OUTLINE))
    s.add(ridge)
    floor = Layer()
    ground(floor, [NAVY, NAVY, OUTLINE], rim=STEEL_D)
    for x0, y0, wd in ((24, FLOOR + 16, 18), (88, FLOOR + 26, 24), (54, FLOOR + 40, 14)):  # puddles catching the sky
        floor.ellipse((x0 - wd, y0 - 3, x0 + wd, y0 + 3), flat(SHADOW))
        floor.rect((x0 - wd + 4, y0 - 1, x0 + wd - 4, y0 - 1), flat(STEEL_D))
    s.add(floor)
    bolt_layer = Layer()
    pts = [(98, 0), (92, 18), (100, 30), (90, 54), (97, 64), (86, 96)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        bolt_layer.d.line((x0, y0, x1, y1), fill=STEEL + (255,))
        bolt_layer.d.line((x0 + 1, y0, x1 + 1, y1), fill=STEEL_D + (255,))

    def flash(f: int, img: Image.Image) -> None:  # two quick flickers per loop
        a = {5: 1.0, 6: 0.45, 8: 0.9, 9: 0.3}.get(f, 0.0)
        if a <= 0:
            return
        px = img.load()
        for y in range(0, 112):
            for x in range(W):
                d = math.hypot((x - 92) / 74, (y - 44) / 74)
                if d < 1:
                    px[x, y] = dith(px[x, y][:3], a * 2.0 * (1 - d) ** 1.3, x, y) + (255,)
        if a > 0.6:
            img.alpha_composite(bolt_layer.img)
    s.glow = flash
    s.particles(40, (-10, -10, W + 10, 140), (-14, 120), [STEEL_D, STEEL, STEEL_D], kind="streak", size=3, sway=0.0)
    return s


def flicker() -> Scene:
    s = Scene(14)
    sky = Layer()
    sky.gradient(0, FLOOR, [OUTLINE, NAVY, NAVY, BLUE])
    s.add(sky)
    stars = Layer()
    for _ in range(40):
        x, y = s.rng.randrange(0, W), s.rng.randrange(0, 84)
        stars.put(x, y, s.rng.choice((STEEL_D, STEEL_D, STEEL)))
    s.add(stars)
    moon = Layer()  # a crisp moon: halo ring, rim band, lit face with a shaded limb
    moon.ellipse((52, -10, 132, 70), flat(SHADOW))
    moon.ellipse((58, -4, 126, 64), flat(NAVY))
    moon.ellipse((72, 10, 112, 50), flat(STEEL_D))
    moon.ellipse((74, 12, 110, 48), lambda x, y: STEEL if (x - 74) + (y - 12) * 0.7 < 33 else STEEL_D)
    moon.ellipse((76, 14, 100, 38), lambda x, y: WHITE if (x - 76) + (y - 14) < 22 else STEEL)
    for cx, cy, r in ((86, 26, 3), (99, 35, 3), (83, 40, 2)):
        moon.ellipse((cx - r, cy - r, cx + r, cy + r), flat(STEEL_D))
    s.add(moon)
    city = Layer()
    city.poly([(0, FLOOR), (0, 106), (14, 106), (14, 96), (30, 96), (30, 108), (44, 108), (44, 88), (49, 78), (54, 88), (54, 108),
               (72, 108), (72, 98), (88, 98), (88, 110), (W, 110), (W, FLOOR)], flat(OUTLINE))
    for x, y in ((18, 100), (36, 112), (62, 112), (78, 104), (110, 116), (94, 114)):
        city.put(x, y, step(YELLOW, -3))
    s.add(city, 1.0, 0.0)
    cloud = Layer()
    for cx, cy, rx, ry in ((20, 66, 30, 4), (92, 60, 36, 4), (56, 86, 30, 3)):
        cloud.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), flat(NAVY))
    s.add(cloud, 6.0, 0.0)
    roof = Layer()
    ground(roof, [SHADOW, SHADOW, NAVY], lines=(6, 1), line_c=OUTLINE, rim=STEEL_D)
    s.add(roof)
    s.particles(8, (0, 20, W, 100), (24, 8), [STEEL, WHITE], size=1, sway=2)
    return s


def shadow() -> Scene:
    s = Scene(15)
    sky = Layer()
    sky.gradient(0, FLOOR, [OUTLINE, VIOLET_D, OUTLINE, VIOLET_D])
    s.add(sky)
    for k, (y0, amp, ph, c, top) in enumerate(((22, 8.0, 0.0, VIOLET_D, VIOLET), (58, 6.0, 0.3, VIOLET_D, VIOLET), (100, 10.0, 0.6, VIOLET, VIOLET_L))):
        mist = Layer()
        boxes = []
        for i in range(5):
            boxes.append((i * 34 - 10 + s.rng.randrange(-6, 6), y0 + s.rng.randrange(-8, 8), s.rng.randrange(26, 40), s.rng.randrange(7, 12)))
        puffs(mist, s.rng, boxes, c, top, -1)
        s.add(mist, amp, ph)
    cols = Layer()  # broken columns standing in the mist
    for x, top, wd in ((8, 44, 7), (114, 30, 8), (30, 80, 5)):
        cols.rect((x, top, x + wd, FLOOR), flat(OUTLINE))
        cols.rect((x, top, x, FLOOR), flat(VIOLET_D))
    s.add(cols)
    floor = Layer()
    ground(floor, [VIOLET_D, VIOLET_D, OUTLINE], rim=VIOLET)
    for rx, ry, c in ((54, 9, VIOLET_D), (38, 6, VIOLET), (22, 3, VIOLET_L)):  # ripples around the fighter
        floor.shape(lambda d, rx=rx, ry=ry: d.ellipse((64 - rx, FLOOR + 22 - ry, 64 + rx, FLOOR + 22 + ry), outline=255), flat(c))
    s.add(floor, 1.0, 0.0)
    s.particles(26, (6, 30, W - 6, FLOOR + 40), (6, -70), [VIOLET_L, VIOLET, VIOLET], sway=4)
    return s


def sakura() -> Scene:
    s = Scene(16)
    sky = Layer()
    sky.gradient(0, FLOOR, [NAVY, VIOLET_D, VIOLET, MAROON])
    s.add(sky)
    far = Layer()  # a pagoda on the horizon and a torii gate framing the fighter
    far.poly([(100, FLOOR - 4), (100, 92), (96, 92), (108, 84), (120, 92), (116, 92), (116, FLOOR - 4)], flat(OUTLINE))
    far.poly([(0, FLOOR), (0, 118), (28, 112), (60, 118), (96, 112), (W, 116), (W, FLOOR)], flat(OUTLINE))
    for x in (30, 90):  # torii posts
        far.rect((x, 56, x + 5, FLOOR), flat(OUTLINE))
        far.rect((x, 56, x, FLOOR), flat(MAROON))
    far.poly([(22, 58), (98, 58), (104, 50), (16, 50)], flat(OUTLINE))  # top beam, upswept ends
    far.rect((28, 66, 97, 70), flat(OUTLINE))
    far.rect((16, 50, 104, 50), flat(MAROON))
    s.add(far, 1.0, 0.0)
    blossom = Layer()  # blossom canopy in three pinks, hanging in from the left
    tree(blossom, 24, 56, FLOOR + 4, 9, OUTLINE, WALNUT_D)
    for cx, cy, r in ((32, 54, 18), (54, 50, 14), (12, 70, 14), (40, 70, 12)):  # the dark mass of the crown
        blossom.ellipse((cx - r, cy - r, cx + r, cy + r), flat(MAROON))
    for tone, count, rmax in ((PINK, 46, 3), (PINK_L, 16, 2)):  # blossom clumps in two lighter pinks
        for _ in range(count):
            x, y = s.rng.randrange(0, 68), s.rng.randrange(30, 90)
            if blossom.get(x, y) is not None:
                r = s.rng.randrange(1, rmax + 1)
                blossom.ellipse((x - r, y - r, x + r, y + r), flat(tone))
    s.add(blossom, 1.5, 0.3)
    floor = Layer()
    ground(floor, [VIOLET_D, VIOLET_D, NAVY], lines=(7, 1), line_c=step(VIOLET_D, -1), rim=PINK)
    for x, y in ((20, FLOOR + 14), (44, FLOOR + 30), (88, FLOOR + 22), (108, FLOOR + 40), (70, FLOOR + 10)):  # petals on the path
        floor.put(x, y, PINK)
        floor.put(x + 1, y, PINK_L)
    s.add(floor)
    s.particles(30, (0, 0, W, 120), (-22, 80), [PINK_L, PINK, PINK], kind="leaf", sway=6)
    return s


def wukong() -> Scene:
    s = Scene(17)
    sky = Layer()
    sky.gradient(0, FLOOR, [OUTLINE, NAVY, BLUE, BLUE])
    s.add(sky)
    peaks = Layer()
    peaks.poly([(0, FLOOR), (0, 84), (22, 52), (40, 84), (58, 36), (80, 82), (98, 54), (W, 90), (W, FLOOR)], flat(SHADOW))
    peaks.poly([(58, 36), (50, 52), (57, 50), (62, 56), (67, 49), (71, 53), (66, 44)], flat(STEEL_D))  # snow
    peaks.poly([(22, 52), (16, 64), (22, 60), (27, 66)], flat(STEEL_D))
    peaks.poly([(98, 54), (92, 66), (98, 62), (103, 68)], flat(STEEL_D))
    s.add(peaks, 1.5, 0.0)
    for k, (y0, amp, ph, c, top) in enumerate(((92, 7.0, 0.0, STEEL_D, STEEL), (108, 10.0, 0.4, STEEL_D, STEEL), (124, 6.0, 0.75, STEEL, WHITE))):
        banks = Layer()
        boxes = []
        for i in range(5):
            boxes.append((i * 34 - 8 + s.rng.randrange(-6, 6), y0 + s.rng.randrange(-4, 5), s.rng.randrange(22, 34), s.rng.randrange(7, 11)))
        puffs(banks, s.rng, boxes, step(c, -1 - (k == 2)), step(top, -1 - (k == 2)), -1)
        s.add(banks, amp, ph)
    ledge = Layer()
    ground(ledge, [SHADOW, SHADOW, NAVY], lines=(9, 2), line_c=OUTLINE, rim=STEEL_D)
    s.add(ledge)
    s.particles(8, (0, 20, W, 100), (-20, 4), [STEEL, WHITE], size=1, sway=3)
    return s


def twinshot() -> Scene:
    s = Scene(18)
    sky = Layer()
    sky.gradient(0, FLOOR, [OUTLINE, MAROON, BROWN, OCHRE_D])
    s.add(sky)
    town = Layer()
    for x0, x1, top in ((-4, 30, 66), (36, 70, 82), (76, 132, 60)):
        town.rect((x0, top, x1, FLOOR), flat(WALNUT_D))
        town.rect((x0, top, x1, top + 1), flat(WALNUT))
    town.poly([(-4, 66), (-4, 58), (12, 54), (30, 58), (30, 66)], flat(WALNUT_D))
    town.rect((84, 84, 112, 93), flat(BROWN))  # sign board
    town.rect((86, 86, 110, 91), flat(WALNUT_D))
    for x, y, w_, h_ in ((6, 80, 8, 12), (20, 80, 8, 12), (44, 94, 8, 11), (92, 100, 9, 12), (108, 100, 9, 12)):
        town.rect((x, y, x + w_, y + h_), flat(OCHRE_D))
        town.rect((x + 1, y + 1, x + w_ - 1, y + h_ - 1), flat(step(YELLOW, -2)))
        town.rect((x + w_ // 2, y, x + w_ // 2, y + h_), flat(WALNUT_D))
    town.rect((52, 110, 66, FLOOR), flat(OUTLINE))  # saloon doors
    s.add(town, 0.5, 0.0)
    road = Layer()
    ground(road, [OCHRE_D, BROWN, BROWN], rim=OCHRE)
    for _ in range(26):  # ruts and pebbles
        x, y = s.rng.randrange(0, W), s.rng.randrange(FLOOR + 4, H - 3)
        road.put(x, y, WALNUT_D)
        road.put(x + 1, y, WALNUT_D)
    s.add(road)
    s.particles(22, (0, 70, W, 168), (-52, 4), [OCHRE, OCHRE_D, YELLOW], sway=1.5)
    s.glow = glow_points([(11, 88, 18, 16, 1.2, 0.3), (48, 100, 16, 14, 1.0, 0.3), (100, 106, 26, 16, 1.2, 0.3)])
    return s


def warden() -> Scene:
    s = Scene(19)
    wall = Layer()
    wall.rect((0, 0, W, FLOOR), lambda x, y: step(SHADOW, -1) if (y % 8 == 0 or (x + (9 if (y // 8) % 2 else 0)) % 18 == 0) else SHADOW)
    wall.shade_rows(0, FLOOR, -0.2, -0.6)
    s.add(wall)
    arches = Layer()
    for cx in (22, 106):  # tall arched windows full of cold light
        arches.rect((cx - 11, 28, cx + 11, 100), flat(OUTLINE))
        arches.ellipse((cx - 11, 17, cx + 11, 40), flat(OUTLINE))
        arches.rect((cx - 9, 30, cx + 9, 100), lambda x, y: step(BLUE, -1) if y > 56 else BLUE if (y > 38 or abs(x - cx) < 6) else step(BLUE, -1))
        arches.ellipse((cx - 9, 19, cx + 9, 38), flat(BLUE))
        arches.rect((cx, 19, cx, 100), flat(OUTLINE))
        arches.rect((cx - 9, 62, cx + 9, 62), flat(OUTLINE))
    s.add(arches)
    shaft = Layer()
    for cx, dirn in ((22, 1), (106, -1)):
        shaft.poly([(cx - 9, 100), (cx + 9, 100), (cx + dirn * 48, FLOOR), (cx + dirn * 18, FLOOR)], flat(BLUE),
                   lambda x, y: 0.4 * (1 - (y - 100) / 28))
    s.add(shaft, 2.0, 0.0)
    banner = Layer()
    for x in (52, 76):
        banner.poly([(x, 28), (x + 12, 28), (x + 12, 74), (x + 6, 67), (x, 74)], flat(MAROON))
        banner.rect((x, 28, x + 12, 30), flat(RED))
        banner.rect((x - 1, 26, x + 13, 27), flat(STEEL_D))
        banner.rect((x + 5, 42, x + 7, 54), flat(step(YELLOW, -2)))
    s.add(banner, 1.0, 0.0)
    torches = Layer()
    for x in (38, 90):
        torches.rect((x, 84, x + 2, 96), flat(WALNUT))
        torches.poly([(x - 2, 80), (x + 4, 80), (x + 1, 68)], flat(ORANGE))
        torches.poly([(x, 80), (x + 2, 80), (x + 1, 73)], flat(YELLOW))
    s.add(torches)
    floor = Layer()
    ground(floor, [SHADOW, SHADOW, NAVY], lines=(9, 2), line_c=OUTLINE, rim=STEEL_D)
    s.add(floor)
    s.particles(18, (4, 30, W - 4, 130), (4, -20), [STEEL, STEEL_D, WHITE], sway=3)
    s.glow = glow_points([(39, 76, 20, 18, 1.1, 0.55), (91, 76, 20, 18, 1.1, 0.55)])
    return s


SCENES = {"eden": eden, "flint": flint, "bolt": bolt, "flicker": flicker, "shadow": shadow, "sakura": sakura,
          "wukong": wukong, "twinshot": twinshot, "warden": warden}


def build(name: str) -> Image.Image:
    scene = SCENES[name]()
    sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
    for f in range(FRAMES):
        sheet.paste(scene.frame(f), (f * W, 0))
    px = sheet.load()
    for y in range(H):  # palette check
        for x in range(0, W * FRAMES, 7):
            assert px[x, y][:3] in PAL, (name, x, y, px[x, y])
    return sheet


def main(out: Path = OUT, only: list | None = None) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for name in only or SCENES:
        build(name).save(out / f"{name}.png")
        print(f"wrote {out / f'{name}.png'} ({FRAMES} frames of {W}x{H})")


if __name__ == "__main__":
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else OUT)
