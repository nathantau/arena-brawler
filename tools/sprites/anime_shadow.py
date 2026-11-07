"""Shadow (id `shadow`, hooded gangster) anime bust + Eclipse rise for the title screen, original art.

Built on Flint's code in anime_busts.py (never forked): poly / outline / smooth / masks, tongue() (hair spikes + shadow
tendrils), snap, cleanup, pixelize. Only the palette (navy-black hoodie with steel / violet rims, violet eyes), hood, torso,
hair, accessories and shading are his own. All globals are prefixed SH / sh_ so nothing Flint, Sakura or Apex uses is touched.
Outputs: assets/title/anime/shadow_bust.png (4 frames of 96 x 128: calm A, calm B, determined, shout) and
assets/title/anime/shadow_rise.png (8 frames: shadows rise and wrap round him, the hood's shadow deepens, eyes ignite, smirk).

Run: tools/sprites/.venv/bin/python tools/sprites/anime_shadow.py [review_dir] [variants]
(review_dir gets shadow_variants.png + key, shadow_bust_review.png, shadow_rise.gif; never commit those.)
"""
import math
import os
import sys
from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anime_busts as ab
from anime_busts import (INK, MAROON, YELLOW, CREAM, LIGHT_OR, ORANGE, SK, SK_L, SK_S, SK_D, WHITE, BG, K, F, SW, SH, W, H,
                         P, poly, outline, shape, smooth, poly_mask, box_mask, mask_of, shift, both, inv, paste_mask, snap,
                         cleanup, pixelize, lc, mirror_pts, ellipse_pts, tongue)

# ---- palette: his gameplay colours (ink navy, steel, violets, gold chain, skin) + ramps for hoodie, hair and violet light
HAIR = (18, 14, 32); HAIR_L = (84, 66, 140)
HD = (36, 36, 64); HM = (50, 50, 84); HL = (74, 78, 118); HR = (112, 128, 168)       # hoodie deep / body / lit / rim
VD = (62, 42, 96); VM = (104, 70, 158); VL = (168, 128, 224)                         # violet: hood inside, rim, glow
SKV1 = (158, 112, 130); SKV2 = (112, 76, 114)                                       # skin in the hood's violet shadow
SH_PAL = [SKV1, SKV2, INK, HAIR, HAIR_L, MAROON, SK, SK_L, SK_S, SK_D, CREAM, WHITE, HD, HM, HL, HR, VD, VM, VL, YELLOW, LIGHT_OR, ORANGE]
SH_SKIN = {SK, SK_L, SK_S, SK_D, MAROON, SKV1, SKV2}
SH_CLOTH = {HD, HM, HL, HR}
SH_VIO = {VD, VM, VL}
SH_HAIRS = {HAIR, HAIR_L}
SH_GOLD = {YELLOW, LIGHT_OR, ORANGE}

SHFACE0 = [(13.4, 17), (34.6, 17), (35.6, 27.5), (35.6, 31.5), (34.6, 35.2), (31.8, 39.4), (28.0, 42.2), (24, 43.0),
          (20.0, 42.2), (16.2, 39.4), (13.4, 35.2), (12.4, 31.5), (12.4, 27.5)]
SHFACE = [(24 + (x - 24) * 0.93, y) for x, y in SHFACE0]
SH_NECK = [(20.4, 35), (27.6, 35), (28.4, 46), (19.6, 46)]
SH_TORSO = [(0, 64), (0, 54), (3, 49.6), (8, 46.6), (14, 44.8), (19.4, 44.0), (24, 46.2), (28.6, 44.0), (34, 44.8), (40, 46.6),
            (45, 49.6), (48, 54), (48, 64)]
SH_HOOD_L = smooth([(24, 6.4), (17, 7.4), (11.6, 11.6), (8.2, 18.5), (6.8, 27), (7.2, 36), (8.4, 44.5)], 8)
SH_HOOD = SH_HOOD_L + mirror_pts(SH_HOOD_L[::-1])
SH_OPEN_L = smooth([(24, 14.0), (17.4, 15.0), (12.6, 19.5), (11.2, 27), (11.4, 34), (14, 40.6), (19, 44.2), (24, 45.2)], 8)
SH_OPEN = SH_OPEN_L + mirror_pts(SH_OPEN_L[::-1])

OL = (6, 6, 14)               # outline source colour: darker than INK so pixelize keeps the line against navy cloth
SH_BASE = dict(hood="up", mask=False, cap=False, hair="fringe", chain=True, hoop=False, brow=0)
SCFG = dict(SH_BASE)
SM = {}                       # rise state (empty = a static look)


# ---------------------------------------------------------------- helpers
def sh_layer():
    hl = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    return hl, ImageDraw.Draw(hl)


def sh_put(img, hl):
    img.paste(hl, (0, 0), hl.split()[3])


def sh_clamp(x):
    return max(0.0, min(1.0, x))


def sh_smooth(a, b, t):
    x = sh_clamp((t - a) / (b - a))
    return x * x * (3 - 2 * x)


def sh_light(img, m, base, lit=HL, rim=HR, deep=HD, vrim=VM, lit_w=(2.2, 3.0), deep_w=3.0):
    """The shading recipe for a cloth mass: lit upper-left band + thin steel rim, deep right band + violet rim."""
    paste_mask(img, base, m)
    paste_mask(img, deep, both(m, inv(shift(m, int(-deep_w * K), 0))))
    paste_mask(img, lit, both(m, inv(shift(m, int(lit_w[0] * K), int(lit_w[1] * K)))))
    paste_mask(img, rim, both(m, inv(shift(m, int(1.5 * K), int(1.5 * K)))))
    paste_mask(img, vrim, both(m, inv(shift(m, int(-1.6 * K), 0))))


# ---------------------------------------------------------------- shadow tendrils (rise) and halo
def sh_tcol(t):
    return HD if t < 0.7 else VD


SH_TCOLS = (lc(VD), sh_tcol, HD, VM)
# (root, tip, width, bend, delay): back set behind the figure, front set wraps over the shoulders
SH_T_BACK = [((4, 50), (0.6, 14), 7.0, -3.0, 0.0), ((44, 50), (47.4, 12), 7.0, 3.0, 0.08), ((8, 41), (2.4, 2.6), 7.4, -3.4, 0.16),
             ((40, 41), (45.6, 2.2), 7.4, 3.4, 0.24), ((12, 30), (5.0, 8.0), 5.5, 2.4, 0.32), ((36, 30), (43.0, 7.0), 5.5, -2.4, 0.4)]
SH_T_FRONT = [((-3, 64), (13.5, 47.5), 9.0, -2.8, 0.3), ((51, 64), (34.5, 47.5), 9.0, 2.8, 0.38),
              ((5, 66), (8.0, 52), 6.0, -1.6, 0.52), ((43, 66), (40.0, 52), 6.0, 1.6, 0.58)]


def sh_tendrils(img, specs, g, s):
    hl, hd = sh_layer()
    for i, (r, t, w, b, dl) in enumerate(specs):
        gi = sh_clamp((g - dl) / 0.5)
        if gi < 0.06:
            continue
        tip = (r[0] + (t[0] - r[0]) * gi, r[1] + (t[1] - r[1]) * gi)
        sw = s * (1.6 + 0.4 * (i % 3)) * (-1 if i % 2 else 1)
        tongue(hd, r, tip, w * (0.5 + 0.5 * gi), b * gi, sway=sw, shade_side=1 if i % 2 else -1, ph=i * 0.37 + s * 0.5,
               wave=0.3, n=26, ow=9, cols=SH_TCOLS,
               bands=[(-1, 0.3, 1.0, 0.04, 0.8, VM), (-1, 0.72, 1.0, 0.1, 0.5, VL)])
    sh_put(img, hl)


def sh_halo(img, g):
    """A flat violet glow rim round the hood so the black shape separates from the background."""
    if g < 0.1:
        return
    hl, hd = sh_layer()
    big = [(24 + (x - 24) * (1 + 0.16 * g), 28 + (y - 28) * (1 + 0.16 * g)) for x, y in SH_HOOD]
    poly(hd, big, VD)
    sh_put(img, hl)


# ---------------------------------------------------------------- torso + hoodie
def sh_draw_torso(img, d):
    shape(d, SH_TORSO, HM, w=9, col=OL)
    torm = poly_mask(SH_TORSO)
    sh_light(img, torm, HM, lit_w=(2.4, 3.4), deep_w=4.5)
    d = ImageDraw.Draw(img)
    # sleeve / body folds: dark crease with a lit lip, mirrored (violet-lit on the right)
    for (a, b, c) in [((6.8, 51.5), (9.2, 57.5), (10.2, 64.5)), ((2.6, 56.5), (4.6, 60.5), (5.2, 64.5))]:
        pts = smooth([a, b, c], 6)
        d.line([P(*p) for p in pts], fill=HD, width=7, joint="curve")
        d.line([P(p[0] + 0.9, p[1] - 0.2) for p in pts], fill=HL, width=4, joint="curve")
        d.line([P(48 - p[0], p[1]) for p in pts], fill=HD, width=7, joint="curve")
        d.line([P(48 - p[0] - 0.9, p[1] - 0.2) for p in pts], fill=VM, width=3, joint="curve")
    # neck-cast crease down the front (the hoodie's centre fold)
    d.line([P(24, 52), P(24.4, 58), P(24, 64.5)], fill=HD, width=5)
    return torm


def sh_hood_drape(img, d, down):
    """Hood fabric piled round the neck (up: front lobes under the chin; down: a bunched cowl behind it)."""
    lobes = [(15.2, 46.4, 6.6, 3.6), (32.8, 46.4, 6.6, 3.6)] if not down else [(14.0, 45.4, 7.6, 3.8), (34.0, 45.4, 7.6, 3.8),
                                                                              (24, 45.0, 8.0, 3.0)]
    for cx, cy, rx, ry in lobes:
        m = poly_mask(ellipse_pts(cx, cy, rx, ry, 28))
        sh_light(img, m, HM, lit_w=(1.8, 1.8), deep_w=2.4, rim=HL)
        d.line([P(*p) for p in ellipse_pts(cx, cy, rx, ry, 28)[8:20]], fill=HD, width=5, joint="curve")
    d = ImageDraw.Draw(img)
    return d


def sh_cords_chain(img, s, chain=True):
    d = ImageDraw.Draw(img)
    for sx in (-1, 1):
        x0 = 24 + sx * 3.8
        sw = s * 0.5 * sx
        pts = smooth([(x0, 45.6), (x0 + sx * 0.4 + sw * 0.4, 50), (x0 + sx * 0.2 + sw, 55.6)], 6)
        d.line([P(*p) for p in pts], fill=HR, width=7, joint="curve")
        d.line([P(p[0] - 0.4, p[1]) for p in pts], fill=CREAM, width=3, joint="curve")
        e = pts[-1]
        d.rectangle(((e[0] - 0.6) * K, (e[1] - 0.4) * K, (e[0] + 0.6) * K, (e[1] + 1.8) * K), fill=YELLOW)
    if chain:
        pts = smooth([(17.8, 45.4), (19.6, 50.6), (24 + s * 0.3, 54.4), (28.4, 50.6), (30.2, 45.4)], 8)
        d.line([P(*p) for p in pts], fill=ORANGE, width=8, joint="curve")
        d.line([P(p[0], p[1] - 0.25) for p in pts], fill=YELLOW, width=5, joint="curve")
        px, py = 24 + s * 0.4, 56.6
        dia = [(px, py - 2.0), (px + 1.7, py), (px, py + 2.0), (px - 1.7, py)]
        poly(d, dia, YELLOW)
        outline(d, dia, 4, col=lc(ORANGE))
        d.rectangle(((px - 0.9) * K, (py - 0.9) * K, (px - 0.2) * K, (py - 0.2) * K), fill=CREAM)


# ---------------------------------------------------------------- hood
def sh_draw_hood_back(img, d):
    hm = poly_mask(SH_HOOD)
    outline(d, SH_HOOD, 10, col=OL)
    sh_light(img, hm, HM, lit_w=(2.6, 3.2), deep_w=5.0)
    d = ImageDraw.Draw(img)
    # crown seam + side folds (dark crease, lit lip)
    seam = smooth([(24, 7.0), (24.6, 10.0), (24, 14.0)], 6)
    d.line([P(*p) for p in seam], fill=HD, width=6, joint="curve")
    d.line([P(p[0] - 0.8, p[1]) for p in seam], fill=HL, width=4, joint="curve")
    for sx in (-1, 1):
        f = smooth([(24 + sx * 11.4, 22), (24 + sx * 12.8, 30), (24 + sx * 12.2, 38)], 6)
        d.line([P(*p) for p in f], fill=HD, width=6, joint="curve")
        d.line([P(p[0] - sx * 0.9, p[1]) for p in f], fill=(HL if sx < 0 else VM), width=3, joint="curve")
    opm = poly_mask(SH_OPEN)
    paste_mask(img, VD, opm)                                       # violet inside of the hood
    paste_mask(img, HD, both(opm, inv(shift(opm, int(1.2 * K), int(1.6 * K)))))
    # lip: the fabric edge round the opening, lit upper left
    big = [(24 + (x - 24) * 1.075, 29.5 + (y - 29.5) * 1.07) for x, y in SH_OPEN]
    lip = both(poly_mask(big), inv(opm))
    paste_mask(img, HM, lip)
    paste_mask(img, HL, both(lip, box_mask(0, 0, 24, 36)))
    paste_mask(img, HD, both(lip, box_mask(30, 0, 48, 80)))
    return opm


# ---------------------------------------------------------------- face
def sh_eye(img, d, cx, cy, side, o, wide, ign, lid):
    """Narrow half-lidded eye: straight heavy upper lid, tall violet iris. ign 0..1 = the eye lights up (violet glow, white core)."""
    ow = 3.4 * wide
    outer = (cx + side * ow, cy - 2.2 + lid)
    inner = (cx - side * ow, cy - 0.9 + lid * 0.5)
    up = [(outer[0] + (inner[0] - outer[0]) * k / 6, outer[1] + (inner[1] - outer[1]) * k / 6) for k in range(7)]
    lo = smooth([inner, (cx - side * 1.6, cy + 0.9 + 0.55 * o), (cx + side * 0.6, cy + 1.2 + 0.65 * o), outer], 6)
    pts = up + lo
    am = poly_mask(pts)
    d.polygon([P(*p) for p in pts], fill=VL if ign >= 0.5 else CREAM)
    ic = cx + side * 0.3
    iris = both(poly_mask(ellipse_pts(ic, cy + 0.35, 2.15, 2.6, 28)), am)
    if ign >= 0.5:
        paste_mask(img, VM, both(iris, box_mask(0, 0, 48, cy + 0.2)))
        paste_mask(img, WHITE, both(poly_mask(ellipse_pts(ic, cy + 0.5, 1.05, 2.0, 24)), am))
    else:
        paste_mask(img, VM, iris)
        paste_mask(img, VD, both(iris, box_mask(0, 0, 48, cy + 0.0)))
        paste_mask(img, VL, both(iris, box_mask(0, cy + 1.7, 48, 80)))
    d = ImageDraw.Draw(img)
    if ign < 0.5:
        d.rectangle(((ic - 0.5) * K, (cy - 0.3) * K, (ic + 0.5) * K, (cy + 1.4) * K), fill=HAIR)
        d.rectangle(((ic - side * 0.2 - 0.7) * K, (cy - 1.1) * K, (ic - side * 0.2 + 0.1) * K, (cy - 0.4) * K), fill=WHITE)
    d.line([P(*p) for p in lo[len(lo) // 2:]], fill=SK_D, width=5)
    d.line([P(*p) for p in up], fill=INK, width=11)
    d.line([P(*outer), P(outer[0] + side * 1.2, outer[1] - 0.9)], fill=INK, width=8)
    return d


def sh_brow(d, cx, cy, side, lift=0.0, tilt=1.0):
    outer = (cx + side * 4.4, cy - 3.9 - lift - 0.5 * (tilt - 1))
    inner = (cx - side * 2.6, cy - 2.5 - lift + 0.5 * (tilt - 1))
    d.line([P(*outer), P(*inner)], fill=lc(HAIR), width=12)


def sh_mouth(d, expr, e=0.0):
    ab.YOFF[0] = -2.7
    if expr == "shout":
        arc = [(24 + 2.2 * math.cos(a * math.pi / 14), 38.2 + 3.0 * math.sin(a * math.pi / 14)) for a in range(15)]
        pts = [(21.8, 38.2), (26.2, 38.2)] + arc
        poly(d, pts, VD)
        d.ellipse((22.6 * K, 36.8 * K, 25.4 * K, 37.9 * K), fill=SK_D)
        ab.rect(d, 22.2, 35.5, 25.8, 36.2, CREAM)
        outline(d, pts, 4, col=lc(MAROON))
    elif e >= 0.5:      # determined: set mouth, one corner lifted
        d.line([P(*p) for p in smooth([(21.7, 39.7), (23.2, 39.6), (25.2, 39.5), (26.6, 38.9)], 6)], fill=lc(MAROON), width=8, joint="curve")
    else:               # cocky smirk, right corner up with a dimple tick
        d.line([P(*p) for p in smooth([(21.7, 39.6), (23.4, 39.9), (25.4, 39.6), (26.9, 38.5)], 6)], fill=lc(MAROON), width=8, joint="curve")
        d.line([P(27.0, 38.9), P(27.5, 38.0)], fill=lc(MAROON), width=6)
    ab.YOFF[0] = 0.0


SH_EAR_L = [(14.2, 25.6), (11.8, 26.2), (10.6, 28.2), (10.8, 30.6), (12.2, 32.4), (14.4, 32.6)]


def sh_draw_head(img, expr, s):
    """Neck + face (+ ears when the hood is down), drawn on `img` (a copy; the caller clips it to the hood opening)."""
    d = ImageDraw.Draw(img)
    facem = poly_mask(SHFACE)
    neckm = poly_mask(SH_NECK)
    torm = poly_mask(SH_TORSO)
    if SCFG["hood"] == "down":
        shape(d, SH_EAR_L, SK)
        shape(d, [(48 - x, y) for x, y in SH_EAR_L], SK_S)
        d.line([P(13.0, 27.8), P(12.1, 29.2), P(12.5, 31.0), P(13.5, 31.7)], fill=MAROON, width=5, joint="curve")
        d.line([P(48 - 13.0, 27.8), P(48 - 12.1, 29.2), P(48 - 12.5, 31.0), P(48 - 13.5, 31.7)], fill=MAROON, width=5, joint="curve")
    shape(d, SH_NECK, SK, w=5, col=lc(SK_D))
    nk = both(neckm, inv(torm))
    paste_mask(img, SK_S, both(nk, box_mask(0, 0, 48, 90)))
    jaw = both(both(shift(facem, int(1.5 * K), int(14 * F)), neckm), inv(facem))
    paste_mask(img, SK_D, jaw)
    d = ImageDraw.Draw(img)
    # cowl of fabric hides the neck base
    shape(d, SHFACE, SK, w=7, col=lc(SK_D))
    paste_mask(img, SK_L, both(facem, poly_mask([(14.4, 28.5), (21.0, 29.5), (20.2, 34.4), (17.4, 34.8), (15.0, 32.5)])))
    paste_mask(img, SK_S, both(facem, inv(shift(facem, int(-4.4 * K), 0))))
    paste_mask(img, SK_S, both(both(facem, inv(shift(facem, int(-1.5 * K), int(-1.4 * K)))), box_mask(0, 29, 48, 80)))
    paste_mask(img, SK_S, both(facem, box_mask(0, 0, 48, 21.4)))                    # hood-brim shadow on the forehead
    paste_mask(img, SK_D, both(facem, box_mask(0, 0, 48, 19.0)))
    chin = both(facem, inv(shift(facem, 0, int(-10 * F))))
    paste_mask(img, SK_S, both(chin, shift(facem, int(-30 * F), 0)))
    d = ImageDraw.Draw(img)
    d.line([P(24.0, 26.0), P(24.0, 30.4)], fill=SK_L, width=7)
    d.line([P(25.0, 31.6), P(25.6, 33.0)], fill=SK_D, width=7)
    e = SM["e"] if SM else (1.0 if expr == "determined" else 0.0)
    if SM and SM.get("sy", 0) > 0:      # the hood's shadow deepens: dark down over the brow and eyes, a soft lower edge
        sy = SM["sy"]
        wob = lambda x: 0.55 * math.sin(x * 0.9 + SM.get("ph", 0) * 6.28)
        edge = [(x, sy + wob(x)) for x in range(12, 38, 2)]
        top = [(37, 12), (11, 12)]
        poly(d, [(11.0, 12)] + edge + top, SKV1)
        edge2 = [(x, sy - 1.5 + wob(x + 2)) for x in range(12, 38, 2)]
        poly(d, [(11.0, 12)] + edge2 + top, SKV2)
    sh_mouth(d, expr, 0.0 if SM else e)
    if SCFG["mask"]:
        sh_mask(img)
        d = ImageDraw.Draw(img)
    if expr == "shout":
        o, wd, lift, tilt = 2.2, 1.15, 0.6, 1.0
    else:
        o, wd, lift, tilt = 1.6 - 1.2 * e, 1.1 - 0.05 * e, -0.2 * e, 1.0 + 1.4 * e
    if e >= 0.5 and expr != "shout":
        d.line([P(23.0, 24.5), P(23.3, 26.0)], fill=SK_D, width=5)
        d.line([P(25.0, 24.5), P(24.7, 26.0)], fill=SK_D, width=5)
    ign = SM.get("k", 0.0) if SM else 0.0
    lid = (SM.get("lid", 0.0) if SM else 0.0)
    cy = 27.8
    sh_eye(img, d, 19.2, cy, -1, o, wd, ign, lid)
    d = ImageDraw.Draw(img)
    sh_eye(img, d, 28.8, cy, 1, o, wd, ign, lid)
    d = ImageDraw.Draw(img)
    return facem, (lift, tilt)


def sh_mask(img):
    """Black bandana over the lower face: slanted top edge under the eyes, lit upper edge, knot-side fold."""
    d = ImageDraw.Draw(img)
    pts = [(12.0, 31.6), (17.5, 33.4), (24, 34.4), (30.5, 33.4), (36.0, 31.6), (35.6, 39), (31, 44.6), (24, 46.4), (17, 44.6), (12.4, 39)]
    m = poly_mask(pts)
    paste_mask(img, HM, m)
    paste_mask(img, HD, both(m, inv(shift(m, int(-3.6 * K), 0))))
    paste_mask(img, HL, both(m, inv(shift(m, int(1.2 * K), int(2.2 * K)))))
    top = smooth(pts[:5], 6)
    d.line([P(*p) for p in top], fill=HR, width=6, joint="curve")
    d.line([P(*p) for p in smooth([(16, 37), (24, 40.4), (32, 37)], 6)], fill=HD, width=5, joint="curve")
    d.line([P(*p) for p in smooth([(24, 36), (24.2, 41), (24, 45)], 6)], fill=HD, width=4, joint="curve")
    for x, y in [(19, 36.8), (29, 36.8), (24, 43.0)]:                     # small violet stitched marks
        d.rectangle(((x - 0.35) * K, (y - 0.35) * K, (x + 0.35) * K, (y + 0.35) * K), fill=VM)


# ---------------------------------------------------------------- hair, cap, accessories
SH_HAIRLINE = [(12.6, 25), (12.2, 20), (14.4, 16), (19, 14.4), (24, 14.0), (29, 14.4), (33.6, 16), (35.8, 20), (35.4, 25)]
# fringe spikes (root, tip, width, bend) hanging over the forehead, tips kept above the brows
SH_FRINGE = {
    "fringe": [((15.0, 17.5), (12.4, 23.6), 4.6, 0.8), ((18.4, 16.4), (19.8, 22.0), 4.8, -0.4), ((22.0, 16.0), (21.6, 20.4), 4.4, 0.2),
               ((25.8, 16.0), (27.6, 23.2), 5.4, -0.8), ((29.8, 16.4), (30.4, 20.8), 4.4, 0.4), ((33.4, 17.2), (35.6, 24.2), 4.8, -0.8)],
    "side": [((14.0, 17.0), (12.6, 24.0), 4.8, 0.8), ((18.0, 16.2), (22.0, 23.4), 6.4, -1.6), ((23.0, 15.8), (29.0, 24.0), 7.0, -1.8),
             ((28.0, 15.8), (34.0, 23.4), 6.4, -1.4), ((32.6, 16.4), (36.0, 21.6), 5.0, -0.8)],
}
SH_SPIKES = [((33.5, 16.0), (42.0, 9.0), 7.0, -2.6), ((30.0, 14.0), (36.0, 3.4), 7.5, -2.2), ((25.5, 12.5), (26.0, 1.4), 8.0, 0.8),
             ((20.5, 13.0), (14.5, 2.4), 8.0, 2.4), ((16.0, 15.5), (5.5, 7.0), 8.0, 3.0), ((13.0, 19.5), (3.6, 15.0), 7.0, 2.6)]


def sh_hcol(t):
    return HAIR_L if t < 0.1 else HAIR


SH_HCOLS = (lc(HAIR), sh_hcol, HAIR, HAIR_L)


def sh_hair(d, root, tip, w0, bend, sway=0.0, shade_side=-1, ph=0.0, n=20, ow=6):
    return tongue(d, root, tip, w0, bend, sway=sway, shade_side=shade_side, ph=ph, wave=0.14, n=n, ow=ow, cols=SH_HCOLS,
                  bands=[(-1, 0.1, 0.55, 0.04, 0.6, HAIR_L)])


def sh_draw_hair(img, facem, s):
    """Dark hair with violet sheen: a fringe over the forehead (hood up) or a spiky swept mop (hood down)."""
    st = SCFG["hair"]
    hl, hd = sh_layer()
    cap_pts = SH_HAIRLINE
    if SCFG["cap"]:
        return sh_draw_cap(img, facem, s)
    poly(hd, cap_pts + [(35.4, 19.5), (12.6, 19.5)], HAIR)
    if SCFG["hood"] == "down":
        for i, (r, t, w, b) in enumerate(SH_SPIKES):
            sw = s * (1.8 + 0.3 * (i % 2)) * (-1 if i < 3 else 1)
            sh_hair(hd, r, t, w, b, sway=sw, ph=i * 0.37 + s * 0.4)
        poly(hd, [(12.4, 24), (12.0, 19), (14, 14.4), (24, 11.6), (34, 14.4), (36, 19), (35.6, 24), (33.4, 22), (30, 20.5),
                  (24, 19.8), (18, 20.5), (14.6, 22)], HAIR)
        hd.line([P(*p) for p in smooth([(14.8, 17.4), (19, 14.2), (24, 13.2)], 6)], fill=HAIR_L, width=6, joint="curve")
        # side locks over the tops of the ears
        for side, (r, t) in ((-1, ((13.2, 21.0), (11.8, 26.6))), (1, ((34.8, 21.0), (36.4, 26.6)))):
            sh_hair(hd, r, t, 4.6, 1.2 * side, sway=s * 0.6 * -side, shade_side=-side, ph=0.5 + s * 0.2 * side, n=16, ow=5)
    for i, (r, t, w, b) in enumerate(SH_FRINGE["side" if st == "side" else "fringe"]):
        tt = (t[0], t[1] - (0.6 if SCFG["hood"] == "down" else 0))
        sh_hair(hd, r, tt, w, b, sway=s * (0.8 + 0.3 * (i % 2)) * (-1 if i < 3 else 1), ph=0.3 * i + s * 0.3, n=16, ow=5)
    sh_put(img, hl)


def sh_draw_cap(img, facem, s):
    """Snapback pulled low: a violet dome with panel seams, gold logo, a curved brim over the brow, hair tufts at the sides."""
    hl, hd = sh_layer()
    dome = [(12.2, 22.4), (12.0, 18), (14, 14.2), (19, 12.4), (24, 12.0), (29, 12.4), (34, 14.2), (36, 18), (35.8, 22.4)]
    poly(hd, dome + [(24, 22.8)], VM)
    outline(hd, dome, 6, closed=False, col=lc(VD))
    sh_put(img, hl)
    dm = poly_mask(dome + [(24, 22.8)])
    paste_mask(img, VD, both(dm, inv(shift(dm, int(-4.0 * K), 0))))
    paste_mask(img, VL, both(dm, inv(shift(dm, int(2.0 * K), int(2.4 * K)))))
    d = ImageDraw.Draw(img)
    d.line([P(*p) for p in smooth([(24, 12.4), (24.2, 17), (24, 21.6)], 6)], fill=VD, width=5)
    d.line([P(*p) for p in smooth([(17, 13.4), (18.4, 17.6), (18.4, 21.8)], 6)], fill=VD, width=4)
    d.line([P(*p) for p in smooth([(31, 13.4), (29.8, 17.6), (29.8, 21.8)], 6)], fill=VD, width=4)
    gem = [(22.0, 17.6), (24, 15.8), (26.0, 17.6), (24, 19.6)]
    poly(d, gem, YELLOW)
    outline(d, gem, 4, col=lc(ORANGE))
    brim = smooth([(11.4, 22.4), (17, 24.4), (24, 25.0), (31, 24.4), (36.6, 22.4)], 6)
    bot = [(x, y + 1.4) for x, y in brim]
    poly(d, brim + bot[::-1], VM)
    d.line([P(*p) for p in bot], fill=VD, width=7, joint="curve")
    d.line([P(*p) for p in brim[: len(brim) // 2]], fill=VL, width=4, joint="curve")
    # hair tufts poking out under the cap at the sides
    hl, hd = sh_layer()
    for side, (r, t) in ((-1, ((12.8, 21.5), (11.0, 28.5))), (1, ((35.2, 21.5), (37.0, 28.5)))):
        sh_hair(hd, r, t, 4.0, 1.0 * side, sway=s * 0.6 * -side, shade_side=-side, n=14, ow=5)
    sh_put(img, hl)


def sh_hoop(img):
    d = ImageDraw.Draw(img)
    d.ellipse((9.4 * K, 32.6 * K, 12.2 * K, 36.4 * K), outline=lc(ORANGE), width=7)
    d.ellipse((9.6 * K, 32.8 * K, 12.0 * K, 36.2 * K), outline=YELLOW, width=5)
    d.rectangle((10.6 * K, 31.6 * K, 11.8 * K, 33.0 * K), fill=YELLOW)


# ---------------------------------------------------------------- frame
def sh_draw_frame(sway=0.0, expr="calm"):
    img = Image.new("RGB", (SW, SH), BG)
    g = SM.get("g", 0.0) if SM else 0.0
    down = SCFG["hood"] == "down"
    sh_halo(img, g)
    if g > 0:
        sh_tendrils(img, SH_T_BACK, g, sway)
    d = ImageDraw.Draw(img)
    sh_draw_torso(img, d)
    d = ImageDraw.Draw(img)
    if not down:
        opm = sh_draw_hood_back(img, d)
        d = ImageDraw.Draw(img)
        head = img.copy()
        facem, brw = sh_draw_head(head, expr, sway)
        sh_draw_hair(head, facem, sway)
        dh = ImageDraw.Draw(head)
        sh_brows(dh, brw)
        img.paste(head, (0, 0), opm)
        d = ImageDraw.Draw(img)
        sh_hood_drape(img, d, False)
    else:
        d = sh_hood_drape(img, d, True)
        facem, brw = sh_draw_head(img, expr, sway)
        sh_draw_hair(img, facem, sway)
        d = ImageDraw.Draw(img)
        sh_brows(d, brw)
        if SCFG["hoop"]:
            sh_hoop(img)
    sh_cords_chain(img, sway, SCFG["chain"])
    if g > 0:
        sh_tendrils(img, SH_T_FRONT, g, sway)
    return img


def sh_brows(d, brw):
    lift, tilt = brw
    if SCFG["cap"]:
        return
    sh_brow(d, 19.2, 28.0, -1, lift, tilt)
    sh_brow(d, 28.8, 28.0, 1, lift, tilt)


def sh_recolor_interior(im, keeps):
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
            cnt = {"skin": sum(c in SH_SKIN for c in ring), "cloth": sum(c in SH_CLOTH for c in ring),
                   "vio": sum(c in SH_VIO for c in ring), "hair": sum(c in SH_HAIRS for c in ring),
                   "gold": sum(c in SH_GOLD for c in ring)}
            best = max(cnt, key=cnt.get)
            col = {"skin": MAROON, "cloth": HD, "vio": VD, "hair": HAIR, "gold": ORANGE}[best] if cnt[best] else HD
            ch.append((x, y, col + (255,)))
    for x, y, c in ch:
        o[x, y] = c
    return im


SH_WISPS = [((3, 44), (-1, -3)), ((92, 38), (1, -3)), ((8, 22), (-1, -3)), ((88, 12), (1, -2))]


def sh_add_wisps(out, sway):
    """1-2 px shadow motes rising off the shoulders (violet light to dark)."""
    px = out.load()
    step = 1 if sway >= 0 else 0
    for k, ((x, y), (dx, dy)) in enumerate(SH_WISPS):
        for j, col in enumerate((VL, VM, VD)):
            X, Y = x + dx * (step + j), y + dy * (step + j)
            if 0 <= X < out.width - 1 and 0 <= Y < out.height - 1 and px[X, Y][3] == 0:
                px[X, Y] = col + (255,)
                if j == 0 and k % 2 == 0 and px[X + 1, Y][3] == 0:
                    px[X + 1, Y] = VM + (255,)


def sh_eye_glow(out, ign):
    """Light streaks trailing off the ignited eyes (outward and up)."""
    if ign < 0.5:
        return
    px = out.load()
    for sgn in (-1, 1):
        ex = int((24 + sgn * 4.8) * 2)
        for i, col in enumerate((VL, VM, VD)):
            X, Y = ex + sgn * (5 + i), 56 - i
            if 0 <= X < out.width and px[X, Y][3] and px[X, Y][:3] in SH_SKIN | SH_VIO | SH_CLOTH | {HD}:
                px[X, Y] = col + (255,)


def sh_ink_edge(out):
    """Close the outer silhouette: cloth pixels touching the background become ink (violet rims stay as the far-side accent)."""
    o = out.load()
    w, h = out.size
    ch = []
    for y in range(h):
        for x in range(w):
            if o[x, y][3] and o[x, y][:3] in SH_CLOTH:
                if any(not (0 <= x + dx < w and 0 <= y + dy < h) or o[x + dx, y + dy][3] == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    if y < h - 1 and x not in (0, w - 1):
                        ch.append((x, y))
    for x, y in ch:
        o[x, y] = INK + (255,)
    return out


def sh_make_frame(sway, expr, cfg=None, st=None):
    global SCFG, SM
    SCFG = dict(SH_BASE, **(cfg or {}))
    SM = dict(st or {})
    src = sh_draw_frame(sway, expr)
    diff = ImageChops.difference(src, Image.new("RGB", src.size, BG)).convert("L").point(lambda v: 255 if v > 0 else 0)
    mask = diff.resize((W, H), Image.BOX).point(lambda v: 255 if v > 110 else 0)
    out = snap(pixelize(src, W, 64), mask, SH_PAL)
    nn = snap(src.resize((W, H), Image.NEAREST), mask, SH_PAL)
    for sgn in (-1, 1):
        ex = 24 + sgn * 4.8
        for y in range(int((27.8 - 3.6) * 2), int((27.8 + 3.7) * 2) + 1):
            for x in range(int((ex - 5.0) * 2), int((ex + 5.0) * 2) + 1):
                out.putpixel((x, y), nn.getpixel((x, y)))
    out = cleanup(out)
    out = sh_ink_edge(out)
    keeps = [(28, 48, 68, 62)] + ([(38, 66, 60, 82)] if expr == "shout" else [])
    out = sh_recolor_interior(out, keeps)
    if SM.get("k", 0) >= 0.5:
        sh_eye_glow(out, SM["k"])
    if SCFG.get("wisps", True) and not SM:
        sh_add_wisps(out, sway)
    return out


SH_FRAMES = [(-1, "calm"), (1, "calm"), (0.3, "determined"), (0.5, "shout")]

SH_VARIANTS = [
    ("A", dict(hood="up", hair="fringe", chain=True),
     "hood up (violet inside), messy black fringe, gold chain + pendant, cocky smirk: the gameplay sprite's look"),
    ("B", dict(hood="up", hair="side", mask=True, chain=True),
     "hood up + black bandana over the lower face (only the eyes show), fringe, chain"),
    ("C", dict(hood="down", hair="swept", hoop=True, chain=True),
     "hood down in a bunched cowl, wild swept-back black hair with violet sheen, gold hoop earring, chain"),
    ("D", dict(hood="up", cap=True, chain=True),
     "hood up over a violet snapback pulled low (gold gem logo, curved brim), hair tufts at the sides, chain"),
]
SH_SHIP = "A"


def sh_variants_sheet(review, flint_frame):
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
    tiles = [("Flint", flint_frame)] + [(lab, sh_make_frame(-1, "calm", cfg)) for lab, cfg, _ in SH_VARIANTS]
    for i, (label, f) in enumerate(tiles):
        big = f.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(big, (8 + i * cw, 8), big)
        tw = d.textlength(label, font=font)
        d.text((8 + i * cw + (W * S - tw) / 2, H * S + 20), label, fill=(255, 255, 255, 255), font=font)
        sheet.alpha_composite(f, (8 + i * cw + (W * S - W) // 2, H * S + 90 + 8))
    sheet.convert("RGB").save(os.path.join(review, "shadow_variants.png"))
    with open(os.path.join(review, "shadow_variants_key.txt"), "w") as fh:
        for lab, _, text in SH_VARIANTS:
            fh.write("%s: %s\n" % (lab, text))
        fh.write("shipped: %s\n" % SH_SHIP)


def shadow_main(review=None, variants_only=False):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    dst = os.path.join(root, "assets", "title", "anime")
    flint = Image.open(os.path.join(dst, "flint_bust.png")).convert("RGBA").crop((0, 0, W, H))
    if review:
        os.makedirs(review, exist_ok=True)
        sh_variants_sheet(review, flint)
    if variants_only:
        return
    ship = dict((l, c) for l, c, _ in SH_VARIANTS)[SH_SHIP]
    frames = [sh_make_frame(s, e, ship) for s, e in SH_FRAMES]
    strip = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    strip.save(os.path.join(dst, "shadow_bust.png"))
    if not review:
        return
    S = 4
    bg = (92, 112, 134, 255)
    cw = W * S + 8
    sheet = Image.new("RGBA", (cw * 5 + 8, H * S + 16), bg)
    fb = flint.resize((W * S, H * S), Image.NEAREST)
    sheet.paste(fb, (8, 8), fb)
    for i, f in enumerate(frames):
        big = f.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(big, (8 + (i + 1) * cw, 8), big)
    sheet.convert("RGB").save(os.path.join(review, "shadow_bust_review.png"))
    x1 = Image.new("RGBA", (W * 5, H), bg)
    x1.alpha_composite(flint, (0, 0))
    for i, f in enumerate(frames):
        x1.alpha_composite(f, ((i + 1) * W, 0))
    x1.convert("RGB").save(os.path.join(review, "shadow_bust_x1.png"))


def sh_state(t):
    return dict(g=sh_smooth(0.05, 0.8, t), sy=17.0 + 12.4 * sh_smooth(0.12, 0.92, t) if t > 0.05 else 0,
                k=sh_smooth(0.42, 0.62, t), e=sh_smooth(0.55, 0.95, t), lid=0.7 * math.sin(math.pi * sh_smooth(0.0, 0.7, t)) ** 0.7,
                ph=t)


SH_RISE_T = [0.0, 0.14, 0.29, 0.43, 0.57, 0.71, 0.86, 1.0]


def shadow_rise(review=None):
    """Variant A: calm -> shadows climb the sides and wrap his shoulders, the hood's shadow drops over his brow, the eyes ignite,
    a smirk. 8 frames of 96 x 128, the last one is the held look."""
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    cfg = dict((l, c) for l, c, _ in SH_VARIANTS)[SH_SHIP]
    frames = []
    for i, t in enumerate(SH_RISE_T):
        sway = (-0.8, 0.8)[i % 2] * (1 - 0.5 * t)
        st = sh_state(t) if i else None
        frames.append(sh_make_frame(sway, "calm", cfg, st) if i else sh_make_frame(-0.8, "calm", cfg))
    dst = os.path.join(root, "assets", "title", "anime")
    strip = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    strip.save(os.path.join(dst, "shadow_rise.png"))
    if not review:
        return
    bg = (92, 112, 134)
    S = 4
    gif = []
    for f in frames:
        im = Image.new("RGBA", (W * S, H * S), bg + (255,))
        im.alpha_composite(f.resize((W * S, H * S), Image.NEAREST))
        gif.append(im.convert("RGB"))
    dur = [500] + [120] * (len(gif) - 2) + [900]
    gif[0].save(os.path.join(review, "shadow_rise.gif"), save_all=True, append_images=gif[1:], duration=dur, loop=0)
    cw = W * S + 8
    sheet = Image.new("RGB", (cw * 4 + 8, (H * S + 8) * 2 + 8), bg)
    for i, f in enumerate(gif):
        sheet.paste(f, (8 + (i % 4) * cw, 8 + (i // 4) * (H * S + 8)))
    sheet.save(os.path.join(review, "shadow_rise_sheet.png"))


if __name__ == "__main__":
    rv = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "-" else None
    vo = len(sys.argv) > 2 and sys.argv[2] == "variants"
    shadow_main(rv, vo)
    if not vo:
        shadow_rise(rv)
