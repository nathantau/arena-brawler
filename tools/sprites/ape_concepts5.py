"""Great Ape concepts, round 5 (design stage only): V1 (closed snarl, round 3) vs V1c = V1 with two clearly separate 2x4 fangs
and 1 px dim teeth between them, plus a dark-gold cuirass: straight top edge under the chin, two pec plates meeting in a centre
ridge, a flat hem; the right pec is split by a jagged crack (fur showing) with its bottom-right corner snapped off, the left is
dented. Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts5.py [out_png]
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import generate as g
import ape_concepts3 as c3
from generate import E, L, P, R
from ape_concepts import dent, font, idle, mask_of, scratch, seam, show, BOX, GOLD_D, GOLD_X
from palette import BROWN, MAROON, ORANGE, OUTLINE, RED, STEEL, WALNUT_D, WHITE


def dark_plate(c, shape):
    """Dark-gold plate: OCHRE_D body, BROWN shaded bottom/right edge, ORANGE only on the lit top-left edge."""
    c.part(shape, GOLD_D, shade=False, line=True)
    m = mask_of(shape, c.size).load()
    n = c.size
    ins = lambda x, y: 0 <= x < n and 0 <= y < n and m[x, y]
    for y in range(n):
        for x in range(n):
            if ins(x, y):
                if not ins(x, y + 1) or not ins(x + 1, y):
                    c.dot(x, y, GOLD_X)
                elif not ins(x, y - 1) or not ins(x - 1, y):
                    c.dot(x, y, ORANGE)


def tweak(up):
    # ---- fangs: two separate 2x4 fangs, each with its own outline, and two dim 1 px teeth with dark gaps
    for x0 in (35, 42):
        for y in range(26, 30):
            up.dot(x0 - 1, y, OUTLINE)
            up.dot(x0 + 2, y, OUTLINE)
            up.dot(x0, y, WHITE)
            up.dot(x0 + 1, y, STEEL if y >= 28 else WHITE)
        up.dot(x0, 30, OUTLINE)
        up.dot(x0 + 1, 30, OUTLINE)
    for x, y in ((37, 26), (38, 26), (39, 26), (40, 26), (41, 26), (39, 27), (38, 27), (40, 27)):
        up.dot(x, y, OUTLINE)
    up.dot(38, 26, STEEL)
    up.dot(40, 26, STEEL)
    # ---- cuirass: the left half still sits on his chest; the right half has torn away along a jagged break and hangs off
    # his right side on the last of its strap, tilted ~25 degrees, down past the belly toward the hip
    top = 31
    brk = [(33, 31), (31, 34), (33, 36), (30, 39), (32, 41), (29, 44)]  # jagged break edge, top to bottom
    gap = [(x + 2, y) for x, y in brk]
    up.part(P(brk + gap[::-1]), WALNUT_D, shade=False, line=False)  # dark gap, fur where the plate was
    for x, y in ((34, 33), (35, 35), (34, 37), (33, 40), (35, 42), (31, 43)):
        up.dot(x, y, MAROON)
    for x, y in ((35, 34), (34, 38), (33, 42)):
        up.dot(x, y, RED)
    dark_plate(up, P([(21, top)] + brk + [(26, 44), (24, 41), (22, 36)]))
    for x in range(22, 32):
        up.dot(x, top, GOLD_X)  # dark rim along the straight top edge
        up.dot(x, top + 1, ORANGE)  # lit lip below it
    for x in range(24, 30):
        up.dot(x, 39, GOLD_X)  # lower tier seam
    for x, y in ((23, 35), (24, 34), (25, 33)):
        up.dot(x, y, ORANGE)  # pec curve, lit
    up.dot(23, 32, WHITE)  # the one glint
    dent(up, 26, 37)
    # the torn-off half: a plate tilted 25 degrees, jagged inner edge, hanging from the shoulder strap
    local = [(-5, 0), (5, 0), (6, 5), (5, 11), (2, 14), (-3, 13), (-5, 10), (-3, 8), (-6, 5), (-3, 3)]
    a = math.radians(-25)
    pivot = (45, 32)
    hang = [(round(pivot[0] + x * math.cos(a) - y * math.sin(a)), round(pivot[1] + x * math.sin(a) + y * math.cos(a))) for x, y in local]
    dark_plate(up, P(hang))
    for (x0, y0), (x1, y1) in ((hang[9], hang[0]), (hang[0], hang[1])):  # lit upper edges
        for i in range(5):
            up.dot(x0 + (x1 - x0) * i // 4, y0 + (y1 - y0) * i // 4 + 1, ORANGE)
    up.dot(hang[1][0] - 1, hang[1][1] + 2, WHITE)
    p0, p1 = hang[0], hang[1]
    for i in range(5):  # its top rim
        up.dot(p0[0] + (p1[0] - p0[0]) * i // 4, p0[1] + (p1[1] - p0[1]) * i // 4, GOLD_X)
    seam(up, [hang[2], (hang[2][0] - 2, hang[2][1] + 3), (hang[2][0] - 1, hang[2][1] + 6)], GOLD_X)  # a crack in it
    # the strap: what is left of it holds the half to his shoulder; the other end snapped and frays from the left plate
    seam(up, [(45, 31), (48, 28), (49, 27)], BROWN)
    seam(up, [(46, 31), (49, 28)], BROWN)
    seam(up, [(33, 31), (35, 30)], BROWN)
    up.dot(36, 31, BROWN)
    up.dot(35, 32, OUTLINE)


def build(v):
    def f(step=None, t=0):
        low, up = g.wukong_ape(step, t)
        c3.enhance(up, "1")
        if v == "c":
            tweak(up)
        return low, up
    return f


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else
               "/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/"
               "scratchpad/ape/ape_concepts5.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    apex = idle(g.wukong, g.wukong_clouds)
    cur = idle(g.wukong_ape, g.ape_storm)
    vs = [("CURRENT", cur), ("V1  (round 3)", idle(build("1"), g.ape_storm)), ("V1c  + CUIRASS", idle(build("c"), g.ape_storm))]
    for k, (_, fr) in zip(("cur", "v1", "v1c"), vs):
        fr.save(out.parent / f"ape5_{k}_frame.png")
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
