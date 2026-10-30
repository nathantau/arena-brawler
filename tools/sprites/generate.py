"""Procedural pixel art for Arena Brawler's original characters.

Writes one horizontal sprite sheet per character to assets/sprites/<id>.png:
frames 0-3 = idle bob, frames 4-5 = hit flash (white silhouette, then one step lighter).
Each frame is 64x64, transparent, palette-only colours, with an automatic 1 px outline.
Also writes the 1024 px app icon (assets/icon.png) from Flicker's first idle frame.

Run: tools/sprites/.venv/bin/python tools/sprites/generate.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

from palette import (BLUE, BROWN, LIGHTER, NAVY, ORANGE, OUTLINE, PALETTE, RED, SHADOW, SKIN, SKIN_D,
                     STEEL, STEEL_D, TEAL, TEAL_L, WHITE, YELLOW)

SIZE = 64
IDLE_BOB = [0, 1, 2, 1]  # upper-body offset (px down) per idle frame; legs stay planted
ICON_SIZE = 1024
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sprites"


def layer() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def eyes(d: ImageDraw.ImageDraw, y: int, xs: tuple[int, int], color=OUTLINE) -> None:
    for x in xs:
        d.rectangle((x, y, x + 2, y + 3), color)
        if color == OUTLINE:
            d.point((x, y), WHITE)  # glint


def legs(d: ImageDraw.ImageDraw, pants, boots) -> None:
    d.rectangle((24, 46, 30, 56), pants)
    d.rectangle((34, 46, 40, 56), pants)
    d.rectangle((23, 55, 31, 61), boots)
    d.rectangle((33, 55, 41, 61), boots)


# --- characters: each returns (legs layer, upper layer), facing right -------

def flicker():
    """Dash: hooded scout with a trailing scarf."""
    low, d = layer()
    legs(d, NAVY, BROWN)
    up, d = layer()
    d.polygon([(22, 33), (6, 29), (4, 35), (10, 39), (22, 38)], ORANGE)  # scarf tails
    d.polygon([(10, 35), (4, 35), (10, 39)], RED)
    d.rectangle((22, 34, 42, 47), NAVY)  # tunic
    d.rectangle((38, 34, 42, 47), SHADOW)
    d.rectangle((22, 44, 42, 45), BROWN)  # belt
    d.rectangle((31, 43, 34, 46), YELLOW)
    d.ellipse((16, 6, 48, 37), TEAL)  # hood
    d.ellipse((20, 9, 30, 16), TEAL_L)
    d.ellipse((24, 16, 46, 34), SKIN)  # face
    d.rectangle((24, 15, 46, 19), TEAL)  # hood rim
    d.rectangle((42, 22, 45, 31), SKIN_D)
    eyes(d, 23, (33, 39))
    d.rectangle((21, 32, 43, 36), ORANGE)  # scarf
    d.rectangle((21, 36, 43, 37), RED)
    d.ellipse((17, 39, 23, 45), SKIN)  # hands
    d.ellipse((41, 39, 47, 45), SKIN)
    return low, up


def warden():
    """Shield: armoured knight with a plume and a tower shield."""
    low, d = layer()
    legs(d, STEEL_D, SHADOW)
    up, d = layer()
    d.rectangle((21, 33, 43, 47), STEEL)  # breastplate
    d.rectangle((38, 33, 43, 47), STEEL_D)
    d.rectangle((27, 35, 37, 47), BLUE)  # tabard
    d.rectangle((27, 35, 37, 36), YELLOW)
    d.ellipse((14, 30, 26, 40), STEEL)  # pauldrons
    d.ellipse((38, 30, 50, 40), STEEL_D)
    d.ellipse((22, 2, 36, 11), RED)  # plume
    d.ellipse((24, 3, 30, 7), ORANGE)
    d.ellipse((17, 6, 47, 36), STEEL)  # helmet
    d.ellipse((21, 10, 28, 16), WHITE)
    d.rectangle((18, 30, 46, 34), STEEL_D)  # rim
    d.rounded_rectangle((23, 19, 46, 26), 3, OUTLINE)  # visor
    eyes(d, 21, (33, 40), TEAL_L)
    d.rounded_rectangle((40, 32, 54, 54), 4, BLUE)  # tower shield
    d.rounded_rectangle((42, 34, 52, 52), 3, NAVY)
    d.polygon([(47, 37), (50, 43), (47, 49), (44, 43)], YELLOW)
    return low, up


def twinshot():
    """Dual wield: gunslinger with a wide hat, poncho and two holstered pistols."""
    low, d = layer()
    legs(d, SHADOW, BROWN)
    up, d = layer()
    d.polygon([(20, 34), (44, 34), (48, 46), (16, 46)], ORANGE)  # poncho
    d.rectangle((18, 40, 46, 41), RED)
    d.rectangle((18, 45, 46, 47), BROWN)  # gun belt
    for x in (14, 44):  # holsters + grips
        d.rectangle((x, 43, x + 5, 51), BROWN)
        d.rectangle((x + 1, 39, x + 3, 43), STEEL)
    d.ellipse((21, 14, 43, 36), SKIN)  # face
    d.rectangle((39, 22, 42, 31), SKIN_D)
    eyes(d, 24, (31, 37))
    d.rectangle((22, 32, 42, 36), RED)  # bandana
    d.ellipse((6, 13, 58, 22), BROWN)  # hat brim
    d.rounded_rectangle((19, 3, 45, 17), 5, BROWN)  # crown
    d.rectangle((19, 11, 45, 13), YELLOW)  # band
    d.ellipse((22, 5, 28, 9), SKIN_D)
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
    idle = []
    for dy in IDLE_BOB:
        f = low.copy()
        f.alpha_composite(up, (0, dy))
        idle.append(outline(f))
    hit = [recolor(idle[0], lambda _c: WHITE), recolor(idle[0], LIGHTER.__getitem__)]
    return idle + hit


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
