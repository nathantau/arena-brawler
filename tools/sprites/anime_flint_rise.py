"""Flint power-up strip for the loadout bust (assets/title/anime/flint_rise.png): 8 frames of 96 x 128.

Calm and low-burning -> the flames in his hair surge taller, wider and brighter (hotter colours, white-hot core), embers swirl
up round his head, his eyes glow brighter yellow with a warm halo, ending on a fierce, confident look (narrowed eyes,
V brows, a smirk) with the hair fully flared; the last frame is the held look.

Built on Flint's own code in anime_busts.py (never edited): its tongue / eye / brow / mouth functions are wrapped for the
duration of the run (state in RS) and restored afterwards, so flint_bust.png / sakura_bust.png stay byte-identical.

Run: tools/sprites/.venv/bin/python tools/sprites/anime_flint_rise.py [review_dir]
(review_dir gets flint_rise.gif + flint_rise_sheet.png + flint_rise_x1.png; never commit those.)
"""
import math
import os
import sys
from PIL import Image, ImageChops

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anime_busts as ab
from anime_busts import (INK, MAROON, RED, ORANGE, YELLOW, CREAM, LIGHT_OR, DEEP_RED, BG, W, H, P, smooth, snap, cleanup,
                         pixelize, recolor_interior, YOFF, K)

EYEHOT = (255, 228, 110)              # eyes glowing brighter than his normal yellow
HOT = (255, 238, 150)                 # white-hot yellow, added after snapping (not in Flint's palette)
RISE_T = [0.0, 0.14, 0.29, 0.43, 0.57, 0.71, 0.86, 1.0]
RS = {}                               # per-frame state read by the wrappers
BASE_TONGUES = list(ab.TONGUES)
EXTRA = [((24.0, 15.0), (24.6, 1.2), 7.0, 2.0), ((28.0, 15.6), (32.4, 1.0), 6.6, -2.0)]    # two more, only at the peak


def smoothstep(a, b, t):
    u = max(0.0, min(1.0, (t - a) / (b - a)))
    return u * u * (3 - 2 * u)


def lerp(a, b, t):
    return a + (b - a) * t


def tongues_for(g):
    """Calm: short low flames. Peak: taller (to the frame top), wider, tips fanned outward."""
    out = []
    ln = lerp(0.58, 1.3, g)
    spread = lerp(1.0, 1.16, g)
    wm = lerp(0.82, 1.18, g)
    for (r, t, w, b) in BASE_TONGUES:
        tx = r[0] + (t[0] - r[0]) * ln
        ty = r[1] + (t[1] - r[1]) * ln
        tx = 24 + (tx - 24) * spread
        out.append((r, (min(46.2, max(1.8, tx)), max(1.0, ty)), w * wm, b))
    k = smoothstep(0.45, 1.0, g)
    if k > 0.02:
        for (r, t, w, b) in EXTRA:
            out.append((r, (t[0], r[1] + (t[1] - r[1]) * k), w * (0.6 + 0.4 * k), b))
    return out


def make_wrappers():
    o_tongue, o_eye, o_brow, o_mouth = ab.tongue, ab.eye, ab.brow, ab.mouth

    def tongue(d, root, tip, w0, bend, **kw):
        heat = RS["heat"]
        kw["cols"] = (DEEP_RED, lambda t: ab.flame_col(min(1.0, t / heat)), RED, YELLOW)
        return o_tongue(d, root, tip, w0, bend, **kw)

    def eye(d, cx, cy, side, o, wide=1.0):
        return o_eye(d, cx, cy, side, RS["o"], RS["wd"])

    def brow(d, cx, cy, side, lift=0.0, tilt=1.0):
        return o_brow(d, cx, cy, side, RS["lift"], RS["tilt"])

    def mouth(d, kind):
        YOFF[0] = -2.7
        sm = RS["smirk"]
        d.line([P(*p) for p in smooth([(22.0, 39.0), (24.2, 39.2 - 0.1 * sm), (26.0, 39.1 - 0.5 * sm), (26.9, 38.9 - 1.1 * sm)], 6)],
               fill=MAROON, width=8, joint="curve")
        YOFF[0] = 0.0
    return (o_tongue, o_eye, o_brow, o_mouth), (tongue, eye, brow, mouth)


def hot_pass(out, g):
    """White-hot hair cores, brighter glowing eyes and the warm halo round them (post snap, exact pixels)."""
    px = out.load()
    w, h = out.size
    warm = (YELLOW, LIGHT_OR, HOT)

    def solid(x, y):
        return all(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] and px[x + dx, y + dy][:3] in warm
                   for dx in (-1, 0, 1) for dy in (-1, 0, 1))
    if g > 0.5:
        core = [(x, y) for y in range(0, 46) for x in range(w) if px[x, y][3] and px[x, y][:3] == YELLOW and solid(x, y)]
        for x, y in core:
            px[x, y] = HOT + (255,)
    eyes = [(x0, 47, x0 + 17, 64) for x0 in (29, 50)]

    def in_eye(x, y):
        return any(a <= x <= c and b <= y <= d for a, b, c, d in eyes)
    if g > 0.25:
        if g > 0.5:
            for y in range(47, 65):
                for x in range(w):
                    if in_eye(x, y) and px[x, y][3] and px[x, y][:3] == YELLOW:
                        px[x, y] = EYEHOT + (255,)
        add = []
        for y in range(44, 68):
            for x in range(w):
                if not in_eye(x, y) or px[x, y][3] == 0 or px[x, y][:3] not in (ORANGE, RED, LIGHT_OR):
                    continue
                near = any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][:3] in (YELLOW, EYEHOT) and px[x + dx, y + dy][3]
                           for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                if near:
                    add.append((x, y))
        for x, y in add:
            px[x, y] = LIGHT_OR + (255,)


def embers(out, i, g):
    """Embers swirling up round his head: they orbit it, rising and cooling, each with a short darker tail behind it; only
    drawn where the frame is empty (so they pass behind him)."""
    px = out.load()
    n = int(5 + 15 * g)

    def put(X, Y, col, size):
        for ax in range(size):
            for ay in range(size):
                if 0 <= X + ax < out.width and 0 <= Y + ay < out.height and px[X + ax, Y + ay][3] == 0:
                    px[X + ax, Y + ay] = col + (255,)
    for k in range(n):
        u = (i * 0.145 + k * 0.173) % 1.0                     # 0 = low, 1 = at the top
        ang = 2 * math.pi * (k * 0.37 + u * 1.15)
        rad = 38 + 7 * u + 3 * math.sin(k * 2.1)
        x = 48 + rad * math.sin(ang)
        y = 90 - u * 86
        col, tail, size = (YELLOW, LIGHT_OR, 2) if u < 0.35 else (LIGHT_OR, ORANGE, 2) if u < 0.65 else (ORANGE, RED, 1) if u < 0.85 else (RED, DEEP_RED, 1)
        X, Y = int(x), int(y)
        if u < 0.3:                                           # young embers are small crosses of light
            put(X, Y, col, 2)
            for ax, ay in ((-1, 0), (2, 0), (0, -1), (0, 2)):
                put(X + ax, Y + ay, tail, 1)
        else:
            put(X, Y, col, size)
        put(int(x - 3 * math.cos(ang)), Y + 3, tail, 1)
        put(int(x - 5 * math.cos(ang)), Y + 6, tail if u < 0.6 else DEEP_RED, 1)


def frame(i, t):
    g = smoothstep(0.0, 1.0, t)
    fierce = smoothstep(0.25, 0.9, t)
    RS.clear()
    RS.update(heat=lerp(0.8, 1.55, g), o=lerp(1.6, 0.95, fierce), wd=lerp(1.1, 1.05, fierce), lift=lerp(0.0, 0.1, fierce),
              tilt=lerp(1.0, 1.55, fierce), smirk=smoothstep(0.55, 1.0, t))
    ab.TONGUES[:] = tongues_for(g)
    sway = (-0.8, 0.8)[i % 2] * lerp(0.7, 1.0, g)
    src = ab.draw_frame(sway, "calm")
    diff = ImageChops.difference(src, Image.new("RGB", src.size, BG)).convert("L").point(lambda v: 255 if v > 0 else 0)
    mask = diff.resize((W, H), Image.BOX).point(lambda v: 255 if v > 110 else 0)
    out = snap(pixelize(src, W, 40), mask)
    px = out.load()
    prot = {(x, y) for y in range(44, 66) for x in range(26, 72) if px[x, y] == CREAM + (255,)}
    out = cleanup(out, prot)
    out = recolor_interior(out, None)
    hot_pass(out, g)
    embers(out, i, g)
    return out


def flint_rise(review=None):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    saved, wrapped = make_wrappers()
    try:
        ab.tongue, ab.eye, ab.brow, ab.mouth = wrapped
        frames = [frame(i, t) for i, t in enumerate(RISE_T)]
    finally:
        ab.tongue, ab.eye, ab.brow, ab.mouth = saved
        ab.TONGUES[:] = BASE_TONGUES
    strip = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * W, 0))
    dst = os.path.join(root, "assets", "title", "anime")
    os.makedirs(dst, exist_ok=True)
    strip.save(os.path.join(dst, "flint_rise.png"))
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
    gif[0].save(os.path.join(review, "flint_rise.gif"), save_all=True, append_images=gif[1:], duration=dur, loop=0)
    cw = W * S + 8
    sheet = Image.new("RGB", (cw * 4 + 8, (H * S + 8) * 2 + 8), bg)
    for i, f in enumerate(gif):
        sheet.paste(f, (8 + (i % 4) * cw, 8 + (i // 4) * (H * S + 8)))
    sheet.save(os.path.join(review, "flint_rise_sheet.png"))
    x1 = Image.new("RGBA", (W * len(frames), H), bg + (255,))
    x1.alpha_composite(strip)
    x1.convert("RGB").save(os.path.join(review, "flint_rise_x1.png"))


if __name__ == "__main__":
    flint_rise(sys.argv[1] if len(sys.argv) > 1 else None)
