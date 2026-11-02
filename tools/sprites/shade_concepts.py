"""Shade (id `flicker`) redesign concept A, "Crimson kunoichi" (picked from three directions). Design stage only: nothing is
written into assets/. Drawn at the game's cell size (96 px) with the art-box helpers from generate.py: a long red scarf with two
slim tails as her silhouette hook, one high volumetric ponytail with a kunai hairpin, a festival fox mask on the side of her head,
crimson lips, navy top with a kimono crossover, red obi, gold bracers, thigh holster, grey shin wraps.
Run: tools/sprites/.venv/bin/python tools/sprites/shade_concepts.py [out_dir]
Output: shade_A_polish.png (x6: 4 idle frames + 2 walking frames) and shade_A_scale.png (1x on an arena floor beside Sakura,
Bolt and the current Shade, then 2x) in the repo root (or out_dir). Only palette colours are used."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw  # noqa: E402

import generate as g  # noqa: E402
from generate import BODY, FACE, FACE_R, IDLE_BOB, L, P, R, RR, E, Canvas, arm, legs, big_eyes  # noqa: E402
from palette import (OUTLINE, SHADOW, STEEL, STEEL_D, WHITE, YELLOW, RED, TEAL_L, TEAL, ORANGE, SKIN, SKIN_D, MAROON, NAVY,
                     BLUE, BROWN, DARKER, LIGHTER, VIOLET_D, VIOLET, VIOLET_L, OCHRE, OCHRE_D, PINK, PINK_L, CREAM,
                     CREAM_D, GREEN, GREEN_L)  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CELL, PAD, UPPER_DY = g.CELL, g.PAD, g.UPPER_DY


# --- drawing helpers ------------------------------------------------------------------------------------------------------------
class Off:
    """Wraps an ImageDraw so shape lambdas written in art coordinates can paint into a CELL canvas at an offset."""

    def __init__(self, d, ox, oy):
        self.d, self.ox, self.oy = d, ox, oy

    def _p(self, a):
        if isinstance(a[0], (tuple, list)):
            return [(x + self.ox, y + self.oy) for x, y in a]
        return [v + (self.ox if i % 2 == 0 else self.oy) for i, v in enumerate(a)]

    def ellipse(self, box, fill=None, **k):
        self.d.ellipse(self._p(box), fill, **k)

    def rectangle(self, box, fill=None, **k):
        self.d.rectangle(self._p(box), fill, **k)

    def rounded_rectangle(self, box, radius, fill=None, **k):
        self.d.rounded_rectangle(self._p(box), radius, fill, **k)

    def polygon(self, pts, fill=None, **k):
        self.d.polygon(self._p(pts), fill, **k)

    def line(self, pts, fill=None, width=1, **k):
        self.d.line(self._p(pts), fill, width, **k)

    def arc(self, box, a0, a1, fill=None, **k):
        self.d.arc(self._p(box), a0, a1, fill, **k)


class Big(Canvas):
    """A CELL canvas that takes 64 px art coordinates: everything is shifted by (ox, oy) (the bob moves oy)."""

    def __init__(self, ox=PAD, oy=PAD):
        super().__init__(CELL)
        self.ox, self.oy = ox, oy

    def part(self, shape, color, shade=True, line=True):
        n = self.size
        mask = Image.new("1", (n, n), 0)
        shape(Off(ImageDraw.Draw(mask), self.ox, self.oy), 1)
        m = mask.load()

        def inside(x, y):
            return 0 <= x < n and 0 <= y < n and m[x, y]

        bb = mask.getbbox()
        if bb is None:
            return
        xs, xe, ys, ye = max(0, bb[0] - 1), min(n, bb[2] + 1), max(0, bb[1] - 1), min(n, bb[3] + 1)
        if line:
            for y in range(ys, ye):
                for x in range(xs, xe):
                    if not inside(x, y) and self.px[x, y][3] and any(
                            inside(nx, ny) for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                        self.px[x, y] = OUTLINE + (255,)
        for y in range(ys, ye):
            for x in range(xs, xe):
                if not inside(x, y):
                    continue
                c = color
                if shade:
                    if not inside(x, y + g.SHADE_DEPTH) or not inside(x + g.SHADE_DEPTH, y):
                        c = DARKER[color]
                    elif not inside(x, y - 1) or not inside(x - 1, y):
                        c = LIGHTER[color]
                self.px[x, y] = c + (255,)

    def flat(self, shape, color):
        shape(Off(ImageDraw.Draw(self.img), self.ox, self.oy), color + (255,))

    def dot(self, x, y, color):
        x, y = int(x + self.ox), int(y + self.oy)
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[x, y] = color + (255,)

    def at(self, x, y):
        return self.px[int(x + self.ox), int(y + self.oy)]

    def dither(self, shape, color, pat="check", only_on=None):
        """Dithered fill of a shape: a checker (or sparse) pattern; `only_on` keeps it on pixels that already hold that colour."""
        n = self.size
        mask = Image.new("1", (n, n), 0)
        shape(Off(ImageDraw.Draw(mask), self.ox, self.oy), 1)
        m = mask.load()
        for y in range(n):
            for x in range(n):
                if not m[x, y] or not self.px[x, y][3]:
                    continue
                if only_on is not None and self.px[x, y][:3] != only_on:
                    continue
                if (x + y) % 2 == 0 if pat == "check" else (x % 2 == 0 and y % 2 == 0):
                    self.px[x, y] = color + (255,)


def phase(t, lag=0.0, k=0.0):
    """A 4-frame looping sine, shifted by `lag` ticks (and `k` radians): the wave that runs down hair and cloth."""
    return math.sin(2 * math.pi * (t - lag) / 4 - k)


def strand(p0, p1, p2, p3, t, amp, k=1.6, n=12, lag=0.0):
    """A cubic Bezier from p0 to p3 with a travelling sine wave added across it (zero at the root, `amp` px at the tip)."""
    out = []
    for i in range(n + 1):
        s = i / n
        a, b, c, d = (1 - s) ** 3, 3 * s * (1 - s) ** 2, 3 * s ** 2 * (1 - s), s ** 3
        x = a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0]
        y = a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]
        # offset along the local normal
        dx = 3 * ((1 - s) ** 2 * (p1[0] - p0[0]) + 2 * s * (1 - s) * (p2[0] - p1[0]) + s ** 2 * (p3[0] - p2[0]))
        dy = 3 * ((1 - s) ** 2 * (p1[1] - p0[1]) + 2 * s * (1 - s) * (p2[1] - p1[1]) + s ** 2 * (p3[1] - p2[1]))
        ln = math.hypot(dx, dy) or 1
        w = amp * s * phase(t, lag, k * s)
        out.append((x - dy / ln * w, y + dx / ln * w))
    return out


def band(pts, w0, w1, notch=0.0):
    """Polygon of a ribbon along `pts`, its width tapering w0 -> w1; `notch` cuts a V into the tip."""
    left, right = [], []
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        w = (w0 + (w1 - w0) * i / (n - 1)) / 2
        left.append((x - dy / ln * w, y + dx / ln * w))
        right.append((x + dy / ln * w, y - dx / ln * w))
    tip = []
    if notch:
        (x, y), (px_, py_) = pts[-1], pts[-2]
        dx, dy = x - px_, y - py_
        ln = math.hypot(dx, dy) or 1
        tip = [(x - dx / ln * notch, y - dy / ln * notch)]
    return [(round(x), round(y)) for x, y in left + tip + right[::-1]]


def across(c, pts, i, half, color, w=1):
    """A short stripe across a ribbon at point i (trim bands)."""
    n = len(pts)
    a, b = pts[max(0, i - 1)], pts[min(n - 1, i + 1)]
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1
    x, y = pts[i]
    nx, ny = -dy / ln, dx / ln
    c.flat(L([(round(x - nx * half), round(y - ny * half)), (round(x + nx * half), round(y + ny * half))], w), color)


def disc(c, cx, cy, r, color, shade=True, line=True):
    c.part(E((cx - r, cy - r, cx + r, cy + r)), color, shade=shade, line=line)


def compose(low, up):
    f = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    f.alpha_composite(low.img)
    f.alpha_composite(up.img)
    return g.outline(f)




def sw_(t, lag, amp):
    return round(amp * phase(t, lag))


def bandw(pts, widths):
    """Left / right edge points along `pts` with a width per point (volume: hair bulges then tapers)."""
    left, right = [], []
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        w = widths[i] / 2
        left.append((x - dy / ln * w, y + dx / ln * w))
        right.append((x + dy / ln * w, y - dx / ln * w))
    return left, right


def ipts(ps):
    return [(round(x), round(y)) for x, y in ps]


def lerp2(a, b, f):
    return [(p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f) for p, q in zip(a, b)]


def ribbon(c, pts, w0, w1, base):
    """A slim cloth tail along `pts`: lit upper edge, dark underside, a few soft fold dashes, a two-toothed frayed tip."""
    n = len(pts)
    left, right = bandw(pts, [w0 + (w1 - w0) * i / (n - 1) for i in range(n)])
    (x, y), (px_, py_) = pts[-1], pts[-2]
    dx, dy = x - px_, y - py_
    ln = math.hypot(dx, dy) or 1
    tx, ty = dx / ln, dy / ln
    nx, ny = -ty, tx
    h = w1 / 2
    tip = [(x + nx * h * 0.6 + tx * 3.0, y + ny * h * 0.6 + ty * 3.0), (x + tx * 0.5, y + ty * 0.5),
           (x - nx * h * 0.6 + tx * 4.5, y - ny * h * 0.6 + ty * 4.5)]
    c.part(P(ipts(left + tip + right[::-1])), base)
    top, bot = (left, right) if sum(p[1] for p in left) < sum(p[1] for p in right) else (right, left)
    c.flat(L(ipts(top[1:-1]), 1), LIGHTER[base])
    c.flat(L(ipts([(a, b + 1) for a, b in bot[2:-1]]), 1), DARKER[base])
    mid = lerp2(left, right, 0.5)
    for i in range(3, n - 3, 4):
        c.flat(L(ipts(mid[i:i + 2]), 1), DARKER[base])


# ==================================================================================================================================
# Crimson kunoichi (polish round)
# ==================================================================================================================================
HAIR_A = SHADOW  # black hair: rim-lit by STEEL_D, shades to OUTLINE
GOLD = OCHRE


def kunai_pin(c, ring, base, tip):
    """A kunai hairpin: gold ring, red grip, leaf blade with a lit edge."""
    mx, my = (base[0] + tip[0]) // 2, (base[1] + tip[1]) // 2
    c.part(P([(base[0], base[1] - 2), (mx, my - 2), tip, (mx, my + 2), (base[0], base[1] + 2)]), STEEL)
    c.flat(L([(base[0] - 1, base[1] - 1), (mx - 1, my - 1)], 1), WHITE)
    c.flat(L([ring, (base[0] + 1, base[1])], 2), RED)
    c.flat(L([ring, (base[0] + 1, base[1])], 1), MAROON)
    disc(c, ring[0], ring[1], 2, GOLD)
    c.dot(ring[0], ring[1], OUTLINE)


def fox_mask(c, ox, oy):
    """A festival fox mask pushed up on the side of her head: symmetric ears with red tips, mirrored eye slits, cheek and
    forehead marks, a nose, and a tiny tie cord going back into her hair."""
    m = lambda x: 2 * ox + 7 - x  # mirror about the mask's axis
    for a in (1, -1):
        ear = [(ox - 2, oy + 1), (ox - 2, oy - 7), (ox + 3, oy - 2)]
        c.part(P([(x if a == 1 else m(x), y) for x, y in ear]), WHITE)
    c.part(lambda d, f: (d.ellipse((ox - 3, oy - 3, ox + 10, oy + 8), f), d.polygon([(ox - 1, oy + 5), (ox + 3, oy + 10), (ox + 4, oy + 10), (ox + 8, oy + 5)], f)), WHITE)
    for x in (ox - 2, m(ox - 2)):  # red ear tips
        c.dot(x, oy - 6, RED)
        c.dot(x, oy - 5, RED)
    for a, b in ((ox - 1, ox + 1), (ox + 6, ox + 8)):  # slanted eye slits (mirrored)
        c.flat(L([(a, oy + 2 if a < ox + 3 else oy + 1), (b, oy + 1 if a < ox + 3 else oy + 2)], 1), OUTLINE)
    for a, b in ((ox - 2, ox + 1), (ox + 6, ox + 9)):  # cheek whiskers
        c.flat(L([(a, oy + 5 if a < ox + 3 else oy + 4), (b, oy + 4 if a < ox + 3 else oy + 5)], 1), RED)
    c.flat(R((ox + 3, oy - 2, ox + 4, oy)), RED)  # forehead mark
    c.dot(ox + 3, oy + 8, OUTLINE)
    c.dot(ox + 4, oy + 8, OUTLINE)
    c.dot(ox + 1, oy - 2, STEEL)  # lit rim, top left
    c.dot(ox, oy - 1, STEEL)
    # tie cord: a red thread curling round the back of her head, with a gold bead
    c.flat(L([(ox - 3, oy + 3), (ox - 5, oy + 5), (ox - 4, oy + 8)], 1), RED)
    c.dot(ox - 4, oy + 8, GOLD)


def build_a(low, up, t, step=None):
    mv = 1.0 if step is not None else 0.0  # walking: tails and ponytail stream further back
    # ---- legs: navy trousers, light grey shin wraps with wrap lines, a thigh strap, dark split-toe tabi
    for x, dy in legs(low, NAVY, SHADOW, step):
        low.flat(L([(x + 1, 46 + dy), (x + 1, 49 + dy)], 1), BLUE)
        low.flat(R((x, 50 + dy, x + 5, 50 + dy)), BROWN)
        low.dot(x + 2, 50 + dy, GOLD)
        low.flat(R((x, 51 + dy, x + 5, 53 + dy)), STEEL)
        low.flat(R((x, 53 + dy, x + 5, 53 + dy)), STEEL_D)
        low.flat(L([(x, 52 + dy), (x + 5, 51 + dy)], 1), WHITE)  # wrap lines
        low.flat(L([(x, 53 + dy), (x + 5, 52 + dy)], 1), STEEL_D)
        low.flat(L([(x + 6, 55 + dy), (x + 6, 56 + dy)], 1), OUTLINE)  # tabi split toe
        low.dot(x, 54 + dy, STEEL_D)
    # ---- ponytail: ONE high tail with volume, clumped strands, a crisp lit rim, a pointed tip; it lags the head
    tie = (29, 5)
    pt = strand(tie, (13 - 3 * mv, -13), (-3 - 4 * mv, 8), (3 - 5 * mv, 36 - 3 * mv), t, 5.0, k=2.0, lag=0.8, n=18)
    wid = [4, 8, 10, 11, 11, 10, 10, 9, 9, 8, 7, 7, 6, 5, 4, 3, 2, 1.5, 1]
    lw, rw = bandw(pt, wid)
    up.part(P(ipts(lw + rw[::-1])), HAIR_A)
    outer, inner = (lw, rw) if sum(x + y for x, y in lw) < sum(x + y for x, y in rw) else (rw, lw)
    n = len(pt)
    up.flat(L(ipts(outer[1:n - 2]), 1), STEEL_D)  # crisp lit rim along the outer edge
    up.flat(L(ipts(lerp2(outer, inner, 0.28)[3:n - 3]), 1), BLUE)  # lit strand cluster
    up.flat(L(ipts(lerp2(outer, inner, 0.55)[4:n - 4]), 1), OUTLINE)  # gap between clusters
    up.flat(L(ipts(lerp2(outer, inner, 0.7)[5:n - 6]), 1), BLUE)
    # ---- scarf tails: two slim tapering cloth tails with an S-wave, the second lagging the first
    t1 = strand((23, 37), (10, 35 - 2 * mv), (2, 41 - 3 * mv), (-7, 38 - 4 * mv), t, 6.0, k=2.6, lag=0.0, n=18)
    t2 = strand((23, 39), (12, 45), (4, 50 - 2 * mv), (-4, 54 - 4 * mv), t, 5.5, k=2.6, lag=1.0, n=18)
    ribbon(up, t2, 4.5, 2.5, RED)
    ribbon(up, t1, 5.0, 3.0, RED)
    across(up, t1, 13, 2.2, GOLD)
    across(up, t1, 14, 2.2, OCHRE_D)
    across(up, t2, 13, 2.0, GOLD)
    # obi bow behind her hip
    bw = sw_(t, 1.0, 2)
    up.part(P([(21, 42), (12, 39 + bw), (10, 44 + bw), (15, 46), (21, 45)]), RED)
    up.part(P([(21, 44), (14, 49 + bw), (16, 53 + bw), (22, 47)]), RED)
    up.flat(L([(13, 41 + bw), (19, 43)], 1), ORANGE)
    # ---- back arm: gold bracer
    ax = g.ARM_X[0]
    arm(up, ax, NAVY, SKIN)
    up.flat(R((ax, 39, ax + 5, 41)), GOLD)
    up.flat(R((ax, 39, ax + 5, 39)), YELLOW)
    up.flat(R((ax, 41, ax + 5, 41)), OCHRE_D)
    # ---- fitted navy top over a short, split hem
    flare = [(20, 44), (44, 44), (45, 49), (42, 50 + sw_(t, 1.0, 1)), (37, 48), (32, 50), (27, 48), (22, 50 - sw_(t, 0.5, 1)), (19, 48)]
    up.part(lambda d, f: (d.rounded_rectangle(BODY, 3, f), d.polygon(flare, f)), NAVY)
    up.flat(L([(21, 39), (21, 47)], 1), BLUE)  # lit left edge
    up.flat(L([(23, 38), (27, 38)], 1), BLUE)
    up.dither(R((36, 39, 44, 48)), SHADOW, "check", only_on=NAVY)
    # kimono crossover: right panel over left, a clean V
    up.flat(L([(25, 38), (32, 43)], 1), SHADOW)
    up.flat(L([(41, 38), (33, 43)], 1), SHADOW)
    up.flat(L([(26, 38), (32, 42)], 1), BLUE)
    up.flat(L([(33, 39), (33, 43)], 1), SHADOW)
    # red obi, gold buckle
    up.part(R((19, 43, 45, 46)), RED, line=False)
    up.flat(R((19, 43, 45, 43)), ORANGE)
    up.flat(R((19, 46, 45, 46)), MAROON)
    up.part(RR((29, 42, 36, 47), 2), GOLD)
    up.flat(R((30, 43, 32, 43)), YELLOW)
    up.flat(R((32, 45, 34, 46)), OCHRE_D)
    # ---- neck scarf: a snug wrap with a knot at the back of her neck
    up.part(RR((19, 34, 46, 38), 2), RED)
    up.flat(L([(22, 35), (36, 35)], 1), ORANGE)
    up.flat(L([(22, 37), (44, 37)], 1), MAROON)
    up.part(E((16, 34, 24, 41)), RED)
    up.flat(L([(18, 36), (22, 36)], 1), ORANGE)
    up.flat(L([(19, 39), (23, 40)], 1), MAROON)
    # ---- front arm: gold bracer
    fx = g.ARM_X[1]
    arm(up, fx, NAVY, SKIN)
    up.flat(R((fx, 39, fx + 5, 41)), GOLD)
    up.flat(R((fx, 39, fx + 5, 39)), YELLOW)
    up.flat(R((fx, 41, fx + 5, 41)), OCHRE_D)
    # ---- thigh kunai holster on the outer (front) leg, drawn on the body so it sits over the hem; handle sticks out
    up.part(P([(39, 48), (44, 49), (44, 54), (41, 55), (39, 52)]), BROWN)
    up.flat(L([(39, 49), (44, 50)], 1), OCHRE_D)
    up.dot(41, 50, GOLD)
    up.flat(L([(42, 49), (45, 46)], 1), RED)
    disc(up, 46, 45, 2, GOLD)
    up.dot(46, 45, OUTLINE)
    # ---- head
    up.part(lambda d, f: (d.ellipse((16, 5, 50, 36), f), d.polygon(
        [(16, 20), (14, 30), (18, 28), (19, 36), (22, 31), (24, 20)], f)), HAIR_A)
    up.part(RR(FACE, FACE_R), SKIN)
    up.flat(L([(26, 35), (42, 36)], 1), SKIN_D)
    up.part(P([(46, 14), (51, 17), (52 + sw_(t, 1.0, 1) + (1 if mv else 0), 28), (49, 26), (49, 31), (46, 27)]), HAIR_A, shade=False)
    up.part(P([(19, 11), (49, 11), (50, 17), (45, 14), (42, 18), (37, 14), (33, 18), (29, 14), (25, 17), (22, 16), (19, 18)]),
            HAIR_A, shade=False)
    up.flat(L([(30, 9), (41, 8)], 1), STEEL_D)
    up.dot(46, 12, STEEL_D)
    up.part(RR((26, 2, 33, 8), 2), RED)  # tie
    up.dot(28, 4, ORANGE)
    fox_mask(up, 15, 16)
    kunai_pin(up, (39, 0), (34, 3), (24, 8))  # hairpin through the tie
    # eyes: orange iris with a bright lower rim, a heavy top lid and a lash flick with a red tip
    big_eyes(up, g.EYES_Y - 1, g.EYES_X, ORANGE, h=6)
    for x in g.EYES_X:
        up.flat(R((x - 1, 20, x + 3, 20)), OUTLINE)
        up.flat(R((x + 3, 19, x + 4, 19)), OUTLINE)
        up.dot(x + 5, 18, OUTLINE)
        up.dot(x + 5, 19, RED)
        up.dot(x + 1, 26, YELLOW)
        up.dot(x + 2, 26, YELLOW)
    g.face(up, g.BLUSH, None)
    # confident smirk with crimson lips: upper lip, fuller lower lip with a highlight, one raised corner
    up.flat(R((37, 30, 40, 30)), MAROON)
    up.flat(R((37, 31, 39, 31)), RED)
    up.dot(38, 31, ORANGE)
    up.dot(41, 29, MAROON)


# ==================================================================================================================================
def frame(build, t, step=None):
    dy = IDLE_BOB[t] if step is None else g.WALK_BOB[step]
    low, up = Big(PAD, PAD), Big(PAD, PAD + UPPER_DY + dy)
    build(low, up, t, step)
    return compose(low, up)


def nn(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def floor_bg(w, h):
    tiles = Image.open(ROOT / "assets" / "arenas" / "pit_tiles.png").convert("RGBA")
    t = tiles.height
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, t):
        for x in range(0, w, t):
            n = (x // t + y // t) % 2
            out.paste(tiles.crop((n * t, 0, n * t + t, t)), (x, y))
    return out


def scale_sheet(out_dir):
    """1x on an arena floor beside Sakura, Bolt and the current Shade, then the new Shade at 2x."""
    def ref(name):
        return Image.open(ROOT / "assets" / "sprites" / f"{name}.png").convert("RGBA").crop((0, 0, CELL, CELL))
    figs = [ref("sakura"), ref("bolt"), ref("flicker"), frame(build_a, 0)]
    w = len(figs) * (CELL + 4) + 4
    row = floor_bg(w, CELL + 8)
    for i, f in enumerate(figs):
        row.alpha_composite(f, (4 + i * (CELL + 4), 4))
    big = floor_bg(w, 2 * CELL + 8)
    big.alpha_composite(nn(figs[3], 2), (4, 4))
    big.alpha_composite(nn(figs[2], 2), (4 + 2 * CELL + 4, 4))
    out = Image.new("RGBA", (w, 3 * CELL + 20), (24, 24, 32, 255))
    out.alpha_composite(row, (0, 0))
    out.alpha_composite(big, (0, CELL + 12))
    out.convert("RGB").save(out_dir / "shade_A_scale.png")


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT
    idle = [frame(build_a, t) for t in range(4)]
    walk = [frame(build_a, t, step) for t, step in ((1, 1), (3, 5))]
    k = 6
    bg = (46, 44, 50, 255)
    crop = (0, 8, CELL, CELL - 8)  # trim the empty rows above and below
    tw, th = CELL * k, (CELL - 16) * k
    sheet = Image.new("RGBA", (3 * tw + 4 * 8, 2 * (th + 8) + 8), (24, 24, 32, 255))
    for i, f in enumerate(idle[:2] + walk[:1] + idle[2:] + walk[1:]):
        tile = Image.new("RGBA", (tw, th), bg)
        tile.alpha_composite(nn(f.crop(crop), k))
        sheet.alpha_composite(tile, (8 + (i % 3) * (tw + 8), 8 + (i // 3) * (th + 8)))
    assert all(f.getpixel((0, y))[3] == 0 for f in idle + walk for y in range(CELL)), 'art clipped at the cell edge'
    sheet.convert("RGB").save(out_dir / "shade_A_polish.png")
    scale_sheet(out_dir)


if __name__ == "__main__":
    main()
