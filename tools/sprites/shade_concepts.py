"""Shade (id `flicker`) redesign concepts. Design stage only: nothing is written into assets/.
Three directions, 4 idle frames each, drawn at the game's cell size (96 px) with the art-box helpers from generate.py:
  A  Crimson kunoichi   (long red scarf, high ponytail with a kunai hairpin, fox half-mask, thigh holsters)
  B  Moon assassin      (silver braid, indigo + cyan trim, crescent forehead plate, tattered cape, chakram on her back)
  C  Street ninja       (cropped techwear jacket, LED respirator, asymmetric hair streak, kunai on a chain)
Run: tools/sprites/.venv/bin/python tools/sprites/shade_concepts.py [out_dir]
Output: shade_concepts.png (x6 contact sheet) and shade_concepts_scale.png (1x on an arena floor beside Sakura, Bolt and the
current Shade) in the repo root (or out_dir). Only palette colours are used."""
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


def frame(build, t):
    dy = IDLE_BOB[t]
    low, up = Big(PAD, PAD), Big(PAD, PAD + UPPER_DY + dy)
    build(low, up, t)
    return compose(low, up)


# ==================================================================================================================================
# shared cloth / hair helpers
# ==================================================================================================================================
def bandw(pts, widths):
    """Polygon along `pts` with a width per point (volume: hair bulges then tapers)."""
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


def ribbon(c, pts, w0, w1, base, frayed=True, folds=True):
    """A cloth tail along `pts`: lit upper edge, dark underside, broken fold line, frayed (jagged) end."""
    n = len(pts)
    left, right = bandw(pts, [w0 + (w1 - w0) * i / (n - 1) for i in range(n)])
    (x, y), (px_, py_) = pts[-1], pts[-2]
    dx, dy = x - px_, y - py_
    ln = math.hypot(dx, dy) or 1
    tx, ty = dx / ln, dy / ln
    nx, ny = -ty, tx
    h = w1 / 2
    tip = []
    if frayed:
        for a, b in ((0.55, 2.5), (0.2, -1.0), (-0.15, 4.0), (-0.5, -0.5), (-0.75, 2.0)):
            tip.append((x + nx * h * a + tx * b, y + ny * h * a + ty * b))
    poly = left + tip + right[::-1]
    c.part(P(ipts(poly)), base)
    top, bot = (left, right) if sum(p[1] for p in left) < sum(p[1] for p in right) else (right, left)
    c.flat(L(ipts(top[1:-1]), 1), LIGHTER[base])
    c.flat(L([(a, b + 1) for a, b in ipts(bot[1:-1])], 1), DARKER[base])
    if folds:
        mid = [((a[0] + b[0]) / 2 + (bb[0] - a[0]) * 0.0, (a[1] + b[1]) / 2 + 1) for a, b, bb in zip(left, right, left)]
        for i in range(2, n - 2, 3):
            c.flat(L(ipts(mid[i:i + 2]), 1), DARKER[base])


def lock_highlight(c, pts, off, color):
    c.flat(L([(round(x + off[0]), round(y + off[1])) for x, y in pts], 1), color)


# ==================================================================================================================================
# A  Crimson kunoichi
# ==================================================================================================================================
HAIR_A = SHADOW  # black hair: rim-lit by STEEL_D, shades to OUTLINE
GOLD = OCHRE


def kunai_pin(c, ring, base, tip):
    """A kunai hairpin: gold ring, red grip, leaf blade."""
    c.flat(L([ring, base], 1), RED)
    mx, my = (base[0] + tip[0]) // 2, (base[1] + tip[1]) // 2
    c.part(P([(base[0], base[1] - 2), (mx, my - 2), tip, (mx, my + 2), (base[0], base[1] + 1)]), STEEL)
    c.flat(L([(base[0] + 1, base[1] - 1), (mx + 1, my - 1)], 1), WHITE)
    disc(c, ring[0], ring[1], 2, GOLD)
    c.dot(ring[0], ring[1], OUTLINE)


def fox_mask(c, ox, oy):
    """A festival fox mask pushed up and tilted on the side of her head."""
    c.part(P([(ox - 1, oy + 1), (ox - 3, oy - 6), (ox + 3, oy - 2)]), WHITE)  # ears
    c.part(P([(ox + 5, oy - 2), (ox + 9, oy - 7), (ox + 10, oy + 1)]), WHITE)
    c.dot(ox - 2, oy - 3, RED)
    c.dot(ox - 2, oy - 2, RED)
    c.dot(ox + 8, oy - 4, RED)
    c.dot(ox + 8, oy - 3, RED)
    c.part(lambda d, f: (d.ellipse((ox - 3, oy - 3, ox + 10, oy + 8), f), d.polygon([(ox - 2, oy + 4), (ox + 3, oy + 10), (ox + 8, oy + 5)], f)), WHITE)
    c.flat(L([(ox, oy + 1), (ox + 2, oy + 2)], 1), OUTLINE)  # slanted eye slits
    c.flat(L([(ox + 6, oy + 2), (ox + 8, oy + 1)], 1), OUTLINE)
    c.flat(L([(ox - 2, oy + 4), (ox + 1, oy + 5)], 1), RED)  # cheek marks
    c.flat(L([(ox + 7, oy + 5), (ox + 9, oy + 4)], 1), RED)
    c.flat(L([(ox + 1, oy), (ox + 4, oy - 1)], 1), RED)  # forehead mark
    c.dot(ox + 3, oy + 8, OUTLINE)  # nose
    c.dot(ox + 4, oy + 8, OUTLINE)
    c.dot(ox + 2, oy - 1, STEEL)


def build_a(low, up, t):
    # ---- legs: navy trousers, light grey shin wraps, a strap with a gold stud, kunai holster on the front thigh
    for x, dy in legs(low, NAVY, SHADOW, None):
        low.flat(L([(x + 1, 47 + dy), (x + 1, 50 + dy)], 1), BLUE)
        low.flat(R((x, 50 + dy, x + 5, 50 + dy)), BROWN)
        low.dot(x + 2, 50 + dy, GOLD)
        low.flat(R((x, 51 + dy, x + 5, 53 + dy)), STEEL)
        low.flat(R((x, 53 + dy, x + 5, 53 + dy)), STEEL_D)
        low.dot(x, 51 + dy, WHITE)
        low.flat(L([(x + 1, 52 + dy), (x + 4, 51 + dy)], 1), WHITE)
    low.part(P([(39, 49), (43, 50), (43, 55), (40, 56), (39, 53)]), BROWN)
    low.flat(L([(40, 50), (42, 50)], 1), GOLD)
    low.flat(L([(41, 49), (42, 46)], 1), RED)
    low.dot(42, 45, GOLD)

    # ---- ponytail: ONE high tail with volume, tapering in clumps, lagging the head
    tie = (29, 5)
    pt = strand(tie, (13, -13), (-3, 8), (3, 36), t, 6.0, k=2.0, lag=0.8, n=16)
    lw, rw = bandw(pt, [5, 9, 11, 11, 10, 10, 9, 9, 8, 7, 7, 6, 5, 4, 3, 2, 1])
    up.part(P(ipts(lw + rw[::-1])), HAIR_A)
    # clumps: two lighter strand lines inside the mass, a bright rim on the top edge, a split tip
    lock_highlight(up, [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in zip(lw[1:12], rw[1:12])], (0, -1), STEEL_D)
    lock_highlight(up, [((a[0] * 2 + b[0]) / 3, (a[1] * 2 + b[1]) / 3) for a, b in zip(lw[3:14], rw[3:14])], (0, 0), BLUE)
    up.flat(L(ipts(rw[2:10]), 1), OUTLINE)
    tip = pt[-1]
    up.part(P(ipts([(tip[0] - 2, tip[1] - 3), (tip[0] - 4 - sw_(t, 1.5, 2), tip[1] + 4), (tip[0], tip[1] - 1)])), HAIR_A, shade=False)
    # ---- scarf tails: two broad cloth tails with an S-wave (drawn over the ponytail)
    t1 = strand((23, 37), (9, 29), (-4, 49), (-19, 41), t, 7.0, k=3.4, lag=0.0, n=14)
    t2 = strand((23, 39), (11, 47), (2, 53), (-9, 58), t, 6.0, k=3.0, lag=0.9, n=14)
    ribbon(up, t2, 6, 5, RED)
    ribbon(up, t1, 7, 5, RED)
    across(up, t1, 9, 4, GOLD)
    across(up, t1, 10, 4, OCHRE_D)
    across(up, t2, 9, 3, GOLD)
    # obi bow behind her hip
    bw = sw_(t, 1.0, 2)
    up.part(P([(21, 42), (11, 38 + bw), (9, 44 + bw), (15, 46), (21, 45)]), RED)
    up.part(P([(21, 44), (13, 49 + bw), (15, 54 + bw), (22, 48)]), RED)
    up.flat(L([(12, 40 + bw), (19, 43)], 1), ORANGE)
    # ---- back arm: gold bracer
    ax = g.ARM_X[0]
    arm(up, ax, NAVY, SKIN)
    up.flat(R((ax, 39, ax + 5, 41)), GOLD)
    up.flat(R((ax, 39, ax + 5, 39)), YELLOW)
    up.flat(R((ax, 41, ax + 5, 41)), OCHRE_D)
    # ---- fitted navy top over a short flared hem
    flare = [(20, 44), (44, 44), (46, 50), (42, 52 + sw_(t, 1.0, 1)), (37, 49), (32, 52), (26, 49), (22, 52 - sw_(t, 0.5, 1)), (18, 50)]
    up.part(lambda d, f: (d.rounded_rectangle(BODY, 3, f), d.polygon(flare, f)), NAVY)
    up.flat(L([(21, 38), (21, 46)], 1), BLUE)  # lit left edge
    up.flat(L([(23, 35), (29, 34)], 1), BLUE)
    up.dither(R((35, 37, 44, 49)), SHADOW, "check", only_on=NAVY)
    up.flat(L([(26, 34), (33, 41)], 1), SHADOW)  # crossed collar
    up.flat(L([(41, 34), (33, 41)], 1), SHADOW)
    up.flat(L([(27, 35), (33, 41)], 1), BLUE)
    # red obi, a big gold-buckled knot
    up.part(R((19, 43, 45, 46)), RED, line=False)
    up.flat(R((19, 43, 45, 43)), ORANGE)
    up.flat(R((19, 46, 45, 46)), MAROON)
    up.part(RR((29, 42, 36, 47), 2), GOLD)
    up.flat(R((30, 43, 32, 43)), YELLOW)
    up.flat(R((32, 45, 34, 46)), OCHRE_D)
    # ---- neck scarf: a thick wrap with a knot on her far side
    up.part(RR((19, 34, 46, 39), 2), RED)
    up.flat(L([(22, 35), (36, 35)], 1), ORANGE)
    up.flat(L([(22, 38), (44, 38)], 1), MAROON)
    up.part(E((16, 34, 24, 41)), RED)
    up.flat(L([(18, 36), (22, 36)], 1), ORANGE)
    up.flat(L([(19, 39), (23, 40)], 1), MAROON)
    # ---- front arm + shoulder pad
    fx = g.ARM_X[1]
    arm(up, fx, NAVY, SKIN)
    up.flat(R((fx, 39, fx + 5, 41)), GOLD)
    up.flat(R((fx, 39, fx + 5, 39)), YELLOW)
    up.flat(R((fx, 41, fx + 5, 41)), OCHRE_D)
    # ---- head
    up.part(lambda d, f: (d.ellipse((16, 5, 50, 36), f), d.polygon(
        [(16, 20), (14, 30), (18, 28), (19, 36), (22, 31), (24, 20)], f)), HAIR_A)
    up.part(RR(FACE, FACE_R), SKIN)
    up.flat(L([(26, 35), (42, 36)], 1), SKIN_D)
    up.part(P([(46, 14), (51, 17), (52 + sw_(t, 1.0, 1), 28), (49, 26), (49, 31), (46, 27)]), HAIR_A, shade=False)
    up.part(P([(19, 11), (49, 11), (50, 17), (45, 14), (42, 18), (37, 14), (33, 18), (29, 14), (25, 17), (22, 16), (19, 18)]),
            HAIR_A, shade=False)
    up.flat(L([(28, 9), (40, 8)], 1), STEEL_D)
    up.dot(45, 12, STEEL_D)
    # tie + kunai hairpin through it
    up.part(RR((26, 2, 33, 8), 2), RED)
    up.dot(28, 4, ORANGE)
    kunai_pin(up, (15, 10), (21, 8), (37, 4))
    # fox mask on the side of her head, string round the back
    fox_mask(up, 17, 16)
    # eyes + soft little smile (no lower-face mask)
    big_eyes(up, g.EYES_Y - 1, g.EYES_X, ORANGE, h=6)
    for x in g.EYES_X:
        up.flat(R((x + 3, 19, x + 4, 19)), OUTLINE)
        up.dot(x + 5, 18, RED)
        up.dot(x + 4, 20, RED)
    g.face(up, g.BLUSH, None)
    up.flat(L([(36, 30), (37, 31), (39, 31), (40, 30)], 1), MAROON)


def sw_(t, lag, amp):
    return round(amp * phase(t, lag))


# ==================================================================================================================================
# B  Moon assassin
# ==================================================================================================================================
def crescent(c, cx, cy, r1, r2, dx, dy, col, rim=OUTLINE):
    """A crescent moon: the disc (cx, cy, r1) minus a disc offset by (dx, dy); lit at its top left, outlined."""
    ins = lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r1 * r1 and (x - cx - dx) ** 2 + (y - cy - dy) ** 2 > r2 * r2
    rr = int(r1) + 3
    cells = {(x, y) for x in range(cx - rr, cx + rr + 1) for y in range(cy - rr, cy + rr + 1) if ins(x, y)}
    for x, y in cells:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) not in cells:
                c.dot(nx, ny, rim)
    for x, y in cells:
        lit = (x - 1, y) not in cells or (x, y - 1) not in cells
        dark = (x + 1, y) not in cells or (x, y + 1) not in cells
        c.dot(x, y, LIGHTER[col] if lit else (DARKER[col] if dark else col))


def chakram(c, cx, cy, rot):
    """A sleek ring of three curved blades (a polished steel ring with hooked crescent blades sweeping round it)."""
    pol = lambda r, a: (cx + r * math.cos(a), cy + r * math.sin(a))
    for k in range(3):
        a = rot + k * 2 * math.pi / 3
        blade = [pol(9.5, a), pol(13, a + 0.35), pol(16, a + 0.85), pol(13.5, a + 1.0), pol(10.5, a + 0.75), pol(8.5, a + 0.45)]
        c.part(P(ipts(blade)), STEEL)
    c.part(E((cx - 10, cy - 10, cx + 10, cy + 10)), STEEL, line=False)
    for yy in range(cy - 9, cy + 10):  # hollow centre
        for xx in range(cx - 9, cx + 10):
            if (xx - cx) ** 2 + (yy - cy) ** 2 <= 52:
                c.px[xx + c.ox, yy + c.oy] = (0, 0, 0, 0)
    # polish: white glints on the upper-left rim, shaded lower-right, cyan edge glow inside the hole
    for a in [math.pi + 0.15 * k for k in range(1, 8)]:
        x, y = pol(9.2, a)
        c.dot(round(x), round(y), WHITE)
    for a in [0.25 * k for k in range(1, 6)]:
        x, y = pol(9.2, a)
        c.dot(round(x), round(y), STEEL_D)


def build_b(low, up, t):
    IND = VIOLET_D
    for x, dy in legs(low, IND, SHADOW, None):
        low.flat(L([(x + 4, 46 + dy), (x + 4, 52 + dy)], 1), TEAL_L)
        low.flat(R((x, 51 + dy, x + 5, 53 + dy)), STEEL)
        low.flat(R((x, 53 + dy, x + 5, 53 + dy)), STEEL_D)
        low.dot(x, 51 + dy, WHITE)
        low.flat(R((x + 5, 55 + dy, x + 7, 56 + dy)), TEAL_L)
    # ---- chakram on her back, slowly turning
    chakram(up, 9, 19, -t * math.pi / 6 + 0.5)
    # ---- short tattered cape behind the shoulders: flat indigo, one cyan hem line, ragged teeth
    cape = [(25, 34), (15, 35), (11, 42), (10 + sw_(t, 0.5, 1), 49), (14 + sw_(t, 0.8, 1), 46), (17 + sw_(t, 1, 2), 52),
            (21 + sw_(t, 1.2, 1), 47), (25 + sw_(t, 1.4, 2), 51), (29, 45), (31, 40)]
    up.part(P(cape), IND)
    up.flat(L([(13, 44), (11 + sw_(t, 0.5, 1), 49)], 1), TEAL_L)
    up.flat(L([(14, 37), (13, 41)], 1), VIOLET)
    # ---- braid: one smooth braid with cross-weave lines, a cyan tie and a tassel, swinging with lag
    br = strand((22, 26), (12, 31), (17, 44), (13, 56), t, 3.5, k=2.0, lag=0.8, n=16)
    lw, rw = bandw(br, [6 if i < 11 else 6 - (i - 10) for i in range(len(br))])
    up.part(P(ipts(lw + rw[::-1])), WHITE)
    for i in range(1, len(br) - 5, 2):
        up.flat(L(ipts([lw[i], rw[i + 1]]), 1), STEEL)
    up.flat(L(ipts(lw[1:12]), 1), WHITE)
    bx, by = br[-5]
    across(up, br, len(br) - 5, 3, TEAL_L, 2)
    ex, ey = br[-1]
    up.part(P(ipts([(ex - 1, ey), (ex + 2, ey), (ex + 3 + sw_(t, 1.5, 1), ey + 6), (ex - 3, ey + 6)])), TEAL_L)
    up.flat(L(ipts([(ex, ey + 2), (ex - 1, ey + 5)]), 1), WHITE)
    # ---- back arm
    ax = g.ARM_X[0]
    arm(up, ax, IND, SKIN)
    up.flat(R((ax, 39, ax + 5, 41)), STEEL)
    up.flat(R((ax, 41, ax + 5, 41)), STEEL_D)
    up.dot(ax, 39, WHITE)
    up.flat(R((ax, 40, ax + 5, 40)), TEAL_L)
    # ---- body: plain indigo with ONE cyan V trim, a moon-gem belt
    up.part(RR(BODY, 3), IND)
    up.flat(L([(21, 38), (21, 44)], 1), VIOLET)
    up.dither(R((36, 38, 43, 47)), OUTLINE, "check", only_on=IND)
    up.flat(L([(26, 35), (33, 43)], 1), TEAL_L)
    up.flat(L([(41, 35), (34, 43)], 1), TEAL)
    up.part(R((20, 44, 44, 46)), VIOLET, line=False)
    up.flat(R((20, 44, 44, 44)), VIOLET_L)
    up.flat(R((20, 46, 44, 46)), OUTLINE)
    up.part(RR((30, 43, 36, 47), 1), STEEL)
    up.flat(R((32, 44, 34, 46)), TEAL_L if t % 2 == 0 else WHITE)
    up.part(RR((21, 34, 45, 38), 2), VIOLET)
    up.flat(L([(23, 35), (30, 35)], 1), VIOLET_L)
    # ---- front arm + crescent pauldron
    fx = g.ARM_X[1]
    arm(up, fx, IND, SKIN)
    up.flat(R((fx, 39, fx + 5, 41)), STEEL)
    up.flat(R((fx, 41, fx + 5, 41)), STEEL_D)
    up.dot(fx, 39, WHITE)
    up.flat(R((fx, 40, fx + 5, 40)), TEAL_L)
    crescent(up, 45, 36, 5, 4, -1, 1, STEEL)
    # ---- head: silver hair, face, fringe, dark band and a BIG crescent plate cradling a cyan gem
    up.part(lambda d, f: (d.ellipse((16, 5, 50, 36), f), d.polygon(
        [(16, 20), (14, 28), (18, 27), (19, 33), (23, 28), (24, 20)], f)), WHITE)
    up.flat(L([(22, 8), (32, 6)], 1), STEEL)
    up.dither(R((18, 24, 24, 34)), STEEL, "check", only_on=WHITE)
    up.part(RR(FACE, FACE_R), SKIN)
    up.flat(L([(26, 35), (42, 36)], 1), SKIN_D)
    up.part(P([(46, 14), (51, 17), (52 + sw_(t, 1.0, 1), 29), (49, 27), (49, 32), (46, 27)]), WHITE, shade=False)
    up.flat(L([(50, 20), (51, 27)], 1), STEEL)
    up.part(P([(19, 12), (49, 12), (50, 17), (46, 15), (43, 18), (39, 15), (35, 18), (31, 15), (27, 17), (23, 15), (19, 18)]),
            WHITE, shade=False)
    up.flat(L([(21, 17), (24, 16)], 1), STEEL)
    up.part(P([(19, 10), (30, 8), (40, 8), (49, 10), (49, 14), (40, 12), (30, 12), (19, 15)]), IND, shade=False)
    up.flat(L([(21, 11), (28, 10)], 1), VIOLET_L)
    crescent(up, 35, 10, 7, 6, 0, -3, STEEL)
    up.flat(R((35, 6, 36, 7)), TEAL_L)
    up.dot(35, 6, WHITE)
    big_eyes(up, g.EYES_Y - 1, g.EYES_X, TEAL_L, h=6)
    for x in g.EYES_X:
        up.flat(R((x + 3, 19, x + 4, 19)), OUTLINE)
        up.dot(x + 5, 18, OUTLINE)
    up.dot(33, 29, TEAL_L)
    up.dot(34, 30, TEAL_L)
    up.flat(R((g.BLUSH[0], 30, g.BLUSH[0] + 1, 30)), PINK)
    up.flat(R((g.MOUTH[0], g.MOUTH[1], g.MOUTH[0] + 1, g.MOUTH[1])), MAROON)


# ==================================================================================================================================
# C  Street ninja: charcoal techwear, acid-lime accent
# ==================================================================================================================================
def build_c(low, up, t):
    JK, HAIR = STEEL_D, NAVY
    ACC, ACC2 = GREEN_L, GREEN
    # ---- legs: dark cargo pants (lit left edge, strap + lime tab, knee pad), white sneakers with lime soles
    for x, dy in legs(low, SHADOW, WHITE, None):
        low.flat(L([(x, 46 + dy), (x, 52 + dy)], 1), STEEL_D)
        low.flat(R((x, 50 + dy, x + 5, 50 + dy)), OUTLINE)
        low.dot(x + 3, 50 + dy, ACC)
        low.flat(R((x + 1, 52 + dy, x + 4, 53 + dy)), STEEL_D)
        low.flat(R((x + 1, 53 + dy, x + 4, 53 + dy)), STEEL)
        low.flat(R((x - 1, 57 + dy, x + 7, 57 + dy)), ACC)
        low.flat(R((x + 5, 55 + dy, x + 7, 55 + dy)), STEEL)
        low.flat(L([(x - 1, 55 + dy), (x + 1, 55 + dy)], 1), STEEL)
    low.part(RR((39, 49, 44, 54), 1), STEEL_D)
    low.flat(R((40, 50, 43, 50)), STEEL)
    low.dot(42, 52, ACC)
    # ---- long back lock of hair with a lime streak
    lock = strand((20, 14), (3, 20), (10, 34), (5, 50), t, 4.5, k=2.0, lag=0.8)
    lw, rw = bandw(lock, [10, 11, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1])
    up.part(P(ipts(lw + rw[::-1])), HAIR)
    up.flat(L(ipts([((a[0] * 2 + b[0]) / 3, (a[1] * 2 + b[1]) / 3) for a, b in zip(lw[1:11], rw[1:11])]), 1), ACC)
    up.flat(L(ipts([((a[0] + b[0]) / 2 - 1, (a[1] + b[1]) / 2) for a, b in zip(lw[1:7], rw[1:7])]), 1), BLUE)
    ax = g.ARM_X[0]
    arm(up, ax, JK, SKIN)
    up.flat(R((ax, 38, ax + 5, 39)), SHADOW)
    up.flat(R((ax, 37, ax + 5, 37)), STEEL)
    # ---- mesh top (black with silver mesh dots) and the cropped jacket
    up.part(RR(BODY, 3), OUTLINE)
    jacket = [(19, 36), (45, 36), (48, 40), (46, 44), (38, 44), (36, 46), (28, 46), (26, 44), (19, 44), (17, 40)]
    up.part(P(jacket), JK)
    up.dither(R((36, 38, 46, 44)), SHADOW, "check", only_on=JK)
    up.flat(L([(20, 38), (20, 43)], 1), STEEL)  # lit left edge
    up.flat(L([(22, 37), (29, 37)], 1), STEEL)
    # folds: a dark crease with a lit ridge beside it, following the cloth
    for (x0, y0, x1, y1) in ((26, 38, 28, 43), (40, 38, 38, 43)):
        up.flat(L([(x0, y0), (x1, y1)], 1), SHADOW)
        up.flat(L([(x0 - 1, y0 + 1), (x1 - 1, y1)], 1), STEEL)
    up.flat(L([(33, 37), (33, 45)], 1), SHADOW)  # zip
    up.flat(L([(32, 38), (32, 44)], 1), STEEL)
    up.flat(R((33, 38, 33, 39)), ACC)  # lime pull
    up.flat(R((28, 41, 31, 42)), SHADOW)  # chest pocket + lime tab
    up.dot(29, 41, ACC)
    up.dot(31, 45, ACC)  # hem toggles
    up.dot(37, 45, ACC)
    # high collar flaring up round the neck
    up.part(P([(19, 33), (24, 31), (26, 37), (22, 38), (18, 37)]), JK)
    up.part(P([(46, 33), (41, 31), (39, 37), (43, 38), (47, 37)]), JK)
    up.flat(L([(20, 33), (24, 32)], 1), STEEL)
    up.flat(L([(41, 32), (45, 33)], 1), STEEL)
    # ---- front arm: sleeve with a chain wrapped in diagonals round the forearm; the kunai swings from the wrist
    fx = g.ARM_X[1]
    arm(up, fx, JK, SKIN)
    up.flat(R((fx, 37, fx + 5, 37)), STEEL)
    for k in range(2):
        y = 37 + k * 3
        up.flat(L([(fx, y), (fx + 5, y + 2)], 1), WHITE)
        up.flat(L([(fx, y + 1), (fx + 5, y + 3)], 1), SHADOW)
    up.dot(fx + 5, 39, ACC)
    ch = strand((fx + 4, 43), (fx + 8, 47), (fx + 3, 52), (fx + 6, 56), t, 2.5, k=1.5, lag=0.4, n=8)
    for i, (x, y) in enumerate(ch[:-2]):
        up.dot(round(x), round(y), STEEL if i % 2 == 0 else STEEL_D)
    kx, ky = round(ch[-1][0]), round(ch[-1][1])
    up.part(P([(kx - 1, ky - 3), (kx + 1, ky - 3), (kx + 2, ky), (kx, ky + 4), (kx - 2, ky)]), STEEL)
    up.flat(L([(kx, ky - 2), (kx, ky + 2)], 1), WHITE)
    up.flat(R((kx - 1, ky - 4, kx + 1, ky - 4)), ACC)
    up.part(RR((42, 33, 49, 38), 2), JK)
    up.flat(R((43, 33, 46, 33)), STEEL)
    # ---- head: dark blue asymmetric hair, a long sweep on her left and a short undercut on the right
    up.part(lambda d, f: (d.ellipse((16, 5, 50, 36), f), d.polygon([(16, 20), (14, 28), (20, 26), (24, 20)], f)), HAIR)
    up.part(RR(FACE, FACE_R), SKIN)
    up.flat(L([(26, 35), (42, 36)], 1), SKIN_D)
    up.part(P([(19, 10), (49, 10), (50, 15), (44, 14), (36, 14), (31, 18), (26, 22), (23, 26), (23, 19), (19, 17)]), HAIR, shade=False)
    up.flat(L([(27, 20), (24, 25)], 1), ACC)
    up.flat(L([(29, 18), (26, 21)], 1), ACC2)
    up.flat(L([(22, 9), (34, 7)], 1), BLUE)
    up.flat(L([(40, 11), (47, 12)], 1), BLUE)
    up.part(E((21, 24, 26, 30)), SHADOW)  # headset + LED
    up.dot(23, 26, ACC if t % 2 == 0 else ACC2)
    big_eyes(up, g.EYES_Y - 1, g.EYES_X, ACC, h=6)
    up.flat(L([(g.EYES_X[1] - 1, 20), (g.EYES_X[1] + 4, 19)], 1), OUTLINE)
    mask = [(26, 31), (34, 31), (40, 30), (46, 31), (48, 34), (45, 37), (40, 38), (32, 38), (27, 37)]
    up.part(P(mask), STEEL_D)
    up.flat(L([(28, 33), (31, 33)], 1), STEEL)
    up.flat(L([(28, 35), (31, 35)], 1), SHADOW)
    up.flat(R((35, 34, 45, 34)), ACC if t % 4 != 3 else ACC2)
    up.flat(R((36, 33, 44, 33)), ACC2)
    up.dot(34, 34, WHITE)
    up.flat(R((26, 29, 27, 29)), PINK)



CONCEPTS = [("A  Crimson kunoichi", build_a), ("B  Moon assassin", build_b), ("C  Street ninja", build_c)]


def nn(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def floor_bg(w, h):
    tiles = Image.open(ROOT / "assets" / "arenas" / "pit_tiles.png").convert("RGBA")
    t = tiles.height
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, t):
        for x in range(0, w, t):
            out.paste(tiles.crop((((x // t + y // t) % 2) * t, 0, ((x // t + y // t) % 2) * t + t, t)), (x, y))
    return out


def scale_sheet(out_dir):
    """1x (and 2x below) on an arena floor: the three concepts beside Sakura, Bolt and the current Shade for scale."""
    def ref(name):
        return Image.open(ROOT / "assets" / "sprites" / f"{name}.png").convert("RGBA").crop((0, 0, CELL, CELL))
    figs = [("Sakura", ref("sakura")), ("Bolt", ref("bolt")), ("Shade now", ref("flicker"))] + [
        (n[:1], frame(b, 0)) for n, b in CONCEPTS]
    w = len(figs) * (CELL + 4) + 4
    row = floor_bg(w, CELL + 8)
    for i, (_, f) in enumerate(figs):
        row.alpha_composite(f, (4 + i * (CELL + 4), 4))
    mine = floor_bg(w, 2 * CELL + 8)
    for i, (_, f) in enumerate(figs[3:]):
        mine.alpha_composite(nn(f, 2), (4 + i * (2 * CELL + 4), 4))
    out = Image.new("RGBA", (w, 3 * CELL + 20), (24, 24, 32, 255))
    out.alpha_composite(row, (0, 0))
    out.alpha_composite(mine, (0, CELL + 12))
    out.convert("RGB").save(out_dir / "shade_concepts_scale.png")


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT
    rows = [[frame(b, t) for t in range(4)] for _, b in CONCEPTS]
    k = 6
    bg = (46, 44, 50, 255)
    sheet = Image.new("RGBA", (4 * CELL * k + 5 * 8, len(rows) * (CELL * k + 30) + 8), (24, 24, 32, 255))
    for r, (name, _) in enumerate(CONCEPTS):
        y = 8 + r * (CELL * k + 30)
        ImageDraw.Draw(sheet).text((8, y + 6), name, fill=(240, 240, 230, 255))
        for t, f in enumerate(rows[r]):
            tile = Image.new("RGBA", (CELL * k, CELL * k), bg)
            tile.alpha_composite(nn(f, k))
            sheet.alpha_composite(tile, (8 + t * (CELL * k + 8), y + 22))
    sheet.convert("RGB").save(out_dir / "shade_concepts.png")
    scale_sheet(out_dir)


if __name__ == "__main__":
    main()
