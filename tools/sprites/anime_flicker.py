"""Shade (id `flicker`, female shadow-ninja fighter) anime bust + power-up for the title screen, original art.

Built on Sakura's pipeline in anime_busts.py (never forked, never edited): her face / eye / brow / mouth drawing, tongue() hair
rendering, snap / cleanup / pixelize. Role-for-role recolouring is done at RUNTIME by rebinding the colour globals of the
anime_busts module in this process only (the file on disk is untouched, so Flint / Sakura output stays byte-identical when
their own scripts run). Everything of her own is prefixed F / f_: palette, long flowing hair, scarf, fox mask, headband,
gi + belt torso, smoke.
Output: assets/title/anime/flicker_bust.png (calm A, calm B, determined, shout), flicker_rise.png (8 frames).

Run: tools/sprites/.venv/bin/python tools/sprites/anime_flicker.py [review_dir]
(review_dir gets flicker_variants.png + key, flicker_bust_review.png, flicker_rise.gif; never commit those.)
"""
import math
import os
import sys
from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anime_busts as ab
from anime_busts import (INK, MAROON, YELLOW, CREAM, ORANGE, LIGHT_OR, RED, DEEP_RED, SK, SK_L, SK_S, SK_D, WHITE, BLUSH, LIP,
                         BG, K, F, SW, SH, W, H, P, poly, outline, shape, smooth, poly_mask, box_mask, mask_of, shift,
                         both, inv, paste_mask, snap, cleanup, pixelize, lc, mir, mirror_pts, ellipse_pts)

# ---------------------------------------------------------------- palette (gameplay navy hair / grey-blue gi / blue scarf / orange belt)
FH_EDGE = (30, 28, 62); FHR = (62, 66, 114); FH_D = (42, 44, 86); FH_L = (74, 94, 166); FH_HI = (152, 176, 228)
FKIM = (93, 107, 138); FKIM_S = (70, 82, 116); FKIM_D = (50, 58, 92); FKIM_L = (154, 167, 194)
FSC = (60, 111, 209); FSC_L = (120, 170, 248); FSC_D = (36, 66, 150)
FOR_D = (196, 102, 52)
FSM_L = (238, 242, 250); FSM = (194, 202, 226); FSM_D = (140, 152, 188)
FIRIS = {"ember": ((226, 128, 52), (136, 58, 44), (250, 196, 98)),
         "flash": ((252, 232, 130), (244, 176, 72), (255, 255, 255))}

# rebind Sakura's colour roles (this process only): hair H_*, cloth KIM*, iris
if not os.environ.get("F_PLAIN"):          # F_PLAIN=1: leave Sakura's colours alone (chin sheet renders her in a subprocess)
    ab.H_EDGE, ab.HR, ab.H_D, ab.H_L, ab.H_HI = FH_EDGE, FHR, FH_D, FH_L, FH_HI
    ab.KIM, ab.KIM_S, ab.KIM_D = FKIM, FKIM_S, FKIM_D
    ab.KIMS = {FKIM, FKIM_S, FKIM_D, FKIM_L}
    ab.HAIRS = {FH_EDGE, FHR, FH_D, FH_L, FH_HI}
    ab.IRISES.update(FIRIS)
    ab.LOCK_BANDS = [(-1, 0.2, 1.0, 0.1, 0.97, FH_D), (1, 0.1, 0.95, 0.04, 0.75, FH_L), (1, 0.5, 0.9, 0.06, 0.4, FH_HI)]

F_PAL = [INK, MAROON, LIP, SK, SK_L, SK_S, SK_D, BLUSH, CREAM, WHITE, FH_EDGE, FHR, FH_D, FH_L, FH_HI, FKIM, FKIM_S, FKIM_D,
         FKIM_L, FSC, FSC_L, FSC_D, ORANGE, LIGHT_OR, FOR_D, RED, DEEP_RED, YELLOW, FSM_L, FSM, FSM_D]
F_HAIRS = ab.HAIRS
F_SCARF = {FSC, FSC_L, FSC_D}
F_KIM = {FKIM, FKIM_S, FKIM_D, FKIM_L}
F_ORANGE = {ORANGE, LIGHT_OR, FOR_D}
F_MASK = {CREAM, FSM, FSM_L}

FBASE = dict(mouth="smirk", hair="long", eyes="animeB", mask="side", scarf="tail", outfit="cross", bangs="curtain", cheeks=-0.03,
             lift=0.0, wind=0.0, iris="ember", mode="open", sidelock=False)



# ---------------------------------------------------------------- female face shape (explicit, per character)
# Cheek width and chin are SEPARATE: cheek0 scales the face width below y 27 exactly as Sakura's does (Shade -0.03); the chin
# only replaces the last two points of her polygon (below y ~40): chin_w = width of the chin, chin_drop = how far the tip sits
# below y 43.0. "Pointier" means the chin tip only; the jaw corners and cheek points never move.
F_CHIN_STEPS = [(8.0, 0.0), (7.2, 0.4), (6.5, 0.8), (5.4, 1.6)]
F_CHIN_SHIP = (6.5, 0.8)
F_FACE = {"chin": F_CHIN_SHIP, "cheek0": -0.03}


def f_face_pts():
    cw, drop = F_FACE["chin"]
    f = F_FACE["cheek0"]
    base = ab.SFACE0[:6]          # ... (31.8, 39.4): everything down to the jaw corner, unchanged
    right_low = [(28.0 + (cw - 8.0) * 0.5 - 0.3, 41.9 + drop * 0.55), (24 + cw / 2 * 0.62, 42.9 + drop * 0.9), (24, 43.0 + drop)]
    left_low = [(48 - x, y) for x, y in right_low[::-1]][1:]
    left_hi = ab.SFACE0[9:]      # (20.0, 42.2) is replaced by the chin points; keep (16.2, 39.4) .. (12.4, 27.5)
    left_hi = [pt for pt in left_hi if pt[1] < 41]
    pts = base + right_low + left_low + left_hi
    return [(24 + (x - 24) * (1 + f), y) if y > 27 else (x, y) for x, y in pts]


ab.s_face_pts = f_face_pts

# ---------------------------------------------------------------- torso: gi, scarf, belt
F_NECK = [(20.2, 35), (27.8, 35), (28.6, 45), (19.4, 45)]


def f_scarf_tail(hd, root, tip, w0, bend, sway, ph=0.0):
    ab.tongue(hd, root, tip, w0, bend, sway=sway, shade_side=1, ph=ph, wave=0.1, n=26, ow=6,
              cols=(lc(INK), lambda t: FSC, FSC_D, FSC_L), bands=[(1, 0.2, 1.0, 0.06, 0.8, FSC_D), (-1, 0.5, 1.0, 0.05, 0.5, FSC_L)])


def f_draw_torso(img, d, s, cfg):
    ab.YOFF[0] = ab.STOFF
    shape(d, F_NECK, SK)
    shape(d, ab.STORSO, FKIM)
    neckm, torm = poly_mask(F_NECK), poly_mask(ab.STORSO)
    poly(d, [(28, 43.8), (34, 45.2), (43, 48.7), (47.6, 54), (47.6, 64), (40, 64), (36.5, 52)], FKIM_S)
    paste_mask(img, FKIM_L, both(both(torm, inv(shift(torm, 0, int(9 * F)))), box_mask(0, 0, 19, 80)))
    paste_mask(img, FH_HI, both(both(torm, inv(shift(torm, int(-6 * F), int(5 * F)))), box_mask(34, 0, 48, 56)))
    d = ImageDraw.Draw(img)
    for (a, b) in [((6.0, 51), (8.0, 56)), ((40.0, 51), (39.0, 56))]:
        d.line([P(*a), P(*b)], fill=FKIM_S, width=7)
        d.line([P(a[0] + 0.9, a[1] - 0.3), P(b[0] + 0.9, b[1] - 0.3)], fill=FKIM_L, width=4)
    o = cfg["outfit"]
    if o == "high":                     # a dark high collar (mesh under-armour) instead of the open V
        poly(d, [(18.4, 42.4), (29.6, 42.4), (30.4, 49.5), (23.45, 52.0), (17.6, 49.5)], FH_D)
        d.line([P(18.2, 43.0), P(17.4, 49.6), P(23.45, 52.2), P(29.5, 49.6), P(28.8, 43.0)], fill=FH_EDGE, width=6, joint="curve")
    else:
        poly(d, [(20.4, 43.0), (27.6, 43.0), (23.45, 52.0)], FH_D)               # dark under-shirt in the V
        top = [(27.7, 43.2), (24.4, 50.0), (21.0, 57.6)]
        lft = [(20.4, 43.2), (23.45, 52.0)]
        trim = FSC if o == "cross" else FKIM_D
        d.line([P(*p) for p in lft], fill=FKIM_D, width=20)
        d.line([P(*p) for p in top], fill=FKIM_D, width=22)
        d.line([P(*p) for p in top], fill=trim, width=12)
        d.line([P(*p) for p in lft], fill=FKIM_L if o != "cross" else FSC_L, width=5)
        d.line([P(27.0, 44.0), P(24.0, 50.6)], fill=FKIM_L if o != "cross" else FSC_L, width=4)
        d.line([P(*p) for p in [(29.4, 44.4), (26.0, 51.6), (22.6, 58.0)]], fill=FKIM_D, width=6)
    paste_mask(img, SK_S, both(neckm, box_mask(0, 41.5, 48, 44.6)))
    d = ImageDraw.Draw(img)
    # belt (orange, fold line, tie ends)
    poly(d, [(0, 58.6), (48, 58.6), (48, 66), (0, 66)], ORANGE)
    d.line([P(0, 58.6), P(48, 58.6)], fill=FOR_D, width=8)
    d.line([P(0, 59.4), P(48, 59.4)], fill=LIGHT_OR, width=5)
    d.line([P(0, 62.6), P(48, 62.6)], fill=FOR_D, width=5)
    for (a, b) in (((12.6, 59.8), (10.6, 66)), ((35.8, 59.8), (38.2, 66))):
        d.line([P(*a), P(*b)], fill=FOR_D, width=7)
        d.line([P(a[0] + 0.9, a[1]), P(b[0] + 0.9, b[1])], fill=LIGHT_OR, width=4)
    ab.YOFF[0] = 0.0
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    ab.YOFF[0] = ab.STOFF
    sc = cfg["scarf"]
    ls = s * 1.2 + cfg["lift"] * 3.0 + cfg["wind"] * 2.0
    if sc in ("tail", "long"):          # tails hanging over her viewer-left shoulder (long: whipping out the other side too)
        f_scarf_tail(hd, (19.0, 47.0), (11.0, 62.0), 5.2, 1.6, ls, 0.2)
        f_scarf_tail(hd, (20.6, 47.6), (17.0, 64.0), 4.2, -1.2, ls * 1.3, 0.7)
        if sc == "long":
            f_scarf_tail(hd, (28.0, 47.0), (42.0, 58.0 - cfg["lift"] * 8), 4.6, -2.0, ls * 1.5 + 2.0, 0.4)
    elif sc == "short":
        f_scarf_tail(hd, (28.0, 47.0), (35.0, 60.0), 4.6, -1.4, ls, 0.3)
    # the band round the neck, a cowl with a shadow under the chin
    band = [(16.4, 44.0), (20.4, 44.8), (24, 45.2), (27.6, 44.8), (31.6, 44.0), (33.6, 47.6), (29, 50.2), (24, 51.0),
            (19, 50.2), (14.4, 47.6)]
    ab.poly(hd, band, FSC)
    ab.outline(hd, band, w=6, col=lc(INK))
    hd.line([P(*p) for p in [(15.6, 47.4), (19.4, 50.0), (24, 50.8)]], fill=FSC_D, width=5)
    hd.line([P(*p) for p in [(24, 50.8), (28.6, 50.0), (32.4, 47.4)]], fill=FSC_D, width=10)
    hd.line([P(*p) for p in [(16.8, 45.4), (21, 46.4)]], fill=FSC_L, width=6)
    hd.line([P(*p) for p in [(20, 48.6), (23, 49.2)]], fill=FSC_L, width=4)
    ab.YOFF[0] = 0.0
    img.paste(hl, (0, 0), hl.split()[3])
    return neckm, torm


# ---------------------------------------------------------------- hair
F_BACKS = {"flow": [(24, 9.8), (16.5, 10.8), (11.0, 15.5), (7.6, 22), (5.6, 32), (4.2, 42), (3.4, 52), (3.6, 62)],
           "head": ab.BACKS["head"]}
# locks: (root, tip, width, bend), left side then right side (own lists so the two sides are not mirror twins)
F_LOCKS = {
    "long": ([((16.5, 13.5), (3.4, 62.0), 10.0, 2.8), ((18.0, 14.0), (8.6, 63.0), 8.0, -2.2), ((19.5, 14.5), (13.6, 60.0), 6.0, 2.0)],
             [((31.5, 13.5), (44.6, 60.0), 10.0, -2.6), ((30.0, 14.0), (39.6, 63.0), 8.0, 2.4), ((28.5, 14.5), (34.8, 59.0), 6.0, -2.0)]),
    "halfup": ([((16.5, 13.5), (4.0, 60.0), 9.0, 2.8), ((18.0, 14.0), (10.0, 62.0), 7.0, -2.2)],
               [((31.5, 13.5), (44.0, 59.0), 9.0, -2.6), ((30.0, 14.0), (38.0, 62.0), 7.0, 2.4)]),
    "pony": ([((15.0, 17.0), (8.4, 55.0), 6.0, 1.8)], [((33.0, 17.0), (39.4, 55.0), 6.0, -1.8)]),
    "wind": ([((16.5, 13.5), (6.0, 61.0), 10.0, 2.4), ((18.0, 14.0), (12.0, 63.0), 8.0, -2.0), ((19.5, 14.5), (16.4, 60.0), 6.0, 1.8)],
             [((31.5, 13.5), (47.0, 54.0), 10.0, -3.4), ((30.0, 14.0), (43.0, 60.0), 8.0, 2.6), ((28.5, 14.5), (38.0, 58.0), 6.0, -2.0)]),
}
F_BANGS = {
    "curtain": [((15.0, 17.5), (12.6, 23.8), 7.0, 1.0), ((18.4, 17.0), (15.6, 23.6), 7.0, 0.9), ((21.6, 16.8), (19.6, 22.2), 6.5, 0.7),
                ((26.4, 16.8), (28.4, 22.2), 6.5, -0.7), ((29.6, 17.0), (32.4, 23.6), 7.0, -0.9), ((33.0, 17.5), (35.4, 23.8), 7.0, -1.0)],
    "side": ab.SBANG_SETS["side"],
    "blunt": ab.SBANG_SETS["blunt"],
}



def f_curtain(hd, side, s, cfg, top=(14.0, 22.0), outer=((9.8, 28.0), (8.0, 38.0), (6.8, 50.0), (6.0, 61.0)), inner=((16.0, 60.0), (14.0, 48.0), (13.2, 36.0)),
              flow=1.0, depth=64.0):
    """One broad curtain of hair down a side of her face over the shoulder: wavy outer edge that flows with s / lift / wind,
    a lit band left, a shade band right, strand streaks, three tapered tips."""
    lift, wind = cfg["lift"], cfg["wind"]
    sw = s * 2.2 + wind * 3.0 + side * lift * 2.2

    def X(x):
        return 24 + side * (24 - x)          # side -1 = left (as drawn), +1 = mirrored right

    def flowx(i, n, y):
        t = (y - 22) / 40.0
        return sw * t * t * flow + side * lift * 3.0 * t * t * flow + 0.7 * math.sin(y * 0.33 + (0.6 if side > 0 else 0.0))
    o = [(top[0] + 0.0, top[1])] + [(x, y) for x, y in outer]
    o = smooth(o, 7)
    o = [(X(x) + flowx(0, 0, y) * 1.0, y - lift * 3.0 * ((y - 22) / 40.0) ** 2 * 6) for x, y in o]
    tips_y = depth
    ipts = [(X(x) + flowx(0, 0, y) * 0.6, y) for x, y in inner]
    # three tips along the bottom, tapering: outer tip, middle, inner
    ox, oy = o[-1]
    ix, iy = ipts[0]
    bot = [(ox, oy), (ox + (ix - ox) * 0.22 + side * 0.4, tips_y + 0.5), (ox + (ix - ox) * 0.42, tips_y - 2.5),
           (ox + (ix - ox) * 0.62, tips_y + 1.0), (ox + (ix - ox) * 0.82, tips_y - 3.0), (ix, iy)]
    pts = o + bot[1:] + ipts[1:] + [(X(12.4), 28.0), (X(14.0), 18.0)]
    poly(hd, pts, FHR)
    m = mask_of(lambda mm: mm.polygon([P(*p) for p in pts], fill=255))
    ab.outline(hd, o + bot[1:] + ipts[1:], w=6, closed=False, col=lc(FH_EDGE))
    # strand streaks between outer and inner edges
    n = min(len(o), 12)
    for f, col, wd, a0, a1 in ((0.3, FH_L, 14, 0.04, 0.9), (0.56, FH_D, 8, 0.1, 0.95), (0.8, FH_D, 10, 0.2, 1.0), (0.22, FH_HI, 7, 0.06, 0.55)):
        line = []
        for k in range(len(o)):
            ik = min(len(ipts) - 1, int(k * len(ipts) / len(o)))
            ox_, oy_ = o[k]
            ix_, iy_ = ipts[ik][0] + 0.0, o[k][1]
            line.append((ox_ + (X(15.0 - 0.8 * (oy_ - 22) / 40) + flowx(0, 0, oy_) * 0.3 - ox_) * f, oy_))
        sel = line[int(a0 * len(line)):int(a1 * len(line))]
        if len(sel) > 1:
            hd.line([P(*p) for p in sel], fill=col, width=wd, joint="curve")
    return o


def f_locks(hd, s, cfg, name):
    lt, rt = F_LOCKS[name]
    lift, wind = cfg["lift"], cfg["wind"]
    for side, specs in ((-1, lt), (1, rt)):
        for i, (r, t, w, b) in enumerate(specs):
            t = (t[0] + side * lift * 7.0 + wind * 4.0, t[1] - lift * 20.0 * (0.8 + 0.1 * i))
            sw = s * (1.4 + 0.3 * i) + lift * side * 1.5
            ab.hair(hd, r, t, w, b * (1 + lift * 0.5), sway=sw, ph=i * 0.37 + (0.3 if side > 0 else 0) + s * 0.2, n=40, wave=0.2,
                    bands=ab.LOCK_BANDS)


def f_back_hair(img, s, cfg):
    if cfg["hair"] in ("long", "halfup", "wind"):
        ab.s_back_hair(img, s, F_BACKS["flow"], k=0.0)
    else:
        ab.s_back_hair(img, s, F_BACKS["head"], k=0.0)


def f_hair_under(img, s, cfg):
    st = cfg["hair"]
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    lift, wind = cfg["lift"], cfg["wind"]
    if st == "pony":
        # a long high ponytail streaming out to her left (viewer right) with a blue tie
        for i, (r, t, w, b) in enumerate([((30.0, 11.5), (46.0, 44.0 - lift * 14), 17.0, -3.0), ((29.0, 12.0), (41.0, 58.0), 12.0, 2.8),
                                          ((28.0, 12.5), (36.0, 52.0), 8.0, -2.0)]):
            ab.hair(hd, r, (t[0] + wind * 3, t[1]), w, b, sway=s * (1.6 + 0.4 * i) + lift * 3, ph=0.3 + i * 0.4 + s * 0.2, n=40, wave=0.2,
                    bands=ab.LOCK_BANDS)
        f_curtain(hd, -1, s, cfg, outer=((10.0, 28.0), (8.4, 36.0), (8.0, 44.0), (8.6, 52.0)), depth=53.0, inner=((15.4, 51.0), (14.0, 44.0), (13.2, 36.0)))
        f_curtain(hd, 1, s, cfg, outer=((10.0, 28.0), (8.4, 36.0), (8.0, 44.0), (8.6, 52.0)), depth=53.0, inner=((15.4, 51.0), (14.0, 44.0), (13.2, 36.0)))
    elif st == "halfup":
        f_curtain(hd, -1, s, cfg)
        f_curtain(hd, 1, s, cfg, outer=((9.8, 28.0), (8.2, 38.0), (7.2, 50.0), (6.6, 61.0)))
        ab.bun(hl, hd, 24.0, 8.2, 4.4)
        for a, b in (((18.6, 5.4), (30.6, 11.4)), ((19.6, 11.6), (29.6, 4.8))):          # two steel pins crossed through the knot
            hd.line([P(*a), P(*b)], fill=lc(INK), width=7)
            hd.line([P(*a), P(*b)], fill=FKIM_L, width=4)
    elif st == "wind":
        f_curtain(hd, -1, s, cfg, outer=((9.8, 28.0), (8.0, 38.0), (7.6, 50.0), (8.2, 61.0)), flow=0.8)
        f_curtain(hd, 1, s, cfg, outer=((9.8, 28.0), (7.4, 38.0), (4.4, 48.0), (1.6, 58.0)), flow=1.6)
    else:
        f_curtain(hd, -1, s, cfg)
        f_curtain(hd, 1, s, cfg, outer=((9.8, 28.0), (8.2, 38.0), (7.2, 50.0), (6.6, 61.0)))
    img.paste(hl, (0, 0), hl.split()[3])


def f_hair_front(img, facem, s, cfg):
    st = cfg["hair"]
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    cap_pts = ab.SCAP_TOP + ab.SHAIRLINE[::-1]
    poly(hd, cap_pts, FHR)
    ab.outline(hd, ab.SCAP_TOP[1:-1], w=6, closed=False, col=lc(FH_EDGE))
    cap = poly_mask(cap_pts)
    hl.paste(FH_D + (255,), (0, 0), both(cap, poly_mask([(31.4, 11), (37, 16), (37, 24), (33.4, 22), (32.2, 15)])))
    ring_t = smooth([(14.4, 19.4), (18, 16.2), (24, 14.6), (30, 16.2), (33.4, 19.2)], 8)
    ring_b = [(x, y + 2.2 - 0.8 * abs(x - 24) / 10) for x, y in ring_t]
    poly(hd, ring_t + ring_b[::-1], FH_L)
    core_t = smooth([(15.4, 18.6), (18.8, 15.9), (23.4, 14.9)], 8)
    poly(hd, core_t + [(x, y + 1.3) for x, y in core_t][::-1], FH_HI)
    shd = both(both(shift(cap, 0, int(15 * F)), facem), inv(cap))
    img.paste(SK_S, (0, 0), shd)
    shd2 = both(both(shift(cap, 0, int(6 * F)), facem), inv(cap))
    img.paste(SK_D, (0, 0), shd2)
    bangs = F_BANGS[cfg["bangs"]]
    for i, (r, t, w, b) in enumerate(bangs):
        ab.hair(hd, r, t, w, b, sway=s * 0.5, ow=5, ph=i * 0.6 + s * 0.2, n=16)
        dx, dy = t[0] - r[0], t[1] - r[1]
        ln = math.hypot(dx, dy)
        tx_, ty_ = t[0] + s * 0.5 - dx / ln * 1.1, t[1] - dy / ln * 1.1
        hd.ellipse(((tx_ - 1.2) * K, (ty_ - 1.1) * K, (tx_ + 1.2) * K, (ty_ + 1.1) * K), fill=FHR, outline=lc(FH_EDGE), width=5)
    if cfg["mask"] == "headband":
        band = [(12.4, 19.2), (24, 17.8), (35.6, 19.2), (35.6, 22.0), (24, 20.8), (12.4, 22.0)]
        poly(hd, band, FSC)
        ab.outline(hd, band, w=5, col=lc(INK))
        hd.line([P(13, 21.2), P(24, 20.0), P(35, 21.2)], fill=FSC_D, width=6, joint="curve")
        hd.line([P(13, 19.8), P(24, 18.6), P(35, 19.8)], fill=FSC_L, width=5, joint="curve")
        plate = [(19.6, 18.4), (28.4, 18.4), (28.4, 22.6), (19.6, 22.6)]
        poly(hd, plate, FKIM_L)
        ab.outline(hd, plate, w=5, col=lc(INK))
        hd.line([P(19.6, 22.0), P(28.4, 22.0)], fill=FKIM_S, width=8)
        d2 = [(24.0, 19.2), (25.4, 19.8), (24.8, 21.2), (23.2, 20.8), (23.8, 19.8)]
        hd.line([P(*p) for p in d2], fill=FKIM_D, width=5, joint="curve")
    if cfg["sidelock"]:
        tipy = 50.0 if st in ("long", "halfup", "wind") else 46.0
        for side, (r, t) in ((-1, ((13.4, 21.0), (9.6, tipy))), (1, ((34.6, 21.0), (38.4, tipy)))):
            ab.hair(hd, r, (t[0] + cfg["wind"] * 2 + side * cfg["lift"] * 2.0, t[1] - cfg["lift"] * 8), 5.0, 1.6 * side,
                    sway=s * 0.8 + cfg["lift"] * side, ph=0.5 + s * 0.2 * side, ow=5, n=26)
    if st == "pony":
        ab.tie(hd, 30.4, 12.4, 1.9, 1.3)
        hd.ellipse((29.0 * K, 11.4 * K, 31.8 * K, 13.4 * K), fill=FSC, outline=lc(INK), width=5)
    img.paste(hl, (0, 0), hl.split()[3])


def f_mask(img, cfg, s):
    """A white kitsune half-mask pushed up on the side of her head (red ear insides, whisker marks, narrow eye slit)."""
    kind = cfg["mask"]
    if kind not in ("side", "top"):
        return
    cx, cy, sc, rot = (9.4, 16.4, 1.5, -20) if kind == "side" else (38.6, 15.4, 1.4, 22)
    flip = 1 if kind == "side" else -1
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)

    def T(pts):
        a = math.radians(rot)
        return [(cx + sc * (flip * x * math.cos(a) - y * math.sin(a)), cy + sc * (flip * x * math.sin(a) + y * math.cos(a))) for x, y in pts]
    face = [(-3.0, -1.4), (-2.9, -5.4), (-1.0, -2.8), (1.0, -2.8), (2.9, -5.4), (3.0, -1.4), (2.5, 1.4), (1.0, 3.6), (0, 4.2), (-1.0, 3.6), (-2.5, 1.4)]
    ab.poly(hd, T(face), CREAM)
    hl_mask = mask_of(lambda m: m.polygon([P(*p) for p in T(face)], fill=255))
    sh = both(hl_mask, inv(shift(hl_mask, int(-0.9 * K), int(-0.6 * K))))
    hl.paste(FSM + (255,), (0, 0), sh)
    ab.outline(hd, T(face), w=6, col=lc(INK))
    ab.poly(hd, T([(-2.5, -4.2), (-1.7, -2.8), (-2.7, -2.4)]), RED)
    ab.poly(hd, T([(2.5, -4.2), (1.7, -2.8), (2.7, -2.4)]), RED)
    for a, b in (((-2.7, 0.2), (-1.3, 0.9)), ((2.7, 0.2), (1.3, 0.9)), ((-2.4, 1.6), (-1.1, 2.0)), ((2.4, 1.6), (1.1, 2.0))):
        hd.line([P(*p) for p in T([a, b])], fill=RED, width=9)
    hd.line([P(*p) for p in T([(-2.0, -1.0), (-0.5, -0.5)])], fill=lc(FH_EDGE), width=9)
    hd.line([P(*p) for p in T([(2.0, -1.0), (0.5, -0.5)])], fill=lc(FH_EDGE), width=9)
    ab.poly(hd, T([(-0.5, 3.0), (0.5, 3.0), (0, 3.9)]), DEEP_RED)
    img.paste(hl, (0, 0), hl.split()[3])


# ---------------------------------------------------------------- eyes for the rise (closed / flash)
def f_eye_closed(img, d, cx, cy, side, o, wide=1.0):
    ow = 3.4
    arc = smooth([(cx - side * ow, cy + 0.4), (cx - side * ow * 0.3, cy + 1.2), (cx + side * ow * 0.45, cy + 1.2),
                  (cx + side * ow, cy + 0.2)], 6)
    d.line([P(*p) for p in arc], fill=INK, width=11, joint="curve")
    d.line([P(cx + side * ow, cy + 0.2), P(cx + side * (ow + 1.2), cy - 0.5)], fill=INK, width=8)
    return d



# ---------------------------------------------------------------- her own mouth (patched over Sakura's s_mouth while drawing)
F_MOUTH = ["smirk"]
F_ORIG_MOUTH = ab.s_mouth


def f_mouth(d, kind):
    if kind == "shout":
        return F_ORIG_MOUTH(d, kind)
    m = F_MOUTH[0]
    det = 0.5 if kind == "determined" else 0.0
    ab.YOFF[0] = -2.7
    col = lc(LIP)

    def line(pts, w=12):
        d.line([P(*p) for p in smooth(pts, 6)], fill=col, width=w, joint="curve")
    if m == "smirk":        # A: cool one-sided smirk, right corner high, tiny dimple tick
        line([(21.9, 39.9), (23.4, 40.0), (25.0, 39.5), (26.2, 38.6), (26.7, 38.0 - det)])
        d.line([P(23.4, 41.0), P(25.2, 40.8)], fill=BLUSH, width=6)
        d.rectangle((26.9 * K, (38.9 - det) * K - 2, 27.3 * K, (39.5 - det) * K), fill=SK_S)
    elif m == "serious":    # B: short neutral line, one corner turned down
        line([(21.9, 39.7), (23.2, 39.9), (24.8, 39.9), (25.9, 40.1), (26.3, 40.7 - det)])
        d.line([P(23.0, 40.9), P(24.6, 40.9)], fill=BLUSH, width=5)
    elif m == "full":       # C: fuller lips, upper line + a soft lower lip with a highlight
        line([(21.9, 39.3), (23.0, 39.6), (24.0, 39.3), (25.0, 39.6), (26.1, 39.2 - det)])
        d.ellipse((22.6 * K, 40.0 * K, 25.6 * K, 41.3 * K), fill=BLUSH)
        d.line([P(23.4, 40.35), P(24.4, 40.35)], fill=SK_L, width=5)
    else:                   # D: playful small smile with a tiny fang
        line([(22.2, 39.2), (23.2, 39.9), (24.4, 40.0), (25.4, 39.6), (26.0, 38.8 - det)])
        d.rectangle((22.95 * K, 39.45 * K, 23.45 * K, 40.5 * K), fill=CREAM)
        d.line([P(23.4, 41.0), P(25.0, 40.9)], fill=BLUSH, width=5)
    ab.YOFF[0] = 0.0


F_MOUTHS = [("A", "smirk", "A: cool one-sided smirk (mysterious)"), ("B", "serious", "B: small neutral line, one corner turned down (serious)"),
            ("C", "full", "C: fuller lips with a soft lower-lip highlight (calm, attractive)"),
            ("D", "fang", "D: playful small smile with a tiny fang")]


def f_draw_frame(sway, expr, cfg):
    img = Image.new("RGB", (SW, SH), BG)
    f_back_hair(img, sway, cfg)
    d = ImageDraw.Draw(img)
    neckm, torm = f_draw_torso(img, d, sway, cfg)
    f_hair_under(img, sway, cfg)
    orig = ab.s_eye
    ab.s_mouth = f_mouth
    if cfg["mode"] == "closed":
        ab.s_eye = f_eye_closed
    try:
        facem = ab.s_draw_face(img, neckm, torm, expr)
    finally:
        ab.s_eye = orig
        ab.s_mouth = F_ORIG_MOUTH
    f_hair_front(img, facem, sway, cfg)
    f_mask(img, cfg, sway)
    return img


def f_recolor_interior(im, keep=None):
    """Near-black ink stays on the silhouette and lids; interior ink becomes the area's own dark tone."""
    o = im.load()
    w, h = im.size
    eye_cols = set(ab.IRISES[ab.SCFG["iris"]]) | {WHITE}

    def get(x, y):
        return o[x, y] if 0 <= x < w and 0 <= y < h else (0, 0, 0, 0)
    ch = []
    for y in range(h):
        for x in range(w):
            if o[x, y][:3] != INK or o[x, y][3] == 0 or (keep and keep[0] <= x <= keep[2] and keep[1] <= y <= keep[3]):
                continue
            ring = [get(x + dx, y + dy)[:3] if get(x + dx, y + dy)[3] else None for dx in range(-2, 3) for dy in range(-2, 3)]
            if None in ring or any(c in eye_cols for c in ring):
                continue
            cnt = {"sc": 0, "kim": 0, "or": 0, "hair": 0, "red": 0, "mask": 0}
            for c in ring:
                cnt["sc"] += c in F_SCARF
                cnt["kim"] += c in F_KIM
                cnt["or"] += c in F_ORANGE
                cnt["hair"] += c in F_HAIRS
                cnt["red"] += c in (RED, DEEP_RED)
                cnt["mask"] += c in F_MASK
            best = max(cnt, key=cnt.get)
            if cnt[best] <= len(ring) / 3:
                best = "skin"
            col = {"sc": FSC_D, "kim": FKIM_D, "or": FOR_D, "hair": FH_EDGE, "red": DEEP_RED, "mask": FSM_D, "skin": SK_D}[best]
            ch.append((x, y, col + (255,)))
    for x, y, c in ch:
        o[x, y] = c
    return im


def f_flash(out):
    """Eyes blaze: light streaks sweep out from the outer corners and a star glints on each."""
    px = out.load()
    for sgn in (-1, 1):
        ex = int((24 + sgn * 4.8) * 2 + sgn * 6)
        ey = int(27.8 * 2) - 1
        for k, col in ((0, WHITE), (1, YELLOW), (2, YELLOW), (3, LIGHT_OR), (4, LIGHT_OR)):
            x, y = ex + sgn * k, ey - (k + 1) // 2
            if 0 <= x < out.width and 0 <= y < out.height and px[x, y][3] == 0 or (0 <= x < out.width and px[x, y][:3] in F_HAIRS):
                px[x, y] = col + (255,)


def make_frame(sway, expr, cfg=None, extra=None):
    cfg = dict(FBASE, **(cfg or {}))
    ab.SCFG = dict(ab.SDEFAULT, eyes=cfg["eyes"], iris=cfg["iris"] if cfg["mode"] != "flash" else "flash", hair="long",
                   cheeks=cfg["cheeks"], shade=1)
    F_MOUTH[0] = cfg["mouth"]
    F_FACE["cheek0"] = cfg["cheeks"]
    F_FACE["chin"] = cfg.get("chin", F_CHIN_SHIP)
    src = f_draw_frame(sway, expr, cfg)
    diff = ImageChops.difference(src, Image.new("RGB", src.size, BG)).convert("L").point(lambda v: 255 if v > 0 else 0)
    mask = diff.resize((W, H), Image.BOX).point(lambda v: 255 if v > 110 else 0)
    art = pixelize(src, W, 40)
    pal = F_PAL + list(ab.IRISES[ab.SCFG["iris"]])
    out = snap(art, mask, pal)
    nn = snap(src.resize((W, H), Image.NEAREST), mask, pal)
    E = ab.EYES[ab.SCFG["eyes"]]
    for sgn in (-1, 1):
        ex = 24 + sgn * E["gap"] / 2
        for y in range(int((E["cy"] - 3.6) * 2), int((E["cy"] + 3.7) * 2) + 1):
            for x in range(int((ex - 5.0) * 2), int((ex + 5.0) * 2) + 1):
                out.putpixel((x, y), nn.getpixel((x, y)))
    px = out.load()
    prot = {(x, y) for y in range(44, 66) for x in range(26, 72) if px[x, y] == WHITE + (255,)}
    out = cleanup(out, prot)
    out = f_recolor_interior(out, (40, 68, 56, 80) if expr == "shout" else None)
    if cfg["mode"] != "closed":
        ab.add_brows(out)
    else:
        ab.add_brows(out)
    if cfg["mode"] == "flash":
        f_flash(out)
    return out


# ---------------------------------------------------------------- smoke (pixel space)
def f_shift(m, dx, dy):
    r = Image.new("L", m.size, 0)
    r.paste(m, (dx, dy))
    return r


def f_smoke(circles, lit=2):
    """Union of discs shaded as one cloud: lit crescent top left, shadow crescent bottom right."""
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for cx, cy, r in circles:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    m = m.point(lambda v: 255 if v > 127 else 0)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(FSM + (255,), (0, 0), m)
    out.paste(FSM_D + (255,), (0, 0), both(m, inv(f_shift(m, -lit, -lit))))
    out.paste(FSM_L + (255,), (0, 0), both(m, inv(f_shift(m, lit, lit))))
    return out


def f_ring(n, rx, ry, r, a0, cy=100, cx=48, jitter=True):
    """Puffs on an ellipse round her body; returns (back, front) disc lists (front = lower half, in front of her)."""
    back, front = [], []
    for i in range(n):
        a = a0 + 2 * math.pi * i / n
        rr = r * (1 + (0.25 if jitter and i % 2 else -0.1))
        x0, y0 = cx + rx * math.cos(a), cy + ry * math.sin(a)
        cl = [(x0, y0, rr), (x0 - rr * 0.8, y0 + rr * 0.3, rr * 0.7), (x0 + rr * 0.85, y0 + rr * 0.35, rr * 0.65),
              (x0 + rr * 0.1, y0 - rr * 0.65, rr * 0.62), (x0 + rr * 1.5, y0 - rr * 0.1, rr * 0.4)]
        (front if math.sin(a) > 0.0 else back).extend(cl)
    return back, front


def f_with_smoke(frame, back, front):
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    if back:
        out.alpha_composite(f_smoke(back))
    out.alpha_composite(frame)
    if front:
        out.alpha_composite(f_smoke(front))
    return out


F_BUST = [(-1, "calm"), (1, "calm"), (0.2, "determined"), (0.5, "shout")]

# ---------------------------------------------------------------- variants (same base, four different looks)
F_VARIANTS = [
    ("A", dict(hair="long", bangs="curtain", mask="side", scarf="tail", outfit="cross", eyes="animeB"),
     "A: long straight hair + curtain bangs, fox mask pushed up on the left temple, blue scarf tails over the shoulder, gi with blue cross collar, soft eyes (B)"),
    ("B", dict(hair="pony", bangs="side", mask="top", scarf="long", outfit="vneck", eyes="animeD", sidelock=False),
     "B: long windswept high ponytail with face-framing locks, fox mask on the right temple, long streaming scarf, plain gi V collar, sharper cat-eye (D)"),
    ("C", dict(hair="halfup", bangs="blunt", mask="none", scarf="short", outfit="high", eyes="animeC"),
     "C: half-up knot with crossed steel pins and long hair down, no mask, short scarf, dark high-collar mesh under-armour, gentle eyes (C)"),
    ("D", dict(hair="wind", bangs="side", mask="headband", scarf="tail", outfit="cross", eyes="animeA", wind=0.4),
     "D: long hair blown to one side, blue forehead protector with steel plate, scarf tails, tall round eyes (A)"),
]


def f_variants_sheet(review, flint_frame, name="flicker_variants", items=None):
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
    items = items or F_VARIANTS
    tiles = [("Flint", flint_frame)] + [(lab, make_frame(-1, "calm", cfg)) for lab, cfg, _ in items]
    for i, (label, f) in enumerate(tiles):
        big = f.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(big, (8 + i * cw, 8), big)
        tw = d.textlength(label, font=font)
        d.text((8 + i * cw + (W * S - tw) / 2, H * S + 20), label, fill=(255, 255, 255, 255), font=font)
        sheet.alpha_composite(f, (8 + i * cw + (W * S - W) // 2, H * S + 90 + 8))
    sheet.convert("RGB").save(os.path.join(review, name + ".png"))
    with open(os.path.join(review, name + "_key.txt"), "w") as fh:
        fh.write("Flint = reference (far left)\n")
        for lab, cfg, text in items:
            fh.write(text + "\n")


# ---------------------------------------------------------------- shipped look
F_SHIP = dict(F_VARIANTS[0][1])
F_SHIP_NAME = "A"


def f_bust_frames():
    return [make_frame(s, e, F_SHIP) for s, e in F_BUST]


# rise: (sway, expr, cfg mods, smoke ring params or None)
# ring = (n, rx, ry, r, angle, cy)
F_RISE = [
    (-0.6, "calm", dict(), (3, 44, 8, 3.0, 0.4, 118)),
    (-0.2, "calm", dict(mode="closed", lift=0.05), (5, 44, 22, 4.5, 0.9, 100)),
    (0.4, "calm", dict(mode="closed", lift=0.3), (7, 36, 22, 5.5, 1.7, 98)),
    (1.2, "calm", dict(mode="closed", lift=0.6), (8, 28, 20, 6.5, 2.6, 96)),
    (-1.6, "determined", dict(mode="flash", lift=1.0, scarf="long"), (9, 44, 26, 7.5, 3.4, 96)),
    (1.4, "determined", dict(mode="flash", lift=0.7, scarf="long"), (8, 52, 30, 6.0, 4.0, 96)),
    (-0.4, "determined", dict(lift=0.3), (5, 54, 26, 4.5, 4.6, 98)),
    (0.2, "determined", dict(), (3, 46, 14, 3.4, 5.2, 112)),
]


def f_rise_frames():
    frames = []
    for s, e, mods, ring in F_RISE:
        base = make_frame(s, e, dict(F_SHIP, **mods))
        n, rx, ry, r, a0, cy = ring
        back, front = f_ring(n, rx, ry, r, a0, cy=cy)
        frames.append(f_with_smoke(base, back, front))
    return frames


def f_save_rise(frames, review):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    dst = os.path.join(root, "assets", "title", "anime")
    strip = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    strip.save(os.path.join(dst, "flicker_rise.png"))
    if not review:
        return
    S = 4
    bg = (92, 112, 134, 255)
    gif = []
    for f in frames:
        im = Image.new("RGBA", f.size, bg)
        im.alpha_composite(f)
        gif.append(im.resize((W * S, H * S), Image.NEAREST).convert("RGB"))
    dur = [500] + [120] * (len(gif) - 2) + [900]
    gif[0].save(os.path.join(review, "flicker_rise.gif"), save_all=True, append_images=gif[1:], duration=dur, loop=0)
    cw = W * S + 8
    sheet = Image.new("RGB", (cw * 4 + 8, (H * S + 8) * 2 + 8), bg[:3])
    for i, g in enumerate(gif):
        sheet.paste(g, (8 + (i % 4) * cw, 8 + (i // 4) * (H * S + 8)))
    sheet.save(os.path.join(review, "flicker_rise_sheet.png"))



def f_chin_sheet(review):
    """Four chin steps A (current) .. D (clear V) on Shade (top row) and on Sakura's face (second row, review only)."""
    import subprocess
    import tempfile
    from PIL import ImageFont
    tmp = tempfile.mkdtemp(prefix="sakura_chins_")
    env = dict(os.environ, F_PLAIN="1")
    subprocess.run([sys.executable, os.path.abspath(__file__), "--sakura-chins", tmp], check=True, env=env)
    rows = [[make_frame(-1, "calm", dict(F_SHIP, chin=st)) for st in F_CHIN_STEPS],
            [Image.open(os.path.join(tmp, "s%d.png" % i)).convert("RGBA") for i in range(4)]]
    S = 4
    bg = (92, 112, 134, 255)
    cw = W * S + 8
    rh = H * S + 8
    sheet = Image.new("RGBA", (cw * 4 + 8, rh * 2 + 70 + (H + 8) * 2), bg)
    try:
        font = ImageFont.load_default(size=44)
    except TypeError:
        font = ImageFont.load_default()
    d = ImageDraw.Draw(sheet)
    for r, row in enumerate(rows):
        for i, f in enumerate(row):
            big = f.resize((W * S, H * S), Image.NEAREST)
            sheet.paste(big, (8 + i * cw, 8 + r * rh), big)
            sheet.alpha_composite(f, (8 + i * cw + (W * S - W) // 2, rh * 2 + 70 + r * (H + 8)))
    for i, lab in enumerate("ABCD"):
        tw = d.textlength(lab, font=font)
        d.text((8 + i * cw + (W * S - tw) / 2, rh * 2 + 8), lab, fill=(255, 255, 255, 255), font=font)
    sheet.convert("RGB").save(os.path.join(review, "female_chins.png"))
    with open(os.path.join(review, "female_chins_key.txt"), "w") as fh:
        fh.write("Top row Shade, second row Sakura (same chin steps, review only). (chin width, tip drop); cheeks never change\n")
        for lab, st in zip("ABCD", F_CHIN_STEPS):
            fh.write("%s: %s\n" % (lab, st))
        fh.write("shipped for Shade: %s (chin only)\n" % (F_CHIN_SHIP,))


def f_sakura_chins(out_dir):
    """Subprocess (F_PLAIN=1, her own colours): Sakura's calm frame with each chin step."""
    for i, st in enumerate(F_CHIN_STEPS):
        F_FACE["chin"] = st
        F_FACE["cheek0"] = 0.03
        ab.make_sakura_frame(-1, "calm").save(os.path.join(out_dir, "s%d.png" % i))


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--sakura-chins":
        return f_sakura_chins(sys.argv[2])
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    review = sys.argv[1] if len(sys.argv) > 1 else None
    flint = Image.open(os.path.join(root, "assets", "title", "anime", "flint_bust.png")).convert("RGBA").crop((0, 0, W, H))
    if review:
        os.makedirs(review, exist_ok=True)
        f_variants_sheet(review, flint)
        f_chin_sheet(review)
        f_variants_sheet(review, flint, "flicker_mouths", [(l, dict(F_SHIP, mouth=k), t) for l, k, t in F_MOUTHS])
    frames = f_bust_frames()
    strip = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    strip.save(os.path.join(root, "assets", "title", "anime", "flicker_bust.png"))
    if review:
        S = 4
        bg = (92, 112, 134, 255)
        cw = W * S + 8
        sheet = Image.new("RGBA", (cw * 5 + 8, H * S + 16), bg)
        fb = flint.resize((W * S, H * S), Image.NEAREST)
        sheet.paste(fb, (8, 8), fb)
        for i, f in enumerate(frames):
            big = f.resize((W * S, H * S), Image.NEAREST)
            sheet.paste(big, (8 + (i + 1) * cw, 8), big)
        sheet.convert("RGB").save(os.path.join(review, "flicker_bust_review.png"))
        x1 = Image.new("RGBA", (W * 5, H), bg)
        x1.alpha_composite(flint, (0, 0))
        for i, f in enumerate(frames):
            x1.alpha_composite(f, ((i + 1) * W, 0))
        x1.convert("RGB").save(os.path.join(review, "flicker_bust_x1.png"))
    f_save_rise(f_rise_frames(), review)


if __name__ == "__main__":
    main()
