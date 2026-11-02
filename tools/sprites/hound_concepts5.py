"""Gloom Hound concept, round 5: a CHIBI shadow hound built like the fighters (generate.py helpers: Canvas.part shading with
top-left light, one outline pass, dithered shade). Front-facing 3/4, ~24 px tall, a big round head (half the height) with big
pointed ears, a snub muzzle and big angry glowing eyes, a compact chest with a smoke ruff, stubby legs, a fluffy tail curling up.
Shows an idle front frame and a run frame next to Shadow at 8x with 1x / 2x insets. Nothing is written into assets/.
Run: tools/sprites/.venv/bin/python tools/sprites/hound_concepts5.py [out.png]"""
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


def bez(p0, p1, p2, p3, n=14):
    pts = []
    for i in range(n + 1):
        u = i / n
        x = (1 - u) ** 3 * p0[0] + 3 * (1 - u) ** 2 * u * p1[0] + 3 * (1 - u) * u * u * p2[0] + u ** 3 * p3[0]
        y = (1 - u) ** 3 * p0[1] + 3 * (1 - u) ** 2 * u * p1[1] + 3 * (1 - u) * u * u * p2[1] + u ** 3 * p3[1]
        pts.append((x, y))
    return pts


BASE = OUTLINE  # near-black indigo body; violet only where the light catches it


def plume(c: Canvas, bob: int, tw: float) -> None:
    """One tapered fluffy tail curling up and over behind the body: a lit top edge, a shaded underside, fur notches, and a tip
    that breaks into smoke."""
    centre = bez((22, 54 + bob), (12 - tw, 55 + bob), (8 - tw, 42 + bob), (12 - tw * 0.6, 33 + bob))
    top, under = [], []
    for i, (x, y) in enumerate(centre):
        u = i / (len(centre) - 1)
        w = 4.6 * (1 - u) ** 0.8 + 1.0
        nx, ny = (centre[min(i + 1, len(centre) - 1)][1] - centre[max(i - 1, 0)][1]), -(centre[min(i + 1, len(centre) - 1)][0] - centre[max(i - 1, 0)][0])
        ln = math.hypot(nx, ny) or 1.0
        nx, ny = nx / ln, ny / ln
        top.append((x - nx * w * 0.55, y - ny * w * 0.55))
        under.append((x + nx * w, y + ny * w))
    c.part(P(top + under[::-1]), BASE)
    d = ImageDraw.Draw(c.img)
    for k in (3, 6, 9):  # soft fur notches on the underside
        x, y = under[k]
        d.polygon([(x - 1, y - 1), (x + 1, y + 1), (x + 1.5, y - 2)], fill=(0, 0, 0, 0))
    for (x, y) in top[1:9]:  # the lit top edge
        c.dot(round(x), round(y), VIOLET)
    for (x, y) in top[2:7:2]:
        c.dot(round(x), round(y) - 1 if False else round(y), VIOLET_L)
    tx, ty = centre[-1]
    wisp(c, tx + 1, ty - 1, 0.7, -0.6, 7, 3)


def hound(t: int = 0, step: int | None = None) -> Canvas:
    """One frame, 64 px canvas. `t` 0..3 is the sway tick; `step` None = standing, 0..3 = a run frame."""
    c = Canvas(64)
    sway = (0, 1, 1, 0)[t % 4]
    run = step is not None
    bob = (0, -2, 0, -1)[step % 4] if run else (0, 0, 1, 0)[t % 4]
    squash = (1, 0, 1, 0)[step % 4] if run else 0
    tw = (0, 1, 2, 1)[t % 4]
    plume(c, bob, tw)
    legs_y = FEET - 5
    lf = ((24, legs_y - 2), (35, legs_y - 2))  # front legs: forward and long
    lb = ((19, legs_y - 1), (41, legs_y - 1))
    if run:
        a = step % 4
        lift = ((3, 0), (0, 3), (3, 0), (0, 3))[a]
        lf = ((24 - (a in (1, 3)), legs_y - 2 - lift[0]), (35 + (a in (0, 2)), legs_y - 2 - lift[1]))
        lb = ((19 + (a in (0, 2)), legs_y - 1 - lift[1]), (41 - (a in (1, 3)), legs_y - 1 - lift[0]))
    for (x, y) in lb:  # hind legs: short, dark
        c.part(RR((x, y + bob, x + 5, y + 5 + bob), 2), SHADOW)
        c.flat(R((x + 1, y + 5 + bob, x + 4, y + 5 + bob)), VIOLET_D)
    c.part(RR((21, 42 + bob + squash, 45, 56 + bob), 6), BASE)  # the body
    c.flat(L([(25, 44 + bob), (37, 43 + bob)], 1), VIOLET)  # violet on the lit back
    c.flat(L([(23, 46 + bob), (24, 49 + bob)], 1), VIOLET_D)
    for x in range(24, 43, 2):
        c.dot(x + (x // 2) % 2, 54 + bob, SHADOW if x % 4 == 0 else BASE)  # dithered belly lift so it isn't a black slab
    # smoke ruff: tufts round the neck, violet only on their lit tips, lavender highlights
    c.part(E((18, 43 + bob, 46, 52 + bob)), BASE)
    for i, x in enumerate(range(19, 46, 4)):
        tip_y = 54 + bob + (i % 2)
        c.part(P([(x, 49 + bob), (x + 4, 49 + bob), (x + 2 + (sway if i % 2 else -sway), tip_y)]), BASE, line=False)
        c.dot(x + 2, 48 + bob, VIOLET)
        if i % 2 == 0:
            c.dot(x + 1, 47 + bob, VIOLET_L)
    for (x, y) in lf:  # front legs forward over the ruff: longer, with light top edges
        c.part(RR((x, y + bob, x + 5, y + 8 + bob), 2), VIOLET_D)
        c.flat(L([(x + 1, y + bob), (x + 4, y + bob)], 1), VIOLET)  # light top edge
        c.flat(R((x + 1, y + 8 + bob, x + 4, y + 8 + bob)), VIOLET_D)  # paw
        c.dot(x + 1, y + 1 + bob, VIOLET_L)
    # head
    hx, hy = 32, 41 + bob
    for side in (-1, 1):  # big pointed ears: dark, a violet rim on the lit edge, lavender tips, lighter inner ear
        ex = hx + side * 9
        tip = (ex + side * 3, hy - 14)
        c.part(P([(ex - 4, hy - 3), tip, (ex + 4, hy - 1)]), BASE)
        c.flat(P([(ex - 2, hy - 3), (ex + side * 2, hy - 10), (ex + 2, hy - 2)]), VIOLET_D)  # inner ear
        c.flat(L([(ex - 4, hy - 3), tip], 1), VIOLET if side < 0 else VIOLET_D)  # rim light on the left ear's outer edge
        c.dot(tip[0], tip[1] + 1, VIOLET_L)
        c.dot(tip[0], tip[1], VIOLET_L if side < 0 else VIOLET)
    c.part(E((hx - 12, hy - 9, hx + 12, hy + 9)), BASE)  # the skull
    c.flat(L([(hx - 9, hy - 7), (hx + 1, hy - 8)], 1), VIOLET)  # violet on the head's top plane
    c.flat(L([(hx - 11, hy - 4), (hx - 10, hy - 6)], 1), VIOLET)
    c.dot(hx - 6, hy - 8, VIOLET_L)
    # wolf muzzle: longer, narrower, pointing a little down, same dark tone; lighter chin and cheek fur only
    c.part(E((hx - 5, hy + 1, hx + 5, hy + 10)), BASE)
    c.flat(L([(hx - 1, hy + 1), (hx - 1, hy + 5)], 1), SHADOW)  # the bridge catching a little light
    c.part(E((hx - 3, hy + 8, hx + 3, hy + 12)), VIOLET_D)  # lighter chin
    for side in (-1, 1):  # cheek fur tufts
        c.flat(P([(hx + side * 8, hy + 3), (hx + side * 4, hy + 7), (hx + side * 10, hy + 9)]), VIOLET_D)
    c.flat(R((hx - 2, hy + 7, hx, hy + 8)), WHITE if False else OUTLINE)  # the nose, small and black, at the tip
    c.dot(hx - 1, hy + 6, VIOLET_L)  # its glint
    c.flat(L([(hx - 3, hy + 9), (hx + 3, hy + 9)], 1), OUTLINE)  # mouth line
    c.dot(hx - 2, hy + 10, WHITE)  # a tiny fang
    for side in (-1, 1):  # big angry glowing eyes
        ex = hx + side * 6
        c.flat(R((ex - 2, hy - 4, ex + 2, hy + 1)), VIOLET_L)
        c.flat(R((ex - 1, hy - 3, ex + 1, hy)), WHITE)
        c.flat(P([(ex - side * 3, hy - 5), (ex + side * 3, hy - 5), (ex - side * 3, hy - 1)]), BASE)
        c.flat(L([(ex - side * 3, hy - 2), (ex + side * 2, hy - 5)], 1), OUTLINE)
    wisp(c, 18, 44 + bob, -0.8, -0.6, 7, 1)
    wisp(c, 45, 45 + bob, 0.8, -0.7, 7, 2)
    for k, (x, y) in enumerate(lf + lb):
        wisp(c, x + 2, FEET + 1 + (0 if y >= legs_y - 3 else -2), -0.3 if k % 2 else 0.3, 0.0, 3, 10 + k)
    return c


def main() -> None:
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("hound_concepts5.png")
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
