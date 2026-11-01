"""Great Ape concepts, round 7 (design stage only): V1 (closed snarl, round 3 face) vs V1e = V1 + a Trojan-style muscle cuirass
that is Apex's own armour (gold plate, orange lames, red rivets, specular) burst on the much bigger body:
undersized (fur on both flanks), cracked down the centre with the gap widened by bulging fur, a crack across a pec,
side straps snapped, one shoulder strap broken and flapping, edges splayed, a chunk gone from the bottom corner, shards falling.
Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts7.py [out_png]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import generate as g
import ape_concepts3 as c3
from generate import P
from ape_concepts import dent, font, idle, metal, seam, show, BOX, GOLD_D
from palette import BROWN, MAROON, ORANGE, OUTLINE, RED, SHADOW, WALNUT_D, WHITE, YELLOW


def cuirass(up):
    top, hem = 33, 44
    # ---- the gap down the centre: fur bulging through, dark where the plates leave it
    left_edge = [(32, top), (31, 35), (32, 37), (30, 39), (31, 41), (29, hem)]
    right_edge = [(35, top), (34, 35), (35, 37), (33, 39), (34, 41), (32, hem)]
    up.part(P(left_edge + right_edge[::-1]), MAROON, shade=False, line=True)
    for x, y in ((32, 34), (33, 36), (32, 38), (31, 40), (31, 43), (33, 41)):
        up.dot(x, y, SHADOW)  # shadowed fur
    for x, y in ((33, 35), (34, 37), (32, 40), (32, 42)):
        up.dot(x, y, RED)  # lit fur tufts pushing out
    # ---- left half (intact apart from the splayed edge) and right half (chunk gone from the bottom-right corner)
    metal(up, P([(26, top), (32, top), (31, 35), (32, 37), (30, 39), (31, 41), (29, hem), (23, hem), (25, 39)]))
    metal(up, P([(35, top), (40, top), (41, 39), (42, 41), (40, 42), (41, 43), (38, hem), (32, hem), (34, 41), (33, 39), (35, 37), (34, 35)]))
    # sculpted pecs, top-left light: lit arc over each upper curve, shaded underline beneath
    for x, y in ((27, 35), (28, 34), (29, 34), (30, 34), (36, 35), (37, 34), (38, 34), (39, 34)):
        up.dot(x, y, YELLOW)
    for x, y in ((26, 38), (27, 39), (28, 39), (29, 39), (30, 38), (36, 39), (37, 39), (38, 39), (39, 38)):
        up.dot(x, y, GOLD_D)
    for x, y in ((26, 37), (36, 38)):
        up.dot(x, y, ORANGE)
    # ab ridges (Apex's lames): a dark line with a lit pixel row above
    for x0, x1 in ((25, 29), (34, 39)):
        for x in range(x0, x1 + 1):
            up.dot(x, 41, GOLD_D)
            if x % 4 == 0:
                up.dot(x, 40, YELLOW)
    up.dot(28, 43, GOLD_D)
    up.dot(37, 43, GOLD_D)
    up.dot(26, 42, RED)  # Apex's red rivets
    up.dot(39, 42, RED)
    up.dot(26, 34, WHITE)  # his specular (the one glint)
    up.dot(27, 34, WHITE)
    dent(up, 28, 36)
    # a crack across the right pec, fur showing
    for x, y in ((40, 36), (39, 36), (38, 37), (37, 37)):
        up.dot(x, y, WALNUT_D)
    up.dot(39, 37, MAROON)
    up.dot(38, 38, RED)
    # ---- snapped side straps: short stubs with frayed ends
    seam(up, [(25, 38), (23, 39)], BROWN)
    up.dot(22, 40, BROWN)
    up.dot(22, 38, OUTLINE)
    seam(up, [(41, 37), (43, 38)], BROWN)
    up.dot(44, 36, BROWN)
    up.dot(44, 39, BROWN)
    # shoulder straps: the left one holds; the right one broke and flaps out
    seam(up, [(26, 33), (23, 31), (20, 29)], GOLD_D)
    seam(up, [(26, 34), (23, 32)], BROWN)
    seam(up, [(40, 33), (42, 32)], GOLD_D)  # stub
    up.dot(43, 31, BROWN)
    seam(up, [(45, 32), (48, 34), (49, 37)], GOLD_D)  # the loose end, flapping out
    seam(up, [(45, 33), (47, 35)], BROWN)
    up.dot(50, 38, BROWN)
    up.dot(48, 38, OUTLINE)
    # shards falling from the broken corner
    metal(up, P([(44, 44), (47, 43), (46, 46)]), lo2=False)
    metal(up, P([(43, 48), (45, 47), (45, 50)]), lo2=False)


def build(v):
    def f(step=None, t=0):
        low, up = g.wukong_ape(step, t)
        c3.enhance(up, "1")
        if v == "e":
            cuirass(up)
        return low, up
    return f


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else
               "/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/"
               "scratchpad/ape/ape_concepts7.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    apex = idle(g.wukong, g.wukong_clouds)
    vs = [("V1  (round 3)", idle(build("1"), g.ape_storm)), ("V1e  + MUSCLE CUIRASS", idle(build("e"), g.ape_storm))]
    for k, (_, fr) in zip(("v1", "v1e"), vs):
        fr.save(out.parent / f"ape7_{k}_frame.png")
    Z, pad = 8, 24
    bw, bh = BOX[2] - BOX[0], BOX[3] - BOX[1]
    W = pad + bw * 4 + pad + 2 * (bw * Z + pad)
    H = 62 + bh * Z + 24 + 30 + bh * 3 + 40
    sheet = Image.new("RGBA", (W, H), (24, 24, 36, 255))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 20), "APEX  (4x, armour reference)", fill=(240, 240, 230), font=font(22))
    sheet.alpha_composite(show(apex, 4), (pad, 62))
    x0 = pad + bw * 4 + pad
    for i, (label, fr) in enumerate(vs):
        x = x0 + i * (bw * Z + pad)
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
