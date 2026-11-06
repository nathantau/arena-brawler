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


def tongue(d, root, tip, w0, bend, sway=0.0, shade_side=1, ph=0.0, wave=0.24, n=28, ow=6, cols=None):
    """Flame tongue: S-curved centre line, wavy asymmetric edges, deep-red edge line, colour by heat.
    cols = (edge, colour fn of t, shade band, lit band) restyles it (Sakura's hair)."""
    edge_col, col_fn, shade_col, lit_col = cols or (DEEP_RED, flame_col, RED, YELLOW)
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
    outline(d, edge(0, -1) + edge(0, 1)[::-1], w=ow, closed=False, col=edge_col)
    a0, a1 = edge(0.35, -1), edge(0.35, 1)
    for i in range(n):
        poly(d, [a0[i], a0[i + 1], a1[i + 1], a1[i]], col_fn((i + 0.5) / n))
    band(shade_side, 0.35, 1.0, 0.24, 0.72, shade_col)
    band(-shade_side, 0.55, 1.0, 0.06, 0.36, lit_col)
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
FACE = [(13.4, 17), (34.6, 17), (35.6, 27.5), (35.0, 33), (31.6, 38.6), (27.6, 41.6), (24, 42.4), (20.4, 41.6),
        (16.4, 38.6), (13.0, 33), (12.4, 27.5)]
EAR_L = [(14.2, 25.6), (11.8, 26.2), (10.6, 28.2), (10.8, 30.6), (12.2, 32.4), (14.4, 32.6)]
EAR_R = [(48 - x, y) for x, y in EAR_L]
NECK = [(19.6, 35), (28.4, 35), (29.2, 45), (18.8, 45)]
TORSO = [(0, 64), (0, 53), (5, 47.5), (14, 44.2), (20.2, 42.6), (24, 47.8), (27.8, 42.6), (34, 44.2), (43, 47.5),
         (48, 53), (48, 64)]

# One flame in a wind, mostly swept up and left, with two tongues rising on the right.
# root, tip, width, bend. Drawn back to front.
TONGUES = [
    ((34.5, 18.5), (41.5, 6.0), 7, -3.0),
    ((31.5, 16.5), (34.5, 3.2), 7.5, -2.6),
    ((30, 17.5), (23.5, 2.4), 8, 3.4),
    ((25, 16), (15, 2.8), 8, 3.6),
    ((20, 17), (6.5, 4.4), 8, 3.4),
    ((16, 20.5), (2.2, 12.0), 8, 3.0),
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
    outer = (cx + side * ow, cy - 2.4)
    inner = (cx - side * ow, cy - 0.6)
    up = [(outer[0] + (inner[0] - outer[0]) * k / 6, outer[1] + (inner[1] - outer[1]) * k / 6) for k in range(7)]
    lo = smooth([inner, (cx - side * 0.9, cy + 0.55 * o + 0.8), (cx + side * 1.2, cy + 0.4 * o + 0.6), outer])
    pts = up + lo
    d.polygon([P(*p) for p in pts], fill=YELLOW)
    d.line([P(*p) for p in lo], fill=MAROON, width=6)
    hx, hy = cx + side * 0.5, cy - 1.0
    d.rectangle((hx * K - 6, hy * K - 6, hx * K + 6, hy * K + 6), fill=CREAM)
    d.line([P(*p) for p in up], fill=INK, width=11)


def brow(d, cx, cy, side, lift=0.0, tilt=1.0):
    """Short thick V stroke sitting right on the lid, inner end lower."""
    outer = (cx + side * 4.2, cy - 3.8 - lift - 0.5 * (tilt - 1))
    inner = (cx - side * 2.7, cy - 2.4 - lift + 0.4 * (tilt - 1))
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
    # ears: small C shapes tucked behind the face, lit left, shadowed right, maroon inner fold
    shape(d, EAR_L, ORANGE)
    shape(d, EAR_R, RED)
    d.line([P(11.9, 26.9), P(11.0, 28.4), P(11.1, 30.4)], fill=LIGHT_OR, width=4, joint="curve")
    d.line([P(48 - 11.9, 26.9), P(48 - 11.0, 28.4), P(48 - 11.1, 30.4)], fill=DEEP_RED, width=4, joint="curve")
    d.line([P(13.0, 27.8), P(12.1, 29.2), P(12.5, 31.0), P(13.5, 31.7)], fill=MAROON, width=4, joint="curve")
    d.line([P(48 - 13.0, 27.8), P(48 - 12.1, 29.2), P(48 - 12.5, 31.0), P(48 - 13.5, 31.7)], fill=MAROON, width=4, joint="curve")
    shape(d, FACE, ORANGE)
    paste_mask(img, LIGHT_OR, both(facem, poly_mask([(15.0, 29.0), (21.0, 30.0), (20.2, 34.0), (17.6, 34.2), (15.4, 32.5)])))
    paste_mask(img, LIGHT_OR, both(facem, poly_mask([(15.4, 22.5), (21, 22.5), (20.5, 24.5), (15.2, 25)])))
    paste_mask(img, RED, both(facem, inv(shift(facem, int(-22 * F), 0))))
    paste_mask(img, RED, both(facem, poly_mask([(26.0, 34.0), (35.4, 30.5), (34.4, 35.5), (28.0, 41.4), (24.5, 41)])))
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
    # back-to-front tongues with their licks
    params = []
    for i, (r, t, w, b) in enumerate(TONGUES):
        sw = s * (2.2 + 0.3 * (i % 2)) * (-1 if i < 2 else 1)
        params.append((r, t, w, b, sw))
    for (pi_, t0, side, ln, w) in LICKS:
        lick(hd, params[pi_], t0 + 0.05 * s * side, side, ln, w, s, shade_side=-side, ph=pi_ * 0.3 + s * 0.4)
    for i, (r, t, w, b) in enumerate(TONGUES):
        tongue(hd, r, t, w, b, sway=params[i][4], ph=i * 0.37 + s * 0.45)
    # flame side locks over the top half of each ear, licking outward and back; they flicker
    for side, (r, t) in ((-1, ((13.4, 21.0), (9.6, 31.0))), (1, ((34.6, 21.0), (38.4, 31.0)))):
        tongue(hd, r, t, 4.8, 1.6 * side, sway=s * 0.9 * -side, shade_side=-side, ph=0.5 + s * 0.4 * side, wave=0.2, n=20, ow=5)
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


# Sparks rising off the tips, hottest first: yellow 2x2, orange 1x1, red 1x1, drifting up and away.
SPARKS = [  # first spark position (design units), per-step drift
    ((5.0, 3.4), (-1.5, -1.5)), ((13.6, 1.8), (-1.4, -1.3)), ((22.0, 1.2), (-1.3, -1.1)),
    ((36.0, 2.0), (1.0, -1.4)), ((42.6, 4.8), (1.1, -1.6)), ((0.9, 10.6), (-0.6, -1.8)),
]
SPARK_STEPS = [(YELLOW, 2), (LIGHT_OR, 1), (RED, 1)]


def add_embers(out, sway, expr):
    """1-2 px sparks that rise and cool (yellow, orange, red), placed on the finished pixel art."""
    px = out.load()
    u = OW / 48
    for k, ((x, y), (dx, dy)) in enumerate(SPARKS):
        for j, (col, size) in enumerate(SPARK_STEPS):
            fl = sway * (0.7 + 0.3 * j) * (1 if k % 2 else -1)
            X = int((x + dx * j * 1.3 + fl) * u)
            Y = int((y + dy * j * 1.3 - abs(sway) * 0.4 * j) * u)
            for ax in range(size):
                for ay in range(size):
                    if 0 <= X + ax < out.width and 0 <= Y + ay < out.height and px[X + ax, Y + ay][3] == 0:
                        px[X + ax, Y + ay] = col + (255,)


def snap(art, mask, palette=None):
    palette = palette or PALETTE
    px, mk = art.load(), mask.load()
    out = Image.new("RGBA", art.size, (0, 0, 0, 0))
    o = out.load()
    for y in range(art.height):
        for x in range(art.width):
            if mk[x, y] < 128:
                continue
            c = px[x, y]
            o[x, y] = min(palette, key=lambda p: sum((a - b) ** 2 for a, b in zip(c, p))) + (255,)
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


def flint_main():
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


# ================================================================ Sakura
# Built from Flint's own code (same FACE construction, eye / brow / mouth drawing, torso layout, tongue() hair
# rendering, snap / cleanup / recolor_interior), with her palette mapped role for role:
#   skin  ORANGE -> SK, LIGHT_OR -> SK_L, RED -> SK_S, DEEP_RED -> SK_D      cloth  NAVY -> KIM, BLUE -> KIM_S,
#   NAVY_L -> CREAM, NAVY_D -> KIM_D      hair (replaces the flame ramp) H_HI / H_L / H / H_D, edge H_EDGE.
# Output: assets/title/anime/sakura_bust.png (calm A, calm B, determined, shout).
SK = (240, 193, 154); SK_L = (252, 222, 198); SK_S = (222, 150, 130); SK_D = (176, 96, 100)
BLUSH = (240, 150, 150)
ROSE = (200, 62, 124); H_EDGE = (104, 30, 78)
HR = (226, 110, 160); H_D = (190, 72, 126); H_L = (244, 160, 196); H_HI = (252, 214, 230)
KIM = (232, 230, 244); KIM_S = (200, 198, 226); KIM_D = (150, 146, 190)
RED_L = (236, 110, 104); WHITE = (255, 255, 255)
SAKURA_PALETTE = [INK, MAROON, SK, SK_L, SK_S, SK_D, BLUSH, CREAM, WHITE, ROSE, H_EDGE, HR, H_D, H_L, H_HI, KIM, KIM_S,
                  KIM_D, RED, DEEP_RED, RED_L, YELLOW]
KIMS = {KIM, KIM_S, KIM_D, CREAM}
HAIRS = {H_EDGE, HR, H_D, H_L, H_HI}
EYE_COLS = {ROSE, WHITE}


def lc(c):
    """Source colour that comes out as c after pixelize's 0.6 line darkening (hair edge, brows)."""
    return tuple(min(255, round(v / 0.6)) for v in c)


def hair_col(t):
    """Light at the root, rose in the body, deeper towards the tip."""
    if t < 0.12:
        return H_HI
    if t < 0.3:
        return H_L
    if t < 0.66:
        return HR
    return H_D


def hair(d, root, tip, w0, bend, sway=0.0, shade_side=1, ph=0.0, wave=0.14, n=28, ow=6):
    return tongue(d, root, tip, w0, bend, sway=sway, shade_side=shade_side, ph=ph, wave=wave, n=n, ow=ow,
                  cols=(lc(H_EDGE), hair_col, H_D, H_HI))


# face: Flint's polygon, narrowed about 1.4 units at the jaw with a softer chin
SFACE = [(13.4, 17), (34.6, 17), (35.4, 27.5), (34.0, 33), (30.2, 38.4), (26.6, 41.8), (24, 42.8), (21.4, 41.8),
         (17.8, 38.4), (14.0, 33), (12.6, 27.5)]
SNECK = [(20.6, 35), (27.4, 35), (28.0, 45), (20.0, 45)]
STORSO = [(0, 64), (0, 53.5), (5, 48.5), (14, 45.0), (20.4, 43.0), (23.45, 52.0), (27.6, 43.0), (34, 45.0), (43, 48.5),
          (48, 53.5), (48, 64)]


def s_eye(img, d, cx, cy, side, o, wide=1.0):
    """Flint's almond with a straight heavy upper lid, iris ~1.3x taller, rose iris with a darker top, a cream
    highlight and one tiny lash flick at the outer corner."""
    ow = 3.2 * wide
    outer = (cx + side * ow, cy - 1.9)
    inner = (cx - side * ow, cy - 0.9)
    up = [(outer[0] + (inner[0] - outer[0]) * k / 6, outer[1] + (inner[1] - outer[1]) * k / 6) for k in range(7)]
    lo = smooth([inner, (cx - side * 1.0, cy + 0.5 * o + 1.2), (cx + side * 1.2, cy + 0.4 * o + 1.0), outer])
    pts = up + lo
    d.polygon([P(*p) for p in pts], fill=ROSE)
    lm = mask_of(lambda m: m.line([P(*p) for p in up], fill=255, width=30))
    paste_mask(img, H_EDGE, both(poly_mask(pts), lm))
    d = ImageDraw.Draw(img)
    d.line([P(*p) for p in lo], fill=MAROON, width=6)
    hx, hy = cx + side * 0.5, cy - 0.7
    d.rectangle((hx * K - 7, hy * K - 7, hx * K + 7, hy * K + 7), fill=WHITE)
    d.line([P(*p) for p in up], fill=INK, width=11)
    d.line([P(*outer), P(outer[0] + side * 1.3, outer[1] - 0.8)], fill=INK, width=8)
    return d


def s_brow(d, cx, cy, side, lift=0.0, tilt=1.0):
    """Thinner than Flint's, softly arched when calm, angled down for determined."""
    outer = (cx + side * 4.0, cy - 3.6 - lift - 0.5 * (tilt - 1))
    inner = (cx - side * 2.7, cy - 2.6 - lift + 0.5 * (tilt - 1))
    mid = ((outer[0] + inner[0]) / 2 + side * 0.2, (outer[1] + inner[1]) / 2 - 0.5 / tilt)
    d.line([P(*p) for p in smooth([inner, mid, outer], 6)], fill=lc(MAROON), width=8, joint="curve")


def s_mouth(d, kind):
    YOFF[0] = -2.7
    if kind == "shout":
        pts = [(21.9, 38.0), (26.1, 37.8), (25.6, 40.6), (24.0, 41.8), (22.4, 40.6)]
        poly(d, pts, INK)
        rect(d, 22.3, 38.2, 25.7, 39.4, CREAM)
        outline(d, pts, 5, col=MAROON)
    elif kind == "determined":
        d.line([P(22.8, 39.2), P(25.2, 39.1)], fill=MAROON, width=8)
    else:
        d.line([P(*p) for p in smooth([(22.7, 38.9), (23.5, 39.3), (24.6, 39.3), (25.4, 38.8)], 6)], fill=MAROON, width=8,
               joint="curve")
    YOFF[0] = 0.0


def s_draw_torso(img, d):
    YOFF[0] = TOFF
    shape(d, SNECK, SK)
    shape(d, STORSO, KIM)
    neckm, torm = poly_mask(SNECK), poly_mask(STORSO)
    poly(d, [(28, 43.8), (34, 45.2), (43, 48.7), (47.6, 54), (47.6, 64), (40, 64), (36.5, 52)], KIM_S)
    paste_mask(img, CREAM, both(both(torm, inv(shift(torm, 0, int(9 * F)))), box_mask(0, 0, 19, 80)))
    paste_mask(img, H_HI, both(both(torm, inv(shift(torm, int(-6 * F), int(5 * F)))), box_mask(34, 0, 48, 56)))
    d = ImageDraw.Draw(img)
    for (a, b, dark, lit) in [((5.5, 49), (8.5, 55), KIM_D, CREAM), ((2.5, 52), (4.5, 56), KIM_D, CREAM),
                              ((37.5, 49.5), (36, 55), KIM_D, KIM_S), ((41.5, 51), (40.5, 56), KIM_D, KIM_S)]:
        d.line([P(*a), P(*b)], fill=dark, width=7)
        d.line([P(a[0] + 0.9, a[1] - 0.3), P(b[0] + 0.9, b[1] - 0.3)], fill=lit, width=4)
    # chest in the neckline, collar crossing left over right (our right flap on top), red trim
    poly(d, [(20.4, 43.0), (27.6, 43.0), (23.45, 52.0)], SK_S)
    d.line([P(*p) for p in [(20.4, 43.2), (23.45, 52.0)]], fill=DEEP_RED, width=22)
    d.line([P(*p) for p in [(20.4, 43.2), (23.45, 52.0)]], fill=RED, width=14)
    top = [(27.7, 43.2), (24.4, 50.0), (21.0, 57.6)]
    d.line([P(*p) for p in top], fill=DEEP_RED, width=24)
    d.line([P(*p) for p in top], fill=RED, width=16)
    d.line([P(*p) for p in [(27.0, 44.0), (24.0, 50.6)]], fill=RED_L, width=5)
    d.line([P(*p) for p in [(29.4, 44.4), (26.0, 51.6), (22.6, 58.0)]], fill=KIM_D, width=6)
    paste_mask(img, SK_S, both(neckm, box_mask(0, 41.5, 48, 80)))
    d = ImageDraw.Draw(img)
    # obi across the bottom with a darker fold
    poly(d, [(0, 56.4), (48, 56.4), (48, 64), (0, 64)], RED)
    d.line([P(0, 56.4), P(48, 56.4)], fill=DEEP_RED, width=8)
    d.line([P(0, 57.2), P(48, 57.2)], fill=RED_L, width=5)
    for (a, b) in (((12.6, 57.8), (10.6, 64)), ((35.8, 57.8), (38.2, 64))):
        d.line([P(*a), P(*b)], fill=DEEP_RED, width=7)
        d.line([P(a[0] + 0.9, a[1]), P(b[0] + 0.9, b[1])], fill=RED_L, width=4)
    YOFF[0] = 0.0
    return neckm, torm


def s_draw_face(img, neckm, torm, expr):
    facem = poly_mask(SFACE)
    jaw = both(both(shift(facem, int(4 * F), int(20 * F)), neckm), inv(facem))
    paste_mask(img, SK_S, both(jaw, inv(torm)))
    jaw2 = both(both(shift(facem, int(4 * F), int(8 * F)), neckm), inv(facem))
    paste_mask(img, SK_D, both(jaw2, inv(torm)))
    d = ImageDraw.Draw(img)
    # ears as Flint's: small C shapes tucked behind the face, lit left, shadowed right, deep inner fold
    shape(d, EAR_L, SK)
    shape(d, EAR_R, SK_S)
    d.line([P(11.9, 26.9), P(11.0, 28.4), P(11.1, 30.4)], fill=SK_L, width=4, joint="curve")
    d.line([P(48 - 11.9, 26.9), P(48 - 11.0, 28.4), P(48 - 11.1, 30.4)], fill=SK_D, width=4, joint="curve")
    d.line([P(13.0, 27.8), P(12.1, 29.2), P(12.5, 31.0), P(13.5, 31.7)], fill=SK_D, width=4, joint="curve")
    d.line([P(48 - 13.0, 27.8), P(48 - 12.1, 29.2), P(48 - 12.5, 31.0), P(48 - 13.5, 31.7)], fill=SK_D, width=4, joint="curve")
    shape(d, SFACE, SK)
    paste_mask(img, SK_L, both(facem, poly_mask([(15.0, 29.0), (21.0, 30.0), (20.2, 34.0), (17.6, 34.2), (15.4, 32.5)])))
    paste_mask(img, SK_L, both(facem, poly_mask([(15.4, 22.5), (21, 22.5), (20.5, 24.5), (15.2, 25)])))
    paste_mask(img, SK_S, both(facem, inv(shift(facem, int(-22 * F), 0))))
    paste_mask(img, SK_S, both(facem, poly_mask([(26.0, 34.0), (35.2, 30.5), (33.6, 36.0), (27.4, 41.8), (24.5, 41.4)])))
    chin = both(facem, inv(shift(facem, 0, int(-14 * F))))
    paste_mask(img, SK_S, both(chin, shift(facem, int(-30 * F), 0)))
    paste_mask(img, SK_D, both(both(facem, inv(shift(facem, int(-9 * F), 0))), box_mask(0, 25, 48, 40)))
    paste_mask(img, SK_L, both(both(facem, inv(shift(facem, int(-4 * F), 0))), box_mask(0, 26, 48, 36)))
    d = ImageDraw.Draw(img)
    for bx in (16.6, 31.4):
        d.ellipse(((bx - 1.8) * K, 32.3 * K, (bx + 1.8) * K, 33.9 * K), fill=BLUSH)
    d.line([P(25.0, 31.6), P(25.3, 32.8)], fill=SK_D, width=7)       # nose: one shade stroke
    s_mouth(d, expr)
    outline(d, SFACE[1:] + SFACE[:1], w=9, closed=False)
    if expr == "shout":
        o, wd, lift, tilt = 2.2, 1.12, 0.6, 1.0
    elif expr == "determined":
        o, wd, lift, tilt = 1.2, 1.05, -0.1, 1.5
    else:
        o, wd, lift, tilt = 1.6, 1.1, 0.0, 1.0
    cy = 27.8
    s_eye(img, d, 19.2, cy, -1, o, wd)
    s_eye(img, d, 28.8, cy, 1, o, wd)
    d = ImageDraw.Draw(img)
    s_brow(d, 19.2, cy + 0.2, -1, lift, tilt)
    s_brow(d, 28.8, cy + 0.2, 1, lift, tilt)
    return facem


SCAP_TOP = [(11.2, 23), (12.0, 16.4), (16.5, 12.2), (24, 10.4), (31.5, 12.2), (36.0, 16.4), (36.8, 23)]
SHAIRLINE = [(13.4, 23.5), (14.5, 21.8), (17, 20.4), (20.5, 20.8), (24, 20.2), (27.5, 20.8), (31, 20.4), (33.5, 21.8),
             (34.6, 23.5)]
# bangs: short wide tongues across the forehead ending above the brows (root, tip, width, bend)
SBANGS = [((15.0, 17.5), (14.4, 23.2), 6.0, 0.8), ((18.4, 17.0), (17.6, 23.8), 6.0, 0.7),
          ((21.8, 16.8), (21.4, 24.0), 6.0, 0.5), ((25.4, 16.8), (26.0, 23.8), 6.0, -0.5),
          ((28.9, 17.0), (30.0, 23.6), 6.0, -0.7), ((32.4, 17.5), (33.6, 23.0), 6.0, -0.8)]
# long locks over the shoulders: root, tip, width, bend (left side; the right side mirrors it)
SLOCKS = [((11.4, 18.5), (6.0, 52.0), 5.2, 3.6), ((12.4, 20.0), (13.6, 47.0), 3.8, -2.8)]
# long locks behind the head and shoulders
SBACK = [((14.0, 21.0), (5.0, 60.0), 9.0, 2.4), ((15.5, 22.0), (9.5, 63.0), 8.0, -2.0), ((17.0, 23.0), (15.0, 63.0), 7.0, 1.6)]


def mir(p):
    return (48 - p[0], p[1])


BACK_COLS = (lc(H_EDGE), lambda t: H_D if t < 0.7 else H_EDGE, H_EDGE, H)      # behind her: deeper tones


def s_back_hair(img, s):
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    poly(hd, [(11.0, 22.0), (37.0, 22.0), (40.0, 50.0), (8.0, 50.0)], H_EDGE)
    for i, (r, t, w, b) in enumerate(SBACK):
        sw = s * (1.2 + 0.25 * i)
        tongue(hd, r, t, w, b, sway=sw, ph=i * 0.4 + s * 0.2, wave=0.14, cols=BACK_COLS)
        tongue(hd, mir(r), mir(t), w, -b, sway=sw, shade_side=-1, ph=i * 0.4 + 0.2 + s * 0.2, wave=0.14, cols=BACK_COLS)
    img.paste(hl, (0, 0), hl.split()[3])


def s_draw_hair(img, facem, s):
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    cap_pts = SCAP_TOP + SHAIRLINE[::-1]
    # long locks over the shoulders (under the cap, which hides their roots)
    for i, (r, t, w, b) in enumerate(SLOCKS):
        sw = s * (1.4 + 0.3 * i)
        hair(hd, r, t, w, b, sway=sw, ph=i * 0.37 + s * 0.2, n=36)
        hair(hd, mir(r), mir(t), w, -b, sway=sw, shade_side=-1, ph=i * 0.37 + 0.3 + s * 0.2, n=36)
    poly(hd, cap_pts, HR)
    outline(hd, SCAP_TOP[1:-1], w=6, closed=False, col=lc(H_EDGE))
    cap = poly_mask(cap_pts)
    hl.paste(H_D + (255,), (0, 0), both(cap, poly_mask([(31.4, 11), (37, 16), (37, 24), (33.4, 22), (32.2, 15)])))
    # glossy band across the crown (angel ring): pale pink, brightest on the left
    ring_t = smooth([(14.4, 19.4), (18, 16.2), (24, 14.6), (30, 16.2), (33.4, 19.2)], 8)
    ring_b = [(x, y + 2.2 - 0.8 * abs(x - 24) / 10) for x, y in ring_t]
    poly(hd, ring_t + ring_b[::-1], H_L)
    core_t = smooth([(15.4, 18.6), (18.8, 15.9), (23.4, 14.9)], 8)
    poly(hd, core_t + [(x, y + 1.3) for x, y in core_t][::-1], H_HI)
    shd = both(both(shift(cap, 0, int(15 * F)), facem), inv(cap))
    img.paste(SK_S, (0, 0), shd)
    shd2 = both(both(shift(cap, 0, int(6 * F)), facem), inv(cap))
    img.paste(SK_D, (0, 0), shd2)
    for i, (r, t, w, b) in enumerate(SBANGS):
        hair(hd, r, t, w, b, sway=s * 0.5, shade_side=1 if i < 3 else -1, ow=5, ph=i * 0.6 + s * 0.2, n=16)
    # side locks over the top half of each ear, like Flint's
    for side, (r, t) in ((-1, ((13.4, 21.0), (10.4, 36.0))), (1, ((34.6, 21.0), (37.6, 36.0)))):
        hair(hd, r, t, 4.8, 1.6 * side, sway=s * 0.6, shade_side=-side, ph=0.5 + s * 0.2 * side, ow=5, n=20)
    # cherry blossom clip on her left
    cx, cy = 14.6, 15.4
    for k in range(5):
        a = math.radians(-100 + 72 * k)
        px_, py_ = cx + 1.9 * math.cos(a), cy + 1.9 * math.sin(a)
        pts = []
        for j in range(14):
            tt = 2 * math.pi * j / 14
            ex, ey = 1.8 * math.cos(tt), 1.4 * math.sin(tt)
            pts.append((px_ + ex * math.cos(a) - ey * math.sin(a), py_ + ex * math.sin(a) + ey * math.cos(a)))
        poly(hd, pts, H_HI)
        outline(hd, pts, w=4, col=lc(H_D))
    hd.ellipse(((cx - 1.0) * K, (cy - 1.0) * K, (cx + 1.0) * K, (cy + 1.0) * K), fill=YELLOW)
    img.paste(hl, (0, 0), hl.split()[3])


def s_draw_frame(sway=0.0, expr="calm"):
    img = Image.new("RGB", (SW, SH), BG)
    d = ImageDraw.Draw(img)
    s_back_hair(img, sway)
    d = ImageDraw.Draw(img)
    neckm, torm = s_draw_torso(img, d)
    facem = s_draw_face(img, neckm, torm, expr)
    s_draw_hair(img, facem, sway)
    return img


# drifting cherry petals in place of Flint's sparks
PETALS = [((6, 14), (-2, 4)), ((88, 20), (2, 4)), ((84, 62), (2, 3)), ((4, 66), (-2, 3))]
PETAL_PX = [((1, 0), H_HI), ((0, 1), H_HI), ((1, 1), H_L), ((2, 1), HR), ((1, 2), H_D)]


def add_petals(out, sway):
    px = out.load()
    step = 1 if sway >= 0 else 0
    for k, ((x, y), (dx, dy)) in enumerate(PETALS):
        X, Y = x + dx * step, y + dy * step
        flip = (k + step) % 2
        for (ax, ay), col in PETAL_PX:
            X2, Y2 = X + (ax if not flip else 2 - ax), Y + ay
            if 0 <= X2 < out.width and 0 <= Y2 < out.height and px[X2, Y2][3] == 0:
                px[X2, Y2] = col + (255,)


def s_recolor_interior(im, keep=None):
    """Near-black ink stays on the silhouette (and the lids); interior ink becomes deep rose on skin, lavender on
    the kimono, dark red on the obi, as Flint's does."""
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
            if None in ring or any(c in EYE_COLS for c in ring):
                continue
            km = sum(c in KIMS for c in ring)
            rd = sum(c in (RED, RED_L, DEEP_RED) for c in ring)
            hr = sum(c in HAIRS for c in ring)
            col = KIM_D if km >= max(rd, hr, len(ring) - km - rd - hr) and km > 0 else \
                DEEP_RED if rd > len(ring) / 3 else H_EDGE if hr > len(ring) / 3 else SK_D
            ch.append((x, y, col + (255,)))
    for x, y, c in ch:
        o[x, y] = c
    return im


def add_obi_motif(out):
    """Tiny blossoms and dashes on the obi band (on the finished pixel art)."""
    px = out.load()
    for x in (12, 36, 60, 84):
        for dx, dy, col in ((0, -1, H_L), (-1, 0, H_L), (1, 0, H_L), (0, 1, H_L), (0, 0, YELLOW)):
            if px[x + dx, 122 + dy][:3] in (RED, RED_L, DEEP_RED):
                px[x + dx, 122 + dy] = col + (255,)
    for x in (24, 48, 72):
        for dx in (-1, 0, 1):
            if px[x + dx, 122][:3] == RED:
                px[x + dx, 122] = DEEP_RED + (255,)


def make_sakura_frame(sway, expr):
    src = s_draw_frame(sway, expr)
    diff = ImageChops.difference(src, Image.new("RGB", src.size, BG)).convert("L").point(lambda v: 255 if v > 0 else 0)
    mask = diff.resize((W, H), Image.BOX).point(lambda v: 255 if v > 110 else 0)
    out = snap(pixelize(src, W, 40), mask, SAKURA_PALETTE)
    px = out.load()
    prot = {(x, y) for y in range(44, 66) for x in range(26, 72) if px[x, y] == WHITE + (255,)}
    out = cleanup(out, prot)
    out = s_recolor_interior(out, (38, 66, 60, 82) if expr == "shout" else None)
    add_obi_motif(out)
    add_petals(out, sway)
    return out


SAKURA_FRAMES = [(-1, "calm"), (1, "calm"), (0.2, "determined"), (0.5, "shout")]


def sakura_main(review=None, flint_frame=None):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    frames = [make_sakura_frame(s, e) for s, e in SAKURA_FRAMES]
    strip = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    dst = os.path.join(root, "assets", "title", "anime")
    os.makedirs(dst, exist_ok=True)
    strip.save(os.path.join(dst, "sakura_bust.png"))
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
    clean.convert("RGB").save(os.path.join(review, "sakura_bust_clean.png"))
    sheet = Image.new("RGBA", (cw * 5 + 8, H * S + 16), bg)
    if flint_frame is not None:        # Flint calm first, her four frames after it
        fb = flint_frame.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(fb, (8, 8), fb)
    for i, f in enumerate(big):
        sheet.paste(f, (8 + (i + 1) * cw, 8), f)
    sheet.convert("RGB").save(os.path.join(review, "sakura_bust_review.png"))
    x1 = Image.new("RGBA", (W * 5, H), bg)
    if flint_frame is not None:
        x1.alpha_composite(flint_frame, (0, 0))
    for i, f in enumerate(frames):
        x1.alpha_composite(f, ((i + 1) * W, 0))
    x1.convert("RGB").save(os.path.join(review, "sakura_bust_x1.png"))


def main():
    flint_main()
    review = sys.argv[1] if len(sys.argv) > 1 else None
    flint = Image.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "title", "anime",
                                    "flint_bust.png")).convert("RGBA").crop((0, 0, W, H))
    sakura_main(review, flint)


if __name__ == "__main__":
    main()
