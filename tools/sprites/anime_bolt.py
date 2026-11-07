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
BT_PALETTE = [INK, MAROON, SK, SK_L, SK_S, SK_D, WHITE, BT_TEAL, BT_TEAL_D, BT_TEAL_L, BT_HY, BT_HY_L, BT_HY_D, BT_HY_E,
              BT_SUIT_L, BT_SUIT_D, BT_STEEL, BT_STEEL_L, BT_BROW, RED]
BT_SUITS = {BT_SUIT, BT_SUIT_L, BT_SUIT_D, RED}
BT_HAIRS = {BT_HY, BT_HY_L, BT_HY_D, BT_HY_E}
BT_EYECOLS = {WHITE, BT_TEAL, BT_TEAL_D, BT_TEAL_L}

# ---------------------------------------------------------------- the look (variant = a dict)
BT_SPIKES = {
    # root, tip, width, bend  (design units; head top y 12.8, tips may reach y 0.5)
    "up": [((34.5, 18.5), (45.0, 11.0), 6.5, -2.0), ((32.0, 16.0), (39.5, 3.0), 7.5, 2.2), ((28.0, 14.5), (31.0, 6.4), 6.5, -1.4),
           ((25.0, 14.0), (26.5, 0.8), 8, 2.2), ((20.5, 14.5), (13.5, 3.0), 8.5, -2.4), ((17.5, 16.0), (17.0, 6.0), 6, 1.2),
           ((15.5, 18.5), (3.0, 7.5), 8, 2.0), ((13.5, 22.0), (0.8, 18.0), 7, -1.4)],
    "swept": [((34.0, 19.0), (40.0, 9.0), 6.5, -1.2), ((31.0, 16.5), (31.0, 3.0), 7, 1.6), ((26.5, 15.0), (18.0, 1.2), 7.5, -2.0),
              ((21.5, 15.5), (7.0, 2.4), 8, 1.8), ((17.5, 18.0), (1.5, 9.0), 8, -1.8), ((14.5, 21.5), (0.8, 18.0), 7, 1.2)],
    "fringe": [((34.0, 19.0), (41.0, 11.0), 7, -1.0), ((30.5, 16.0), (35.5, 6.0), 7.5, 1.2), ((26.0, 14.5), (27.0, 3.6), 7.5, -1.2),
               ((21.5, 14.5), (19.0, 3.8), 7.5, 1.2), ((17.0, 16.0), (10.5, 5.5), 8, -1.2), ((14.0, 20.0), (4.5, 12.0), 8, 1.0)],
    "mohawk": [((27.5, 15.0), (34.0, 3.0), 7.5, -1.4), ((24.0, 14.0), (26.0, 0.6), 8, 1.4), ((20.5, 14.5), (17.0, 1.2), 8, -1.4),
               ((17.0, 16.0), (8.0, 3.2), 7.5, 1.2), ((31.0, 16.5), (41.0, 5.0), 7, 1.2), ((14.0, 20.0), (3.0, 12.0), 7, -1.0),
               ((34.5, 19.5), (45.0, 13.0), 6.5, -1.0)],
}
BT_BANGS = {
    "up": [((19.6, 19.0), (18.0, 22.4), 5.0), ((24.0, 19.0), (24.0, 22.8), 4.6), ((28.6, 19.0), (30.2, 22.4), 5.0)],
    "swept": [((20.4, 19.0), (17.0, 22.4), 5.0), ((26.0, 19.0), (23.6, 22.8), 4.8), ((30.0, 19.0), (28.8, 22.2), 4.4)],
    "fringe": [((17.5, 19.0), (16.0, 22.8), 5.2), ((21.5, 19.0), (20.4, 23.2), 5.0), ((25.5, 19.0), (25.4, 23.0), 5.0),
               ((29.5, 19.0), (30.4, 22.8), 5.0), ((33.0, 19.4), (34.2, 22.4), 4.4)],
    "mohawk": [((22.0, 19.0), (21.0, 22.0), 4.4), ((27.0, 19.0), (28.0, 22.0), 4.4)],
}
BT_BASE = dict(spikes="up", eyes="narrow", acc="none", mouth="smirk")
BT_CFG = dict(BT_BASE)


# ---------------------------------------------------------------- torso
BT_LCOLLAR = [(14.0, 44.6), (17.4, 39.6), (19.6, 40.0), (23.6, 48.0), (19.4, 46.0)]
BT_RCOLLAR = [(34.0, 44.6), (30.6, 39.6), (28.4, 40.0), (24.4, 48.0), (28.6, 46.0)]
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
    # collar: stand-up, lit left, gold piping
    shape(d, BT_LCOLLAR, BT_STEEL_L, col=BT_SUIT_D)
    shape(d, BT_RCOLLAR, BT_STEEL, col=BT_SUIT_D)
    d.line([P(*p) for p in (BT_LCOLLAR[0], BT_LCOLLAR[1], BT_LCOLLAR[2])], fill=WHITE, width=4)
    d.line([P(*p) for p in (BT_RCOLLAR[0], BT_RCOLLAR[1], BT_RCOLLAR[2])], fill=BT_STEEL_L, width=4)
    paste_mask(img, SK_S, both(neckm, box_mask(0, 41.5, 48, 80)))
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
    d = ImageDraw.Draw(img)
    d.ellipse(((icx - 0.55) * K, (icy - 0.5) * K, (icx + 0.55) * K, (icy + 0.7) * K), fill=INK)      # pupil
    hx, hy = icx - side * 0.75, icy - 1.0
    d.rectangle(((hx - 0.55) * K, (hy - 0.55) * K, (hx + 0.55) * K, (hy + 0.55) * K), fill=WHITE)
    d.line([P(*p) for p in up], fill=INK, width=14, joint="curve")
    if kind == "sharp":   # lid tail flick outwards
        d.line([P(outer[0], outer[1]), P(outer[0] + side * 0.9, outer[1] - 0.5)], fill=INK, width=12)
    return d


def bt_mouth(d, kind, expr):
    YOFF[0] = -2.7
    if expr == "shout":
        pts = [(20.4, 37.6), (28.4, 37.4), (27.6, 41.2), (24.4, 42.8), (21.2, 41.2)]
        poly(d, pts, INK)
        rect(d, 21.0, 37.9, 27.8, 39.7, WHITE)
        outline(d, pts, 5, col=MAROON)
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
    d.line([P(24.0, 25.4), P(24.0, 30.0)], fill=SK_L, width=7)
    d.line([P(25.0, 31.4), P(25.5, 33.0)], fill=SK_D, width=7)
    bt_mouth(d, BT_CFG["mouth"], expr)
    outline(d, FACE[1:] + FACE[:1], w=9, closed=False)
    if expr == "shout":
        o, wd = 2.2, 1.12
    elif expr == "determined":
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


def bt_spike(hd, root, tip, w, bend, sway, ph, shade=1, n=24):
    # tongues with cols: deep orange edge, lit band on the left, orange shade band on the right
    return tongue(hd, root, tip, w, bend, sway=sway, shade_side=shade, ph=ph, wave=0.05, n=n, ow=6,
                  cols=(BT_EDGE, bt_hair_col, BT_HY_D, BT_HY_L),
                  bands=[(shade, 0.3, 1.0, 0.1, 0.7, BT_HY_D), (-shade, 0.4, 1.0, 0.3, 0.85, BT_HY_L)])


def bt_hair(img, facem, s):
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    cap_pts = BT_CAP + BT_HAIRLINE[::-1]
    poly(hd, cap_pts, BT_HY)
    cap = poly_mask(cap_pts)
    sp = BT_SPIKES[BT_CFG["spikes"]]
    for i, (r, t, w, b) in enumerate(sp):
        sw = s * (3.0 + 1.0 * (i % 2)) * (-1 if r[0] > 24 else 1) * (-1 if i % 3 == 0 else 1)
        bt_spike(hd, r, t, w, b, sw, i * 0.37 + s * 0.3, shade=1 if r[0] < 24 else -1)
    # side locks over the top of each ear
    for side, (r, t) in ((-1, ((13.4, 21.0), (10.4, 30.0))), (1, ((34.6, 21.0), (37.6, 30.0)))):
        bt_spike(hd, r, t, 4.4, 0.8 * side, s * 0.5 * -side, 0.5 + s * 0.2, shade=-side, n=18)
    # crown gloss (lit, top left) and a shade band along the hairline
    gl = both(both(cap, inv(shift(cap, int(4 * F), int(5 * F)))), box_mask(0, 12, 28, 21))
    hl.paste(BT_HY_L + (255,), (0, 0), gl)
    band = both(both(cap, inv(shift(cap, 0, int(-10 * F)))), box_mask(0, 17, 48, 27))
    hl.paste(BT_HY_D + (255,), (0, 0), band)
    shd = both(both(shift(cap, 0, int(15 * F)), facem), inv(cap))
    img.paste(SK_S, (0, 0), shd)
    shd2 = both(both(shift(cap, 0, int(6 * F)), facem), inv(cap))
    img.paste(SK_D, (0, 0), shd2)
    for i, (r, t, w) in enumerate(BT_BANGS[BT_CFG["spikes"]]):
        bt_spike(hd, r, t, w, 0.6 * (1 if i % 2 else -1), s * 0.5, i + s * 0.3, shade=1 if i % 2 == 0 else -1, n=14)
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
    bt_hair(img, facem, sway)
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
            if None in ring or any(c in BT_EYECOLS for c in ring):
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
BT_ARCS = [((5, 14), [(-3, -1), (2, -3), (-3, -1), (2, -3)]), ((90, 12), [(3, -1), (-2, -3), (3, -1), (-2, -3)]),
           ((3, 38), [(-1, 3), (3, 2), (-3, 3), (3, 2), (-3, 3)]), ((93, 42), [(1, 3), (-3, 2), (3, 3), (-3, 2), (3, 3)])]


def bt_arcs(out, sway):
    """Lightning forks jumping off the head: 2 px bolts (dark teal under, light teal / white over), re-jittered per frame."""
    px = out.load()
    ph = 1 if sway >= 0 else 0
    for k, ((x, y), steps) in enumerate(BT_ARCS):
        x += ph * (1 if k % 2 else -1)
        y += ph * (k % 2)
        pts = [(x, y)]
        for j, (dx, dy) in enumerate(steps):
            sgn = -1 if ph else 1
            pts.append((pts[-1][0] + dx * sgn, pts[-1][1] + dy))
        for j in range(len(pts) - 1):
            a, b = pts[j], pts[j + 1]
            bt_line(px, out.width, out.height, (a[0] + 1, a[1]), (b[0] + 1, b[1]), BT_TEAL_D)
        for j in range(len(pts) - 1):
            bt_line(px, out.width, out.height, pts[j], pts[j + 1], BT_TEAL_L if j % 2 == 0 else WHITE)


def bt_brows(out, expr):
    """Exact pixels after the pixel art: short brows sitting just above the lids, V-tilted when determined."""
    px = out.load()
    tilt = 1 if expr == "determined" else 0
    lift = 1 if expr == "shout" else 0
    kind = BT_CFG["eyes"]
    for side in (-1, 1):
        cx = 24 + side * 4.8
        x_out = int(cx * 2 + side * (6 if kind != "sharp" else 7))
        x_in = int(cx * 2 - side * 4)
        y0 = 49 - lift - (1 if kind == "round" else 0)
        pts = []
        n = abs(x_out - x_in)
        for i in range(n + 1):
            x = x_in + (x_out - x_in) * i // n
            y = y0 + (tilt if i < n // 2 else 0) - (1 if i >= n * 0.65 else 0) * (0 if tilt else 1) - (1 if (tilt == 0 and i >= n * 0.4) else 0) * 0
            pts.append((x, y))
        for x, y in pts:
            px[x, y] = BT_BROW + (255,)
        px[x_in, y0 + 1 + tilt] = BT_BROW + (255,)


def bt_frame(sway, expr, cfg=None):
    global BT_CFG
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
    px = out.load()
    prot = {(x, y) for y in range(44, 66) for x in range(26, 72) if px[x, y] == WHITE + (255,)}
    out = cleanup(out, prot)
    out = bt_recolor_interior(out, (38, 66, 60, 82) if expr == "shout" else None)
    bt_brows(out, expr)
    bt_arcs(out, sway)
    return out


BT_FRAMES = [(-1, "calm"), (1, "calm"), (0.3, "determined"), (0.5, "shout")]

BT_VARIANTS = [
    ("A", dict(spikes="up", eyes="narrow", acc="none", mouth="smirk"),
     "Godspeed crown: seven upright lightning spikes, narrow Flint-style teal eyes, smirk"),
    ("B", dict(spikes="swept", eyes="sharp", acc="goggles", mouth="smirk"),
     "Wind-swept back spikes, sharp slanted eyes, goggles strapped on the crown"),
    ("C", dict(spikes="fringe", eyes="round", acc="plaster", mouth="grin"),
     "Short spiky fringe, big round cheerful eyes, plaster on the nose, open grin"),
    ("D", dict(spikes="mohawk", eyes="narrow", acc="headband", mouth="smirk"),
     "Tall central mohawk of spikes, maroon bolt headband, narrow eyes, smirk"),
]
BT_SHIP = "A"


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


def bolt_main():
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    anime = os.path.join(root, "assets", "title", "anime")
    flint = Image.open(os.path.join(anime, "flint_bust.png")).convert("RGBA").crop((0, 0, W, H))
    cfg = dict(next(c for k, c, _ in BT_VARIANTS if k == BT_SHIP))
    frames = [bt_frame(s, e, cfg) for s, e in BT_FRAMES]
    strip = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    strip.save(os.path.join(anime, "bolt_bust.png"))
    review = sys.argv[1] if len(sys.argv) > 1 else None
    if not review:
        return
    os.makedirs(review, exist_ok=True)
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
