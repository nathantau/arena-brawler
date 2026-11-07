"""Sakura power-up strip for the loadout bust (assets/title/anime/sakura_rise.png): 8 frames of 96 x 128.

Calm -> cherry petals swirl in from the edges and orbit closer round her, the blossom clip glows (halo + sparkle growing
frame by frame), her hair lifts and sways outward a little, the calm smile turns determined; the last frame is the held
look (confident smile, petals all round her).

Built on Sakura's own code in anime_busts.py (never edited): make_sakura_frame draws her; its hair() and bob outline are
wrapped for the duration of the run (state in RS) and restored afterwards, so flint_bust.png / sakura_bust.png stay
byte-identical. Petals / glow are exact pixels added after the pixel art.

Run: tools/sprites/.venv/bin/python tools/sprites/anime_sakura_rise.py [review_dir]
(review_dir gets sakura_rise.gif + sakura_rise_sheet.png + sakura_rise_x1.png; never commit those.)
"""
import math
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anime_busts as ab
from anime_busts import (W, H, WHITE, CREAM, YELLOW, H_HI, H_L, HR, H_D, SK, SK_L, SK_S, SK_D, BLUSH, HAIRS, KIMS, IRISES,
                         PETAL_PX)

RISE_T = [0.0, 0.14, 0.29, 0.43, 0.57, 0.71, 0.86, 1.0]
RS = {}
BASE_BOB = list(ab.BACKS["bob"])
CLIP_PX = (29, 31)                     # the blossom clip on the finished 96 x 128 art
FACE_BOX = (25, 36, 71, 88)            # petals never pass in front of the face
FACE_COLS = {SK, SK_L, SK_S, SK_D, BLUSH, WHITE} | set(IRISES["amber"])


def smoothstep(a, b, t):
    u = max(0.0, min(1.0, (t - a) / (b - a)))
    return u * u * (3 - 2 * u)


def lerp(a, b, t):
    return a + (b - a) * t


def lifted_bob(lift):
    """The bob's outline swung out and up a little (hair lifting)."""
    out = []
    for x, y in BASE_BOB:
        k = max(0.0, (y - 20) / 30)
        out.append((x - lift * 1.6 * k, y - lift * 3.0 * k))
    return out


def make_wrappers():
    o_hair = ab.hair

    def hair(d, root, tip, w0, bend, **kw):
        if kw.get("bands") is ab.LOCK_BANDS:                  # the long front locks lift and flare
            side = 1 if tip[0] > 24 else -1
            lift = RS["lift"]
            tip = (tip[0] + side * lift * 1.8, tip[1] - lift * 3.2)
        return o_hair(d, root, tip, w0, bend, **kw)
    return o_hair, hair


def glow(out, g, i):
    """Blossom clip glow: a dithered halo and a sparkle that grow with g (exact pixels)."""
    px = out.load()
    cx, cy = CLIP_PX
    R = lerp(2.0, 6.5, g) + (0.6 if i % 2 else 0.0)
    for y in range(cy - 9, cy + 10):
        for x in range(cx - 9, cx + 10):
            if not (0 <= x < out.width and 0 <= y < out.height):
                continue
            d = math.hypot(x - cx, y - cy)
            if d > R:
                continue
            if d < R * 0.4:
                col = WHITE
            elif (x + y) % 2 == 0 or d < R * 0.65:
                col = H_HI if d < R * 0.75 else H_L
            else:
                continue
            px[x, y] = col + (255,)
    size = 1 + int(round(3 * g))
    px[cx, cy] = WHITE + (255,)
    for r in range(1, size + 1):
        for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r)):
            X, Y = cx + dx, cy + dy
            if 0 <= X < out.width and 0 <= Y < out.height:
                px[X, Y] = (CREAM if r < size else YELLOW) + (255,)
    if size >= 3:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            px[cx + dx, cy + dy] = CREAM + (255,)


BIG_PETAL = [((1, 0), H_HI), ((2, 0), H_HI), ((0, 1), H_HI), ((1, 1), WHITE), ((2, 1), H_L), ((3, 1), HR), ((1, 2), H_L),
             ((2, 2), HR), ((3, 2), H_D)]
SMALL_PETAL = [((1, 0), H_HI), ((0, 1), H_HI), ((1, 1), H_L), ((2, 1), HR), ((1, 2), H_D)]


def petals(out, g, i):
    """Petals spiralling in: they orbit an ellipse about her that tightens with g; the ones on the far half only show against
    the empty frame (behind her), the near half may pass over hair and kimono but never the face."""
    px = out.load()
    n = int(8 + 14 * g)
    safe = set(HAIRS) | set(KIMS) | {(217, 71, 75), (236, 110, 104), (168, 54, 66)}
    for k in range(n):
        th = 2 * math.pi * (k * 0.19 + i * 0.075 + 0.35 * (1 - g) * math.sin(k))
        rx = lerp(46, 36, g) * (0.92 + 0.08 * math.sin(k * 1.7))
        y0 = 14 + 100 * ((k * 0.382 + 0.13) % 1.0)
        x = 48 + rx * math.cos(th)
        y = y0 + 8 * math.sin(th) - 8 * g * (k % 3 == 0)
        near = k % 4 != 3 or math.sin(th) > 0      # most petals pass in front of her hair and kimono
        flip = (k + i) % 2
        pat = BIG_PETAL if near else SMALL_PETAL
        wd = 3 if near else 2
        for (ax, ay), col in pat:
            X, Y = int(x) + (ax if not flip else wd - ax), int(y) + ay
            if not (0 <= X < out.width and 0 <= Y < out.height):
                continue
            under = px[X, Y]
            inface = FACE_BOX[0] <= X <= FACE_BOX[2] and FACE_BOX[1] <= Y <= FACE_BOX[3]
            if under[3] == 0 or (near and not inface and under[:3] in safe):
                px[X, Y] = col + (255,)


def frame(i, t):
    g = smoothstep(0.0, 1.0, t)
    expr = "calm" if t < 0.5 else "determined"
    RS.clear()
    RS.update(lift=lerp(0.0, 1.5, smoothstep(0.1, 0.9, t)), fierce=t >= 0.5)
    ab.BACKS["bob"] = lifted_bob(RS["lift"])
    sway = (-1, 1)[i % 2] * lerp(0.4, 1.0, g)
    out = ab.make_sakura_frame(sway, expr)
    petals(out, g, i)
    glow(out, g, i)
    return out


def sakura_rise(review=None):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    o_hair, hair = make_wrappers()
    o_petals, o_brows = ab.add_petals, ab.add_brows

    def brows(out):                                        # the determined look pulls the brows in harder
        if RS["fierce"]:
            ab.BROW_ARGS = (-0.3, 2.1)
        o_brows(out)
    try:
        ab.add_brows = brows
        ab.hair = hair
        ab.add_petals = lambda out, sway: None
        frames = [frame(i, t) for i, t in enumerate(RISE_T)]
    finally:
        ab.hair = o_hair
        ab.add_petals, ab.add_brows = o_petals, o_brows
        ab.BACKS["bob"] = BASE_BOB
    strip = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    dst = os.path.join(root, "assets", "title", "anime")
    os.makedirs(dst, exist_ok=True)
    strip.save(os.path.join(dst, "sakura_rise.png"))
    if not review:
        return
    os.makedirs(review, exist_ok=True)
    bg = (92, 112, 134)
    S = 4
    gif = []
    for f in frames:
        im = Image.new("RGBA", (W * S, H * S), bg + (255,))
        im.alpha_composite(f.resize((W * S, H * S), Image.NEAREST))
        gif.append(im.convert("RGB"))
    dur = [500] + [120] * (len(gif) - 2) + [900]
    gif[0].save(os.path.join(review, "sakura_rise.gif"), save_all=True, append_images=gif[1:], duration=dur, loop=0)
    cw = W * S + 8
    sheet = Image.new("RGB", (cw * 4 + 8, (H * S + 8) * 2 + 8), bg)
    for i, f in enumerate(gif):
        sheet.paste(f, (8 + (i % 4) * cw, 8 + (i // 4) * (H * S + 8)))
    sheet.save(os.path.join(review, "sakura_rise_sheet.png"))
    x1 = Image.new("RGBA", (W * len(frames), H), bg + (255,))
    x1.alpha_composite(strip)
    x1.convert("RGB").save(os.path.join(review, "sakura_rise_x1.png"))


if __name__ == "__main__":
    sakura_rise(sys.argv[1] if len(sys.argv) > 1 else None)
