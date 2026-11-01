"""Bolt redesign concepts: a regular guy in a track suit ("normal") who powers up into GODSPEED (yellow spiky hair, lightning).
Design stage only: a single front idle frame per look, nothing is written into assets/.
Run: tools/sprites/.venv/bin/python tools/sprites/bolt_concepts.py
Only palette colours are used. Output: OUT_DIR/bolt_concepts.png plus bolt_<a|b|c>.png."""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw  # noqa: E402

import generate as g  # noqa: E402
from generate import BODY, FACE, FACE_R, L, P, R, RR, Canvas, arm, legs, big_eyes, zap_arc, zap_zig, arcs_from  # noqa: E402
from palette import (OUTLINE, SHADOW, STEEL, STEEL_D, WHITE, YELLOW, RED, TEAL_L, TEAL, ORANGE, SKIN, SKIN_D, MAROON, NAVY,
                     BLUE, BROWN, DARKER, LIGHTER)  # noqa: E402

OUT_DIR = Path("/private/tmp/claude-501/-Users-nathan-Documents-programming/961ae1a4-1456-4311-9df7-6959d23f560c/scratchpad/bolt")
ROOT = Path(__file__).resolve().parents[2]
O = 16  # a 64 px art coordinate -> the 96 px cell (cell padding)
HAIR_BLACK = SHADOW  # shades to OUTLINE, rim-lit with STEEL_D: reads as black hair


def pts(ps):
    return [(x + O, y + O) for x, y in ps]


def spike(xc, tip_x, tip_y, hw, base=16):
    return pts([(xc - hw, base), (tip_x, tip_y), (xc + hw, base)])


# --- variants -----------------------------------------------------------------------------------------------------------------
# suit / stripe / shoe accent, hair colour and style, and how loud the godspeed look is.
VARIANTS = {
    "a": dict(name="A  navy suit, white stripes, short brown hair  |  godspeed: five tall spikes, tight arcs, dithered gold glow",
              suit=NAVY, stripe=WHITE, accent=BLUE, hair=BROWN, style="tufts", eyes=YELLOW, god="A",
              spikes=[(22, 19, -2, 4), (27, 25, -8, 4.5), (33, 33, -13, 5), (39, 41, -8, 4.5), (44, 47, -2, 4)]),
    "b": dict(name="B  teal suit, white stripes, spiky black hair  |  godspeed: huge spikes, white-hot eyes, big forked bolts, blue-gold aura",
              suit=TEAL, stripe=WHITE, accent=TEAL_L, hair=HAIR_BLACK, style="spiky", eyes=WHITE, god="B",
              spikes=[(20, 15, 0, 3.5), (24, 20, -8, 4), (28, 26, -14, 4), (33, 33, -17, 4.5), (38, 40, -14, 4),
                      (42, 46, -8, 4), (46, 51, 0, 3.5)]),
    "c": dict(name="C  maroon retro suit, gold stripes, swept brown hair  |  godspeed: wind-swept flame spikes, sparse arcs, soft halo",
              suit=MAROON, stripe=YELLOW, accent=RED, hair=BROWN, style="swept", eyes=YELLOW, god="C",
              spikes=[(21, 11, -4, 4), (26, 18, -10, 4.5), (32, 26, -14, 5), (38, 34, -11, 4.5), (43, 42, -5, 4)]),
}


def build_legs(v):
    low = Canvas()
    suit, stripe = v["suit"], v["stripe"]
    for x, dy in legs(low, suit, WHITE, None):
        low.flat(L([(x + 4, 46 + dy), (x + 4, 51 + dy)], 1), stripe)  # side stripe
        low.flat(R((x, 51 + dy, x + 5, 51 + dy)), DARKER[suit])  # elastic cuff
        low.flat(L([(x + 1, 47 + dy), (x + 1, 49 + dy)], 1), LIGHTER[suit])  # lit fold
        low.flat(R((x + 4, 55 + dy, x + 6, 56 + dy)), v["accent"])  # sneaker toe accent
        low.dot(x + 2, 54 + dy, STEEL)  # laces
        low.dot(x + 3, 55 + dy, STEEL)
    return low


def build_body(v):
    suit, stripe = v["suit"], v["stripe"]
    a = Canvas()
    arm(a, g.ARM_X[0], suit, SKIN)
    a.flat(L([(g.ARM_X[0] + 1, 37), (g.ARM_X[0] + 1, 41)], 1), stripe)
    a.flat(R((g.ARM_X[0], 41, g.ARM_X[0] + 5, 41)), DARKER[suit])
    a.part(RR(BODY, 3), suit)  # jacket
    a.flat(R((20, 46, 44, 47)), DARKER[suit])  # ribbed hem
    a.flat(L([(20, 37), (20, 45)], 1), stripe)  # side stripe down the back of the jacket
    a.flat(L([(33, 38), (33, 47)], 1), STEEL)  # zip
    a.flat(L([(34, 38), (34, 47)], 1), STEEL_D)
    a.flat(R((32, 38, 34, 39)), WHITE)  # pull
    a.flat(R((24, 37, 43, 37)), stripe)  # collar edge under the chin
    a.flat(L([(25, 41), (26, 41)], 1), stripe)  # little chest logo
    a.dot(26, 42, stripe)
    a.dot(38, 40, LIGHTER[suit])  # sheen
    a.dot(38, 41, LIGHTER[suit])
    arm(a, g.ARM_X[1], suit, SKIN)
    a.flat(L([(g.ARM_X[1] + 4, 37), (g.ARM_X[1] + 4, 41)], 1), stripe)
    a.flat(R((g.ARM_X[1], 41, g.ARM_X[1] + 5, 41)), DARKER[suit])
    return a


def hair_layer(v, a, god):
    """The 96 px canvas: the body pasted in, then the hair mass (with its spikes above the art box) over it."""
    h = Canvas(g.CELL)
    h.img.paste(a.img, (O, O))
    h.px = h.img.load()
    col = YELLOW if god else v["hair"]
    mass = lambda d, f: d.ellipse((16 + O, 6 + O, 48 + O, 37 + O), f)
    if god:
        spikes = v["spikes"]
        h.part(lambda d, f: (mass(d, f), [d.polygon(spike(*s), f) for s in spikes]), col)
        # hair lock down the back of the head, flaring out
        h.part(P(pts([(18, 24), (11, 30), (15, 29), (12, 35), (20, 32), (22, 26)])), col)
        if v["god"] == "C":
            h.part(P(pts([(18, 20), (6, 22), (14, 25), (4, 30), (17, 29)])), col)  # streaming back
        for xc, tx, ty, hw in spikes[1:-1]:  # one lit pixel line up each inner spike
            h.flat(L(pts([(xc - 1, 11), (xc - 1 + (tx - xc) // 3, ty + 4)]), 1), WHITE)
        return h
    style = v["style"]
    parts = []
    if style == "tufts":
        parts = [[(25, 11), (27, 3), (33, 9)], [(32, 9), (38, 2), (43, 10)], [(18, 14), (17, 8), (24, 11)]]
    elif style == "spiky":
        parts = [[(19, 14), (17, 5), (25, 10)], [(24, 10), (25, 0), (31, 8)], [(30, 8), (35, -1), (40, 8)],
                 [(38, 9), (46, 1), (47, 12)], [(44, 12), (52, 8), (49, 18)]]
    elif style == "swept":
        parts = [[(22, 10), (14, 3), (30, 8)], [(28, 8), (22, 0), (38, 8)], [(36, 8), (36, 1), (45, 10)]]
    h.part(lambda d, f: (mass(d, f), [d.polygon(pts(p), f) for p in parts]), col)
    h.part(P(pts([(18, 24), (12, 30), (16, 29), (14, 34), (21, 31), (22, 26)])), col)  # nape hair
    if style == "swept":
        h.part(P(pts([(18, 22), (8, 25), (14, 27), (7, 33), (19, 30)])), col)  # longer back lock
    h.flat(L(pts([(22, 9), (30, 6)]), 1), LIGHTER[col])
    return h


def face_layer(v, h, god):
    """Face, fringe, eyes and mouth in 64 px art coordinates over the hair canvas."""
    b = Canvas()
    b.img.paste(h.img.crop((O, O, O + 64, O + 64)))
    b.px = b.img.load()
    col = YELLOW if god else v["hair"]
    b.part(RR(FACE, FACE_R), SKIN)
    b.flat(L([(FACE[0] + 3, FACE[3] - 2), (FACE[2] - 4, FACE[3] - 1)], 1), SKIN_D)  # chin shade
    # fringe: a swept chunk across the forehead ending in points; spikier when powered up
    if god:
        fr = [(21, 15), (49, 15), (49, 19), (46, 17), (44, 19), (40, 17), (37, 19), (34, 16), (31, 19), (28, 16), (25, 19), (22, 20)]
    elif v["style"] == "spiky":
        fr = [(21, 15), (49, 15), (49, 18), (45, 17), (42, 20), (38, 17), (34, 19), (30, 16), (26, 19), (22, 18)]
    elif v["style"] == "swept":
        fr = [(21, 15), (49, 15), (49, 17), (40, 18), (32, 17), (25, 19), (22, 22)]
    else:
        fr = [(21, 15), (49, 15), (49, 18), (44, 17), (39, 20), (34, 18), (29, 20), (24, 22), (22, 20)]
    b.part(P(fr), col, shade=False)
    for x in range(21, 50):  # no seam where the fringe meets the hair mass
        if b.px[x, 14][:3] == OUTLINE and b.px[x, 13][3] and b.px[x, 13][:3] != OUTLINE:
            b.px[x, 14] = b.px[x, 13]
    # side lock hanging in front of the ear (the far side)
    b.part(P([(FACE[2] - 1, 17), (50, 18), (50 + (1 if god else 0), 25), (48, 23), (FACE[2], 22)]), col, shade=False)
    # eyes
    if god:
        for x in g.EYES_X:
            b.flat(R((x, 22, x + 3, 27)), OUTLINE)
            if v["god"] == "B":  # white-hot
                b.flat(R((x, 23, x + 3, 26)), WHITE)
                b.flat(R((x + 1, 24, x + 2, 25)), TEAL_L)
            else:
                b.flat(R((x, 24, x + 3, 26)), v["eyes"])
                b.flat(R((x + 1, 25, x + 2, 25)), WHITE)
            b.dot(x, 22, WHITE)
        b.flat(L([(30, 21), (35, 22)], 1), OUTLINE)  # determined brows
        b.flat(L([(40, 22), (45, 21)], 1), OUTLINE)
    else:
        big_eyes(b, g.EYES_Y, g.EYES_X, BROWN)
    g.face(b, g.BLUSH, None)
    if god:  # confident open grin
        b.flat(R((36, 29, 41, 31)), MAROON)
        b.flat(R((36, 29, 41, 29)), WHITE)
        b.dot(35, 28, OUTLINE)
        b.dot(42, 28, OUTLINE)
    else:  # relaxed little smile
        b.flat(L([(36, 30), (37, 31), (39, 31), (40, 30)], 1), MAROON)
    return b


def character(v, god):
    low = build_legs(v)
    a = build_body(v)
    h = hair_layer(v, a, god)
    b = face_layer(v, h, god)
    f = Image.new("RGBA", (g.CELL, g.CELL), (0, 0, 0, 0))
    f.alpha_composite(low.img, (O, O))
    up = h.img.copy()
    up.alpha_composite(b.img, (O, O))
    f.alpha_composite(up, (0, g.UPPER_DY))
    return g.outline(f)


# --- godspeed effects ---------------------------------------------------------------------------------------------------------------
def silhouette(f):
    w, h = f.size
    px = f.load()
    return [[px[x, y][3] > 0 for x in range(w)] for y in range(h)]


def aura(f, rings):
    """Silhouette-hugging dither glow behind him: rings = [(max distance, pattern, colour)], nearest first."""
    sil = silhouette(f)
    w, h = f.size
    dist = [[0 if sil[y][x] else 99 for x in range(w)] for y in range(h)]
    for d in range(1, 8):
        for y in range(h):
            for x in range(w):
                if dist[y][x] == 99 and any(0 <= x + dx < w and 0 <= y + dy < h and dist[y + dy][x + dx] == d - 1
                                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    dist[y][x] = d
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = out.load()
    for y in range(h):
        for x in range(w):
            d = dist[y][x]
            if d in (0, 99):
                continue
            for mx, pat, c in rings:
                if d <= mx:
                    if pat(x, y):
                        px[x, y] = c + (255,)
                    break
    return out


full = lambda x, y: True
check = lambda x, y: (x + y) % 2 == 0
sparse = lambda x, y: x % 2 == 0 and y % 2 == 0
quarter = lambda x, y: (x + 2 * y) % 4 == 0


def edge_roots(f, rng, n, lo=0):
    sil = silhouette(f)
    w, h = f.size
    cand = [(x, y) for y in range(lo, h - 1) for x in range(1, w - 1) if sil[y][x] and not all(
        sil[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    return rng.sample(cand, min(n, len(cand)))


def sparks(f, v):
    """Lightning arcs jumping off the silhouette (drawn over everything)."""
    c = Canvas(g.CELL)
    kind = v["god"]
    rng = random.Random({"A": 11, "B": 23, "C": 5}[kind])
    if kind == "A":
        arcs_from(c, rng, edge_roots(f, rng, 60), (48, 52), 7, (7, 14), forks=0.5, glow=YELLOW, tip=WHITE, jit=2.2)
    elif kind == "B":
        arcs_from(c, rng, edge_roots(f, rng, 80), (48, 52), 10, (10, 22), forks=0.9, glow=YELLOW, tip=WHITE, jit=3.0)
        arcs_from(c, rng, edge_roots(f, rng, 80), (48, 52), 5, (6, 12), forks=0.3, glow=TEAL_L, tip=WHITE, jit=2.0)
        for x0 in (22, 74):  # two big bolts hitting the floor beside him
            p = zap_zig(rng, (x0 + rng.randint(-3, 3), 10), (x0 + rng.randint(-4, 4), 76), 6, 4)
            zap_arc(c, p, YELLOW, WHITE, tip=WHITE)
    else:
        arcs_from(c, rng, edge_roots(f, rng, 60), (48, 52), 4, (6, 12), forks=0.2, glow=YELLOW, tip=WHITE, jit=1.8)
    return c.img


def godspeed(v, f):
    kind = v["god"]
    if kind == "A":
        rings = [(1, check, YELLOW), (3, sparse, YELLOW)]
    elif kind == "B":
        rings = [(1, full, YELLOW), (2, check, YELLOW), (4, sparse, TEAL_L)]
    else:
        rings = [(2, quarter, YELLOW), (4, sparse, ORANGE)]
    out = Image.new("RGBA", f.size, (0, 0, 0, 0))
    out.alpha_composite(aura(f, rings))
    out.alpha_composite(f)
    out.alpha_composite(sparks(f, v))
    return out


# --- sheet ---------------------------------------------------------------------------------------------------------------------------------
def floor_crop(w, h):
    tiles = Image.open(ROOT / "assets" / "arenas" / "pit_tiles.png").convert("RGBA")
    t = tiles.height
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, t):
        for x in range(0, w, t):
            n = (x // t + y // t) % 2
            out.paste(tiles.crop((n * t, 0, n * t + t, t)), (x, y))
    return out


def nn(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def on_floor(im, k):
    fl = floor_crop(im.width, im.height)
    fl.alpha_composite(im)
    return nn(fl, k)


def labelled(img, text):
    out = Image.new("RGBA", (img.width, img.height + 22), (24, 24, 32, 255))
    out.alpha_composite(img, (0, 22))
    ImageDraw.Draw(out).text((6, 5), text, fill=(240, 240, 230, 255))
    return out


def look_panel(im):
    big = Image.new("RGBA", (g.CELL * 8, g.CELL * 8), (46, 44, 50, 255))
    big.alpha_composite(nn(im, 8))
    side = Image.new("RGBA", (g.CELL * 2, g.CELL * 3 + 8), (24, 24, 32, 255))
    side.alpha_composite(on_floor(im, 1), (g.CELL // 2, 0))
    side.alpha_composite(on_floor(im, 2), (0, g.CELL + 8))
    pan = Image.new("RGBA", (big.width + 8 + side.width, big.height), (24, 24, 32, 255))
    pan.alpha_composite(big)
    pan.alpha_composite(side, (big.width + 8, 0))
    return pan


def variant_sheet(key):
    v = VARIANTS[key]
    n = character(v, False)
    s = godspeed(v, character(v, True))
    pn, ps = look_panel(n), look_panel(s)
    sheet = Image.new("RGBA", (pn.width + ps.width + 24, pn.height + 16), (24, 24, 32, 255))
    sheet.alpha_composite(pn, (8, 8))
    sheet.alpha_composite(ps, (pn.width + 16, 8))
    return labelled(sheet, v["name"])


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sheets = []
    for key in VARIANTS:
        sh = variant_sheet(key)
        sh.convert("RGB").save(OUT_DIR / f"bolt_{key}.png")
        sheets.append(sh)
    out = Image.new("RGBA", (sheets[0].width, sum(s.height for s in sheets)), (24, 24, 32, 255))
    y = 0
    for s in sheets:
        out.alpha_composite(s, (0, y))
        y += s.height
    out.convert("RGB").save(OUT_DIR / "bolt_concepts.png")


if __name__ == "__main__":
    main()
