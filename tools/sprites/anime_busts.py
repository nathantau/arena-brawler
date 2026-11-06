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


# ================================================================ Sakura (female / cute anime bust)
# Same pipeline as Flint (vector -> pixelize -> snap), own palette. Hair is not elemental, so it gets a thin
# outline in deep magenta. Colours drawn in the source as "line" colours are brightened by 1/0.6 because
# pixelize() darkens line pixels by 0.6 (see lc()).
S_INK = INK
S_SKIN_OUT = MAROON
SKIN_L = (252, 222, 198); SKIN = (240, 193, 154); SKIN_S = (222, 156, 126); SKIN_SS = (200, 128, 108)
BLUSH = (244, 148, 156); LIP = (190, 66, 88)
HAIR = (226, 110, 160); HAIR_L = (240, 150, 190); HAIR_HI = (252, 210, 228)
HAIR_D = (186, 66, 122); HAIR_DD = (148, 46, 102); HAIR_OUT = (100, 28, 78)
IRIS_D = (22, 50, 96); IRIS_M = (40, 124, 176); IRIS_B = (122, 214, 226); WHITE = (255, 252, 250)
LAV = (212, 210, 234); LAV_D = (172, 168, 210); LAV_OUT = (100, 94, 146)
RED_L = (240, 112, 108); MOUTH_D = (104, 30, 70)
SAKURA_PALETTE = [S_INK, MAROON, SKIN_L, SKIN, SKIN_S, SKIN_SS, BLUSH, LIP, HAIR, HAIR_L, HAIR_HI, HAIR_D, HAIR_DD, HAIR_OUT,
                  IRIS_D, IRIS_M, IRIS_B, MOUTH_D, WHITE, CREAM, LAV, LAV_D, LAV_OUT, RED, RED_L, DEEP_RED, YELLOW, ORANGE]
SBG = BG


def lc(c):
    """Source colour that comes out as c after pixelize's 0.6 line darkening."""
    return tuple(min(255, round(v / 0.6)) for v in c)


def mirror(pts):
    return [(48 - x, y) for x, y in pts]


def ellipse_pts(cx, cy, rx, ry, n=24, a0=0.0, a1=2 * math.pi):
    return [(cx + rx * math.cos(a0 + (a1 - a0) * i / n), cy + ry * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def ribbon(ctrl, w0, w1, n=10, taper=0.22):
    """Edges of a tapering lock along a smooth centre line. edge(f): f=+1 normal side (lit), -1 other side."""
    cs = smooth(ctrl, n)
    m = len(cs)
    nr, ws = [], []
    for i in range(m):
        a, b = cs[max(i - 1, 0)], cs[min(i + 1, m - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, ty) or 1
        nr.append((-ty / L, tx / L))
        t = i / (m - 1)
        w = w0 + (w1 - w0) * t
        if t < 0.16:
            w *= 0.55 + 0.45 * t / 0.16
        if t > 1 - taper:
            w *= max(0.0, (1 - t) / taper) ** 0.8
        ws.append(w)

    def edge(f, t0=0.0, t1=1.0):
        return [(cs[i][0] + nr[i][0] * f * ws[i] / 2, cs[i][1] + nr[i][1] * f * ws[i] / 2)
                for i in range(m) if t0 <= i / (m - 1) <= t1]
    return cs, edge



def lock(d, ctrl, w0, w1, base=HAIR, lit=True, taper=0.22, clumps=(), n=10, ow=6, streak=False, mode="both"):
    """mode 'outline' draws only the thick outline, 'fill' only the cel shapes: drawing every outline first and
    every fill after leaves a line round the whole hair mass but none between overlapping locks."""
    cs, edge = ribbon(ctrl, w0, w1, n, taper)
    poly_pts = edge(1) + edge(-1)[::-1]
    if mode == "outline":
        outline(d, poly_pts, w=ow, col=lc(HAIR_OUT))
        return cs, edge
    poly(d, poly_pts, base)
    if base == HAIR:
        a, b = edge(-0.2, 0.08), edge(-1.0, 0.08)
        poly(d, a + b[::-1], HAIR_D)
        if lit:
            a, b = edge(0.95, 0.04, 0.75), edge(0.25, 0.04, 0.75)
            poly(d, a + b[::-1], HAIR_L)
        if streak:
            a, b = edge(0.82, 0.08, 0.5), edge(0.55, 0.08, 0.5)
            poly(d, a + b[::-1], HAIR_HI)
        for (f, t0, t1) in clumps:
            pts = [P(*p) for p in edge(f, t0, t1)]
            d.line(pts, fill=HAIR_D, width=4, joint="curve")
    if ow and mode == "both":
        outline(d, poly_pts, w=ow, col=lc(HAIR_OUT))
    return cs, edge


def wob(ctrl, s, k, t0=0.3):
    """Sway: shift the lower control points sideways, more towards the tip."""
    n = len(ctrl)
    return [(x + s * k * max(0.0, i / (n - 1) - t0) / (1 - t0), y) for i, (x, y) in enumerate(ctrl)]


SFACE = [(13.6, 17), (24, 16.2), (34.4, 17), (35.4, 24), (35.0, 31), (33.2, 37), (30.0, 41.2), (26.6, 43.2), (24, 43.8),
         (21.4, 43.2), (18.0, 41.2), (14.8, 37), (13.0, 31), (12.6, 24)]
SFACE_S = smooth(SFACE + [SFACE[0]], 6)
SNECK = [(21.2, 35), (26.8, 35), (27.2, 47.5), (20.8, 47.5)]
STORSO = [(0, 64), (0, 55), (4, 50.4), (12, 47.8), (20.2, 45.9), (24, 48.0), (27.8, 45.9), (36, 47.8), (44, 50.4),
          (48, 55), (48, 64)]
BACKMASS = smooth([(24, 10.0), (17.8, 10.9), (13.0, 14.4), (10.6, 20), (9.6, 28), (9.4, 37), (9.8, 46), (10.8, 54)], 8)
BACKMASS = BACKMASS + [(24, 58)] + mirror(BACKMASS[::-1])
SCAP_TOP = smooth([(11.6, 27), (11.3, 21), (13.6, 15.4), (18.4, 12.2), (24, 11.2), (29.6, 12.2), (34.4, 15.4), (36.7, 21),
                  (36.4, 27)], 8)
NOTCHES = [30.4, 26.2, 21.8, 17.6]


def bang_y(x):
    return 23.9 + 0.8 * ((x - 24) / 10.5) ** 2


def bangs_bottom():
    pts = [(36.4, 27), (35.0, bang_y(35.0) + 0.4), (34.6, bang_y(34.6))]
    for nx in NOTCHES:
        pts += [(nx + 0.2, bang_y(nx + 0.2)), (nx, bang_y(nx) - 1.0), (nx - 0.2, bang_y(nx - 0.2))]
    pts += [(13.4, bang_y(13.4)), (12.6, bang_y(12.6) + 0.4), (11.6, 27)]
    return pts




def s_eye(img, cx, cy, side, expr):
    """Anime eye matched to the study ref: nearly as tall as wide, outer corner a little raised, iris fills most
    of it (teal: navy top -> bright bottom, contrasts with pink hair), dark upper lash with a small outer flick,
    a thin lower lash hint, one big highlight and a small second one."""
    h = {"shout": 1.12, "determined": 0.88}.get(expr, 1.0)
    hw, hh = 3.1, 3.1 * h
    N = 20
    top, bot = [], []
    for k in range(N + 1):
        t = k / N
        u = 2 * t - 1
        x = cx - side * hw + side * 2 * hw * t
        sq = math.sqrt(max(0.0, 1 - u * u))
        top.append((x, cy - hh * sq - 0.5 * t + 0.1))
        bot.append((x, cy + hh * 0.72 * sq - 0.45 * t + 0.1))
    almond = top + bot[::-1]
    am = poly_mask(almond)
    d = ImageDraw.Draw(img)
    poly(d, almond, CREAM)
    iris = both(poly_mask(ellipse_pts(cx + side * 0.1, cy + 0.2, 2.45, hh * 1.0, 24)), am)
    paste_mask(img, IRIS_B, iris)
    paste_mask(img, IRIS_M, both(iris, box_mask(0, 0, 48, cy + hh * 0.3)))
    paste_mask(img, IRIS_D, both(iris, box_mask(0, 0, 48, cy - hh * 0.28)))
    d = ImageDraw.Draw(img)
    m = len(top) - 1
    for i in range(m):
        t = i / m
        w = 8 + 7 * t ** 1.3
        d.line([P(*top[i]), P(*top[i + 1])], fill=S_INK, width=int(w))
        x, y = P(*top[i + 1])
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=S_INK)
    ox, oy = top[-1]
    f1 = (ox + side * 0.8, oy - 0.1)
    f2 = (ox + side * 1.4, oy - 0.45)
    for (a, b, w) in ((top[-1], f1, 10), (f1, f2, 6)):
        d.line([P(*a), P(*b)], fill=S_INK, width=w)
    lo = bot[int(N * 0.62):]
    d.line([P(*p) for p in lo], fill=S_INK, width=4, joint="curve")
    hx, hy = cx - 0.55, cy - hh * 0.3
    d.ellipse(((hx - 0.9) * K, (hy - 0.95) * K, (hx + 0.9) * K, (hy + 0.95) * K), fill=WHITE)
    d.ellipse(((cx + 1.0 - 0.45) * K, (cy + hh * 0.5 - 0.45) * K, (cx + 1.0 + 0.45) * K, (cy + hh * 0.5 + 0.45) * K), fill=WHITE)


def s_brow(d, cx, cy, side, expr):
    if expr == "determined":
        a, b = (cx + side * 3.6, cy - 0.4), (cx - side * 2.6, cy + 1.0)
    elif expr == "shout":
        a, b = (cx + side * 3.2, cy - 1.0), (cx - side * 2.6, cy - 0.7)
    else:
        a, b = (cx + side * 3.4, cy - 0.1), (cx - side * 2.6, cy - 0.2)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - 0.35)
    d.line([P(*p) for p in smooth([b, mid, a], 6)], fill=lc(HAIR_OUT), width=12, joint="curve")


def s_mouth(d, expr):
    if expr == "shout":
        pts = ellipse_pts(24, 39.2, 1.4, 1.6, 16)
        poly(d, pts, MOUTH_D)
        d.ellipse((23.0 * K, 39.8 * K, 25.0 * K, 40.5 * K), fill=RED_L)
        outline(d, pts, 5, col=lc(MAROON))
    elif expr == "determined":
        d.line([P(22.7, 38.9), P(25.3, 38.9)], fill=lc(MAROON), width=7)
    else:
        d.line([P(*p) for p in smooth([(22.7, 38.5), (23.4, 39.1), (24.6, 39.1), (25.3, 38.5)], 6)], fill=lc(MAROON), width=7,
               joint="curve")


def s_draw_torso(img):
    YOFF[0] = 0.0
    d = ImageDraw.Draw(img)
    shape(d, SNECK, SKIN, col=lc(S_SKIN_OUT))
    shape(d, STORSO, CREAM, col=lc(LAV_OUT))
    torm, neckm = poly_mask(STORSO), poly_mask(SNECK)
    d = ImageDraw.Draw(img)
    # shadow on the right and under the shoulders, folds in the sleeves
    paste_mask(img, LAV, both(torm, poly_mask([(33.5, 46), (36, 47.8), (44, 50.4), (48, 55), (48, 64), (37.5, 64), (35.5, 56)])))
    paste_mask(img, LAV, both(torm, poly_mask([(11, 49), (17, 48), (18.5, 62), (14, 61)])))
    paste_mask(img, LAV_D, both(torm, poly_mask([(31.5, 48), (37, 48.5), (36, 61), (32, 62)])))
    paste_mask(img, LAV_D, both(torm, poly_mask([(41, 51), (44.4, 50.6), (48, 55), (48, 64), (43, 64), (42, 56)])))
    d = ImageDraw.Draw(img)
    for a, b, col in (((5.2, 52.4), (8.2, 62.0), LAV_D), ((39.6, 52.6), (37.4, 61.6), LAV_D), ((11.5, 49.6), (13.4, 55.4), LAV), ((17.5, 54), (16.5, 61), LAV)):
        d.line([P(*a), P(*b)], fill=col, width=7)
    # lavender shadow under the hair, then folds: dark crease with a lit lip on its light side
    paste_mask(img, LAV, both(torm, poly_mask([(8, 49), (15, 48), (16, 58), (10, 57)])))
    paste_mask(img, LAV, both(torm, poly_mask([(33, 48), (40, 49), (39, 58), (32, 58)])))
    d = ImageDraw.Draw(img)
    for pts in (((3.0, 51.5), (5.0, 56), (4.0, 62)), ((22.0, 55), (20.5, 59), (21.5, 63)), ((43.5, 52), (41.5, 57), (42.5, 62)),
                ((30.0, 51), (31.4, 56), (30.4, 62))):
        d.line([P(*p) for p in pts], fill=LAV_D, width=7, joint="curve")
        d.line([P(p[0] - 0.8, p[1]) for p in pts], fill=WHITE, width=5, joint="curve")
    # chest V, collar crossing left over right (the flap from the wearer's left, our right, lies on top)
    V = [(19.8, 45.0), (28.2, 45.0), (22.6, 54.0)]
    poly(d, V, SKIN)
    poly(d, [(19.8, 45.0), (28.2, 45.0), (26.4, 46.8), (23.4, 48.4), (21.6, 46.8)], SKIN_S)
    under = [(19.4, 44.4), (22.7, 54.4)]
    d.line([P(*p) for p in under], fill=lc(DEEP_RED), width=26)
    d.line([P(*p) for p in under], fill=RED, width=17)
    top = [(29.0, 44.4), (25.6, 50.6), (21.0, 58.6)]
    d.line([P(*p) for p in top], fill=lc(DEEP_RED), width=29)
    d.line([P(*p) for p in top], fill=RED, width=20)
    d.line([P(*p) for p in [(28.0, 45.2), (24.7, 51.0)]], fill=RED_L, width=5)
    d.line([P(*p) for p in [(30.9, 45.6), (27.2, 52.6), (23.0, 59.4)]], fill=LAV, width=7)
    # red obi, only its top band fits in the crop
    YOFF[0] = 0.0
    d.rectangle((0, 59.7 * K, SW, SH), fill=DEEP_RED)
    d.rectangle((0, 60.7 * K, SW, SH), fill=RED)
    d.rectangle((0, 60.7 * K, SW, 61.3 * K), fill=RED_L)
    d.rectangle((0, 62.8 * K, SW, SH), fill=DEEP_RED)
    return neckm, torm




def s_draw_face(img, neckm, torm, expr):
    facem = poly_mask(SFACE_S)
    jaw = both(both(shift(facem, int(1 * F), int(13 * F)), neckm), inv(facem))
    paste_mask(img, SKIN_S, both(jaw, inv(torm)))
    jaw2 = both(both(shift(facem, int(1 * F), int(5 * F)), neckm), inv(facem))
    paste_mask(img, SKIN_SS, both(jaw2, inv(torm)))
    d = ImageDraw.Draw(img)
    poly(d, SFACE_S, SKIN)
    # light from the top left: lit cheek, shadow down the right side, under the chin and under the bangs
    paste_mask(img, SKIN_L, both(facem, poly_mask([(13, 24), (22, 24), (21, 29), (17, 35.5), (13.4, 33)])))
    paste_mask(img, SKIN_S, both(facem, poly_mask([(29.5, 22), (36, 22), (36, 31), (33.6, 38), (29.5, 42.6), (26, 44.4), (29.2, 38.5),
                                                  (31.4, 31)])))
    paste_mask(img, SKIN_S, both(both(facem, inv(shift(facem, 0, int(-3.0 * F)))), box_mask(0, 38, 48, 48)))
    paste_mask(img, SKIN_S, both(facem, poly_mask([(14, 21), (34, 21), (34, 24.4), (14, 24.4)])))      # under the bangs
    d = ImageDraw.Draw(img)
    for bx in (16.9, 31.1):
        d.ellipse(((bx - 2.0) * K, 34.0 * K, (bx + 2.0) * K, 35.8 * K), fill=BLUSH)
    d.rectangle((23.7 * K, 36.4 * K, 24.5 * K, 37.0 * K), fill=SKIN_S)
    s_mouth(d, expr)
    outline(d, SFACE_S[24:73], w=11, closed=False, col=lc(S_SKIN_OUT))
    cy = 30.4
    s_eye(img, 17.4, cy, -1, expr)
    s_eye(img, 30.6, cy, 1, expr)
    return facem


def s_draw_hair(img, facem, s, expr):
    d = ImageDraw.Draw(img)
    # back mass in a deep shade: shows between the locks
    shape(d, BACKMASS, HAIR_DD, col=lc(HAIR_OUT))
    return d


LOCKS_L = [
    ([(11.0, 21), (9.2, 29), (8.4, 38), (10.0, 46), (8.2, 53), (9.0, 59.5)], 4.8, 0.85),
    ([(12.4, 21), (11.0, 29), (11.4, 37), (13.2, 44), (11.4, 51), (12.6, 58)], 4.6, 0.7),
    ([(13.8, 22), (13.6, 30), (14.6, 37), (16.6, 43), (15.2, 49), (17.6, 53.5)], 3.8, 0.55),
]
STRANDS_L = [([(9.6, 40), (7.6, 45), (7.2, 50), (8.4, 53)], 1.2, 0.9), ([(11.6, 46), (10.4, 52), (11.8, 58)], 1.1, 0.7)]



LOCKS_L = [
    ([(11.6, 18.5), (9.0, 27), (7.8, 36), (9.4, 46), (7.6, 53), (8.6, 59.5)], 5.6, 0.85),
    ([(12.6, 20), (10.6, 28), (10.8, 38), (12.8, 45), (11.0, 52), (12.4, 58.5)], 5.4, 0.7),
    ([(13.4, 22), (12.6, 30), (13.8, 38), (15.8, 44), (14.4, 50), (16.8, 54.5)], 4.4, 0.55),
]
STRANDS_L = [([(9.6, 40), (7.6, 45), (7.2, 50), (8.4, 53)], 1.2, 0.9)]


def s_front_hair(img, s, expr):
    d = ImageDraw.Draw(img)
    for mode in ("outline", "fill"):
        for side in (1, -1):
            for ctrl, w, k in LOCKS_L:
                c = wob(ctrl, s, k, 0.35)
                lock(d, mirror(c) if side < 0 else c, w, w + 0.4, taper=0.34, ow=9, mode=mode)
            c = wob(STRANDS_L[0][0], s, 1.1, 0.3)
            lock(d, mirror(c) if side < 0 else c, 1.1, 1.1, base=HAIR_L, taper=0.5, ow=5, n=6, mode=mode)
    return d


BANG_CLUMPS = [(15.6, 13.8, 26.6, 4.6), (32.6, 34.0, 26.4, 4.6), (18.8, 17.4, 25.6, 4.4), (29.4, 30.4, 25.8, 4.6),
               (21.6, 20.6, 24.8, 3.8), (26.2, 27.2, 25.2, 3.8)]


def s_cap(img, s, expr):
    d = ImageDraw.Draw(img)
    cap_pts = SCAP_TOP + [(36.4, 22.5), (11.6, 22.5)]
    poly(d, cap_pts, HAIR)
    capm = poly_mask(cap_pts)
    paste_mask(img, HAIR_D, both(capm, poly_mask([(31.5, 11), (36.8, 16), (37, 28), (33, 26), (32.2, 19)])))
    paste_mask(img, HAIR_L, both(capm, poly_mask([(11, 20), (13.4, 14.6), (17, 12), (18.4, 12.6), (14.6, 16.6), (13.6, 22)])))
    d = ImageDraw.Draw(img)
    # angel ring: glossy band across the crown, brightest on the left
    ring_top = smooth([(14.0, 19.2), (17.6, 16.0), (23.6, 14.4), (30.2, 16.0), (33.6, 19.0)], 8)
    ring_bot = [(x, y + 2.2 - 1.0 * abs(x - 24) / 10) for x, y in ring_top]
    poly(d, ring_top + ring_bot[::-1], HAIR_L)
    core_t = smooth([(15.2, 18.6), (18.6, 15.8), (23.0, 14.8)], 8)
    core_b = [(x, y + 1.5) for x, y in core_t]
    poly(d, core_t + core_b[::-1], HAIR_HI)
    outline(d, SCAP_TOP[6:-6], w=6, closed=False, col=lc(HAIR_OUT))
    for mode in ("outline", "fill"):
        for (xr, xt, yt, w) in BANG_CLUMPS:
            sw = s * 0.25
            lock(d, [(xr, 18.5), ((xr + xt) / 2, (18.5 + yt) / 2), (xt + sw, yt)], w, w * 0.9, taper=0.5, ow=9, n=8, mode=mode)
    return d



def s_inner_locks(img, s, expr):
    d = ImageDraw.Draw(img)
    # locks start at the temples and fall in front of the ears, outside the face edge
    li = [(12.2, 21.0), (11.6, 28), (12.0, 35.5), (13.4, 41.5)]
    lock(d, wob(li, s, 0.6, 0.4), 3.0, 2.6, taper=0.34, ow=5)
    lock(d, wob(mirror(li), s, 0.6, 0.4), 3.0, 2.6, taper=0.34, ow=5)
    lock(d, wob([(23.4, 11.0), (22.4, 8.2), (24.0, 6.2), (26.4, 7.0)], s, 0.8, 0.3), 1.3, 1.1, base=HAIR_L, taper=0.5, ow=4, n=6)
    lock(d, wob([(27.6, 11.6), (29.4, 9.2), (31.6, 9.0)], s, 0.8, 0.3), 1.2, 1.0, base=HAIR_L, taper=0.5, ow=4, n=6)
    return d


def s_blossom(img):
    d = ImageDraw.Draw(img)
    cx, cy = 15.0, 15.6
    petal_out = lc((176, 58, 116))
    for k in range(5):
        a = math.radians(-100 + 72 * k)
        px, py = cx + 1.95 * math.cos(a), cy + 1.95 * math.sin(a)
        pts = []
        for j in range(16):
            t = 2 * math.pi * j / 16
            ex, ey = 1.85 * math.cos(t), 1.4 * math.sin(t)
            pts.append((px + ex * math.cos(a) - ey * math.sin(a), py + ex * math.sin(a) + ey * math.cos(a)))
        poly(d, pts, HAIR_HI)
        outline(d, pts, w=4, col=petal_out)
    d.ellipse(((cx - 1.05) * K, (cy - 1.05) * K, (cx + 1.05) * K, (cy + 1.05) * K), fill=YELLOW)
    d.ellipse(((cx - 0.4) * K, (cy - 0.4) * K, (cx + 0.2) * K, (cy + 0.2) * K), fill=ORANGE)


def s_draw_frame(sway, expr):
    img = Image.new("RGB", (SW, SH), SBG)
    d = ImageDraw.Draw(img)
    s_draw_hair(img, None, sway, expr)
    neckm, torm = s_draw_torso(img)
    facem = s_draw_face(img, neckm, torm, expr)
    s_front_hair(img, sway, expr)
    s_cap(img, sway, expr)
    s_inner_locks(img, sway, expr)
    s_blossom(img)
    d = ImageDraw.Draw(img)
    if expr != 'calm':
        s_brow(d, 17.4, 25.4, -1, expr)
        s_brow(d, 30.6, 25.4, 1, expr)
    return img


# drifting cherry petals (placed on the finished pixel art): (x, y, per-step drift)
PETALS = [((5, 14), (-3, 5)), ((88, 22), (3, 4)), ((84, 70), (3, 4))]
PETAL_PX = [((1, 0), HAIR_HI), ((2, 0), HAIR_L), ((0, 1), HAIR_HI), ((1, 1), HAIR_L), ((2, 1), HAIR), ((1, 2), HAIR_D)]


def add_petals(out, sway):
    px = out.load()
    for k, ((x, y), (dx, dy)) in enumerate(PETALS):
        step = 0 if sway < 0 else 1
        X, Y = x + dx * step * (1 if sway >= 0 else 0), y + dy * step
        flip = (k + step) % 2
        for (ax, ay), col in PETAL_PX:
            X2, Y2 = X + (ax if not flip else 2 - ax), Y + ay
            if 0 <= X2 < out.width and 0 <= Y2 < out.height and px[X2, Y2][3] == 0:
                px[X2, Y2] = col + (255,)


def add_obi_motif(out):
    """Tiny blossoms and dashes on the obi band (placed on the finished pixel art)."""
    px = out.load()
    for x in (12, 36, 60, 84):
        for dx, dy, col in ((0, -1, HAIR_L), (-1, 0, HAIR_L), (1, 0, HAIR_L), (0, 1, HAIR_L), (0, 0, YELLOW)):
            if px[x + dx, 123 + dy][:3] in (RED, RED_L, DEEP_RED):
                px[x + dx, 123 + dy] = col + (255,)
    for x in (24, 48, 72):
        for dx in (-1, 0, 1):
            if px[x + dx, 123][:3] == RED:
                px[x + dx, 123] = DEEP_RED + (255,)


def make_sakura_frame(sway, expr):
    src = s_draw_frame(sway, expr)
    diff = ImageChops.difference(src, Image.new("RGB", src.size, SBG)).convert("L").point(lambda v: 255 if v > 0 else 0)
    mask = diff.resize((W, H), Image.BOX).point(lambda v: 255 if v > 110 else 0)
    out = snap(pixelize(src, W, 40), mask, SAKURA_PALETTE)
    out = cleanup(out)
    add_petals(out, sway)
    add_obi_motif(out)
    return out


SAKURA_FRAMES = [(-1, "calm"), (1, "calm"), (0.0, "determined"), (0.4, "shout")]


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
    sheet = Image.new("RGBA", (cw * 6 + 8, H * S + 16), bg)
    sheet.paste(clean, (0, 0))
    if flint_frame is not None:
        fb = flint_frame.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(fb, (8 + 4 * cw, 8), fb)
    ref_path = os.path.join(review, "ref96.png")      # study only (pixelized female ref), never committed
    if os.path.exists(ref_path):
        ref = Image.open(ref_path).convert("RGBA")
        sc = 0.85
        ref = ref.resize((round(ref.width * sc), round(ref.height * sc)), Image.NEAREST)
        lay = Image.new("RGBA", (W, H), (255, 255, 255, 255))
        lay.alpha_composite(ref, (7, 61 - round(70.5 * sc)))
        mine = Image.new("RGBA", (W, H), (255, 255, 255, 255))
        mine.alpha_composite(frames[0])
        ov = Image.blend(lay, mine, 0.5).resize((W * S, H * S), Image.NEAREST)
        sheet.paste(ov, (8 + 5 * cw, 8))
    sheet.convert("RGB").save(os.path.join(review, "sakura_bust_review.png"))
    x1 = Image.new("RGBA", strip.size, bg)
    x1.alpha_composite(strip)
    x1.convert("RGB").save(os.path.join(review, "sakura_bust_x1.png"))


def main():
    flint_main()
    review = sys.argv[1] if len(sys.argv) > 1 else None
    flint = Image.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "title", "anime",
                                    "flint_bust.png")).convert("RGBA").crop((0, 0, W, H))
    sakura_main(review, flint)


if __name__ == "__main__":
    main()
