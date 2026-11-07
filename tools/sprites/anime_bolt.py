"""Bolt anime bust (title-screen showcase art), original art. Built on Flint's / Sakura's code in anime_busts.py.

Same pipeline (.claude/skills/anime-pixel-art): smooth vector illustration at 8 source px per output px ->
pixelize -> snap to Bolt's palette (gameplay colours + ramps) -> cleanup -> interior ink recoloured -> crackling
arcs in place of Flint's embers. His hair is the Godspeed form: yellow lightning spikes (flame tongues drawn as
straight, barely wavy spikes) with orange edges, teal eyes, maroon track suit with gold stripes and a bolt patch.

Run: tools/sprites/.venv/bin/python tools/sprites/anime_bolt.py [review_dir]
Output: assets/title/anime/bolt_bust.png (calm A, calm B, determined, shout), 96 x 128 each.
With a review_dir also writes bolt_variants.png (+ key txt) and bolt_bust_review.png.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anime_busts as ab
from anime_busts import (P, K, F, SW, SH, W, H, BG, INK, MAROON, YELLOW, ORANGE, SK, SK_L, SK_S, SK_D, WHITE, RED, FACE,
                         EAR_L, EAR_R, NECK, TORSO, YOFF, TOFF, poly, outline, shape, rect, poly_mask, box_mask, shift, both,
                         inv, paste_mask, tongue, snap, cleanup, pixelize, lc, smooth)

# ---------------------------------------------------------------- palette
BT_TEAL = (60, 200, 196); BT_TEAL_D = (24, 112, 140); BT_TEAL_L = (160, 240, 240)
BT_HY = YELLOW; BT_HY_L = (255, 238, 150); BT_HY_D = ORANGE; BT_HY_E = (196, 104, 40)
BT_SUIT = MAROON; BT_SUIT_L = (178, 62, 72); BT_SUIT_D = (78, 30, 46)
BT_STEEL = (93, 107, 138); BT_STEEL_L = (154, 167, 194)
BT_BROW = (150, 84, 40)
BT_RIM = (255, 238, 150)
BT_PALETTE = [(58, 24, 44), INK, MAROON, SK, SK_L, SK_S, SK_D, WHITE, BT_TEAL, BT_TEAL_D, BT_TEAL_L, BT_HY, BT_HY_L, BT_HY_D, BT_HY_E,
              BT_SUIT_L, BT_SUIT_D, BT_STEEL, BT_STEEL_L, BT_BROW, RED]
BT_SUITS = {BT_SUIT, BT_SUIT_L, BT_SUIT_D, RED}
BT_HAIRS = {BT_HY, BT_HY_L, BT_HY_D, BT_HY_E}
BT_EYECOLS = {WHITE, BT_TEAL, BT_TEAL_D, BT_TEAL_L}
BT_EYECOLS_YEL = BT_EYECOLS | {YELLOW, BT_HY_L, ORANGE}

# ---------------------------------------------------------------- the look (variant = a dict)
# Hair takes: three depth layers (back = deep orange mass, mid, front) of irregular spikes. Each layer is
# (count, angle from, angle to (deg from vertical, + = right), tip length base); `lean` rotates the whole crown,
# `seed` jitters angles / lengths so nothing is evenly spaced. Tips are clamped inside the frame.
BT_TAKES = {
    "explode": dict(back=(10, -58, 58, 26), mid=(9, -52, 54, 21), front=(8, -38, 40, 12), lean=0, seed=3, bang=3),
    "swept": dict(back=(10, -80, 32, 27), mid=(9, -74, 30, 22), front=(8, -62, 24, 13), lean=-6, seed=11, bang=3),
    "clumps": dict(back=(9, -60, 62, 27), mid=(10, -56, 58, 22), front=(8, -42, 46, 13), lean=4, seed=7, bang=4, clump=True),
    "pomp": dict(back=(9, -50, 54, 25), mid=(8, -26, 62, 25), front=(7, -16, 52, 19), lean=8, seed=5, bang=3),
}
BT_BASE = dict(take="explode", eyes="narrow", acc="none", mouth="smirk")
BT_TIPS = []
BT_ST = {}      # per-frame state of the charge strip (empty = the normal bust)


def bt_layers(take, flare=1.0):
    import random
    import math as m
    T = BT_TAKES[take]
    rng = random.Random(T["seed"])
    out = []
    # tip height ranges per depth (design y): back reaches the frame top, front stays on the crown
    heights = {0: (0.9, 11.0), 1: (3.0, 12.0), 2: (7.0, 14.5)}
    for name, depth in (("back", 0), ("mid", 1), ("front", 2)):
        n, a0, a1, L0 = T[name]
        layer = []
        for i in range(n):
            u = i / (n - 1)
            a = a0 + (a1 - a0) * u + rng.uniform(-6, 6) + T["lean"]
            if T.get("clump") and i % 3 == 1:
                a = layer[-1][4] + rng.uniform(5, 9)
            ang = m.radians(a)
            th = m.radians(max(-95, min(95, (a - T["lean"]) * 1.5)))
            rt = (24 + 11.0 * m.sin(th), 20.6 - 7.0 * m.cos(th) + depth * 0.8)
            hlo, hhi = heights[depth]
            centre = 1.0 - abs(u - 0.5) * 2 * 0.4          # taller towards the middle
            ty = hhi - (hhi - hlo) * centre * rng.choice((0.25, 0.45, 0.6, 0.8, 1.0, 1.0)) * rng.uniform(0.9, 1.0) - (flare - 1.0) * 14
            ty = max(ty, 0.9)
            dy = -m.cos(ang)
            ln = (rt[1] - ty) / max(-dy, 0.35)
            ln = min(ln, L0 * 1.25) * flare ** 0.5
            dx = m.sin(ang)
            tx = rt[0] + dx * ln
            if tx < 1.0:
                ln *= (rt[0] - 1.0) / max(rt[0] - tx, 1e-3)
            elif tx > 47.0:
                ln *= (47.0 - rt[0]) / max(tx - rt[0], 1e-3)
            tip = (rt[0] + dx * ln, max(0.9, rt[1] + dy * ln))
            w = (8.0 - 1.2 * depth) * rng.uniform(0.85, 1.1)
            bend = rng.uniform(-1.8, 1.8)
            layer.append((rt, tip, w, bend, a))
        out.append(layer)
    return out


def bt_bangs(take, s):
    """Spikes down over the forehead: a thin one between the eyes, two over the temples, short ones either side."""
    n = BT_TAKES[take]["bang"]
    sets = [((24.0, 19.0), (24.3, 25.6), 3.8), ((19.8, 19.0), (17.6, 23.4), 5.0), ((28.4, 19.0), (30.2, 23.0), 5.0),
            ((15.5, 19.5), (13.4, 24.0), 4.4)]
    return sets[:n]
BT_CFG = dict(BT_BASE)


# ---------------------------------------------------------------- torso
BT_LCOLLAR = [(14.0, 45.2), (18.2, 42.6), (20.2, 43.2), (23.6, 49.0), (19.6, 47.0)]
BT_RCOLLAR = [(34.0, 45.2), (29.8, 42.6), (27.8, 43.2), (24.4, 49.0), (28.4, 47.0)]
BT_BOLT = [(11.0, 52.2), (16.0, 51.4), (14.6, 54.6), (17.6, 54.2), (11.8, 61.0), (13.2, 56.6), (10.2, 56.8)]


def bt_torso(img, d):
    YOFF[0] = TOFF
    shape(d, NECK, SK)
    shape(d, TORSO, BT_SUIT)
    neckm, torm = poly_mask(NECK), poly_mask(TORSO)
    poly(d, [(28, 42.8), (34, 44.4), (43, 47.7), (47.6, 53), (47.6, 64), (40, 64), (36.5, 52)], BT_SUIT_D)
    paste_mask(img, BT_SUIT_L, both(both(torm, inv(shift(torm, 0, int(9 * F)))), box_mask(0, 0, 19, 80)))
    paste_mask(img, BT_RIM, both(both(torm, inv(shift(torm, int(-6 * F), int(5 * F)))), box_mask(34, 0, 48, 56)))
    d = ImageDraw.Draw(img)
    # sleeve folds
    for (a, b, dark, lit) in [((6.5, 52), (10.5, 60.5), BT_SUIT_D, BT_SUIT_L), ((2.5, 57.5), (5.5, 64.5), BT_SUIT_D, BT_SUIT_L),
                              ((36.5, 51.5), (34.5, 60), BT_SUIT_D, BT_SUIT),
                              ((41.5, 55.5), (39.5, 64.5), BT_SUIT_D, BT_SUIT)]:
        d.line([P(*a), P(*b)], fill=dark, width=7)
        d.line([P(a[0] + 0.9, a[1] - 0.3), P(b[0] + 0.9, b[1] - 0.3)], fill=lit, width=4)
    # gold shoulder stripe running down the sleeves
    for pts, col in [([(3.6, 48.4), (1.0, 56), (0.6, 64)], YELLOW), ([(44.4, 48.4), (46.6, 56), (47.2, 64)], BT_HY_D)]:
        d.line([P(*p) for p in pts], fill=col, width=7, joint="curve")
    # zip + the bolt patch
    d.line([P(24.0, 47.6), P(24.0, 64.5)], fill=BT_STEEL_L, width=8)
    d.line([P(24.7, 47.6), P(24.7, 64.5)], fill=BT_STEEL, width=4)
    poly(d, BT_BOLT, YELLOW)
    d.line([P(*p) for p in (BT_BOLT[0], BT_BOLT[1], BT_BOLT[2])], fill=BT_HY_L, width=3)
    paste_mask(img, SK_L, both(neckm, box_mask(0, 0, 21.4, 80)))
    paste_mask(img, SK_S, both(neckm, box_mask(26.6, 0, 48, 80)))
    d = ImageDraw.Draw(img)
    # collar
    shape(d, BT_LCOLLAR, BT_SUIT_L, col=BT_SUIT_D)
    shape(d, BT_RCOLLAR, BT_SUIT, col=BT_SUIT_D)
    d.line([P(*p) for p in (BT_LCOLLAR[0], BT_LCOLLAR[1], BT_LCOLLAR[2])], fill=BT_STEEL_L, width=4)
    d.line([P(*p) for p in (BT_RCOLLAR[0], BT_RCOLLAR[1], BT_RCOLLAR[2])], fill=BT_STEEL, width=4)
    YOFF[0] = 0.0
    return neckm, torm


# ---------------------------------------------------------------- face
def bt_eye(img, d, cx, cy, side, o, kind, wide=1.0):
    """White sclera, tall teal iris (dark top, light bottom glow), heavy straight upper lid, white highlight."""
    if kind == "round":
        ow, ot, it, bot = 3.3, 3.6, 2.2, 1.9
        irx, iry = 2.15, 2.5
    elif kind == "sharp":
        ow, ot, it, bot = 3.5 * wide, 3.0, (0.2 if o < 1.1 else 0.9), 2.0
        irx, iry = 1.9, 2.6
    else:   # narrow: Flint's eye
        ow, ot, it, bot = 3.3 * wide, 2.4, (0.1 if o < 1.1 else 1.2), 2.3
        irx, iry = 2.0, 2.6
    outer = (cx + side * ow, cy - ot * (0.7 if kind == "round" else 1.0))
    inner = (cx - side * ow, cy - it * (0.7 if kind == "round" else 1.0) if kind != "round" else cy - 1.4)
    up = [(outer[0] + (inner[0] - outer[0]) * k / 6, outer[1] + (inner[1] - outer[1]) * k / 6) for k in range(7)]
    if kind == "round":   # arched lid
        up = [(x, y - 1.1 * (1 - ((k - 3) / 3.0) ** 2)) for k, (x, y) in enumerate(up)]
    lo = smooth([inner, (cx - side * 0.9, cy + bot * 0.55 + 0.4 * o), (cx + side * 1.2, cy + bot * 0.5 + 0.3 * o), outer])
    pts = up + lo
    d.polygon([P(*p) for p in pts], fill=WHITE)
    m = ab.mask_of(lambda m_: m_.polygon([P(*p) for p in pts], fill=255))
    icx, icy = cx + side * 0.4, cy - 0.3 + (0.2 if kind == "round" else 0)

    def ell(rx, ry, ox=0.0, oy=0.0):
        return ab.mask_of(lambda m_: m_.ellipse(((icx + ox - rx) * K, (icy + oy - ry) * K, (icx + ox + rx) * K, (icy + oy + ry) * K), fill=255))
    paste_mask(img, BT_TEAL_D, both(ell(irx, iry), m))
    paste_mask(img, BT_TEAL, both(both(ell(irx - 0.35, iry - 0.5, 0, 0.35), m), inv(box_mask(0, 0, 48, icy - 0.9))))
    paste_mask(img, BT_TEAL_L, both(both(ell(irx - 0.7, iry - 1.2, 0, 1.1), m), box_mask(0, icy + 0.8, 48, 64)))
    st = BT_ST
    yr = st.get("yel", 0.0)
    if yr > 0:      # yellow spreads from the pupil outward: dark orange top, yellow, light lower glow
        yl = both(ell(irx * yr * 1.1, iry * yr * 1.1), both(ell(irx, iry), m))
        paste_mask(img, BT_HY_D, yl)
        paste_mask(img, YELLOW, both(yl, box_mask(0, icy - 0.9, 48, 64)))
        paste_mask(img, BT_HY_L, both(yl, box_mask(0, icy + 1.5, 48, 64)))
    if yr >= 1.0:   # white-yellow core round the pupil
        paste_mask(img, BT_HY_L, both(ell(0.95, 1.15, 0, 0.1), m))
    if st.get("flash"):    # white spark in the iris
        def spark(m_):
            m_.ellipse(((icx - 0.95) * K, (icy - 0.95) * K, (icx + 0.95) * K, (icy + 0.95) * K), fill=255)
            m_.line([P(icx - 2.3, icy), P(icx + 2.3, icy)], fill=255, width=16)
            m_.line([P(icx, icy - 2.5), P(icx, icy + 2.5)], fill=255, width=16)
        paste_mask(img, WHITE, both(ab.mask_of(spark), m))
    d = ImageDraw.Draw(img)
    pw = max(0.42, 0.55 * st.get("pupil", 1.0))
    d.ellipse(((icx - pw) * K, (icy - 0.5) * K, (icx + pw) * K, (icy + 0.7) * K), fill=INK)      # pupil
    hx, hy = icx - side * 0.75, icy - 1.0
    hs = 0.7 if yr >= 1.0 else 0.55
    d.rectangle(((hx - hs) * K, (hy - hs) * K, (hx + hs) * K, (hy + hs) * K), fill=WHITE)
    d.line([P(*p) for p in up], fill=INK, width=14, joint="curve")
    if kind == "sharp":   # lid tail flick outwards
        d.line([P(outer[0], outer[1]), P(outer[0] + side * 0.9, outer[1] - 0.5)], fill=INK, width=12)
    return d


def bt_mouth(d, kind, expr):
    YOFF[0] = -2.7
    if expr == "shout":
        pass   # exact pixels after the pixel art (bt_shout)
    elif expr == "grin":
        pts = [(21.0, 38.5), (24.0, 39.4), (27.2, 38.3), (26.4, 40.3), (24.0, 41.3), (21.8, 40.3)]
        poly(d, pts, MAROON)
        rect(d, 21.8, 38.9, 26.4, 39.9, WHITE)
    elif expr == "determined":
        d.line([P(22.0, 39.2), P(24.4, 39.3), P(26.8, 38.7)], fill=MAROON, width=8, joint="curve")
    elif kind == "grin":
        pts = [(21.6, 38.7), (24.0, 39.5), (26.6, 38.7), (26.0, 40.2), (24.0, 40.9), (22.2, 40.2)]
        poly(d, pts, MAROON)
        rect(d, 22.2, 39.0, 26.0, 39.8, WHITE)
    else:   # smirk, right corner lifted
        d.line([P(22.2, 39.3), P(24.4, 39.4), P(26.2, 39.0), P(27.0, 38.4)], fill=MAROON, width=8, joint="curve")
    YOFF[0] = 0.0


def bt_face(img, neckm, torm, expr):
    facem = poly_mask(FACE)
    jaw = both(both(shift(facem, int(4 * F), int(20 * F)), neckm), inv(facem))
    paste_mask(img, SK_S, both(jaw, inv(torm)))
    jaw2 = both(both(shift(facem, int(4 * F), int(8 * F)), neckm), inv(facem))
    paste_mask(img, SK_D, both(jaw2, inv(torm)))
    d = ImageDraw.Draw(img)
    shape(d, EAR_L, SK)
    shape(d, EAR_R, SK_S)
    d.line([P(11.9, 26.9), P(11.0, 28.4), P(11.1, 30.4)], fill=SK_L, width=4, joint="curve")
    d.line([P(48 - 11.9, 26.9), P(48 - 11.0, 28.4), P(48 - 11.1, 30.4)], fill=SK_D, width=4, joint="curve")
    d.line([P(13.0, 27.8), P(12.1, 29.2), P(12.5, 31.0), P(13.5, 31.7)], fill=SK_D, width=4, joint="curve")
    d.line([P(48 - 13.0, 27.8), P(48 - 12.1, 29.2), P(48 - 12.5, 31.0), P(48 - 13.5, 31.7)], fill=SK_D, width=4, joint="curve")
    shape(d, FACE, SK)
    paste_mask(img, SK_L, both(facem, poly_mask([(15.0, 29.0), (21.0, 30.0), (20.2, 34.0), (17.6, 34.2), (15.4, 32.5)])))
    paste_mask(img, SK_L, both(facem, poly_mask([(15.4, 22.5), (21, 22.5), (20.5, 24.5), (15.2, 25)])))
    paste_mask(img, SK_S, both(facem, inv(shift(facem, int(-22 * F), 0))))
    paste_mask(img, SK_S, both(facem, poly_mask([(26.0, 34.0), (35.4, 30.5), (34.4, 35.5), (28.0, 41.4), (24.5, 41)])))
    chin = both(facem, inv(shift(facem, 0, int(-14 * F))))
    paste_mask(img, SK_S, both(chin, shift(facem, int(-30 * F), 0)))
    paste_mask(img, SK_D, both(both(facem, inv(shift(facem, int(-9 * F), 0))), box_mask(0, 25, 48, 40)))
    paste_mask(img, BT_RIM, both(both(facem, inv(shift(facem, int(-4 * F), 0))), box_mask(0, 26, 48, 36)))
    d = ImageDraw.Draw(img)
    d = ImageDraw.Draw(img)
    d.line([P(24.0, 25.4), P(24.0, 30.0)], fill=SK_L, width=7)
    d.line([P(25.0, 31.4), P(25.5, 33.0)], fill=SK_D, width=7)
    bt_mouth(d, BT_CFG["mouth"], expr)
    outline(d, FACE[1:] + FACE[:1], w=9, closed=False)
    if expr == "shout":
        o, wd = 2.2, 1.12
    elif expr in ("determined", "grin"):
        o, wd = 1.0, 1.05
    else:
        o, wd = 1.6, 1.1
    cy = 27.8
    kind = BT_CFG["eyes"]
    bt_eye(img, d, 19.2, cy, -1, o, kind, wd)
    bt_eye(img, d, 28.8, cy, 1, o, kind, wd)
    return facem


# ---------------------------------------------------------------- hair
BT_HAIRLINE = [(13.4, 23), (14.5, 21.6), (17, 19.8), (20.5, 20.4), (24, 20), (27.5, 20.4), (31, 19.8), (33.5, 21.6), (34.6, 23)]
BT_CAP = [(12.8, 22), (13.4, 17), (17, 14.5), (24, 12.8), (31, 14.5), (34.6, 17), (35.2, 22)]
BT_EDGE = lc(BT_HY_E)


def bt_hair_col(t):
    if t < 0.18:
        return BT_HY_D
    if t < 0.7:
        return BT_HY
    return BT_HY_L


def bt_spike(hd, root, tip, w, bend, sway, ph, shade=1, n=24, depth=1):
    # tongues with cols: orange edge, no ink; back layer deep orange, mid yellow, front lighter
    fn = {0: lambda t: BT_HY_D if t < 0.62 else BT_HY, 1: bt_hair_col, 2: lambda t: BT_HY if t < 0.5 else BT_HY_L}[depth]
    shade_c = BT_HY_E if depth == 0 else BT_HY_D
    lit_c = BT_HY if depth == 0 else BT_HY_L
    return tongue(hd, root, tip, w, bend, sway=sway, shade_side=shade, ph=ph, wave=0.05, n=n, ow=6,
                  cols=(BT_EDGE, fn, shade_c, lit_c),
                  bands=[(shade, 0.3, 1.0, 0.1, 0.75, shade_c), (-shade, 0.4, 1.0, 0.25, 0.9, lit_c)])


def bt_hair(img, facem, s, expr="calm"):
    global BT_TIPS
    BT_TIPS = []
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    cap_pts = BT_CAP + BT_HAIRLINE[::-1]
    cap = poly_mask(cap_pts)
    flare = BT_ST.get("flare", 1.14 if expr == "shout" else 1.0)
    layers = bt_layers(BT_CFG["take"], flare)
    for depth, layer in enumerate(layers):
        if depth == 2:
            poly(hd, cap_pts, BT_HY)
        for i, (r, t, w, b, a) in enumerate(layer):
            h = ((i * 7 + depth * 3) % 5 - 2) / 2.0           # -1 .. 1, fixed per spike
            sw = s * 3.2 * h + (0.8 * flare if expr == "shout" else 0) * h + (flare - 1.0) * 4 * h * (0 if expr == "shout" else 1)
            cs, _ = bt_spike(hd, r, t, w * (1.06 if expr == "shout" else 1.0), b, sw, i * 0.37 + s * 0.3 + depth,
                             shade=1 if a < 0 else -1, depth=depth)
            if depth < 2 or i % 2 == 0:
                BT_TIPS.append((cs[-1][0] * 2, cs[-1][1] * 2, depth))
    # side locks over the top of each ear
    for side, (r, t) in ((-1, ((13.4, 21.0), (9.6, 32.0))), (1, ((34.6, 21.0), (38.4, 32.0)))):
        bt_spike(hd, r, t, 4.8, 1.0 * side, s * 0.5 * -side, 0.5 + s * 0.2, shade=-side, n=18, depth=2)
    # crown gloss (lit, top left) and a shade band along the hairline
    gl = both(both(cap, inv(shift(cap, int(4 * F), int(5 * F)))), box_mask(0, 12, 28, 21))
    hl.paste(BT_HY_L + (255,), (0, 0), gl)
    band = both(both(cap, inv(shift(cap, 0, int(-10 * F)))), box_mask(0, 17, 48, 27))
    hl.paste(BT_HY_D + (255,), (0, 0), band)
    shd = both(both(shift(cap, 0, int(15 * F)), facem), inv(cap))
    img.paste(SK_S, (0, 0), shd)
    shd2 = both(both(shift(cap, 0, int(6 * F)), facem), inv(cap))
    img.paste(SK_D, (0, 0), shd2)
    for i, (r, t, w) in enumerate(bt_bangs(BT_CFG["take"], s)):
        bt_spike(hd, r, t, w, 0.6 * (1 if i % 2 else -1), s * 0.5, i + s * 0.3, shade=1 if i % 2 == 0 else -1, n=14, depth=2)
    img.paste(hl, (0, 0), hl.split()[3])
    d = ImageDraw.Draw(img)
    d.line([P(*p) for p in BT_HAIRLINE], fill=SK_D, width=4, joint="curve")


def bt_accessory(img):
    acc = BT_CFG["acc"]
    d = ImageDraw.Draw(img)
    if acc == "goggles":   # strap round the crown with two lenses pushed up on the hair
        d.line([P(13.0, 20.2), P(18, 17.2), P(24, 16.4), P(30, 17.2), P(35, 20.2)], fill=BT_STEEL, width=22, joint="curve")
        d.line([P(13.0, 19.4), P(18, 16.4), P(24, 15.6), P(30, 16.6), P(35, 19.4)], fill=BT_STEEL_L, width=6, joint="curve")
        for cx in (19.4, 28.6):
            d.ellipse(((cx - 3.0) * K, 12.8 * K, (cx + 3.0) * K, 19.0 * K), fill=INK)
            d.ellipse(((cx - 2.3) * K, 13.5 * K, (cx + 2.3) * K, 18.3 * K), fill=BT_TEAL_D)
            d.ellipse(((cx - 1.9) * K, 13.9 * K, (cx + 1.3) * K, 16.8 * K), fill=BT_TEAL)
            d.rectangle(((cx - 1.4) * K, 14.1 * K, (cx - 0.2) * K, 15.1 * K), fill=WHITE)
    elif acc == "headband":   # maroon band with a gold bolt across the brow, spikes pushing out above
        band = [(12.8, 20.6), (17, 18.6), (24, 17.8), (31, 18.6), (35.2, 20.6), (35.2, 23.6), (31, 21.6), (24, 20.9), (17, 21.6),
                (12.8, 23.6)]
        shape(d, band, BT_SUIT, w=6, col=BT_SUIT_D)
        d.line([P(*p) for p in band[:5]], fill=BT_SUIT_L, width=4, joint="curve")
        poly(d, [(23.4, 17.9), (26.2, 17.9), (25.0, 20.0), (26.6, 20.0), (22.6, 23.0), (23.6, 20.8), (22.2, 20.8)], YELLOW)
    elif acc == "plaster":   # a plaster over the nose bridge
        d.rectangle((21.2 * K, 30.2 * K, 26.6 * K, 31.8 * K), fill=WHITE)
        d.rectangle((21.2 * K, 30.2 * K, 22.0 * K, 31.8 * K), fill=SK_S)
        d.rectangle((25.8 * K, 30.2 * K, 26.6 * K, 31.8 * K), fill=SK_S)
        d.rectangle((23.1 * K, 30.2 * K, 24.5 * K, 31.8 * K), fill=BT_STEEL_L)


def bt_draw_frame(sway=0.0, expr="calm"):
    img = Image.new("RGB", (SW, SH), BG)
    d = ImageDraw.Draw(img)
    neckm, torm = bt_torso(img, d)
    facem = bt_face(img, neckm, torm, expr)
    bt_hair(img, facem, sway, expr)
    bt_accessory(img)
    return img


# ---------------------------------------------------------------- finishing
def bt_recolor_interior(im, keep=None):
    """Ink only on the silhouette and lids; interior ink -> maroon-dark suit, orange-brown on hair, deep skin."""
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
            if None in ring or any(c in (BT_EYECOLS_YEL if BT_ST.get("yel") else BT_EYECOLS) for c in ring):
                continue
            su = sum(c in BT_SUITS for c in ring)
            hr = sum(c in BT_HAIRS for c in ring)
            col = BT_SUIT_D if su >= max(hr, len(ring) - su - hr) and su > 0 else BT_HY_E if hr > len(ring) / 3 else SK_D
            ch.append((x, y, col + (255,)))
    for x, y, c in ch:
        o[x, y] = c
    return im


def bt_line(px, w, h, a, b, col):
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        if 0 <= x0 < w and 0 <= y0 < h and px[x0, y0][3] == 0:
            px[x0, y0] = col + (255,)
        if (x0, y0) == (x1, y1):
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


# arcs crackling off the head: start pixel, then zig-zag offsets; the two phases alternate with the frame
BT_PLUM = (58, 24, 44)


BT_ARC_TEAL = (BT_TEAL_D, BT_TEAL_L, WHITE)
BT_ARC_YEL = (BT_HY_D, YELLOW, BT_HY_L)


def bt_zig(px, w, h, a, b, ph, amp=2, cols=BT_ARC_TEAL):
    """Zig-zag bolt from a to b: dark under, light over (alternating with white), only on empty pixels."""
    import math as m
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = max(m.hypot(dx, dy), 1)
    nx, ny = -dy / L, dx / L
    n = max(3, int(L / 3.5))
    pts = [a]
    for k in range(1, n):
        t = k / n
        o = amp * (1 if (k + ph) % 2 else -1)
        pts.append((round(a[0] + dx * t + nx * o), round(a[1] + dy * t + ny * o)))
    pts.append(b)
    for j in range(len(pts) - 1):
        bt_line(px, w, h, (pts[j][0] + 1, pts[j][1]), (pts[j + 1][0] + 1, pts[j + 1][1]), cols[0])
    for j in range(len(pts) - 1):
        bt_line(px, w, h, pts[j], pts[j + 1], cols[1] if j % 2 == 0 else cols[2])


def bt_arcs(out, sway, frame):
    """Electric rim on some spike tips, bolts jumping between tips and off the outer ones.
    Charge strip: BT_ST arcs = how many bolts, rim = how many tips flicker white, arcyel = bolts / rims yellow-white."""
    px = out.load()
    st = BT_ST
    tips = sorted(((round(x), round(y), d) for x, y, d in BT_TIPS), key=lambda t: t[0])
    W_, H_ = out.width, out.height
    yel = st.get("arcyel", 0)
    cols = BT_ARC_YEL if yel else BT_ARC_TEAL
    rim_cols = (WHITE, BT_HY_L, BT_HY_L) if yel else (WHITE, BT_TEAL_L, BT_TEAL_L)
    if "rim" in st:
        order = sorted(range(len(tips)), key=lambda k: (k * 7 + frame * 3) % max(len(tips), 1))
        rim_set = set(order[:st["rim"]])
    else:
        rim_set = {k for k in range(len(tips)) if (k + frame) % 3 == 0}
    for k, (x, y, d) in enumerate(tips):
        if k in rim_set:
            for j, col in enumerate(rim_cols):
                yy = y + j
                if 0 <= x < W_ and 0 <= yy < H_ and (px[x, yy][3] > 0 or j == 0):
                    px[x, yy] = col + (255,)
    top = [t for t in tips if t[1] < 26]
    pairs = []
    for k in range(len(top) - 1):
        a, b = top[k], top[k + 1]
        dist = abs(a[0] - b[0]) + abs(a[1] - b[1])
        if 8 <= dist <= 26:
            pairs.append((a, b))
    if "arcs" in st:
        order = sorted(range(len(pairs)), key=lambda k: (k * 5 + frame * 3) % max(len(pairs), 1))
        chosen = set(order[:st["arcs"]])
    else:
        chosen = {k for k in range(len(pairs)) if (k + frame) % 3 == 1}
    for k, (a, b) in enumerate(pairs):
        if k in chosen:
            bt_zig(px, W_, H_, (a[0], a[1]), (b[0], b[1]), frame, cols=cols)
    for k in range(st.get("side", 0)):      # bolts jumping off the sides of the head into the empty space
        y = (36, 46, 28, 54, 40, 32)[k % 6] + (frame % 2) * 2
        xs = [x for x in range(W_) if px[x, y][3] > 0]
        if xs:
            l, r = xs[0], xs[-1]
            if k % 2 == 0:
                bt_zig(px, W_, H_, (l, y), (max(1, l - 9), y - 5 - frame % 2), frame + k, 1, cols)
            else:
                bt_zig(px, W_, H_, (r, y), (min(W_ - 2, r + 9), y - 5 - frame % 2), frame + k, 1, cols)
    if top and st.get("arcs", 1) >= 1:   # off the outermost tips
        l, r = top[0], top[-1]
        bt_zig(px, W_, H_, (l[0], l[1]), (max(1, l[0] - 6 - frame % 2), max(1, l[1] - 7 + frame % 2)), frame, 1, cols)
        bt_zig(px, W_, H_, (r[0], r[1]), (min(W_ - 2, r[0] + 6 + frame % 2), max(1, r[1] - 7 + frame % 2)), frame + 1, 1, cols)


def bt_cheek_rim(out):
    """Electric teal rim on the right cheek: the pixel just inside the ink outline, jaw rows only."""
    px = out.load()
    for y in range(67, 80):
        xs = [x for x in range(out.width - 1, 40, -1) if px[x, y][3] > 0]
        if not xs:
            continue
        xr = xs[0]
        for k in (1, 2) if y < 76 else (1,):
            if px[xr - k, y][:3] in (SK, SK_S, SK_D, SK_L):
                px[xr - k, y] = BT_TEAL_L + (255,)


def bt_shout(out):
    """Small rounded-D mouth: flat top with a 1 px teeth row, dark plum inside, a tongue hint, no ink."""
    px = out.load()
    x0, y0 = 44, 71
    rows = ["OOOOOOOO", "OWWWWWWO", "OPPPPPPO", "OPTTTTPO", ".OTTTTO.", "..OOOO.."]
    cols = {"O": BT_SUIT_D, "W": WHITE, "P": BT_PLUM, "T": RED}
    for j, row in enumerate(rows):
        for i, c in enumerate(row):
            if c != ".":
                px[x0 + i, y0 + j] = cols[c] + (255,)


def bt_brows(out, expr):
    """Exact pixels after the pixel art: short brows sitting just above the lids, V-tilted when determined."""
    px = out.load()
    tilt = 1 if expr in ("determined", "grin") else 0
    lift = 1 if expr == "shout" else 0
    kind = BT_CFG["eyes"]
    for side in (-1, 1):
        cx = 24 + side * 4.8
        x_out = int(cx * 2 + side * (6 if kind != "sharp" else 7))
        x_in = int(cx * 2 - side * 4)
        y0 = 49 + BT_ST.get("browdrop", 0) - lift - (1 if kind == "round" else 0)
        pts = []
        n = abs(x_out - x_in)
        for i in range(n + 1):
            x = x_in + (x_out - x_in) * i // n
            y = y0 + (tilt if i < n // 2 else 0) - (1 if i >= n * 0.65 else 0) * (0 if tilt else 1) - (1 if (tilt == 0 and i >= n * 0.4) else 0) * 0
            pts.append((x, y))
        for x, y in pts:
            px[x, y] = BT_BROW + (255,)
        px[x_in, y0 + 1 + tilt] = BT_BROW + (255,)


def bt_frame(sway, expr, cfg=None, frame=0, st=None):
    global BT_CFG, BT_ST
    BT_ST = dict(st or {})
    BT_CFG = dict(BT_BASE, **(cfg or {}))
    src = bt_draw_frame(sway, expr)
    from PIL import ImageChops
    diff = ImageChops.difference(src, Image.new("RGB", src.size, BG)).convert("L").point(lambda v: 255 if v > 0 else 0)
    mask = diff.resize((W, H), Image.BOX).point(lambda v: 255 if v > 110 else 0)
    out = snap(pixelize(src, W, 40), mask, BT_PALETTE)
    nn = snap(src.resize((W, H), Image.NEAREST), mask, BT_PALETTE)
    for sgn in (-1, 1):
        ex = 24 + sgn * 4.8
        for y in range(int(24.5 * 2), int(31.4 * 2) + 1):
            for x in range(int((ex - 4.6) * 2), int((ex + 4.6) * 2) + 1):
                out.putpixel((x, y), nn.getpixel((x, y)))
    if BT_ST.get("glow"):     # 1 px yellow glow just outside the lash line
        pxg = out.load()
        for sgn in (-1, 1):
            ex = 24 + sgn * 4.8
            for x in range(int((ex - 4.2) * 2), int((ex + 4.2) * 2) + 1):
                ys = [y for y in range(44, 66) if pxg[x, y][:3] == INK and pxg[x, y][3]]
                if ys and pxg[x, ys[0] - 1][:3] in (SK, SK_L, SK_S, SK_D):
                    pxg[x, ys[0] - 1] = (YELLOW if BT_ST["glow"] > 1 else BT_HY_L) + (255,)
    px = out.load()
    prot = {(x, y) for y in range(44, 66) for x in range(26, 72) if px[x, y] == WHITE + (255,)}
    out = cleanup(out, prot)
    out = bt_recolor_interior(out, (38, 66, 60, 82) if expr == "shout" else None)
    bt_brows(out, expr)
    if expr == "shout":
        bt_shout(out)
    bt_cheek_rim(out)
    bt_arcs(out, sway, frame)
    return out


BT_FRAMES = [(-1, "calm"), (1, "calm"), (0.3, "determined"), (0.5, "shout")]

BT_VARIANTS = [
    ("A", dict(take="explode", eyes="narrow", acc="none", mouth="smirk"),
     "Explosive crown: big symmetric-ish fan of ~23 spikes in 3 layers, narrow teal eyes, smirk"),
    ("B", dict(take="swept", eyes="narrow", acc="none", mouth="smirk"),
     "Blast-back: the whole crown blown up and to the left, long streaking spikes"),
    ("C", dict(take="clumps", eyes="narrow", acc="none", mouth="smirk"),
     "Wild clumps: spikes in clusters of 3 with uneven gaps, tallest leaning both ways"),
    ("D", dict(take="pomp", eyes="narrow", acc="none", mouth="smirk"),
     "Mega pompadour: tall forward-leaning central mass with shorter flanks"),
]
BT_SHIP = "C"


def bt_variants_sheet(review, flint):
    bg = (92, 112, 134, 255)
    S = 4
    cw = W * S + 8
    cw1 = W + 8
    tiles = [("Flint", flint)] + [(k, bt_frame(-1, "calm", cfg)) for k, cfg, _ in BT_VARIANTS]
    sheet = Image.new("RGBA", (cw * 5 + 8, H * S + 16 + H + 16 + 70), bg)
    try:
        font = ImageFont.load_default(size=44)
    except TypeError:
        font = ImageFont.load_default()
    d = ImageDraw.Draw(sheet)
    y1 = H * S + 16 + 70
    for i, (label, f) in enumerate(tiles):
        big = f.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(big, (8 + i * cw, 8), big)
        tw = d.textlength(label, font=font)
        d.text((8 + i * cw + (W * S - tw) / 2, H * S + 14), label, fill=(255, 255, 255, 255), font=font)
        sheet.paste(f, (8 + i * cw, y1), f)
    sheet.convert("RGB").save(os.path.join(review, "bolt_variants.png"))
    with open(os.path.join(review, "bolt_variants_key.txt"), "w") as fh:
        fh.write("Flint = reference (far left), calm frame. Top row x4, bottom row x1.\n")
        for k, _, text in BT_VARIANTS:
            fh.write("%s: %s\n" % (k, text))
        fh.write("Shipped: %s\n" % BT_SHIP)


# ---------------------------------------------------------------- charge strip (calm -> eyes turn electric yellow)
# per frame: sway, expr, state. yel = how far the yellow has spread from the pupil, flash = white spark in the iris,
# pupil = pupil width scale, glow = yellow line above the lashes, flare = hair size, arcs / rim = bolts between tips /
# tips flickering white, arcyel = bolts and rims turned yellow-white, browdrop = brows pushed down 1 px.
BT_CHARGE = [
    (-1.0, "calm", dict()),
    (0.6, "calm", dict(arcs=2, rim=3, flare=1.02, browdrop=1, side=1)),
    (-0.5, "determined", dict(arcs=3, rim=4, flare=1.04, flash=True, pupil=0.8, side=2)),
    (0.9, "determined", dict(arcs=4, rim=5, flare=1.07, yel=0.4, pupil=0.7, side=3)),
    (-0.8, "determined", dict(arcs=5, rim=6, flare=1.10, yel=0.75, pupil=0.65, glow=1, side=4)),
    (1.0, "determined", dict(arcs=6, rim=8, flare=1.14, yel=1.1, pupil=0.55, glow=2, arcyel=1, side=5)),
    (-0.9, "determined", dict(arcs=8, rim=10, flare=1.2, yel=1.1, pupil=0.5, glow=2, arcyel=1, side=6)),
    (0.4, "grin", dict(arcs=5, rim=7, flare=1.14, yel=1.1, pupil=0.55, glow=2, arcyel=1, side=4)),
]
BT_CHARGE_MS = [500, 110, 110, 110, 110, 110, 110, 900]


def bolt_charge(anime, review):
    cfg = dict(next(c for k, c, _ in BT_VARIANTS if k == BT_SHIP))
    frames = [bt_frame(sw, ex, cfg, k, dict(st)) for k, (sw, ex, st) in enumerate(BT_CHARGE)]
    strip = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    strip.save(os.path.join(anime, "bolt_charge.png"))
    if not review:
        return
    S = 4
    bg = (92, 112, 134, 255)
    big = []
    for f in frames:
        b = Image.new("RGBA", (W * S, H * S), bg)
        b.alpha_composite(f.resize((W * S, H * S), Image.NEAREST))
        big.append(b.convert("RGB"))
    big[0].save(os.path.join(review, "bolt_charge.gif"), save_all=True, append_images=big[1:], duration=BT_CHARGE_MS, loop=0)
    cw = W * S + 8
    sheet = Image.new("RGB", (cw * 4 + 8, (H * S + 8) * 2 + 8), bg[:3])
    for i, b in enumerate(big):
        sheet.paste(b, (8 + (i % 4) * cw, 8 + (i // 4) * (H * S + 8)))
    sheet.save(os.path.join(review, "bolt_charge_sheet.png"))
    x1 = Image.new("RGBA", strip.size, bg)
    x1.alpha_composite(strip)
    x1.convert("RGB").save(os.path.join(review, "bolt_charge_x1.png"))


def bolt_main():
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    anime = os.path.join(root, "assets", "title", "anime")
    flint = Image.open(os.path.join(anime, "flint_bust.png")).convert("RGBA").crop((0, 0, W, H))
    cfg = dict(next(c for k, c, _ in BT_VARIANTS if k == BT_SHIP))
    frames = [bt_frame(s, e, cfg, k) for k, (s, e) in enumerate(BT_FRAMES)]
    strip = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    strip.save(os.path.join(anime, "bolt_bust.png"))
    review = sys.argv[1] if len(sys.argv) > 1 else None
    if review:
        os.makedirs(review, exist_ok=True)
    bolt_charge(anime, review)
    if not review:
        return
    bt_variants_sheet(review, flint)
    S = 4
    bg = (92, 112, 134, 255)
    cw = W * S + 8
    sheet = Image.new("RGBA", (cw * 5 + 8, H * S + 16), bg)
    for i, f in enumerate([flint] + frames):
        big = f.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(big, (8 + i * cw, 8), big)
    sheet.convert("RGB").save(os.path.join(review, "bolt_bust_review.png"))


if __name__ == "__main__":
    bolt_main()
