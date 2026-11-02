"""Gloom Hound concept, round 4: a CHIBI shadow hound built like the fighters (generate.py helpers: Canvas.part shading with
top-left light, one outline pass, dithered shade). Front-facing 3/4, ~24 px tall, a big round head (half the height) with big
pointed ears, a snub muzzle and big angry glowing eyes, a compact chest with a smoke ruff, stubby legs, a fluffy tail curling up.
Shows an idle front frame and a run frame next to Shadow at 8x with 1x / 2x insets. Nothing is written into assets/.
Run: tools/sprites/.venv/bin/python tools/sprites/hound_concepts4.py [out.png]"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw  # noqa: E402

import generate as g  # noqa: E402
from generate import E, L, P, R, RR, Canvas, outline  # noqa: E402
from palette import OUTLINE, PINK_L, SHADOW, VIOLET, VIOLET_D, VIOLET_L, WHITE  # noqa: E402

BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
FEET = 57  # row of the paws (like the fighters' SH_FEET)


def wisp(c: Canvas, x: float, y: float, dx: float, dy: float, n: int, seed: int) -> None:
    """A clean smoke wisp: a few dithered dots drifting off along (dx, dy), lighter near the source, thinning out."""
    rng = random.Random(seed)
    for i in range(n):
        u = i / n
        X, Y = round(x + dx * i + rng.uniform(-0.4, 0.4)), round(y + dy * i)
        if 1 <= X < c.size - 1 and 1 <= Y < c.size - 1 and (X + Y) % 2 == 0 and u < 0.9:
            c.dot(X, Y, VIOLET_L if u < 0.3 else VIOLET if u < 0.65 else VIOLET_D)


def hound(t: int = 0, step: int | None = None) -> Canvas:
    """One frame, 64 px canvas. `t` 0..3 is the sway tick (tail, ruff, ears); `step` None = standing, 0..3 = a run frame
    (bounce, squash, legs alternating)."""
    c = Canvas(64)
    sway = (0, 1, 1, 0)[t % 4]
    run = step is not None
    bob = (0, -2, 0, -1)[step % 4] if run else (0, 0, 1, 0)[t % 4]  # idle: a slow breath; run: a bounce
    squash = (1, 0, 1, 0)[step % 4] if run else 0  # a frame of squash on the landing steps
    # big fluffy tail curling up behind (left), tip dissolving into smoke
    tw = (0, 1, 2, 1)[t % 4]
    for (cx, cy, r, col) in ((16, 52, 4.5, VIOLET_D), (12, 48, 4.2, VIOLET_D), (10 - tw * 0.5, 43, 3.8, VIOLET_D),
                             (10 - tw, 38, 3.3, VIOLET), (12 - tw, 34, 2.6, VIOLET)):  # one fluffy curl rising behind, tapering
        c.part(E((cx - r, cy - r + bob, cx + r, cy + r + bob)), col)
    # body: a compact chunky chest angled so we see one side, lit from the top left
    legs_y = FEET - 4
    lf = ((24, legs_y), (35, legs_y))  # front legs forward
    lb = ((20, legs_y - 1), (40, legs_y - 1))  # hind legs behind, wider apart
    if run:
        a = step % 4
        lift = ((3, 0), (0, 3), (3, 0), (0, 3))[a]  # px each front leg is lifted (alternating)
        lf = ((24 - (a in (1, 3)), legs_y - lift[0]), (35 + (a in (0, 2)), legs_y - lift[1]))
        lb = ((20 + (a in (0, 2)), legs_y - 1 - lift[1]), (40 - (a in (1, 3)), legs_y - 1 - lift[0]))
    for (x, y) in lb:  # hind legs first (behind the body): stubby, dark
        c.part(RR((x, y + bob, x + 5, y + 4 + bob), 2), VIOLET_D)
        c.flat(R((x + 1, y + 4 + bob, x + 4, y + 4 + bob)), VIOLET)  # paw
    c.part(RR((21, 42 + bob + squash, 45, 56 + bob), 6), VIOLET_D)  # the body
    c.flat(L([(26, 45 + bob), (36, 44 + bob)], 1), VIOLET)  # a lit back
    for x in range(24, 43, 2):  # dithered belly shade
        c.dot(x + (x // 2) % 2, 54 + bob, OUTLINE)
    for (x, y) in lf:  # front legs forward, over the body
        c.part(RR((x, y + bob, x + 5, y + 5 + bob), 2), VIOLET_D)
        c.flat(R((x + 1, y + 5 + bob, x + 4, y + 5 + bob)), VIOLET)  # paw
    # smoke ruff: a fluffy collar round the neck, tufts that sway
    c.part(E((18, 43 + bob, 46, 52 + bob)), VIOLET)
    for i, x in enumerate(range(19, 46, 4)):
        c.part(P([(x, 49 + bob), (x + 4, 49 + bob), (x + 2 + (sway if i % 2 else -sway), 54 + bob + (i % 2))]), VIOLET_D, line=False)
    # head: a big round skull, half the height
    hx, hy = 32, 41 + bob
    for side in (-1, 1):  # two big pointed ears with lighter inner ears
        ex = hx + side * 9
        c.part(P([(ex - 4, hy - 3), (ex + side * 3 + (sway * side * 0), hy - 14), (ex + 4, hy - 1)]), VIOLET_D)
        c.flat(P([(ex - 2, hy - 3), (ex + side * 2, hy - 10), (ex + 2, hy - 2)]), VIOLET)  # inner ear
    c.part(E((hx - 12, hy - 9, hx + 12, hy + 9)), VIOLET_D)  # the skull
    c.flat(L([(hx - 9, hy - 7), (hx + 2, hy - 8)], 1), VIOLET)  # light catching the top-left of the head
    c.flat(L([(hx - 11, hy - 4), (hx - 10, hy - 6)], 1), VIOLET_L)
    c.part(E((hx - 5, hy + 1, hx + 6, hy + 8)), VIOLET)  # snub muzzle, lighter
    c.flat(R((hx - 1, hy + 2, hx + 1, hy + 3)), OUTLINE)  # small dark nose
    c.dot(hx - 1, hy + 2, SHADOW)
    c.flat(L([(hx - 3, hy + 6), (hx + 3, hy + 6)], 1), OUTLINE)  # mouth line
    c.dot(hx - 2, hy + 7, WHITE)  # a tiny fang
    for side in (-1, 1):  # big angry glowing eyes: violet glow, white core, a slanted brow cutting the inner top corner
        ex = hx + side * 6
        c.flat(R((ex - 2, hy - 4, ex + 2, hy + 1)), VIOLET_L)  # glow
        c.flat(R((ex - 1, hy - 3, ex + 1, hy)), WHITE)  # core
        c.flat(P([(ex - side * 3, hy - 5), (ex + side * 3, hy - 5), (ex - side * 3, hy - 1)]), VIOLET_D)  # brow slants down to the middle
        c.flat(L([(ex - side * 3, hy - 2), (ex + side * 2, hy - 5)], 1), OUTLINE)
    # smoke: off the ruff, the tail tip and the paws
    wisp(c, 18, 44 + bob, -0.8, -0.6, 7, 1)
    wisp(c, 45, 45 + bob, 0.8, -0.7, 7, 2)
    wisp(c, 12 - tw, 31 + bob, -0.3, -1.0, 8, 3)
    for k, (x, y) in enumerate(lf + lb):
        wisp(c, x + 2, FEET + 1 + (0 if y >= legs_y - 1 else -2), -0.3 if k % 2 else 0.3, 0.0, 3, 10 + k)
    return c


def main() -> None:
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("hound_concepts4.png")
    shadow = Image.open(Path(__file__).resolve().parents[2] / "assets/sprites/shadow.png").convert("RGBA").crop((0, 0, 96, 96))
    cells = [("Shadow", shadow)]
    for label, c in (("hound idle", hound(0)), ("hound idle (tick 2)", hound(2)), ("hound run 1", hound(1, 0)), ("hound run 2", hound(2, 1))):
        cells.append((label, g.cell(outline(c.img))))
    S8 = 8
    box = (8, 14, 88, 80)
    w, h = box[2] - box[0], box[3] - box[1]
    bg = (58, 64, 74)
    img = Image.new("RGB", (len(cells) * w * S8, h * S8 + 190), bg)
    d = ImageDraw.Draw(img)
    for i, (label, im) in enumerate(cells):
        layer = Image.new("RGBA", (96, 96), bg + (255,))
        sh = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        rx = 13 if label != "Shadow" else 14
        sd.ellipse((48 - rx, 73 - 3, 48 + rx, 73 + 5), fill=(0, 0, 0, 77))  # the fighters' soft 0.3 ellipse
        layer.alpha_composite(sh)
        layer.alpha_composite(im)
        cell = layer.convert("RGB").crop(box)
        x0 = i * w * S8
        img.paste(cell.resize((w * S8, h * S8), Image.NEAREST), (x0, 0))
        d.text((x0 + 4, h * S8 + 2), label, fill=(255, 230, 120))
        img.paste(cell, (x0 + 4, h * S8 + 20))
        img.paste(cell.resize((w * 2, h * 2), Image.NEAREST), (x0 + 4 + w + 8, h * S8 + 20))
    img.save(out_path)
    print("wrote", out_path, img.size)


if __name__ == "__main__":
    main()
