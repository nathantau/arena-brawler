"""Great Ape concepts, round 2 (design stage only): the CURRENT ape (generate.py wukong_ape) kept as the base (silhouette,
proportions, colours, gorilla face) and enhanced with restrained detail: a darker face skin, heavy gorilla brow, angry
slanted red eyes, broad nose, snarl with tusks, broken gold armour, torn sash scraps, fur clumps on shoulders / arms.
  V1 closed snarl      V2 open roar
Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts2.py [out_png]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import generate as g
from generate import E, L, P, R, RR, CELL, PAD
from ape_concepts import band, dent, floor, font, fur, idle, metal, scratch, seam, show, tuft, BOX
from palette import (BROWN, MAROON, ORANGE, OUTLINE, RED, SHADOW, SKIN_D, STEEL, WALNUT, WALNUT_D, WALNUT_L, WHITE, YELLOW)

FACE_MASK = E((28, 11, 50, 29))


def enhance(up, v):
    inside = lambda x, y: 0 <= x < 64 and 0 <= y < 64 and up.px[x, y][3]
    # ---- fur clumps on shoulders and arms (lit top-left edge), drawn first so armour sits on them
    for box in ((12, 15, 19, 21), (4, 33, 10, 38), (49, 17, 56, 23), (53, 33, 59, 38)):
        fur(up, E(box))
    # ---- face: darker skin than the fur
    for y in range(11, 30):
        for x in range(28, 51):
            if up.px[x, y][:3] == BROWN:
                up.dot(x, y, WALNUT)
    m = Image.new("1", (64, 64), 0)
    ImageDraw.Draw(m).ellipse((28, 11, 50, 29), 1)
    mm = m.load()
    for y in range(14, 30):
        for x in range(28, 51):
            if mm[x, y] and up.px[x, y][:3] != OUTLINE:
                up.dot(x, y, WALNUT)  # wipe the old eyes / brows / nose / mouth / fangs
    # ---- big rounded brown muzzle: lit top-left, dark underneath
    bottom = 33 if v == "2" else 31
    band(up, E((30, 20, 50, bottom)), BROWN, SKIN_D, WALNUT_D)
    for x in (34, 36, 38):
        up.dot(x, 20 if x != 38 else 20, SKIN_D)
    # ---- brow: heavy, low, slanting to the nose; shadow socket under it
    for x0 in (31, 42):
        up.flat(R((x0, 19, x0 + 5, 21)), OUTLINE)
    band(up, P([(29, 15), (34, 14), (39, 16), (44, 14), (49, 15), (49, 17), (44, 18), (40, 19), (35, 18), (29, 17)]),
         WALNUT, WALNUT_L, WALNUT_D)  # one heavy ridge, dipping to the nose
    up.flat(L([(39, 14), (39, 20)], 1), OUTLINE)  # furrow between the brows
    up.flat(L([(40, 14), (40, 17)], 1), WALNUT_D)
    for pts in ([(33, 12), (36, 13)], [(45, 12), (42, 13)]):
        up.flat(L(pts, 1), WALNUT_D)  # forehead creases under the circlet
    # ---- eyes: small, slanted down to the nose, red glow
    L_EYE = [(32, 19), (33, 19), (34, 20), (35, 20)]
    R_EYE = [(78 - x, y) for x, y in L_EYE]
    for eye in (L_EYE, R_EYE):
        for x, y in eye:
            for dx, dy in ((1, 0), (-1, 0), (0, 1)):
                if (x + dx, y + dy) not in eye and up.px[x + dx, y + dy][:3] == OUTLINE:
                    up.dot(x + dx, y + dy, RED)  # 1 px glow
        for x, y in eye:
            up.dot(x, y, ORANGE)
        up.dot(*eye[2], YELLOW)
        up.dot(*eye[1], RED)
    # ---- broad flat nose, big flared nostrils, wrinkles
    up.flat(R((36, 21, 42, 22)), WALNUT_D)  # flat nose pad
    up.flat(R((38, 20, 40, 20)), WALNUT_L)
    up.flat(P([(35, 22), (38, 22), (38, 24), (36, 24), (34, 23)]), OUTLINE)  # nostrils
    up.flat(P([(43, 22), (40, 22), (40, 24), (42, 24), (44, 23)]), OUTLINE)
    for pts in ([(38, 20), (38, 22)], [(41, 20), (41, 22)], [(34, 21), (32, 24), (32, 27)], [(45, 21), (47, 24), (47, 27)]):
        up.flat(L(pts, 1), WALNUT_D)
    up.dot(33, 21, SKIN_D)
    up.dot(37, 21, SKIN_D)
    # ---- mouth
    if v == "1":  # closed snarl: down-turned lip, tusks over it, a hint of upper teeth
        up.flat(P([(31, 27), (33, 26), (45, 26), (47, 27), (46, 28), (44, 27), (34, 27), (32, 28)]), OUTLINE)
        up.flat(R((33, 28, 45, 28)), WALNUT_D)  # lower lip
        for x in (37, 39, 41):
            up.dot(x, 27, WHITE)  # upper teeth hint
        for x0 in (34, 42):  # lower tusks over the lip
            up.flat(P([(x0, 29), (x0 + 3, 29), (x0 + 2, 24), (x0 + 1, 24)]), WHITE)
            up.flat(L([(x0 + 3, 28), (x0 + 2, 25)], 1), STEEL)
    else:  # open roar: gorilla mouth, tongue, upper teeth, thin lower tusks
        up.flat(P([(32, 26), (35, 25), (43, 25), (46, 26), (46, 29), (43, 32), (35, 32), (32, 29)]), OUTLINE)
        up.flat(E((37, 29, 41, 33)), RED)  # tongue
        for x in (37, 39, 41):
            up.dot(x, 26, WHITE)
        for x in (34, 44):  # small upper canines
            up.flat(L([(x, 26), (x, 28)], 1), WHITE)
        for x0 in (33, 43):
            up.flat(P([(x0, 32), (x0 + 2, 32), (x0 + 1, 27)]), WHITE)
            up.dot(x0 + 1, 30, STEEL)
    # ---- broken circlet: a chunk gone from the tip, a dent, glints, one more crack
    up.flat(P([(23, 8), (27, 9), (25, 11), (23, 12)]), MAROON)
    up.flat(L([(23, 8), (27, 9), (25, 11), (23, 12)], 1), OUTLINE)
    up.dot(31, 7, WHITE)
    up.dot(40, 5, WHITE)
    up.dot(44, 7, ORANGE)
    up.dot(45, 7, ORANGE)
    up.dot(44, 6, OUTLINE)
    up.flat(L([(33, 9), (32, 11)], 1), OUTLINE)
    # ---- split pauldron on the back shoulder, lower half hanging by a strap; dent + glint
    metal(up, P([(7, 24), (8, 20), (12, 18), (17, 19), (18, 22), (14, 21), (11, 24)]))
    seam(up, [(12, 19), (11, 21), (13, 22)], BROWN)
    dent(up, 15, 20)
    seam(up, [(9, 24), (8, 27), (9, 29)], BROWN)  # strap
    metal(up, P([(5, 29), (9, 28), (11, 31), (9, 34), (6, 33)]))
    scratch(up, 6, 30, 2)
    # ---- snapped bracer (back arm): cracked through, a chip missing, a piece falling
    up.flat(L([(17, 41), (18, 42), (17, 43), (18, 44)], 1), OUTLINE)
    up.flat(R((20, 41, 21, 41)), MAROON)
    up.dot(19, 42, SHADOW)
    metal(up, P([(7, 45), (10, 44), (9, 47)]), lo2=False)
    # ---- gold shards on the floor
    for pts in ([(4, 55), (7, 54), (6, 57)], [(57, 54), (60, 53), (59, 56)]):
        metal(up, P(pts), lo2=False)
    # ---- torn red sash scraps
    up.part(P([(21, 44), (26, 44), (25, 48), (24, 50), (23, 47), (22, 51), (21, 47)]), RED)
    up.part(P([(40, 44), (45, 44), (46, 48), (44, 47), (43, 50), (41, 47)]), RED)


def build(v):
    def f(step=None, t=0):
        low, up = g.wukong_ape(step, t)
        enhance(up, v)
        return low, up
    return f


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else
               "/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/"
               "scratchpad/ape/ape_concepts2.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    apex = idle(g.wukong, g.wukong_clouds)
    cur = idle(g.wukong_ape, g.ape_storm)
    vs = [("CURRENT", cur), ("V1  CLOSED SNARL", idle(build("1"), g.ape_storm)), ("V2  OPEN ROAR", idle(build("2"), g.ape_storm))]
    for k, (_, fr) in zip(("cur", "v1", "v2"), vs):
        fr.save(out.parent / f"ape2_{k}_frame.png")
    Z, pad = 8, 24
    bw, bh = BOX[2] - BOX[0], BOX[3] - BOX[1]
    W = pad + 3 * (bw * Z + pad)
    H = 62 + bh * Z + 24 + 30 + bh * 3 + 40
    sheet = Image.new("RGBA", (W, H), (24, 24, 36, 255))
    d = ImageDraw.Draw(sheet)
    for i, (label, fr) in enumerate(vs):
        x = pad + i * (bw * Z + pad)
        d.text((x, 20), label, fill=(240, 240, 230), font=font(30))
        sheet.alpha_composite(show(fr, Z), (x, 62))
    y = 62 + bh * Z + 24
    d.text((pad, y), "1x / 2x", fill=(240, 240, 230), font=font(22))
    items = [("Apex", apex)] + [(l.split()[0], f) for l, f in vs]
    for i, (label, fr) in enumerate(items):
        x = pad + i * (bw * 2 + 20)
        sheet.alpha_composite(show(fr, 1), (x, y + 30))
        sheet.alpha_composite(show(fr, 2), (x, y + 30 + bh + 8))
        d.text((x, y + 30 + bh * 3 + 14), label, fill=(190, 190, 200), font=font(16))
    sheet.convert("RGB").save(out)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()
