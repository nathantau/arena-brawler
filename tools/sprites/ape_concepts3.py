"""Great Ape concepts, round 3 (design stage only): the CURRENT ape (generate.py wukong_ape) kept as the base (silhouette,
proportions, colours, gorilla face) and enhanced with restrained detail: a darker face skin, heavy gorilla brow, angry
slanted red eyes, broad nose, snarl with tusks, broken gold armour, torn sash scraps, fur clumps on shoulders / arms.
  V1 closed snarl      V2 open roar
Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts3.py [out_png]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import generate as g
from generate import E, L, P, R, RR, CELL, PAD
from ape_concepts import dent, floor, font, idle, metal, scratch, seam, show, BOX, GOLD_D, GOLD_X
from palette import (BROWN, MAROON, ORANGE, OUTLINE, RED, SHADOW, SKIN_D, STEEL, WALNUT, WALNUT_D, WALNUT_L, WHITE, YELLOW)

FACE_MASK = E((28, 11, 50, 29))


def enhance(up, v):
    # The ORIGINAL face disc is kept as it is; only the brow, eyes, nose, mouth lines and armour are redrawn on it.
    def clear(box, color=BROWN):  # repaint bits of the old face with its own brown
        x0, y0, x1, y1 = box
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if up.px[x, y][:3] in (OUTLINE, RED, ORANGE, WHITE):
                    up.dot(x, y, color)
    clear((30, 12, 47, 19))  # old eyes + thin brows
    clear((36, 20, 45, 22))  # old nostrils
    clear((32, 22, 48, 28))  # old mouth line and the lower tusks (gorillas show upper canines instead)
    # muzzle shade: lighter top-left, darker lower rim
    for y in range(18, 29):
        for x in range(30, 48):
            if up.px[x, y][:3] == BROWN and (x + y) % 2 == 0:
                if x + y < 52 and 19 <= y < 24 and x < 36:
                    up.dot(x, y, SKIN_D)
                elif y >= 28:
                    up.dot(x, y, WALNUT)
    # ---- V brow: 2 px of darker brown dropping hard to the centre, 1 px lit edge on top
    for side in (0, 1):
        for i in range(8):
            x = 31 + i
            y = 13 + (i * 3) // 7
            if side:
                x = 77 - x
            for yy in (y, y + 1):
                up.dot(x, yy, WALNUT)
            if i % 2 == 0:
                up.dot(x, y - 1, WALNUT_L)
    up.dot(38, 13, WALNUT_D)  # furrow between the brows
    up.dot(39, 14, WALNUT_D)
    up.dot(38, 19, WALNUT_D)  # crease above the nose
    up.dot(39, 19, WALNUT_D)
    # ---- eyes: slanted (inner end lower), red glow, 1 px brighter core
    L_EYE = [(32, 17), (33, 17), (34, 18), (35, 18)]
    R_EYE = [(77 - x, y) for x, y in L_EYE]
    for eye in (L_EYE, R_EYE):
        for x, y in eye:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if (x + dx, y + dy) not in eye and up.px[x + dx, y + dy][:3] in (BROWN, WALNUT, WALNUT_L, SKIN_D):
                        up.dot(x + dx, y + dy, OUTLINE)
        for x, y in eye:
            up.dot(x, y, RED)
        up.dot(*eye[2], ORANGE)
        up.dot(eye[2][0] + (0 if eye is L_EYE else 0), eye[2][1], YELLOW)
    # ---- broad flat gorilla nose: a darker rounded shape, two nostril dots
    up.part(E((35, 19, 43, 22)), WALNUT, shade=False, line=False)
    up.flat(R((36, 19, 37, 19)), WALNUT_L)
    up.dot(37, 21, OUTLINE)
    up.dot(41, 21, OUTLINE)
    up.dot(36, 21, WALNUT_D)
    up.dot(42, 21, WALNUT_D)
    # ---- mouth: gorilla teeth, long UPPER canines
    def canine(x0, y0, n, up_=True):  # 2 px wide, n long, pointing down (or up); right column shaded
        for i in range(n):
            y = y0 + i
            up.dot(x0, y, WHITE)
            up.dot(x0 + 1, y, STEEL if i >= n - 2 else WHITE)
    if v == "1":  # closed snarl: lip curled up at the sides over two canines, small teeth between
        up.flat(P([(32, 26), (34, 25), (44, 25), (46, 26), (45, 27), (43, 28), (35, 28), (33, 27)]), OUTLINE)
        up.flat(P([(32, 24), (34, 23), (35, 25), (33, 26)]), WALNUT_D)  # lip curled up, left
        up.flat(P([(46, 24), (44, 23), (43, 25), (45, 26)]), WALNUT_D)
        up.dot(33, 24, WALNUT_L)
        for x in (38, 40):
            up.dot(x, 26, WHITE)  # small upper teeth
        up.dot(39, 27, SKIN_D)
        canine(35, 26, 3)
        canine(42, 26, 3)
        for x in range(36, 43):
            up.dot(x, 28, WALNUT)  # lower lip
        up.dot(35, 29, WALNUT_D)
        up.dot(43, 29, WALNUT_D)
    else:  # open roar: a dark oval, long upper canines, shorter lower ones, a row of small teeth
        up.flat(E((33, 23, 46, 30)), OUTLINE)
        canine(35, 24, 5)
        canine(43, 24, 5)
        for x in (38, 39, 40, 41):
            up.dot(x, 24, WHITE)  # small teeth
        canine(37, 28, 2)
        canine(41, 28, 2)
        up.flat(R((39, 29, 40, 29)), MAROON)  # a 2 px dark-red tongue
    # ---- broken circlet: a chunk gone from the tip, a dent, glints, one more crack
    up.flat(P([(23, 8), (27, 9), (25, 11), (23, 12)]), MAROON)
    up.flat(L([(23, 8), (27, 9), (25, 11), (23, 12)], 1), OUTLINE)
    up.dot(31, 7, WHITE)
    up.dot(40, 5, WHITE)
    up.dot(44, 7, ORANGE)
    up.dot(45, 7, ORANGE)
    up.dot(44, 6, OUTLINE)
    up.flat(L([(33, 9), (32, 11)], 1), OUTLINE)
    # ---- split pauldron: cracked top on the shoulder, a clear outlined plate hanging below on a strap
    metal(up, P([(7, 24), (8, 20), (12, 18), (17, 19), (18, 22), (14, 21), (11, 24)]))
    seam(up, [(12, 19), (11, 21), (13, 22)], BROWN)
    dent(up, 15, 20)
    seam(up, [(9, 24), (8, 27), (8, 29)], BROWN)  # strap
    metal(up, P([(4, 29), (11, 28), (12, 34), (8, 38), (4, 34)]))
    seam(up, [(5, 32), (11, 31)], GOLD_D)  # plate ridges
    seam(up, [(6, 35), (10, 34)], GOLD_D)
    up.dot(6, 30, WHITE)
    up.dot(7, 30, WHITE)
    up.dot(10, 33, GOLD_X)
    dent(up, 8, 36)
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
               "scratchpad/ape/ape_concepts3.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    apex = idle(g.wukong, g.wukong_clouds)
    cur = idle(g.wukong_ape, g.ape_storm)
    vs = [("CURRENT", cur), ("V1  CLOSED SNARL", idle(build("1"), g.ape_storm)), ("V2  OPEN ROAR", idle(build("2"), g.ape_storm))]
    for k, (_, fr) in zip(("cur", "v1", "v2"), vs):
        fr.save(out.parent / f"ape3_{k}_frame.png")
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
