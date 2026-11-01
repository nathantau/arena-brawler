"""Great Ape concepts, round 4 (design stage only): V1 (closed snarl, round 3) vs V1b = V1 with smaller teeth between longer
fangs and a broken gold chest plate (cracked along a jagged diagonal, a corner snapped off, dented and scratched).
Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts4.py [out_png]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import generate as g
import ape_concepts3 as c3
from generate import E, L, P, R
from ape_concepts import dent, font, idle, metal, scratch, seam, show, BOX, GOLD_D, GOLD_X
from palette import BROWN, MAROON, OUTLINE, RED, STEEL, STEEL_D, WALNUT_D, WHITE


def tweak(up):
    # teeth: three tiny dim teeth between the fangs, fangs 1 px longer
    for x, y in ((38, 26), (40, 26)):
        up.dot(x, y, OUTLINE)
    for x, y in ((38, 26), (40, 26), (39, 27)):
        up.dot(x, y, STEEL)
    for x0 in (35, 42):
        up.dot(x0, 29, WHITE)
        up.dot(x0 + 1, 29, STEEL)
    # broken chest plate: two pieces split along a jagged diagonal, a dark gap with fur, the top-right corner snapped off
    left = [(33, 32), (31, 35), (33, 37), (30, 40), (31, 42), (29, 44)]
    right = [(33, 44), (35, 42), (34, 40), (37, 37), (35, 35), (37, 32)]
    up.part(P(left + right), WALNUT_D, shade=False, line=True)
    for x, y in ((34, 34), (34, 38), (33, 41), (35, 36)):
        up.dot(x, y, MAROON)  # fur showing through the gap
    up.dot(34, 36, RED)
    metal(up, P([(26, 34), (28, 32)] + left + [(27, 43), (25, 39)]))
    metal(up, P([(37, 32), (39, 32), (39, 34), (41, 35), (41, 41), (39, 44)] + right[:-1]))
    seam(up, [(26, 39), (30, 39)], GOLD_D)  # one lame line
    dent(up, 29, 36)
    scratch(up, 27, 34, 2)
    scratch(up, 38, 39, 2)
    up.dot(40, 38, WHITE)
    # a snapped-off corner shard fallen on the belly side, and a short broken strap over the shoulder
    seam(up, [(26, 33), (23, 30), (21, 29)], BROWN)
    seam(up, [(19, 28), (18, 30)], BROWN)


def build(v):
    def f(step=None, t=0):
        low, up = g.wukong_ape(step, t)
        c3.enhance(up, "1")
        if v == "b":
            tweak(up)
        return low, up
    return f


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else
               "/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/"
               "scratchpad/ape/ape_concepts4.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    apex = idle(g.wukong, g.wukong_clouds)
    cur = idle(g.wukong_ape, g.ape_storm)
    vs = [("CURRENT", cur), ("V1  (round 3)", idle(build("1"), g.ape_storm)), ("V1b  + CHEST PLATE", idle(build("b"), g.ape_storm))]
    for k, (_, fr) in zip(("cur", "v1", "v1b"), vs):
        fr.save(out.parent / f"ape4_{k}_frame.png")
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
