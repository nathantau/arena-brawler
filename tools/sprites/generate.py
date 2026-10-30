"""Procedural pixel art for Arena Brawler's original characters.

Writes one horizontal sprite sheet per character to assets/sprites/<id>.png:
frames 0-3 = idle bob, frames 4-5 = hit flash (white silhouette, then one step lighter),
frames 6-9 = walk cycle (legs stride, upper body bounces on the passing frames).
Each frame is 64x64, transparent, palette-only colours, with an automatic 1 px outline.
Characters are built from "parts": each part is auto-shaded (dark band on its bottom/right
edge, highlight on its top/left edge) and can draw a dark line where it overlaps earlier parts.
Also writes the 1024 px app icon (assets/icon.png) from Flicker's first idle frame.

Run: tools/sprites/.venv/bin/python tools/sprites/generate.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

from palette import (BLUE, BROWN, DARKER, LIGHTER, MAROON, NAVY, ORANGE, OUTLINE, PALETTE, RED, SHADOW,
                     SKIN, SKIN_D, STEEL, STEEL_D, TEAL, TEAL_L, WHITE, YELLOW)

SIZE = 64
IDLE_BOB = [0, 1, 2, 1]  # upper-body offset (px down) per idle frame; legs stay planted
UPPER_DY = 2  # upper body sits this far down over the legs: shorter legs = chibbier
# Walk: per frame, (dx, dy) of the back and front leg, plus the upper-body bounce.
WALK_LEGS = [((-3, 0), (3, 0)), ((0, 0), (0, -2)), ((3, 0), (-3, 0)), ((0, -2), (0, 0))]
WALK_BOB = [0, -1, 0, -1]
SHADE_DEPTH = 2  # px of shade on a part's bottom/right edge
ICON_SIZE = 1024
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sprites"


# Shape helpers: each returns fn(draw, fill) so a shape can be painted into a mask or the canvas.
def E(box):
    return lambda d, f: d.ellipse(box, f)


def R(box):
    return lambda d, f: d.rectangle(box, f)


def RR(box, radius):
    return lambda d, f: d.rounded_rectangle(box, radius, f)


def P(points):
    return lambda d, f: d.polygon(points, f)


def L(points, width):
    return lambda d, f: d.line(points, f, width)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        self.px = self.img.load()

    def part(self, shape, color, shade=True, line=True):
        """Paints a shaded part; `line` draws OUTLINE where its edge sits on earlier parts."""
        mask = Image.new("1", (SIZE, SIZE), 0)
        shape(ImageDraw.Draw(mask), 1)
        m = mask.load()

        def inside(x, y):
            return 0 <= x < SIZE and 0 <= y < SIZE and m[x, y]

        if line:
            for y in range(SIZE):
                for x in range(SIZE):
                    if not inside(x, y) and self.px[x, y][3] and any(
                            inside(nx, ny) for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                        self.px[x, y] = OUTLINE + (255,)
        for y in range(SIZE):
            for x in range(SIZE):
                if not inside(x, y):
                    continue
                c = color
                if shade:
                    if not inside(x, y + SHADE_DEPTH) or not inside(x + SHADE_DEPTH, y):
                        c = DARKER[color]
                    elif not inside(x, y - 1) or not inside(x - 1, y):
                        c = LIGHTER[color]
                self.px[x, y] = c + (255,)

    def flat(self, shape, color):
        """Unshaded detail (eyes, rivets, stripes)."""
        shape(ImageDraw.Draw(self.img), color + (255,))

    def dot(self, x, y, color):
        self.px[x, y] = color + (255,)


def big_eyes(c: Canvas, y: int, xs: tuple[int, int], iris, h: int = 6):
    for x in xs:
        c.flat(R((x, y, x + 3, y + h)), OUTLINE)
        c.flat(R((x, y + h - 2, x + 3, y + h - 1)), iris)
        c.flat(R((x, y, x + 1, y + 1)), WHITE)  # glints
        c.dot(x + 3, y + h - 2, WHITE)


def face(c: Canvas, blush: tuple[int, int, int], mouth: tuple[int, int] | None = None):
    """Blush marks at (left x, right x, y) and an optional tiny mouth at (x, y)."""
    lx, rx, y = blush
    c.flat(R((lx, y, lx + 2, y)), ORANGE)
    c.flat(R((rx, y, rx + 1, y)), ORANGE)
    if mouth:
        mx, my = mouth
        c.flat(R((mx, my, mx + 1, my)), MAROON)


def legs(c: Canvas, pants, boots, step) -> list[int]:
    """Two stubby legs (back, front); `step` indexes WALK_LEGS, None = standing. Returns each leg's x."""
    xs = []
    for x, (dx, dy) in zip((24, 34), WALK_LEGS[step] if step is not None else ((0, 0), (0, 0))):
        c.part(R((x + dx, 45 + dy, x + dx + 6, 56 + dy)), pants)
        xs.append((x + dx, dy))
    for x, dy in xs:  # boot: shaft, then a foot with the toe pointing forward, dark sole
        c.part(P([(x - 1, 52 + dy), (x + 6, 52 + dy), (x + 6, 55 + dy), (x + 8, 55 + dy),
                  (x + 10, 57 + dy), (x + 10, 61 + dy), (x - 2, 61 + dy), (x - 2, 57 + dy)]), boots)
        c.flat(R((x - 2, 61 + dy, x + 10, 61 + dy)), SHADOW)
    return xs


# --- characters: each returns (legs canvas, upper canvas), facing right ------

def flicker(step=None):
    """Dash: hooded scout with a trailing scarf and a dagger on the back."""
    low = Canvas()
    for x, dy in legs(low, NAVY, BROWN, step):
        low.flat(R((x - 1, 52 + dy, x + 6, 53 + dy)), SKIN_D)  # boot cuffs
    up = Canvas()
    up.part(P([(21, 33), (4, 27), (2, 34), (9, 40), (21, 39)]), ORANGE)  # scarf tails
    up.part(P([(9, 33), (2, 34), (9, 40)]), RED, shade=False)
    up.part(L([(13, 25), (25, 45)], 4), BROWN)  # dagger sheath on the back
    up.part(RR((9, 21, 15, 27), 1), STEEL)  # dagger pommel
    up.part(RR((20, 33, 44, 48), 3), NAVY)  # tunic
    up.part(L([(23, 35), (40, 46)], 2), BROWN, shade=False, line=False)  # strap
    up.part(R((20, 44, 44, 46)), BROWN, line=False)  # belt
    up.part(R((30, 43, 34, 47)), YELLOW)
    up.dot(32, 45, ORANGE)
    up.part(E((16, 39, 23, 46)), SKIN)  # hands
    up.part(E((41, 39, 48, 46)), SKIN)
    up.part(P([(18, 12), (7, 19), (17, 27)]), TEAL)  # hood point
    up.part(E((15, 4, 49, 38)), TEAL)  # hood
    up.part(E((23, 15, 47, 35)), SKIN)  # face
    up.part(P([(23, 13), (47, 13), (47, 19), (41, 21), (36, 17), (30, 21), (23, 19)]), TEAL)  # fringe
    up.flat(E((20, 8, 27, 13)), TEAL_L)  # hood shine
    big_eyes(up, 21, (32, 40), TEAL)
    face(up, (28, 45, 29), (37, 29))
    up.part(RR((19, 31, 45, 37), 2), ORANGE)  # scarf
    up.part(RR((17, 32, 24, 39), 2), RED)  # scarf knot
    return low, up


def warden(step=None):
    """Shield: armoured knight with a plume, cape and tower shield."""
    low = Canvas()
    for x, dy in legs(low, STEEL_D, NAVY, step):
        low.part(R((x, 48 + dy, x + 6, 50 + dy)), STEEL, line=False)  # knee plates
    up = Canvas()
    up.part(P([(18, 32), (46, 32), (50, 50), (14, 50)]), RED)  # cape
    up.part(RR((20, 32, 44, 48), 3), STEEL)  # breastplate
    up.part(R((27, 35, 37, 48)), BLUE, line=False)  # tabard
    up.flat(R((27, 35, 37, 35)), YELLOW)
    up.flat(P([(32, 38), (35, 41), (32, 44), (29, 41)]), YELLOW)
    up.part(R((20, 45, 44, 47)), BROWN)  # belt
    up.part(E((12, 28, 27, 40)), STEEL)  # pauldrons
    up.part(E((37, 28, 52, 40)), STEEL)
    for x, y in ((16, 32), (23, 32), (41, 32), (48, 32)):
        up.dot(x, y, WHITE)  # rivets
    up.part(P([(24, 5), (10, 12), (14, 14), (24, 10)]), RED)  # plume tail
    up.part(E((21, 2, 37, 12)), RED)  # plume
    up.part(E((16, 5, 48, 37)), STEEL)  # helmet
    up.part(R((31, 6, 33, 18)), STEEL, line=False)  # crest ridge
    up.part(R((17, 30, 47, 35)), STEEL_D)  # helmet rim
    up.flat(RR((22, 19, 47, 27), 3), OUTLINE)  # visor
    for x in (34, 41):  # round glowing eyes
        up.flat(RR((x, 20, x + 3, 25), 1), TEAL_L)
        up.flat(R((x, 20, x + 1, 21)), WHITE)
    up.flat(R((30, 27, 32, 27)), ORANGE)  # blush glow on the faceplate
    up.flat(R((46, 27, 47, 27)), ORANGE)
    for x in (35, 38, 41, 44):
        up.dot(x, 29, STEEL_D)  # breathing holes
    up.part(RR((40, 31, 56, 57), 5), BLUE)  # tower shield
    up.flat(RR((42, 33, 54, 55), 4), NAVY)
    up.part(RR((43, 34, 53, 54), 3), BLUE, line=False)
    up.part(P([(48, 37), (52, 44), (48, 51), (44, 44)]), YELLOW, line=False)
    for x, y in ((43, 34), (53, 34), (43, 54), (53, 54)):
        up.dot(x, y, STEEL)
    return low, up


def twinshot(step=None):
    """Dual wield: gunslinger with a feathered wide hat, poncho, bandolier and two holsters."""
    low = Canvas()
    for x, dy in legs(low, BLUE, BROWN, step):
        low.dot(x - 3, 58 + dy, YELLOW)  # spurs
    up = Canvas()
    up.part(P([(18, 33), (46, 33), (50, 48), (14, 48)]), ORANGE)  # poncho
    for x in range(16, 49, 4):
        up.flat(P([(x, 41), (x + 2, 39), (x + 4, 41)]), RED)  # zigzag
    for x in range(17, 48, 4):
        up.dot(x, 44, YELLOW)
    up.part(L([(19, 34), (44, 47)], 3), BROWN, shade=False)  # bandolier
    for i in range(5):
        up.dot(22 + i * 5, 36 + int(i * 2.5), YELLOW)
    up.part(R((14, 46, 50, 48)), BROWN)  # gun belt
    for x in (12, 45):
        up.part(RR((x, 42, x + 7, 54), 2), BROWN)  # holster
        up.part(RR((x + 1, 36, x + 5, 43), 1), STEEL_D)  # grip
        up.dot(x + 2, 37, STEEL)
    up.part(E((20, 14, 44, 37)), SKIN)  # face
    big_eyes(up, 23, (30, 37), BLUE)
    up.flat(R((30, 21, 33, 21)), BROWN)  # brows
    up.flat(R((37, 21, 40, 21)), BROWN)
    face(up, (26, 42, 30))
    up.part(RR((20, 32, 44, 37), 2), RED)  # bandana
    up.part(P([(21, 33), (14, 37), (16, 40), (22, 36)]), RED)  # bandana tail
    up.part(E((5, 13, 59, 23)), BROWN)  # hat brim
    up.part(RR((18, 2, 46, 18), 6), BROWN)  # crown
    up.flat(R((31, 3, 33, 7)), MAROON)  # crown dent
    up.part(R((18, 11, 46, 14)), YELLOW, line=False)  # band
    up.part(P([(40, 12), (53, 2), (56, 4), (44, 13)]), TEAL)  # feather
    return low, up


CHARACTERS = {"flicker": flicker, "warden": warden, "twinshot": twinshot}


# --- frame processing -------------------------------------------------------

def outline(img: Image.Image) -> Image.Image:
    """Adds a 1 px OUTLINE border around every opaque region (4-neighbour)."""
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if src[x, y][3]:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < SIZE and 0 <= ny < SIZE and src[nx, ny][3]:
                    dst[x, y] = OUTLINE + (255,)
                    break
    return out


def recolor(img: Image.Image, fn) -> Image.Image:
    out = img.copy()
    px = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = px[x, y]
            if a and (r, g, b) != OUTLINE:
                px[x, y] = fn((r, g, b)) + (255,)
    return out


def frames(build) -> list[Image.Image]:
    low, up = build()

    def frame(legs_img, dy):
        f = legs_img.copy()
        f.alpha_composite(up.img, (0, UPPER_DY + dy))
        return outline(f)

    idle = [frame(low.img, dy) for dy in IDLE_BOB]
    hit = [recolor(idle[0], lambda _c: WHITE), recolor(idle[0], LIGHTER.__getitem__)]
    walk = [frame(build(i)[0].img, dy) for i, dy in enumerate(WALK_BOB)]
    return idle + hit + walk


def check(sheet: Image.Image) -> None:
    """Self-check: palette-only colours, hard alpha, and the outline fits inside each frame."""
    allowed = set(PALETTE)
    px = sheet.load()
    w, h = sheet.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            assert a in (0, 255), f"soft alpha at {x},{y}"
            assert not a or (r, g, b) in allowed, f"off-palette colour {(r, g, b)} at {x},{y}"
            on_edge = y in (0, h - 1) or x % SIZE in (0, SIZE - 1)
            assert not (a and on_edge), f"sprite touches frame edge at {x},{y}"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in CHARACTERS.items():
        fs = frames(build)
        sheet = Image.new("RGBA", (SIZE * len(fs), SIZE), (0, 0, 0, 0))
        for i, f in enumerate(fs):
            sheet.paste(f, (i * SIZE, 0))
        check(sheet)
        sheet.save(OUT / f"{name}.png")
        print(f"wrote {OUT / f'{name}.png'} ({len(fs)} frames)")
    # App Store icons must be opaque.
    icon = Image.new("RGBA", (SIZE, SIZE), NAVY + (255,))
    icon.alpha_composite(frames(flicker)[0])
    icon.convert("RGB").resize((ICON_SIZE, ICON_SIZE), Image.NEAREST).save(ROOT / "assets" / "icon.png")
    print("wrote assets/icon.png")


if __name__ == "__main__":
    main()
