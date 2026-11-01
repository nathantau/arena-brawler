"""Eden redesign CONCEPTS, round 2 (design stage only), v2: a charming wanderer in an earthy pilgrim dress.
Two idle-frame variants of the A (Wayfarer) + B (Meadow Maiden) combination, with a light carved-wood half-mask, a clear scoop / sweetheart neckline with a
cream chemise trim, a bell skirt that reaches her feet, chestnut hair (no green hair), at most two accessories.
Not wired into generate.py's sheets. Run:
  tools/sprites/.venv/bin/python tools/sprites/eden_concepts2.py [out_dir]
Writes eden_a_v2/b_v2/c_v2.png and eden_ab.png (A/B/C at 8x + 1x/2x previews beside Sakura and Shadow).

PALETTE: the 12 earthy colours below are PROPOSED additions (olive 3, cream 2, chestnut 3, birch 2, ochre 2). They are
only registered at runtime here (shade/highlight ramps added to generate's DARKER / LIGHTER); palette.py is untouched.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import generate as g
from generate import (Canvas, E, L, P, R, RR, FACE, FACE_R, CELL, PAD, UPPER_DY, EYES_X, EYES_Y, MOUTH, ARM_X,
                      HAIR_FLOW, big_eyes, draw_leaf, legs, frames)
from palette import (BROWN, GREEN, GREEN_D, GREEN_L, MAROON, ORANGE, OUTLINE, PINK_L, SHADOW, SKIN, SKIN_D, STEEL,
                     WHITE, YELLOW)

HALF = math.pi / 2

# --- proposed palette additions ---------------------------------------------------------------------------------
OLIVE_D, OLIVE, OLIVE_L = (74, 84, 40), (112, 124, 56), (156, 164, 84)
CREAM, CREAM_D = (240, 228, 196), (206, 188, 150)
CH_D, CH, CH_L = (92, 48, 32), (142, 76, 42), (196, 124, 66)  # chestnut
BIRCH, BIRCH_D = (184, 128, 66), (126, 82, 46)  # carved light wood
OCHRE, OCHRE_D = (212, 156, 56), (156, 104, 44)
NEW = (OLIVE_D, OLIVE, OLIVE_L, CREAM, CREAM_D, CH_D, CH, CH_L, BIRCH, BIRCH_D, OCHRE, OCHRE_D)
g.DARKER.update({OLIVE_L: OLIVE, OLIVE: OLIVE_D, OLIVE_D: SHADOW, CREAM: CREAM_D, CREAM_D: SKIN_D, CH_L: CH,
                 CH: CH_D, CH_D: OUTLINE, BIRCH: BIRCH_D, BIRCH_D: BROWN, OCHRE: OCHRE_D, OCHRE_D: BROWN})
g.LIGHTER.update({OLIVE_D: OLIVE, OLIVE: OLIVE_L, OLIVE_L: GREEN_L, CREAM_D: CREAM, CREAM: WHITE, CH_D: CH,
                  CH: CH_L, CH_L: SKIN_D, BIRCH_D: BIRCH, BIRCH: CREAM, OCHRE_D: OCHRE, OCHRE: YELLOW})


def wave(t, lag, amp):
    return round(HAIR_FLOW[(t - lag) % 4] * amp)


# ---------------------------------------------------------------------------------------------------------------
# shared pieces

def smile(c):
    """A small open smile on the shared mouth spot."""
    x, y = MOUTH
    c.dot(x - 1, y, MAROON)
    c.dot(x + 2, y, MAROON)
    c.flat(R((x, y + 1, x + 1, y + 1)), MAROON)


def blush(c):
    c.flat(R((27, 29, 29, 29)), PINK_L)
    c.flat(R((44, 29, 45, 29)), PINK_L)


def face_shape(up):
    """A heart-shaped face: full cheeks tapering to a small, soft chin (not a box)."""
    up.part(lambda d, f: (d.rounded_rectangle((23, 15, 47, 29), 8, f),
                          d.polygon([(23, 24), (47, 24), (45, 31), (42, 35), (38, 37), (34, 37), (30, 35), (26, 31)],
                                    f)), SKIN, line=False)


def mask(up):
    """A carved light-wood half-mask: one birch shape that arches over both eyes, with a bridge and two wings sweeping
    down the outer cheeks, so the eyes stay open in clean almond cut-outs; a vein along the brow, an olive leaf at
    each temple."""
    pts = [(21, 19), (25, 16), (31, 16), (36, 17), (39, 17), (44, 16), (48, 16), (50, 19), (48, 23), (47, 28),
           (45, 23), (44, 20), (40, 20), (39, 24), (36, 24), (35, 20), (31, 20), (28, 21), (27, 27), (25, 28),
           (23, 23)]
    up.part(P(pts), BIRCH)
    big_eyes(up, EYES_Y, EYES_X, GREEN)
    for x in (30, 45):  # a lash flick at each outer top corner
        up.dot(x, 21, OUTLINE)
    up.flat(L([(24, 19), (28, 17), (33, 17)], 1), CREAM)  # carved brow vein
    up.flat(L([(41, 17), (45, 17), (48, 18)], 1), CREAM)
    for x, y, a in ((24, 19, -2.5), (49, 18, -0.6)):  # a leaf at each temple
        up.part(P(g.leaf_pts(x, y, a, 7, 2.3)), OLIVE, line=False)


def neckline(up):
    """A low sweetheart neckline: a skin scoop with two soft humps and a centre dip, a clean cream chemise band, a
    wooden pendant on a cord."""
    edge = [(25, 38), (27, 39), (30, 40), (32, 39), (33, 41), (34, 39), (36, 40), (39, 39), (41, 38)]
    up.flat(P([(25, 36), (41, 36)] + edge[::-1]), SKIN)
    up.flat(P(edge + [(x, y + 2) for x, y in edge[::-1]]), CREAM)
    up.flat(L([(28, 36), (33, 38), (38, 36)], 1), BROWN)
    up.part(E((32, 37, 35, 40)), BIRCH_D)


def sleeves(up):
    for x in ARM_X:
        up.part(E((x + 1, 41, x + 5, 45)), SKIN)
        up.part(E((x - 1, 34, x + 7, 42)), CREAM)
        up.flat(R((x + 1, 41, x + 5, 41)), OCHRE)


def skirt(up, base, hem, apron=CREAM):
    """A bell skirt that flares from the waist to the feet, a front apron panel, a plain hem band."""
    up.part(P([(21, 44), (43, 44), (46, 48), (51, 52), (13, 52), (18, 48)]), base)
    d = g.DARKER[base]
    up.flat(L([(25, 47), (22, 52)], 1), d)
    up.flat(L([(41, 47), (44, 52)], 1), d)
    up.flat(L([(20, 47), (17, 52)], 1), g.LIGHTER[base])
    up.part(P([(27, 45), (38, 45), (43, 52), (22, 52)]), apron, line=False)
    up.flat(L([(28, 46), (25, 52)], 1), g.LIGHTER[apron])
    up.part(P([(14, 50), (50, 50), (51, 52), (13, 52)]), hem, line=False)
    up.flat(L([(14, 50), (50, 50)], 1), g.LIGHTER[hem])


def corset(up):
    """Bark-brown corset with a cream lacing chevron and an ochre waist band."""
    up.part(RR((21, 36, 43, 45), 3), BROWN)
    up.flat(L([(23, 40), (23, 44)], 1), SKIN_D)
    up.flat(L([(41, 41), (41, 44)], 1), MAROON)
    up.flat(L([(30, 42), (33, 44), (36, 42)], 1), CREAM)
    up.part(R((21, 45, 43, 45)), OCHRE, line=False)


def lacing(up):
    pass


def head(up, hair):
    up.part(RR((15, 6, 48, 36), 9), hair)
    face_shape(up)


def legs_low(step, sock):
    low = Canvas()
    legs(low, sock, BROWN, step)
    return low


def flower(up, x, y, col, mid=YELLOW):
    up.part(E((x - 3, y - 3, x + 3, y + 3)), col)
    up.flat(R((x - 1, y - 1, x, y)), mid)


def blank_crown(t, dy):
    return Canvas(CELL)


# ---------------------------------------------------------------------------------------------------------------
# The combination: Wayfarer's carved mask, side lock + flowers and apron dress, with Meadow Maiden's puff sleeves, laced
# bark-brown corset with a sweetheart neckline and wooden pendant, and braids / flowers.

def fringe(up, hair, hi, side):
    up.part(P([(22, 22), (22, 12), (28, 8), (37, 7), (45, 9), (48, 16), (45, 14), (39, 13), (32, 14), (27, 19),
               (25, 25)]) if side == "swept" else
            P([(22, 22), (22, 12), (28, 8), (37, 7), (44, 9), (48, 16), (46, 22), (44, 18), (40, 15), (37, 14),
               (34, 15), (30, 18), (26, 22)]), hair, shade=False, line=False)
    up.flat(L([(28, 10), (34, 8)], 1), hi)
    up.flat(L([(38, 9), (43, 10)], 1), hi)


def eden_loose(step=None, t=0):
    """1: long loose chestnut hair with a lock over the front shoulder, an orange blossom and a white one; moss skirt."""
    low = legs_low(step, CREAM_D)
    up = Canvas()
    w = lambda lag, amp: wave(t, lag, amp)
    up.part(P([(17, 10), (13, 20), (12, 33), (14 - w(1, 1), 44), (19 - w(2, 1), 47), (24 - w(1, 1), 43), (24, 28),
               (22, 12)]), CH)
    up.flat(L([(16, 22), (15, 31), (16, 39)], 1), CH_L)
    up.part(P([(46, 22), (50, 26), (51 - w(1, 1), 38), (47 - w(2, 1), 41), (45, 30)]), CH)
    sleeves(up)
    skirt(up, GREEN, GREEN_D)
    corset(up)
    neckline(up)
    lacing(up)
    up.part(RR((38, 46, 45, 52), 2), BROWN)  # satchel at the right hip
    up.flat(R((38, 46, 45, 47)), SKIN_D)
    up.part(E((ARM_X[1] + 1, 41, ARM_X[1] + 5, 45)), SKIN)
    up.part(E((ARM_X[1] - 1, 34, ARM_X[1] + 7, 42)), CREAM)
    up.flat(R((ARM_X[1] + 1, 41, ARM_X[1] + 5, 41)), OCHRE)
    head(up, CH)
    up.flat(L([(21, 12), (26, 9), (33, 8)], 1), CH_L)
    fringe(up, CH, CH_L, "swept")
    up.part(P([(20, 16), (24, 18), (24, 30), (22, 35 + w(2, 1)), (18, 28)]), CH, shade=False, line=False)
    mask(up)
    blush(up)
    smile(up)
    flower(up, 46, 11, ORANGE)
    flower(up, 18, 12, WHITE)
    return low, up


def side_braid(up, w):
    """A thick braid over her front shoulder (right), plaited bands, cream ribbon and a blossom at its tie."""
    sw = w(2, 1)
    up.part(P([(45, 28), (50, 28), (51 + sw, 46), (46 + sw, 46)]), CH)
    for y in (32, 36, 40, 44):
        o = sw * (y - 28) // 18
        up.flat(L([(46 + o, y), (50 + o, y + 1)], 1), CH_D)
    up.part(R((46 + sw, 46, 51 + sw, 47)), CREAM, line=False)
    up.part(P([(46 + sw, 48), (51 + sw, 48), (48 + sw, 52)]), CH, shade=False)


def eden_braid(step=None, t=0):
    """2: long chestnut hair with a thick side braid over the front shoulder, an orange and a white blossom at her
    temple, olive skirt with an ochre hem and a gourd."""
    low = legs_low(step, CREAM_D)
    up = Canvas()
    w = lambda lag, amp: wave(t, lag, amp)
    up.part(P([(17, 10), (13, 20), (12, 33), (14 - w(1, 1), 44), (19 - w(2, 1), 47), (24 - w(1, 1), 43), (24, 28),
               (22, 12)]), CH)
    up.flat(L([(16, 22), (15, 31), (16, 39)], 1), CH_L)
    sleeves(up)
    skirt(up, OLIVE, OCHRE)
    corset(up)
    neckline(up)
    gx = w(1, 1)  # gourd canteen at the left hip
    up.flat(L([(24, 46), (24 + gx, 47)], 1), BROWN)
    up.part(E((20 + gx, 46, 27 + gx, 52)), OCHRE_D)
    up.part(R((23 + gx, 45, 24 + gx, 47)), BROWN, line=False)
    up.part(E((ARM_X[1] + 1, 41, ARM_X[1] + 5, 45)), SKIN)
    up.part(E((ARM_X[1] - 1, 34, ARM_X[1] + 7, 42)), CREAM)
    up.flat(R((ARM_X[1] + 1, 41, ARM_X[1] + 5, 41)), OCHRE)
    side_braid(up, w)
    head(up, CH)
    up.flat(L([(21, 12), (26, 9), (33, 8)], 1), CH_L)
    fringe(up, CH, CH_L, "curtain")
    up.part(P([(20, 16), (24, 18), (24, 30), (22, 34), (18, 27)]), CH, shade=False, line=False)
    mask(up)
    blush(up)
    smile(up)
    flower(up, 45, 10, ORANGE)
    flower(up, 40, 7, WHITE)
    return low, up


# ---------------------------------------------------------------------------------------------------------------
VARIANTS = {"1": ("Eden 1: loose chestnut + moss skirt", eden_loose, blank_crown),
            "2": ("Eden 2: side braid + olive skirt", eden_braid, blank_crown)}
BOX = (10, 0, 86, 82)


def idle(build, crown):
    return frames(build, None, crown)[0]


def sheet_frame(name):
    return Image.open(g.OUT / f"{name}.png").convert("RGBA").crop((0, 0, CELL, CELL))


def font(n):
    try:
        return ImageFont.load_default(size=n)
    except TypeError:
        return ImageFont.load_default()


def dark_floor(w, h):
    tiles = Image.open(g.ROOT / "assets" / "arenas" / "pit_tiles.png").convert("RGBA")
    a, b = tiles.crop((0, 0, 32, 32)), tiles.crop((32, 0, 64, 32))
    out = Image.new("RGBA", (w, h))
    for ty in range(0, h, 32):
        for tx in range(0, w, 32):
            out.paste(a if (tx // 32 + ty // 32) % 2 == 0 else b, (tx, ty))
    return out


def on_floor(fr, zoom):
    z = fr.crop(BOX)
    bg = dark_floor(z.width, z.height)
    bg.alpha_composite(z)
    return bg.resize((z.width * zoom, z.height * zoom), Image.NEAREST)


def panel(label, fr, extras):
    big = on_floor(fr, 8)
    s1, s2 = on_floor(fr, 1), on_floor(fr, 2)
    W = big.width + 24 + s2.width * 2 + 24
    H = max(big.height + 56, 56 + s2.height * 2 + 70)
    out = Image.new("RGBA", (W, H), (24, 24, 36, 255))
    d = ImageDraw.Draw(out)
    d.text((12, 8), label, fill=(240, 240, 230), font=font(30))
    out.alpha_composite(big, (0, 50))
    x = big.width + 24
    out.alpha_composite(s1, (x, 56))
    d.text((x, 56 + s1.height + 4), "1x", fill=(190, 190, 200), font=font(16))
    out.alpha_composite(s2, (x, 56 + s1.height + 30))
    d.text((x, 56 + s1.height + 30 + s2.height + 4), "2x", fill=(190, 190, 200), font=font(16))
    x2 = x + s2.width + 16
    for i, (name, f) in enumerate(extras):
        out.alpha_composite(on_floor(f, 2), (x2, 56 + i * (s2.height + 26)))
        d.text((x2, 56 + i * (s2.height + 26) + s2.height + 2), name, fill=(190, 190, 200), font=font(16))
    return out


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else
               "/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/"
               "scratchpad/eden2")
    out.mkdir(parents=True, exist_ok=True)
    extras = [("Sakura (2x)", sheet_frame("sakura")), ("Shadow (2x)", sheet_frame("shadow"))]
    panels = []
    for k, (label, build, crown) in VARIANTS.items():
        p = panel(label, idle(build, crown), extras)
        p.convert("RGB").save(out / f"eden_ab_{k}.png")
        panels.append(p)
    W = max(p.width for p in panels)
    sheet = Image.new("RGB", (W, sum(p.height for p in panels)), (24, 24, 36))
    y = 0
    for p in panels:
        sheet.paste(p.convert("RGB"), (0, y))
        y += p.height
    sheet.save(out / "eden_ab.png")
    print("wrote previews to", out)


if __name__ == "__main__":
    main()
