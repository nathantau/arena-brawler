"""Great Ape concepts, round 5 (design stage only): V1 (closed snarl, round 3) vs V1c = V1 with two clearly separate 2x4 fangs
and 1 px dim teeth between them, plus a dark-gold cuirass: straight top edge under the chin, two pec plates meeting in a centre
ridge, a flat hem; the right pec is split by a jagged crack (fur showing) with its bottom-right corner snapped off, the left is
dented. Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts5.py [out_png]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import generate as g
import ape_concepts3 as c3
from generate import E, L, P, R
from ape_concepts import dent, font, idle, mask_of, scratch, show, BOX, GOLD_D, GOLD_X
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
    # ---- cuirass
    top, hem = 31, 44
    left = [(21, top), (32, top), (32, hem), (26, hem), (24, 41), (22, 36)]
    right = [(33, top), (45, top), (44, 36), (43, 38), (41, 40), (42, 42), (39, hem), (33, hem)]
    dark_plate(up, P(left))
    dark_plate(up, P(right))
    for x in list(range(22, 32)) + list(range(34, 45)):
        up.dot(x, top, GOLD_X)  # dark rim along the top edge
        if (x + top) % 2 == 0 or x < 28:
            up.dot(x, top + 1, ORANGE)  # lit lip below it
    for y in range(top + 1, hem):
        up.dot(32, y, ORANGE)  # centre ridge: lit, then shaded
        up.dot(33, y, GOLD_X)
    for pts in ([(23, 35), (25, 33)], [(34, 35), (36, 33)]):  # pec curves: a lit arc on each upper-left
        for x, y in pts:
            up.dot(x, y, ORANGE)
    for x in list(range(24, 32)) + list(range(34, 41)):
        up.dot(x, 39, GOLD_X)  # the pecs sit over a lower tier
        if x < 31:
            up.dot(x, 40, ORANGE) if x % 2 == 0 else None
    # right pec: jagged crack, dark gap with fur showing
    path = [(39, 32), (38, 34), (40, 36), (38, 38), (39, 40), (37, 42), (38, 44)]
    up.flat(L(path, 1), WALNUT_D)
    for x, y in path:
        up.dot(x + 1, y, WALNUT_D)
    for x, y in ((39, 35), (38, 37), (39, 41), (38, 43)):
        up.dot(x, y, MAROON)
    up.dot(39, 39, RED)
    # left pec: one dent; right pec: one scratch with the glint
    dent(up, 26, 37)
    scratch(up, 42, 34, 2)


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
