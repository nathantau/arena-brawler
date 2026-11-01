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


def stripe_v(c, x, y0, y1, stripe):
    """A stripe that follows the form: lit head, base, shaded tail."""
    c.flat(L([(x, y0), (x, y1)], 1), stripe)
    c.dot(x, y0, LIGHTER[stripe])
    c.dot(x, y1, DARKER[stripe])


def build_legs(v):
    low = Canvas()
    suit, stripe, acc = v["suit"], v["stripe"], v["accent"]
    lit, dark = LIGHTER[suit], DARKER[suit]
    for x, dy in legs(low, suit, WHITE, None):
        # only ~3 rows of trousers show under the jacket: keep them simple and readable
        low.flat(R((x, 49 + dy, x + 3, 52 + dy)), suit)
        low.flat(L([(x, 49 + dy), (x, 51 + dy)], 1), lit)  # lit edge
        low.flat(R((x + 4, 49 + dy, x + 5, 52 + dy)), dark)  # shaded side
        stripe_v(low, x + 3, 49 + dy, 52 + dy, stripe)  # side stripe
        low.flat(R((x, 52 + dy, x + 2, 52 + dy)), dark)  # elastic ankle cuff, bunched
        # sneaker: toe cap, heel tab, strap, laces, sole
        low.flat(R((x + 5, 55 + dy, x + 7, 56 + dy)), acc)
        low.flat(R((x - 1, 55 + dy, x - 1, 56 + dy)), acc)
        low.flat(L([(x + 1, 55 + dy), (x + 3, 54 + dy)], 1), acc)
        low.dot(x + 4, 54 + dy, STEEL_D)
        low.flat(R((x - 1, 57 + dy, x + 7, 57 + dy)), STEEL_D)  # sole
    return low


def build_body(v):
    suit, stripe, acc = v["suit"], v["stripe"], v["accent"]
    lit, dark = LIGHTER[suit], DARKER[suit]
    a = Canvas()

    def sleeve(x, sx):  # stripe x offset sx
        stripe_v(a, x + sx, 37, 40, stripe)
        a.flat(R((x + 1, 41, x + 4, 41)), dark)  # ribbed cuff
        a.dot(x + 1, 41, lit)
        a.flat(L([(x + 2, 38), (x + 3, 39)], 1), dark)  # crease at the elbow

    arm(a, g.ARM_X[0], suit, SKIN)
    sleeve(g.ARM_X[0], 1)
    a.part(RR(BODY, 3), suit)  # jacket
    a.flat(L([(21, 38), (21, 42)], 1), lit)  # lit left edge
    a.flat(L([(29, 42), (27, 45)], 1), dark)  # folds running down from the chest
    a.flat(L([(38, 41), (40, 45)], 1), dark)
    a.flat(L([(23, 44), (26, 43)], 1), dark)  # pocket slit
    a.flat(R((20, 46, 44, 47)), dark)  # ribbed hem
    for x in range(22, 43, 2):
        a.dot(x, 47, OUTLINE)
    a.flat(R((21, 46, 30, 46)), suit)  # hem lit on the left
    # collar: gold-trimmed band under the chin, a dark lining behind it
    a.flat(R((26, 37, 40, 37)), stripe)
    a.flat(R((24, 37, 25, 37)), LIGHTER[stripe])
    a.flat(R((41, 37, 43, 37)), DARKER[stripe])
    a.flat(R((28, 38, 38, 38)), dark)
    # zip and pull tab
    a.flat(L([(33, 38), (33, 46)], 1), STEEL)
    a.flat(L([(34, 39), (34, 46)], 1), STEEL_D)
    a.flat(R((32, 40, 34, 42)), WHITE)
    a.flat(R((32, 42, 34, 42)), STEEL)
    # gold bolt patch on the left chest
    a.flat(P([(29, 39), (25, 42), (27, 42), (26, 45), (31, 41), (29, 41)]), stripe)
    a.flat(L([(29, 39), (26, 42)], 1), LIGHTER[stripe])
    a.dot(26, 45, DARKER[stripe])
    a.dot(30, 41, DARKER[stripe])
    arm(a, g.ARM_X[1], suit, SKIN)
    sleeve(g.ARM_X[1], 4)
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


# --- round 2: variant C refined (clean normal hair options, polished godspeed) ----------------------------------------------------------
HEAD2 = (17, 7, 48, 35)  # the one head / hair-mass shape shared by every normal option and by godspeed
HAIR2 = {
    "sweep": dict(label="1  side-swept quiff", bumps=[(28, 3, 46, 13)],
                  fringe=[(21, 15), (49, 15), (49, 17), (44, 17), (36, 19), (28, 18), (23, 21), (21, 24)]),
    "tousled": dict(label="2  tousled, soft rounded tufts", bumps=[(20, 5, 31, 13), (29, 2, 41, 11), (38, 5, 48, 14)],
                    fringe=[(21, 15), (49, 15), (49, 18), (46, 18), (44, 20), (40, 18), (36, 20), (32, 18), (28, 20), (24, 20), (22, 22)]),
    "crop": dict(label="3  neat short crop, side parting", bumps=[],
                 fringe=[(21, 15), (49, 15), (49, 18), (45, 18), (40, 17), (36, 16), (33, 19), (27, 20), (23, 22)]),
}
# godspeed: the same head, a few big faceted spikes standing up (tips lean back for the wind) plus two flames off the back
GOD2_TOP = [(23, 17, -2, 5), (30, 25, -12, 5.5), (37, 36, -15, 5.5), (44, 47, -5, 5)]
GOD2_BACK = [[(22, 15), (4, 7), (25, 26)], [(19, 25), (2, 26), (22, 35)]]
GOD2_FRINGE = [(21, 15), (49, 15), (49, 19), (45, 17), (42, 19), (38, 16), (34, 19), (30, 16), (26, 19), (22, 21)]


def spike2(c, xc, tx, ty, hw, base=16):
    c.part(P(pts([(xc - hw, base), (tx, ty), (xc + hw, base)])), YELLOW, shade=False)
    c.flat(L(pts([(xc - hw + 1, base - 1), (tx - 1, ty + 5)]), 1), LIGHTER[YELLOW])  # lit edge
    c.flat(P(pts([(tx, ty + 2), (xc + hw, base), (xc, base)])), ORANGE)  # shaded right facet


def hair_layer2(opt, a, god):
    h = Canvas(g.CELL)
    h.img.paste(a.img, (O, O))
    h.px = h.img.load()
    col = YELLOW if god else BROWN
    bumps = [] if god else HAIR2[opt]["bumps"]
    ell = lambda bx: (lambda d, f: d.ellipse(tuple(v + O for v in bx), f))
    h.part(lambda d, f: [ell(HEAD2)(d, f)] + [ell(b)(d, f) for b in bumps], col, shade=not god)
    if god:
        sp = Canvas(g.CELL)
        for poly in GOD2_BACK:
            sp.part(P(pts(poly)), YELLOW, shade=False)
            sp.flat(P(pts([poly[1], poly[2], (poly[0][0] + 2, poly[0][1] + 6)])), ORANGE)
        for t in GOD2_TOP:
            spike2(sp, *t)
        h.img.alpha_composite(sp.img)
        h.px = h.img.load()
        h.flat(lambda d, f: d.arc(tuple(v + O for v in HEAD2), 100, 175, f), ORANGE)
    else:
        h.flat(L(pts([(24, 9), (32, 6)]), 1), LIGHTER[col])
        if opt == "crop":
            h.flat(L(pts([(37, 8), (36, 14)]), 1), DARKER[col])  # the parting
    return h


def face_layer2(opt, h, god):
    b = Canvas()
    b.img.paste(h.img.crop((O, O, O + 64, O + 64)))
    b.px = b.img.load()
    col = YELLOW if god else BROWN
    b.part(RR(FACE, FACE_R), SKIN)
    b.flat(L([(FACE[0] + 3, FACE[3] - 2), (FACE[2] - 4, FACE[3] - 1)], 1), SKIN_D)
    b.part(P(GOD2_FRINGE if god else HAIR2[opt]["fringe"]), col, shade=False)
    for x in range(21, 50):  # no seam where the fringe meets the hair mass
        if b.px[x, 14][:3] == OUTLINE and b.px[x, 13][3] and b.px[x, 13][:3] != OUTLINE:
            b.px[x, 14] = b.px[x, 13]
    b.part(P([(46, 16), (49, 17), (49, 23), (47, 24)]), col, shade=False)  # sideburn
    if god:
        for x in g.EYES_X:
            b.flat(R((x - 1, 22, x + 4, 27)), OUTLINE)  # wide open, glowing
            b.flat(R((x, 23, x + 3, 26)), WHITE)
            b.flat(R((x + 1, 24, x + 2, 26)), TEAL_L)  # electric iris
            b.dot(x + 2, 25, WHITE)
            b.dot(x - 2, 25, TEAL_L)  # crackle at the corners
            b.dot(x + 5, 24, TEAL_L)
        b.flat(L([(29, 20), (35, 22)], 1), OUTLINE)  # fierce brows
        b.flat(L([(40, 22), (46, 20)], 1), OUTLINE)
    else:
        big_eyes(b, g.EYES_Y, g.EYES_X, BROWN)
    g.face(b, g.BLUSH, None)
    if god:
        b.flat(R((36, 29, 41, 31)), MAROON)
        b.flat(R((36, 29, 41, 29)), WHITE)
        b.dot(35, 28, OUTLINE)
        b.dot(42, 28, OUTLINE)
    else:
        b.flat(L([(36, 30), (37, 31), (39, 31), (40, 30)], 1), MAROON)
    return b


def character2(opt, god):
    v = VARIANTS["c"]
    low = build_legs(v)
    a = build_body(v)
    h = hair_layer2(opt, a, god)
    b = face_layer2(opt, h, god)
    f = Image.new("RGBA", (g.CELL, g.CELL), (0, 0, 0, 0))
    f.alpha_composite(low.img, (O, O))
    up = h.img.copy()
    up.alpha_composite(b.img, (O, O))
    f.alpha_composite(up, (0, g.UPPER_DY))
    return g.outline(f)


def godspeed2(f):
    c = Canvas(g.CELL)
    rng = random.Random(9)
    arcs_from(c, rng, edge_roots(f, rng, 90), (48, 52), 7, (10, 20), forks=0.6, glow=YELLOW, tip=WHITE, jit=2.8)
    out = Image.new("RGBA", f.size, (0, 0, 0, 0))
    out.alpha_composite(aura(f, [(1, full, YELLOW), (2, check, ORANGE)]))
    out.alpha_composite(f)
    out.alpha_composite(c.img)
    return out


def main2():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for opt in HAIR2:
        pn, ps = look_panel(character2(opt, False)), look_panel(godspeed2(character2(opt, True)))
        sheet = Image.new("RGBA", (pn.width + ps.width + 24, pn.height + 16), (24, 24, 32, 255))
        sheet.alpha_composite(pn, (8, 8))
        sheet.alpha_composite(ps, (pn.width + 16, 8))
        rows.append(labelled(sheet, "C refined, hair " + HAIR2[opt]["label"]))
    out = Image.new("RGBA", (rows[0].width, sum(r.height for r in rows)), (24, 24, 32, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    out.convert("RGB").save(OUT_DIR / "bolt_c2.png")


# --- round 3: centre-parted curtain hair, soft godspeed glow (no sticker rim), rounded electric eyes ---------------------------------
PART_X = 35  # the parting, on the face's centre line
HAIR3 = {
    "short": dict(label="1  middle part, short curtains",
                  left=[(21, 15), (34, 15), (33, 17), (29, 20), (26, 23), (24, 25), (21, 22)],
                  right=[(37, 15), (49, 15), (49, 24), (46, 23), (44, 20), (41, 18), (38, 16)]),
    "long": dict(label="2  middle part, long full curtains",
                 left=[(21, 15), (34, 15), (32, 17), (28, 20), (25, 24), (24, 28), (21, 27)],
                 right=[(37, 15), (49, 15), (50, 27), (47, 26), (46, 22), (43, 19), (39, 16)]),
}
GOD3_TOP = [(22, 17, -2, 6), (28, 24, -10, 6), (33, 32, -15, 6), (38, 39, -15, 6), (43, 47, -10, 6), (47, 52, -2, 5)]
GOD3_BACK = [[(22, 16), (5, 8), (25, 27)]]
GOD3_LEFT = [(21, 15), (35, 15), (34, 16), (31, 19), (29, 18), (27, 21), (24, 19), (22, 21)]
GOD3_RIGHT = [(36, 15), (49, 15), (49, 21), (47, 19), (45, 21), (42, 19), (40, 18), (37, 16)]


def hair_layer3(opt, a, god):
    h = Canvas(g.CELL)
    h.img.paste(a.img, (O, O))
    h.px = h.img.load()
    col = YELLOW if god else BROWN
    h.part(lambda d, f: d.ellipse(tuple(v + O for v in HEAD2), f), col, shade=not god)
    if god:
        sp = Canvas(g.CELL)
        for poly in GOD3_BACK:
            sp.part(P(pts(poly)), YELLOW, shade=False)
            sp.flat(P(pts([poly[1], poly[2], (poly[0][0] + 2, poly[0][1] + 6)])), ORANGE)
        for t in GOD3_TOP:
            spike2(sp, *t)
        h.img.alpha_composite(sp.img)
        h.px = h.img.load()
        h.flat(lambda d, f: d.arc(tuple(v + O for v in HEAD2), 100, 175, f), ORANGE)
    else:
        h.flat(L(pts([(PART_X, 8), (PART_X, 14)]), 1), DARKER[col])  # the parting
        h.flat(L(pts([(PART_X - 1, 9), (PART_X - 1, 13)]), 1), LIGHTER[col])  # lit hair beside it
        h.flat(L(pts([(24, 10), (30, 8)]), 1), LIGHTER[col])
        h.flat(L(pts([(41, 8), (45, 11)]), 1), LIGHTER[col])
    return h


def eyes3(b):
    for x in g.EYES_X:
        b.flat(lambda d, f, x=x: d.ellipse((x - 1, 22, x + 4, 27), f), OUTLINE)
        b.flat(lambda d, f, x=x: d.ellipse((x, 23, x + 3, 26), f), TEAL)
        b.flat(R((x + 1, 24, x + 2, 26)), TEAL_L)
        b.flat(R((x, 23, x + 1, 23)), WHITE)  # bright highlight
        b.dot(x + 1, 24, WHITE)
        b.dot(x - 2, 25, TEAL_L)  # crackle at the corners
        b.dot(x + 5, 24, TEAL_L)


def face_layer3(opt, h, god):
    b = Canvas()
    b.img.paste(h.img.crop((O, O, O + 64, O + 64)))
    b.px = b.img.load()
    col = YELLOW if god else BROWN
    b.part(RR(FACE, FACE_R), SKIN)
    b.flat(L([(FACE[0] + 3, FACE[3] - 2), (FACE[2] - 4, FACE[3] - 1)], 1), SKIN_D)
    left, right = (GOD3_LEFT, GOD3_RIGHT) if god else (HAIR3[opt]["left"], HAIR3[opt]["right"])
    b.part(P(left), col, shade=False)
    b.part(P(right), col, shade=False)
    for x in range(21, 50):  # no seam where the curtains meet the hair mass
        if b.px[x, 14][:3] == OUTLINE and b.px[x, 13][3] and b.px[x, 13][:3] != OUTLINE:
            b.px[x, 14] = b.px[x, 13]
    if not god:  # keep the parting reading down to the forehead
        b.dot(PART_X, 14, DARKER[col])
        b.dot(PART_X, 15, OUTLINE)
    if god:
        eyes3(b)
        b.flat(L([(29, 20), (35, 22)], 1), OUTLINE)
        b.flat(L([(40, 22), (46, 20)], 1), OUTLINE)
    else:
        big_eyes(b, g.EYES_Y, g.EYES_X, BROWN)
    g.face(b, g.BLUSH, None)
    if god:
        b.flat(R((36, 29, 41, 31)), MAROON)
        b.flat(R((36, 29, 41, 29)), WHITE)
        b.dot(35, 28, OUTLINE)
        b.dot(42, 28, OUTLINE)
    else:
        b.flat(L([(36, 30), (37, 31), (39, 31), (40, 30)], 1), MAROON)
    return b


def character3(opt, god):
    v = VARIANTS["c"]
    low = build_legs(v)
    a = build_body(v)
    h = hair_layer3(opt, a, god)
    b = face_layer3(opt, h, god)
    f = Image.new("RGBA", (g.CELL, g.CELL), (0, 0, 0, 0))
    f.alpha_composite(low.img, (O, O))
    up = h.img.copy()
    up.alpha_composite(b.img, (O, O))
    f.alpha_composite(up, (0, g.UPPER_DY))
    return g.outline(f)


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def glow3(f, reach=7):
    """A soft glow behind him: ordered-dither layers (yellow near, orange far) thinning out with distance; no solid rim."""
    sil = silhouette(f)
    w, h = f.size
    dist = [[0 if sil[y][x] else 99 for x in range(w)] for y in range(h)]
    for d in range(1, reach + 1):
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
            if d in (0, 99) or d < 2:
                continue  # leave the first px clear so his outline stays crisp
            p = max(0.0, 1 - (d - 1) / reach) * 0.7
            if BAYER[y % 4][x % 4] / 16 < p:
                px[x, y] = (YELLOW if d <= 3 else ORANGE) + (255,)
    return out


def godspeed3(f):
    c = Canvas(g.CELL)
    rng = random.Random(9)
    arcs_from(c, rng, [r for r in edge_roots(f, rng, 200, lo=24) if r[1] < 64], (48, 52), 7, (10, 20), forks=0.6, glow=YELLOW, tip=WHITE, jit=2.8)
    out = Image.new("RGBA", f.size, (0, 0, 0, 0))
    out.alpha_composite(glow3(f))
    out.alpha_composite(f)
    out.alpha_composite(c.img)
    return out


def main3():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for opt in HAIR3:
        pn, ps = look_panel(character3(opt, False)), look_panel(godspeed3(character3(opt, True)))
        sheet = Image.new("RGBA", (pn.width + ps.width + 24, pn.height + 16), (24, 24, 32, 255))
        sheet.alpha_composite(pn, (8, 8))
        sheet.alpha_composite(ps, (pn.width + 16, 8))
        rows.append(labelled(sheet, "C round 3, hair " + HAIR3[opt]["label"]))
    out = Image.new("RGBA", (rows[0].width, sum(r.height for r in rows)), (24, 24, 32, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    out.convert("RGB").save(OUT_DIR / "bolt_c3.png")


if __name__ == "__main__":
    main3() if "--c3" in sys.argv else main2() if "--c2" in sys.argv else main()
