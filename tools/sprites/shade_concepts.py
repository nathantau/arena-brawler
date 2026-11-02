"""Shade (id `flicker`) redesign concept A, "Crimson kunoichi" (picked from three directions). Design stage only: nothing is
written into assets/. Drawn at the game's cell size (96 px) with the art-box helpers from generate.py: a long red scarf with two
slim tails as her silhouette hook, one high volumetric ponytail with a kunai hairpin, a festival fox mask on the side of her head,
crimson lips, navy top with a kimono crossover, red obi, gold bracers, thigh holster, grey shin wraps.
Run: tools/sprites/.venv/bin/python tools/sprites/shade_concepts.py [out_dir]
Output: shade_A_v2.png (x6: rows = hair options H1 ponytail / H2 asymmetric bob / H3 twin low tails, each 2 idle + 2 walking
frames) and shade_A_v2_scale.png (1x on an arena floor beside Sakura and Bolt, then 2x) in the repo root (or out_dir). Only palette colours are used."""
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
    """A festival fox mask pushed up on the side of her head (~30% bigger than round 2): symmetric ears with red tips,
    mirrored eye slits, whiskers, forehead mark, nose, and a tiny tie cord going back into her hair. Axis at x = ox + 4.5."""
    m = lambda x: 2 * ox + 9 - x  # mirror about the mask's axis
    ear = [(ox - 3, oy + 1), (ox - 3, oy - 9), (ox + 3, oy - 3)]
    c.part(P(ear), WHITE)
    c.part(P([(m(x), y) for x, y in ear]), WHITE)
    c.part(lambda d, f: (d.ellipse((ox - 4, oy - 4, ox + 13, oy + 10), f),
                         d.polygon([(ox - 1, oy + 6), (ox + 4, oy + 13), (ox + 5, oy + 13), (ox + 10, oy + 6)], f)), WHITE)
    for x in (ox - 2, m(ox - 2)):  # red ear tips + inner ear
        c.dot(x, oy - 8, RED)
        c.dot(x, oy - 7, RED)
        c.dot(x, oy - 6, MAROON)
    for a, b in (((ox - 1, oy + 1), (ox + 2, oy + 3)), ((m(ox - 1), oy + 1), (m(ox + 2), oy + 3))):  # slanted eye slits
        c.flat(L([a, b], 1), OUTLINE)
    for a, b in (((ox - 3, oy + 6), (ox + 1, oy + 5)), ((ox - 3, oy + 8), (ox, oy + 7))):  # cheek whiskers, mirrored
        c.flat(L([a, b], 1), RED)
        c.flat(L([(m(a[0]), a[1]), (m(b[0]), b[1])], 1), RED)
    c.flat(R((ox + 4, oy - 3, ox + 5, oy)), RED)  # forehead mark
    c.dot(ox + 4, oy - 4, RED)
    c.dot(ox + 4, oy + 11, OUTLINE)  # nose
    c.dot(ox + 5, oy + 11, OUTLINE)
    c.flat(L([(ox, oy - 3), (ox + 1, oy - 4), (ox + 2, oy - 5)], 1), STEEL)  # lit rim, top left
    c.dot(ox - 3, oy - 1, STEEL)
    # tie cord: a red thread curling round the back of her head, with a gold bead
    c.flat(L([(ox - 4, oy + 3), (ox - 6, oy + 6), (ox - 5, oy + 9)], 1), RED)
    c.dot(ox - 5, oy + 9, GOLD)


def build_a(low, up, t, step=None, hair="H1"):
    mv = 1.0 if step is not None else 0.0  # walking: tails and hair stream further back
    # ---- legs: navy trousers, light grey shin wraps with wrap lines, a thigh strap, dark split-toe tabi
    for x, dy in legs(low, NAVY, SHADOW, step):
        low.flat(L([(x + 1, 46 + dy), (x + 1, 49 + dy)], 1), BLUE)
        low.flat(R((x, 50 + dy, x + 5, 50 + dy)), BROWN)
        low.dot(x + 2, 50 + dy, GOLD)
        low.flat(R((x, 51 + dy, x + 5, 53 + dy)), STEEL)
        low.flat(R((x, 53 + dy, x + 5, 53 + dy)), STEEL_D)
        low.flat(L([(x, 52 + dy), (x + 5, 51 + dy)], 1), WHITE)
        low.flat(L([(x, 53 + dy), (x + 5, 52 + dy)], 1), STEEL_D)
        low.flat(L([(x + 6, 55 + dy), (x + 6, 56 + dy)], 1), OUTLINE)
        low.dot(x, 54 + dy, STEEL_D)
    # ---- back hair
    if hair == "H1":  # ONE high ponytail with volume, clumped strands, a crisp lit rim, a pointed tip; it lags the head
        pt = strand((29, 5), (13 - 3 * mv, -13), (-3 - 4 * mv, 8), (3 - 5 * mv, 36 - 3 * mv), t, 5.0, k=2.0, lag=0.8, n=18)
        wid = [4, 8, 10, 11, 11, 10, 10, 9, 9, 8, 7, 7, 6, 5, 4, 3, 2, 1.5, 1]
        lw, rw = bandw(pt, wid)
        up.part(P(ipts(lw + rw[::-1])), HAIR_A)
        outer, inner = (lw, rw) if sum(x + y for x, y in lw) < sum(x + y for x, y in rw) else (rw, lw)
        n = len(pt)
        up.flat(L(ipts(outer[1:n - 2]), 1), STEEL_D)
        up.flat(L(ipts(lerp2(outer, inner, 0.28)[3:n - 3]), 1), BLUE)
        up.flat(L(ipts(lerp2(outer, inner, 0.55)[4:n - 4]), 1), OUTLINE)
        up.flat(L(ipts(lerp2(outer, inner, 0.7)[5:n - 6]), 1), BLUE)
    elif hair == "H3":  # twin low tails: this one hangs behind her on the near side
        pt = strand((22, 27), (4 - 2 * mv, 30), (11 - 3 * mv, 43), (5 - 4 * mv, 54), t, 3.5, k=2.2, lag=0.8, n=16)
        lw, rw = bandw(pt, [5, 8, 9, 9, 9, 8, 8, 7, 7, 6, 5, 4, 3, 3, 2, 1.5, 1])
        up.part(P(ipts(lw + rw[::-1])), HAIR_A)
        outer, inner = (lw, rw) if sum(x + y for x, y in lw) < sum(x + y for x, y in rw) else (rw, lw)
        n = len(pt)
        up.flat(L(ipts(outer[1:n - 2]), 1), STEEL_D)
        up.flat(L(ipts(lerp2(outer, inner, 0.3)[3:n - 3]), 1), BLUE)
        up.flat(L(ipts(lerp2(outer, inner, 0.6)[4:n - 5]), 1), OUTLINE)
        tx, ty = pt[2]
        up.part(RR((round(tx) - 2, round(ty) - 2, round(tx) + 2, round(ty) + 2), 1), RED)  # tie
        up.dot(round(tx) - 1, round(ty) - 1, ORANGE)
    # ---- scarf: a snug neck wrap with two SHORT slim tails from the knot, an S-wave, the second lagging; gold bands
    t1 = strand((22, 37), (16, 34 - 1 * mv), (10 - 2 * mv, 39 - 2 * mv), (3 - 3 * mv, 37 - 3 * mv), t, 3.5, k=2.6, lag=0.0, n=12)
    t2 = strand((22, 39), (17, 43), (12 - 1 * mv, 44 - mv), (6 - 3 * mv, 48 - 2 * mv), t, 3.0, k=2.6, lag=1.0, n=12)
    ribbon(up, t2, 4.5, 3.0, RED)
    ribbon(up, t1, 5.0, 3.4, RED)
    across(up, t1, 8, 1.8, GOLD)
    across(up, t2, 8, 1.6, GOLD)
    # obi bow behind her hip (small)
    bw = sw_(t, 1.0, 1)
    up.part(P([(21, 43), (15, 41 + bw), (14, 45 + bw), (18, 46), (21, 45)]), RED)
    up.part(P([(21, 44), (16, 48 + bw), (18, 51 + bw), (22, 47)]), RED)
    # ---- back arm: gold bracer
    ax = g.ARM_X[0]
    arm(up, ax, NAVY, SKIN)
    up.flat(R((ax, 39, ax + 5, 41)), GOLD)
    up.flat(R((ax, 39, ax + 5, 39)), YELLOW)
    up.flat(R((ax, 41, ax + 5, 41)), OCHRE_D)
    # ---- fitted navy top over a short, split hem
    flare = [(20, 44), (44, 44), (45, 49), (42, 50 + sw_(t, 1.0, 1)), (37, 48), (32, 50), (27, 48), (22, 50 - sw_(t, 0.5, 1)), (19, 48)]
    up.part(lambda d, f: (d.rounded_rectangle(BODY, 3, f), d.polygon(flare, f)), NAVY)
    up.flat(L([(21, 39), (21, 47)], 1), BLUE)
    up.flat(L([(23, 38), (27, 38)], 1), BLUE)
    up.dither(R((36, 39, 44, 48)), SHADOW, "check", only_on=NAVY)
    up.flat(L([(25, 38), (32, 43)], 1), SHADOW)  # kimono crossover V
    up.flat(L([(41, 38), (33, 43)], 1), SHADOW)
    up.flat(L([(26, 38), (32, 42)], 1), BLUE)
    up.flat(L([(33, 39), (33, 43)], 1), SHADOW)
    up.part(R((19, 43, 45, 46)), RED, line=False)  # red obi, gold buckle
    up.flat(R((19, 43, 45, 43)), ORANGE)
    up.flat(R((19, 46, 45, 46)), MAROON)
    up.part(RR((29, 42, 36, 47), 2), GOLD)
    up.flat(R((30, 43, 32, 43)), YELLOW)
    up.flat(R((32, 45, 34, 46)), OCHRE_D)
    up.part(RR((19, 34, 46, 38), 2), RED)  # neck scarf
    up.flat(L([(22, 35), (36, 35)], 1), ORANGE)
    up.flat(L([(22, 37), (44, 37)], 1), MAROON)
    up.part(E((17, 34, 25, 41)), RED)  # the knot the tails come from
    up.flat(L([(19, 36), (23, 36)], 1), ORANGE)
    up.flat(L([(20, 39), (24, 40)], 1), MAROON)
    # ---- front arm: gold bracer
    fx = g.ARM_X[1]
    arm(up, fx, NAVY, SKIN)
    up.flat(R((fx, 39, fx + 5, 41)), GOLD)
    up.flat(R((fx, 39, fx + 5, 39)), YELLOW)
    up.flat(R((fx, 41, fx + 5, 41)), OCHRE_D)
    # ---- thigh kunai holster (on the body so it sits over the hem; handle sticks out)
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
    if hair == "H2":  # asymmetric: swept fringe, one long lock down the far side
        fringe = [(19, 11), (49, 11), (50, 15), (44, 14), (39, 17), (34, 15), (29, 19), (25, 17), (21, 22), (19, 18)]
    else:
        fringe = [(19, 11), (49, 11), (50, 17), (45, 14), (42, 18), (37, 14), (33, 18), (29, 14), (25, 17), (22, 16), (19, 18)]
    if hair == "H2":
        lk = strand((48, 15), (54, 22), (49, 33), (53, 47), t, 2.0, k=2.0, lag=0.6, n=14)
        lw, rw = bandw(lk, [5, 7, 7, 7, 7, 6, 6, 6, 5, 5, 4, 3, 2, 1.5, 1])
        up.part(P(ipts(lw + rw[::-1])), HAIR_A, shade=False)
        up.flat(L(ipts(lw[1:-3]), 1), STEEL_D)
        bx, by = lk[6]
        up.part(RR((round(bx) - 2, round(by) - 1, round(bx) + 2, round(by) + 1), 1), RED)
        up.dot(round(lk[-1][0]), round(lk[-1][1]) + 1, GOLD)
    elif hair == "H3":  # twin low tails: the far one hangs in front of her shoulder
        lk = strand((48, 21), (54, 28), (50, 39), (54, 51), t, 2.5, k=2.2, lag=0.2, n=16)
        lw, rw = bandw(lk, [5, 8, 9, 9, 9, 8, 8, 7, 7, 6, 5, 4, 3, 3, 2, 1.5, 1])
        up.part(P(ipts(lw + rw[::-1])), HAIR_A, shade=False)
        up.flat(L(ipts(lw[1:-3]), 1), STEEL_D)
        up.flat(L(ipts(lerp2(lw, rw, 0.7)[3:-5]), 1), BLUE)
        tx, ty = lk[2]
        up.part(RR((round(tx) - 2, round(ty) - 2, round(tx) + 2, round(ty) + 2), 1), RED)
        up.dot(round(tx) - 1, round(ty) - 1, ORANGE)
    else:
        up.part(P([(46, 14), (51, 17), (52 + sw_(t, 1.0, 1) + (1 if mv else 0), 28), (49, 26), (49, 31), (46, 27)]), HAIR_A, shade=False)
    up.part(P(fringe), HAIR_A, shade=False)
    up.flat(L([(30, 9), (41, 8)], 1), STEEL_D)
    up.dot(46, 12, STEEL_D)
    if hair == "H1":
        up.part(RR((26, 2, 33, 8), 2), RED)  # tie
        up.dot(28, 4, ORANGE)
    fox_mask(up, 13, 17)
    if hair == "H1":
        kunai_pin(up, (39, 0), (34, 3), (24, 8))
    else:
        kunai_pin(up, (40, 1), (36, 4), (30, 7))
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
    # lips: bright crimson upper, darker lower with one gloss pixel, a raised smirk corner
    up.flat(R((36, 30, 39, 30)), RED)
    up.flat(R((37, 31, 39, 31)), MAROON)
    up.dot(38, 31, PINK)
    up.dot(40, 29, MAROON)
    up.dot(35, 31, SKIN_D)


# ==================================================================================================================================
def frame(build, t, step=None, **kw):
    dy = IDLE_BOB[t] if step is None else g.WALK_BOB[step]
    low, up = Big(PAD, PAD), Big(PAD, PAD + UPPER_DY + dy)
    build(low, up, t, step, **kw)
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


HAIRS = [("H1  high ponytail", "H1"), ("H2  asymmetric bob + long side lock", "H2"), ("H3  twin low tails", "H3")]
SHOTS = ((0, None), (2, None), (1, 1), (3, 5))  # two idle + two walking frames


def scale_sheet(out_dir):
    """1x on an arena floor beside Sakura and Bolt, then the three hair options at 2x."""
    def ref(name):
        return Image.open(ROOT / "assets" / "sprites" / f"{name}.png").convert("RGBA").crop((0, 0, CELL, CELL))
    mine = [frame(build_a, 0, hair=h) for _, h in HAIRS]
    figs = [ref("sakura"), ref("bolt")] + mine
    w = 3 * (2 * CELL + 4) + 4
    row = floor_bg(w, CELL + 8)
    x0 = (w - len(figs) * (CELL + 4)) // 2
    for i, f in enumerate(figs):
        row.alpha_composite(f, (x0 + i * (CELL + 4), 4))
    big = floor_bg(w, 2 * CELL + 8)
    for i, f in enumerate(mine):
        big.alpha_composite(nn(f, 2), (4 + i * (2 * CELL + 4), 4))
    out = Image.new("RGBA", (w, 3 * CELL + 20), (24, 24, 32, 255))
    out.alpha_composite(row, (0, 0))
    out.alpha_composite(big, (0, CELL + 12))
    out.convert("RGB").save(out_dir / "shade_A_v2_scale.png")


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT
    k, bg = 6, (46, 44, 50, 255)
    crop = (0, 8, 78, CELL - 8)
    tw, th = (crop[2] - crop[0]) * k, (crop[3] - crop[1]) * k
    sheet = Image.new("RGBA", (4 * (tw + 8) + 8, 3 * (th + 30) + 8), (24, 24, 32, 255))
    for r, (name, h) in enumerate(HAIRS):
        y = 8 + r * (th + 30)
        ImageDraw.Draw(sheet).text((10, y + 6), name, fill=(240, 240, 230, 255))
        for i, (t, step) in enumerate(SHOTS):
            f = frame(build_a, t, step, hair=h)
            assert all(f.getpixel((0, yy))[3] == 0 for yy in range(CELL)), f"{h} clipped at the cell edge"
            tile = Image.new("RGBA", (tw, th), bg)
            tile.alpha_composite(nn(f.crop(crop), k))
            sheet.alpha_composite(tile, (8 + i * (tw + 8), y + 22))
    sheet.convert("RGB").save(out_dir / "shade_A_v2.png")
    scale_sheet(out_dir)


if __name__ == "__main__":
    main()
