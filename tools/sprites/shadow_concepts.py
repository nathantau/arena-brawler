"""Shadow redesign concepts (gangster street look, all-black hoodie). Single idle frame per variant, nothing is written
into assets/: previews go to /private/tmp/claude-501/redesign-previews/.
Run: tools/sprites/.venv/bin/python tools/sprites/shadow_concepts.py
Only palette colours are used: OUTLINE is the "black" (its auto rim is SHADOW), SHADOW the dark grey, one accent per variant."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw  # noqa: E402

import generate as g  # noqa: E402
from generate import BODY, FACE, FACE_R, L, P, R, RR, E, Canvas, arm, legs  # noqa: E402
from palette import (OUTLINE, SHADOW, STEEL, STEEL_D, WHITE, YELLOW, RED, TEAL_L, TEAL, ORANGE, SKIN, SKIN_D, MAROON,
                     VIOLET, VIOLET_D, VIOLET_L, PINK_L)  # noqa: E402

OUT_DIR = Path("/private/tmp/claude-501/redesign-previews")
ROOT = Path(__file__).resolve().parents[2]
BLACK = OUTLINE


def baggy_legs(low: Canvas, pants, cuff, shoe, sole_accent, wide=1):
    """Baggy pants: legs a bit wider than the base, a bunched cuff, chunky sneakers."""
    for x in (23, 34):
        low.part(RR((x - wide, 45, x + 5 + wide, 55), 1), pants)
        low.flat(R((x - wide, 52, x + 5 + wide, 52)), SHADOW)  # bunched hem
        low.flat(L([(x + 1, 47), (x + 1, 50)], 1), SHADOW)  # fold
        low.part(RR((x - 2, 54, x + 8, 58), 2), shoe)
        low.flat(R((x - 1, 58, x + 7, 58)), sole_accent)  # sole
        low.flat(R((x + 4, 55, x + 7, 55)), WHITE)  # toe sheen


def eyes_glow(up: Canvas, col, ys=21):
    for x in (31, 41):
        up.flat(R((x, ys, x + 3, ys + 1)), col)
        up.dot(x + 1, ys, WHITE)


def hood(up: Canvas, base=BLACK, lip=STEEL_D, peak=True):
    """Hood up: a big rounded shell with a drape on the back; the face opening is a dark void under the brow."""
    up.part(lambda d, f: (d.ellipse((15, 5, 49, 38), f), d.polygon(
        [(15, 20), (11, 29), (14, 28), (13, 37), (19, 33), (22, 38), (24, 31), (24, 20)], f)), base)
    up.flat(L([(21, 9), (30, 6), (39, 7)], 1), lip)  # rim light on the crown
    up.flat(L([(16, 20), (14, 27)], 1), lip)
    up.part(RR(FACE, FACE_R), SHADOW if False else BLACK)  # the opening
    up.flat(RR((FACE[0] + 1, FACE[1] + 1, FACE[2], FACE[3] - 1), FACE_R - 2), BLACK)
    # a lit hood edge round the opening so the face reads as a hole
    up.flat(L([(FACE[0] + 1, 16), (FACE[0] + 3, 14), (FACE[2] - 3, 13), (FACE[2], 16)], 1), lip)
    up.flat(L([(FACE[2] + 1, 18), (FACE[2] + 1, 30)], 1), SHADOW)


def hoodie_body(up: Canvas, base, trim, pocket=True):
    arm(up, g.ARM_X[0], base, base)
    up.part(RR((19, 32, 45, 49), 4), base)  # wider, boxier hoodie
    up.flat(R((19, 47, 44, 48)), SHADOW)  # ribbed hem
    up.flat(L([(26, 34), (25, 40)], 1), trim)  # drawstrings
    up.flat(L([(33, 34), (34, 40)], 1), trim)
    up.dot(25, 41, WHITE)
    up.dot(34, 41, WHITE)
    if pocket:
        up.flat(P([(23, 43), (41, 43), (43, 48), (21, 48)]), BLACK)  # kangaroo pocket
        up.flat(L([(23, 43), (41, 43)], 1), STEEL_D)
        up.flat(L([(21, 48), (23, 43)], 1), BLACK)
    if pocket:  # two fists pushing the pocket out
        for x in (27, 35):
            up.part(E((x, 42, x + 5, 47)), base)
            up.flat(L([(x + 1, 43), (x + 3, 43)], 1), STEEL_D)
    arm(up, g.ARM_X[1], base, base)  # front arm tucked into the pocket: no hand showing
    up.flat(R((g.ARM_X[1], 42, g.ARM_X[1] + 5, 43)), SHADOW)


def chain(up: Canvas, col, pendant):
    pts = [(23, 34), (26, 39), (32, 41), (38, 39), (41, 34)]
    up.flat(L(pts, 1), col)
    up.flat(R((31, 41, 33, 43)), pendant)
    up.dot(32, 42, WHITE)


# --- round 2: a human, mischievous face (the other fighters' base face) under streetwear -----------------------------------
def sly_eyes(up: Canvas, iris, half=(True, True)) -> None:
    """Dark chibi eyes with a heavy lid (half-lidded = sly), an accent iris and a glint."""
    for x, lidded in zip((31, 41), half):
        top = 23 if lidded else 21
        up.flat(R((x, top, x + 3, 26)), OUTLINE)
        up.flat(R((x + 1, 25, x + 2, 26)), iris)
        up.dot(x, top + 1 if lidded else 22, WHITE)
        if lidded:
            up.flat(R((x - 1, 22, x + 4, 22)), SKIN_D)  # the lid's shadow line
            up.flat(R((x, 22, x + 3, 22)), OUTLINE)


def brows(up: Canvas, raised: int, col=OUTLINE) -> None:
    """Eyebrows: `raised` 0 = left one lifted, 1 = right one lifted; the other slopes down sly."""
    for i, x in enumerate((30, 40)):
        if i == raised:
            up.flat(L([(x, 19), (x + 2, 17), (x + 5, 17)], 1), col)
        else:
            up.flat(L([(x, 19), (x + 5, 20)], 1), col)


def smirk(up: Canvas, tooth=True, tongue=False) -> None:
    """A lopsided grin: low on the left, curling up on the far (right) side, a tooth glint under it."""
    up.flat(L([(34, 31), (37, 32), (40, 30), (42, 28)], 1), OUTLINE)
    up.dot(42, 27, SKIN_D)
    if tooth:
        up.flat(R((38, 31, 39, 31)), WHITE)
    if tongue:
        up.flat(R((36, 32, 38, 33)), RED)
        up.flat(R((37, 33, 37, 33)), MAROON)
    up.flat(R((g.BLUSH[0], 29, g.BLUSH[0] + 1, 29)), ORANGE)  # blush
    up.flat(R((45, 29, 46, 29)), ORANGE)


def face_base(up: Canvas) -> None:
    up.part(RR(FACE, FACE_R), SKIN)
    up.flat(L([(FACE[0] + 3, FACE[3] - 2), (FACE[2] - 4, FACE[3] - 1)], 1), SKIN_D)  # chin shade
    up.flat(L([(28, 16), (33, 15)], 1), SKIN)  # forehead sheen


def pocket_hoodie(up: Canvas, accent, pocket=True, front_hand=False) -> None:
    arm(up, g.ARM_X[0], SHADOW, SHADOW)
    up.part(RR((19, 32, 45, 49), 4), SHADOW)
    up.flat(R((19, 47, 44, 48)), BLACK)  # ribbed hem
    up.flat(L([(22, 34), (21, 40)], 1), STEEL_D)  # fold lit by the light from the top left
    up.flat(L([(26, 35), (25, 41)], 1), accent)  # drawstrings with tips
    up.flat(L([(33, 35), (34, 41)], 1), accent)
    up.dot(25, 42, WHITE)
    up.dot(34, 42, WHITE)
    if pocket:
        up.flat(P([(23, 43), (41, 43), (43, 48), (21, 48)]), BLACK)
        up.flat(L([(23, 43), (41, 43)], 1), STEEL_D)
        up.flat(L([(23, 43), (21, 48)], 1), STEEL_D)
        up.flat(L([(41, 43), (43, 48)], 1), SHADOW)
        for x in ((27,) if front_hand else (27, 35)):
            up.part(E((x, 42, x + 5, 47)), SHADOW)
            up.flat(L([(x + 1, 43), (x + 3, 43)], 1), STEEL_D)
    arm(up, g.ARM_X[1], SHADOW, SKIN if front_hand else SHADOW)
    up.flat(R((g.ARM_X[1], 41, g.ARM_X[1] + 5, 41)), BLACK)  # cuff
    if not front_hand:
        up.flat(R((g.ARM_X[1], 42, g.ARM_X[1] + 5, 43)), BLACK)


def jogger_legs(low: Canvas, shoe, sole, stripe=None) -> None:
    for x in (23, 34):
        low.part(RR((x - 1, 45, x + 6, 55), 1), BLACK)
        low.flat(R((x - 1, 52, x + 6, 52)), SHADOW)  # elastic cuff
        low.flat(L([(x + 1, 47), (x + 1, 50)], 1), SHADOW)  # crease
        if stripe:
            low.flat(L([(x + 5, 46), (x + 5, 51)], 1), stripe)
        low.part(RR((x - 2, 54, x + 8, 58), 2), shoe)
        low.flat(R((x - 1, 58, x + 7, 58)), sole)
        low.flat(R((x + 4, 55, x + 7, 55)), WHITE)  # toe sheen
        low.dot(x + 2, 55, STEEL_D if shoe == SHADOW else STEEL)  # lace dots


def wisps(low: Canvas, xs, col=VIOLET, hi=VIOLET_L) -> None:
    """Thin shadow-magic curls rising off his feet."""
    for i, (x, y) in enumerate(xs):
        pts = [(x + round(math.sin((y - j) * 0.7 + i) * 1.5), y - j) for j in range(0, 7)]
        low.flat(L(pts, 1), col)
        low.dot(pts[-1][0], pts[-1][1] - 1, hi)


def grin_shadow(low: Canvas) -> None:
    """His own shadow on the floor, grinning back up."""
    low.flat(E((12, 57, 54, 64)), VIOLET_D)
    low.flat(E((14, 58, 52, 63)), BLACK)
    low.flat(L([(25, 61), (29, 62), (36, 62), (40, 61)], 1), PINK_L)  # grin
    for x in (27, 38):
        low.flat(R((x, 59, x + 1, 59)), PINK_L)  # eyes


# --- D: hood up over a cap, hair poking out, gold hoop ---------------------------------------------------------------------
def variant_d():
    low = Canvas()
    wisps(low, ((20, 58), (45, 58), (14, 55), (50, 56)))
    jogger_legs(low, WHITE, YELLOW)
    up = Canvas()
    pocket_hoodie(up, YELLOW)
    up.flat(L([(23, 34), (26, 39), (32, 41), (38, 39), (41, 34)], 1), YELLOW)  # chain
    up.flat(R((31, 41, 33, 43)), YELLOW)
    up.dot(32, 42, WHITE)
    up.part(lambda d, f: (d.ellipse((15, 5, 49, 38), f), d.polygon(
        [(15, 20), (11, 29), (14, 28), (13, 37), (19, 33), (22, 38), (24, 31), (24, 20)], f)), SHADOW)
    up.flat(L([(21, 9), (30, 6), (39, 7)], 1), STEEL_D)
    up.flat(L([(16, 20), (14, 27)], 1), STEEL_D)
    face_base(up)
    up.part(P([(22, 18), (25, 16), (25, 24), (22, 29), (20, 26)]), OUTLINE, shade=False)  # hair at the temples
    up.part(P([(48, 17), (46, 16), (46, 22), (48, 24)]), OUTLINE, shade=False)
    up.flat(L([(23, 19), (23, 24)], 1), SHADOW)
    up.part(P([(24, 17), (26, 11), (36, 9), (45, 12), (46, 17)]), BLACK)  # cap crown
    up.flat(L([(27, 12), (35, 10), (42, 12)], 1), STEEL_D)
    up.part(P([(33, 17), (47, 16), (53, 18), (51, 20), (33, 20)]), BLACK)  # brim
    up.flat(L([(34, 17), (46, 16)], 1), STEEL_D)
    up.flat(R((36, 13, 40, 14)), YELLOW)  # pin
    sly_eyes(up, TEAL_L)
    brows(up, 1)
    smirk(up)
    up.flat(E((20, 30, 24, 35)), YELLOW)  # gold hoop
    up.flat(E((21, 31, 23, 34)), SKIN)
    return low, up


# --- E: hood down, messy black hair, bandana round the neck, tongue out ---------------------------------------------------------
def variant_e():
    low = Canvas()
    grin_shadow(low)
    wisps(low, ((16, 57), (49, 57)))
    jogger_legs(low, SHADOW, RED, stripe=RED)
    up = Canvas()
    up.part(P([(19, 30), (14, 38), (20, 44), (46, 44), (46, 30)]), SHADOW)  # bunched hood
    up.flat(L([(15, 37), (19, 31)], 1), STEEL_D)
    pocket_hoodie(up, RED)
    up.part(P([(21, 32), (43, 32), (40, 40), (32, 44), (24, 40)]), RED)  # bandana
    up.flat(L([(22, 33), (42, 33)], 1), ORANGE)
    for x, y in ((28, 37), (33, 40), (37, 36)):
        up.dot(x, y, WHITE)
    up.part(P([(41, 34), (46, 38), (45, 43), (41, 40)]), RED)  # knot tail
    up.part(lambda d, f: d.ellipse((16, 6, 48, 36), f), OUTLINE)  # hair mass
    up.flat(L([(21, 10), (30, 7), (38, 8)], 1), STEEL_D)
    up.flat(L([(18, 16), (17, 24)], 1), SHADOW)
    face_base(up)
    up.part(P([(22, 16), (20, 8), (26, 13), (27, 4), (32, 12), (36, 3), (39, 12), (45, 6), (44, 14), (49, 12), (48, 20), (44, 17),
               (41, 20), (38, 17), (34, 19), (30, 17), (26, 19), (24, 24)]), OUTLINE, shade=False)
    up.flat(L([(28, 6), (31, 11)], 1), SHADOW)
    up.flat(L([(37, 5), (39, 10)], 1), SHADOW)
    up.flat(L([(43, 8), (46, 12)], 1), STEEL_D)
    sly_eyes(up, RED)
    brows(up, 0)
    smirk(up, tooth=False, tongue=True)
    up.dot(21, 31, STEEL)  # stud
    return low, up


# --- F: slouchy beanie, plaster on the cheek, flicking a shuriken ---------------------------------------------------------
def variant_f():
    low = Canvas()
    wisps(low, ((19, 58), (47, 59), (51, 52)), col=VIOLET, hi=TEAL_L)
    jogger_legs(low, SHADOW, TEAL_L, stripe=TEAL)
    up = Canvas()
    pocket_hoodie(up, TEAL_L, front_hand=True)
    up.flat(L([(23, 34), (26, 39), (32, 41), (38, 39), (41, 34)], 1), STEEL)  # silver chain
    up.flat(R((31, 41, 32, 43)), STEEL)
    up.part(P([(19, 28), (13, 38), (22, 41), (26, 33)]), SHADOW)  # hood bunched behind
    up.flat(L([(15, 37), (19, 30)], 1), STEEL_D)
    up.part(lambda d, f: d.ellipse((16, 8, 48, 37), f), OUTLINE)
    face_base(up)
    up.part(P([(22, 17), (24, 14), (47, 14), (47, 19), (44, 18), (41, 21), (38, 18), (34, 20), (30, 18), (26, 20), (24, 25)]),
            OUTLINE, shade=False)  # fringe
    up.part(P([(18, 18), (20, 8), (30, 3), (42, 4), (49, 10), (49, 17)]), SHADOW)  # beanie
    up.flat(L([(22, 8), (30, 5), (40, 6)], 1), STEEL_D)
    up.part(RR((17, 13, 49, 18), 2), BLACK)  # folded cuff
    for x in range(19, 48, 3):
        up.flat(L([(x, 14), (x, 17)], 1), SHADOW)
    up.flat(L([(18, 13), (48, 13)], 1), STEEL_D)
    up.flat(R((26, 15, 31, 16)), TEAL_L)
    sly_eyes(up, TEAL_L, half=(False, True))
    brows(up, 0)
    smirk(up)
    up.flat(R((27, 27, 31, 28)), WHITE)  # plaster
    up.flat(R((29, 26, 29, 29)), WHITE)
    up.dot(28, 27, STEEL)
    up.dot(30, 28, STEEL)
    up.dot(20, 31, STEEL)  # stud
    cx, cy = 56, 39  # the shuriken he flicks
    up.flat(P(g.star_points(cx, cy, 6, 0.4)), STEEL)
    up.flat(P(g.star_points(cx, cy, 4, 0.4, inner=0.5)), TEAL_L)
    up.dot(cx, cy, WHITE)
    up.flat(L([(52, 36), (50, 34)], 1), TEAL)
    up.flat(L([(52, 42), (50, 44)], 1), TEAL)
    return low, up


VARIANTS = (("D", variant_d, "hood up over a cap, gold hoop + chain, tooth-glint smirk"),
            ("E", variant_e, "hood down, messy hair, red bandana, tongue out"),
            ("F", variant_f, "beanie + plaster, silver chain, flicking a shuriken"))


# --- G: E with a real hoodie (hood up over the messy hair), violet eyes --------------------------------------------------------
def violet_eyes(up: Canvas) -> None:
    sly_eyes(up, VIOLET_L)
    for x in (31, 41):
        up.flat(R((x + 1, 26, x + 2, 26)), VIOLET)  # iris deepens at the bottom
        up.dot(x + 2, 25, PINK_L)  # second, softer glint


def variant_g(mask: bool = False):
    low = Canvas()
    grin_shadow(low)
    wisps(low, ((16, 57), (49, 57)))
    jogger_legs(low, SHADOW, RED, stripe=RED)
    up = Canvas()
    pocket_hoodie(up, RED)
    for x in (g.ARM_X[0], g.ARM_X[1]):  # ribbed sleeve cuffs
        up.flat(R((x, 41, x + 5, 42)), BLACK)
        up.flat(R((x, 41, x + 5, 41)), STEEL_D)
    up.flat(L([(23, 33), (41, 33)], 1), STEEL_D)  # hood collar seam
    # bandana round the neck (collar of the hoodie shows above and below it)
    if not mask:
        up.part(P([(21, 32), (43, 32), (40, 40), (32, 44), (24, 40)]), RED)
        up.flat(L([(22, 33), (42, 33)], 1), ORANGE)
        for x, y in ((28, 37), (33, 40), (37, 36)):
            up.dot(x, y, WHITE)
        up.part(P([(41, 34), (46, 38), (45, 43), (41, 40)]), RED)
    # the hood: big shell with a drape behind, a lit rim round the face, a pointy peak on top
    up.part(lambda d, f: (d.ellipse((14, 4, 50, 38), f), d.polygon(
        [(14, 20), (9, 30), (13, 29), (12, 38), (19, 34), (22, 39), (25, 31), (25, 20)], f)), SHADOW)
    up.flat(L([(20, 9), (30, 5), (40, 6)], 1), STEEL_D)
    up.flat(L([(15, 20), (12, 28)], 1), STEEL_D)
    up.flat(L([(18, 34), (22, 36)], 1), STEEL_D)
    up.flat(RR((FACE[0] - 3, FACE[1] - 4, FACE[2] + 2, FACE[3] + 1), FACE_R + 3), STEEL_D)  # the hood's lit lip
    up.flat(RR((FACE[0] - 2, FACE[1] - 3, FACE[2] + 1, FACE[3] + 1), FACE_R + 2), BLACK)  # the opening, in shadow
    face_base(up)
    # messy black hair poking out of the opening: spiky fringe over the brow + tufts at the temples
    up.part(P([(23, 25), (23, 16), (26, 13), (26, 7), (30, 12), (33, 5), (36, 13), (40, 8), (41, 14), (45, 12), (46, 17),
               (45, 22), (43, 18), (41, 20), (38, 18), (34, 20), (30, 18), (26, 20), (25, 27)]), OUTLINE, shade=False)
    up.flat(L([(26, 9), (27, 11)], 1), STEEL_D)
    up.flat(L([(33, 7), (34, 10)], 1), STEEL_D)
    up.flat(L([(40, 10), (40, 12)], 1), STEEL_D)
    up.flat(L([(29, 14), (33, 16)], 1), SHADOW)
    up.part(P([(23, 24), (21, 31), (25, 29)]), OUTLINE, shade=False)  # sideburn tuft
    violet_eyes(up)
    brows(up, 0)
    if mask:  # bandana pulled up over the mouth only
        up.part(P([(24, 28), (46, 27), (45, 33), (38, 38), (31, 35), (25, 33)]), RED)
        up.flat(L([(25, 28), (45, 27)], 1), ORANGE)
        for x, y in ((31, 31), (37, 33), (42, 30)):
            up.dot(x, y, WHITE)
        up.part(P([(24, 29), (18, 34), (19, 39), (24, 34)]), RED)  # knot tail
        up.flat(R((g.BLUSH[0], 29, g.BLUSH[0] + 1, 29)), ORANGE)
    else:
        smirk(up, tooth=False, tongue=True)
    up.dot(21, 31, STEEL)  # stud
    return low, up


def variant_g2():
    return variant_g(mask=True)


# --- H: G with a loose, baggy hoodie and a hood that is its own grey shape ----------------------------------------------------
def baggy_hoodie(up: Canvas) -> None:
    """Oversized hoodie: wide boxy body, sleeves that droop past the wrists in bunched cuffs, a low ribbed hem, a big pocket."""
    # back sleeve (left), hanging loose and wider than the arm, cuff bunched over the hand
    up.part(RR((8, 34, 20, 51), 5), SHADOW)
    up.flat(L([(10, 38), (10, 45)], 1), STEEL_D)  # lit fold on the sleeve
    up.flat(L([(15, 41), (17, 46)], 1), BLACK)  # crease
    up.part(RR((7, 47, 20, 52), 2), BLACK)  # bunched cuff
    up.flat(L([(8, 47), (19, 47)], 1), STEEL_D)
    up.flat(L([(9, 49), (18, 49)], 1), SHADOW)
    # torso: much wider than the shoulders, boxy, falling past the hips
    up.part(RR((14, 31, 50, 50), 7), SHADOW)
    up.flat(L([(17, 34), (15, 42)], 1), STEEL_D)  # lit edge, left
    up.flat(L([(22, 38), (20, 44)], 1), STEEL_D)  # folds
    up.flat(L([(41, 36), (44, 44)], 1), BLACK)
    up.flat(L([(28, 45), (30, 49)], 1), BLACK)
    up.flat(L([(36, 44), (38, 48)], 1), STEEL_D)
    # ribbed hem band hanging low
    up.part(R((14, 47, 49, 50)), BLACK)
    up.flat(L([(15, 47), (48, 47)], 1), STEEL_D)
    for x in range(17, 48, 3):
        up.flat(L([(x, 48), (x, 49)], 1), SHADOW)
    # big kangaroo pocket, both fists pushing it out, sleeve cuffs drooping into the openings
    up.part(P([(19, 40), (45, 40), (49, 47), (15, 47)]), BLACK)
    up.flat(L([(19, 40), (45, 40)], 1), STEEL_D)
    up.flat(L([(19, 40), (15, 47)], 1), STEEL_D)
    up.flat(L([(45, 40), (49, 47)], 1), SHADOW)
    for x in (23, 36):
        up.part(E((x, 41, x + 7, 47)), SHADOW)
        up.flat(L([(x + 1, 43), (x + 4, 42)], 1), STEEL_D)
    # front sleeve (right), its cuff bunched at the pocket edge
    up.part(RR((43, 34, 55, 49), 5), SHADOW)
    up.flat(L([(45, 37), (45, 43)], 1), STEEL_D)
    up.flat(L([(51, 40), (52, 45)], 1), BLACK)
    up.part(RR((43, 45, 56, 50), 2), BLACK)
    up.flat(L([(44, 45), (55, 45)], 1), STEEL_D)
    up.flat(L([(45, 47), (54, 47)], 1), SHADOW)


def variant_h(mask: bool = False):
    low = Canvas()
    grin_shadow(low)
    wisps(low, ((16, 58), (49, 58)))
    jogger_legs(low, SHADOW, RED, stripe=RED)
    up = Canvas()
    # hood volume behind the head and neck: a grey bunched collar, visible around the shoulders
    baggy_hoodie(up)
    if not mask:
        up.part(P([(21, 32), (43, 32), (40, 40), (32, 44), (24, 40)]), RED)  # bandana round the neck
        up.flat(L([(22, 33), (42, 33)], 1), ORANGE)
        for x, y in ((28, 37), (33, 40), (37, 36)):
            up.dot(x, y, WHITE)
        up.part(P([(41, 34), (47, 38), (46, 43), (41, 40)]), RED)
    # drawstrings dangling at different lengths with aglets
    up.flat(L([(26, 35), (25, 40), (26, 46)], 1), WHITE)
    up.flat(R((26, 46, 26, 47)), RED)
    up.flat(L([(36, 35), (37, 39), (36, 42)], 1), WHITE)
    up.flat(R((36, 42, 36, 43)), RED)
    # the hood: its own big grey shape, loose around the head, slouching back to a soft peak
    up.part(lambda d, f: (d.ellipse((11, 3, 53, 38), f), d.polygon(
        [(11, 18), (4, 29), (9, 28), (8, 39), (17, 35), (21, 41), (25, 32), (25, 20)], f),
        d.polygon([(14, 12), (11, 4), (20, 6), (26, 5)], f)), SHADOW)  # drape + a soft slouched peak
    up.flat(L([(15, 14), (13, 7), (20, 6)], 1), STEEL_D)  # lit peak
    up.flat(L([(18, 8), (28, 4), (39, 5), (47, 9)], 2), STEEL_D)  # lit crown, two px thick
    up.flat(L([(12, 20), (7, 28), (10, 30)], 1), STEEL_D)  # lit drape
    up.flat(L([(31, 5), (38, 9), (44, 15)], 1), BLACK)  # a seam / fold across the crown
    up.flat(L([(32, 6), (39, 10)], 1), STEEL_D)
    up.flat(L([(51, 20), (52, 28)], 1), BLACK)  # shaded far side
    up.flat(L([(14, 34), (19, 37)], 1), BLACK)  # fold at the drape's bottom
    # opening: lit lip, then the hood's dark lining, then the face
    up.flat(RR((FACE[0] - 4, FACE[1] - 5, FACE[2] + 3, FACE[3] + 1), FACE_R + 4), STEEL)
    up.flat(RR((FACE[0] - 3, FACE[1] - 4, FACE[2] + 2, FACE[3] + 1), FACE_R + 3), BLACK)
    face_base(up)
    up.part(P([(23, 25), (23, 16), (26, 13), (26, 7), (30, 12), (33, 5), (36, 13), (40, 8), (41, 14), (45, 12), (46, 17),
               (45, 22), (43, 18), (41, 20), (38, 18), (34, 20), (30, 18), (26, 20), (25, 27)]), OUTLINE, shade=False)
    up.flat(L([(26, 9), (27, 11)], 1), STEEL_D)
    up.flat(L([(33, 7), (34, 10)], 1), STEEL_D)
    up.flat(L([(40, 10), (40, 12)], 1), STEEL_D)
    up.flat(L([(29, 14), (33, 16)], 1), SHADOW)
    up.part(P([(23, 24), (21, 31), (25, 29)]), OUTLINE, shade=False)
    violet_eyes(up)
    brows(up, 0)
    if mask:
        up.part(P([(24, 28), (46, 27), (45, 33), (38, 38), (31, 35), (25, 33)]), RED)
        up.flat(L([(25, 28), (45, 27)], 1), ORANGE)
        for x, y in ((31, 31), (37, 33), (42, 30)):
            up.dot(x, y, WHITE)
        up.part(P([(24, 29), (18, 34), (19, 39), (24, 34)]), RED)
        up.flat(R((g.BLUSH[0], 29, g.BLUSH[0] + 1, 29)), ORANGE)
    else:
        smirk(up, tooth=False, tongue=True)
    up.dot(21, 31, STEEL)
    return low, up


def variant_h2():
    return variant_h(mask=True)


def gh() -> None:
    cols = [("G", variant_g), ("H", variant_h), ("H2", variant_h2)]
    panels = []
    games = []
    for label, build in cols:
        im = idle_frame(build)
        bg = Image.new("RGBA", (g.CELL * 5, g.CELL * 5), (60, 56, 52, 255))
        bg.alpha_composite(nn(im, 5))
        panels.append(labelled(bg, label))
        games.append(labelled(ingame(im), f"{label} in game"))
    w = max(sum(p.width for p in panels) + 32, games[0].width + 16)
    h = panels[0].height + sum(x.height for x in games) + 24 + 8 * len(games)
    out = Image.new("RGBA", (w, h), (24, 24, 32, 255))
    x = 8
    for p in panels:
        out.alpha_composite(p, (x, 8))
        x += p.width + 8
    y = panels[0].height + 16
    for gm in games:
        out.alpha_composite(gm, (8, y))
        y += gm.height + 8
    out.convert("RGB").save(OUT_DIR / "shadow_gh.png")


# --- I: G (smooth rounded hood, soft body) with a gold chain, no bandana, a small smirk -------------------------------------
def small_smirk(up: Canvas) -> None:
    up.flat(L([(36, 31), (38, 32), (40, 30)], 1), OUTLINE)  # short, lopsided
    up.dot(41, 29, SKIN_D)
    up.flat(R((g.BLUSH[0], 29, g.BLUSH[0] + 1, 29)), ORANGE)
    up.flat(R((45, 29, 46, 29)), ORANGE)


def variant_i():
    low = Canvas()
    grin_shadow(low)
    wisps(low, ((16, 57), (49, 57)))
    jogger_legs(low, SHADOW, YELLOW, stripe=YELLOW)
    up = Canvas()
    pocket_hoodie(up, YELLOW)
    for x in (g.ARM_X[0], g.ARM_X[1]):  # ribbed sleeve cuffs
        up.flat(R((x, 41, x + 5, 42)), BLACK)
        up.flat(R((x, 41, x + 5, 41)), STEEL_D)
    up.flat(L([(22, 36), (21, 43)], 1), STEEL_D)  # a soft fold or two
    up.flat(L([(40, 37), (41, 42)], 1), BLACK)
    # gold chain with a small pendant, and a lit link
    up.flat(L([(23, 33), (25, 38), (30, 41), (35, 41), (40, 38), (42, 33)], 1), YELLOW)
    up.dot(25, 38, WHITE)
    up.flat(R((31, 42, 33, 44)), YELLOW)
    up.dot(31, 42, WHITE)
    up.flat(R((32, 44, 32, 44)), ORANGE)
    # the hood: a smooth round shell with a soft round drape behind, no peak
    up.part(lambda d, f: (d.ellipse((14, 4, 50, 38), f), d.ellipse((10, 17, 30, 40), f)), SHADOW)
    up.flat(L([(20, 9), (30, 5), (40, 6), (46, 10)], 1), STEEL_D)  # lit crown
    up.flat(L([(13, 25), (12, 31), (15, 36)], 1), STEEL_D)  # lit drape
    up.flat(L([(15, 15), (13, 21)], 1), STEEL_D)
    up.flat(RR((FACE[0] - 3, FACE[1] - 4, FACE[2] + 2, FACE[3] + 1), FACE_R + 3), STEEL_D)  # lit lip
    up.flat(RR((FACE[0] - 2, FACE[1] - 3, FACE[2] + 1, FACE[3] + 1), FACE_R + 2), BLACK)  # opening
    face_base(up)
    up.part(P([(23, 25), (23, 16), (26, 13), (26, 7), (30, 12), (33, 5), (36, 13), (40, 8), (41, 14), (45, 12), (46, 17),
               (45, 22), (43, 18), (41, 20), (38, 18), (34, 20), (30, 18), (26, 20), (25, 27)]), OUTLINE, shade=False)
    up.flat(L([(26, 9), (27, 11)], 1), STEEL_D)
    up.flat(L([(33, 7), (34, 10)], 1), STEEL_D)
    up.flat(L([(40, 10), (40, 12)], 1), STEEL_D)
    up.flat(L([(29, 14), (33, 16)], 1), SHADOW)
    up.part(P([(23, 24), (21, 31), (25, 29)]), OUTLINE, shade=False)
    violet_eyes(up)
    brows(up, 0)
    small_smirk(up)
    up.flat(R((21, 30, 22, 31)), YELLOW)  # gold stud
    up.dot(21, 30, WHITE)
    return low, up


def gi() -> None:
    panels, games = [], []
    for label, build in (("G", variant_g), ("I", variant_i)):
        im = idle_frame(build)
        bg = Image.new("RGBA", (g.CELL * 7, g.CELL * 7), (60, 56, 52, 255))
        bg.alpha_composite(nn(im, 7))
        panels.append(labelled(bg, label))
        games.append(labelled(ingame(im), f"{label} in game"))
    out = Image.new("RGBA", (panels[0].width * 2 + 24, panels[0].height + sum(x.height for x in games) + 40), (24, 24, 32, 255))
    out.alpha_composite(panels[0], (8, 8))
    out.alpha_composite(panels[1], (16 + panels[0].width, 8))
    y = panels[0].height + 16
    for gm in games:
        out.alpha_composite(gm, (8, y))
        y += gm.height + 8
    out.convert("RGB").save(OUT_DIR / "shadow_gi.png")


EXTRA = (("G", variant_g, "E with a real hoodie: hood up over messy hair, violet eyes, tongue out"),
         ("G2", variant_g2, "G with the bandana pulled up over his mouth"),
         ("H", variant_h, "baggy hoodie, grey hood with a lit rim, violet eyes, tongue out"),
         ("H2", variant_h2, "H with the bandana pulled up over his mouth"),
         ("I", variant_i, "G with a gold chain instead of the bandana, smaller smirk, smooth hood"))


def sheet_for(letter: str, build, blurb: str) -> Image.Image:
    im = idle_frame(build)
    bg = Image.new("RGBA", (g.CELL * 8, g.CELL * 8), (60, 56, 52, 255))
    bg.alpha_composite(nn(im, 8))
    game = ingame(im)
    sheet = Image.new("RGBA", (max(bg.width, game.width) + 16, bg.height + game.height + 24), (24, 24, 32, 255))
    sheet.alpha_composite(bg, (8, 8))
    sheet.alpha_composite(game, (8, bg.height + 16))
    return labelled(sheet, f"Shadow {letter}: {blurb}")


def extras() -> None:
    gh()
    gi()
    for letter, build, blurb in EXTRA:
        sheet_for(letter, build, blurb).convert("RGB").save(OUT_DIR / f"shadow_{letter.lower()}.png")
    pair = [("E", variant_e, "E"), ("G", variant_g, "G (hoodie, violet eyes)")]
    panels = []
    for letter, build, label in pair:
        im = idle_frame(build)
        bg = Image.new("RGBA", (g.CELL * 7, g.CELL * 7), (60, 56, 52, 255))
        bg.alpha_composite(nn(im, 7))
        panels.append(labelled(bg, label))
    game = ingame(idle_frame(variant_g))
    game_e = ingame(idle_frame(variant_e))
    w = sum(p.width for p in panels) + 24
    out = Image.new("RGBA", (w, panels[0].height + game.height * 2 + 40), (24, 24, 32, 255))
    out.alpha_composite(panels[0], (8, 8))
    out.alpha_composite(panels[1], (16 + panels[0].width, 8))
    out.alpha_composite(labelled(game_e, "E in game"), (8, panels[0].height + 16))
    out.alpha_composite(labelled(game, "G in game"), (8, panels[0].height + game.height + 40))
    out.convert("RGB").save(OUT_DIR / "shadow_eg.png")


def rim(f: Image.Image, col=STEEL_D) -> None:
    """Rim light: dark pixels on the silhouette's top / left edge turn STEEL_D so the black reads against the floor."""
    px = f.load()
    w, h = f.size
    dark = {BLACK + (255,), SHADOW + (255,)}
    todo = []
    for y in range(h):
        for x in range(w):
            if px[x, y] in dark and ((y == 0 or px[x, y - 1][3] == 0) or (x == 0 or px[x - 1, y][3] == 0)):
                todo.append((x, y))
    for x, y in todo:
        px[x, y] = col + (255,)


def idle_frame(build) -> Image.Image:
    low, up = build()
    f = Image.new("RGBA", (g.SIZE, g.SIZE), (0, 0, 0, 0))
    f.alpha_composite(low.img)
    f.alpha_composite(up.img, (0, g.UPPER_DY))
    rim(f)
    return g.cell(g.outline(f))


def sheet_frame(name: str, i: int = 0) -> Image.Image:
    img = Image.open(ROOT / "assets" / "sprites" / f"{name}.png").convert("RGBA")
    return img.crop((i * g.CELL, 0, (i + 1) * g.CELL, g.CELL))


def floor_crop(w: int, h: int) -> Image.Image:
    tiles = Image.open(ROOT / "assets" / "arenas" / "pit_tiles.png").convert("RGBA")
    t = tiles.height
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, t):
        for x in range(0, w, t):
            out.paste(tiles.crop(((x // t + y // t) % 2 * t, 0, (x // t + y // t) % 2 * t + t, t)), (x, y))
    return out


def nn(img: Image.Image, k: int) -> Image.Image:
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def ingame(shadow_img: Image.Image) -> Image.Image:
    """The three fighters on arena floor at the game's pixel scale (sprite 1.5 x camera 1.4 = 2.1, shown at 2x)."""
    n = 3
    cw = g.CELL
    floor = floor_crop(cw * n, cw)
    for k, im in enumerate((sheet_frame("flicker"), shadow_img, sheet_frame("bolt"))):
        floor.alpha_composite(im, (k * cw, 0))
    return nn(floor, 2)


def labelled(img: Image.Image, text: str) -> Image.Image:
    out = Image.new("RGBA", (img.width, img.height + 22), (24, 24, 32, 255))
    out.alpha_composite(img, (0, 22))
    ImageDraw.Draw(out).text((6, 5), text, fill=(240, 240, 230, 255))
    return out


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    panels = []
    for letter, build, blurb in VARIANTS:
        im = idle_frame(build)
        big = nn(im, 8)
        bg = Image.new("RGBA", big.size, (60, 56, 52, 255))
        bg.alpha_composite(big)
        game = ingame(im)
        pad = 8
        w = max(bg.width, game.width) + pad * 2
        sheet = Image.new("RGBA", (w, bg.height + game.height + pad * 3), (24, 24, 32, 255))
        sheet.alpha_composite(bg, (pad, pad))
        sheet.alpha_composite(game, (pad, bg.height + pad * 2))
        sheet = labelled(sheet, f"Shadow {letter}: {blurb}")
        sheet.convert("RGB").save(OUT_DIR / f"shadow_{letter.lower()}.png")
        panels.append(labelled(Image.alpha_composite(Image.new("RGBA", game.size, (0, 0, 0, 255)), game), f"{letter}"))
    # combined sheet: big frames side by side + the in-game strips
    bigs = []
    for letter, build, blurb in VARIANTS:
        b = nn(idle_frame(build), 6)
        bg = Image.new("RGBA", b.size, (60, 56, 52, 255))
        bg.alpha_composite(b)
        bigs.append(labelled(bg, f"{letter}: {blurb}"))
    row_w = sum(p.width for p in bigs) + 8 * (len(bigs) + 1)
    games_h = sum(p.height for p in panels) + 8 * len(panels)
    allsheet = Image.new("RGBA", (max(row_w, panels[0].width + 16), bigs[0].height + games_h + 24), (24, 24, 32, 255))
    x = 8
    for p in bigs:
        allsheet.alpha_composite(p, (x, 8))
        x += p.width + 8
    y = bigs[0].height + 16
    for p in panels:
        allsheet.alpha_composite(p, (8, y))
        y += p.height + 8
    allsheet.convert("RGB").save(OUT_DIR / "shadow_all.png")
    extras()
    print("wrote previews to", OUT_DIR)


if __name__ == "__main__":
    main()
