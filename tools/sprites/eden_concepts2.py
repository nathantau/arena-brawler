"""Eden redesign CONCEPTS, round 2 (design stage only), v2: a charming wanderer in an earthy pilgrim dress.
Two idle-frame variants of the A (Wayfarer) + B (Meadow Maiden) combination, with a light carved-wood half-mask, a clear scoop / sweetheart neckline with a
cream chemise trim, a bell skirt that reaches her feet, chestnut hair (no green hair), at most two accessories.
Not wired into generate.py's sheets. Run:
  tools/sprites/.venv/bin/python tools/sprites/eden_concepts2.py [out_dir]
Writes eden_a_v2/b_v2/c_v2.png and eden_braids.png (A/B/C at 8x + 1x/2x previews beside Sakura and Shadow).

PALETTE: the 12 earthy colours below are PROPOSED additions (olive 3, cream 2, chestnut 3, birch 2, ochre 2). They are
only registered at runtime here (shade/highlight ramps added to generate's DARKER / LIGHTER); palette.py is untouched.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import generate as g
from generate import (Canvas, E, L, P, R, RR, FACE, FACE_R, BLUSH, CELL, PAD, UPPER_DY, EYES_X, EYES_Y, MOUTH, ARM_X,
                      HAIR_FLOW, big_eyes, draw_leaf, legs, frames)
from palette import (BROWN, GREEN, GREEN_D, GREEN_L, MAROON, ORANGE, OUTLINE, PINK_L, SHADOW, SKIN, SKIN_D, STEEL,
                     WHITE, YELLOW)

HALF = math.pi / 2

# --- proposed palette additions ---------------------------------------------------------------------------------
OLIVE_D, OLIVE, OLIVE_L = (74, 84, 40), (112, 124, 56), (156, 164, 84)
CREAM, CREAM_D = (240, 228, 196), (206, 188, 150)
CH_D, CH, CH_L = (72, 38, 28), (116, 62, 38), (176, 108, 60)  # chestnut
BIRCH, BIRCH_D = (218, 176, 104), (150, 104, 58)  # carved light wood
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

## Sakura's face, copied from generate.py at 1dc9071 ("narrower, softer jaw"): a full-width brow tapering into a small
## rounded chin, big eyes with a calm lid and a lash flick at each outer corner, blush kept on the narrower cheeks.
def female_face(c, iris=GREEN, blush=PINK_L, between=None):
    c.part(lambda d, f: (d.rounded_rectangle((FACE[0], FACE[1], FACE[2], 29), FACE_R, f),
                         d.ellipse((FACE[0] + 1, 19, FACE[2] - 1, FACE[3] - 1), f)), SKIN, line=False)
    if between:
        between()
    big_eyes(c, EYES_Y, EYES_X, iris, h=6)
    for x, out in ((29, -1), (39, 4)):
        c.flat(R((x, 21, x + 3, 21)), OUTLINE)
        c.dot(x + out, 21, OUTLINE)
        c.dot(x + out + (1 if out > 0 else -1), 20, OUTLINE)
    c.flat(R((BLUSH[0] + 1, BLUSH[2], BLUSH[0] + 3, BLUSH[2])), blush)
    c.flat(R((BLUSH[1] - 3, BLUSH[2], BLUSH[1] - 2, BLUSH[2])), blush)
    c.flat(R((MOUTH[0], MOUTH[1], MOUTH[0] + 1, MOUTH[1])), MAROON)
    c.dot(MOUTH[0] - 1, MOUTH[1] - 1, MAROON)  # Eden smiles: the corners lift a pixel
    c.dot(MOUTH[0] + 2, MOUTH[1] - 1, MAROON)


MASKS = {
    # 1: a masquerade eye-band with swept cat-eye wings down the outer cheeks
    "wing": [(21, 18), (25, 15), (31, 15), (36, 17), (39, 17), (44, 15), (48, 15), (50, 18), (48, 23), (47, 28),
             (46, 24), (45, 19), (40, 19), (39, 24), (36, 24), (35, 19), (30, 19), (27, 21), (27, 27), (25, 28),
             (23, 23)],
    # 2: a softer domino with a raised leaf crest and short rounded cheek tabs
    "domino": [(22, 19), (26, 15), (32, 14), (36, 16), (39, 16), (43, 14), (48, 15), (51, 19), (49, 25), (47, 27),
               (46, 22), (45, 19), (40, 19), (39, 25), (36, 25), (35, 19), (30, 19), (27, 21), (26, 27), (24, 26),
               (23, 22)],
}


def mask(up, shape):
    """A carved birch half-mask, one pale wooden shape with a dark outline, wood-grain lines, a bridge and wings round
    the eyes (which stay open under it) and an olive leaf at each temple."""
    up.part(P(MASKS[shape]), BIRCH)
    if shape == "wing":
        grains = [[(23, 19), (28, 17), (33, 17), (36, 18)], [(41, 18), (45, 17), (49, 18)], [(26, 21), (27, 26)],
                  [(48, 21), (47, 26)]]
        leaves = ((23, 19, -2.5), (49, 18, -0.6))
    else:
        grains = [[(24, 19), (28, 17), (34, 17), (36, 18)], [(41, 17), (46, 17), (50, 19)], [(26, 22), (26, 25)],
                  [(49, 22), (48, 25)]]
        leaves = ((24, 18, -2.7), (50, 18, -0.45))
    for line in grains:
        up.flat(L(line, 1), BIRCH_D)
    up.flat(L([(37, 19), (37, 22)], 1), BIRCH_D)  # bridge grain
    for x, y, a in leaves:
        up.part(P(g.leaf_pts(x, y, a, 7, 2.3)), OLIVE, line=False)
    if shape == "domino":
        up.part(P(g.leaf_pts(36, 14, -HALF, 5, 2.0)), OLIVE, line=False)


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
    """A bell skirt from the waist to the feet, a front apron panel, a plain hem band."""
    up.part(P([(21, 42), (43, 42), (47, 46), (53, 52), (11, 52), (17, 46)]), base)
    d = g.DARKER[base]
    up.flat(L([(23, 46), (19, 51)], 1), d)
    up.flat(L([(42, 46), (46, 51)], 1), d)
    up.flat(L([(19, 45), (15, 51)], 1), g.LIGHTER[base])
    up.part(P([(28, 44), (37, 44), (40, 52), (25, 52)]), apron, line=False)
    up.flat(L([(29, 45), (27, 51)], 1), g.LIGHTER[apron])
    up.part(P([(12, 50), (52, 50), (53, 52), (11, 52)]), hem, line=False)
    up.flat(L([(12, 50), (52, 50)], 1), g.LIGHTER[hem])


def corset(up):
    """Bark-brown corset, boning lines, an ochre waist band."""
    up.part(RR((21, 36, 43, 43), 3), BROWN)
    up.flat(L([(23, 40), (23, 41)], 1), SKIN_D)
    up.part(R((21, 42, 43, 43)), OCHRE, line=False)
    up.flat(L([(21, 42), (43, 42)], 1), YELLOW)


def legs_low(step, sock):
    low = Canvas()
    legs(low, sock, BROWN, step)
    return low


def flower(up, x, y, col, mid=YELLOW):
    up.part(E((x - 2, y - 2, x + 2, y + 2)), col)
    up.dot(x, y, mid)


def blank_crown(t, dy):
    return Canvas(CELL)


def braid(up, bx, sw, wide=0):
    """A plait hanging over the front of her shoulder: four stacked rounded segments, each lit top-left with a dark
    notch between them, tied off with a small cream ribbon and a tuft."""
    for i in range(4):
        y = 26 + i * 5
        o = round(sw * i / 3)
        up.part(E((bx - 3 + o, y, bx + 3 + o, y + 6)), CH)
        up.flat(L([(bx - 2 + o, y + 2), (bx - 1 + o, y + 1)], 1), CH_L)
    o = sw
    up.part(R((bx - 2 + o, 46, bx + 2 + o, 47)), CREAM, line=False)
    up.part(P([(bx - 2 + o, 48), (bx + 2 + o, 48), (bx + o, 51)]), CH, shade=False)


def eden(shape, skirt_col, hem_col, step=None, t=0):
    low = legs_low(step, CREAM_D)
    up = Canvas()
    w = lambda lag, amp: wave(t, lag, amp)
    sleeves(up)
    skirt(up, skirt_col, hem_col)
    corset(up)
    neckline(up)
    # a small gourd on the belt (one accessory beside the pendant)
    gx = w(1, 1)
    up.flat(L([(40, 45), (40 + gx, 46)], 1), BROWN)
    up.part(E((38 + gx, 46, 44 + gx, 52)), OCHRE_D)
    up.part(R((40 + gx, 44, 41 + gx, 46)), BROWN, line=False)
    up.part(E((ARM_X[1] + 1, 41, ARM_X[1] + 5, 45)), SKIN)
    up.part(E((ARM_X[1] - 1, 34, ARM_X[1] + 7, 42)), CREAM)
    up.flat(R((ARM_X[1] + 1, 41, ARM_X[1] + 5, 41)), OCHRE)
    braid(up, 24, -w(2, 1))
    braid(up, 43, w(2, 1))
    # smooth skull cap, shorter than the old helmet: it stops at the ears and the braids take over
    up.part(RR((16, 6, 48, 28), 11), CH)
    up.flat(L([(22, 10), (28, 8), (36, 8)], 1), CH_L)
    up.flat(L([(40, 9), (44, 11)], 1), CH_L)

    def hair_over_face():
        # a middle part with soft curtain bangs, sweeping to the temples
        up.part(P([(35, 7), (28, 9), (23, 15), (22, 24), (24, 22), (26, 17), (30, 14), (34, 13)]), CH, shade=False,
                line=False)
        up.part(P([(35, 7), (42, 9), (47, 15), (48, 24), (46, 22), (44, 17), (40, 14), (36, 13)]), CH, shade=False,
                line=False)
        up.flat(L([(33, 8), (28, 11), (25, 16)], 1), CH_L)
        up.flat(L([(37, 8), (42, 11), (46, 16)], 1), CH_L)
        mask(up, shape)

    female_face(up, GREEN, PINK_L, hair_over_face)
    flower(up, 44, 8, WHITE)
    flower(up, 40, 6, ORANGE)
    return low, up


def eden_wing(step=None, t=0):
    """1: wing mask, moss skirt with a moss hem."""
    return eden("wing", GREEN, GREEN_D, step, t)


def eden_domino(step=None, t=0):
    """2: domino + leaf-crest mask, olive skirt with an ochre hem."""
    return eden("domino", OLIVE, OCHRE, step, t)


# ---------------------------------------------------------------------------------------------------------------
VARIANTS = {"1": ("Eden 1: wing mask, moss skirt", eden_wing, blank_crown),
            "2": ("Eden 2: domino mask, olive skirt", eden_domino, blank_crown)}
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
        p.convert("RGB").save(out / f"eden_braids_{k}.png")
        panels.append(p)
    W = max(p.width for p in panels)
    sheet = Image.new("RGB", (W, sum(p.height for p in panels)), (24, 24, 36))
    y = 0
    for p in panels:
        sheet.paste(p.convert("RGB"), (0, y))
        y += p.height
    sheet.save(out / "eden_braids.png")
    print("wrote previews to", out)


if __name__ == "__main__":
    main()
