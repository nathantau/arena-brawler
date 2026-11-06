"""Flint anime bust (title-screen showcase art), original art.

Pipeline (see .claude/skills/anime-pixel-art): smooth vector illustration drawn in code at 8 source px
per output px -> pixelize(src, 96, 40) -> snap to Flint's gameplay palette (+ 6 in-between ramp
colours) -> stray-pixel cleanup -> interior ink recoloured -> embers.
Output: assets/title/anime/flint_bust.png, 4 frames of 96 x 128
(calm sway A, calm sway B, shout, determined squint).

Hair is fire, not hair with an outline: no ink on it. Flame colour runs hottest (yellow) at the root to
orange to red at the tips, with a deep-red edge, small licks on the sides and detached wisps.

Run: tools/sprites/.venv/bin/python tools/sprites/anime_busts.py [review_dir]
(review_dir gets flint_bust_clean.png and flint_bust_review.png; never commit those.)
"""
import math
import os
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelize import pixelize

OW, OH = 96, 128          # output size (px)
K = 8 * OW / 48           # source px per design unit (design grid is 48 x 64 units)
SW, SH = OW * 8, OH * 8   # source size: 8 source px per output px
F = K / 8                 # scale for pixel offsets written for the 48 px grid
W, H = OW, OH
INK = (27, 26, 46); MAROON = (122, 46, 56); RED = (217, 71, 75); ORANGE = (240, 138, 62)
YELLOW = (245, 210, 86); CREAM = (242, 240, 230); NAVY = (58, 58, 92); BLUE = (43, 58, 107)
BROWN = (184, 117, 79)
# in-between ramp colours (same hue families as the gameplay palette)
LIGHT_OR = (250, 172, 84); DEEP_RED = (168, 54, 66)
NAVY_L = (86, 88, 130); NAVY_D = (34, 40, 76)
BROWN_L = (214, 152, 104); BROWN_D = (132, 80, 62)
PALETTE = [INK, MAROON, RED, ORANGE, YELLOW, CREAM, NAVY, BLUE, BROWN,
           LIGHT_OR, DEEP_RED, NAVY_L, NAVY_D, BROWN_L, BROWN_D]
NAVYS = {NAVY, BLUE, NAVY_L, NAVY_D}
BROWNS = {BROWN, BROWN_L, BROWN_D}
TOFF = 3.5                # torso / neck-base offset (longer neck)
BG = (236, 236, 236)
LINE = 7                  # outline thickness in source px

YOFF = [0.0]


def P(x, y):
    return (x * K, (y + YOFF[0]) * K)


def poly(d, pts, fill):
    d.polygon([P(*p) for p in pts], fill=fill)


def outline(d, pts, w=LINE, closed=True, col=INK):
    q = [P(*p) for p in pts]
    if closed:
        q.append(q[0])
    d.line(q, fill=col, width=w, joint="curve")
    for x, y in q:  # round the joints
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=col)


def shape(d, pts, fill, w=LINE, col=INK):
    outline(d, pts, w, col=col)
    poly(d, pts, fill)


def rect(d, x0, y0, x1, y1, fill):
    d.rectangle((x0 * K, y0 * K, x1 * K, y1 * K), fill=fill)


def smooth(pts, n=8):
    """Catmull-Rom through pts (open)."""
    out = []
    p = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(p) - 2):
        for j in range(n):
            t = j / n
            a, b, c, e = p[i - 1], p[i], p[i + 1], p[i + 2]
            out.append(tuple(0.5 * ((2 * b[k]) + (-a[k] + c[k]) * t + (2 * a[k] - 5 * b[k] + 4 * c[k] - e[k]) * t * t
                                    + (-a[k] + 3 * b[k] - 3 * c[k] + e[k]) * t ** 3) for k in (0, 1)))
    out.append(pts[-1])
    return out


def mask_of(fn):
    m = Image.new("L", (SW, SH), 0)
    fn(ImageDraw.Draw(m))
    return m


def poly_mask(pts):
    return mask_of(lambda m: m.polygon([P(*p) for p in pts], fill=255))


def box_mask(x0, y0, x1, y1):
    return mask_of(lambda m: m.rectangle((x0 * K, (y0 + YOFF[0]) * K, x1 * K, (y1 + YOFF[0]) * K), fill=255))


def shift(m, dx, dy):
    return ImageChops.offset(m, dx, dy)


def both(a, b):
    return ImageChops.multiply(a, b)


def inv(a):
    return ImageChops.invert(a)


def paste_mask(img, col, m):
    img.paste(col, (0, 0), m)


# ---------------------------------------------------------------- flame tongue
def centreline(root, tip, bend, sway, n=28):
    x0, y0 = root
    x1, y1 = tip[0] + sway, tip[1] + abs(sway) * 0.2
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    bend = (bend - sway * 0.55) * 1.35
    nx, ny = -dy / L, dx / L
    c1 = (x0 + dx * 0.33 + nx * bend + sway * 0.2, y0 + dy * 0.33 + ny * bend)
    c2 = (x0 + dx * 0.68 - nx * bend * 0.95 + sway * 0.6, y0 + dy * 0.68 - ny * bend * 0.95)
    cs = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        cs.append((u ** 3 * x0 + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t ** 3 * x1,
                   u ** 3 * y0 + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t ** 3 * y1))
    nrm = []
    for i in range(n + 1):
        a, b = cs[max(i - 1, 0)], cs[min(i + 1, n)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        m = math.hypot(tx, ty) or 1
        nrm.append((-ty / m, tx / m, tx / m, ty / m))   # normal, tangent
    return cs, nrm


def flame_col(t):
    """Hottest at the root, coolest at the tip."""
    if t < 0.12:
        return YELLOW
    if t < 0.32:
        return LIGHT_OR
    if t < 0.64:
        return ORANGE
    return RED


def tongue(d, root, tip, w0, bend, sway=0.0, shade_side=1, ph=0.0, wave=0.24, n=28, ow=6):
    """Flame tongue: S-curved centre line, wavy asymmetric edges, deep-red edge line, colour by heat."""
    cs, nr = centreline(root, tip, bend, sway, n)
    hs = [[], []]
    for k in (0, 1):
        for i in range(n + 1):
            t = i / n
            h = w0 / 2 * ((1 - t) ** 1.05) * (1 + 0.4 * math.sin(math.pi * t * 0.85))
            h *= 1 + wave * math.sin(2 * math.pi * (2.3 * t + ph + 0.41 * k)) * math.sin(math.pi * min(t * 1.2, 1))
            hs[k].append(max(h, 0))

    def edge(inset, side, frac=1.0):
        k = 0 if side < 0 else 1
        return [(cs[i][0] + nr[i][0] * max(hs[k][i] - inset, 0) * side * frac,
                 cs[i][1] + nr[i][1] * max(hs[k][i] - inset, 0) * side * frac) for i in range(n + 1)]

    def band(side, f0, f1, t0, t1, col):
        A, B = edge(0.35, side, f0), edge(0.35, side, f1)
        for i in range(int(t0 * n), int(t1 * n)):
            poly(d, [A[i], A[i + 1], B[i + 1], B[i]], col)
    outline(d, edge(0, -1) + edge(0, 1)[::-1], w=ow, closed=False, col=DEEP_RED)
    a0, a1 = edge(0.35, -1), edge(0.35, 1)
    for i in range(n):
        poly(d, [a0[i], a0[i + 1], a1[i + 1], a1[i]], flame_col((i + 0.5) / n))
    band(shade_side, 0.35, 1.0, 0.24, 0.72, RED)
    band(-shade_side, 0.55, 1.0, 0.06, 0.36, YELLOW)
    return cs, nr


def lick(d, parent, t0, side, length, w, s, shade_side=1, ph=0.0):
    """Small flame lick breaking off the side of a parent tongue."""
    (root, tip, w0, bend, psw) = parent
    cs, nr = centreline(root, tip, bend, psw)
    i = int(t0 * 28)
    hh = w0 / 2 * ((1 - t0) ** 1.05)
    nx, ny, tx, ty = nr[i]
    r = (cs[i][0] + nx * hh * 0.55 * side, cs[i][1] + ny * hh * 0.55 * side)
    ln = length * (1 + 0.3 * s * side)
    tp = (r[0] + tx * ln * 0.9 + nx * side * ln * 0.8 - 0.25 * s * ln, r[1] + ty * ln * 0.9 + ny * side * ln * 0.8)
    tongue(d, r, tp, w, 0.9 * side, shade_side=shade_side, ph=ph, wave=0.12, n=14, ow=5)


# ---------------------------------------------------------------- the bust
FACE = [(13.4, 17), (34.6, 17), (35.2, 28), (33.8, 35), (27.2, 40.4), (24, 43.0), (20.8, 40.4),
        (14.2, 35), (12.8, 28)]
NECK = [(19.6, 35), (28.4, 35), (29.2, 45), (18.8, 45)]
TORSO = [(0, 64), (0, 53), (5, 47.5), (14, 44.2), (20.2, 42.6), (24, 47.8), (27.8, 42.6), (34, 44.2), (43, 47.5),
         (48, 53), (48, 64)]

# One flame in a wind, mostly swept up and left, with two tongues rising on the right.
# root, tip, width, bend. Drawn back to front.
TONGUES = [
    ((34.5, 18.5), (41.5, 8.0), 7, -3.0),
    ((31.5, 16.5), (34.5, 4.8), 7.5, -2.6),
    ((30, 17.5), (23.5, 4.2), 8, 3.4),
    ((25, 16), (15, 4.6), 8, 3.6),
    ((20, 17), (6.5, 6.0), 8, 3.4),
    ((16, 20.5), (2.2, 13.5), 8, 3.0),
]
# lick: parent index, t along the parent, side, length, width
LICKS = [(0, 0.45, 1, 3.4, 3.4), (1, 0.5, 1, 3.0, 3.2), (2, 0.5, -1, 3.6, 3.6), (2, 0.7, 1, 2.6, 3.0),
         (3, 0.45, 1, 3.8, 3.6), (3, 0.65, -1, 3.0, 3.2), (4, 0.5, 1, 3.6, 3.6), (4, 0.7, -1, 2.8, 3.0),
         (5, 0.5, 1, 3.2, 3.2)]
WISPS = [((24.6, 3.6), (23.4, 0.8), 3.4), ((15.6, 3.4), (13.8, 0.6), 3.2), ((36.4, 3.2), (37.6, 0.9), 3.0),
         ((42.6, 6.6), (43.6, 3.6), 2.8)]
BANGS = [  # thin wisps over the forehead
    ((19.8, 19.0), (18.4, 22.6), 5.0, 0.9),
    ((29.2, 19.0), (30.6, 22.4), 4.8, 0.8),
]
HAIRLINE = [(13.4, 23), (14.5, 21.6), (17, 19.8), (20.5, 20.4), (24, 20), (27.5, 20.4), (31, 19.8),
            (33.5, 21.6), (34.6, 23)]
CAP_TOP = [(12.8, 22), (13.4, 17), (17, 14.5), (24, 12.8), (31, 14.5), (34.6, 17), (35.2, 22)]


def eye(d, cx, cy, side, o, wide=1.0):
    """side -1 = left eye (outer corner on the left). Narrow, outer corner angled up, straight heavy
    upper lid, clean almond iris with a maroon rim, cream highlight."""
    ow = 3.2 * wide
    outer = (cx + side * ow, cy - 1.9)
    inner = (cx - side * ow, cy - 0.1)
    up = [(outer[0] + (inner[0] - outer[0]) * k / 6, outer[1] + (inner[1] - outer[1]) * k / 6) for k in range(7)]
    lo = smooth([inner, (cx - side * 0.9, cy + 0.55 * o + 0.3), (cx + side * 1.2, cy + 0.4 * o + 0.1), outer])
    pts = up + lo
    d.polygon([P(*p) for p in pts], fill=YELLOW)
    d.line([P(*p) for p in lo], fill=MAROON, width=6)
    hx, hy = cx + side * 0.5, cy - 0.7
    d.rectangle((hx * K - 6, hy * K - 6, hx * K + 6, hy * K + 6), fill=CREAM)
    d.line([P(*p) for p in up], fill=INK, width=11)


def brow(d, cx, cy, side, lift=0.0, tilt=1.0):
    """Short thick V stroke sitting right on the lid, inner end lower."""
    outer = (cx + side * 4.2, cy - 3.3 - lift - 0.5 * (tilt - 1))
    inner = (cx - side * 2.7, cy - 1.9 - lift + 0.4 * (tilt - 1))
    d.line([P(*outer), P(*inner)], fill=MAROON, width=11)


def mouth(d, kind):
    YOFF[0] = -2.7
    if kind == "shout":
        pts = [(20.6, 37.6), (28.2, 37.4), (27.4, 41.0), (24.4, 42.6), (21.4, 41.0)]
        poly(d, pts, INK)
        rect(d, 21.2, 37.9, 27.6, 39.7, CREAM)
        outline(d, pts, 5, col=MAROON)
    elif kind == "squint":
        d.line([P(22.0, 39.0), P(26.8, 38.8)], fill=MAROON, width=8)
    else:
        d.line([P(22.2, 39.0), P(26.6, 39.1)], fill=MAROON, width=8)
    YOFF[0] = 0.0


STRAP = [(9.5, 47.2), (14.5, 44.6), (42, 64), (31, 64)]
LFLAP = [(12.5, 45), (19.2, 40.2), (21.8, 40.6), (24.6, 48.4), (19.8, 46.4)]
RFLAP = [(35.5, 45), (28.8, 40.2), (26.2, 40.6), (23.4, 48.4), (28.2, 46.4)]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def draw_torso(img, d):
    YOFF[0] = TOFF
    shape(d, NECK, ORANGE)
    shape(d, TORSO, NAVY)
    neckm, torm = poly_mask(NECK), poly_mask(TORSO)
    poly(d, [(28, 42.8), (34, 44.4), (43, 47.7), (47.6, 53), (47.6, 64), (40, 64), (36.5, 52)], BLUE)
    paste_mask(img, NAVY_L, both(both(torm, inv(shift(torm, 0, int(9 * F)))), box_mask(0, 0, 19, 80)))
    paste_mask(img, ORANGE, both(both(torm, inv(shift(torm, int(-6 * F), int(5 * F)))), box_mask(34, 0, 48, 56)))
    d = ImageDraw.Draw(img)
    for (a, b, dark, lit) in [((6.5, 52), (10.5, 60.5), NAVY_D, NAVY_L), ((2.5, 57.5), (5.5, 64.5), NAVY_D, NAVY_L),
                              ((36.5, 51.5), (34.5, 60), NAVY_D, BLUE), ((41.5, 55.5), (39.5, 64.5), NAVY_D, BLUE)]:
        d.line([P(*a), P(*b)], fill=dark, width=7)
        d.line([P(a[0] + 0.9, a[1] - 0.3), P(b[0] + 0.9, b[1] - 0.3)], fill=lit, width=4)
    shape(d, STRAP, BROWN, col=NAVY_D)
    d.line([P(15.0, 45.6), P(41, 63.4)], fill=BROWN_L, width=6)
    d.line([P(10.4, 48.2), P(31.5, 63.5)], fill=BROWN_D, width=6)
    for row in (0.3, 0.7):
        for k in range(9):
            t0, t1 = 0.06 + k * 0.1, 0.06 + k * 0.1 + 0.05
            pts = []
            for t in (t0, t1):
                up = (14.5 + 27.5 * t, 44.6 + 19.4 * t)
                lo = (9.5 + 21.5 * t, 47.2 + 16.8 * t)
                pts.append(P(*lerp(lo, up, row)))
            d.line(pts, fill=BROWN_D, width=3)
    rect(d, 24.6, 54.2, 29.8, 59.4, NAVY_D)
    rect(d, 25.4, 55.0, 29.0, 58.6, YELLOW)
    rect(d, 26.2, 55.8, 28.2, 57.8, BROWN_D)
    rect(d, 25.4, 55.0, 26.4, 56.0, CREAM)
    flapm = ImageChops.lighter(poly_mask(LFLAP), poly_mask(RFLAP))
    paste_mask(img, NAVY_D, both(both(shift(flapm, 0, int(10 * F)), torm), inv(flapm)))
    paste_mask(img, RED, both(neckm, box_mask(0, 41.5, 48, 80)))
    d = ImageDraw.Draw(img)
    shape(d, LFLAP, NAVY, col=NAVY_D)
    shape(d, RFLAP, BLUE, col=NAVY_D)
    d.line([P(*p) for p in (LFLAP[0], LFLAP[1], LFLAP[2])], fill=NAVY_L, width=5)
    d.line([P(*p) for p in (RFLAP[0], RFLAP[1], RFLAP[2])], fill=NAVY, width=5)
    YOFF[0] = 0.0
    return neckm, torm


def draw_face(img, neckm, torm, expr):
    facem = poly_mask(FACE)
    jaw = both(both(shift(facem, int(4 * F), int(20 * F)), neckm), inv(facem))
    paste_mask(img, RED, both(jaw, inv(torm)))
    jaw2 = both(both(shift(facem, int(4 * F), int(8 * F)), neckm), inv(facem))
    paste_mask(img, MAROON, both(jaw2, inv(torm)))
    d = ImageDraw.Draw(img)
    shape(d, FACE, ORANGE)
    paste_mask(img, LIGHT_OR, both(facem, poly_mask([(15.0, 29.0), (21.0, 30.0), (20.2, 34.0), (17.6, 34.2), (15.4, 32.5)])))
    paste_mask(img, LIGHT_OR, both(facem, poly_mask([(15.4, 22.5), (21, 22.5), (20.5, 24.5), (15.2, 25)])))
    paste_mask(img, RED, both(facem, inv(shift(facem, int(-22 * F), 0))))
    paste_mask(img, RED, both(facem, poly_mask([(26.0, 34.0), (34.8, 30.5), (33.6, 35.5), (27.0, 40.8), (24.5, 40)])))
    chin = both(facem, inv(shift(facem, 0, int(-14 * F))))
    paste_mask(img, RED, both(chin, shift(facem, int(-30 * F), 0)))
    paste_mask(img, DEEP_RED, both(both(facem, inv(shift(facem, int(-9 * F), 0))), box_mask(0, 25, 48, 40)))
    paste_mask(img, LIGHT_OR, both(both(facem, inv(shift(facem, int(-4 * F), 0))), box_mask(0, 26, 48, 36)))
    d = ImageDraw.Draw(img)
    d.line([P(24.0, 25.4), P(24.0, 30.0)], fill=LIGHT_OR, width=7)
    d.line([P(25.0, 31.4), P(25.5, 33.0)], fill=DEEP_RED, width=7)
    mouth(d, expr)
    outline(d, FACE[1:] + FACE[:1], w=9, closed=False)
    if expr == "shout":
        o, wd, lift, tilt = 2.2, 1.15, 0.6, 1.0
    elif expr == "squint":
        o, wd, lift, tilt = 1.0, 1.05, -0.1, 1.5
    else:
        o, wd, lift, tilt = 1.6, 1.1, 0.0, 1.0
    cy = 27.8
    eye(d, 19.2, cy, -1, o, wd)
    eye(d, 28.8, cy, 1, o, wd)
    brow(d, 19.2, cy + 0.2, -1, lift, tilt)
    brow(d, 28.8, cy + 0.2, 1, lift, tilt)
    return facem


def draw_hair(img, facem, s):
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    cap_pts = CAP_TOP + HAIRLINE[::-1]
    poly(hd, cap_pts, ORANGE)
    outline(hd, CAP_TOP[1:-1], w=6, closed=False, col=DEEP_RED)
    cap = poly_mask(cap_pts)
    # wisps floating above the tips, then back-to-front tongues with their licks
    for k, (r, t, w) in enumerate(WISPS):
        flick = 0.5 * s * (1 if k % 2 else -1)
        tongue(hd, (r[0] + flick, r[1]), (t[0] + flick * 1.6, t[1] + 0.6 * s * (-1) ** k), w, 0.6, ph=k, wave=0.1, n=12, ow=4)
    params = []
    for i, (r, t, w, b) in enumerate(TONGUES):
        sw = s * (2.2 + 0.3 * (i % 2)) * (-1 if i < 2 else 1)
        params.append((r, t, w, b, sw))
    for (pi_, t0, side, ln, w) in LICKS:
        lick(hd, params[pi_], t0 + 0.05 * s * side, side, ln, w, s, shade_side=-side, ph=pi_ * 0.3 + s * 0.4)
    for i, (r, t, w, b) in enumerate(TONGUES):
        tongue(hd, r, t, w, b, sway=params[i][4], ph=i * 0.37 + s * 0.45)
    # glowing root band: yellow at the hairline, light orange above it
    band = both(both(cap, inv(shift(cap, 0, int(-12 * F)))), box_mask(0, 17, 48, 27))
    band2 = both(both(both(cap, inv(shift(cap, 0, int(-24 * F)))), shift(cap, 0, int(-12 * F))), box_mask(0, 17, 48, 27))
    hl.paste(LIGHT_OR + (255,), (0, 0), band2)
    hl.paste(YELLOW + (255,), (0, 0), band)
    shd = both(both(shift(cap, 0, int(15 * F)), facem), inv(cap))
    img.paste(RED, (0, 0), shd)
    shd2 = both(both(shift(cap, 0, int(6 * F)), facem), inv(cap))
    img.paste(DEEP_RED, (0, 0), shd2)
    for i, (r, t, w, b) in enumerate(BANGS):
        tongue(hd, r, t, w, b, sway=s * 0.7, shade_side=1 if i % 2 == 0 else -1, ow=5, ph=i + s * 0.3)
    img.paste(hl, (0, 0), hl.split()[3])
    d = ImageDraw.Draw(img)
    d.line([P(*p) for p in HAIRLINE], fill=DEEP_RED, width=4, joint="curve")


def draw_frame(sway=0.0, expr="calm"):
    img = Image.new("RGB", (SW, SH), BG)
    d = ImageDraw.Draw(img)
    neckm, torm = draw_torso(img, d)
    facem = draw_face(img, neckm, torm, expr)
    draw_hair(img, facem, sway)
    return img


EMBERS = [((44.5, 12.0), YELLOW), ((45.5, 6.0), LIGHT_OR), ((39.0, 1.6), YELLOW), ((29.0, 1.4), LIGHT_OR),
          ((10.0, 1.6), YELLOW), ((1.2, 8.5), LIGHT_OR)]


def add_embers(out, sway, expr):
    """Little 2x2 embers drifting off the flame, placed on the finished pixel art."""
    px = out.load()
    u = OW / 48
    for k, ((x, y), col) in enumerate(EMBERS):
        x += sway * (0.8 + 0.3 * k) * (1 if k < 3 else -1)
        y += -sway * 0.8 * (1 if k % 2 else -1) + (0.8 if expr == "shout" else 0)
        for dx in range(2):
            for dy in range(2):
                X, Y = int(x * u) + dx, int(y * u) + dy
                if 0 <= X < out.width and 0 <= Y < out.height and px[X, Y][3] == 0:
                    px[X, Y] = col + (255,)


def snap(art, mask):
    px, mk = art.load(), mask.load()
    out = Image.new("RGBA", art.size, (0, 0, 0, 0))
    o = out.load()
    for y in range(art.height):
        for x in range(art.width):
            if mk[x, y] < 128:
                continue
            c = px[x, y]
            o[x, y] = min(PALETTE, key=lambda p: sum((a - b) ** 2 for a, b in zip(c, p))) + (255,)
    return out


def cleanup(im, protect=()):
    """Drop alpha specks, repaint pixels matching none of their 4 neighbours."""
    o = im.load()
    w, h = im.size
    for _ in range(2):
        ch = []
        for y in range(h):
            for x in range(w):
                if o[x, y][3] == 0:
                    continue
                op = [o[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                      if 0 <= x + dx < w and 0 <= y + dy < h and o[x + dx, y + dy][3] > 0]
                if len(op) <= 1:
                    ch.append((x, y, (0, 0, 0, 0)))
                    continue
                if o[x, y] in op or (x, y) in protect:
                    continue
                cnt = {}
                for n in op:
                    cnt[n] = cnt.get(n, 0) + 1
                ch.append((x, y, max(cnt, key=cnt.get)))
        for x, y, c in ch:
            o[x, y] = c
    return im


def recolor_interior(im, keep=None):
    """Near-black ink stays on the outer silhouette (and the eye lids); interior ink lines become maroon on
    skin, dark navy on the jacket, dark brown on the strap."""
    o = im.load()
    w, h = im.size

    def get(x, y):
        return o[x, y] if 0 <= x < w and 0 <= y < h else (0, 0, 0, 0)
    ch = []
    for y in range(h):
        for x in range(w):
            if o[x, y][:3] != INK or o[x, y][3] == 0 or (keep and keep[0] <= x <= keep[2] and keep[1] <= y <= keep[3]):
                continue
            ring = [get(x + dx, y + dy)[:3] if get(x + dx, y + dy)[3] else None
                    for dx in range(-2, 3) for dy in range(-2, 3)]
            if None in ring or any(c in (YELLOW, CREAM) for c in ring):
                continue
            nv = sum(c in NAVYS for c in ring)
            br = sum(c in BROWNS for c in ring)
            ch.append((x, y, (NAVY_D if nv >= max(br, len(ring) - nv - br) else BROWN_D if br > len(ring) / 3 else MAROON) + (255,)))
    for x, y, c in ch:
        o[x, y] = c
    return im


def make_frame(sway, expr):
    src = draw_frame(sway, expr)
    diff = ImageChops.difference(src, Image.new("RGB", src.size, BG)).convert("L").point(lambda v: 255 if v > 0 else 0)
    mask = diff.resize((W, H), Image.BOX).point(lambda v: 255 if v > 110 else 0)
    out = snap(pixelize(src, W, 40), mask)
    px = out.load()
    prot = {(x, y) for y in range(44, 66) for x in range(26, 72) if px[x, y] == CREAM + (255,)}
    out = cleanup(out, prot)
    out = recolor_interior(out, (38, 66, 60, 82) if expr == "shout" else None)
    add_embers(out, sway, expr)
    return out


FRAMES = [(-1, "calm"), (1, "calm"), (0.3, "shout"), (-0.4, "squint")]


def main():
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    frames = [make_frame(s, e) for s, e in FRAMES]
    strip = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    dst = os.path.join(root, "assets", "title", "anime")
    os.makedirs(dst, exist_ok=True)
    strip.save(os.path.join(dst, "flint_bust.png"))
    review = sys.argv[1] if len(sys.argv) > 1 else None
    if not review:
        return
    os.makedirs(review, exist_ok=True)
    S = 4
    bg = (92, 112, 134, 255)
    big = [f.resize((W * S, H * S), Image.NEAREST) for f in frames]
    cw = W * S + 8
    clean = Image.new("RGBA", (cw * 4 + 8, H * S + 16), bg)
    for i, f in enumerate(big):
        clean.paste(f, (8 + i * cw, 8), f)
    clean.convert("RGB").save(os.path.join(review, "flint_bust_clean.png"))
    sheet = Image.new("RGBA", (cw * 5 + 8, 144 * S + 16), bg)
    sheet.paste(clean, (0, 0))
    mock_path = os.path.join(review, "..", "poc", "flint_mock2.png")
    if os.path.exists(mock_path):
        mock = Image.open(mock_path).convert("RGBA").crop((392, 0, 776, 576))
        lay = Image.new("RGBA", mock.size, bg)
        lay.alpha_composite(big[0])
        sheet.paste(Image.blend(mock, lay, 0.5), (8 + 4 * cw, 8))
    sheet.convert("RGB").save(os.path.join(review, "flint_bust_review.png"))
    x1 = Image.new("RGBA", strip.size, bg)
    x1.alpha_composite(strip)
    x1.convert("RGB").save(os.path.join(review, "flint_bust_x1.png"))


if __name__ == "__main__":
    main()
