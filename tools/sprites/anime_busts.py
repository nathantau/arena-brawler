"""Flint anime bust (title-screen showcase art), original art.

Pipeline (see .claude/skills/anime-pixel-art): smooth vector illustration drawn in code at 8x
-> pixelize(src, 48, 20) -> snap to Flint's gameplay palette -> stray-pixel cleanup.
Output: assets/title/anime/flint_bust.png, 4 frames of 48 x 64
(calm sway A, calm sway B, shout, determined squint).

Run: tools/sprites/.venv/bin/python tools/sprites/anime_busts.py [review_dir]
(review_dir gets flint_bust_clean.png and flint_bust_review.png; never commit those.)
"""
import math
import os
import sys
from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelize import pixelize

K = 8                     # source px per art px
W, H = 48, 64
INK = (27, 26, 46); MAROON = (122, 46, 56); RED = (217, 71, 75); ORANGE = (240, 138, 62)
YELLOW = (245, 210, 86); CREAM = (242, 240, 230); NAVY = (58, 58, 92); BLUE = (43, 58, 107)
BROWN = (184, 117, 79)
PALETTE = [INK, MAROON, RED, ORANGE, YELLOW, CREAM, NAVY, BLUE, BROWN]
BG = (236, 236, 236)
LINE = 7                  # outline thickness in source px


YOFF = [0.0]


def P(x, y):
    return (x * K, (y + YOFF[0]) * K)


def poly(d, pts, fill):
    d.polygon([P(*p) for p in pts], fill=fill)


def outline(d, pts, w=LINE, closed=True):
    q = [P(*p) for p in pts]
    if closed:
        q.append(q[0])
    d.line(q, fill=INK, width=w, joint="curve")
    for x, y in q:  # round the joints
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=INK)


def shape(d, pts, fill, w=LINE):
    outline(d, pts, w)
    poly(d, pts, fill)


def rect(d, x0, y0, x1, y1, fill):
    d.rectangle((x0 * K, y0 * K, x1 * K, y1 * K), fill=fill)


def smooth(pts, n=8):
    """Catmull-Rom through pts (open)."""
    out = []
    p = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(p) - 2):
        for j in range(n):
            t = j / n
            a, b, c, e = p[i - 1], p[i], p[i + 1], p[i + 2]
            out.append(tuple(0.5 * ((2 * b[k]) + (-a[k] + c[k]) * t + (2 * a[k] - 5 * b[k] + 4 * c[k] - e[k]) * t * t
                                    + (-a[k] + 3 * b[k] - 3 * c[k] + e[k]) * t ** 3) for k in (0, 1)))
    out.append(pts[-1])
    return out


def mask_of(fn):
    m = Image.new("L", (W * K, H * K), 0)
    fn(ImageDraw.Draw(m))
    return m


def shift(m, dx, dy):
    return ImageChops.offset(m, dx, dy)


def both(a, b):
    return ImageChops.multiply(a, b)


def inv(a):
    return ImageChops.invert(a)


# ---------------------------------------------------------------- flame tongue
def tongue(d, root, tip, w0, bend, sway=0.0, shade_side=1, tipcol=RED, rootcol=ORANGE, hot_root=0.0, n=28):
    """Flame tongue: S-curved centre line tapering to a sharp tip. Outline first, then flat
    colours: body, one hard shadow half, a thin lit streak, tip colour."""
    x0, y0 = root
    x1, y1 = tip[0] + sway, tip[1] + abs(sway) * 0.15
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    bend *= 1.35
    nx, ny = -dy / L, dx / L
    c1 = (x0 + dx * 0.33 + nx * bend, y0 + dy * 0.33 + ny * bend)
    c2 = (x0 + dx * 0.68 - nx * bend * 0.95 + sway * 0.5, y0 + dy * 0.68 - ny * bend * 0.95)
    cs, hs = [], []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        cs.append((u ** 3 * x0 + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t ** 3 * x1,
                   u ** 3 * y0 + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t ** 3 * y1))
        hs.append(w0 / 2 * (u ** 1.1) * (1 + 0.4 * math.sin(math.pi * t * 0.85)))
    nrm = []
    for i in range(n + 1):
        a, b = cs[max(i - 1, 0)], cs[min(i + 1, n)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        m = math.hypot(tx, ty) or 1
        nrm.append((-ty / m, tx / m))

    def edge(inset, side, frac=1.0):
        return [(cs[i][0] + nrm[i][0] * max(hs[i] - inset, 0) * side * frac,
                 cs[i][1] + nrm[i][1] * max(hs[i] - inset, 0) * side * frac) for i in range(n + 1)]
    outline(d, edge(0, -1) + edge(0, 1)[::-1])
    ins = 0.5
    a0, a1 = edge(ins, -1), edge(ins, 1)
    for i in range(n):
        t = (i + 0.5) / n
        col = YELLOW if t < hot_root else (rootcol if t < 0.68 else tipcol)
        poly(d, [a0[i], a0[i + 1], a1[i + 1], a1[i]], col)
    sh, sh0 = edge(ins, shade_side), edge(ins, shade_side, 0.5)
    for i in range(int(0.10 * n), int(0.70 * n)):
        poly(d, [sh0[i], sh0[i + 1], sh[i + 1], sh[i]], RED)
    e = edge(ins, -shade_side, 0.5)
    e2 = edge(ins, -shade_side, 0.12)
    for i in range(int(0.12 * n), int(0.5 * n)):
        poly(d, [e[i], e[i + 1], e2[i + 1], e2[i]], YELLOW)
    return cs


# ---------------------------------------------------------------- the bust
FACE = [(14.2, 19), (33.8, 19), (34.2, 29.5), (32.2, 36), (27.6, 41.6), (24, 44), (20.4, 41.6),
        (15.8, 36), (13.8, 29.5)]
NECK = [(19.6, 37), (28.4, 37), (29.2, 47), (18.8, 47)]
TORSO = [(0, 64), (0, 53), (5, 47.5), (14, 44.2), (20.2, 42.6), (24, 47.8), (27.8, 42.6), (34, 44.2), (43, 47.5),
         (48, 53), (48, 64)]

BACK = [  # root, tip, width, bend  (far layer, swept up and to the left)
    ((11.5, 24), (1.5, 15), 7, -3.5),
    ((13.5, 19), (0.8, 5), 9, 4.0),
    ((18, 15), (5, 0.8), 10, -4.0),
    ((25, 13.5), (14.5, 0.8), 11, 4.0),
    ((31, 14.5), (26, 0.8), 10, -3.5),
    ((35, 18), (40.5, 3.5), 9, 3.4),
    ((36, 23), (46, 15), 7, -2.6),
]
FRONT = [
    ((17, 20), (7, 10), 7, 3.0),
    ((23, 17), (12, 5.5), 8, -3.0),
    ((30, 16), (21, 4), 8, 3.0),
]
SIDES = [  # temple locks hanging beside the face
    ((13, 23), (7.5, 34), 5.0, 1.4, 1),
    ((35, 23), (40.5, 33), 5.0, -1.4, -1),
]
BANGS = [  # wisps over the forehead
    ((17.4, 20.0), (16.2, 23.4), 4.6, 1.0),
    ((30.2, 20.0), (31.8, 23.2), 4.4, 0.9),
]
HAIRLINE = [(13.4, 26.5), (14.2, 23), (17, 20.8), (20.5, 21.4), (24, 21.0), (27.5, 21.4), (31, 20.8),
            (33.8, 23), (34.6, 26.5)]
CAP_TOP = [(12.8, 24), (13.4, 18), (17, 15), (24, 13.2), (31, 15), (34.6, 18), (35.2, 24)]


def eye(d, cx, cy, side, o, wide=1.0):
    """side -1 = left eye (outer corner on the left). o = openness."""
    ow = 4.5 * wide
    outer = (cx + side * ow, cy - 0.9 - 0.3 * (o - 1))
    inner = (cx - side * ow, cy + 0.5)
    up = smooth([outer, (cx + side * 1.6, cy - 1.45 * o - 0.2), (cx - side * 1.2, cy - 1.25 * o), inner])
    lo = smooth([inner, (cx - side * 0.2, cy + 0.85 * o + 0.3), (cx + side * 1.8, cy + 0.55 * o), outer])
    d.polygon([P(*p) for p in up + lo], fill=YELLOW)
    d.line([P(x, y + 0.75) for x, y in up], fill=ORANGE, width=9)
    d.line([P(*p) for p in lo], fill=MAROON, width=5)
    hx, hy = cx + side * 0.9, cy - 0.35 * o + 0.1
    d.rectangle((hx * K - 5, hy * K - 5, hx * K + 5, hy * K + 5), fill=CREAM)
    flick = (outer[0] + side * 1.2, outer[1] - 0.7)
    d.line([P(*p) for p in [flick] + up], fill=INK, width=7, joint="curve")
    for p in [flick, up[-1]]:
        d.ellipse((p[0] * K - 4, p[1] * K - 4, p[0] * K + 4, p[1] * K + 4), fill=INK)


def brow(d, cx, cy, side, lift=0.0, tilt=1.0):
    outer = (cx + side * 4.6, cy - 4.9 - lift - 0.6 * (tilt - 1))
    inner = (cx - side * 2.6, cy - 3.5 - lift + 0.5 * (tilt - 1))
    d.line([P(*outer), P(*inner)], fill=INK, width=7)


def mouth(d, kind):
    if kind == "shout":
        pts = [(21.3, 37.9), (27.7, 37.7), (27.0, 40.5), (24.4, 41.5), (21.9, 40.5)]
        poly(d, pts, INK)
        rect(d, 21.9, 38.1, 27.1, 39.4, CREAM)
        poly(d, [(22.6, 40.3), (24.4, 39.6), (26.2, 40.3), (24.4, 41.1)], RED)
        outline(d, pts, 5)
    elif kind == "squint":
        d.line([P(22.0, 39.0), P(26.8, 38.8)], fill=INK, width=7)
    else:
        d.line([P(21.8, 39.0), P(27.0, 39.2)], fill=INK, width=4)


def draw_frame(sway=0.0, expr="calm"):
    img = Image.new("RGB", (W * K, H * K), BG)
    d = ImageDraw.Draw(img)
    s = sway
    for i, (r, t, w, b) in enumerate(BACK):
        tongue(d, r, t, w, b, sway=s * (1.7 + 0.35 * (i % 3)))
    for r, t, w, b, side in SIDES:
        tongue(d, r, t, w, b, sway=s * 0.5, shade_side=side)
    YOFF[0] = 2.0
    shape(d, NECK, ORANGE)
    shape(d, TORSO, NAVY)
    poly(d, [(28, 42.8), (34, 44.4), (43, 47.7), (47.6, 53), (47.6, 64), (40, 64), (36.5, 52)], BLUE)
    shape(d, [(9.5, 47.2), (14.5, 44.6), (42, 64), (31, 64)], BROWN)
    poly(d, [(31, 64), (42, 64), (40.5, 62.8), (32, 62.5)], MAROON)
    rect(d, 25.3, 55.2, 28.8, 58.4, INK)
    rect(d, 25.9, 55.8, 28.2, 57.8, YELLOW)
    shape(d, [(13, 44.6), (20, 41.2), (24, 47.8), (19.4, 46)], NAVY)
    shape(d, [(35, 44.6), (28, 41.2), (24, 47.8), (28.6, 46)], BLUE)
    YOFF[0] = 2.0
    facem = mask_of(lambda m: m.polygon([P(*p) for p in FACE], fill=255))
    neckm = mask_of(lambda m: m.polygon([P(*p) for p in NECK], fill=255))
    torm = mask_of(lambda m: m.polygon([P(*p) for p in TORSO], fill=255))
    YOFF[0] = 0.0
    facem = mask_of(lambda m: m.polygon([P(*p) for p in FACE], fill=255))
    jaw = both(both(shift(facem, 4, 20), neckm), inv(facem))
    img.paste(RED, (0, 0), both(jaw, inv(torm)))
    # face
    d = ImageDraw.Draw(img)
    shape(d, FACE, ORANGE)
    img.paste(RED, (0, 0), both(facem, inv(shift(facem, -20, 0))))
    chin = both(facem, inv(shift(facem, 0, -14)))
    img.paste(RED, (0, 0), both(chin, shift(facem, -30, 0)))
    d = ImageDraw.Draw(img)
    d.line([P(25.4, 33.4), P(25.8, 34.8)], fill=RED, width=7)
    mouth(d, expr)
    if expr == "shout":
        o, wd, lift, tilt = 2.2, 1.1, 0.6, 1.0
    elif expr == "squint":
        o, wd, lift, tilt = 1.15, 1.0, -0.1, 1.5
    else:
        o, wd, lift, tilt = 1.7, 1.0, 0.0, 1.0
    cy = 30.6
    eye(d, 19.6, cy, -1, o, wd)
    eye(d, 28.4, cy, 1, o, wd)
    brow(d, 19.6, cy + 0.2, -1, lift, tilt)
    brow(d, 28.4, cy + 0.2, 1, lift, tilt)
    # front tongues + cap
    for i, (r, t, w, b) in enumerate(FRONT):
        tongue(d, r, t, w, b, sway=s * (2.0 + 0.4 * i))
    cap_pts = CAP_TOP + HAIRLINE[::-1]
    poly(d, cap_pts, ORANGE)
    cap = mask_of(lambda m: m.polygon([P(*p) for p in cap_pts], fill=255))
    band = both(cap, inv(shift(cap, 0, -22)))
    band = both(band, mask_of(lambda m: m.rectangle((0, 21 * K, W * K, 30 * K), fill=255)))
    img.paste(YELLOW, (0, 0), band)
    d = ImageDraw.Draw(img)
    d.line([P(*p) for p in HAIRLINE], fill=INK, width=5, joint="curve")
    shd = both(both(shift(cap, 0, 15), facem), inv(cap))
    img.paste(RED, (0, 0), shd)
    d = ImageDraw.Draw(img)
    for i, (r, t, w, b) in enumerate(BANGS):
        tongue(d, r, t, w, b, sway=s * 0.6, shade_side=1 if i % 2 == 0 else -1, hot_root=0.3)
    return img


def snap(art, mask):
    px, mk = art.load(), mask.load()
    out = Image.new("RGBA", art.size, (0, 0, 0, 0))
    o = out.load()
    for y in range(art.height):
        for x in range(art.width):
            if mk[x, y] < 128:
                continue
            c = px[x, y]
            o[x, y] = min(PALETTE, key=lambda p: sum((a - b) ** 2 for a, b in zip(c, p))) + (255,)
    return out


def cleanup(im, protect=()):
    """Drop alpha specks, repaint pixels matching none of their 4 neighbours."""
    o = im.load()
    w, h = im.size
    for _ in range(2):
        ch = []
        for y in range(h):
            for x in range(w):
                if o[x, y][3] == 0:
                    continue
                op = [o[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                      if 0 <= x + dx < w and 0 <= y + dy < h and o[x + dx, y + dy][3] > 0]
                if len(op) <= 1:
                    ch.append((x, y, (0, 0, 0, 0)))
                    continue
                if o[x, y] in op or (x, y) in protect:
                    continue
                cnt = {}
                for n in op:
                    cnt[n] = cnt.get(n, 0) + 1
                ch.append((x, y, max(cnt, key=cnt.get)))
        for x, y, c in ch:
            o[x, y] = c
    return im


def make_frame(sway, expr):
    src = draw_frame(sway, expr)
    diff = ImageChops.difference(src, Image.new("RGB", src.size, BG)).convert("L").point(lambda v: 255 if v > 0 else 0)
    mask = diff.resize((W, H), Image.BOX).point(lambda v: 255 if v > 110 else 0)
    out = snap(pixelize(src, W, 20), mask)
    px = out.load()
    prot = {(x, y) for y in range(24, 31) for x in range(14, 35) if px[x, y] == CREAM + (255,)}
    return cleanup(out, prot)


FRAMES = [(-1, "calm"), (1, "calm"), (0.3, "shout"), (-0.4, "squint")]


def main():
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    frames = [make_frame(s, e) for s, e in FRAMES]
    strip = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    dst = os.path.join(root, "assets", "title", "anime")
    os.makedirs(dst, exist_ok=True)
    strip.save(os.path.join(dst, "flint_bust.png"))
    review = sys.argv[1] if len(sys.argv) > 1 else None
    if not review:
        return
    os.makedirs(review, exist_ok=True)
    S = 8
    bg = (92, 112, 134, 255)
    big = [f.resize((W * S, H * S), Image.NEAREST) for f in frames]
    cw = W * S + 8
    clean = Image.new("RGBA", (cw * 4 + 8, H * S + 16), bg)
    for i, f in enumerate(big):
        clean.paste(f, (8 + i * cw, 8), f)
    clean.convert("RGB").save(os.path.join(review, "flint_bust_clean.png"))
    sheet = Image.new("RGBA", (cw * 5 + 8, 72 * S + 16), bg)
    sheet.paste(clean, (0, 0))
    mock_path = os.path.join(review, "..", "poc", "flint_mock2.png")
    if os.path.exists(mock_path):
        mock = Image.open(mock_path).convert("RGBA").crop((392, 0, 776, 576))
        lay = Image.new("RGBA", mock.size, bg)
        lay.alpha_composite(big[0])
        sheet.paste(Image.blend(mock, lay, 0.5), (8 + 4 * cw, 8))
    sheet.convert("RGB").save(os.path.join(review, "flint_bust_review.png"))


if __name__ == "__main__":
    main()
