"""Gloom Hound redesign concept: side run frames and front-facing run frames beside Shadow for scale. Nothing is written
into assets/. Run: tools/sprites/.venv/bin/python tools/sprites/hound_concepts.py [out.png]
Only palette colours; light from the top left like the fighters (Canvas.part rims lit / shaded edges)."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw  # noqa: E402

import generate as g  # noqa: E402
from generate import E, L, P, R, Canvas, outline  # noqa: E402
from palette import OUTLINE, PINK, PINK_L, SHADOW, VIOLET, VIOLET_D, VIOLET_L, WHITE  # noqa: E402

G = 68  # row of the paws (96 px canvas)
BODY = VIOLET
FAR = VIOLET_D


def dot(c: Canvas, x: float, y: float, col) -> None:
    x, y = round(x), round(y)
    if 2 <= x < c.size - 2 and 2 <= y < c.size - 2:
        c.dot(x, y, col)


def side_leg(c: Canvas, hip, ph: float, front: bool, col, paw_col) -> None:
    swing, lift = math.sin(ph), max(0.0, math.cos(ph))
    paw = (round(hip[0] + 9 * swing), round(G - 7 * lift))
    # knee bends forward on the front legs while the foot is back, backwards on the hind legs (a hound's hock)
    mid = ((hip[0] + paw[0]) / 2, (hip[1] + paw[1]) / 2)
    bend = (3 if front else -3) * (0.6 + 0.4 * lift)
    knee = (round(mid[0] + bend), round(mid[1] - 1 - 2 * lift))
    c.part(L([hip, knee, paw], 3), col)
    c.flat(R((paw[0] - 1, paw[1] + 1, paw[0] + 3, paw[1] + 1)), paw_col)  # paw


def hound_side(phase: float, jaw: int = 0, k: int = 0) -> Canvas:
    c = Canvas(96)
    bob = -round(abs(math.sin(phase)) * 1.5)
    gy = G + bob
    # smoke streaming off the back and tail, behind everything
    for i in range(6):
        dot(c, 24 - i * 3 - (k % 2) * 2, gy - 36 + i * 2 + math.sin(phase + i * 1.4) * 2, (VIOLET_D, VIOLET, PINK_L)[i % 3 if i < 5 else 1])
    # tail: a long plume streaming back and up, tapering into a wisp
    tw = round(math.sin(phase) * 2)
    c.part(L([(24, gy - 27), (17, gy - 31), (12, gy - 38 + tw), (11, gy - 46 + tw)], 4), BODY)
    c.part(L([(12, gy - 38 + tw), (11, gy - 46 + tw)], 2), VIOLET_L)
    dot(c, 10, gy - 49 + tw, VIOLET_L)
    dot(c, 9, gy - 51 + tw, PINK_L)
    # far legs (darker), then the body, then the near legs
    side_leg(c, (31, gy - 17), phase + math.pi, False, FAR, OUTLINE)
    side_leg(c, (59, gy - 17), phase + math.pi + 0.7, True, FAR, OUTLINE)
    c.part(P([(24, gy - 26), (33, gy - 33), (47, gy - 34), (59, gy - 33), (65, gy - 27), (64, gy - 17), (58, gy - 14),
              (47, gy - 17), (36, gy - 15), (27, gy - 13), (21, gy - 19)]), BODY)
    c.part(E((20, gy - 28, 38, gy - 11)), BODY)  # round haunch
    c.part(E((54, gy - 33, 68, gy - 14)), BODY)  # deep chest
    # shading: lit back, dithered belly, a lit shoulder and haunch
    for x in range(30, 62, 2):
        dot(c, x, gy - 34 + (x // 2) % 2, VIOLET_L)
    for x in range(30, 60, 2):
        dot(c, x + (x // 2) % 2, gy - 17, VIOLET_D)
        dot(c, x, gy - 18, VIOLET_D if (x // 2) % 2 else BODY)
    c.flat(L([(23, gy - 25), (27, gy - 29)], 1), VIOLET_L)
    c.flat(L([(57, gy - 30), (62, gy - 28)], 1), VIOLET_L)
    # mane: jagged spikes down the neck and spine
    for i, (mx, my) in enumerate(((60, gy - 34), (54, gy - 35), (48, gy - 35), (42, gy - 34))):
        c.part(P([(mx - 2, my + 1), (mx + 2, my + 1), (mx - 1, my - 4 - i % 2)]), VIOLET_D)
    side_leg(c, (29, gy - 16), phase, False, BODY, VIOLET_D)
    side_leg(c, (57, gy - 16), phase + 0.7, True, BODY, VIOLET_D)
    # neck and head, facing right: long snout, pointed ears, open jaw
    c.part(P([(56, gy - 34), (66, gy - 38), (70, gy - 28), (62, gy - 22)]), BODY)
    hy = gy - 32
    for ex0, ex1 in ((64, 62), (70, 71)):  # two pointed ears
        c.part(P([(ex0, hy - 4), (ex1, hy - 16), (ex0 + 6, hy - 4)]), BODY)
    c.flat(L([(65, hy - 6), (64, hy - 11)], 1), VIOLET_L)
    c.part(P([(63, hy - 5), (72, hy - 7), (79, hy - 3), (88, hy + 1), (88, hy + 4), (79, hy + 6), (68, hy + 6)]), BODY)  # skull + snout
    c.flat(L([(72, hy - 6), (79, hy - 3), (87, hy)], 1), VIOLET_L)  # lit bridge
    jd = jaw
    c.part(P([(70, hy + 5), (86, hy + 4 + jd), (87, hy + 6 + jd), (76, hy + 11 + jd), (68, hy + 8)]), BODY)  # lower jaw
    c.flat(L([(72, hy + 5), (86, hy + 5 + jd)], 1), OUTLINE)  # mouth line
    if jaw:
        for tx in (79, 83):
            c.dot(tx, hy + 5, WHITE)
            c.dot(tx + 1, hy + 4 + jd, WHITE)
    c.flat(R((75, hy - 3, 78, hy - 2)), PINK_L)  # glowing eye: a slit with a white core
    c.dot(77, hy - 3, WHITE)
    c.dot(74, hy - 4, VIOLET_L)
    c.dot(87, hy + 1, VIOLET_L)  # nose
    return c


def hound_front(phase: float, k: int = 0) -> Canvas:
    c = Canvas(96)
    bob = -round(abs(math.sin(phase)) * 2)
    gy = G + bob
    cx = 48
    for i in range(5):  # smoke rising off the back
        dot(c, cx - 14 + i * 7 + math.sin(phase + i) * 2, gy - 44 - (i % 2) * 5 - (k % 2) * 2, (VIOLET, VIOLET_D, PINK_L)[i % 3])
    c.part(L([(cx - 12, gy - 22), (cx - 20, gy - 32), (cx - 21, gy - 42)], 3), BODY)  # tail behind, up on the left
    dot(c, cx - 21, gy - 45, VIOLET_L)
    # hind legs, small and wide behind the chest
    sw = math.sin(phase)
    for side, ph in ((-1, phase + math.pi), (1, phase)):
        lift = max(0.0, math.cos(ph))
        c.part(L([(cx + side * 12, gy - 17), (cx + side * 15, gy - 9 - lift * 3), (cx + side * 13, gy - 3 - lift * 4)], 3), FAR)
    # chest and shoulders
    c.part(P([(cx - 15, gy - 32), (cx + 15, gy - 32), (cx + 17, gy - 14), (cx + 6, gy - 10), (cx - 6, gy - 10), (cx - 17, gy - 14)]), BODY)
    c.part(E((cx - 14, gy - 34, cx + 14, gy - 16)), BODY)
    c.flat(L([(cx - 12, gy - 31), (cx - 4, gy - 33)], 1), VIOLET)
    for x in range(cx - 12, cx + 13, 2):  # dithered belly shade
        dot(c, x, gy - 12 + (x // 2) % 2, OUTLINE)
    for i in range(3):  # mane tufts on the shoulders
        c.part(P([(cx - 15 + i * 3, gy - 31), (cx - 11 + i * 3, gy - 31), (cx - 14 + i * 3, gy - 38)]), VIOLET)
        c.part(P([(cx + 15 - i * 3, gy - 31), (cx + 11 - i * 3, gy - 31), (cx + 14 - i * 3, gy - 38)]), VIOLET)
    # front legs reaching alternately toward us
    for side, ph in ((-1, phase), (1, phase + math.pi)):
        s, lift = math.sin(ph), max(0.0, math.cos(ph))
        top = (cx + side * 11, gy - 22)
        paw = (cx + side * (11 + 2 * lift), round(gy - 2 - 4 * lift + 2 * s))
        c.part(L([top, (top[0] + side * 2, (top[1] + paw[1]) // 2), paw], 3), BODY)
        c.flat(R((paw[0] - 2, paw[1] + 1, paw[0] + 2, paw[1] + 1)), VIOLET)
    # head: wide skull, pointed ears, a short snout pointing at us
    hy = gy - 42
    for side in (-1, 1):
        c.part(P([(cx + side * 4, hy - 7), (cx + side * 12, hy - 20), (cx + side * 13, hy - 5)]), BODY)
        c.flat(L([(cx + side * 10, hy - 7), (cx + side * 11, hy - 15)], 1), VIOLET_L)
    c.part(E((cx - 13, hy - 10, cx + 13, hy + 9)), BODY)
    c.flat(L([(cx - 9, hy - 8), (cx + 2, hy - 9)], 1), VIOLET)
    c.part(E((cx - 6, hy - 1, cx + 6, hy + 12)), VIOLET_D)  # snout
    c.flat(R((cx - 2, hy + 1, cx + 1, hy + 2)), VIOLET_L)  # nose
    c.flat(L([(cx, hy + 4), (cx, hy + 7)], 1), OUTLINE)
    for side in (-1, 1):  # glowing slanted eyes
        c.flat(L([(cx + side * 3, hy - 3), (cx + side * 8, hy - 5)], 1), PINK_L)
        c.dot(cx + side * 6, hy - 4, WHITE)
    return c


def finish(c: Canvas) -> Image.Image:
    return outline(c.img)


def main() -> None:
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("hound_concept.png")
    sheet = g.Image.open(Path(__file__).resolve().parents[2] / "assets/sprites/shadow.png").convert("RGBA")
    shadow = sheet.crop((0, 0, 96, 96))
    cells = [("Shadow", shadow, None)]
    for k in range(4):
        cells.append((f"run {k + 1}", finish(hound_side(math.tau * k / 6 * 1.5, jaw=0, k=k)), "side"))
    cells.append(("bite", finish(hound_side(0.9, jaw=5)), "side"))
    for k in range(2):
        cells.append((f"front {k + 1}", finish(hound_front(math.tau * k / 2, k=k)), "front"))
    S = 8
    box = (6, 14, 92, 76)  # crop 86 x 62
    w, h = box[2] - box[0], box[3] - box[1]
    bg = (58, 64, 74)
    img = Image.new("RGB", (len(cells) * w * S // 2, h * S // 2 * 2 + 40), bg)
    # two rows of 4 cells at 8x would be huge, so lay them out in 2 rows
    cols = 4
    rows = (len(cells) + cols - 1) // cols
    img = Image.new("RGB", (cols * w * S, rows * (h * S + 24)), bg)
    d = ImageDraw.Draw(img)
    for i, (label, im, kind) in enumerate(cells):
        x0, y0 = (i % cols) * w * S, (i // cols) * (h * S + 24)
        layer = Image.new("RGBA", (96, 96), bg + (255,))
        shade = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shade)
        feet = 66 if kind is None else G + 1
        rx, ry = (13, 5) if kind != "side" else (22, 5)
        sd.ellipse((48 - rx, feet - ry + 2, 48 + rx, feet + ry + 2), fill=(0, 0, 0, 77))  # the fighters' soft 0.3 ellipse
        layer.alpha_composite(shade)
        layer.alpha_composite(im)
        img.paste(layer.convert("RGB").crop(box).resize((w * S, h * S), Image.NEAREST), (x0, y0))
        d.text((x0 + 6, y0 + h * S + 4), label, fill=(255, 230, 120))
    img.save(out_path)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
