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
                     CREAM_D)  # noqa: E402

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
# A  Crimson kunoichi
# ==================================================================================================================================
HAIR_A = SHADOW  # black hair: rim-lit by STEEL_D, shades to OUTLINE
GOLD = OCHRE


def kunai_pin(c, base, tip, ring):
    """A kunai: leaf blade from `base` out to `tip`, red-wrapped grip, gold ring at `ring`."""
    c.flat(L([ring, base], 1), RED)
    c.flat(L([base, (base[0] + (tip[0] - base[0]) // 3, base[1] + (tip[1] - base[1]) // 3)], 1), GOLD)
    mx, my = (base[0] + tip[0]) // 2, (base[1] + tip[1]) // 2
    c.part(P([(base[0] + (tip[0] - base[0]) // 4, base[1] + (tip[1] - base[1]) // 4 - 1), (mx + 1, my - 2), tip,
              (mx - 1, my + 2)]), STEEL)
    disc(c, ring[0], ring[1], 2, GOLD)
    c.dot(ring[0], ring[1], OUTLINE)


def build_a(low, up, t):
    # ---- legs: navy trousers, red ankle wraps, a gold-studded thigh strap and a kunai holster on the front leg
    for i, (x, dy) in enumerate(legs(low, NAVY, SHADOW, None)):
        low.flat(L([(x + 1, 49 + dy), (x + 1, 52 + dy)], 1), BLUE)
        low.flat(R((x, 52 + dy, x + 5, 52 + dy)), RED)  # ankle wrap
        low.flat(R((x, 53 + dy, x + 5, 53 + dy)), MAROON)
        low.dot(x + 1, 52 + dy, ORANGE)
        low.flat(R((x, 50 + dy, x + 5, 50 + dy)), BROWN)  # thigh strap
        low.dot(x + 2, 50 + dy, GOLD)
    fx, fdy = 34, 0
    low.part(P([(fx + 5, 49), (fx + 9, 50), (fx + 9, 55), (fx + 6, 56), (fx + 5, 53)]), BROWN)  # holster pouch on the outer thigh
    low.flat(L([(fx + 6, 50), (fx + 8, 50)], 1), OCHRE)  # buckle strap
    low.flat(L([(fx + 7, 49), (fx + 8, 46)], 1), RED)  # kunai grip sticking up
    low.dot(fx + 8, 46, GOLD)
    low.dot(fx + 8, 45, GOLD)

    # ---- scarf tails, streaming behind her (the silhouette hook): three trailing ribbons, each lagging the one before
    tails = [((22, 37), (6, 31), (-8, 46), (-20, 40), 5.5, 1.4, 8.0, 5.0, 0.0),
             ((22, 39), (8, 44), (-3, 52), (-12, 56), 5.0, 1.0, 7.0, 3.5, 0.8),
             ((22, 38), (10, 26), (-2, 28), (-8, 20), 4.0, 1.4, 6.0, 3.0, 1.6)]
    for p0, p1, p2, p3, w0, k, amp, w1, lag in reversed(tails):
        pts = strand(p0, p1, p2, p3, t, amp, k=1.8 + k, lag=lag)
        poly = band(pts, w0 + 1, w1 + 1, notch=2.2)
        up.part(P(poly), RED)
        mid = pts[len(pts) // 2]
        up.flat(L([(round(x), round(y) + 1) for x, y in pts[2:-2]], 1), MAROON)  # centre fold
        across(up, pts, len(pts) - 3, w1 / 2 + 1, GOLD)
        across(up, pts, len(pts) - 4, w1 / 2 + 1, OCHRE_D)
    # ---- ponytail (high, from a tie on the crown)
    tie = (27, 5)
    pt = strand(tie, (12, -12), (-4, 6), (-2, 34), t, 4.0, k=1.7, lag=0.7)
    up.part(P(band(pt, 7, 2, notch=0)), HAIR_A)
    pt2 = strand((tie[0] - 1, tie[1] + 2), (14, -2), (4, 14), (8, 36), t, 3.5, k=1.7, lag=1.4)
    up.part(P(band(pt2, 4, 1)), HAIR_A)
    for (x, y) in pt[3:9:2]:
        up.dot(round(x) - 1, round(y) - 1, STEEL_D)
    up.flat(L([(round(x) - 1, round(y)) for x, y in pt[2:6]], 1), STEEL_D)
    # ---- back arm
    arm(up, g.ARM_X[0], NAVY, SKIN)
    up.flat(R((g.ARM_X[0], 39, g.ARM_X[0] + 5, 40)), GOLD)
    up.flat(R((g.ARM_X[0], 39, g.ARM_X[0] + 5, 39)), YELLOW)
    # ---- body: tunic with a flared, split hem
    flare = [(20, 44), (44, 44), (46, 50), (42, 52 + round(phase(t, 1.0)) ), (38, 49), (33, 52), (27, 49), (22, 52 - round(phase(t, 0.5))), (18, 50)]
    up.part(lambda d, f: (d.rounded_rectangle(BODY, 3, f), d.polygon(flare, f)), NAVY)
    up.flat(L([(21, 40), (21, 46)], 1), BLUE)
    up.flat(L([(22, 36), (28, 33)], 1), BLUE)
    up.dither(R((36, 38, 43, 49)), SHADOW, "check", only_on=NAVY)
    # crossed collar
    up.flat(L([(26, 34), (33, 41)], 1), SHADOW)
    up.flat(L([(40, 34), (33, 41)], 1), SHADOW)
    up.flat(L([(26, 35), (32, 41)], 1), BLUE)
    # hem trim: gold piping along the flare's bottom edge
    for (x0, y0, x1, y1) in ((18, 50, 22, 52), (38, 49, 42, 52), (42, 52, 46, 50)):
        pass
    up.flat(L([(20, 47), (44, 47)], 1), SHADOW)
    # red obi with a gold knot
    up.part(R((20, 41, 44, 45)), RED, line=False)
    up.flat(R((20, 41, 44, 41)), ORANGE)
    up.flat(R((20, 45, 44, 45)), MAROON)
    up.part(RR((29, 40, 36, 46), 1), GOLD)
    up.flat(R((30, 41, 31, 41)), YELLOW)
    up.flat(L([(32, 42), (34, 44)], 1), OCHRE_D)
    # ---- scarf wrap round the neck, with a hanging front tail and the knot on her far shoulder
    up.part(RR((20, 34, 46, 40), 3), RED)
    up.flat(L([(23, 35), (35, 36)], 1), ORANGE)
    ft = strand((24, 38), (20, 44), (21, 50), (19, 53), t, 2.0, k=1.5, lag=0.5)
    up.part(P(band(ft, 5, 3, notch=2)), RED)
    up.flat(L([(round(x) + 1, round(y)) for x, y in ft[1:-2]], 1), MAROON)
    up.part(E((18, 35, 24, 41)), RED)  # knot
    up.flat(L([(19, 37), (22, 36)], 1), ORANGE)
    up.dot(21, 39, MAROON)
    # ---- front arm
    arm(up, g.ARM_X[1], NAVY, SKIN)
    up.flat(R((g.ARM_X[1], 39, g.ARM_X[1] + 5, 40)), GOLD)
    up.flat(R((g.ARM_X[1], 39, g.ARM_X[1] + 5, 39)), YELLOW)
    up.flat(R((g.ARM_X[1], 41, g.ARM_X[1] + 5, 41)), OCHRE_D)
    up.part(RR((42, 34, 48, 38), 2), SHADOW)  # shoulder pad
    up.flat(R((43, 34, 45, 34)), STEEL_D)
    # ---- head
    up.part(lambda d, f: (d.ellipse((16, 5, 50, 36), f), d.polygon(
        [(16, 20), (14, 30), (18, 28), (19, 36), (22, 31), (24, 20)], f)), HAIR_A)
    up.part(RR(FACE, FACE_R), SKIN)
    up.flat(L([(26, 35), (42, 36)], 1), SKIN_D)
    # far side lock + fringe
    up.part(P([(46, 14), (51, 17), (52 + round(phase(t, 1.0) * 0.8), 28), (49, 26), (49, 31), (46, 27)]), HAIR_A, shade=False)
    up.part(P([(19, 11), (49, 11), (50, 17), (45, 14), (42, 18), (37, 14), (33, 18), (29, 14), (25, 17), (22, 16), (19, 18)]),
            HAIR_A, shade=False)
    up.flat(L([(24, 9), (33, 7)], 1), STEEL_D)
    up.dot(22, 12, STEEL_D)
    # hairpin tie (red) and the kunai through it
    up.part(RR((23, 3, 31, 9), 2), RED)
    up.dot(25, 5, ORANGE)
    kunai_pin(up, (30, 5), (18, 13), (33, 1))
    # eyes: gold, with a red flick at the outer corner
    big_eyes(up, g.EYES_Y - 1, g.EYES_X, ORANGE, h=6)
    for x in g.EYES_X:
        up.flat(R((x + 3, 19, x + 4, 19)), OUTLINE)
        up.dot(x + 5, 18, RED)
        up.dot(x + 4, 20, RED)
    # fox half-mask: white, pointed muzzle to the front, red markings, gold studs
    mask = [(29, 33), (34, 33), (40, 31), (45, 31), (50, 34), (46, 36), (42, 38), (34, 38), (29, 37)]
    up.part(P(mask), WHITE)
    up.flat(L([(31, 35), (35, 36)], 1), RED)
    up.flat(L([(38, 31), (42, 34)], 1), RED)
    up.flat(L([(41, 31), (44, 33)], 1), RED)
    up.flat(R((48, 32, 49, 33)), OUTLINE)  # nose
    up.dot(48, 32, STEEL_D)
    up.dot(34, 33, GOLD)
    up.flat(L([(29, 34), (24, 31)], 1), RED)  # mask cord
    up.flat(R((26, 29, 27, 29)), PINK)  # blush above the mask
    up.flat(R((30, 37, 44, 37)), STEEL)


# ==================================================================================================================================
# B  Moon assassin, C  Street ninja are added below
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


def build_b(low, up, t):
    IND = VIOLET_D
    # ---- legs: indigo with a glowing cyan seam, silver greaves, cyan toe glow
    for x, dy in legs(low, IND, SHADOW, None):
        low.flat(L([(x + 4, 46 + dy), (x + 4, 52 + dy)], 1), TEAL_L)
        low.dot(x + 3, 49 + dy, TEAL)
        low.flat(R((x, 51 + dy, x + 5, 53 + dy)), STEEL)
        low.flat(R((x, 53 + dy, x + 5, 53 + dy)), STEEL_D)
        low.dot(x, 51 + dy, WHITE)
        low.flat(R((x + 5, 55 + dy, x + 7, 56 + dy)), TEAL_L)
        low.flat(L([(x - 1, 55 + dy), (x + 2, 55 + dy)], 1), VIOLET)
    sw = lambda lag, a: round(a * phase(t, lag))
    # ---- chakram on her back (rotates a little each frame), the cape hangs over its lower rim
    cx, cy, rot = 9, 22, t * math.pi / 8
    pts_ = []
    for k in range(8):
        a = rot + k * math.pi / 4
        pts_ += [(cx + 13 * math.cos(a), cy + 13 * math.sin(a)), (cx + 9 * math.cos(a + math.pi / 8), cy + 9 * math.sin(a + math.pi / 8))]
    up.part(P(pts_), STEEL)
    up.part(E((cx - 9, cy - 9, cx + 9, cy + 9)), STEEL, line=False)
    for yy in range(cy - 6, cy + 7):  # hollow centre
        for xx in range(cx - 6, cx + 7):
            if (xx - cx) ** 2 + (yy - cy) ** 2 <= 30:
                up.px[xx + up.ox, yy + up.oy] = (0, 0, 0, 0)
    for x, y in set((cx + round(6 * math.cos(a)), cy + round(6 * math.sin(a))) for a in [k * math.pi / 12 for k in range(24)]):
        up.dot(x, y, OUTLINE)
    for x, y in set((cx + round(7.5 * math.cos(a)), cy + round(7.5 * math.sin(a))) for a in [k * math.pi / 12 for k in range(24)]):
        up.dot(x, y, TEAL_L if (x + y) % 3 else WHITE)
    # ---- tattered cape: ragged hem, cyan edge
    cape = [(25, 34), (14, 36 + sw(0, 1)), (8 + sw(0.5, 2), 44), (9 + sw(1, 2), 52), (13 + sw(1, 2), 48), (15 + sw(1.5, 2), 56),
            (20 + sw(1.5, 2), 50), (23 + sw(2, 2), 55), (27, 48), (31, 42)]
    up.part(P(cape), IND)
    up.flat(L([(14, 38), (10 + sw(0.5, 2), 45), (11 + sw(1, 2), 51)], 1), TEAL_L)
    up.flat(L([(24, 36), (28, 47)], 1), VIOLET)
    up.dither(R((8, 44, 20, 56)), OUTLINE, "check", only_on=IND)
    # ---- braid: long, woven, tied in cyan, swinging with a lag
    br = strand((22, 24), (13, 30), (17, 42), (15, 55), t, 3.5, k=1.8, lag=0.8, n=14)
    for i, (x, y) in enumerate(br[:-1]):
        r = 3 if i < 9 else 2
        up.part(E((round(x) - r, round(y) - 2, round(x) + r, round(y) + 2)), WHITE if i % 2 == 0 else STEEL)
    ex, ey = round(br[-1][0]), round(br[-1][1])
    up.part(P([(ex - 2, ey - 2), (ex + 2, ey - 2), (ex + 3, ey + 3), (ex, ey + 5), (ex - 3, ey + 2)]), WHITE)
    bx, by = round(br[-3][0]), round(br[-3][1])
    up.flat(R((bx - 2, by, bx + 2, by + 1)), TEAL_L)
    # ---- back arm: silver gauntlet with a cyan band
    ax = g.ARM_X[0]
    arm(up, ax, IND, SKIN)
    up.flat(R((ax, 39, ax + 5, 41)), STEEL)
    up.flat(R((ax, 41, ax + 5, 41)), STEEL_D)
    up.dot(ax, 39, WHITE)
    up.flat(R((ax + 1, 40, ax + 4, 40)), TEAL_L)
    # ---- body
    up.part(RR(BODY, 3), IND)
    up.flat(L([(21, 38), (21, 44)], 1), VIOLET)
    up.dither(R((36, 37, 43, 47)), OUTLINE, "check", only_on=IND)
    up.flat(L([(28, 35), (33, 44)], 1), TEAL)
    up.flat(L([(27, 35), (32, 44)], 1), TEAL_L)
    up.flat(L([(40, 35), (34, 44)], 1), TEAL)
    up.dot(33, 45, TEAL_L)
    crescent(up, 25, 41, 3, 3, 1, -1, STEEL)
    up.dot(23, 39, TEAL_L)
    up.part(R((20, 44, 44, 46)), VIOLET, line=False)
    up.flat(R((20, 44, 44, 44)), VIOLET_L)
    up.flat(R((20, 46, 44, 46)), OUTLINE)
    up.part(RR((30, 43, 36, 47), 1), STEEL)
    up.flat(R((32, 44, 34, 46)), TEAL_L if t % 2 == 0 else WHITE)
    up.part(RR((21, 34, 45, 38), 2), VIOLET)
    up.flat(L([(23, 35), (30, 35)], 1), VIOLET_L)
    up.flat(L([(23, 37), (43, 38)], 1), TEAL)
    # ---- front arm + crescent pauldron
    fx = g.ARM_X[1]
    arm(up, fx, IND, SKIN)
    up.flat(R((fx, 39, fx + 5, 41)), STEEL)
    up.flat(R((fx, 41, fx + 5, 41)), STEEL_D)
    up.dot(fx, 39, WHITE)
    up.flat(R((fx + 1, 40, fx + 4, 40)), TEAL_L)
    crescent(up, 45, 36, 5, 4, -1, 1, STEEL)
    up.dot(44, 33, TEAL_L)
    # ---- head: silver hair, face, fringe, headband with the crescent plate
    up.part(lambda d, f: (d.ellipse((16, 5, 50, 36), f), d.polygon(
        [(16, 20), (14, 28), (18, 27), (19, 33), (23, 28), (24, 20)], f)), WHITE)
    up.flat(L([(22, 8), (32, 6)], 1), STEEL)
    up.dither(R((18, 24, 24, 34)), STEEL, "check", only_on=WHITE)
    up.part(RR(FACE, FACE_R), SKIN)
    up.flat(L([(26, 35), (42, 36)], 1), SKIN_D)
    up.part(P([(46, 14), (51, 17), (52 + round(phase(t, 1.0) * 0.8), 29), (49, 27), (49, 32), (46, 27)]), WHITE, shade=False)
    up.flat(L([(50, 20), (51, 27)], 1), STEEL)
    up.part(P([(19, 11), (49, 11), (50, 17), (46, 14), (43, 18), (39, 14), (35, 18), (31, 14), (27, 17), (23, 14), (19, 18)]),
            WHITE, shade=False)
    up.flat(L([(21, 17), (24, 15)], 1), STEEL)
    up.part(P([(19, 10), (30, 8), (40, 8), (49, 10), (49, 13), (40, 11), (30, 11), (19, 14)]), IND, shade=False)
    up.flat(L([(21, 11), (28, 10)], 1), VIOLET_L)
    crescent(up, 35, 11, 4, 3, 1, -1, STEEL)
    up.dot(36, 11, TEAL_L)
    big_eyes(up, g.EYES_Y - 1, g.EYES_X, TEAL_L, h=6)
    for x in g.EYES_X:
        up.flat(R((x + 3, 19, x + 4, 19)), OUTLINE)
        up.dot(x + 5, 18, OUTLINE)
    up.dot(33, 29, TEAL_L)
    up.dot(34, 30, TEAL_L)
    up.dot(33, 31, TEAL)
    up.flat(R((g.BLUSH[0], 30, g.BLUSH[0] + 1, 30)), PINK)
    up.flat(R((g.MOUTH[0], g.MOUTH[1], g.MOUTH[0] + 1, g.MOUTH[1])), MAROON)


def build_c(low, up, t):
    JACKET, MESH, PANTS = OUTLINE, STEEL_D, STEEL_D
    ACC = TEAL_L
    # ---- legs: cargo pants with straps, a shin pad, chunky white sneakers with LED soles
    for x, dy in legs(low, PANTS, WHITE, None):
        low.flat(L([(x + 1, 50 + dy), (x + 1, 52 + dy)], 1), STEEL)
        low.flat(R((x, 51 + dy, x + 5, 51 + dy)), OUTLINE)
        low.dot(x + 3, 51 + dy, STEEL)
        low.flat(R((x, 52 + dy, x + 5, 53 + dy)), SHADOW)
        low.dot(x, 52 + dy, STEEL)
        low.flat(R((x - 1, 57 + dy, x + 7, 57 + dy)), ACC)
        low.flat(R((x + 5, 55 + dy, x + 7, 55 + dy)), STEEL)
        low.flat(L([(x - 1, 55 + dy), (x + 1, 55 + dy)], 1), SHADOW)
    low.part(RR((39, 49, 44, 53), 1), SHADOW)
    low.flat(R((40, 50, 43, 50)), STEEL_D)
    low.dot(41, 52, ACC)
    # ---- hair behind: a long asymmetric back lock with a cyan streak
    lock = strand((20, 14), (3, 20), (10, 34), (5, 50), t, 4.0, k=1.8, lag=0.8)
    up.part(P(band(lock, 9, 2)), NAVY)
    up.flat(L([(round(x) + 1, round(y)) for x, y in lock[2:-1]], 1), ACC)
    up.flat(L([(round(x) - 2, round(y)) for x, y in lock[2:6]], 1), STEEL_D)
    ax = g.ARM_X[0]
    arm(up, ax, JACKET, SKIN)
    up.flat(R((ax, 38, ax + 5, 39)), STEEL_D)
    up.dot(ax + 1, 38, STEEL)
    # ---- body: mesh top with a cropped jacket over it
    up.part(RR(BODY, 3), MESH)
    up.dither(R((20, 40, 44, 48)), SHADOW, "check", only_on=MESH)
    up.flat(R((20, 47, 44, 48)), SHADOW)
    up.part(P([(20, 34), (44, 34), (46, 38), (44, 43), (38, 43), (36, 45), (28, 45), (26, 43), (20, 43), (18, 38)]), JACKET)
    up.flat(L([(21, 36), (21, 41)], 1), SHADOW)
    up.flat(L([(23, 35), (30, 35)], 1), STEEL_D)
    up.flat(L([(33, 36), (33, 44)], 1), ACC)
    up.dot(34, 37, STEEL)
    up.flat(L([(26, 35), (31, 42)], 1), STEEL_D)
    up.flat(L([(41, 35), (35, 42)], 1), STEEL_D)
    up.flat(R((29, 41, 31, 42)), STEEL)
    up.dot(29, 41, WHITE)
    up.flat(R((22, 40, 25, 42)), SHADOW)
    up.dot(24, 40, ACC)
    up.flat(L([(40, 39), (43, 40)], 1), ACC)
    up.dither(R((37, 36, 44, 43)), SHADOW, "check", only_on=JACKET)
    # ---- front arm: sleeve, a kunai chain wrapped round the forearm, the kunai swinging from it
    fx = g.ARM_X[1]
    arm(up, fx, JACKET, SKIN)
    for i, y in enumerate(range(37, 43)):
        up.flat(R((fx, y, fx + 5, y)), STEEL if i % 2 == 0 else STEEL_D)
        up.dot(fx + (i % 3) + 1, y, OUTLINE)
    up.dot(fx, 37, WHITE)
    ch = strand((fx + 4, 43), (fx + 7, 47), (fx + 2, 52), (fx + 6, 56), t, 2.5, k=1.5, lag=0.4, n=8)
    for i, (x, y) in enumerate(ch[:-2]):
        up.dot(round(x), round(y), STEEL if i % 2 == 0 else STEEL_D)
    kx, ky = round(ch[-1][0]), round(ch[-1][1])
    up.part(P([(kx - 1, ky - 3), (kx + 1, ky - 3), (kx + 2, ky), (kx, ky + 4), (kx - 2, ky)]), STEEL)
    up.flat(L([(kx, ky - 2), (kx, ky + 2)], 1), WHITE)
    up.dot(kx, ky - 4, ACC)
    up.part(RR((42, 33, 48, 38), 2), SHADOW)
    up.flat(R((43, 33, 45, 33)), STEEL_D)
    # ---- head
    up.part(lambda d, f: (d.ellipse((16, 5, 50, 36), f), d.polygon([(16, 20), (14, 28), (20, 26), (24, 20)], f)), NAVY)
    up.part(RR(FACE, FACE_R), SKIN)
    up.flat(L([(26, 35), (42, 36)], 1), SKIN_D)
    up.part(P([(19, 10), (49, 10), (50, 15), (44, 14), (36, 14), (30, 19), (25, 24), (22, 27), (23, 19), (19, 17)]), NAVY, shade=False)
    up.flat(L([(26, 22), (23, 27)], 1), ACC)
    up.flat(L([(28, 20), (25, 24)], 1), TEAL)
    up.flat(L([(22, 9), (34, 7)], 1), BLUE)
    up.flat(L([(40, 11), (47, 12)], 1), BLUE)
    up.part(E((21, 24, 26, 30)), SHADOW)
    up.dot(23, 26, ACC if t % 2 == 0 else TEAL)
    big_eyes(up, g.EYES_Y - 1, g.EYES_X, TEAL_L, h=6)
    up.flat(L([(g.EYES_X[1] - 1, 20), (g.EYES_X[1] + 4, 19)], 1), OUTLINE)
    mask = [(26, 31), (34, 31), (40, 30), (46, 31), (48, 34), (45, 37), (40, 38), (32, 38), (27, 37)]
    up.part(P(mask), SHADOW)
    up.flat(L([(28, 33), (31, 33)], 1), STEEL_D)
    up.flat(L([(28, 35), (31, 35)], 1), STEEL_D)
    up.flat(R((35, 34, 45, 34)), ACC if t % 4 != 3 else TEAL)
    up.flat(R((36, 33, 44, 33)), TEAL)
    up.dot(34, 34, WHITE)
    up.dot(46, 33, STEEL)
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
    out = Image.new("RGBA", (w * 2, (CELL + 8) * 3 + 8), (24, 24, 32, 255))
    out.alpha_composite(row, (0, 0))  # true 1x
    out.alpha_composite(nn(row, 2).crop((0, 0, w * 2, (CELL + 8) * 2)), (0, CELL + 8 + 4))
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
