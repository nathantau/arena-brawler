"""Great Ape concepts, round 6 (design stage only): V1 (closed snarl, round 3) vs V1d = V1 (face, mouth and teeth identical to round 3) plus a broken cuirass in the SAME gold ramp as the split pauldron (metal()): a small left-pec plate and a smaller
plate hanging tilted ~30 deg from a 2 px strap beside his right side, with the brown belly disc showing between them.
Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts6.py [out_png]
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import generate as g
import ape_concepts3 as c3
from generate import E, L, P, R
from ape_concepts import dent, font, idle, metal, seam, show, BOX, GOLD_D, GOLD_X
from palette import ORANGE, BROWN, MAROON, OUTLINE, RED, SKIN_D, STEEL, WALNUT_D, WHITE


def tweak(up):
    # ---- left pec plate: straight top edge (a brown fur gap under the chin), curved outer edge, jagged inner break edge
    top = 34
    metal(up, P([(24, top), (33, top), (30, 36), (32, 38), (29, 40), (31, 42), (29, 44), (25, 44), (23, 42), (22, 39), (22, 36)]))
    for x, y in ((33, 37), (32, 40), (33, 43), (31, 39)):
        up.dot(x, y, MAROON)  # fur showing where the plate broke
    up.dot(33, 41, RED)
    up.dot(32, 35, WALNUT_D)
    seam(up, [(24, 40), (28, 40)], GOLD_D)  # lower tier seam
    dent(up, 26, 37)
    # ---- the torn-off half: smaller, tilted ~30 deg, hanging from its top corner on the strap, beside his right side
    local = [(0, 0), (6, 0), (6, 8), (4, 11), (1, 11), (-1, 8), (1, 6), (-1, 3)]
    a = math.radians(30)
    pivot = (47, 33)
    hang = [(round(pivot[0] + x * math.cos(a) - y * math.sin(a)), round(pivot[1] + x * math.sin(a) + y * math.cos(a))) for x, y in local]
    # strap first (drawn under the plate's corner): 2 px dark brown, a lighter top pixel
    seam(up, [(49, 28), (47, 33)], GOLD_D)
    seam(up, [(50, 28), (48, 33)], GOLD_D)
    up.dot(49, 28, ORANGE)
    up.dot(50, 28, ORANGE)
    metal(up, P(hang))
    seam(up, [hang[3], (hang[3][0] - 1, hang[3][1] - 3)], GOLD_X)  # a crack
    # the strap's other end snapped and frays from the left plate's corner
    seam(up, [(33, 34), (35, 35)], BROWN)
    up.dot(36, 36, BROWN)


def build(v):
    def f(step=None, t=0):
        low, up = g.wukong_ape(step, t)
        c3.enhance(up, "1")
        if v == "d":
            tweak(up)
        return low, up
    return f


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else
               "/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/"
               "scratchpad/ape/ape_concepts6.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    apex = idle(g.wukong, g.wukong_clouds)
    cur = idle(g.wukong_ape, g.ape_storm)
    vs = [("CURRENT", cur), ("V1  (round 3)", idle(build("1"), g.ape_storm)), ("V1d  + BROKEN CUIRASS", idle(build("d"), g.ape_storm))]
    for k, (_, fr) in zip(("cur", "v1", "v1d"), vs):
        fr.save(out.parent / f"ape6_{k}_frame.png")
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
