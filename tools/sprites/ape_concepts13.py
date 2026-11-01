"""Great Ape concepts, round 13 (design stage only): the V1g body (round-3 face, broken cuirass, backpack ropes) inside a new,
more intimidating storm aura: heavy near-black indigo / steel clouds massed behind his head and shoulders, a few dense dark
cores, red-orange lightning forks crackling inside them, drifting embers, churning slowly. The aura is drawn on the whole 96 px
sheet cell (the current one is 64 px, so it can't loom above his head). Cloud colours (NAVY, VIOLET_D, STEEL_D) never overlap his
fur shade (SHADOW); a 1 px gap round the body turns into the dark outline.
Run: tools/sprites/.venv/bin/python tools/sprites/ape_concepts13.py [out_png]
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import generate as g
from generate import CELL, PAD, UPPER_DY, IDLE_BOB, outline
from ape_concepts import floor, font, idle
import ape_concepts3 as c3
from generate import P
from ape_concepts import mask_of, GOLD_D, GOLD_X
from palette import STEEL, BROWN, CREAM, CREAM_D, MAROON, NAVY, ORANGE, OUTLINE, RED, SKIN_D, STEEL_D, VIOLET_D, WALNUT, WALNUT_D, WHITE, YELLOW

# (x, y, radius, dense) in 96 px cell space; the mass sits low enough that nothing is clipped at the top of the cell
PUFFS = [(48, 17, 12, 1), (31, 23, 10, 0), (65, 22, 11, 0), (47, 29, 9, 1), (23, 29, 7, 1), (72, 28, 7, 0), (38, 13, 7, 0), (57, 12, 8, 1),
         (17, 34, 8, 0), (79, 34, 8, 0), (11, 45, 6, 0), (85, 44, 6, 1), (26, 16, 6, 0), (69, 15, 6, 0), (14, 24, 5, 0), (83, 24, 5, 0)]
# each frame: ONE lightning fork as (main path, [branch paths]); it moves round the cloud across the 4 frames of the loop
FORKS = [
    [([(27, 16), (30, 20), (26, 24), (30, 28)], [[(30, 20), (34, 22)], [(26, 24), (22, 26)]])],
    [([(64, 13), (67, 17), (63, 21), (66, 25)], [[(67, 17), (71, 19)], [(63, 21), (59, 23)]])],
    [([(50, 8), (47, 12), (51, 16), (47, 20)], [[(51, 16), (55, 18)], [(47, 12), (43, 14)]])],
    [([(20, 28), (23, 32), (20, 36), (23, 40)], [[(23, 32), (27, 34)]])],
]
WISPS = [  # curled S / hook tendrils in frame coords: left forearm, right hip, right forearm, and one short curl round an ankle
    [(22, 68), (22, 62), (24, 57), (29, 55), (33, 57), (33, 61), (30, 62)],
    [(76, 50), (74, 55), (70, 58), (69, 63), (72, 67), (76, 66)],
    [(84, 62), (82, 56), (84, 50), (88, 50), (88, 54)],
    [(35, 73), (37, 70), (41, 70), (43, 73)],
]
EMBERS = [(20, 50), (76, 44), (30, 62), (70, 60), (14, 34), (84, 50), (60, 30), (38, 72)]


def ropes(up):
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


def cuirass11(up):
    """V1h cuirass: a neckline that arches and dips, a jagged split that opens at the top (widest, fur bulging) and tapers to a
    point at the abs with two small branch cracks, a diagonal pec crack, short curved ab highlights."""
    hem = 44
    left_edge = [(30, 31), (29, 33), (31, 35), (30, 37), (32, 39), (33, 41), (33, 43)]
    right_edge = [(36, 31), (37, 33), (35, 35), (36, 37), (34, 39), (33, 41), (33, 43)]
    up.part(P(left_edge + right_edge[::-1]), WALNUT, shade=False, line=True)  # the burst: fur showing
    for x, y in ((32, 34), (33, 37), (33, 40)):
        up.dot(x, y, WALNUT_D)
    left = P([(22, 33), (24, 31), (26, 31), (27, 32), (29, 32)] + left_edge + [(32, hem), (23, hem), (22, 40)])
    right = P([(36, 31), (38, 32), (40, 32), (41, 31), (42, 31), (44, 33), (44, 38), (42, 39), (43, 41), (41, 42), (42, hem), (34, hem)]
              + right_edge[::-1][1:])
    up.part(left, ORANGE, shade=False, line=True)
    up.part(right, ORANGE, shade=False, line=True)
    m1, m2 = mask_of(left, 64).load(), mask_of(right, 64).load()
    ins = lambda x, y: 0 <= x < 64 and 0 <= y < 64 and (m1[x, y] or m2[x, y])
    for y in range(28, 46):
        for x in range(20, 47):
            if ins(x, y) and (not ins(x, y + 1) or not ins(x + 1, y)):
                up.dot(x, y, GOLD_X if (not ins(x, y + 2) and not ins(x + 2, y)) else GOLD_D)
    # pec domes: lit upper-left arc, dark under-curve
    for x, y in ((23, 36), (23, 35), (24, 34), (25, 33), (26, 33), (27, 33),
                 (38, 36), (38, 35), (39, 34), (40, 33), (41, 33)):
        up.dot(x, y, YELLOW)
    for x, y in ((23, 37), (24, 38), (25, 38), (26, 38), (27, 38), (28, 37),
                 (38, 37), (39, 38), (40, 38), (41, 38), (42, 38), (43, 37)):
        up.dot(x, y, GOLD_D)
    up.dot(25, 34, WHITE)  # the one glint
    # ab blocks (3x3), only a short lit highlight on the top edge, offset a pixel per row so they don't line up
    for x0, y0 in ((25, 39), (24, 42), (38, 39), (39, 42)):
        up.dot(x0, y0, YELLOW)
        up.dot(x0 + 1, y0, YELLOW)
        for x in range(x0, x0 + 3):
            up.dot(x, y0 + 2, GOLD_D)
    up.dot(24, 32, RED)  # shoulder-corner rivets
    up.dot(42, 32, RED)
    # a diagonal jagged crack across the right pec
    for x, y in ((43, 34), (42, 35), (42, 36), (41, 36), (41, 37), (40, 37), (40, 38), (39, 39)):
        up.dot(x, y, WALNUT_D)
    # fur bulging through at the top of the split, over both plate edges
    for x, y in ((30, 32), (31, 31), (35, 32), (36, 33), (30, 34), (35, 34)):
        up.dot(x, y, BROWN)
    # snapped waist straps
    for sx, d in ((21, -1), (45, 1)):
        for k in range(2):
            up.dot(sx + d * k, 40, GOLD_D)
            up.dot(sx + d * k, 41, GOLD_X)
        up.dot(sx, 40, ORANGE)
    up.dot(19, 41, GOLD_X)
    up.dot(47, 41, GOLD_X)
    ropes(up)


def build11(step=None, t=0):
    low, up = g.wukong_ape(step, t)
    c3.enhance(up, "1")
    cuirass11(up)
    return low, up


def puff(img, cx, cy, r, dense, k):
    """An irregular, lumpy cloud puff: wobbling radius, flattened top, torn dithered edge, lit top-left rim, darker dithered
    underside (denser ones get more of it)."""
    px = img.load()
    R = int(r * 1.5) + 2
    for y in range(cy - R, cy + R + 1):
        for x in range(cx - R, cx + R + 1):
            if not (0 <= x < CELL and 0 <= y < CELL):
                continue
            dx, dy = x - cx, y - cy
            if dy < 0:
                dy *= 1.3  # flattened top
            th = math.atan2(dy, dx)
            rad = r * (1 + 0.16 * math.sin(3 * th + k * 1.7) + 0.10 * math.sin(5 * th + k * 2.9))
            d = math.hypot(dx, dy) / rad
            if d > 1.0:
                continue
            if d > 0.84 and (x * 7 + y * 3 + k) % 4 == 0:
                continue  # torn edge
            lit = -(dx + dy) * 0.7071 / rad
            hz = ((x * 73856093) ^ (y * 19349663) ^ (k * 83492791)) % 100  # irregular, not a checker
            if lit > 0.55 and d > 0.7:
                c = STEEL_D
            elif lit > 0.2 and d > 0.45:
                c = NAVY
            elif lit > 0.0 and d > 0.5 and hz < 48:
                c = NAVY
            else:
                c = VIOLET_D
                if lit < (-0.3 if dense else -0.5) and hz < 48 and d < 0.85:
                    c = OUTLINE  # soft darker dithered shading, not a hole
            px[x, y] = c + (255,)


def aura11(i):
    """The new storm aura on a CELL x CELL image; loops every 4 frames."""
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for k, (x, y, r, dense) in enumerate(PUFFS):
        ph = i / 4
        dx = round(math.sin(2 * math.pi * (ph + k * 0.37)))
        dy = round(math.cos(2 * math.pi * (ph + k * 0.53)))
        rr = r + (1 if math.sin(2 * math.pi * (ph + k * 0.21)) > 0.6 else 0)
        puff(img, x + dx, y + dy, rr, dense, k)
    cloud = img.load()

    def trace(path):
        pts = []
        for p, q in zip(path, path[1:]):
            n = max(abs(q[0] - p[0]), abs(q[1] - p[1]))
            pts += [(round(p[0] + (q[0] - p[0]) * t / n), round(p[1] + (q[1] - p[1]) * t / n)) for t in range(n + 1)]
        return [(x, y) for x, y in pts if 0 <= x < CELL and 0 <= y < CELL and cloud[x, y][3]]

    bolt = []
    for main, branches in FORKS[i % len(FORKS)]:
        bolt += trace(main)
        for b in branches:
            bolt += trace(b)
    bset = set(bolt)
    for x, y in bolt:
        for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + ddx, y + ddy
            if 0 <= nx < CELL and 0 <= ny < CELL and cloud[nx, ny][3] and (nx, ny) not in bset:
                cloud[nx, ny] = RED + (255,)
    for x, y in bolt:
        cloud[x, y] = ORANGE + (255,)
    for main, _ in FORKS[i % len(FORKS)]:
        pts = trace(main)
        if pts:
            cloud[pts[len(pts) // 2]] = YELLOW + (255,)
    return img


def draw_wisps(f, i, body_alpha):
    """Thin dithered tendrils of the storm palette curling round his limbs; not over the face or the plate centre."""
    px = f.load()
    covered = 0
    for k, path in enumerate(WISPS):
        ph = i / 4 + k * 0.29
        ox, oy = round(2 * math.sin(2 * math.pi * ph)), round(1.4 * math.cos(2 * math.pi * ph))
        pts = []
        for p, q in zip(path, path[1:]):
            n = max(abs(q[0] - p[0]), abs(q[1] - p[1]))
            pts += [(p[0] + (q[0] - p[0]) * t / n, p[1] + (q[1] - p[1]) * t / n) for t in range(n)]
        n = len(pts)
        for t, (x, y) in enumerate(pts):
            x = round(x + ox + 1.2 * math.sin(t / 3 + ph * 6.28))
            y = round(y + oy)
            th = 1 if t < 3 or t > n - 4 else (3 if n / 3 < t < 2 * n / 3 else 2)
            cells = []
            for row in range(th):
                c = STEEL if row == 0 else STEEL_D if row == 1 else NAVY
                cells.append((x, y + row, c))
            if t % 2 == 0:
                cells.append((x, y + th, NAVY))  # dithered lower edge
            else:
                cells.append((x, y - 1, STEEL_D))  # dithered upper edge
            for cx, cy, c in cells:
                if not (0 <= cx < CELL and 0 <= cy < CELL):
                    continue
                if 42 <= cx <= 62 and 28 <= cy <= 64:
                    continue  # keep the face / plate centre clear
                if 42 <= cx <= 68 and 28 <= cy <= 49:
                    continue
                px[cx, cy] = c + (255,)
                if body_alpha[cx, cy]:
                    covered += 1
    return covered


def frame11(i):
    """Idle frame i of the V1g ape inside the new aura, with a dark gap round the body and embers on top."""
    low, up = build11(None, i)
    body = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    body.alpha_composite(low.img, (PAD, PAD))
    body.alpha_composite(up.img, (PAD, PAD + UPPER_DY + IDLE_BOB[i % 4]))
    grow = body.getchannel("A").filter(ImageFilter.MaxFilter(3))  # body + 1 px: cleared from the clouds -> outlined gap
    f = aura11(i)
    f.paste((0, 0, 0, 0), mask=grow)
    f.alpha_composite(body)
    f = outline(f)
    cov = draw_wisps(f, i, body.getchannel("A").load())
    frame11.coverage = cov / max(1, sum(1 for v in body.getchannel("A").getdata() if v))
    px = f.load()
    for k, (x, y) in enumerate(EMBERS):  # tiny embers drifting up and sideways, drawn after the outline so they stay bright
        ex, ey = x + (i * 1 if k % 2 else -i * 1), y - i * 2 - (k % 3)
        if 0 <= ex < CELL and 0 <= ey < CELL and not px[ex, ey][3]:
            px[ex, ey] = (ORANGE if k % 3 == 0 else RED) + (255,)
    return f


BOX = (0, 0, 96, 88)


def view(fr, zoom):
    z = fr.crop(BOX)
    bg = floor(z.width, z.height)
    bg.alpha_composite(z)
    return bg.resize((z.width * zoom, z.height * zoom), Image.NEAREST)


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else
               "/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/"
               "scratchpad/ape/ape_concepts13.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    frames = []
    for i in range(3):
        frames.append(frame11(i))
        print("wisp pixels over the body, frame", i, "=", round(frame11.coverage * 100, 1), "% of body pixels")
        top = frames[-1].getbbox()[1]
        print("  cloud top row:", top)
    for i, f in enumerate(frames):
        f.save(out.parent / f"ape13_v1i_f{i}.png")
    bw, bh = BOX[2] - BOX[0], BOX[3] - BOX[1]
    Z, pad = 8, 24
    W = max(pad + bw * Z + pad, pad + 3 * (bw * 4 + 20))
    H = 62 + bh * Z + 24 + 30 + bh * 4 + 20 + 30 + bh * 3 + 40
    sheet = Image.new("RGBA", (W, H), (24, 24, 36, 255))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 20), "V1j  (storm aura + wisps)", fill=(240, 240, 230), font=font(30))
    sheet.alpha_composite(view(frames[0], Z), (pad, 62))
    y = 62 + bh * Z + 24
    d.text((pad, y), "V1j loop, frames 0 / 1 / 2 of 4  (4x)", fill=(240, 240, 230), font=font(22))
    for i, f in enumerate(frames):
        sheet.alpha_composite(view(f, 4), (pad + i * (bw * 4 + 20), y + 30))
    y2 = y + 30 + bh * 4 + 20
    d.text((pad, y2), "1x / 2x", fill=(240, 240, 230), font=font(22))
    for i, fr in enumerate(frames):
        x = pad + i * (bw * 2 + 20)
        sheet.alpha_composite(view(fr, 1), (x, y2 + 30))
        sheet.alpha_composite(view(fr, 2), (x, y2 + 30 + bh + 8))
        d.text((x, y2 + 30 + bh * 3 + 14), f"V1j f{i}", fill=(190, 190, 200), font=font(16))
    sheet.convert("RGB").save(out)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()
