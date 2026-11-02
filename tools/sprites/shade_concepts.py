"""Shade (id `flicker`) redesign concept A, "Crimson kunoichi". Design stage only: nothing is written into assets/.
Drawn at the game's cell size (96 px) with the art-box helpers from generate.py: a neck scarf with two short rounded tails, a fox
mask worn askew (tilted ~30 deg, drawn from rotated vertices) on the far side of her face, crimson lips (mouth options M1-M3),
navy top with a kimono crossover, red obi, gold bracers, thigh holster, grey shin wraps, and five hair options (H1 high ponytail,
H4 bun with crossed kunai, H5 hime cut, H6 side ponytail, H7 pixie with rat-tail).
Run: tools/sprites/.venv/bin/python tools/sprites/shade_concepts.py [out_dir]
Output in the repo root (or out_dir): shade_A_v3_hair.png (x6, a row per hair, 2 idle + 2 walking frames), shade_A_v3_mouth.png
(x8 face close-ups + 1x) and shade_A_v3_scale.png (1x + 2x beside Sakura). Only palette colours are used."""
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
    m = len(widths)
    if m != n:  # resample the width profile to the number of points
        widths = [widths[min(m - 1, int(i * (m - 1) / (n - 1) + 0.5))] if False else
                  widths[int(i * (m - 1) / (n - 1))] * (1 - (i * (m - 1) / (n - 1) % 1)) +
                  widths[min(m - 1, int(i * (m - 1) / (n - 1)) + 1)] * (i * (m - 1) / (n - 1) % 1) for i in range(n)]
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
    """A soft cloth tail along `pts`: a rounded tip with one small notch, lit upper edge, dark underside, a few fold dashes."""
    n = len(pts)
    left, right = bandw(pts, [w0 + (w1 - w0) * i / (n - 1) for i in range(n)])
    (x, y), (px_, py_) = pts[-1], pts[-2]
    dx, dy = x - px_, y - py_
    ln = math.hypot(dx, dy) or 1
    tx, ty = dx / ln, dy / ln
    nx, ny = -ty, tx
    h = w1 / 2
    tip = []
    for a in (60, 30, 0, -30, -60):  # rounded end, the middle point pulled back into a small notch
        r = math.radians(a)
        back = 1.6 if a == 0 else 0.0
        tip.append((x + nx * h * math.sin(r) + tx * (h * math.cos(r) * 1.3 - back), y + ny * h * math.sin(r) + ty * (h * math.cos(r) * 1.3 - back)))
    c.part(P(ipts(left + tip + right[::-1])), base)
    top, bot = (left, right) if sum(p[1] for p in left) < sum(p[1] for p in right) else (right, left)
    c.flat(L(ipts(top[1:-1]), 1), LIGHTER[base])
    c.flat(L(ipts([(a, b + 1) for a, b in bot[2:-1]]), 1), DARKER[base])
    mid = lerp2(left, right, 0.5)
    for i in range(3, n - 3, 4):
        c.flat(L(ipts(mid[i:i + 2]), 1), DARKER[base])


# ==================================================================================================================================
# Crimson kunoichi: hair options, side fox mask, mouth options
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
    rx, ry = ring
    c.flat(R((rx - 1, ry - 1, rx, ry)), GOLD)  # small gold bead, then a red tassel hanging from it
    c.dot(rx - 1, ry - 1, YELLOW)
    c.flat(R((rx - 1, ry + 1, rx, ry + 3)), RED)
    c.flat(L([(rx - 2, ry + 3), (rx - 2, ry + 5)], 1), RED)
    c.flat(L([(rx + 1, ry + 3), (rx + 1, ry + 4)], 1), MAROON)
    c.dot(rx - 1, ry + 4, MAROON)
    c.dot(rx, ry + 5, RED)


def hair_band(c, pts, widths, clusters=((0.28, BLUE), (0.55, OUTLINE), (0.7, BLUE)), shade=True, color=None, rim=True):
    """A tapered lock of hair along `pts`: a crisp lit rim on the outer edge and strand clusters inside."""
    lw, rw = bandw(pts, widths)
    c.part(P(ipts(lw + rw[::-1])), color or HAIR_A, shade=shade)
    outer, inner = (lw, rw) if sum(x + y for x, y in lw) < sum(x + y for x, y in rw) else (rw, lw)
    n = len(pts)
    if rim:
        c.flat(L(ipts(outer[1:n - 2]), 1), STEEL_D)
    for i, (f, col) in enumerate(clusters):
        c.flat(L(ipts(lerp2(outer, inner, f)[3 + i:n - 3 - 2 * i]), 1), col)
    return lw, rw


def rot_pts(cx, cy, th, pts):
    co, si = math.cos(th), math.sin(th)
    return [(cx + u * co - v * si, cy + u * si + v * co) for u, v in pts]


def fox_mask(c, cx, cy, deg=30, k=1.25):
    """A festival fox mask pushed up and askew on the far (right) side of her face, drawn tilted `deg` degrees clockwise
    directly from rotated vertices (no pixel rotation), so the outline stays crisp and the markings stay symmetric about
    the tilted axis: ears with red tips, slanted eye slits, whiskers, forehead mark, nose, and a tie cord into her hair."""
    th = math.radians(deg)
    rp = lambda pts: rot_pts(cx, cy, th, [(u * k, v * k) for u, v in pts])
    mir = lambda pts: [(-u, v) for u, v in pts]
    ear = [(-6.2, -1), (-5.8, -10), (-0.5, -4.5)]
    c.part(P(ipts(rp(ear))), WHITE)
    c.part(P(ipts(rp(mir(ear)))), WHITE)
    face = [(6.8 * math.cos(math.radians(a)), 5.8 * math.sin(math.radians(a))) for a in range(0, 360, 15)]
    muzzle = [(-4.2, 3), (-0.9, 9), (0.9, 9), (4.2, 3)]
    c.part(lambda d, f: (d.polygon(ipts(rp(face)), f), d.polygon(ipts(rp(muzzle)), f)), WHITE)
    line = lambda a, b, col: c.flat(L(ipts(rp([a, b])), 1), col)
    for s in (1, -1):
        line((-5.7 * s, -8.6), (-5.4 * s, -6.6), RED)  # red ear tips
        line((-4.6 * s, -0.6), (-1.9 * s, 1.4), OUTLINE)  # slanted eye slits
        line((-5.3 * s, 3.2), (-2.9 * s, 2.7), RED)  # whiskers
        line((-4.5 * s, 4.9), (-2.3 * s, 4.3), RED)
    line((0, -4.2), (0, -1.6), RED)  # forehead mark
    line((-0.8, 7.4), (0.8, 7.4), OUTLINE)  # nose
    for u, v in ((-4.4, -4.6), (-3.2, -5.4)):
        x, y = rp([(u, v)])[0]
        c.dot(round(x), round(y), STEEL)
    # cord running up from the mask's inner top edge into her hair, with a gold bead
    a = rp([(-6.2, -2.5)])[0]
    c.flat(L(ipts([a, (a[0] - 2, a[1] - 3), (a[0] - 4, a[1] - 4)]), 1), RED)
    c.dot(round(a[0] - 2), round(a[1] - 3), GOLD)


def mouth(c, kind):
    """Lipstick options (art px, mouth sits at x 36..41, y 29..31)."""
    if kind == "M1":  # a clean 3 px crimson smirk line, one corner up
        c.flat(R((37, 31, 39, 31)), RED)
        c.dot(40, 30, RED)
    elif kind == "M2":  # small closed lips: crimson upper 4 px, darker lower 2 px centred
        c.flat(R((37, 30, 40, 30)), RED)
        c.flat(R((38, 31, 39, 31)), MAROON)
    else:  # M3: tiny cat smile ":3"
        for x, y in ((37, 30), (38, 31), (39, 30), (40, 31), (41, 30)):
            c.dot(x, y, RED)


def build_a(low, up, t, step=None, hair="H1", mouth_kind="M2"):
    mv = 1.0 if step is not None else 0.0  # walking: tails and hair stream further back
    # ---- legs: dark leggings with a dithered fishnet strip, light grey bandage wraps with diagonal lines, dark split-toe tabi
    for x, dy in legs(low, SHADOW, SHADOW, step):
        for yy in (50 + dy, 51 + dy):
            for xx in range(x, x + 6):
                if (xx + yy) % 2 == 0:
                    low.dot(xx, yy, STEEL_D)
        low.flat(R((x, 52 + dy, x + 5, 53 + dy)), STEEL)
        low.flat(R((x, 53 + dy, x + 5, 53 + dy)), STEEL_D)
        low.flat(L([(x, 53 + dy), (x + 5, 52 + dy)], 1), WHITE)  # wrap line
        low.dot(x, 52 + dy, WHITE)
        low.flat(L([(x + 6, 55 + dy), (x + 6, 56 + dy)], 1), OUTLINE)  # tabi split toe
        low.dot(x, 54 + dy, STEEL_D)
    # thigh holster on the outer leg: a dark-brown pouch and one kunai ring
    low.part(P([(39, 50), (43, 51), (43, 55), (40, 56), (39, 54)]), BROWN)
    low.flat(L([(39, 51), (43, 52)], 1), SHADOW)
    low.flat(L([(43, 52), (46, 51)], 2), STEEL_D)
    low.dot(47, 51, WHITE)
    low.dot(47, 50, STEEL)
    # ---- back hair
    if hair == "H1":  # high ponytail with volume
        pt = strand((29, 5), (13 - 3 * mv, -13), (-3 - 4 * mv, 8), (3 - 5 * mv, 36 - 3 * mv), t, 5.0, k=2.0, lag=0.8, n=18)
        hair_band(up, pt, [4, 8, 10, 11, 11, 10, 10, 9, 9, 8, 7, 7, 6, 5, 4, 3, 2, 1.5, 1])
    elif hair == "H4":  # high bun (odango)
        up.part(E((21, -7, 41, 10)), NAVY)
        up.flat(lambda d, f: d.arc((22, -6, 40, 9), 185, 300, f), STEEL)
        up.flat(lambda d, f: d.arc((23, -5, 39, 8), 190, 290, f), STEEL_D)
        up.flat(lambda d, f: d.arc((25, -3, 37, 6), 200, 280, f), BLUE)
        up.flat(lambda d, f: d.arc((27, -1, 37, 8), 10, 120, f), SHADOW)
        up.flat(L([(25, -2), (28, -4), (33, -5)], 1), STEEL)
        up.dot(26, -3, WHITE)
        up.part(RR((26, 8, 36, 11), 1), RED)
        up.dot(27, 9, ORANGE)
        up.dot(35, 9, GOLD)
    elif hair == "H5":  # long straight hime hair: a wide sheet behind her that sways with a lag
        pt = strand((20, 16), (4 - 2 * mv, 24), (9 - 3 * mv, 40), (12 - 5 * mv, 54), t, 3.5, k=2.0, lag=0.8, n=15)
        hair_band(up, pt, [7, 11, 13, 14, 14, 14, 14, 14, 14, 14, 14, 13, 13, 13, 12],
                  clusters=((0.22, BLUE), (0.5, OUTLINE), (0.75, BLUE)))
    elif hair == "H8":  # very long straight hair: a curtain of four strand clumps behind her, tips swaying with a lag
        for ci, (p0, p1, p2, p3, lag) in enumerate((((21, 15), (2, 24), (1, 42), (3, 57), 1.5), ((20, 17), (6, 26), (5, 44), (9, 58), 1.1),
                                                    ((20, 19), (11, 27), (11, 42), (15, 56), 0.7), ((21, 22), (15, 29), (16, 40), (19, 54), 0.3))):
            sh = 3.5 * mv
            pt = strand(p0, (p1[0] - sh, p1[1]), (p2[0] - sh, p2[1]), (p3[0] - sh * 1.4, p3[1] - sh * 0.5), t, 2.4, k=2.0, lag=lag, n=16)
            hair_band(up, pt, [3, 6, 8, 9, 9.5, 9.5, 9.5, 9, 9, 8.5, 8, 7, 6, 4.5, 3, 1.5, 1],
                      clusters=((0.3, BLUE),), color=(NAVY if ci % 2 else HAIR_A), rim=(ci == 0))
    elif hair == "H9":  # long straight hair: narrow vertical panels peeking out beside the shoulders, behind the arms
        b = sw_(t, 1.2, 1) - 2.0 * mv
        off = lambda y: b * max(0.0, (y - 28) / 20)
        left = [(22, 16), (14, 20), (12, 26), (11, 33), (11, 40), (12, 44), (14, 47.5), (16, 48.5), (18, 46), (19, 40), (19, 30), (21, 22)]
        for side in (0, 1):
            pts_ = [((x if side == 0 else 66 - x) + off(y), y) for x, y in left]
            up.part(P(ipts(pts_)), NAVY)
            for yy in range(16, 60):  # a darker navy toward the body
                for xx in range(6, 62):
                    near = (xx - 11) if side == 0 else (55 - xx)
                    if near > 2.8 + 1.0 * math.sin(yy / 7.0) and up.at(xx, yy)[:3] == NAVY:
                        up.dot(xx, yy, SHADOW)
            hx = 13 if side == 0 else 53  # one soft vertical highlight
            for yy in range(27, 43):
                if yy % 6:
                    up.dot(round(hx + off(yy)), yy, BLUE if 29 < yy < 40 else STEEL_D)
    elif hair == "H6":  # side ponytail on her far side, swinging out behind her head
        pt = strand((44, 6), (62 - 6 * mv, -6), (70 - 9 * mv, 22), (60 - 12 * mv, 42), t, 4.0, k=2.0, lag=0.8, n=18)
        hair_band(up, pt, [4, 8, 10, 11, 11, 10, 10, 9, 9, 8, 7, 6, 5, 4, 3, 2, 1.5, 1.2, 1])
    elif hair == "H7":  # pixie with a single long tied rat-tail at the nape and a red ribbon
        pt = strand((21, 28), (6 - 2 * mv, 33), (13 - 3 * mv, 45), (7 - 5 * mv, 57), t, 3.5, k=2.2, lag=0.8, n=16)
        hair_band(up, pt, [4, 6, 7, 7, 6.5, 6, 5.5, 5, 5, 4.5, 4, 3.5, 3, 2.5, 2, 1.5, 1], clusters=((0.35, BLUE),))
        rx, ry = pt[2]
        up.part(RR((round(rx) - 2, round(ry) - 2, round(rx) + 2, round(ry) + 2), 1), RED)
        up.dot(round(rx) - 1, round(ry) - 1, ORANGE)
        r1 = strand((rx, ry), (rx - 4, ry - 3), (rx - 8, ry + 1), (rx - 11 - 2 * mv, ry + 5), t, 2.0, k=2.0, lag=1.4, n=8)
        ribbon(up, r1, 3.2, 2.6, RED)
    # ---- scarf: a snug neck wrap with two SHORT rounded tails from the knot, an S-wave, the second lagging; gold bands
    if hair == "H9":  # a single rounded tail from the scarf, streaming out past her shoulder
        t1 = strand((22, 38), (16, 37.5 - mv), (11, 41), (9 - 2 * mv, 48 - mv), t, 1.6, k=2.2, lag=0.0, n=12)
        ribbon(up, t1, 4.4, 3.4, RED)
    else:
        t1 = strand((22, 37), (16, 34 - mv), (10 - 2 * mv, 39 - 2 * mv), (3 - 3 * mv, 37 - 3 * mv), t, 3.0, k=2.6, lag=0.0, n=12)
        t2 = strand((22, 39), (17, 43), (12 - mv, 44 - mv), (6 - 3 * mv, 48 - 2 * mv), t, 2.6, k=2.6, lag=1.0, n=12)
        ribbon(up, t2, 5.0, 4.0, RED)
        ribbon(up, t1, 5.6, 4.4, RED)
        across(up, t1, 7, 2.4, GOLD)
        across(up, t2, 7, 2.2, GOLD)
    bw = sw_(t, 1.0, 1)
    KIM = STEEL_D  # the kimono: a steel-blue one step lighter than the hair
    def tekko(x):  # a lighter cuff edge and a small steel plate on the back of the hand
        up.flat(R((x, 41, x + 5, 41)), SHADOW)
        up.flat(R((x + 1, 43, x + 4, 44)), STEEL)
        up.dot(x + 1, 43, WHITE)
        up.flat(R((x + 1, 45, x + 4, 45)), STEEL_D)
    ax = g.ARM_X[0]
    arm(up, ax, KIM, SKIN)
    tekko(ax)
    # ---- kimono-style wrap top over a short flared skirt (same colour, darker underside)
    flare = [(20, 45), (44, 45), (46, 47), (42, 48.5 + sw_(t, 1.0, 1)), (37, 47.5), (33, 46), (29, 47.5), (24, 48.5 - sw_(t, 0.5, 1)), (19, 47)]
    up.part(lambda d, f: (d.rounded_rectangle((20, 33, 44, 46), 3, f), d.polygon(flare, f)), KIM)
    up.flat(R((20, 47, 46, 47)), SHADOW)
    up.dither(R((36, 38, 45, 48)), SHADOW, "check", only_on=KIM)
    up.flat(L([(21, 38), (21, 44)], 1), STEEL)
    up.flat(L([(33, 46), (33, 48)], 1), SHADOW)  # skirt split
    # slim neck scarf under her chin
    up.part(RR((22, 37, 43, 38), 1), RED)
    up.flat(L([(24, 37), (36, 37)], 1), ORANGE)
    # collar V: a dark inner layer between two bold 2 px cream lapels that meet at the sternum
    up.part(P([(28, 39), (40, 39), (34, 43)]), SHADOW, shade=False, line=False)
    up.flat(L([(26, 39), (34, 43)], 2), CREAM)
    up.flat(L([(42, 39), (34, 43)], 2), CREAM)
    up.flat(L([(26, 41), (33, 44)], 1), SHADOW)  # shadow under the lapels
    up.flat(L([(42, 41), (35, 44)], 1), SHADOW)
    # red obi: one bold 3 px band with a lit top row, a knot and two hanging ends at her side
    up.part(R((20, 43, 44, 45)), RED, line=False)
    up.flat(R((20, 43, 44, 43)), ORANGE)
    up.flat(R((20, 45, 44, 45)), MAROON)
    up.part(P([(38, 46), (36, 50.5 + bw), (39, 49.5 + bw), (40, 46)]), RED)
    up.part(P([(40, 46), (42, 50.5 + bw), (44, 48.5 + bw), (42, 46)]), RED)
    up.part(E((37, 42, 42, 47)), RED)
    up.dot(38, 43, ORANGE)
    fx = g.ARM_X[1]
    arm(up, fx, KIM, SKIN)
    tekko(fx)
    # ---- head: hair mass, face
    if hair in ("H5", "H7", "H8", "H9"):
        up.part(E((17, 7, 49, 36) if hair == "H7" else ((13, 3, 53, 37) if hair == "H9" else (16, 4, 50, 36))), HAIR_A)
    up.part(RR(FACE, FACE_R), SKIN)
    up.flat(L([(26, 35), (42, 36)], 1), SKIN_D)
    # side locks + fringe, per style
    wv = sw_(t, 1.0, 1) + (1 if mv else 0)
    if hair == "H4":  # short loose strands framing the face
        for p0, p1, p2, p3, sgn in (((22, 14), (18, 22), (22, 29), (20, 36), 1), ((47, 14), (52, 22), (48, 30), (51, 38), -1)):
            hair_band(up, strand(p0, p1, p2, p3, t, 1.5, k=2.0, lag=0.5, n=10), [3.5, 4.5, 4.5, 4, 3.5, 3, 2.5, 2, 1.5, 1, 0.8],
                      clusters=((0.4, BLUE),), shade=False)
        fringe = [(19, 11), (49, 11), (50, 17), (45, 14), (42, 18), (37, 14), (33, 18), (29, 14), (25, 17), (22, 16), (19, 18)]
    elif hair == "H5":  # blunt bangs and straight side locks to the jaw
        up.part(P([(18, 12), (26, 14), (26, 31), (25, 37), (22, 38), (19, 34), (18, 24)]), HAIR_A, shade=False)
        up.part(P([(45, 14), (51, 14), (52, 26), (51, 37), (48, 39), (46, 35)]), HAIR_A, shade=False)
        up.flat(L([(19, 15), (19, 30)], 1), STEEL_D)
        up.flat(L([(23, 18), (23, 33)], 1), BLUE)
        up.flat(L([(47, 17), (47, 33)], 1), BLUE)
        up.flat(L([(50, 17), (51, 33)], 1), STEEL_D)
        up.dot(23, 37, GOLD)
        up.dot(48, 38, GOLD)
        fringe = [(19, 10), (49, 10), (50, 18), (46, 18), (46, 17), (40, 17), (40, 18), (33, 18), (33, 17), (27, 17), (27, 18), (19, 18)]
    elif hair == "H9":  # long side locks in front of her ears, joined to the back hair; then bangs grow out of the crown seamlessly
        for p0, p1, p2, p3, lag in (((22, 13), (21, 24), (23, 34), (22, 43), 0.5), ((47, 13), (48.5, 24), (46, 34), (47, 43), 0.2)):
            sh = -1.0 * mv
            hair_band(up, strand(p0, (p1[0] + sh, p1[1]), (p2[0] + sh, p2[1]), (p3[0] + sh * 1.5, p3[1]), t, 0.8, k=2.0, lag=lag, n=12),
                      [4.2, 4.2, 4, 3.8, 3.5, 3.1, 2.7, 2.2, 1.7, 1.3, 1, 0.8, 0.6], clusters=((0.4, BLUE),))
        # bangs grow out of the crown seamlessly: one fill in the hair colour, outline only along the pointed tips
        zig = [(19, 13), (19, 19), (23.5, 24), (26, 16.5), (29.5, 18.5), (32, 15.5), (34.5, 17.5), (36.5, 15.5), (38, 20.5), (40, 15.5),
               (42.5, 17.5), (45, 15.5), (47.5, 22.5), (49, 17), (48.5, 12)]
        up.part(P(ipts([(19, 9)] + zig + [(47, 9)])), HAIR_A, shade=False, line=False)
        up.flat(L(ipts(zig[2:-1]), 1), OUTLINE)
        pw = (37.0, 3.0)  # the parting / whorl the strands fan out from: separators and highlights follow arcs towards it
        for (vx, vy), f in (((26, 16.5), 0.5), ((32, 15.5), 0.68), ((36.5, 15.5), 0.42), ((40, 15.5), 0.6), ((45, 15.5), 0.36)):
            at = lambda g_: (vx + (pw[0] - vx) * g_, vy + (pw[1] - vy) * g_)
            up.flat(L(ipts([(vx, vy - 1), at(f)]), 1), OUTLINE)  # strand separation, starting at staggered heights
            up.flat(L(ipts([(at(0.1)[0] - 1.5, at(0.1)[1]), (at(f * 0.75)[0] - 1.5, at(f * 0.75)[1])]), 1), BLUE)  # staggered lit streak
        # rounded crown: soft curved highlights following the head from the top left (never a straight row)
        up.flat(lambda d, f: d.arc((14, 4, 52, 36), 186, 246, f), STEEL_D)
        up.flat(lambda d, f: d.arc((17, 7, 49, 33), 196, 240, f), BLUE)
        up.flat(lambda d, f: d.arc((20, 10, 46, 30), 208, 232, f), STEEL)
        fringe = None
    elif hair in ("H8", "H9"):  # (H8) two long straight side locks to the collar; bangs as tapered strands with gaps
        for p0, p1, p2, p3, lag in ( (((21, 13), (17, 21), (21, 30), (20, 41), 0.5), ((48, 13), (53, 21), (49, 30), (50, 41), 0.2))[:2 if hair == "H8" else 0]):
            hair_band(up, strand(p0, p1, p2, p3, t, 1.3, k=2.0, lag=lag, n=12), [6.5, 7, 7, 6.6, 6.2, 5.6, 4.8, 4, 3.2, 2.3, 1.5, 0.9, 0.6],
                      clusters=((0.3, BLUE),))
        for cx, ty, lean in ((24.5, 24, -1.5), (30, 19, 0.5), (35.5, 21.5, 0), (41, 19, 1), (46.5, 23, 1.5)):
            mid = (10 + ty) / 2
            up.part(P(ipts([(cx - 3.6, 10), (cx + 3.6, 10), (cx + 2.8, mid), (cx + lean, ty), (cx - 2.4, mid - 1)])), HAIR_A)
            if cx in (30, 41):
                up.flat(L(ipts([(cx - 2.5, 12), (cx - 2 + lean * 0.3, ty - 4)]), 1), BLUE)
        fringe = None
    elif hair == "H6":  # swept fringe, a short lock on her near side
        up.part(P([(19, 14), (25, 15), (25, 31), (22, 33), (19, 28)]), HAIR_A, shade=False)
        up.flat(L([(20, 16), (20, 27)], 1), STEEL_D)
        fringe = [(19, 11), (49, 11), (50, 15), (44, 14), (39, 17), (34, 15), (29, 19), (25, 17), (21, 22), (19, 18)]
    elif hair == "H7":  # choppy pixie
        up.part(P([(18, 14), (24, 16), (23, 29), (20, 31), (18, 25)]), HAIR_A, shade=False)
        up.part(P([(47, 14), (51, 16), (50, 28), (47, 31), (46, 22)]), HAIR_A, shade=False)
        up.flat(L([(19, 17), (19, 25)], 1), STEEL_D)
        fringe = [(19, 11), (49, 11), (50, 17), (46, 14), (43, 19), (40, 14), (36, 19), (32, 14), (28, 18), (24, 14), (21, 19), (19, 16)]
    else:  # H1
        up.part(P([(46, 14), (51, 17), (52 + wv, 28), (49, 26), (49, 31), (46, 27)]), HAIR_A, shade=False)
        fringe = [(19, 11), (49, 11), (50, 17), (45, 14), (42, 18), (37, 14), (33, 18), (29, 14), (25, 17), (22, 16), (19, 18)]
    if fringe:
        up.part(P(fringe), HAIR_A, shade=False)
    if hair not in ("H4", "H8", "H9"):
        up.flat(L([(30, 9), (41, 8)], 1), STEEL_D)
    if hair == "H5":
        up.flat(L([(22, 8), (27, 6), (34, 5)], 1), STEEL_D)
        up.flat(L([(24, 10), (29, 8)], 1), BLUE)
    if hair == "H1":
        up.part(RR((26, 2, 33, 8), 2), RED)
        up.dot(28, 4, ORANGE)
    if hair == "H6":
        up.part(RR((41, 3, 48, 9), 2), RED)
        up.dot(43, 5, ORANGE)
    # the mask rides the far side of her face, diagonal; then the pins
    fox_mask(up, 52, 17, -30)
    if hair == "H1":
        kunai_pin(up, (39, 0), (34, 3), (24, 8))
    elif hair == "H4":  # two crossed kunai through the bun like kanzashi
        kunai_pin(up, (38, -7), (34, -2), (26, 8))
        kunai_pin(up, (24, -7), (28, -2), (36, 8))
    elif hair == "H6":
        kunai_pin(up, (50, -3), (45, 2), (37, 7))
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
    mouth(up, mouth_kind)


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


HAIRS = [("H8c  long straight hair: strand bangs, two vertical hair panels behind the shoulders", "H9")]
MOUTHS = [("M1  clean crimson smirk line", "M1"), ("M2  small closed lips", "M2"), ("M3  cat smile :3", "M3")]
SHOTS = ((0, None), (2, None), (1, 1), (3, 5))  # two idle + two walking frames
DEFAULT_MOUTH = "M2"


def label_tile(img, text):
    out = Image.new("RGBA", (img.width, img.height + 16), (24, 24, 32, 255))
    out.alpha_composite(img, (0, 16))
    ImageDraw.Draw(out).text((4, 2), text, fill=(240, 240, 230, 255))
    return out


def mouth_sheet(out_dir):
    k = 8
    box = (20, 8, 58, 42)  # art px round her face
    cbox = (PAD + box[0], PAD + UPPER_DY + box[1], PAD + box[2], PAD + UPPER_DY + box[3])
    tiles = []
    for name, m in MOUTHS:
        f = frame(build_a, 0, hair="H1", mouth_kind=m)
        big = Image.new("RGBA", ((cbox[2] - cbox[0]) * k, (cbox[3] - cbox[1]) * k), (46, 44, 50, 255))
        big.alpha_composite(nn(f.crop(cbox), k))
        small = floor_bg(CELL, CELL)
        small.alpha_composite(f)
        one = Image.new("RGBA", (big.width, CELL + 8), (24, 24, 32, 255))
        one.alpha_composite(small, (4, 4))
        one.alpha_composite(nn(small.crop((24, 18, 84, 66)), 2), (CELL + 12, 4))
        tiles.append(label_tile(stack(big, one), name))
    sheet = Image.new("RGBA", (sum(t.width for t in tiles) + 8 * (len(tiles) + 1), max(t.height for t in tiles) + 16), (24, 24, 32, 255))
    x = 8
    for t_ in tiles:
        sheet.alpha_composite(t_, (x, 8))
        x += t_.width + 8
    sheet.convert("RGB").save(out_dir / "shade_A_v3_mouth.png")


def stack(a, b):
    out = Image.new("RGBA", (max(a.width, b.width), a.height + b.height), (24, 24, 32, 255))
    out.alpha_composite(a, (0, 0))
    out.alpha_composite(b, (0, a.height))
    return out


def scale_sheet(out_dir):
    """1x on an arena floor beside Sakura, then every hair option at 2x."""
    ref = lambda n: Image.open(ROOT / "assets" / "sprites" / f"{n}.png").convert("RGBA").crop((0, 0, CELL, CELL))
    mine = [frame(build_a, 0, hair=h, mouth_kind=DEFAULT_MOUTH) for _, h in HAIRS]
    figs = [ref("sakura"), ref("bolt")] + mine
    w = max(len(mine) * (2 * CELL + 4) + 4, len(figs) * (CELL + 4) + 4)
    row = floor_bg(w, CELL + 8)
    x0 = (w - len(figs) * (CELL + 4)) // 2
    for i, f in enumerate(figs):
        row.alpha_composite(f, (x0 + i * (CELL + 4), 4))
    rows = 1
    big = floor_bg(w, rows * (2 * CELL + 4) + 4)
    for i, f in enumerate(mine):
        big.alpha_composite(nn(f, 2), (4 + (i % len(mine)) * (2 * CELL + 4), 4))
    out = Image.new("RGBA", (w, CELL + 8 + 4 + big.height), (24, 24, 32, 255))
    out.alpha_composite(row, (0, 0))
    out.alpha_composite(big, (0, CELL + 12))
    out.convert("RGB").save(out_dir / "shade_A_v10_scale.png")


def head_check(out_dir):
    """x10 crop of the head, plus a row scan of the hair region: the longest horizontal run of each highlight colour."""
    h = HAIRS[0][1]
    f = frame(build_a, 0, hair=h, mouth_kind=DEFAULT_MOUTH)
    oy = PAD + UPPER_DY
    f.crop((PAD + 10, oy - 4, PAD + 62, oy + 42)).resize((520, 460), Image.NEAREST).convert("RGB").save(out_dir / "shade_A_v10_head.png")
    worst = {}
    for y in range(oy + 3, oy + 23):
        run, last = 0, None
        for x in range(PAD + 13, PAD + 46):
            c = f.getpixel((x, y))[:3]
            run = run + 1 if c == last else 1
            last = c
            if c in (STEEL_D, STEEL, BLUE, WHITE, OUTLINE):
                worst[c] = max(worst.get(c, 0), run)
    names = {STEEL_D: "STEEL_D", STEEL: "STEEL", BLUE: "BLUE", WHITE: "WHITE", OUTLINE: "OUTLINE"}
    print("longest horizontal runs in the hair rows:", {names[c]: n for c, n in worst.items()})


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT
    k, bg = 6, (46, 44, 50, 255)
    crop = (0, 4, 90, CELL - 6)
    tw, th = (crop[2] - crop[0]) * k, (crop[3] - crop[1]) * k
    sheet = Image.new("RGBA", (4 * (tw + 8) + 8, len(HAIRS) * (th + 30) + 8), (24, 24, 32, 255))
    for r, (name, h) in enumerate(HAIRS):
        y = 8 + r * (th + 30)
        ImageDraw.Draw(sheet).text((10, y + 6), name, fill=(240, 240, 230, 255))
        for i, (t, step) in enumerate(SHOTS):
            f = frame(build_a, t, step, hair=h, mouth_kind=DEFAULT_MOUTH)
            assert all(f.getpixel((0, yy))[3] == 0 and f.getpixel((CELL - 1, yy))[3] == 0 for yy in range(CELL)), f"{h} clipped"
            tile = Image.new("RGBA", (tw, th), bg)
            tile.alpha_composite(nn(f.crop(crop), k))
            sheet.alpha_composite(tile, (8 + i * (tw + 8), y + 22))
    sheet.convert("RGB").save(out_dir / "shade_A_v10.png")
    head_check(out_dir)
    scale_sheet(out_dir)


if __name__ == "__main__":
    main()
