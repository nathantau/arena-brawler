"""Great Ape concepts, round 10 (design stage only): V1 (closed snarl, round 3 face) vs V1f = V1 + ONE big, simple muscle
cuirass that replaces the brown belly disc (same footprint): two big pec domes, 2x2 ab blocks, a wide V-shaped split with
the belly fur bulging through, a crack across the right pec, the bottom-right corner notched away, snapped waist straps.
Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts10.py [out_png]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import generate as g
import ape_concepts3 as c3
from generate import P
from ape_concepts import font, idle, mask_of, show, BOX, GOLD_D, GOLD_X
from palette import BROWN, CREAM, CREAM_D, OUTLINE, ORANGE, SKIN_D, RED, WALNUT, WALNUT_D, WHITE, YELLOW


def cuirass(up):
    top, hem = 31, 44
    # ---- the V split: dark belly fur showing, 3 px wide at the hem tapering to 1 px at the sternum
    left_edge = [(33, 33), (32, 35), (32, 38), (31, 41), (30, hem)]
    right_edge = [(33, 33), (34, 35), (35, 38), (35, 41), (36, hem)]
    up.part(P(left_edge + right_edge[::-1]), WALNUT, shade=False, line=True)
    for x, y in ((33, 37), (33, 40), (32, 43), (34, 42), (33, 35), (34, 39), (33, 42)):
        up.dot(x, y, WALNUT_D)
    # ---- one shield-like torso plate: rounded shoulder corners, jagged missing bottom-right corner, the V cut out of it
    shape = P([(24, top), (42, top), (44, 33), (44, 38), (42, 39), (43, 41), (41, 42), (42, hem)] + right_edge[::-1][:-1]
              + left_edge[::-1][1:] + [(23, hem), (22, 40), (22, 33)])
    shape = P([(24, top), (42, top), (44, 33), (44, 38), (42, 39), (43, 41), (41, 42), (42, hem), (36, hem), (35, 41), (35, 38), (34, 35),
               (33, 33), (32, 35), (32, 38), (31, 41), (30, hem), (23, hem), (22, 40), (22, 33)])
    up.part(shape, ORANGE, shade=False, line=True)
    m = mask_of(shape, 64).load()
    ins = lambda x, y: 0 <= x < 64 and 0 <= y < 64 and m[x, y]
    for y in range(28, 46):
        for x in range(20, 47):
            if ins(x, y) and (not ins(x, y + 1) or not ins(x + 1, y)):
                up.dot(x, y, GOLD_X if (not ins(x, y + 2) and not ins(x + 2, y)) else GOLD_D)
    # ---- big forms only: two pec domes (lit upper-left arc, dark under-curve) ...
    for x, y in ((23, 36), (23, 35), (24, 34), (25, 33), (26, 33), (27, 32), (28, 32),
                 (35, 36), (35, 35), (36, 34), (37, 33), (38, 33), (39, 32), (40, 32)):
        up.dot(x, y, YELLOW)
    for x, y in ((23, 37), (24, 38), (25, 38), (26, 38), (27, 38), (28, 38), (29, 38), (30, 37),
                 (35, 37), (36, 38), (37, 38), (38, 38), (39, 38), (40, 38), (41, 38), (42, 37)):
        up.dot(x, y, GOLD_D)
    up.dot(25, 34, WHITE)  # the one glint, on the left pec
    # ... and two rows of 2 ab blocks (4x3), lit on the top edge only, dark underside
    for x0 in (24, 38):
        for y0 in (39, 42):
            for x in range(x0, x0 + 4):
                up.dot(x, y0, YELLOW if y0 == 39 else ORANGE)
                up.dot(x, y0 + 2, GOLD_D)
    # shoulder-corner rivets only
    up.dot(24, 32, RED)
    up.dot(42, 32, RED)
    # ---- one crack across the right pec, 1 px dark
    for x, y in ((43, 36), (42, 35), (41, 36), (40, 35), (39, 36), (38, 35), (37, 36)):
        up.dot(x, y, WALNUT_D)
    # ---- belly fur bulging out through the split (two tones) over the plate edges
    for x, y in ((31, 40), (35, 39), (32, 36), (34, 40)):
        up.dot(x, y, BROWN)
    for x, y in ((31, 43), (35, 43), (34, 37), (33, 44)):
        up.dot(x, y, WALNUT)
    # ---- snapped waist straps: 2 px dark stubs with a lit pixel
    for sx, d in ((21, -1), (45, 1)):
        for k in range(2):
            up.dot(sx + d * k, 40, GOLD_D)
            up.dot(sx + d * k, 41, GOLD_X)
        up.dot(sx, 40, ORANGE)
    up.dot(19, 41, GOLD_X)
    up.dot(47, 41, GOLD_X)

    # ---- makeshift twisted ropes stand in for the snapped shoulder straps: one per side, from the plate's top corner up over
    # the shoulder; the left tied tight and straight, the right with some slack; a small knot round each rivet, a loose end
    def line(p, q):
        n = max(abs(q[0] - p[0]), abs(q[1] - p[1]))
        return [(round(p[0] + (q[0] - p[0]) * i / n), round(p[1] + (q[1] - p[1]) * i / n)) for i in range(n + 1)]

    def rope(way):
        path = []
        for p, q in zip(way, way[1:]):
            path += [pt for pt in line(p, q) if pt not in path]
        body = {}
        for i, (x, y) in enumerate(path):
            body[(x, y)] = CREAM if i % 2 == 0 else CREAM_D
        for i, (x, y) in enumerate(path):
            body.setdefault((x + 1, y), CREAM_D if i % 2 == 0 else CREAM)
        for (x, y) in list(body):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) not in body:
                    up.dot(x + dx, y + dy, OUTLINE)
        for (x, y), c in body.items():
            up.dot(x, y, c)
        ex, ey = path[-1]
        up.dot(ex, ey, SKIN_D)  # darker where it curves away over the shoulder, behind
        up.dot(ex + 1, ey, SKIN_D)
        up.dot(ex, ey - 1, OUTLINE)
        up.dot(ex + 1, ey - 1, OUTLINE)

    def knot(cx, cy, loose):
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if abs(dx) + abs(dy) <= 3:
                    up.dot(cx + dx, cy + dy, OUTLINE)
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                up.dot(cx + dx, cy + dy, CREAM_D)
        up.dot(cx - 1, cy - 1, CREAM)
        up.dot(cx, cy - 1, CREAM)
        up.dot(cx, cy, RED)  # the rivet showing through the knot
        for k, (x, y) in enumerate(loose):
            for dx, dy in ((1, 0), (-1, 0), (0, 1)):
                if (x + dx, y + dy) not in loose:
                    up.dot(x + dx, y + dy, OUTLINE)
        for k, (x, y) in enumerate(loose):
            up.dot(x, y, CREAM if k % 2 == 0 else CREAM_D)

    rope([(24, 32), (24, 29), (25, 26), (26, 24)])  # left: tight, straight up beside the neck
    rope([(42, 32), (44, 30), (44, 28), (43, 27)])  # right: a touch slack, a small bow outward
    knot(24, 32, [(23, 35), (23, 36), (22, 37)])
    knot(42, 32, [(43, 35), (44, 36), (44, 37)])


def build(v):
    def f(step=None, t=0):
        low, up = g.wukong_ape(step, t)
        c3.enhance(up, "1")
        if v == "g":
            cuirass(up)
        return low, up
    return f


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else
               "/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/"
               "scratchpad/ape/ape_concepts10.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    apex = idle(g.wukong, g.wukong_clouds)
    vs = [("V1  (round 3)", idle(build("1"), g.ape_storm)), ("V1g  + BACKPACK ROPES", idle(build("g"), g.ape_storm))]
    for k, (_, fr) in zip(("v1", "v1g"), vs):
        fr.save(out.parent / f"ape10_{k}_frame.png")
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
