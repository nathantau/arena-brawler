"""Shadow redesign concepts (gangster street look, all-black hoodie). Single idle frame per variant, nothing is written
into assets/: previews go to /private/tmp/claude-501/redesign-previews/.
Run: tools/sprites/.venv/bin/python tools/sprites/shadow_concepts.py
Only palette colours are used: OUTLINE is the "black" (its auto rim is SHADOW), SHADOW the dark grey, one accent per variant."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw  # noqa: E402

import generate as g  # noqa: E402
from generate import BODY, FACE, FACE_R, L, P, R, RR, E, Canvas, arm, legs  # noqa: E402
from palette import (OUTLINE, SHADOW, STEEL, STEEL_D, WHITE, YELLOW, RED, TEAL_L, TEAL, ORANGE)  # noqa: E402

OUT_DIR = Path("/private/tmp/claude-501/redesign-previews")
ROOT = Path(__file__).resolve().parents[2]
BLACK = OUTLINE


def baggy_legs(low: Canvas, pants, cuff, shoe, sole_accent, wide=1):
    """Baggy pants: legs a bit wider than the base, a bunched cuff, chunky sneakers."""
    for x in (23, 34):
        low.part(RR((x - wide, 45, x + 5 + wide, 55), 1), pants)
        low.flat(R((x - wide, 52, x + 5 + wide, 52)), SHADOW)  # bunched hem
        low.flat(L([(x + 1, 47), (x + 1, 50)], 1), SHADOW)  # fold
        low.part(RR((x - 2, 54, x + 8, 58), 2), shoe)
        low.flat(R((x - 1, 58, x + 7, 58)), sole_accent)  # sole
        low.flat(R((x + 4, 55, x + 7, 55)), WHITE)  # toe sheen


def eyes_glow(up: Canvas, col, ys=21):
    for x in (31, 41):
        up.flat(R((x, ys, x + 3, ys + 1)), col)
        up.dot(x + 1, ys, WHITE)


def hood(up: Canvas, base=BLACK, lip=STEEL_D, peak=True):
    """Hood up: a big rounded shell with a drape on the back; the face opening is a dark void under the brow."""
    up.part(lambda d, f: (d.ellipse((15, 5, 49, 38), f), d.polygon(
        [(15, 20), (11, 29), (14, 28), (13, 37), (19, 33), (22, 38), (24, 31), (24, 20)], f)), base)
    up.flat(L([(21, 9), (30, 6), (39, 7)], 1), lip)  # rim light on the crown
    up.flat(L([(16, 20), (14, 27)], 1), lip)
    up.part(RR(FACE, FACE_R), SHADOW if False else BLACK)  # the opening
    up.flat(RR((FACE[0] + 1, FACE[1] + 1, FACE[2], FACE[3] - 1), FACE_R - 2), BLACK)
    # a lit hood edge round the opening so the face reads as a hole
    up.flat(L([(FACE[0] + 1, 16), (FACE[0] + 3, 14), (FACE[2] - 3, 13), (FACE[2], 16)], 1), lip)
    up.flat(L([(FACE[2] + 1, 18), (FACE[2] + 1, 30)], 1), SHADOW)


def hoodie_body(up: Canvas, base, trim, pocket=True):
    arm(up, g.ARM_X[0], base, base)
    up.part(RR((19, 32, 45, 49), 4), base)  # wider, boxier hoodie
    up.flat(R((19, 47, 44, 48)), SHADOW)  # ribbed hem
    up.flat(L([(26, 34), (25, 40)], 1), trim)  # drawstrings
    up.flat(L([(33, 34), (34, 40)], 1), trim)
    up.dot(25, 41, WHITE)
    up.dot(34, 41, WHITE)
    if pocket:
        up.flat(P([(23, 43), (41, 43), (43, 48), (21, 48)]), BLACK)  # kangaroo pocket
        up.flat(L([(23, 43), (41, 43)], 1), STEEL_D)
        up.flat(L([(21, 48), (23, 43)], 1), BLACK)
    if pocket:  # two fists pushing the pocket out
        for x in (27, 35):
            up.part(E((x, 42, x + 5, 47)), base)
            up.flat(L([(x + 1, 43), (x + 3, 43)], 1), STEEL_D)
    arm(up, g.ARM_X[1], base, base)  # front arm tucked into the pocket: no hand showing
    up.flat(R((g.ARM_X[1], 42, g.ARM_X[1] + 5, 43)), SHADOW)


def chain(up: Canvas, col, pendant):
    pts = [(23, 34), (26, 39), (32, 41), (38, 39), (41, 34)]
    up.flat(L(pts, 1), col)
    up.flat(R((31, 41, 33, 43)), pendant)
    up.dot(32, 42, WHITE)


# --- A: red bandana mask, white sneakers --------------------------------------------------------------------------------
def variant_a():
    low = Canvas()
    baggy_legs(low, BLACK, SHADOW, WHITE, RED)
    up = Canvas()
    hoodie_body(up, SHADOW, STEEL)
    chain(up, STEEL, STEEL)
    hood(up, SHADOW, STEEL)
    # bandana mask over the lower face with a knot tail
    up.flat(RR((FACE[0] + 2, 27, FACE[2] - 1, FACE[3] - 1), 3), RED)
    up.flat(L([(FACE[0] + 3, 27), (FACE[2] - 2, 27)], 1), ORANGE)
    for x, y in ((30, 31), (34, 32), (38, 31), (42, 32)):
        up.dot(x, y, WHITE)  # paisley specks
    up.flat(P([(25, 30), (21, 36), (23, 39), (27, 34)]), RED)  # knot tail
    eyes_glow(up, WHITE, 22)
    up.flat(L([(30, 20), (35, 21)], 1), BLACK)  # heavy brow
    up.flat(L([(40, 21), (45, 20)], 1), BLACK)
    return low, up


# --- B: ski mask, gold chain, black on black ------------------------------------------------------------------------------
def variant_b():
    low = Canvas()
    baggy_legs(low, BLACK, SHADOW, SHADOW, YELLOW, wide=2)
    up = Canvas()
    hoodie_body(up, SHADOW, STEEL_D)
    chain(up, YELLOW, YELLOW)
    up.flat(L([(24, 35), (27, 40), (32, 42), (37, 40), (40, 35)], 1), ORANGE)  # second, longer chain
    hood(up, SHADOW, STEEL_D)
    # ski mask: knit weave in the opening, eye hole band
    up.flat(RR((FACE[0] + 2, FACE[1] + 3, FACE[2] - 1, FACE[3] - 1), 5), SHADOW)
    for y in range(17, 35, 3):
        up.flat(L([(FACE[0] + 3, y), (FACE[2] - 2, y)], 1), BLACK)
    up.flat(R((29, 20, 46, 25)), BLACK)  # eye band cut out
    eyes_glow(up, WHITE, 22)
    up.flat(L([(29, 20), (46, 20)], 1), STEEL_D)
    up.flat(L([(32, 30), (42, 30)], 1), BLACK)  # mouth seam
    return low, up


# --- C: teal-trim techwear hoodie, cross-body bag -------------------------------------------------------------------------
def variant_c():
    low = Canvas()
    baggy_legs(low, BLACK, BLACK, SHADOW, TEAL_L, wide=1)
    for x in (23, 34):
        low.flat(L([(x + 4, 46), (x + 4, 52)], 1), TEAL)  # side stripe
    up = Canvas()
    hoodie_body(up, SHADOW, TEAL, pocket=True)
    up.flat(L([(22, 33), (30, 38), (40, 46)], 2), SHADOW)  # bag strap
    up.flat(L([(22, 33), (30, 38), (40, 46)], 1), STEEL_D)
    up.part(RR((35, 42, 45, 50), 2), SHADOW)  # the bag on the hip
    up.flat(R((36, 44, 44, 44)), TEAL_L)
    up.flat(R((38, 47, 42, 47)), TEAL)
    chain(up, STEEL, TEAL_L)
    hood(up, SHADOW, TEAL_L)
    # half face mask (respirator-style) in dark grey with teal vents
    up.flat(RR((FACE[0] + 4, 28, FACE[2] - 1, FACE[3] - 1), 3), SHADOW)
    for x in (32, 36, 40):
        up.flat(L([(x, 30), (x, 33)], 1), TEAL)
    up.flat(L([(FACE[0] + 4, 28), (FACE[2] - 1, 28)], 1), STEEL_D)
    eyes_glow(up, TEAL_L, 22)
    up.flat(L([(30, 19), (36, 20)], 1), TEAL)  # trim on the brow
    return low, up


VARIANTS = (("A", variant_a, "red bandana + white kicks"), ("B", variant_b, "ski mask + gold chains"),
            ("C", variant_c, "teal techwear + mask"))


def rim(f: Image.Image, col=STEEL_D) -> None:
    """Rim light: dark pixels on the silhouette's top / left edge turn STEEL_D so the black reads against the floor."""
    px = f.load()
    w, h = f.size
    dark = {BLACK + (255,), SHADOW + (255,)}
    todo = []
    for y in range(h):
        for x in range(w):
            if px[x, y] in dark and ((y == 0 or px[x, y - 1][3] == 0) or (x == 0 or px[x - 1, y][3] == 0)):
                todo.append((x, y))
    for x, y in todo:
        px[x, y] = col + (255,)


def idle_frame(build) -> Image.Image:
    low, up = build()
    f = Image.new("RGBA", (g.SIZE, g.SIZE), (0, 0, 0, 0))
    f.alpha_composite(low.img)
    f.alpha_composite(up.img, (0, g.UPPER_DY))
    rim(f)
    return g.cell(g.outline(f))


def sheet_frame(name: str, i: int = 0) -> Image.Image:
    img = Image.open(ROOT / "assets" / "sprites" / f"{name}.png").convert("RGBA")
    return img.crop((i * g.CELL, 0, (i + 1) * g.CELL, g.CELL))


def floor_crop(w: int, h: int) -> Image.Image:
    tiles = Image.open(ROOT / "assets" / "arenas" / "pit_tiles.png").convert("RGBA")
    t = tiles.height
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, t):
        for x in range(0, w, t):
            out.paste(tiles.crop(((x // t + y // t) % 2 * t, 0, (x // t + y // t) % 2 * t + t, t)), (x, y))
    return out


def nn(img: Image.Image, k: int) -> Image.Image:
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def ingame(shadow_img: Image.Image) -> Image.Image:
    """The three fighters on arena floor at the game's pixel scale (sprite 1.5 x camera 1.4 = 2.1, shown at 2x)."""
    n = 3
    cw = g.CELL
    floor = floor_crop(cw * n, cw)
    for k, im in enumerate((sheet_frame("flicker"), shadow_img, sheet_frame("bolt"))):
        floor.alpha_composite(im, (k * cw, 0))
    return nn(floor, 2)


def labelled(img: Image.Image, text: str) -> Image.Image:
    out = Image.new("RGBA", (img.width, img.height + 22), (24, 24, 32, 255))
    out.alpha_composite(img, (0, 22))
    ImageDraw.Draw(out).text((6, 5), text, fill=(240, 240, 230, 255))
    return out


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    panels = []
    for letter, build, blurb in VARIANTS:
        im = idle_frame(build)
        big = nn(im, 8)
        bg = Image.new("RGBA", big.size, (60, 56, 52, 255))
        bg.alpha_composite(big)
        game = ingame(im)
        pad = 8
        w = max(bg.width, game.width) + pad * 2
        sheet = Image.new("RGBA", (w, bg.height + game.height + pad * 3), (24, 24, 32, 255))
        sheet.alpha_composite(bg, (pad, pad))
        sheet.alpha_composite(game, (pad, bg.height + pad * 2))
        sheet = labelled(sheet, f"Shadow {letter}: {blurb}")
        sheet.convert("RGB").save(OUT_DIR / f"shadow_{letter.lower()}.png")
        panels.append(labelled(Image.alpha_composite(Image.new("RGBA", game.size, (0, 0, 0, 255)), game), f"{letter}"))
    # combined sheet: big frames side by side + the in-game strips
    bigs = []
    for letter, build, blurb in VARIANTS:
        b = nn(idle_frame(build), 6)
        bg = Image.new("RGBA", b.size, (60, 56, 52, 255))
        bg.alpha_composite(b)
        bigs.append(labelled(bg, f"{letter}: {blurb}"))
    row_w = sum(p.width for p in bigs) + 8 * (len(bigs) + 1)
    games_h = sum(p.height for p in panels) + 8 * len(panels)
    allsheet = Image.new("RGBA", (max(row_w, panels[0].width + 16), bigs[0].height + games_h + 24), (24, 24, 32, 255))
    x = 8
    for p in bigs:
        allsheet.alpha_composite(p, (x, 8))
        x += p.width + 8
    y = bigs[0].height + 16
    for p in panels:
        allsheet.alpha_composite(p, (8, y))
        y += p.height + 8
    allsheet.convert("RGB").save(OUT_DIR / "shadow_all.png")
    print("wrote previews to", OUT_DIR)


if __name__ == "__main__":
    main()
