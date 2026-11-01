"""Eden redesign CONCEPTS (phase 1): three idle-frame variants (A / B / C) with a wooden/stone/leaf mask over the top
half of her face and a busier outfit. Not wired into generate.py's sheets. Run:
  tools/sprites/.venv/bin/python tools/sprites/eden_concepts.py [out_dir]
Writes eden_a/b/c.png, eden_all.png (A/B/C + current Eden) to out_dir (default /private/tmp/claude-501/redesign-previews).
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import generate as g
from generate import (Canvas, E, L, P, R, RR, BODY, FACE, FACE_R, CELL, PAD, UPPER_DY, EYES_X, EYES_Y, MOUTH, ARM_X,
                      SWAY, HAIR_FLOW, arm, big_eyes, draw_leaf, legs, frames)
from palette import (BROWN, GREEN, GREEN_D, GREEN_L, MAROON, ORANGE, OUTLINE, SHADOW, SKIN, SKIN_D, STEEL, STEEL_D,
                     WHITE, YELLOW)

HALF = math.pi / 2


def leaf_row(c, xs, y, ln, w, cols, bend=0.0, rib=False):
    """Hanging leaves along a line (a mantle layer), each pointing down, tilted away from the centre by `bend`."""
    for i, x in enumerate(xs):
        tilt = (x - 33) * bend
        col = cols[i % len(cols)]
        draw_leaf(c, x, y, HALF + tilt, ln, w, col, rib=g.DARKER[col] if rib else None)


def eyes(c, iris, hole=True, h=5):
    """Glowing eyes inside dark mask holes."""
    if hole:
        c.flat(E((29, 20, 36, 28)), OUTLINE)
        c.flat(E((39, 20, 46, 28)), OUTLINE)
    big_eyes(c, EYES_Y, EYES_X, iris, h=h)


def lower_face(c):
    for x in (33, 43):  # freckles
        c.dot(x, 32, SKIN_D)
    c.flat(R((MOUTH[0], MOUTH[1] + 1, MOUTH[0] + 1, MOUTH[1] + 1)), MAROON)


def head(c, hair):
    c.part(RR((15, 6, 48, 36), 9), hair)
    c.flat(L([(22, 9), (32, 7)], 1), g.LIGHTER[hair])
    c.part(RR(FACE, FACE_R), SKIN)


def locks(c, hair, t):
    w = round(HAIR_FLOW[(t - 1) % 4] * 1)
    c.part(P([(FACE[0] - 1, 17), (FACE[0] + 3, 17), (FACE[0] + 2, 30), (FACE[0] - 2, 34 + w), (FACE[0] - 4, 26)]), hair,
           shade=False)


MASK = [(22, 16), (26, 13), (36, 12), (45, 13), (49, 17), (49, 25), (46, 29), (41, 29), (39, 27), (36, 27), (34, 29),
        (27, 29), (22, 26)]


def pouch(c, x, y, flap=GREEN_D):
    c.part(RR((x, y, x + 5, y + 5), 1), BROWN)
    c.flat(R((x, y, x + 5, y + 1)), flap)
    c.dot(x + 2, y + 3, YELLOW)


def woven_belt(c, y0=43, y1=45):
    c.part(R((20, y0, 44, y1)), BROWN, line=False)
    for x in range(21, 44, 2):
        c.dot(x, y0 + (x // 2) % 2, SKIN_D)
    c.part(RR((30, y0 - 1, 35, y1 + 1), 1), YELLOW)  # amber buckle
    c.dot(32, y0 + 1, ORANGE)


# ---------------------------------------------------------------------------------------------------------------
# A: "Sproutkeeper": pale carved oak mask with a sprout growing from the brow; layered leaf mantle; seed pouches
def eden_a(step=None, t=0):
    low = Canvas()
    for x, dy in legs(low, GREEN_D, BROWN, step):
        low.flat(R((x, 48 + dy, x + 5, 50 + dy)), GREEN)  # moss/vine leg wraps
        low.flat(R((x, 49 + dy, x + 5, 49 + dy)), GREEN_D)
        low.dot(x + 1, 52 + dy, GREEN_L)
        low.flat(R((x, 53 + dy, x + 5, 53 + dy)), STEEL_D)  # boot stone toe
    up = Canvas()
    wave = lambda lag, amp: round(HAIR_FLOW[(t - lag) % 4] * amp)
    arm(up, ARM_X[0], GREEN_D, SKIN)
    up.part(R((ARM_X[0], 39, ARM_X[0] + 5, 42)), BROWN)  # bark bracer, mossed
    up.flat(R((ARM_X[0], 39, ARM_X[0] + 3, 39)), GREEN)
    up.part(RR(BODY, 3), GREEN)
    up.flat(L([(24, 36), (28, 42)], 1), GREEN_D)  # vine bandolier
    up.flat(L([(29, 43), (40, 35)], 1), GREEN_D)
    for x, y in ((26, 38), (30, 42), (34, 40), (38, 37)):
        up.dot(x, y, YELLOW)
    woven_belt(up)
    pouch(up, 21, 45)
    pouch(up, 38, 46, GREEN)
    up.flat(L([(26, 46), (26, 50)], 1), GREEN_D)  # hanging vine with a leaf
    draw_leaf(up, 26, 50, HALF + 0.3 - wave(2, 0.1), 5, 1.8, GREEN_L)
    # mantle: a back layer then a front layer of leaves; heavier on her left (our left)
    leaf_row(up, (19, 23, 27, 31, 35, 39, 43), 33, 12, 3.3, (GREEN_D, GREEN), bend=0.02)
    leaf_row(up, (18, 22, 26), 35, 11, 3.3, (GREEN, GREEN_D), bend=0.05)
    leaf_row(up, (22, 27, 32, 37, 42), 33, 8, 3.0, (GREEN_L, GREEN_L, GREEN), bend=0.02, rib=True)
    arm(up, ARM_X[1], GREEN_D, SKIN)
    up.part(R((ARM_X[1], 39, ARM_X[1] + 5, 42)), BROWN)
    up.flat(R((ARM_X[1], 42, ARM_X[1] + 5, 42)), STEEL_D)
    up.part(E((38, 30, 50, 40)), STEEL_D)  # stone pauldron (right side only)
    up.flat(L([(41, 32), (46, 32)], 1), STEEL)
    up.flat(R((41, 30, 46, 31)), GREEN)
    up.dot(44, 29, GREEN_L)
    up.flat(L([(43, 35), (44, 38)], 1), SHADOW)
    head(up, MAROON)
    locks(up, MAROON, t)
    # mask: carved oak, brow ridge, leaf-vein carvings, sprout
    up.part(P(MASK), BROWN)
    up.flat(R((25, 15, 46, 15)), SKIN_D)
    up.flat(L([(23, 20), (27, 18)], 1), SKIN_D)  # side carved leaf veins
    up.flat(L([(48, 20), (45, 18)], 1), SKIN_D)
    up.flat(L([(35, 15), (35, 19)], 1), SKIN_D)  # brow groove
    up.flat(L([(38, 15), (38, 19)], 1), SKIN_D)
    up.flat(L([(31, 28), (28, 27)], 1), MAROON)  # cheek notches
    up.flat(L([(43, 28), (47, 27)], 1), MAROON)
    eyes(up, YELLOW)
    lower_face(up)
    # sprout from the brow
    sw = wave(1, 0.6)
    up.flat(L([(37, 13), (37, 8)], 1), GREEN_D)
    draw_leaf(up, 37, 8, -2.5 - sw * 0.1, 9, 2.8, GREEN_L, rib=GREEN)
    draw_leaf(up, 37, 8, -0.65 + sw * 0.1, 9, 2.8, GREEN, rib=GREEN_D)
    # leaf clip + flower kept from the old design
    draw_leaf(up, 20, 14, -0.4 - wave(1, 0.1), 8, 2.3, GREEN_L)
    up.flat(E((16, 11, 20, 15)), ORANGE)
    up.dot(18, 13, YELLOW)
    return low, up


def crown_a(t, dy):
    """A small ring of leaves behind her head, tips swaying."""
    c = Canvas(CELL)
    ox, oy = PAD, PAD + UPPER_DY + dy
    wave = lambda lag, amp: g.HAIR_FLOW[(t - lag) % 4] * amp
    for x, y, ang, ln, w, col, lag in ((22, 11, -2.7, 11, 3.0, GREEN_D, 3), (47, 11, -0.45, 11, 3.0, GREEN_D, 3),
                                       (27, 8, -2.2, 13, 3.4, GREEN, 2), (43, 8, -0.95, 13, 3.4, GREEN, 2)):
        draw_leaf(c, ox + x, oy + y, ang + wave(lag, 0.07) * (1 if ang > -HALF else -1), ln, w, col, rib=g.DARKER[col])
    return c


# ---------------------------------------------------------------------------------------------------------------
# B: "Runestone": grey stone mask with glowing rune + moss, antler-branch crown, long leaf cape, vine-wrapped torso
def eden_b(step=None, t=0):
    low = Canvas()
    for x, dy in legs(low, BROWN, GREEN_D, step):
        for y in (46, 49, 52):  # vine wraps up the legs
            low.flat(R((x, y + dy, x + 5, y + dy)), GREEN)
        low.dot(x + 1, 47 + dy, GREEN_L)
        low.dot(x + 4, 50 + dy, GREEN_L)
        low.flat(R((x - 1, 54 + dy, x + 6, 54 + dy)), STEEL_D)
    up = Canvas()
    s = SWAY[t % 4]
    wave = lambda lag, amp: round(HAIR_FLOW[(t - lag) % 4] * amp)
    # long cape of leaves streaming behind (to the left), ragged hem
    cape = [(20, 33), (14 - wave(1, 1), 40 + s), (11 - wave(2, 1.5), 50 + s), (15 - wave(3, 2), 55), (21, 52), (26, 50)]
    up.part(P(cape), GREEN_D)
    for i, (x, y) in enumerate(((13, 52), (17, 53), (21, 51))):  # leaf-tip hem
        draw_leaf(up, x - wave(2 + i % 2, 1.5), y, HALF + 0.1, 6, 2.2, (GREEN, GREEN_D, GREEN)[i])
    up.flat(L([(18, 36), (14 - wave(1, 1), 47)], 1), GREEN)
    arm(up, ARM_X[0], BROWN, SKIN)
    up.flat(R((ARM_X[0], 40, ARM_X[0] + 5, 42)), STEEL_D)  # stone bracer
    up.flat(R((ARM_X[0], 40, ARM_X[0] + 5, 40)), STEEL)
    up.part(RR(BODY, 3), BROWN)  # tunic: wood-brown
    up.part(P([(21, 34), (43, 34), (41, 44), (23, 44)]), GREEN, shade=False)  # leaf-weave jerkin
    for x in range(25, 41, 4):  # woven diagonal
        up.flat(L([(x, 36), (x + 3, 42)], 1), GREEN_D)
        up.dot(x + 1, 37, GREEN_L)
    up.flat(L([(22, 35), (42, 43)], 2), BROWN)  # strap
    up.part(E((29, 38, 36, 44)), YELLOW)  # amber pendant
    up.flat(R((31, 40, 32, 41)), ORANGE)
    up.dot(30, 39, WHITE)
    woven_belt(up, 44, 46)
    pouch(up, 38, 46)
    up.part(E((18, 31, 31, 39)), STEEL_D)  # stone shoulder (left, with a mossy lip)
    up.flat(L([(20, 34), (26, 34)], 1), STEEL)
    up.flat(R((20, 31, 26, 32)), GREEN)
    up.dot(23, 30, GREEN_L)
    arm(up, ARM_X[1], GREEN_D, SKIN)  # right: bare-ish arm with a vine wrap
    up.flat(R((ARM_X[1], 39, ARM_X[1] + 5, 39)), GREEN)
    up.flat(R((ARM_X[1], 41, ARM_X[1] + 5, 41)), GREEN)
    up.dot(ARM_X[1] + 2, 40, GREEN_L)
    head(up, BROWN)
    locks(up, BROWN, t)
    # stone mask: full upper face, moss patches, a glowing rune
    up.part(P(MASK), STEEL)
    up.flat(R((26, 14, 44, 14)), WHITE)
    up.flat(L([(23, 24), (26, 28)], 1), STEEL_D)  # cracks
    up.flat(L([(47, 19), (45, 22)], 1), STEEL_D)
    up.flat(R((42, 13, 47, 15)), GREEN)  # moss
    up.dot(44, 12, GREEN_L)
    up.dot(25, 17, GREEN)
    up.flat(L([(36, 14), (36, 18)], 1), GREEN_L)  # rune on the brow
    up.flat(L([(34, 16), (38, 16)], 1), GREEN_L)
    up.dot(35, 19, GREEN_L)
    up.dot(37, 19, GREEN_L)
    eyes(up, GREEN_L)
    lower_face(up)
    draw_leaf(up, 20, 14, -0.4 - wave(1, 0.1), 8, 2.3, GREEN)
    return low, up


def crown_b(t, dy):
    """Antler-like branches rising from her brow, each tipped with a leaf."""
    c = Canvas(CELL)
    ox, oy = PAD, PAD + UPPER_DY + dy
    wave = lambda lag, amp: g.HAIR_FLOW[(t - lag) % 4] * amp
    for side in (-1, 1):
        x0 = 36 + side * 6
        w = round(wave(2, 0.7)) * side
        trunk = [(ox + x0, oy + 12), (ox + x0 + side * 3, oy + 7), (ox + x0 + side * 5 + w, oy + 1),
                 (ox + x0 + side * 4 + w, oy - 4)]
        c.part(L(trunk, 2), BROWN)
        c.part(L([(ox + x0 + side * 4, oy + 5), (ox + x0 + side * 9 + w, oy + 3)], 2), BROWN)  # side tine
        draw_leaf(c, ox + x0 + side * 4 + w, oy - 4, -HALF + side * 0.4, 9, 3.0, GREEN_L, rib=GREEN)
        draw_leaf(c, ox + x0 + side * 9 + w, oy + 3, -HALF + side * 1.0, 7, 2.5, GREEN)
    return c


# ---------------------------------------------------------------------------------------------------------------
# C: "Verdant Warden": green leaf-shaped mask with a midrib and pointed tips, high vine-tied hair, bark cuirass
def eden_c(step=None, t=0):
    low = Canvas()
    for x, dy in legs(low, GREEN_D, BROWN, step):
        low.part(RR((x - 1, 47 + dy, x + 6, 51 + dy), 1), STEEL_D)  # stone greaves
        low.flat(R((x, 48 + dy, x + 5, 48 + dy)), STEEL)
        low.dot(x + 4, 50 + dy, SHADOW)
        low.flat(R((x + 1, 53 + dy, x + 4, 53 + dy)), GREEN)
    up = Canvas()
    wave = lambda lag, amp: round(HAIR_FLOW[(t - lag) % 4] * amp)
    # high ponytail tied with a vine, falling behind
    up.part(P([(20, 10), (12, 14), (8 - wave(0, .5), 22), (7 - wave(1, 1), 32), (10 - wave(2, 1.5), 38),
               (14 - wave(1, 1), 28), (18, 20)]), BROWN)
    up.flat(R((15, 11, 19, 12)), GREEN)
    up.flat(L([(10, 18), (8 - wave(1, .5), 27)], 1), SKIN_D)
    draw_leaf(up, 10 - wave(2, 1.5), 37, HALF + 0.4, 6, 2.2, GREEN_L)
    arm(up, ARM_X[0], BROWN, SKIN)
    up.part(R((ARM_X[0], 39, ARM_X[0] + 5, 43)), BROWN)  # long wooden vambrace with grooves
    up.flat(L([(ARM_X[0] + 1, 39), (ARM_X[0] + 1, 43)], 1), MAROON)
    up.flat(L([(ARM_X[0] + 3, 39), (ARM_X[0] + 3, 43)], 1), MAROON)
    up.part(RR(BODY, 3), GREEN_D)
    # bark cuirass: overlapping plates
    for i, (x0, x1, y0) in enumerate(((22, 42, 34), (23, 41, 38), (24, 40, 42))):
        up.part(R((x0, y0, x1, y0 + 3)), BROWN, line=True)
        up.flat(R((x0 + 1, y0, x1 - 1, y0)), SKIN_D)
        up.flat(R((x0 + 3 + i * 3, y0 + 1, x0 + 3 + i * 3, y0 + 2)), MAROON)
        up.flat(R((x1 - 4 - i * 2, y0 + 1, x1 - 4 - i * 2, y0 + 2)), MAROON)
    up.part(E((30, 36, 35, 41)), STEEL_D)  # stone core
    up.dot(31, 37, STEEL)
    up.dot(33, 40, ORANGE)  # amber flaw
    woven_belt(up, 45, 46)
    pouch(up, 21, 47, GREEN)
    up.part(E((37, 46, 42, 52)), SKIN_D)  # gourd canteen on the hip
    up.flat(R((39, 45, 40, 46)), BROWN)
    up.dot(38, 48, YELLOW)
    # one big leaf cape over the right shoulder, hanging to the front hip (asymmetry)
    cape = [(36, 31), (49, 33), (53 + wave(1, .5), 41), (50 + wave(2, 1), 49), (44, 47), (40, 40)]
    up.part(P(cape), GREEN)
    up.flat(L([(40, 34), (50 + wave(2, 1), 47)], 1), GREEN_D)  # midrib
    for y in (37, 41, 45):
        up.flat(L([(44, y - 1), (48 + wave(1, .5), y - 2)], 1), GREEN_L)
    arm(up, ARM_X[1], GREEN_D, SKIN)
    up.part(R((ARM_X[1], 40, ARM_X[1] + 5, 42)), STEEL_D)  # stone cuff
    up.flat(R((ARM_X[1], 40, ARM_X[1] + 5, 40)), STEEL)
    up.part(E((16, 31, 28, 40)), GREEN_D)  # small mossy mantle at the other shoulder
    for x in (18, 21, 24):
        draw_leaf(up, x, 35, HALF + 0.1, 6, 2.5, GREEN_L if x == 21 else GREEN)
    head(up, BROWN)
    locks(up, BROWN, t)
    # leaf mask: pointed leaf shape sweeping out at the sides, midrib down the brow
    leaf_mask = [(20, 21), (24, 14), (36, 11), (47, 14), (51, 20), (49, 26), (46, 29), (41, 29), (39, 27), (36, 27),
                 (34, 29), (27, 29), (22, 27)]
    up.part(P(leaf_mask), GREEN)
    up.flat(L([(36, 11), (36, 17)], 1), GREEN_D)  # midrib
    up.flat(L([(36, 14), (28, 17)], 1), GREEN_D)  # veins
    up.flat(L([(36, 14), (45, 17)], 1), GREEN_D)
    up.flat(L([(28, 14), (24, 17)], 1), GREEN_L)
    up.flat(L([(22, 21), (24, 24)], 1), GREEN_D)
    up.flat(L([(49, 21), (47, 24)], 1), GREEN_D)
    up.dot(36, 10, GREEN_L)
    eyes(up, ORANGE)
    lower_face(up)
    return low, up


def crown_c(t, dy):
    """A tall unfurling fan of five leaves, bigger than the mask is wide."""
    c = Canvas(CELL)
    ox, oy = PAD, PAD + UPPER_DY + dy
    wave = lambda lag, amp: g.HAIR_FLOW[(t - lag) % 4] * amp
    for x, y, ang, ln, w, col, lag in ((25, 12, -2.55, 12, 3.2, GREEN_D, 3), (47, 12, -0.6, 12, 3.2, GREEN_D, 3),
                                       (29, 9, -2.1, 16, 4.0, GREEN, 2), (43, 9, -1.04, 16, 4.0, GREEN, 2),
                                       (36, 8, -HALF, 20, 4.4, GREEN_L, 1)):
        draw_leaf(c, ox + x, oy + y, ang + wave(lag, 0.07) * (1 if ang > -HALF else -1), ln, w, col, rib=g.DARKER[col])
    return c


# ---------------------------------------------------------------------------------------------------------------
VARIANTS = {"a": ("A  Sproutkeeper", eden_a, crown_a), "b": ("B  Runestone", eden_b, crown_b),
            "c": ("C  Verdant Warden", eden_c, crown_c)}
BOX = (10, 0, 86, 82)  # region of a 96 cell shown in previews


def idle(build, crown):
    return frames(build, None, crown)[0]


def sheet_frame(name):
    return Image.open(g.OUT / f"{name}.png").convert("RGBA").crop((0, 0, CELL, CELL))


def font(n):
    try:
        return ImageFont.load_default(size=n)
    except TypeError:
        return ImageFont.load_default()


def floor_crop(w, h):
    tiles = Image.open(g.ROOT / "assets" / "arenas" / "pit_tiles.png").convert("RGBA")
    a, b = tiles.crop((0, 0, 32, 32)), tiles.crop((32, 0, 64, 32))
    out = Image.new("RGBA", (w, h))
    for ty in range(0, h, 32):
        for tx in range(0, w, 32):
            out.paste(a if (tx // 32 + ty // 32) % 2 == 0 else b, (tx, ty))
    return out


def panel(label, fighter):
    """Left: the frame at 8x on floor; right: in-game-ish scale (3x) beside Sakura and Flint, same floor."""
    zoom = fighter.crop(BOX)
    big = floor_crop(zoom.width, zoom.height)
    big.alpha_composite(zoom)
    big = big.resize((big.width * 8, big.height * 8), Image.NEAREST)
    cw, ch = (BOX[2] - BOX[0]) * 3, (BOX[3] - BOX[1]) * 3
    step = cw - 60
    row_w = step * 2 + cw
    row = floor_crop(row_w, ch)
    for i, f in enumerate((sheet_frame("sakura"), fighter, sheet_frame("flint"))):
        row.alpha_composite(f.crop(BOX).resize((cw, ch), Image.NEAREST), (i * step, 0))
    W = big.width + 24 + row_w
    H = max(big.height, ch) + 60
    out = Image.new("RGBA", (W, H), (24, 24, 36, 255))
    d = ImageDraw.Draw(out)
    d.text((12, 8), label, fill=(240, 240, 230), font=font(30))
    out.alpha_composite(big, (0, 50))
    out.alpha_composite(row, (big.width + 24, 50))
    d.text((big.width + 24, 50 + ch + 8), "3x: Sakura | Eden | Flint", fill=(190, 190, 200), font=font(18))
    return out


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "/private/tmp/claude-501/redesign-previews")
    out.mkdir(parents=True, exist_ok=True)
    frs = {}
    for k, (label, build, crown) in VARIANTS.items():
        frs[k] = idle(build, crown)
        panel(label, frs[k]).convert("RGB").save(out / f"eden_{k}.png")
    items = [("Current", sheet_frame("eden"))] + [(VARIANTS[k][0], frs[k]) for k in "abc"]
    z = 6
    cw, ch = (BOX[2] - BOX[0]) * z, (BOX[3] - BOX[1]) * z
    sheet = Image.new("RGB", (cw * 4 + 5 * 12, ch + 70), (24, 24, 36))
    d = ImageDraw.Draw(sheet)
    for i, (label, f) in enumerate(items):
        x = 12 + i * (cw + 12)
        bg = floor_crop(BOX[2] - BOX[0], BOX[3] - BOX[1])
        bg.alpha_composite(f.crop(BOX))
        sheet.paste(bg.resize((cw, ch), Image.NEAREST).convert("RGB"), (x, 56))
        d.text((x, 12), label, fill=(240, 240, 230), font=font(30))
    sheet.save(out / "eden_all.png")
    print("wrote previews to", out)


if __name__ == "__main__":
    main()
