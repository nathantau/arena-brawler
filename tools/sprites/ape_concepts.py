"""Great Ape (Apex's transform) premium-detail CONCEPTS (design stage only; not wired into generate.py's sheets).
Three idle-frame variants of the ape, drawn next to normal Apex and the current Great Ape:
  A  Roar      - mouth wide open, bellowing
  B  Snarl     - low menacing snarl, scar across the left eye
  C  Berserker - glowing cracks and steam venting through the broken armour
Each has: broken gold armour (split pauldrons hanging by a strap, cracked chest plate with a dark gap showing fur, snapped
bracers, shards, dents / scratches / glints), a darker rougher face (furrowed brow ridge shadowing slanted glowing eyes,
wrinkled snout, flared nostrils, fangs), shaggy dithered fur and torn sash scraps. Palette: existing colours only.
Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts.py [out_png]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import generate as g
from generate import Canvas, E, L, P, R, RR, CELL, PAD, UPPER_DY, IDLE_BOB, outline
from palette import (BROWN, MAROON, ORANGE, OCHRE_D, OUTLINE, RED, SHADOW, SKIN, SKIN_D, STEEL, STEEL_D, WALNUT, WALNUT_D,
                     WALNUT_L, WHITE, YELLOW)

GOLD, GOLD_L, GOLD_D, GOLD_X = ORANGE, YELLOW, OCHRE_D, BROWN  # mid, lit, shaded, deepest


# --- helpers ------------------------------------------------------------------------------------------------------

def mask_of(shape, n=64):
    m = Image.new("1", (n, n), 0)
    shape(ImageDraw.Draw(m), 1)
    return m


def metal(c, shape, glint=True, lo2=True):
    """Shaded gold plate: mid gold, lit top-left edge, dark gold bottom-right edge (2 px deep -> deepest at the very
    edge), one white glint, selective outline against what is already there."""
    c.part(shape, GOLD, shade=False, line=True)
    m = mask_of(shape, c.size).load()
    n = c.size
    ins = lambda x, y: 0 <= x < n and 0 <= y < n and m[x, y]
    first = None
    for y in range(n):
        for x in range(n):
            if not ins(x, y):
                continue
            if not ins(x, y + 1) or not ins(x + 1, y):
                c.px[x, y] = (GOLD_X if lo2 and (not ins(x, y + 2) and not ins(x + 2, y)) else GOLD_D) + (255,)
            elif not ins(x, y + 2) or not ins(x + 2, y):
                c.px[x, y] = GOLD_D + (255,)
            elif not ins(x, y - 1) or not ins(x - 1, y):
                c.px[x, y] = GOLD_L + (255,)
                if first is None:
                    first = (x, y)
    if glint and first:
        c.dot(first[0] + 1, first[1], WHITE)


def px(c, pts, color):
    for x, y in pts:
        c.dot(x, y, color)


def seam(c, pts, color=OUTLINE):
    c.flat(L(pts, 1), color)


def scratch(c, x, y, n=3):
    """A diagonal scratch with a specular glint at its lit end."""
    for i in range(n):
        c.dot(x + i, y + i, GOLD_X)
    c.dot(x - 1, y - 1, WHITE)


def dent(c, x, y):
    c.dot(x, y, GOLD_X)
    c.dot(x + 1, y, GOLD_D)
    c.dot(x, y + 1, GOLD_D)
    c.dot(x - 1, y - 1, GOLD_L)


def soften(c, region):
    """Dither fur transitions: MAROON next to a lit (RED, up/left) or shaded (SHADOW, down/right) neighbour takes it
    on a checker, so shaded fur has a soft stipple instead of a hard band."""
    x0, y0, x1, y1 = region
    src = c.img.copy().load()
    col = lambda x, y: src[x, y][:3] if 0 <= x < c.size and 0 <= y < c.size and src[x, y][3] else None
    for y in range(y0, y1):
        for x in range(x0, x1):
            if col(x, y) != MAROON:
                continue
            if (x + y) % 2 == 0 and (col(x - 1, y) == RED or col(x, y - 1) == RED):
                c.dot(x, y, RED)
            elif (x + y) % 2 == 1 and (col(x + 1, y) == SHADOW or col(x, y + 1) == SHADOW):
                c.dot(x, y, SHADOW)
            elif (x + y) % 2 == 0 and col(x, y + 2) == SHADOW and col(x, y + 1) == MAROON:
                c.dot(x, y + 1, SHADOW)


def dither_fill(c, box, color, over=(MAROON,), phase=0):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            if (x + y + phase) % 2 == 0 and c.px[x, y][3] and c.px[x, y][:3] in over:
                c.dot(x, y, color)


def fur(c, shape, line=True):
    """A fur clump: MAROON with a 1 px lit RED edge top-left and a 1 px SHADOW edge bottom-right (thin, so small
    clumps keep their colour)."""
    before = c.img.copy().load()
    c.part(shape, MAROON, shade=False, line=line)
    m = mask_of(shape, c.size).load()
    n = c.size
    ins = lambda x, y: 0 <= x < n and 0 <= y < n and m[x, y]
    for y in range(n):
        for x in range(n):
            if not ins(x, y):
                continue
            if not ins(x, y + 1) or not ins(x + 1, y):
                edge = (not ins(x, y + 1) and not before[x, min(y + 2, n - 1)][3]) or (
                    not ins(x + 1, y) and not before[min(x + 2, n - 1), y][3])
                if edge or (x + y) % 2 == 1:
                    c.dot(x, y, SHADOW)
            elif (not ins(x, y - 1) or not ins(x - 1, y)) and (x + y) % 2 == 0:
                c.dot(x, y, RED)


def tuft(c, x, y, w=6, h=5, flip=False, color=MAROON):
    pts = [(x, y + h), (x + w // 2, y), (x + w, y + h)] if not flip else [(x, y), (x + w // 2, y + h), (x + w, y)]
    fur(c, P(pts))


def band(c, shape, mid, lit, dark):
    """Flat part with a 1 px lit top-left edge and 1 px dark bottom-right edge (no outline)."""
    c.part(shape, mid, shade=False, line=True)
    m = mask_of(shape, c.size).load()
    n = c.size
    ins = lambda x, y: 0 <= x < n and 0 <= y < n and m[x, y]
    for y in range(n):
        for x in range(n):
            if ins(x, y):
                if not ins(x, y + 1) or not ins(x + 1, y):
                    c.dot(x, y, dark)
                elif (not ins(x, y - 1) or not ins(x - 1, y)) and (x + y) % 2 == 0:
                    c.dot(x, y, lit)


def strands(c, lst, color=SHADOW, lit=RED):
    for x, y, n in lst:  # a short down-left stroke with a lit pixel beside its top
        for i in range(n):
            c.dot(x - i // 2, y + i, color)
        c.dot(x + 1, y, lit)


def steam(c, x, y, n=4, drift=1, phase=0):
    """A wisp rising from a vent: alternating 2x2 / 1x1 puffs, white at the base thinning to steel."""
    for i in range(n):
        cx = x + (drift if i % 2 else 0) * (1 if (i + phase) % 4 < 2 else -1) + (i // 2) * drift
        cy = y - i * 3
        col = (WHITE, STEEL, STEEL, STEEL_D)[min(i, 3)]
        c.dot(cx, cy, col)
        if i < 3:
            c.dot(cx + 1, cy, col)
            c.dot(cx, cy - 1, col)
        if i < 2:
            c.dot(cx + 1, cy - 1, col)


# --- the ape ------------------------------------------------------------------------------------------------------

def ape(v, step=None, t=0):
    """Variant `v` in 'A' (roar), 'B' (snarl + scar), 'C' (berserker). Returns (low, up) like generate.py characters."""
    low = Canvas()
    for x, (dx, dy) in zip((21, 35), WALK := ((0, 0), (0, 0))):
        x += dx
        low.part(P([(x, 44 + dy), (x + 8, 44 + dy), (x + 9, 54 + dy), (x - 1, 54 + dy)]), MAROON)
        low.part(E((x - 5, 54 + dy, x, 58 + dy)), BROWN)
        low.part(RR((x - 2, 53 + dy, x + 10, 58 + dy), 2), BROWN)
        for tx in (x + 4, x + 7):
            low.flat(R((tx, 56 + dy, tx, 58 + dy)), OUTLINE)
        low.flat(R((x - 1, 58 + dy, x + 9, 58 + dy)), SHADOW)
        # leg fur: shaggy shins and a worn greave strap
        strands(low, [(x + 3, 47, 3)])
        low.flat(R((x - 1, 52, x + 9, 52)), GOLD_D)  # remains of a greave strap
        low.dot(x, 52, GOLD_L)
        low.dot(x + 5, 52, GOLD_X)
    up = Canvas()
    s = g.SWAY[t % 4]
    up.part(L([(14, 40), (6, 38), (4, 31), (8, 27 + s)], 3), MAROON)  # tail
    # shaggy mane: clumps of fur bristling off the shoulders and back
    for x, y, w, h in ((3, 22, 9, 9), (5, 32, 8, 7), (7, 12, 9, 10), (14, 6, 9, 10), (23, 2, 8, 8)):
        tuft(up, x, y, w, h)  # shaggy shoulder mane, bristling up and back
    fur(up, E((10, 14, 54, 45)))  # hunched back and shoulders
    for x, y in ((12, 16), (18, 11), (25, 8)):
        tuft(up, x, y, 7, 7)
    up.part(E((22, 26, 44, 43)), BROWN)  # chest fur
    strands(up, [(25, 44, 3), (28, 44, 3), (39, 44, 3), (42, 43, 3)], color=MAROON, lit=SKIN_D)
    # ---- arms: knuckle-walking, thick with ridged muscle
    arms, fists = g.APE_POSES["walk"]
    for (sx, sy), (ex, ey), (wx, wy) in arms:
        fur(up, L([(sx, sy), (ex, ey), (wx, wy)], 9))
        fur(up, E((sx - 6, sy - 6, sx + 6, sy + 6)))
        bx, by = (sx + ex) // 2, (sy + ey) // 2
        fur(up, E((bx - 6, by - 5, bx + 6, by + 5)))
        fx, fy = (ex * 2 + wx) // 3, (ey * 2 + wy) // 3
        fur(up, E((fx - 5, fy - 4, fx + 5, fy + 4)))
    strands(up, [(11, 36, 3), (16, 38, 3), (51, 36, 3), (54, 40, 3)])
    # ---- chest: broken breastplate, split down a jagged break with a dark gap showing fur
    gap = [(31, 35), (35, 35), (36, 37), (34, 39), (36, 41), (34, 43), (35, 45), (31, 45), (30, 43), (32, 41), (29, 39), (31, 37)]
    up.part(P(gap), WALNUT_D, shade=False, line=False)
    up.flat(L([(31, 37), (32, 39), (31, 42), (33, 44)], 1), RED)  # fur showing in the gap
    up.dot(33, 41, MAROON)
    up.dot(32, 38, MAROON)
    metal(up, P([(22, 37), (25, 35), (28, 36), (30, 35), (31, 37), (29, 39), (31, 41), (30, 43), (31, 45), (25, 46), (22, 42)]))
    metal(up, P([(36, 35), (39, 36), (42, 35), (44, 40), (43, 45), (37, 46), (35, 43), (36, 41), (34, 39), (36, 37)]))
    seam(up, [(24, 40), (29, 40)], GOLD_D)  # lames
    seam(up, [(38, 40), (42, 40)], GOLD_D)
    up.dot(25, 38, WHITE)
    up.dot(26, 39, GOLD_X)
    up.dot(40, 38, WHITE)
    up.dot(41, 39, GOLD_X)
    dent(up, 27, 42)
    dent(up, 39, 42)
    scratch(up, 24, 37, 2)
    scratch(up, 37, 37, 2)
    up.flat(R((25, 44, 27, 44)), GOLD_X)  # torn lower edge
    # shards of plate fallen on the floor
    for pts in (([(4, 53), (7, 52), (6, 55)]), ([(55, 53), (58, 52), (57, 55)]), ([(53, 46), (55, 45), (55, 48)])):
        metal(up, P(pts), lo2=False)
    # ---- split pauldron on the back shoulder: top half cracked on the shoulder, lower half hanging by a strap
    metal(up, P([(8, 25), (9, 20), (14, 17), (19, 18), (20, 21), (16, 21), (14, 24), (11, 22)]))
    seam(up, [(14, 18), (13, 20), (15, 21)], GOLD_X)  # crack
    dent(up, 16, 19)
    seam(up, [(13, 23), (11, 27)], BROWN)  # leather strap
    metal(up, P([(6, 28), (11, 27), (12, 31), (10, 34), (7, 34), (5, 31)]))
    scratch(up, 7, 29, 2)
    up.dot(9, 32, WHITE)
    # front shoulder: a smaller half-pauldron, torn
    metal(up, P([(48, 24), (53, 20), (57, 23), (56, 27), (53, 26), (51, 28)]))
    seam(up, [(53, 21), (54, 24), (52, 25)], GOLD_X)
    dent(up, 51, 23)
    seam(up, [(57, 26), (58, 30)], BROWN)  # strap dangling the lost half
    # ---- snapped bracers
    for (x0, y0) in ((13, 41), (43, 41)):
        metal(up, P([(x0, y0), (x0 + 5, y0), (x0 + 4, y0 + 1), (x0 + 3, y0 + 3), (x0, y0 + 3)]))  # near half
        metal(up, P([(x0 + 6, y0 + 1), (x0 + 9, y0 + 1), (x0 + 9, y0 + 4), (x0 + 5, y0 + 4), (x0 + 6, y0 + 3)]), lo2=False)
        up.dot(x0 + 5, y0 + 2, OUTLINE)
    # ---- fists on the ground
    for i, (x, y, thumb) in enumerate(fists):
        y += 0
        up.part(RR((x, y, x + 12, y + 11), 3), MAROON)
        up.part(E((x + thumb, y + 1, x + thumb + 5, y + 6)), MAROON)
        up.flat(RR((x + 1, y + 6, x + 11, y + 11), 1), BROWN)
        for kx in (x + 4, x + 7):
            up.flat(R((kx, y + 6, kx, y + 11)), OUTLINE)
        up.flat(R((x + 1, y + 6, x + 11, y + 6)), OUTLINE)
        for kx in (x + 2, x + 5, x + 8):  # lit knuckles
            up.dot(kx, y + 7, SKIN_D)
        up.dot(x + 3, y + 9, SHADOW)
    # torn sash scraps hanging from the belt
    for pts, x in (([(20, 44), (24, 44), (24, 49), (23, 52), (22, 49), (21, 53), (20, 49)], 20),
                   ([(41, 44), (46, 44), (47, 48), (45, 51), (45, 47), (43, 50), (42, 46)], 41)):
        up.part(P(pts), RED)
    up.dot(21, 52, MAROON)
    up.dot(44, 50, MAROON)
    # ---- head
    for x, y, w, h in ((19, 12, 6, 8), (21, 4, 6, 7), (28, 1, 6, 6), (17, 19, 6, 6)):  # mane tufts round the skull
        tuft(up, x, y, w, h)
    up.part(E((24, 3, 50, 29)), MAROON)  # skull
    for x, y, w, h in ((48, 12, 8, 8), (49, 20, 8, 8), (47, 27, 7, 7)):  # side whiskers / cheek ruff
        fur(up, P([(x, y), (x + w, y + h // 2), (x, y + h)]))
    up.part(RR((28, 10, 51, 30), 7), WALNUT, shade=False)  # dark rough face mask
    up.part(E((29, 21, 51, 35)), WALNUT, shade=False)  # heavy jaw
    up.flat(L([(30, 12), (29, 22), (31, 29)], 1), WALNUT_D)  # shaded edge towards the neck
    up.part(E((32, 18, 47, 28)), WALNUT, shade=False, line=False)  # muzzle
    up.flat(R((33, 12, 36, 12)), WALNUT_L)  # forehead ridge glints
    up.flat(R((44, 12, 46, 12)), WALNUT_L)
    # circlet, askew, cracked and chipped
    up.part(P(g.APE_CIRCLET), YELLOW)
    up.flat(R((35, 7, 36, 7)), RED)
    for crack in g.APE_CRACKS:
        up.flat(L(crack, 1), OUTLINE)
    up.flat(P([(43, 4), (47, 4), (47, 6)]), OUTLINE)
    up.flat(P([(23, 11), (26, 12), (24, 13)]), OUTLINE)
    # brow ridge: a thick furrowed band slanting to the middle, shadowing the eyes
    band(up, P([(28, 11), (32, 11), (40, 16), (40, 18), (37, 18), (28, 14)]), WALNUT, WALNUT_L, WALNUT_D)
    band(up, P([(51, 10), (47, 11), (39, 16), (39, 18), (42, 18), (51, 14)]), WALNUT, WALNUT_L, WALNUT_D)
    up.flat(R((39, 13, 39, 19)), OUTLINE)  # furrow between the brows
    up.flat(R((40, 14, 40, 18)), WALNUT_D)
    up.flat(L([(36, 14), (37, 16)], 1), WALNUT_D)
    up.flat(L([(43, 14), (42, 16)], 1), WALNUT_D)
    # eyes: dark socket, slanted slit, red glow, orange body, bright core
    ex = {"A": 1.0, "B": 0.8, "C": 1.0}[v]
    L_EYE = [(32, 18), (33, 18), (34, 18), (35, 19), (36, 19), (37, 19)]
    R_EYE = [(79 - x, y) for x, y in L_EYE]
    for sx0 in (31, 41):
        up.flat(R((sx0, 18, sx0 + 7, 20)), OUTLINE)  # socket under the brow
        up.flat(R((sx0, 17, sx0 + 7, 17)), OUTLINE)
    for eye, side in ((L_EYE, 0), (R_EYE, 1)):
        if v == "B" and side == 0:
            continue
        for x, y in eye:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) not in eye and ny >= 18 and up.px[nx, ny][:3] == OUTLINE:
                    up.dot(nx, ny, RED)  # 1 px glow
        for x, y in eye:
            up.dot(x, y, ORANGE)
        cx = eye[2] if side == 0 else eye[2]
        up.dot(cx[0] + (0 if side else 0), cx[1], YELLOW)
        up.dot(eye[3][0], eye[3][1], YELLOW)
    if v == "C":  # berserker: eyes blaze white-hot
        for eye in (L_EYE, R_EYE):
            up.dot(eye[2][0], eye[2][1], WHITE)
            up.dot(eye[3][0], eye[3][1], WHITE)
    if v == "B":  # scarred left eye: a pale diagonal slash splits the lid, the eye below is just a dim ember
        for x, y in L_EYE:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) not in L_EYE and ny >= 18 and up.px[nx, ny][:3] == OUTLINE:
                    up.dot(nx, ny, MAROON)
        for x, y in L_EYE:
            up.dot(x, y, RED)
        up.dot(33, 18, ORANGE)
        up.dot(34, 18, ORANGE)
        up.dot(35, 19, ORANGE)
        for x, y in ((32, 12), (33, 14), (34, 16), (35, 18), (36, 20), (37, 22), (38, 24)):
            up.dot(x, y, SKIN)  # a raised pale slash running through the eye
            up.dot(x + 1, y, SKIN_D)
            up.dot(x + 1, y + 1, SKIN_D)
            up.dot(x - 1, y + 1, OUTLINE)
        up.dot(34, 16, WHITE)
        up.dot(36, 20, WHITE)
        for y in (13, 15, 17, 19):
            up.dot(31 + (y - 13) // 2 * 1, y, OUTLINE)  # stitch marks
    # snout: wrinkles, flared nostrils
    for pts in (([(33, 21), (32, 23), (33, 25)]), ([(46, 21), (47, 23), (46, 25)]), ([(35, 20), (34, 22)]), ([(44, 20), (45, 22)])):
        up.flat(L(pts, 1), WALNUT_D)
    for x in (33, 46):
        up.dot(x - 1 if x < 40 else x + 1, 22, WALNUT_L)
    up.flat(P([(35, 22), (37, 21), (38, 23), (36, 24)]), OUTLINE)  # nostrils, flared wings
    up.flat(P([(44, 22), (42, 21), (41, 23), (43, 24)]), OUTLINE)
    up.dot(36, 22, RED)
    up.dot(43, 22, RED)
    up.dot(39, 21, WALNUT_L)  # nose-bridge highlight
    up.dot(40, 21, WALNUT_L)
    up.flat(L([(39, 22), (40, 22)], 1), WALNUT_D)
    # cheek bones / jaw muscle
    up.dot(31, 22, WALNUT_L)
    up.dot(30, 24, WALNUT_L)
    up.dot(48, 22, WALNUT_D)
    # ---- mouths
    if v == "A":  # roar: jaw dropped, throat dark, tongue, long fangs top and bottom
        up.flat(P([(31, 26), (48, 26), (49, 29), (47, 33), (42, 35), (37, 35), (32, 33), (30, 29)]), OUTLINE)
        up.flat(P([(34, 31), (44, 31), (43, 34), (38, 35), (35, 34)]), MAROON)  # tongue
        up.flat(R((36, 32, 41, 32)), RED)
        up.flat(R((32, 26, 47, 26)), RED)  # gum line
        for x in (34, 36, 38, 41, 43):
            up.flat(R((x, 27, x, 28)), WHITE)  # small upper teeth
        for x0 in (32, 45):  # upper canines
            up.flat(P([(x0, 26), (x0 + 2, 26), (x0 + 2, 28), (x0 + 1, 31), (x0, 28)]), WHITE)
            up.dot(x0 + 1, 28, STEEL)
            up.dot(x0 + 1, 29, STEEL)
            up.dot(x0 + 1, 30, STEEL_D)
        for x0 in (34, 43):  # lower canines
            up.flat(P([(x0, 34), (x0 + 3, 34), (x0 + 2, 30), (x0 + 1, 30)]), WHITE)
            up.dot(x0 + 2, 32, STEEL)
            up.dot(x0 + 2, 33, STEEL)
        up.flat(L([(31, 26), (30, 28)], 1), WALNUT_L)
    elif v == "B":  # low snarl: clenched, lip hitched up over the fangs, heavy jaw
        up.flat(P([(30, 30), (33, 27), (46, 27), (49, 30), (47, 32), (32, 32)]), OUTLINE)
        up.flat(R((34, 27, 45, 27)), RED)  # gum
        up.flat(P([(29, 28), (33, 26), (34, 28), (31, 30)]), WALNUT_D)  # lip hitched up, left
        up.flat(P([(50, 28), (46, 26), (45, 28), (48, 30)]), WALNUT_D)
        up.dot(30, 27, WALNUT_L)
        for x in (37, 39, 41):  # small clenched teeth
            up.dot(x, 28, WHITE)
            up.dot(x, 31, STEEL)
        for x0 in (33, 45):  # upper fangs, long
            up.flat(P([(x0, 27), (x0 + 2, 27), (x0 + 1, 32)]), WHITE)
            up.dot(x0 + 1, 30, STEEL)
        for x0 in (35, 43):  # lower canines
            up.flat(P([(x0, 33), (x0 + 1, 33), (x0 + 1, 30)]), WHITE)
        up.flat(R((33, 33, 45, 33)), WALNUT_D)
        up.flat(R((34, 34, 44, 34)), WALNUT_D)  # heavy underlip
        up.dot(29, 31, OUTLINE)
        up.dot(50, 31, OUTLINE)  # frown creases
    else:  # C: wide gritted snarl, throat glowing ember-orange
        up.flat(P([(31, 26), (48, 26), (49, 29), (46, 33), (41, 34), (37, 34), (33, 33), (30, 29)]), OUTLINE)
        up.flat(P([(34, 30), (45, 30), (43, 33), (36, 33)]), RED)  # glowing throat
        up.flat(P([(36, 31), (43, 31), (41, 33), (38, 33)]), ORANGE)
        up.flat(R((39, 32, 40, 32)), YELLOW)
        up.flat(R((32, 26, 47, 26)), RED)
        for x in (36, 38, 40, 42):
            up.dot(x, 27, WHITE)
        for x0 in (32, 45):
            up.flat(P([(x0, 26), (x0 + 2, 26), (x0 + 2, 28), (x0 + 1, 31), (x0, 28)]), WHITE)
            up.dot(x0 + 2, 28, STEEL)
            up.dot(x0 + 2, 29, STEEL)
        for x0 in (35, 43):
            up.flat(P([(x0, 33), (x0 + 1, 33), (x0 + 1, 30)]), WHITE)
    # ---- berserker: glowing cracks run through fur and armour, steam vents through the gaps
    if v == "C":
        for pts in (([(31, 36), (32, 39), (31, 42), (33, 45)]), ([(21, 40), (24, 41), (27, 44)]), ([(39, 40), (42, 41), (44, 44)]),
                    ([(15, 31), (18, 33), (17, 36)]), ([(50, 32), (52, 35), (50, 38)]), ([(14, 18), (16, 21)])):
            for x, y in pts:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if up.px[x + dx, y + dy][:3] in (MAROON, GOLD_D, GOLD_X, GOLD, BROWN, WALNUT_D, SHADOW):
                        up.dot(x + dx, y + dy, RED)
            seam(up, pts, ORANGE)
            up.dot(*pts[len(pts) // 2], YELLOW)
        steam(up, 33, 34, 3, 1, 0)
        steam(up, 8, 25, 5, -1, 2)
        steam(up, 56, 24, 5, 1, 1)
        steam(up, 4, 44, 3, -1, 3)
        steam(up, 58, 42, 3, 1, 0)
    # dithered shade in the dark underside of the fur (belly, under the arms, behind the legs)
    dither_fill(up, (14, 42, 52, 48), SHADOW, phase=0)
    dither_fill(up, (8, 33, 14, 41), SHADOW, phase=1)
    dither_fill(up, (52, 33, 58, 42), SHADOW, phase=1)
    soften(low, (0, 0, 64, 64))
    return low, up


# --- presentation -------------------------------------------------------------------------------------------------

def idle(build, aura, i=0):
    low, up = build(None, i)
    f = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    if aura:
        f.alpha_composite(aura(i).img, (PAD, PAD))
    f.alpha_composite(low.img, (PAD, PAD))
    f.alpha_composite(up.img, (PAD, PAD + UPPER_DY + IDLE_BOB[i]))
    return outline(f)


def font(n):
    try:
        return ImageFont.load_default(size=n)
    except TypeError:
        return ImageFont.load_default()


BOX = (PAD - 4, PAD - 2, PAD + 68, PAD + 66)  # 72 x 68 crop around the 64 px art


def floor(w, h):
    tiles = Image.open(g.ROOT / "assets" / "arenas" / "pit_tiles.png").convert("RGBA")
    a, b = tiles.crop((0, 0, 32, 32)), tiles.crop((32, 0, 64, 32))
    out = Image.new("RGBA", (w, h))
    for ty in range(0, h, 32):
        for tx in range(0, w, 32):
            out.paste(a if (tx // 32 + ty // 32) % 2 == 0 else b, (tx, ty))
    return out


def show(fr, zoom, scale=1.0):
    z = fr.crop(BOX)
    bg = floor(z.width, z.height)
    bg.alpha_composite(z)
    return bg.resize((round(z.width * zoom * scale), round(z.height * zoom * scale)), Image.NEAREST)


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else
               "/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/"
               "scratchpad/ape/ape_concepts.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    apex = idle(g.wukong, g.wukong_clouds)
    cur = idle(g.wukong_ape, g.ape_storm)
    cons = [("A  ROAR", idle(lambda s, i: ape("A", s, i), g.ape_storm)),
            ("B  SNARL + SCAR", idle(lambda s, i: ape("B", s, i), g.ape_storm)),
            ("C  BERSERKER", idle(lambda s, i: ape("C", s, i), g.ape_storm))]
    for k, (_, fr) in zip("abc", cons):
        fr.save(out.parent / f"ape_{k}_frame.png")
    Z = 8
    bw, bh = BOX[2] - BOX[0], BOX[3] - BOX[1]
    colw, pad = bw * Z, 24
    cols = 3
    insets_h = 150 + 2 * bh * 2 + 40
    W = pad + cols * (colw + pad)
    H = 70 + bh * Z + 20 + (bh * 2 + 60) + 20 + (bh * 2 + 60) + 20
    sheet = Image.new("RGBA", (W, H), (24, 24, 36, 255))
    d = ImageDraw.Draw(sheet)
    # row 1: three concepts at 8x
    for i, (label, fr) in enumerate(cons):
        x = pad + i * (colw + pad)
        d.text((x, 20), label, fill=(240, 240, 230), font=font(30))
        sheet.alpha_composite(show(fr, Z), (x, 62))
    # row 2: references at 8x? -> 4x to save space: Apex, current ape
    y2 = 62 + bh * Z + 24
    d.text((pad, y2), "REFERENCE  (4x)", fill=(240, 240, 230), font=font(22))
    refs = [("Apex (normal)", apex), ("Current Great Ape", cur)]
    for i, (label, fr) in enumerate(refs):
        x = pad + i * (bw * 4 + pad)
        sheet.alpha_composite(show(fr, 4), (x, y2 + 30))
        d.text((x, y2 + 30 + bh * 4 + 4), label, fill=(190, 190, 200), font=font(16))
    # row 2 right: 1x / 2x insets for every one, side by side, in the game's own scale order
    x0 = pad + 2 * (bw * 4 + pad) + 20
    d.text((x0, y2), "1x / 2x  (game ape is drawn x1.35 on top of this)", fill=(240, 240, 230), font=font(22))
    items = [("Apex", apex), ("Current", cur)] + [(l.split()[0], f) for l, f in cons]
    cw = bw * 2 + 12
    for i, (label, fr) in enumerate(items):
        x = x0 + i * cw if i < 5 else x0
        y = y2 + 30
        sheet.alpha_composite(show(fr, 1), (x, y))
        sheet.alpha_composite(show(fr, 2), (x, y + bh + 8))
        d.text((x, y + bh * 3 + 14), label, fill=(190, 190, 200), font=font(16))
    sheet.convert("RGB").save(out)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()
