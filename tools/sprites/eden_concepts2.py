"""Eden redesign CONCEPTS, round 2 (design stage only): a charming wanderer in an earthy pilgrim dress with a lower
sweetheart/scoop neckline, a laced bodice, a layered skirt and a refined mask. Three idle-frame variants (A / B / C),
each with its own mask, dress silhouette and hair. Not wired into generate.py's sheets. Run:
  tools/sprites/.venv/bin/python tools/sprites/eden_concepts2.py [out_dir]
Writes eden_a/b/c.png and eden_concepts.png (A/B/C 8x + 1x/2x previews, with Sakura and the current Eden) to out_dir.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import generate as g
from generate import (Canvas, E, L, P, R, RR, BODY, FACE, FACE_R, CELL, PAD, UPPER_DY, EYES_X, EYES_Y, MOUTH, ARM_X,
                      HAIR_FLOW, big_eyes, draw_leaf, legs, frames)
from palette import (BROWN, GREEN, GREEN_D, GREEN_L, MAROON, ORANGE, OUTLINE, PINK_L, SHADOW, SKIN, SKIN_D, STEEL,
                     STEEL_D, WHITE, YELLOW)

HALF = math.pi / 2


def wave(t, lag, amp):
    return round(HAIR_FLOW[(t - lag) % 4] * amp)


# ---------------------------------------------------------------------------------------------------------------
# shared bits

def smile(c):
    """A cute little open smile on the shared mouth spot: corners lifted, a dark bowl, a hint of tongue."""
    x, y = MOUTH
    c.dot(x - 1, y, MAROON)
    c.dot(x + 2, y, MAROON)
    c.flat(R((x, y + 1, x + 1, y + 1)), MAROON)
    c.dot(x, y, SKIN_D)
    c.dot(x + 1, y, SKIN_D)


def blush(c, col=ORANGE):
    c.flat(R((27, 29, 29, 29)), col)
    c.flat(R((45, 29, 46, 29)), col)


def lashes(c):
    """Soft lid line and a flick at each outer corner."""
    for x, out in ((31, -1), (41, 4)):
        c.flat(R((x, 21, x + 3, 21)), OUTLINE)
        c.dot(x + out, 21, OUTLINE)
        c.dot(x + out + (1 if out > 0 else -1), 20, OUTLINE)


def sweetheart(c, trim, y=37, skin=SKIN):
    """A low sweetheart neckline: two soft scoops over the chest, a dip in the middle, a thin trim line."""
    c.flat(P([(26, y), (31, y), (33, y + 1), (35, y), (40, y), (38, y + 2), (35, y + 3), (33, y + 4), (30, y + 3),
              (28, y + 2)]), skin)
    c.flat(L([(26, y + 1), (29, y + 3), (33, y + 4), (36, y + 3), (39, y + 2)], 1), trim)
    c.dot(33, y + 1, SKIN_D)  # the cleft
    c.dot(32, y + 2, SKIN_D)


def lace_up(c, x, y0, y1, col, cord=None):
    """Criss-cross lacing down a bodice centre line."""
    for y in range(y0, y1, 2):
        c.dot(x - 1, y, col)
        c.dot(x + 1, y, col)
        c.dot(x, y + 1, col)


def hem_row(c, y, x0, x1, cols, step=3, leaf=True):
    """Little embroidered leaves / dots along a hem."""
    for i, x in enumerate(range(x0, x1, step)):
        col = cols[i % len(cols)]
        c.dot(x, y, col)
        if leaf:
            c.dot(x + 1, y - 1, col)
            c.dot(x - 1, y - 1, col)


def frayed_edge(c, y, x0, x1, col, t=0):
    """A ragged linen hem: alternating dangling threads."""
    for x in range(x0, x1):
        if (x + t) % 3 == 0:
            c.dot(x, y, col)


def blank_crown(t, dy):
    return Canvas(CELL)


# ---------------------------------------------------------------------------------------------------------------
# A: "Wayfarer" -- carved walnut half-mask with gilded leaf-vein filigree, long chestnut hair with a side braid and
# flowers, moss pilgrim dress with a cream apron, laced bodice, ochre shawl, satchel + twine belt.

def mask_band(c, base):
    """A carved eye-band: arches over both eyes, a bridge piece between them, two wings sweeping down the outer
    cheeks. Nothing circles the eyes (no 'glasses'): they stay open below the brow."""
    pts = [(21, 16), (25, 14), (31, 14), (36, 16), (39, 16), (44, 14), (48, 14), (50, 16), (48, 21), (47, 27),
           (45, 22), (44, 19), (40, 19), (39, 23), (36, 23), (35, 19), (31, 19), (28, 20), (27, 26), (25, 27),
           (23, 21)]
    c.part(P(pts), base)
    return pts


def eden_a(step=None, t=0):
    low = Canvas()
    for x, dy in legs(low, WHITE, BROWN, step):  # cream stockings, leather boots
        low.flat(R((x, 54 + dy, x + 5, 54 + dy)), STEEL)
        low.flat(R((x - 1, 55 + dy, x + 6, 55 + dy)), SKIN_D)
    up = Canvas()
    w = lambda lag, amp: wave(t, lag, amp)
    breath = (0, 0, 1, 1)[t % 4]
    # long back hair
    up.part(P([(16, 12), (13, 24), (12 - w(1, 1), 36), (14 - w(2, 1), 45), (22 - w(3, 1), 44), (24, 30), (22, 14)]),
            BROWN)
    up.flat(L([(16, 20), (15, 30), (16 - w(2, 1), 41)], 1), SKIN_D)
    # back arm: cream puff sleeve with ochre cuff
    up.part(E((ARM_X[0] + 1, 41, ARM_X[0] + 5, 45)), SKIN)
    up.part(RR((ARM_X[0], 35, ARM_X[0] + 6, 42), 3), WHITE)
    up.flat(R((ARM_X[0], 41, ARM_X[0] + 5, 41)), YELLOW)
    # overskirt in moss, a cream underskirt front, ochre hem band with leaf marks
    up.part(P([(21, 41), (43, 41), (50, 51), (14, 51)]), GREEN)
    for x, d in ((19, -1), (24, -1), (39, 1), (44, 1)):  # fold lines fanning out
        up.flat(L([(x, 46), (x + d * 2, 49)], 1), GREEN_D)
    up.flat(L([(21, 44), (17, 49)], 1), GREEN_L)
    up.part(P([(27, 42), (37, 42), (42, 51), (22, 51)]), WHITE, line=False)
    up.flat(L([(27, 43), (24, 49)], 1), STEEL)
    up.flat(L([(37, 43), (40, 49)], 1), STEEL)
    up.flat(R((15, 49, 49, 49)), YELLOW)
    for x in range(17, 49, 4):
        up.dot(x, 50, ORANGE)
        up.dot(x + 1, 48, YELLOW)
    draw_leaf(up, 32, 44, HALF, 4, 1.4, GREEN, shade=False)  # a little sewn leaf on the front
    # bodice: moss, with a sweetheart neckline over a cream chemise
    up.part(RR((21, 33, 43, 43), 3), GREEN)
    up.flat(R((22, 33, 42, 36)), WHITE)  # chemise at the shoulders
    up.flat(P([(25, 36), (40, 36), (40, 37), (38, 39), (35, 38), (33, 40), (31, 38), (28, 39), (26, 38)]), SKIN)
    up.flat(L([(25, 37), (28, 40), (31, 39), (33, 41), (35, 39), (38, 40), (40, 37)], 1), WHITE)  # neckline trim
    up.flat(L([(23, 38), (23, 41)], 1), GREEN_L)
    up.flat(L([(41, 40), (41, 42)], 1), GREEN_D)
    lace_up(up, 32, 42, 43, YELLOW)
    # belt: twine with a wooden toggle, seed pouch
    up.part(R((21, 42, 43, 43)), BROWN, line=False)
    for x in range(22, 43, 2):
        up.dot(x, 42 + (x // 2) % 2, SKIN_D)
    up.part(RR((30, 41, 34, 44), 1), YELLOW)
    px = w(2, 1)
    up.part(RR((38 + px, 44, 43 + px, 49), 1), BROWN)
    up.flat(R((38 + px, 44, 43 + px, 45)), SKIN_D)
    up.dot(40 + px, 47, YELLOW)
    # satchel on her back hip
    up.part(RR((15, 42 + breath, 23, 49 + breath), 2), BROWN)
    up.flat(R((15, 42 + breath, 23, 44 + breath)), SKIN_D)
    up.dot(19, 46 + breath, YELLOW)
    up.flat(L([(22, 35), (18, 42 + breath)], 1), BROWN)
    # front arm
    up.part(E((ARM_X[1] + 1, 41, ARM_X[1] + 5, 45)), SKIN)
    up.part(RR((ARM_X[1], 35, ARM_X[1] + 6, 42), 3), WHITE)
    up.flat(R((ARM_X[1], 41, ARM_X[1] + 5, 41)), YELLOW)
    # head
    up.part(RR((15, 6, 48, 36), 9), BROWN)
    up.part(RR(FACE, FACE_R), SKIN)
    # fringe: side-swept from a left part, kept above the mask
    up.part(P([(22, 17), (22, 11), (28, 7), (36, 6), (44, 8), (48, 14), (45, 13), (38, 11), (31, 12), (26, 16),
               (24, 22)]), BROWN, shade=False)
    up.flat(L([(27, 8), (33, 7)], 1), SKIN_D)
    up.flat(L([(35, 8), (38, 8)], 1), SKIN_D)
    up.flat(L([(29, 10), (26, 14)], 1), SKIN_D)
    up.part(P([(20, 15), (24, 17), (24, 30), (22, 35 + w(2, 1)), (18, 28)]), BROWN, shade=False)
    # mask: dark carved moss-wood with gilt filigree; the eyes stay open beneath it
    mask_band(up, GREEN)
    big_eyes(up, EYES_Y, EYES_X, GREEN)
    gold = YELLOW
    up.flat(L([(23, 15), (28, 14)], 1), GREEN_L)
    up.flat(L([(23, 17), (28, 15), (33, 15), (36, 17)], 1), gold)  # vein along the brow, branching ticks
    up.flat(L([(40, 17), (44, 15), (48, 15)], 1), gold)
    for x, y in ((26, 17), (30, 17), (43, 17), (46, 17)):
        up.dot(x, y, gold)
    up.dot(37, 19, ORANGE)  # a seed gem on the bridge
    up.dot(38, 19, gold)
    up.flat(L([(25, 21), (26, 25)], 1), gold)  # wing veins
    up.flat(L([(47, 21), (46, 25)], 1), gold)
    draw_leaf(up, 22, 16, -2.3 + w(1, 0.08), 6, 1.8, GREEN_L)  # leaf tips on the wings
    draw_leaf(up, 49, 15, -0.8 - w(1, 0.08), 6, 1.8, GREEN_L)
    blush(up, PINK_L)
    smile(up)
    # a side lock over the front shoulder, tied with an ochre ribbon, and a blossom
    up.part(P([(46, 22), (49, 24), (50 - w(1, 1), 36), (47 - w(2, 1), 40), (46, 30)]), BROWN, shade=False)
    up.flat(R((47, 34, 50, 35)), YELLOW)
    up.part(E((44, 8, 50, 14)), ORANGE)
    up.dot(47, 11, YELLOW)
    up.part(E((16, 10, 21, 15)), WHITE)
    up.dot(18, 12, YELLOW)
    return low, up


# ---------------------------------------------------------------------------------------------------------------
# B: "Meadow Maiden" -- a delicate green leaf masquerade mask on ribbons, auburn hair in two long twin braids with a
# flower crown, cream blouse with puff sleeves under a bark-brown corset pinafore, tiered petal skirt.

def eden_b(step=None, t=0):
    low = Canvas()
    for x, dy in legs(low, WHITE, GREEN_D, step):  # cream stockings, moss-green ankle boots
        low.flat(R((x, 54 + dy, x + 5, 54 + dy)), STEEL)
        low.dot(x + 1, 56 + dy, GREEN_L)
    up = Canvas()
    w = lambda lag, amp: wave(t, lag, amp)
    # twin braids behind her shoulders, tips swaying
    for side, bx in ((-1, 16), (1, 50)):
        sw = round(w(2, 1)) * side
        up.part(P([(bx - 3, 24), (bx + 3, 24), (bx + 3 + sw, 44), (bx - 3 + sw, 44)]), MAROON)
        for y in range(26, 44, 3):  # plait cross-hatching
            up.flat(L([(bx - 2 + sw * (y - 24) // 20, y), (bx + 2 + sw * (y - 24) // 20, y + 1)], 1), ORANGE if y % 6 == 2 else SHADOW)
        up.flat(R((bx - 3 + sw, 44, bx + 3 + sw, 45)), YELLOW)
        up.part(P([(bx - 2 + sw, 46), (bx + 2 + sw, 46), (bx + sw, 50)]), MAROON, shade=False)
    # puff sleeves in cream linen with a moss ribbon at the cuff
    up.part(E((ARM_X[0] + 1, 41, ARM_X[0] + 5, 45)), SKIN)
    up.part(E((ARM_X[0] - 1, 34, ARM_X[0] + 7, 42)), WHITE)
    up.flat(R((ARM_X[0] + 1, 41, ARM_X[0] + 5, 41)), GREEN)
    # tiered petal skirt: moss upper tier, ochre lower tier, both with scalloped hems
    up.part(P([(20, 42), (44, 42), (51, 51), (13, 51)]), YELLOW)
    for x in range(15, 50, 5):  # lower-tier petals
        up.part(E((x, 47, x + 6, 52)), YELLOW, line=False)
        up.dot(x + 3, 49, ORANGE)
    up.part(P([(20, 41), (44, 41), (48, 47), (16, 47)]), GREEN, line=False)
    for x in range(17, 48, 6):  # upper-tier petals
        up.part(E((x, 43, x + 7, 49)), GREEN, line=False)
        up.flat(L([(x + 3, 45), (x + 3, 47)], 1), GREEN_D)
        up.dot(x + 2, 46, GREEN_L)
    up.flat(R((19, 42, 45, 42)), GREEN_L)
    # blouse, bark-brown corset pinafore with a sweetheart scoop and straps, cream lacing
    up.part(RR((21, 33, 43, 43), 3), WHITE)
    up.flat(L([(23, 35), (23, 40)], 1), STEEL)
    up.part(P([(22, 38), (27, 37), (30, 38), (33, 40), (36, 38), (39, 37), (42, 38), (42, 44), (22, 44)]), BROWN)
    up.flat(L([(22, 38), (27, 37), (30, 38), (33, 40), (36, 38), (39, 37), (42, 38)], 1), SKIN_D)
    up.flat(R((25, 33, 26, 37)), BROWN)  # straps
    up.flat(R((39, 33, 40, 37)), BROWN)
    up.flat(L([(31, 41), (33, 43), (31, 43)], 1), WHITE)
    up.flat(L([(35, 41), (33, 43), (35, 43)], 1), WHITE)
    up.flat(R((23, 43, 41, 43)), MAROON)
    up.flat(L([(23, 40), (23, 42)], 1), SKIN_D)
    # vine belt, wooden pendant, gourd canteen on the hip
    up.flat(L([(21, 43), (28, 44), (36, 44), (43, 43)], 1), GREEN_D)
    for x in (24, 30, 38):
        draw_leaf(up, x, 44, HALF + 0.5, 3, 1.1, GREEN_L, shade=False)
    up.part(E((31, 39, 34, 42)), SKIN_D)
    up.dot(32, 40, YELLOW)
    gx = round(w(1, 1))
    up.flat(L([(40, 44), (40 + gx, 46)], 1), BROWN)
    up.part(E((37 + gx, 46, 43 + gx, 52)), SKIN_D)
    up.flat(R((39 + gx, 45, 40 + gx, 46)), BROWN)
    up.dot(38 + gx, 48, YELLOW)
    # front sleeve
    up.part(E((ARM_X[1] + 1, 41, ARM_X[1] + 5, 45)), SKIN)
    up.part(E((ARM_X[1] - 1, 34, ARM_X[1] + 7, 42)), WHITE)
    up.flat(R((ARM_X[1] + 1, 41, ARM_X[1] + 5, 41)), GREEN)
    # head: auburn
    up.part(RR((15, 6, 48, 36), 9), MAROON)
    up.part(RR(FACE, FACE_R), SKIN)
    # curtain bangs parted over the bridge, soft lengths framing the cheeks
    up.part(P([(22, 20), (22, 12), (28, 8), (37, 7), (44, 9), (48, 15), (45, 14), (41, 17), (38, 14), (34, 17),
               (31, 14), (27, 18), (25, 24)]), MAROON, shade=False)
    up.flat(L([(27, 10), (34, 8)], 1), ORANGE)
    up.flat(L([(38, 9), (42, 10)], 1), ORANGE)
    up.part(P([(20, 15), (24, 17), (24, 30), (22, 34), (18, 27)]), MAROON, shade=False)
    # leaf masquerade mask: two pointed leaves flaring into cat-eye tips, joined by an ochre knot
    leaf_l = [(19, 13), (24, 12), (30, 13), (36, 17), (33, 19), (27, 19), (22, 17)]
    leaf_r = [(38, 17), (43, 13), (48, 12), (52, 13), (49, 17), (44, 19), (40, 19)]
    up.part(P(leaf_l), GREEN_L)
    up.part(P(leaf_r), GREEN_L)
    big_eyes(up, EYES_Y, EYES_X, GREEN)
    up.flat(L([(20, 14), (26, 15), (34, 17)], 1), GREEN)  # midribs
    up.flat(L([(51, 13), (46, 15), (40, 17)], 1), GREEN)
    for x, y in ((24, 17), (28, 17), (31, 16), (43, 17), (47, 15)):  # side veins
        up.dot(x, y, GREEN)
    up.flat(R((36, 16, 38, 18)), YELLOW)  # knot
    up.dot(37, 17, ORANGE)
    up.flat(L([(19, 13), (15 - w(1, 1), 20), (14 - w(2, 1), 25)], 1), GREEN_D)  # ribbon tails
    blush(up, PINK_L)
    smile(up)
    # flower crown over the fringe: cream and ochre blooms, leaves between
    for x, y, a in ((24, 9, -2.4), (31, 6, -2.0), (38, 5, -1.4), (45, 8, -0.8)):
        draw_leaf(up, x, y, a, 6, 1.6, GREEN, shade=False)
    for i, (x, y) in enumerate(((21, 11), (28, 7), (35, 5), (42, 6), (47, 10))):
        up.part(E((x - 2, y - 2, x + 2, y + 2)), (WHITE, YELLOW, WHITE, ORANGE, WHITE)[i])
        up.dot(x, y, (YELLOW, ORANGE, YELLOW, YELLOW, ORANGE)[i])
    return low, up


# ---------------------------------------------------------------------------------------------------------------
# C: "Barkwood Druid" -- carved wooden circlet with a leaf gem and slim leaf-wing eye band, deep forest-green hair in a
# high messy bun with leaf sprigs, bark-brown wrap bodice, long petal-hem skirt, hooded forest mantle, lantern gourd.

def eden_c(step=None, t=0):
    low = Canvas()
    for x, dy in legs(low, SKIN_D, BROWN, step):  # terracotta leggings, bark boots
        low.flat(R((x, 54 + dy, x + 5, 54 + dy)), STEEL)
        low.flat(R((x - 1, 55 + dy, x + 6, 55 + dy)), SKIN_D)
    up = Canvas()
    w = lambda lag, amp: wave(t, lag, amp)
    # back arm: bark brown sleeve, bare hand
    up.part(E((ARM_X[0] + 1, 41, ARM_X[0] + 5, 45)), SKIN)
    up.part(RR((ARM_X[0], 35, ARM_X[0] + 6, 42), 3), BROWN)
    up.flat(R((ARM_X[0], 41, ARM_X[0] + 5, 41)), YELLOW)
    # layered skirt: terracotta with bark folds, a leaf-pointed cream petticoat edge below
    up.part(P([(20, 41), (44, 41), (50, 50), (14, 50)]), SKIN_D)
    for x, d in ((20, -1), (25, -1), (39, 1), (44, 1)):
        up.flat(L([(x, 45), (x + d * 2, 49)], 1), BROWN)
    up.flat(L([(22, 43), (18, 48)], 1), YELLOW)
    up.flat(R((16, 46, 48, 46)), YELLOW)
    for x in range(15, 49, 7):
        up.part(P([(x, 48), (x + 7, 48), (x + 4, 53), (x + 3, 53)]), WHITE, line=False)
        up.flat(L([(x + 3, 49), (x + 3, 51)], 1), STEEL)
    for x in range(19, 46, 6):
        up.dot(x, 48, ORANGE)
    # wrap bodice: cream crossover collar over bark brown, a low scoop with a wooden pendant
    up.part(RR((21, 33, 43, 43), 3), BROWN)
    up.flat(P([(25, 36), (40, 36), (38, 38), (34, 41), (32, 40), (29, 38)]), SKIN)
    up.part(P([(22, 34), (29, 36), (34, 43), (22, 43)]), WHITE, line=False)  # left wrap flap
    up.part(P([(43, 34), (37, 36), (33, 43), (43, 43)]), WHITE, line=False)
    up.flat(P([(26, 36), (30, 38), (33, 41), (30, 41), (27, 39)]), BROWN)
    up.flat(P([(38, 36), (36, 38), (33, 41), (36, 41), (38, 39)]), BROWN)
    up.flat(L([(25, 36), (30, 38), (33, 41), (36, 38), (40, 36)], 1), YELLOW)
    up.flat(L([(23, 38), (23, 42)], 1), STEEL)
    up.part(E((31, 39, 35, 43)), SKIN_D)  # pendant: a carved wooden seed
    up.flat(L([(33, 40), (33, 42)], 1), MAROON)
    up.dot(32, 40, YELLOW)
    # vine belt, seed pouch
    up.flat(L([(21, 43), (27, 44), (38, 44), (43, 43)], 1), GREEN_D)
    for x in (24, 40):
        draw_leaf(up, x, 44, HALF + 0.4, 4, 1.3, GREEN_L, shade=False)
    px = round(w(2, 1))
    up.part(RR((17 + px, 44, 22 + px, 49), 1), BROWN)
    up.flat(R((17 + px, 44, 22 + px, 45)), GREEN)
    up.dot(19 + px, 47, YELLOW)
    # short ochre fringed shawl over the shoulders
    up.part(P([(19, 33), (26, 32), (28, 37), (24, 41 + round(w(1, 0.5))), (19, 40)]), YELLOW)
    up.part(P([(45, 33), (38, 32), (36, 37), (40, 41 + round(w(2, 0.5))), (45, 40)]), YELLOW)
    for x in (20, 22, 24, 38, 41, 43):
        up.dot(x, 42, ORANGE)
    up.flat(L([(21, 35), (23, 38)], 1), ORANGE)
    up.flat(L([(42, 35), (40, 38)], 1), ORANGE)
    # front arm
    up.part(E((ARM_X[1] + 1, 41, ARM_X[1] + 5, 45)), SKIN)
    up.part(RR((ARM_X[1], 37, ARM_X[1] + 6, 42), 3), BROWN)
    up.flat(R((ARM_X[1], 41, ARM_X[1] + 5, 41)), YELLOW)
    # head: leaf-green hair, a long tail down the back
    up.part(P([(16, 14), (14, 28), (13 - w(1, 1), 38), (16 - w(2, 1), 44), (21 - w(3, 1), 40), (23, 28)]), GREEN_D)
    up.flat(L([(16, 22), (16, 31), (16 - w(2, 1), 39)], 1), GREEN)
    up.part(RR((15, 6, 48, 36), 9), GREEN_D)
    up.flat(L([(20, 10), (27, 7)], 1), GREEN)
    up.part(RR(FACE, FACE_R), SKIN)
    # centre-swept fringe
    up.part(P([(22, 20), (22, 12), (28, 8), (37, 7), (44, 9), (48, 15), (46, 20), (43, 15), (38, 14), (33, 17),
               (29, 14), (26, 19), (25, 26)]), GREEN_D, shade=False)
    up.flat(L([(26, 10), (32, 8)], 1), GREEN)
    up.flat(L([(36, 9), (42, 10)], 1), GREEN)
    up.part(P([(20, 15), (24, 17), (24, 31), (22, 36 + round(w(2, 1))), (18, 28)]), GREEN_D, shade=False)
    # carved circlet across the brow with a leaf gem, plus mask-like winged eye marks in bark
    up.part(P([(21, 14), (27, 11), (35, 10), (43, 11), (48, 14), (48, 16), (43, 14), (35, 13), (27, 14), (21, 17)]),
            BROWN)
    up.flat(L([(23, 14), (28, 12), (35, 11)], 1), SKIN_D)
    draw_leaf(up, 35, 12, -HALF, 6, 2.0, YELLOW)  # gilded leaf gem
    draw_leaf(up, 29, 12, -2.2, 5, 1.6, GREEN_L, shade=False)
    draw_leaf(up, 41, 12, -0.95, 5, 1.6, GREEN_L, shade=False)
    big_eyes(up, EYES_Y, EYES_X, YELLOW)
    blush(up, PINK_L)
    smile(up)
    return low, up


def eden_c_crown(t, dy):
    """A messy high bun tied with a vine, leaves and a bloom poking out, behind and above her head."""
    c = Canvas(CELL)
    ox, oy = PAD, PAD + UPPER_DY + dy
    wv = lambda lag, amp: round(wave(t, lag, amp))
    c.part(E((ox + 27, oy - 6, ox + 41, oy + 7)), g.GREEN_D)
    c.flat(L([(ox + 29, oy - 3), (ox + 34, oy - 4)], 1), g.GREEN)
    c.flat(R((ox + 28, oy + 2, ox + 40, oy + 3)), YELLOW)
    for x, a_, ln, col in ((ox + 31, -2.5, 7, GREEN), (ox + 37, -0.65, 7, GREEN), (ox + 34, -1.57, 9, GREEN_L)):
        draw_leaf(c, x, oy - 4, a_ + wv(1, 0.07), ln, 2.2, col, rib=g.DARKER[col])
        return c


RED_L = ORANGE  # auburn sheen


# ---------------------------------------------------------------------------------------------------------------
VARIANTS = {"a": ("A  Wayfarer", eden_a, blank_crown), "b": ("B  Meadow Maiden", eden_b, blank_crown),
            "c": ("C  Barkwood Druid", eden_c, eden_c_crown)}
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
    """The dark arena floor tile (pit_tiles), repeated."""
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
    H = max(big.height + 56, 56 + s2.height * 2 + 16 + 70)
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
    extras = [("Sakura (2x)", sheet_frame("sakura")), ("Current Eden (2x)", sheet_frame("eden"))]
    panels = []
    for k, (label, build, crown) in VARIANTS.items():
        p = panel(label, idle(build, crown), extras)
        p.convert("RGB").save(out / f"eden_{k}.png")
        panels.append(p)
    W = max(p.width for p in panels)
    sheet = Image.new("RGB", (W, sum(p.height for p in panels)), (24, 24, 36))
    y = 0
    for p in panels:
        sheet.paste(p.convert("RGB"), (0, y))
        y += p.height
    sheet.save(out / "eden_concepts.png")
    print("wrote previews to", out)


if __name__ == "__main__":
    main()
