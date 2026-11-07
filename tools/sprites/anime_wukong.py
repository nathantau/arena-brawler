"""Apex (id `wukong`, monkey-king fighter) anime bust for the title screen, original art.

Built from Flint's own code in anime_busts.py (never forked): tongue() hair / feathers, snap, cleanup, pixelize, Flint's
eye, mouth and the FACE / EAR proportions; only the palette, torso (white fur mantle over gold armour), headband, plumes,
hair styles and shading are his own. All globals are prefixed WK / w_ so nothing Flint or Sakura uses is touched.
Output: assets/title/anime/wukong_bust.png, 4 frames of 96 x 128 (calm A, calm B, determined, shout).

Run: tools/sprites/.venv/bin/python tools/sprites/anime_wukong.py [review_dir]
(review_dir gets wukong_variants.png + key, wukong_bust_review.png, wukong_bust_x1.png; never commit those.)
"""
import math
import os
import sys
from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anime_busts as ab
from anime_busts import (INK, MAROON, YELLOW, CREAM, ORANGE, LIGHT_OR, RED, DEEP_RED, SK, SK_L, SK_S, SK_D, RED_L, WHITE,
                         BG, K, F, SW, SH, W, H, P, poly, outline, shape, rect, smooth, poly_mask, box_mask, mask_of, shift,
                         both, inv, paste_mask, snap, cleanup, pixelize, lc, mir, mirror_pts, ellipse_pts, tongue)

# ---- palette: his gameplay colours (skin, brown hair, cream fur with steel shade, gold armour, red) + ramps
WH = (110, 70, 48); WH_L = (150, 98, 66); WH_HI = (192, 134, 92); WH_D = (80, 48, 40); WH_E = (56, 32, 34)
FUR_S = (206, 212, 228); FUR_D = (154, 167, 194)
GOLD_D = (196, 102, 52)
WK_PAL = [INK, MAROON, SK, SK_L, SK_S, SK_D, CREAM, WHITE, WH, WH_L, WH_HI, WH_D, WH_E, FUR_S, FUR_D, YELLOW, LIGHT_OR,
          ORANGE, GOLD_D, RED, DEEP_RED, RED_L]
WK_SKIN = {SK, SK_L, SK_S, SK_D}
WK_FUR = {CREAM, WHITE, FUR_S, FUR_D}
WK_GOLD = {YELLOW, LIGHT_OR, ORANGE, GOLD_D}
WK_RED = {RED, DEEP_RED, RED_L}
WK_HAIR = {WH, WH_L, WH_HI, WH_D, WH_E}
WK_OFF = 2.0                 # neck / torso offset (a short thick neck)

WK_BASE = dict(hair="spiky", feather="back", band="wide", eyes="flint", mouth="smirk", staff=False, mane=False)
WCFG = dict(WK_BASE)


def w_hair_col(t):
    if t < 0.1:
        return WH_L
    if t < 0.58:
        return WH
    return WH_D


W_HAIR_COLS = (lc(WH_E), w_hair_col, WH_D, WH_HI)


def w_hair(d, root, tip, w0, bend, sway=0.0, shade_side=-1, ph=0.0, wave=0.16, n=24, ow=6, bands=None):
    return tongue(d, root, tip, w0, bend, sway=sway, shade_side=shade_side, ph=ph, wave=wave, n=n, ow=ow,
                  cols=W_HAIR_COLS, bands=bands)


def w_feather_col(t):
    if t < 0.2:
        return ORANGE
    if t < 0.7:
        return RED
    return DEEP_RED


def w_feather(d, root, tip, w0, bend, sway=0.0, ph=0.0):
    """A pheasant plume: slim leaf outline with barb notches, red body, lit orange side, pale spine, deep-red edge."""
    n = 30
    cs, nr = ab.centreline(root, tip, bend, sway, n)
    L, R = [], []
    for i in range(n + 1):
        t = i / n
        hw = w0 / 2 * math.sin(math.pi * min(t * 0.92 + 0.06, 1)) ** 0.8 * (1 - 0.35 * t)
        notch = 0.72 if (i % 3 == 2 and 0.2 < t < 0.95) else 1.0
        L.append((cs[i][0] - nr[i][0] * hw * notch, cs[i][1] - nr[i][1] * hw * notch))
        R.append((cs[i][0] + nr[i][0] * hw * (0.72 if (i % 3 == 0 and 0.2 < t < 0.95) else 1.0),
                  cs[i][1] + nr[i][1] * hw * (0.72 if (i % 3 == 0 and 0.2 < t < 0.95) else 1.0)))
    pts = L + R[::-1]
    outline(d, pts, w=5, col=lc(DEEP_RED))
    poly(d, pts, RED)
    mid = [cs[i] for i in range(n + 1)]
    lit = [((L[i][0] + cs[i][0]) / 2, (L[i][1] + cs[i][1]) / 2) for i in range(1, n - 1)]
    d.line([P(*p) for p in lit], fill=ORANGE, width=9, joint="curve")
    sh = [((R[i][0] + cs[i][0]) / 2, (R[i][1] + cs[i][1]) / 2) for i in range(2, n - 2)]
    d.line([P(*p) for p in sh], fill=DEEP_RED, width=6, joint="curve")
    d.line([P(*p) for p in mid[1:n - 2]], fill=RED_L, width=4, joint="curve")


# ---------------------------------------------------------------- torso: gold armour + white fur mantle
W_NECK = [(20.4, 35), (27.6, 35), (28.2, 46), (19.8, 46)]
W_TORSO = [(0, 64), (0, 54), (3.5, 49.2), (9, 46.4), (15, 44.8), (20, 43.8), (24, 50), (28, 43.8), (33, 44.8), (39, 46.4),
           (44.5, 49.2), (48, 54), (48, 64)]
# fur lobes (cx, cy, rx, ry) for the left shoulder, mirrored on the right
W_LOBES = [(4.6, 57.5, 8.0, 9.4), (11.4, 51.6, 7.0, 6.4), (16.8, 47.6, 5.0, 4.2), (7.8, 62.0, 7.0, 6.0),
           (1.4, 52.6, 3.6, 3.4), (7.4, 47.6, 4.0, 3.4), (13.0, 45.2, 3.8, 3.0)]


def w_mantle_mask():
    def f(m):
        for cx, cy, rx, ry in W_LOBES:
            for x in (cx, 48 - cx):
                m.polygon([P(*p) for p in ellipse_pts(x, cy, rx, ry, 30)], fill=255)
    return mask_of(f)


def w_draw_torso(img, d):
    ab.YOFF[0] = WK_OFF
    shape(d, W_NECK, SK)
    shape(d, W_TORSO, ORANGE)
    neckm, torm = poly_mask(W_NECK), poly_mask(W_TORSO)
    # gold chest plate: lit left, deeper right, a red inlay with a gold boss
    poly(d, [(26, 46), (34, 47), (47.6, 54), (47.6, 64), (30, 64), (28, 52)], GOLD_D)
    paste_mask(img, YELLOW, both(both(torm, inv(shift(torm, 0, int(8 * F)))), box_mask(0, 0, 24, 80)))
    d = ImageDraw.Draw(img)
    for y in (53.6, 59.4):                       # horizontal plate lines
        d.line([P(14, y), P(34, y)], fill=lc(GOLD_D), width=5)
        d.line([P(14, y + 0.8), P(34, y + 0.8)], fill=LIGHT_OR, width=4)
    d.line([P(24, 49.5), P(24, 64.5)], fill=DEEP_RED, width=26)
    d.line([P(24, 49.5), P(24, 64.5)], fill=RED, width=16)
    d.line([P(23.2, 50.5), P(23.2, 64.5)], fill=RED_L, width=4)
    poly(d, [(24, 54.2), (26.6, 57.2), (24, 60.2), (21.4, 57.2)], YELLOW)
    outline(d, [(24, 54.2), (26.6, 57.2), (24, 60.2), (21.4, 57.2)], 4, col=lc(GOLD_D))
    d.rectangle((23.4 * K, (56.6 + ab.YOFF[0]) * K, 24.6 * K, (57.8 + ab.YOFF[0]) * K), fill=RED)
    # neckline: skin chest in a V, gold rim
    d = ImageDraw.Draw(img)
    neckline = smooth([(16.6, 44.0), (20.4, 47.6), (24, 48.8), (27.6, 47.6), (31.4, 44.0)], 8)
    poly(d, neckline + [(31.4, 40), (16.6, 40)], SK)
    poly(d, neckline + [(31.0, 40), (24, 46.4)], SK_S)
    d.line([P(*p) for p in neckline], fill=lc(GOLD_D), width=14, joint="curve")
    d.line([P(x, y + 0.1) for x, y in neckline], fill=YELLOW, width=8, joint="curve")
    d.line([P(x - 0.2, y - 0.1) for x, y in neckline[: len(neckline) // 2]], fill=CREAM, width=3, joint="curve")
    # fur mantle over both shoulders: one outline round the whole mass, none between lobes
    mm = w_mantle_mask()
    img_outline = mask_of(lambda m: [m.polygon([P(*p) for p in ellipse_pts(x, cy, rx + 0.45, ry + 0.45, 30)], fill=255)
                                     for cx, cy, rx, ry in W_LOBES for x in (cx, 48 - cx)])
    paste_mask(img, INK, img_outline)
    paste_mask(img, CREAM, mm)
    paste_mask(img, FUR_S, both(mm, inv(shift(mm, int(-2.0 * K), int(-1.7 * K)))))
    paste_mask(img, FUR_D, both(both(mm, inv(shift(mm, int(-2.6 * K), int(-2.2 * K)))), box_mask(24, 0, 48, 90)))
    paste_mask(img, WHITE, both(both(mm, inv(shift(mm, int(1.2 * K), int(1.2 * K)))), box_mask(0, 0, 24, 90)))
    paste_mask(img, LIGHT_OR, both(both(mm, inv(shift(mm, int(-0.9 * K), 0))), box_mask(34, 0, 48, 90)))   # warm rim, right
    d = ImageDraw.Draw(img)
    # tuft creases (steel) and a few lit lips
    for (a, b, c) in [((4.0, 55.0), (5.4, 58.0), (3.4, 62.0)), ((10.4, 49.6), (11.4, 53.0), (9.8, 57.0)),
                      ((15.8, 46.8), (16.6, 49.6), (15.4, 52.4)), ((8.6, 60.0), (9.2, 62.6), (8.2, 64.5))]:
        d.line([P(*a), P(*b), P(*c)], fill=(190, 200, 232), width=8, joint="curve")
        d.line([P(a[0] - 0.8, a[1] + 0.2), P(b[0] - 0.8, b[1])], fill=WHITE, width=3)
        d.line([P(48 - a[0], a[1]), P(48 - b[0], b[1]), P(48 - c[0], c[1])], fill=(190, 200, 232), width=8, joint="curve")
    ab.YOFF[0] = 0.0
    return neckm, torm


# ---------------------------------------------------------------- face
W_EAR_L = [(14.4, 24.6), (12.0, 23.6), (10.0, 24.8), (9.0, 27.4), (9.6, 30.2), (11.4, 32.2), (14.4, 32.6)]
W_EAR_R = mirror_pts(W_EAR_L)


def w_eye_iris(img, d, cx, cy, side, o, wide=1.0):
    """Round-ish cheeky eye: cream white, a tall gold iris tucked under a straight heavy ink lid, dark pupil."""
    ow = 3.4 * wide
    outer = (cx + side * ow, cy - 2.2)
    inner = (cx - side * ow, cy - 0.9)
    up = [(outer[0] + (inner[0] - outer[0]) * k / 6, outer[1] + (inner[1] - outer[1]) * k / 6) for k in range(7)]
    lo = smooth([inner, (cx - side * 1.6, cy + 0.9 + 0.55 * o), (cx + side * 0.6, cy + 1.2 + 0.65 * o), outer], 6)
    pts = up + lo
    am = poly_mask(pts)
    d.polygon([P(*p) for p in pts], fill=CREAM)
    ic = cx + side * 0.3
    iris = both(poly_mask(ellipse_pts(ic, cy + 0.35, 2.15, 2.6, 28)), am)
    paste_mask(img, YELLOW, iris)
    paste_mask(img, ORANGE, both(iris, box_mask(0, 0, 48, cy + 0.1)))
    paste_mask(img, LIGHT_OR, both(iris, box_mask(0, cy + 1.7, 48, 80)))
    d = ImageDraw.Draw(img)
    d.rectangle(((ic - 0.5) * K, (cy - 0.3) * K, (ic + 0.5) * K, (cy + 1.4) * K), fill=WH_E)
    d.rectangle(((ic - side * 0.2 - 0.7) * K, (cy - 1.1) * K, (ic - side * 0.2 + 0.1) * K, (cy - 0.4) * K), fill=WHITE)
    d.line([P(*p) for p in lo[len(lo) // 2:]], fill=SK_D, width=5)
    d.line([P(*p) for p in up], fill=INK, width=11)
    d.line([P(*outer), P(outer[0] + side * 1.2, outer[1] - 0.9)], fill=INK, width=8)
    return d


def w_eye(img, d, cx, cy, side, o, wide):
    if WCFG["eyes"] == "flint":
        ab.eye(d, cx, cy, side, o, wide)
        return d
    return w_eye_iris(img, d, cx, cy, side, o, wide)


def w_brow(d, cx, cy, side, lift=0.0, tilt=1.0):
    heavy = WCFG["eyes"] == "flint"
    outer = (cx + side * 4.4, cy - 3.9 - lift - 0.5 * (tilt - 1))
    inner = (cx - side * 2.6, cy - 2.4 - lift + 0.5 * (tilt - 1))
    d.line([P(*outer), P(*inner)], fill=lc(WH_D), width=12 if heavy else 10)


def w_mouth(d, expr):
    if expr == "shout":
        ab.mouth(d, "shout")
        return
    ab.YOFF[0] = -2.7
    kind = WCFG["mouth"]
    if expr == "determined":
        d.line([P(*p) for p in smooth([(21.8, 39.5), (23.6, 39.8), (25.4, 39.4), (26.8, 38.5)], 6)], fill=lc(MAROON), width=8, joint="curve")
    elif kind == "grin":
        d.line([P(*p) for p in smooth([(21.6, 39.2), (23.4, 39.9), (25.4, 39.6), (27.0, 38.4)], 6)], fill=lc(MAROON), width=8, joint="curve")
        rect(d, 25.0, 39.3 + 2.7, 26.0, 40.3 + 2.7, CREAM)
    elif kind == "smirk":
        d.line([P(*p) for p in smooth([(21.8, 39.5), (23.4, 39.8), (25.2, 39.5), (26.6, 38.6)], 6)], fill=lc(MAROON), width=8, joint="curve")
        d.line([P(26.7, 38.9), P(27.2, 38.1)], fill=lc(MAROON), width=6)
    else:
        d.line([P(22.2, 39.0), P(26.6, 39.1)], fill=lc(MAROON), width=8)
    ab.YOFF[0] = 0.0


def w_draw_face(img, neckm, torm, expr):
    facem = poly_mask(ab.FACE)
    jaw = both(both(shift(facem, int(4 * F), int(20 * F)), neckm), inv(facem))
    paste_mask(img, SK_S, both(jaw, inv(torm)))
    jaw2 = both(both(shift(facem, int(4 * F), int(8 * F)), neckm), inv(facem))
    paste_mask(img, SK_D, both(jaw2, inv(torm)))
    d = ImageDraw.Draw(img)
    # big round monkey ears at eye height, lit left, shadowed right, deep inner fold
    shape(d, W_EAR_L, SK)
    shape(d, W_EAR_R, SK_S)
    d.line([P(10.2, 25.8), P(9.8, 28.0), P(10.3, 30.0)], fill=SK_L, width=4, joint="curve")
    d.line([P(48 - 10.2, 25.8), P(48 - 9.8, 28.0), P(48 - 10.3, 30.0)], fill=SK_D, width=4, joint="curve")
    d.line([P(13.0, 26.2), P(11.6, 27.6), P(11.7, 30.0), P(13.2, 31.2)], fill=MAROON, width=6, joint="curve")
    d.line([P(48 - 13.0, 26.2), P(48 - 11.6, 27.6), P(48 - 11.7, 30.0), P(48 - 13.2, 31.2)], fill=MAROON, width=6, joint="curve")
    shape(d, ab.FACE, SK)
    paste_mask(img, SK_L, both(facem, poly_mask([(15.0, 29.0), (21.0, 30.0), (20.2, 34.0), (17.6, 34.2), (15.4, 32.5)])))
    paste_mask(img, SK_L, both(facem, poly_mask([(15.4, 22.5), (21, 22.5), (20.5, 24.5), (15.2, 25)])))
    paste_mask(img, SK_S, both(facem, inv(shift(facem, int(-22 * F), 0))))
    paste_mask(img, SK_S, both(facem, poly_mask([(26.0, 34.0), (35.4, 30.5), (34.4, 35.5), (28.0, 41.4), (24.5, 41)])))
    chin = both(facem, inv(shift(facem, 0, int(-14 * F))))
    paste_mask(img, SK_S, both(chin, shift(facem, int(-30 * F), 0)))
    paste_mask(img, SK_D, both(both(facem, inv(shift(facem, int(-9 * F), 0))), box_mask(0, 25, 48, 40)))
    paste_mask(img, SK_L, both(both(facem, inv(shift(facem, int(-4 * F), 0))), box_mask(0, 26, 48, 36)))
    d = ImageDraw.Draw(img)
    d.ellipse((14.8 * K, 32.0 * K, 17.6 * K, 33.4 * K), fill=LIGHT_OR)       # one warm cheek patch on the lit side
    d.line([P(24.0, 25.4), P(24.0, 30.0)], fill=SK_L, width=7)
    d.line([P(25.0, 31.4), P(25.5, 33.0)], fill=SK_D, width=7)
    w_mouth(d, expr)
    outline(d, ab.FACE[1:] + ab.FACE[:1], w=9, closed=False)
    if expr == "shout":
        o, wd, lift, tilt = 2.2, 1.15, 0.6, 1.0
    elif expr == "determined":
        o, wd, lift, tilt = 0.4, 1.05, -0.2, 1.9
    else:
        o, wd, lift, tilt = 1.6, 1.1, 0.0, 1.0
    cy = 27.8
    w_eye(img, d, 19.2, cy, -1, o, wd)
    d = ImageDraw.Draw(img)
    w_eye(img, d, 28.8, cy, 1, o, wd)
    d = ImageDraw.Draw(img)
    w_BROW[0] = (lift, tilt)
    return facem


w_BROW = [(0.0, 1.0)]


# ---------------------------------------------------------------- hair, headband, plumes, staff
W_CAP_TOP = [(12.0, 23), (12.2, 17), (15.6, 13.6), (24, 12.0), (32.4, 13.6), (35.8, 17), (36.0, 23)]
W_BAND_T = [(11.8, 19.8), (18, 18.4), (24, 18.0), (30, 18.4), (36.2, 19.8)]
W_BAND_B = [(12.2, 23.4), (18, 22.2), (24, 21.9), (30, 22.2), (35.8, 23.4)]

# (root, tip, width, bend) per hair style, drawn back to front; swept back to the left and up
W_SPIKES = {
    "spiky": [((33.5, 16.0), (41.0, 8.4), 7.0, -2.6), ((30.0, 14.5), (34.0, 5.0), 7.5, -2.2), ((26.0, 13.5), (25.0, 3.0), 8.0, 0.8),
              ((21.5, 14.0), (14.0, 4.0), 8.0, 2.6), ((16.5, 16.0), (6.0, 8.0), 8.0, 3.0)],
    "shaggy": [((33.5, 16.5), (39.5, 10.0), 8.0, -2.0), ((29.0, 14.5), (32.0, 6.4), 8.4, -1.6), ((24.0, 13.5), (23.0, 5.4), 8.4, 0.8),
               ((19.0, 14.5), (13.0, 6.4), 8.4, 2.0), ((15.2, 17.0), (7.6, 12.0), 8.0, 2.2)],
    "ears": [((32.0, 16.0), (39.0, 5.2), 8.0, -1.2), ((16.0, 16.0), (9.0, 5.2), 8.0, 1.2), ((24, 14.0), (24.4, 7.4), 7.0, 0.5)],
    "topknot": [],
}


def w_back_hair(img, s):
    """Long hair behind the shoulders (mane option)."""
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    left = smooth([(24, 10.5), (16.5, 11.5), (11.0, 16), (7.0, 24), (4.8, 33), (4.0, 42), (4.6, 50), (6.4, 57)], 8)
    right = mirror_pts(left[::-1])
    pts = left + right
    poly(hd, pts, WH_D)
    poly(hd, [p for p in right if p[1] > 12] + [(48 - 15.0, 58), (48 - 15.0, 14)], WH_E)
    outline(hd, pts, w=6, closed=False, col=lc(WH_E))
    img.paste(hl, (0, 0), hl.split()[3])


def w_staff(img, s):
    """Gold-banded red staff leaning behind his right shoulder."""
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    pts = [(40.0, 5.0), (43.4, 5.6), (47.6, 62), (44.0, 62.4)]
    poly(hd, pts, RED)
    outline(hd, pts, w=7, col=INK)
    poly(hd, pts, RED)
    hd.line([P(40.9, 6), P(44.9, 62)], fill=RED_L, width=6)
    hd.line([P(42.9, 6.2), P(46.9, 62)], fill=DEEP_RED, width=6)
    for t0 in (0.0, 0.22, 0.46, 0.0):
        cx0 = 40.0 + 4.0 * t0 * 1.0; y0 = 5.0 + 57 * t0
        band = [(cx0 - 0.4, y0), (cx0 + 3.8, y0 + 0.4), (cx0 + 3.9, y0 + 3.0), (cx0 - 0.2, y0 + 2.6)]
        if t0 == 0.0 and band[0][1] != 5.0:
            continue
        poly(hd, band, YELLOW)
        outline(hd, band, 4, col=lc(GOLD_D))
        hd.line([P(cx0, y0 + 0.7), P(cx0 + 3.4, y0 + 0.9)], fill=CREAM, width=4)
    img.paste(hl, (0, 0), hl.split()[3])


def w_plumes(hd, s):
    f = WCFG["feather"]
    if f == "back":        # two long plumes swept back over his left, like the gameplay sprite
        w_feather(hd, (18.0, 18.0), (0.8, 7.0), 4.4, 2.8, sway=s * 1.4, ph=0.2 + s * 0.3)
        w_feather(hd, (20.4, 17.4), (5.0, 1.0), 4.4, 3.2, sway=s * 1.8, ph=0.7 + s * 0.3)
    elif f == "up":        # a pair standing up in a V from the band's centre
        w_feather(hd, (22.0, 18.0), (15.0, 0.6), 4.4, 2.0, sway=s * 1.4, ph=0.3 + s * 0.3)
        w_feather(hd, (26.0, 18.0), (35.0, 0.6), 4.4, -2.0, sway=s * 1.2, ph=0.9 + s * 0.3)
    elif f == "single":    # one tall curling plume from the left of the band
        w_feather(hd, (19.0, 18.2), (13.0, 0.0), 5.0, -3.6, sway=s * 1.6, ph=0.4 + s * 0.3)


def w_draw_hair(img, facem, s):
    st = WCFG["hair"]
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    cap_pts = W_CAP_TOP + W_BAND_B[::-1]
    poly(hd, cap_pts, WH)
    outline(hd, W_CAP_TOP[1:-1], w=6, closed=False, col=lc(WH_E))
    cap = poly_mask(cap_pts)
    hl.paste(WH_D + (255,), (0, 0), both(cap, poly_mask([(31.2, 11), (37, 16), (37, 24), (33.4, 22), (32.0, 14)])))
    hl.paste(WH_L + (255,), (0, 0), both(cap, poly_mask([(13, 14), (22, 11.6), (21, 15.4), (14, 18.6)])))
    if st == "topknot":
        # slicked hair with a crown gloss, a round topknot with a gold ring
        ring_t = smooth([(14.4, 18), (18, 15), (24, 13.6), (30, 15), (33.4, 18)], 8)
        poly(hd, ring_t + [(x, y + 1.7) for x, y in ring_t][::-1], WH_L)
        core = smooth([(15.6, 17.2), (19, 14.9), (23.4, 13.9)], 8)
        poly(hd, core + [(x, y + 0.9) for x, y in core][::-1], WH_HI)
        ab.bun_args = None
        box = (int((24 - 5.0) * K), int((3.4 - 0.5) * K), int((24 + 5.0) * K), int((12.6) * K))
        hd.ellipse(box, fill=WH, outline=lc(WH_E), width=6)
        m = mask_of(lambda mm: mm.ellipse(box, fill=255))
        hl.paste(WH_D + (255,), (0, 0), both(m, inv(shift(m, int(-2.4 * K), int(-2.4 * K)))))
        hl.paste(WH_L + (255,), (0, 0), both(m, inv(shift(m, int(2.2 * K), int(2.2 * K)))))
        hd.ellipse(((24 - 2.6) * K, 4.6 * K, (24 - 0.4) * K, 6.4 * K), fill=WH_HI)
        poly(hd, [(20.4, 11.2), (27.6, 11.2), (28.0, 12.8), (20.0, 12.8)], YELLOW)
        outline(hd, [(20.4, 11.2), (27.6, 11.2), (28.0, 12.8), (20.0, 12.8)], 4, col=lc(GOLD_D))
        hd.line([P(20.8, 11.7), P(27.0, 11.7)], fill=CREAM, width=3)
    else:
        for i, (r, t, w, b) in enumerate(W_SPIKES[st]):
            sw = s * (2.0 + 0.3 * (i % 2)) * (-1 if i < 2 else 1)
            w_hair(hd, r, t, w, b, sway=sw, ph=i * 0.37 + s * 0.4, shade_side=-1)
    # plumes behind / out of the band
    w_plumes(hd, s)
    img.paste(hl, (0, 0), hl.split()[3])
    shd = both(both(shift(cap, 0, int(15 * F)), facem), inv(cap))
    img.paste(SK_S, (0, 0), shd)
    shd2 = both(both(shift(cap, 0, int(5 * F)), facem), inv(cap))
    img.paste(SK_D, (0, 0), shd2)
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    # headband
    band_pts = W_BAND_T + W_BAND_B[::-1]
    if WCFG["band"] == "wide":
        poly(hd, band_pts, YELLOW)
        outline(hd, band_pts, w=5, col=lc(GOLD_D))
        poly(hd, band_pts, YELLOW)
        bm = poly_mask(band_pts)
        hl.paste(ORANGE + (255,), (0, 0), both(both(bm, inv(shift(bm, 0, int(-1.2 * K)))), box_mask(0, 0, 48, 90)))
        hl.paste(GOLD_D + (255,), (0, 0), both(bm, poly_mask([(33.6, 17), (37, 17), (37, 25), (33.0, 25)])))
        hl.paste(LIGHT_OR + (255,), (0, 0), both(both(bm, inv(shift(bm, 0, int(0.9 * K)))), box_mask(0, 0, 24, 90)))
        hd.line([P(13.6, 19.9), P(18.4, 18.9), P(22, 18.6)], fill=CREAM, width=4, joint="curve")
        gem = [(24, 18.6), (26.0, 20.5), (24, 22.4), (22.0, 20.5)]
        poly(hd, gem, RED)
        outline(hd, gem, 4, col=lc(GOLD_D))
        hd.rectangle((23.0 * K, 19.6 * K, 23.9 * K, 20.5 * K), fill=RED_L)
    else:                   # thin circlet
        ct = smooth([(12.0, 21.6), (18, 20.2), (24, 19.8), (30, 20.2), (36.0, 21.6)], 8)
        cb = [(x, y + 1.6) for x, y in ct]
        poly(hd, ct + cb[::-1], YELLOW)
        outline(hd, ct + cb[::-1], w=4, col=lc(GOLD_D))
        poly(hd, ct + cb[::-1], YELLOW)
        hd.line([P(*p) for p in ct[: len(ct) // 2]], fill=CREAM, width=3, joint="curve")
        gem = [(24, 18.2), (25.3, 20.3), (24, 22.3), (22.7, 20.3)]
        poly(hd, gem, RED)
        outline(hd, gem, 4, col=lc(GOLD_D))
        hd.rectangle((23.2 * K, 19.4 * K, 23.8 * K, 20.0 * K), fill=RED_L)
    # side tufts in front of the ears: short brown sideburns, or a shaggy cheek mane
    long_tufts = st == "shaggy" or WCFG["mane"]
    tip_y = 35.0 if long_tufts else 27.6
    for side, (r, t) in ((-1, ((14.0, 22.5), (12.8, tip_y))), (1, ((34.0, 22.5), (35.2, tip_y)))):
        w_hair(hd, r, t, 4.8 if long_tufts else 3.4, 1.2 * side, sway=s * 0.6 * -side, shade_side=-side, ph=0.5 + s * 0.2 * side,
               wave=0.2, n=18, ow=5)
    img.paste(hl, (0, 0), hl.split()[3])


def w_draw_frame(sway=0.0, expr="calm"):
    img = Image.new("RGB", (SW, SH), BG)
    d = ImageDraw.Draw(img)
    if WCFG["staff"]:
        w_staff(img, sway)
    if WCFG["mane"]:
        w_back_hair(img, sway)
    d = ImageDraw.Draw(img)
    neckm, torm = w_draw_torso(img, d)
    facem = w_draw_face(img, neckm, torm, expr)
    w_draw_hair(img, facem, sway)
    d = ImageDraw.Draw(img)
    lift, tilt = w_BROW[0]
    w_brow(d, 19.2, 28.0, -1, lift, tilt)
    w_brow(d, 28.8, 28.0, 1, lift, tilt)
    return img


# glints: a few tiny gold / white sparkles in place of Flint's embers
W_GLINTS = [((6, 60), (-1, 3)), ((88, 10), (1, 3)), ((84, 70), (-1, 2)), ((8, 16), (-1, 2))]


def w_add_glints(out, sway):
    px = out.load()
    step = 1 if sway >= 0 else 0
    for k, ((x, y), (dx, dy)) in enumerate(W_GLINTS):
        X, Y = x + dx * step, y + dy * step
        col = (YELLOW, CREAM)[(k + step) % 2]
        for ox, oy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)) if col == YELLOW and k % 2 == 0 else ((0, 0),):
            if 0 <= X + ox < out.width and 0 <= Y + oy < out.height and px[X + ox, Y + oy][3] == 0:
                px[X + ox, Y + oy] = col + (255,) if (ox, oy) == (0, 0) else LIGHT_OR + (255,)


def w_recolor_interior(im, keeps):
    """Ink stays on the outer silhouette and the eye lids; interior ink becomes the area's dark tone."""
    o = im.load()
    w, h = im.size

    def get(x, y):
        return o[x, y] if 0 <= x < w and 0 <= y < h else (0, 0, 0, 0)
    ch = []
    for y in range(h):
        for x in range(w):
            if o[x, y][:3] != INK or o[x, y][3] == 0 or any(k[0] <= x <= k[2] and k[1] <= y <= k[3] for k in keeps):
                continue
            ring = [get(x + dx, y + dy)[:3] if get(x + dx, y + dy)[3] else None for dx in range(-2, 3) for dy in range(-2, 3)]
            if None in ring:
                continue
            cnt = {"skin": sum(c in WK_SKIN or c == MAROON for c in ring), "fur": sum(c in WK_FUR for c in ring),
                   "gold": sum(c in WK_GOLD for c in ring), "red": sum(c in WK_RED for c in ring),
                   "hair": sum(c in WK_HAIR for c in ring)}
            best = max(cnt, key=cnt.get)
            col = {"skin": MAROON, "fur": FUR_D, "gold": GOLD_D, "red": DEEP_RED, "hair": WH_E}[best] if cnt[best] else MAROON
            ch.append((x, y, col + (255,)))
    for x, y, c in ch:
        o[x, y] = c
    return im


def w_make_frame(sway, expr, cfg=None):
    global WCFG
    WCFG = dict(WK_BASE, **(cfg or {}))
    src = w_draw_frame(sway, expr)
    diff = ImageChops.difference(src, Image.new("RGB", src.size, BG)).convert("L").point(lambda v: 255 if v > 0 else 0)
    mask = diff.resize((W, H), Image.BOX).point(lambda v: 255 if v > 110 else 0)
    out = snap(pixelize(src, W, 40), mask, WK_PAL)
    nn = snap(src.resize((W, H), Image.NEAREST), mask, WK_PAL)       # eyes sampled at pixel centres: crisp flat colours
    for sgn in (-1, 1):
        ex = 24 + sgn * 4.8
        for y in range(int((27.8 - 3.6) * 2), int((27.8 + 3.7) * 2) + 1):
            for x in range(int((ex - 5.0) * 2), int((ex + 5.0) * 2) + 1):
                out.putpixel((x, y), nn.getpixel((x, y)))
    px = out.load()
    prot = {(x, y) for y in range(44, 66) for x in range(26, 72) if px[x, y] == CREAM + (255,)}
    out = cleanup(out, prot)
    eyes_box = [(30, 48, 66, 62)] if True else []
    keeps = [(28, 46, 68, 64)] + ([(38, 66, 60, 82)] if expr == "shout" else [])
    out = w_recolor_interior(out, keeps)
    w_add_glints(out, sway)
    return out


W_FRAMES = [(-1, "calm"), (1, "calm"), (0.3, "determined"), (0.5, "shout")]

W_VARIANTS = [
    ("A", dict(hair="spiky", feather="back", band="wide", eyes="iris", mouth="smirk", staff=False, mane=False),
     "spiky swept-back hair, wide gold headband + gem, two long red plumes streaming back (the gameplay sprite's look), cheeky gold-iris eyes, smirk"),
    ("B", dict(hair="shaggy", feather="single", band="circlet", eyes="iris", mouth="flat", staff=False, mane=False),
     "shaggy mop with long cheek tufts, thin gold circlet + gem, one tall curling plume, big cheeky gold-iris eyes, flat calm mouth"),
    ("C", dict(hair="topknot", feather="up", band="wide", eyes="flint", mouth="smirk", staff=True, mane=False),
     "slicked hair with a gold-ringed topknot, wide band, two plumes in a V, red-and-gold Cloud Staff behind the shoulder, narrow eyes"),
    ("D", dict(hair="ears", feather="none", band="wide", eyes="iris", mouth="grin", staff=False, mane=False),
     "two pointed monkey-ear tufts on top, long shaggy cheek fur, wide band, no plume, big gold eyes, a wide grin with one fang"),
]
WK_SHIP = "A"


def w_variants_sheet(review, flint_frame):
    from PIL import ImageFont
    S = 4
    bg = (92, 112, 134, 255)
    cw = W * S + 8
    sheet = Image.new("RGBA", (cw * 5 + 8, H * S + 90 + H + 24), bg)
    try:
        font = ImageFont.load_default(size=52)
    except TypeError:
        font = ImageFont.load_default()
    d = ImageDraw.Draw(sheet)
    tiles = [("Flint", flint_frame)] + [(lab, w_make_frame(-1, "calm", cfg)) for lab, cfg, _ in W_VARIANTS]
    for i, (label, f) in enumerate(tiles):
        big = f.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(big, (8 + i * cw, 8), big)
        tw = d.textlength(label, font=font)
        d.text((8 + i * cw + (W * S - tw) / 2, H * S + 20), label, fill=(255, 255, 255, 255), font=font)
        sheet.alpha_composite(f, (8 + i * cw + (W * S - W) // 2, H * S + 90 + 8))
    sheet.convert("RGB").save(os.path.join(review, "wukong_variants.png"))
    with open(os.path.join(review, "wukong_variants_key.txt"), "w") as fh:
        for lab, _, text in W_VARIANTS:
            fh.write("%s: %s\n" % (lab, text))
        fh.write("shipped: %s\n" % WK_SHIP)


def wukong_main(review=None):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    ship = dict((l, c) for l, c, _ in W_VARIANTS)[WK_SHIP]
    frames = [w_make_frame(s, e, ship) for s, e in W_FRAMES]
    strip = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    dst = os.path.join(root, "assets", "title", "anime")
    os.makedirs(dst, exist_ok=True)
    strip.save(os.path.join(dst, "wukong_bust.png"))
    if not review:
        return
    os.makedirs(review, exist_ok=True)
    flint = Image.open(os.path.join(dst, "flint_bust.png")).convert("RGBA").crop((0, 0, W, H))
    w_variants_sheet(review, flint)
    S = 4
    bg = (92, 112, 134, 255)
    cw = W * S + 8
    sheet = Image.new("RGBA", (cw * 5 + 8, H * S + 16), bg)
    fb = flint.resize((W * S, H * S), Image.NEAREST)
    sheet.paste(fb, (8, 8), fb)
    for i, f in enumerate(frames):
        big = f.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(big, (8 + (i + 1) * cw, 8), big)
    sheet.convert("RGB").save(os.path.join(review, "wukong_bust_review.png"))
    x1 = Image.new("RGBA", (W * 5, H), bg)
    x1.alpha_composite(flint, (0, 0))
    for i, f in enumerate(frames):
        x1.alpha_composite(f, ((i + 1) * W, 0))
    x1.convert("RGB").save(os.path.join(review, "wukong_bust_x1.png"))


if __name__ == "__main__":
    wukong_main(sys.argv[1] if len(sys.argv) > 1 else None)
