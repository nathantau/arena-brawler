"""Procedural pixel art for BrawlBits' original characters.

Writes one horizontal sprite sheet per character to assets/sprites/<id>.png (and one image per
weapon to assets/sprites/weapons/<id>.png):
frames 0-3 = idle bob, frames 4-5 = hit flash (white silhouette, then one step lighter),
frames 6-13 = walk cycle (legs stride, upper body bounces on the passing frames).
Characters also get `t` (frame tick) for small loops: fluttering scarves, swaying feathers, glints.
Each frame is 64x64, transparent, palette-only colours, with an automatic 1 px outline.
Characters are built from "parts": each part is auto-shaded (dark band on its bottom/right
edge, highlight on its top/left edge) and can draw a dark line where it overlaps earlier parts.
Also writes the 1024 px app icon (assets/icon.png) from Flicker's first idle frame.

Run: tools/sprites/.venv/bin/python tools/sprites/generate.py
"""

import functools
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

from palette import (BLUE, BROWN, DARKER, LIGHTER, MAROON, NAVY, ORANGE, OUTLINE, PALETTE, PINK, PINK_L, RED,
                     SHADOW, SKIN, SKIN_D, STEEL, STEEL_D, TEAL, TEAL_L, WHITE, YELLOW)

SIZE = 64
IDLE_BOB = [0, 1, 2, 1]  # upper-body offset (px down) per idle frame; legs stay planted
UPPER_DY = 2  # upper body sits this far down over the legs: shorter legs = chibbier
# Walk (8 frames): per frame, (dx, dy) of the back and front leg; a leg lifts while it swings forward.
WALK_LEGS = [((-3, 0), (3, 0)), ((-2, -1), (2, 0)), ((0, -2), (0, 0)), ((2, -1), (-2, 0)),
             ((3, 0), (-3, 0)), ((2, 0), (-2, -1)), ((0, 0), (0, -2)), ((-2, 0), (2, -1))]
WALK_BOB = [1, 0, -1, 0, 1, 0, -1, 0]  # body dips on contact, rises while passing
SWAY = [0, 1, 0, -1]  # px offset for fluttering bits, indexed by t % 4
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
    def __init__(self, size: int = SIZE):
        self.size = size
        self.img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        self.px = self.img.load()

    def part(self, shape, color, shade=True, line=True):
        """Paints a shaded part; `line` draws OUTLINE where its edge sits on earlier parts."""
        n = self.size
        mask = Image.new("1", (n, n), 0)
        shape(ImageDraw.Draw(mask), 1)
        m = mask.load()

        def inside(x, y):
            return 0 <= x < n and 0 <= y < n and m[x, y]

        bb = mask.getbbox()  # only the shape's box (plus its 1 px outline ring) can change
        if bb is None:
            return
        xs, xe, ys, ye = max(0, bb[0] - 1), min(n, bb[2] + 1), max(0, bb[1] - 1), min(n, bb[3] + 1)
        if line:
            for y in range(ys, ye):
                for x in range(xs, xe):
                    if not inside(x, y) and self.px[x, y][3] and any(
                            inside(nx, ny) for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                        self.px[x, y] = OUTLINE + (255,)
        for y in range(ys, ye):
            for x in range(xs, xe):
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


## Set while drawing death frames: eye helpers draw knocked-out X eyes instead.
KO = False


def x_eye(c: Canvas, x: int, y: int, color=OUTLINE):
    """A 4x4 knocked-out X with its top-left at (x, y)."""
    c.flat(L([(x, y), (x + 3, y + 3)], 1), color)
    c.flat(L([(x + 3, y), (x, y + 3)], 1), color)


# All characters use a 6 px gap between eyes (left eye x, then left x + 10).
## Every character shares one base, modelled on Apex's (Wukong's) face: the same face (a rounded square) and body
## box, eyes, blush and mouth at the same spots. Hair, hats, masks and outfits go on top. Corner radius in art px.
FACE = (23, 15, 47, 36)
FACE_R = 8
BODY = (20, 33, 44, 48)
EYES_X = (31, 41)
EYES_Y = 22
BLUSH = (27, 45, 29)
MOUTH = (37, 30)
## The whole head (hair / back of head) is centred over the body; the face sits right of centre, turned the way
## the character faces. Characters without hair fill this behind the face.
HEAD = (17, 12, 47, 37)


def big_eyes(c: Canvas, y: int, xs: tuple[int, int], iris, h: int = 6):
    for x in xs:
        if KO:
            x_eye(c, x, y + 1)
            continue
        c.flat(R((x, y, x + 3, y + h)), OUTLINE)
        c.flat(R((x, y + h - 2, x + 3, y + h - 1)), iris)
        c.flat(R((x, y, x + 1, y + 1)), WHITE)  # glints
        c.dot(x + 3, y + h - 2, WHITE)


ARM_X = (16, 43)  # back and front arm: small, hanging at the body's sides (weapons float in front, never held)


def arm(c: Canvas, x: int, sleeve, hand):
    """A small arm at the body's side, its hand at the end; the back one goes before the body, the front one after."""
    c.part(lambda d, f: d.rounded_rectangle((x, 36, x + 5, 44), 2, f), sleeve)
    c.part(E((x, 42, x + 5, 47)), hand)


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
        c.part(R((x + dx, 45 + dy, x + dx + 5, 54 + dy)), pants)
        xs.append((x + dx, dy))
    for x, dy in xs:  # small rounded shoe with the toe forward, dark sole
        c.part(RR((x - 1, 53 + dy, x + 7, 57 + dy), 2), boots)
        c.flat(R((x, 57 + dy, x + 6, 57 + dy)), SHADOW)
    return xs


# --- characters: each returns (legs canvas, upper canvas), facing right ------

def sleeve_detail(c: Canvas, x: int):
    """Shade's sleeve: a wrist wrap (lit top, shaded lower edge), a crease and a few weave pixels on the shaded side."""
    c.flat(R((x, 40, x + 5, 40)), STEEL_D)
    c.flat(R((x, 41, x + 5, 41)), SHADOW)
    c.flat(L([(x + 2, 37), (x + 2, 38)], 1), SHADOW)  # crease
    c.dot(x + 1, 38, BLUE)  # lit ridge beside it
    c.dot(x + 4, 39, SHADOW)


def flicker(step=None, t=0, zip_=False):
    """Shade, a kunoichi: a choppy jagged bob with a big spiky topknot that swings in the wind, red ribbon tails fluttering from its tie, a steel forehead
    plate, big lashed teal eyes over a mask that peaks at the bridge of her nose; fitted navy shroud, a metal
    breastplate and a red sash. The topknot is too big for the art box: it's drawn above it (CROWNS: flicker_topknot)."""
    low = Canvas()
    for x, dy in legs(low, NAVY, SHADOW, step):
        for y, top, under in ((49, STEEL_D, SHADOW), (51, STEEL_D, SHADOW)):  # shin wraps: lit top edge, shaded lower
            low.flat(R((x, y + dy, x + 5, y + dy)), top)
            low.flat(R((x, y + 1 + dy, x + 5, y + 1 + dy)), under)
        low.flat(L([(x + 1, 46 + dy), (x + 1, 48 + dy)], 1), BLUE)  # lit fold down the thigh's left
        low.flat(L([(x + 3, 47 + dy), (x + 3, 48 + dy)], 1), SHADOW)  # crease
        low.dot(x + 4, 50 + dy, SHADOW)  # weave on the shaded side
    up = Canvas()
    wave = lambda lag, amp: round(HAIR_FLOW[(t - lag) % 4] * amp)
    arm(up, ARM_X[0], NAVY, SKIN)
    sleeve_detail(up, ARM_X[0])
    up.part(RR(BODY, 3), NAVY)  # fitted shroud
    up.part(P([(24, 36), (41, 36), (42, 40), (38, 44), (27, 44), (23, 40)]), STEEL)  # metal breastplate
    up.flat(L([(33, 37), (33, 43)], 1), STEEL_D)  # its centre ridge
    up.flat(L([(32, 38), (32, 40)], 1), WHITE)  # lit side of the ridge
    up.flat(R((26, 38, 28, 38)), WHITE)  # specular, top left
    up.dot(26, 39, WHITE)
    for x in range(27, 40, 2):  # lower half in shade: dithered up into the lit half, solid below
        up.dot(x, 42, STEEL_D)
    up.flat(R((26, 43, 39, 43)), STEEL_D)
    for x, y in ((26, 41), (39, 41)):  # rivets
        up.dot(x, y, SHADOW)
    up.part(R((20, 45, 44, 46)), RED, shade=False, line=False)  # thin sash
    up.flat(R((20, 46, 44, 46)), MAROON)  # shaded lower half
    up.flat(R((21, 45, 24, 45)), ORANGE)  # lit left end
    for x in range(21, 44, 2):  # shroud under the sash, in shade: weave
        up.dot(x, 47, NAVY)
    # shroud folds: a dark crease with a lit ridge beside it, light from the top left
    for x, y0, y1 in ((22, 41, 44), (42, 42, 44)):
        up.flat(L([(x, y0), (x, y1)], 1), SHADOW)
    up.flat(L([(21, 40), (21, 43)], 1), BLUE)
    up.dot(41, 41, BLUE)
    if zip_:  # Grapple Kunai: the front arm reaches forward along the chain (ribbons stream back: flicker_zip)
        up.part(RR((40, 37, 50, 41), 2), NAVY)
        up.flat(L([(45, 38), (45, 40)], 1), STEEL_D)  # forearm wrap
        up.flat(L([(46, 38), (46, 40)], 1), SHADOW)
        up.part(E((48, 37, 53, 42)), SKIN)
    else:
        arm(up, ARM_X[1], NAVY, SKIN)
        sleeve_detail(up, ARM_X[1])
    # ribbon tails: two thin red streamers hanging from the topknot's tie, fluttering behind her head
    for x0, lag in ((18, 1), (21, 2)) if not zip_ else ():
        up.part(L([(x0, 10), (x0 - 7 - wave(lag, 1), 20), (x0 - 12 - wave(lag + 1, 2), 30),
                   (x0 - 13 - wave(lag + 2, 2), 37)], 2), RED, shade=False)
    up.part(RR((14, 8, 20, 13), 2), RED)  # tie round the topknot's base, half hidden behind her hair
    # choppy bob: the head's hair ends in jagged points round the back of her neck
    up.part(lambda d, f: (d.ellipse((16, 5, 50, 36), f), d.polygon(
        [(16, 20), (14, 31), (17, 29), (17, 37), (20, 33), (22, 39), (24, 32), (24, 20)], f)), NAVY)
    up.flat(L([(22, 8), (32, 6)], 1), BLUE)  # crown sheen
    up.flat(L([(16, 22), (16, 28)], 1), BLUE)  # sheen down the back
    up.part(RR(FACE, FACE_R), SKIN)  # face
    up.part(P([(FACE[2] - 1, 14), (51, 16), (52 + wave(2, 0.5), 27), (49, 25), (49 + wave(1, 0.5), 32),
               (FACE[2], 28)]), NAVY, shade=False)  # jagged lock framing her face
    up.part(P([(19, 11), (49, 11), (49, 16), (46, 13), (43, 19), (39, 13), (35, 18), (31, 13), (27, 18), (24, 13),
               (19, 17)]), NAVY, shade=False)  # choppy fringe, over the side lock
    up.part(R((29, 9, 40, 11)), STEEL)  # small forehead plate
    up.flat(R((34, 10, 35, 10)), STEEL_D)  # its engraving
    big_eyes(up, EYES_Y - 1, EYES_X, TEAL_L, h=6)
    if not KO:
        for x in EYES_X:  # lashes flick up and out at the top outer corner
            up.flat(R((x + 3, 19, x + 4, 19)), OUTLINE)
            up.dot(x + 5, 18, OUTLINE)
    # mask: rises from her cheek to a peak at the bridge of her nose, then drops again
    up.part(P([(23, 34), (38, 28), (48, 33), (47, 34), (42, 36), (29, 36), (23, 36)]), SHADOW)
    up.dot(38, 30, NAVY)  # seam under the peak
    up.flat(R((BLUSH[0], 30, BLUSH[0] + 2, 30)), PINK)  # blush above it
    return low, up


def flicker_topknot(t: int, dy: int) -> Canvas:
    """Shade's big spiky topknot: four fat tufts fanning back from her crown, rising above the art box; the whole tuft
    swings in the wind, the tips furthest. A CELL canvas drawn behind the body; `dy` = the head's bob."""
    c = Canvas(CELL)
    wave = lambda lag, amp: round(HAIR_FLOW[(t - lag) % 4] * amp)
    at = lambda pts: [(PAD + x, PAD + UPPER_DY + dy + y) for x, y in pts]  # art px -> cell px
    c.part(P(at([(29, 9), (25 - wave(0, 1), -4), (19 - wave(0, 1), 3), (9 - wave(1, 1.5), -3), (12 - wave(1, 1), 7),
                 (-2 - wave(2, 2), 5), (9 - wave(2, 1), 11), (-3 - wave(3, 2), 15), (10 - wave(2, 1), 16),
                 (2 - wave(3, 1.5), 24), (19, 18)])), NAVY)
    c.flat(L(at([(22, 6), (12 - wave(1, 1.5), 0)]), 1), BLUE)  # its sheen
    c.flat(L(at([(15, 10), (2 - wave(2, 2), 9)]), 1), BLUE)
    return c


ZIP_LEAN = 0.3  # Grapple Kunai pose: px a row leans forward per row above her feet
ZIP_FEET = 57  # art row of her soles: the lean pivots there


def lean(img: Image.Image, pivot: int, k: float) -> Image.Image:
    """Shears whole rows forward (right) the higher they are above `pivot`: a crisp lean, no resampling."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for y in range(min(pivot, img.height)):
        out.paste(img.crop((0, y, img.width, y + 1)), (round((pivot - y) * k), y))
    out.paste(img.crop((0, pivot, img.width, img.height)), (0, pivot))
    return out


ZIP_FRAMES = 8


def flicker_zip(i: int) -> Image.Image:
    """Shade zipping along her chain (period-8 loop, CELL px, facing right): leaning hard forward, arm out along the
    chain, legs trailing, ribbon tails and topknot snapping in the wind, speed streaks and a fading afterimage."""
    low, up = flicker(0, i % 4, zip_=True)
    f = flicker_topknot(i % 4, 0).img
    snap = [0, 1, 2, 1, 0, -1, -2, -1]
    bob = [0, 0, 1, 1, 0, 0, 1, 1][i]  # the whole body judders a px as the chain tugs
    rib = Canvas(CELL)
    y0 = PAD + UPPER_DY + 10
    for k, (x0, dy) in enumerate(((PAD + 18, 0), (PAD + 20, 3))):
        w = lambda lag: snap[(i + 2 * lag + 3 * k) % 8]
        rib.part(L([(x0, y0 + dy), (x0 - 7, y0 + dy + 3 + w(0)), (x0 - 14, y0 + dy + 6 + w(1)),
                    (x0 - 21, y0 + dy + 10 + w(2)), (x0 - 27, y0 + dy + 12 + w(3))], 2), RED, shade=False)
        rib.flat(L([(x0 - 14, y0 + dy + 5 + w(1)), (x0 - 20, y0 + dy + 8 + w(2))], 1), ORANGE)  # lit stretch
    f.alpha_composite(rib.img)
    f.alpha_composite(low.img, (PAD - 2, PAD - 1))  # legs trail a little, toes off the floor
    f.alpha_composite(up.img, (PAD, PAD + UPPER_DY))
    body = lean(f, PAD + ZIP_FEET, ZIP_LEAN)
    if bob:
        body = ImageChops.offset(body, 0, -1)
    out = Image.new("RGBA", body.size, (0, 0, 0, 0))
    # afterimage: two ghost copies of the silhouette, trailing behind, dithered so they read as speed not mass
    sil = body.getchannel("A")
    for n, (dx, col) in enumerate(((-9, STEEL_D), (-17, SHADOW))):
        ghost = Image.new("RGBA", body.size, (0, 0, 0, 0))
        solid = Image.new("RGBA", body.size, col + (255,))
        ghost.paste(solid, (dx, 0), sil)
        gp = ghost.load()
        for y in range(ghost.height):
            for x in range(ghost.width):
                if (x + y + n + i) % 2:
                    gp[x, y] = (0, 0, 0, 0)
        out.alpha_composite(ghost)
    # speed streaks: thin light lines scrolling back past her, a different set each frame
    rng = random.Random(77)
    lines = [(rng.randint(30, 78), rng.randint(0, 7), rng.randint(6, 13), rng.choice((WHITE, STEEL, BLUE)))
             for _ in range(9)]
    sc = Canvas(CELL)
    for n, (y, ph, ln, col) in enumerate(lines):
        x = 4 + (ph * 11 + i * 9 + n * 5) % 36
        sc.flat(L([(x, y), (x + ln, y)], 1), col)
    out.alpha_composite(sc.img)
    out.alpha_composite(body)
    clear = Image.new("RGBA", (3, CELL), (0, 0, 0, 0))
    out.paste(clear, (0, 0))  # keep the streaks and ghosts off the frame edge
    out.paste(clear, (CELL - 3, 0))
    return outline(out)


def sdot(c: Canvas, x: int, y: int, color) -> None:
    """A dot kept one px off the frame edge, so far-flung sparks are clipped, not a crash."""
    if 1 <= x < c.img.width - 1 and 1 <= y < c.img.height - 1:
        c.dot(x, y, color)


def trim(img: Image.Image) -> Image.Image:
    """Clears the outer 2 px ring, so overshooting sparks are clipped and the outline still fits."""
    w, h = img.size
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img.crop((2, 2, w - 2, h - 2)), (2, 2))
    return out


GRAPPLE_SPARK = 32
GRAPPLE_SPARK_FRAMES = 8


def grapple_spark(k: int) -> Image.Image:
    """The kunai biting the wall: an impact star + shock ring, then sparks with trails and stone chips flying
    out and falling, dimming to embers (one-shot, 8 frames)."""
    c = Canvas(GRAPPLE_SPARK)
    m = GRAPPLE_SPARK // 2
    rng = random.Random(5)
    if k == 0:  # flash: a white core with a four-point star
        c.flat(E((m - 4, m - 4, m + 4, m + 4)), WHITE)
        c.flat(L([(m - 11, m), (m + 11, m)], 1), YELLOW)
        c.flat(L([(m, m - 11), (m, m + 11)], 1), YELLOW)
        c.flat(E((m - 2, m - 2, m + 2, m + 2)), WHITE)
    elif k == 1:
        c.flat(E((m - 5, m - 5, m + 5, m + 5)), YELLOW)
        c.flat(E((m - 3, m - 3, m + 3, m + 3)), WHITE)
    if 1 <= k <= 4:  # shock ring: a broken pixel ring expanding and thinning
        r = 4 + 3 * k
        col = [None, WHITE, YELLOW, ORANGE, ORANGE][k]
        for j in range(16):
            if (j + k) % 4 == 3 and k > 2:
                continue
            a = math.tau * j / 16
            sdot(c, round(m + math.cos(a) * r), round(m + math.sin(a) * r), col)
    colour = [WHITE, WHITE, YELLOW, YELLOW, ORANGE, ORANGE, RED, RED][k]
    for j in range(9):  # sparks: bright heads with a trailing tail, gravity bends them down over time
        ang = math.tau * j / 9 + rng.uniform(-0.25, 0.25)
        sp = rng.uniform(0.8, 1.25)
        d0 = (1.5 + 2.1 * k) * sp
        d1 = d0 + (4.5 - 0.4 * k) * sp
        sag = 0.28 * k * k * 0.35
        p0 = (m + math.cos(ang) * d0, m + math.sin(ang) * d0 + sag)
        p1 = (m + math.cos(ang) * d1, m + math.sin(ang) * d1 + sag)
        if k < 7:
            c.flat(L([p0, p1], 1), colour)
            sdot(c, round(p1[0]), round(p1[1]), WHITE if k < 3 else YELLOW if k < 5 else colour)
        elif j % 2:
            sdot(c, round(p1[0]), round(p1[1]), colour)
    if k >= 2:  # stone chips: dark flecks tumbling out and dropping
        for j in range(5):
            ang = math.tau * j / 5 + 0.6 + rng.uniform(-0.3, 0.3)
            d = (3 + 1.9 * k) * rng.uniform(0.7, 1.1)
            x = m + math.cos(ang) * d
            y = m + math.sin(ang) * d + 0.5 * (k - 2) ** 2
            c.flat(R((round(x), round(y), round(x) + (1 if j % 2 else 0), round(y))), STEEL if k < 5 else STEEL_D)
    if 2 <= k <= 6:  # smoke-grey ember dots lingering at the point
        for dx, dy in ((-1, 1), (1, -1), (0, 0)):
            if (k + dx) % 2 == 0:
                sdot(c, m + dx, m + dy, ORANGE if k < 5 else STEEL_D)
    return outline(trim(c.img))


GRAPPLE_THROW = 32
GRAPPLE_THROW_FRAMES = 6


def grapple_throw(k: int) -> Image.Image:
    """The throw at her hand: a snap flash, a ring of air kicked out ahead (to the right), and a few streaks
    sliding forward after the kunai (one-shot, 6 frames)."""
    c = Canvas(GRAPPLE_THROW)
    m = GRAPPLE_THROW // 2
    if k == 0:  # coil: a tight white glint gathering at the fingers
        c.flat(E((m - 2, m - 2, m + 2, m + 2)), WHITE)
        c.flat(L([(m - 6, m), (m + 6, m)], 1), STEEL)
        c.flat(L([(m, m - 6), (m, m + 6)], 1), STEEL)
    elif k == 1:  # snap: flash star
        c.flat(E((m - 4, m - 4, m + 4, m + 4)), YELLOW)
        c.flat(E((m - 2, m - 2, m + 2, m + 2)), WHITE)
        for ang in (0.0, 0.8, -0.8, math.pi):
            c.flat(L([(m + math.cos(ang) * 5, m + math.sin(ang) * 5), (m + math.cos(ang) * 12, m + math.sin(ang) * 12)], 1), WHITE)
    else:
        r = 3 + 2.6 * (k - 1)
        col = [None, None, WHITE, STEEL, STEEL, STEEL_D][k]
        for j in range(14):  # forward-leaning crescent of kicked-out air
            a = -1.25 + 2.5 * j / 13
            if (j + k) % 3 == 0 and k > 3:
                continue
            sdot(c, round(m + 2 + math.cos(a) * r), round(m + math.sin(a) * r * 1.25), col)
        for n, dy in enumerate((-4, 0, 4)):  # streaks sliding forward behind the kunai
            x0 = m - 6 + 3 * k + n
            c.flat(L([(x0, m + dy), (x0 + 5 - k // 2, m + dy)], 1), WHITE if k < 4 else STEEL_D)
        if k == 2:
            c.flat(E((m - 2, m - 2, m + 2, m + 2)), YELLOW)
    return outline(trim(c.img))


GRAPPLE_LAND = 40
GRAPPLE_LAND_FRAMES = 6


def grapple_land(k: int) -> Image.Image:
    """She lands off the zip: a skid of dust kicked forward and a ring of grit, settling (one-shot, 6 frames)."""
    c = Canvas(GRAPPLE_LAND)
    rng = random.Random(9)
    fy = GRAPPLE_LAND - 8  # floor line
    m = GRAPPLE_LAND // 2
    spread = 4 + 3.2 * k
    rise = [2, 4, 5, 5, 4, 3][k]
    for side in (-1, 1):  # two dust banks sliding outward, flat and low
        for j in range(3):
            x = m + side * (spread - 3 * j + rng.uniform(-1, 1))
            h = max(1, rise - j - (1 if k > 3 else 0))
            c.part(E((round(x - 3 + j), fy - h * 2, round(x + 3 - j), fy + 1)), WHITE if k < 4 else STEEL, shade=False)
    if k <= 3:  # skid streaks along the floor
        c.flat(L([(m - 14 - 2 * k, fy), (m - 4, fy)], 1), STEEL_D)
    for j in range(6):  # grit hopping up and falling
        a = math.pi * (0.15 + 0.7 * j / 5)
        d = 4 + 3.5 * k
        x = m + math.cos(a) * d * (1 if j % 2 else -1)
        y = fy - math.sin(a) * d * 0.9 + 0.35 * k * k
        if k < 5 or j % 2:
            sdot(c, round(x), round(y), STEEL if k < 4 else STEEL_D)
    return outline(trim(c.img))


def grapple_chain(k: int) -> Image.Image:
    """One chain link of an 8-frame cycle: it spins from flat (an open oval) through edge-on and back, while a
    glint runs along it, so the chain shimmers as it's paid out and reeled in."""
    c = Canvas(10)
    turn = k % 4  # 0 flat, 1 three-quarter, 2 edge-on, 3 three-quarter (the back face)
    if turn == 0:
        c.part(E((2, 2, 7, 7)), STEEL, shade=False)
        c.flat(E((3, 4, 6, 5)), OUTLINE)
    elif turn in (1, 3):
        c.part(E((2, 3, 7, 6)), STEEL if turn == 1 else STEEL_D, shade=False)
        c.flat(R((4, 4, 5, 5)), OUTLINE)
    else:
        c.part(R((2, 4, 7, 5)), STEEL_D, shade=False)
    if k < 4:  # glint on the half of the cycle where this link catches the light
        c.dot(3, 3 if turn != 2 else 4, WHITE)
    else:
        c.dot(6, 5 if turn != 2 else 4, WHITE)
    return outline(c.img)


def warden(step=None, t=0):
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
    s = SWAY[t % 4]
    up.part(P([(24, 5), (10, 12 + s), (14, 14 + s), (24, 10)]), RED)  # plume tail sways
    up.part(E((21, 2, 37, 12)), RED)  # plume
    up.part(E((16, 5, 48, 37)), STEEL)  # helmet
    up.part(R((31, 6, 33, 18)), STEEL, line=False)  # crest ridge
    up.part(R((17, 30, 47, 35)), STEEL_D)  # helmet rim
    up.flat(RR((22, 19, 47, 27), 3), OUTLINE)  # visor
    for x in (31, 41):  # round glowing eyes
        if KO:
            x_eye(up, x, 21, TEAL_L)
            continue
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
    if t % 4 == 0:  # gem glint
        up.flat(P([(48, 41), (49, 44), (48, 47), (47, 44)]), WHITE)
    return low, up


def twinshot(step=None, t=0):
    """Dual wield: gunslinger with a feathered wide hat, poncho, bandolier and two holsters."""
    low = Canvas()
    for x, dy in legs(low, BLUE, BROWN, step):
        low.dot(x - 3, 55 + dy, YELLOW)  # spurs
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
    up.part(E(HEAD), BROWN)  # hair under the hat: the head sits centred on the body, the face turned right
    up.part(RR(FACE, FACE_R), SKIN)  # face
    big_eyes(up, EYES_Y, EYES_X, BLUE)
    up.flat(R((EYES_X[0], 20, EYES_X[0] + 3, 20)), BROWN)  # brows
    up.flat(R((EYES_X[1], 20, EYES_X[1] + 3, 20)), BROWN)
    face(up, BLUSH)
    up.part(RR((FACE[0], 31, FACE[2], FACE[3]), 2), RED)  # bandana
    s = SWAY[t % 4]
    up.part(P([(21, 33), (14, 37 + s), (16, 40 + s), (22, 36)]), RED)  # bandana tail flutters
    up.part(E((5, 13, 59, 23)), BROWN)  # hat brim
    up.part(RR((18, 2, 46, 18), 6), BROWN)  # crown
    up.flat(R((31, 3, 33, 7)), MAROON)  # crown dent
    up.part(R((18, 11, 46, 14)), YELLOW, line=False)  # band
    up.part(P([(40, 12), (53 + s, 2), (56 + s, 4), (44, 13)]), TEAL)  # feather sways
    return low, up


def flame(c: Canvas, x0: int, x1: int, base: int, height: int, t: int, tongues: int = 5, lean: float = 0.0,
          back: float = 0.0, line: bool = True, rim=RED):
    """A flickering flame: tongues of uneven height (they shift each tick), red outside, orange,
    then a yellow core. `lean` sweeps the tips backwards (left) by that fraction of their height;
    `back` makes the rear tongues up to that much taller, so it streams off behind."""
    def shape(k, inset):
        w = (x1 - x0) - 2 * inset
        pts = [(x0 + inset, base)]
        for i in range(tongues):
            hx = x0 + inset + w * (i + 0.5) / tongues
            hh = (height - inset * 2) * (0.6 + 0.4 * (((i * 7 + t) % 4) in (1, 2))) * (1.15 if i == tongues // 2 else 1)
            hh *= 1 + back * (1 - i / max(1, tongues - 1))
            pts += [(hx - w / tongues * 0.45 - lean * hh * 0.5, base - hh * 0.55),
                    (hx + SWAY[(t + i) % 4] - lean * hh, base - hh),
                    (hx + w / tongues * 0.45 - lean * hh * 0.45, base - hh * 0.5)]
        return pts + [(x1 - inset, base)]
    c.part(P(shape(t, 0)), rim, shade=False, line=line)
    c.part(P(shape(t, 3)), ORANGE, shade=False, line=False)
    c.part(P(shape(t, 6)), YELLOW, shade=False, line=False)


def flame_tongue(c: Canvas, root, ctrl, tip, phase, side=1, wide=6.0, mid=32):
    """A flowing tongue of flame (Flint's style) along a curve root -> ctrl -> tip (a quadratic bezier), mirrored about
    x = `mid` for side -1; a wave rolls up it with `phase`, and it tapers to a flicking tip. Red rim, orange, yellow core."""
    for col, reach, w in ((RED, 1.0, wide), (ORANGE, 0.78, wide * 0.6), (YELLOW, 0.5, wide / 3)):
        edge_a, edge_b = [], []
        for i in range(9):
            v = i / 8 * reach
            cx = (1 - v) ** 2 * root[0] + 2 * (1 - v) * v * ctrl[0] + v * v * tip[0]
            cy = (1 - v) ** 2 * root[1] + 2 * (1 - v) * v * ctrl[1] + v * v * tip[1]
            gx = 2 * (1 - v) * (ctrl[0] - root[0]) + 2 * v * (tip[0] - ctrl[0])
            gy = 2 * (1 - v) * (ctrl[1] - root[1]) + 2 * v * (tip[1] - ctrl[1])
            g = math.hypot(gx, gy) or 1.0
            nx, ny = -gy / g, gx / g  # across the tongue
            bend = math.sin(v * math.pi * 2 - phase) * wide * 0.37 * v  # the sway grows towards the tip
            cx, cy = cx + nx * bend, cy + ny * bend
            half = w * (1 - i / 8) ** 0.6 + 0.3
            edge_a.append((mid + side * (cx + nx * half - mid), cy + ny * half))
            edge_b.append((mid + side * (cx - nx * half - mid), cy - ny * half))
        c.part(P(edge_a + edge_b[::-1]), col, shade=False, line=col == RED)


HAIR_FLOW = [0, 1, 2, 1]  # px a lock blows back per tick (period 4, so idle and walk loop)


def sakura(step=None, t=0):
    """Blossom: a cool-eyed girl in a white kimono with wide sleeves, red obi tied in a bow at the back; pink hair
    parted in the middle, curtains framing her face, and a long ponytail tied with a cherry blossom that sways
    behind her; geta on her feet."""
    low = Canvas()
    for x, dy in legs(low, WHITE, BROWN, step):  # white tabi socks, wooden geta
        low.flat(R((x + 1, 53 + dy, x + 4, 53 + dy)), RED)  # geta thong
    up = Canvas()
    s = SWAY[t % 4]
    # Wind: a wave runs down hair and cloth (each point further from where it's held lags a step behind and swings
    # wider); loops every 4 ticks for idle and walk.
    wave = lambda lag, amp: round(HAIR_FLOW[(t - lag) % 4] * amp)
    up.part(P([(22, 39), (10 - wave(1, 1), 34 + s), (9 - wave(2, 1), 41 + s), (15, 44 + s), (22, 43)]), RED)  # obi bow
    sleeve = lambda x0, x1: P([(x0 + 1, 34), (x1 - 1, 34), (x1, 39), (x1 - wave(2, 1), 45), (x0 - wave(3, 1), 45),
                               (x0 - wave(2, 1), 39)])  # small kimono sleeve, its hem swinging back
    up.part(E((ARM_X[0] + 1, 43, ARM_X[0] + 5, 47)), SKIN)  # back hand, peeking out of the sleeve
    up.part(sleeve(ARM_X[0] - 1, ARM_X[0] + 6), WHITE)  # back sleeve
    up.flat(L([(ARM_X[0] - wave(3, 1), 44), (ARM_X[0] + 5 - wave(2, 1), 44)], 1), PINK_L)  # its hem
    up.part(RR(BODY, 3), WHITE)  # kimono
    for x in range(BODY[0] + 2, BODY[2] - 1, 4):  # hem ripples, the folds rolling back
        up.dot(x + (t % 4), BODY[3] - 1, STEEL)
    up.flat(L([(26, 33), (32, 40)], 1), RED)  # crossed collar
    up.flat(L([(38, 33), (32, 40)], 1), RED)
    for x, y in ((24, 36), (40, 37), (27, 46), (37, 47)):  # blossom pattern
        up.flat(R((x, y, x + 1, y + 1)), PINK_L)
    up.part(R((20, 40, 44, 44)), RED, line=False)  # obi
    up.flat(R((20, 42, 44, 42)), PINK)  # obi cord
    up.part(E((ARM_X[1] + 1, 43, ARM_X[1] + 5, 47)), SKIN)  # front hand
    up.part(sleeve(ARM_X[1] - 1, ARM_X[1] + 6), WHITE)  # front sleeve
    up.flat(L([(ARM_X[1] - wave(3, 1), 44), (ARM_X[1] + 5 - wave(2, 1), 44)], 1), PINK_L)
    # long ponytail from a high tie at the back of her head, flowing in the wind
    up.part(P([(19, 9), (12, 12), (8 - wave(0, 0.5), 20), (6 - wave(1, 1), 30), (6 - wave(2, 1.5), 40),
               (9 - wave(3, 2), 46), (12 - wave(2, 1.5), 38), (15 - wave(1, 1), 28), (19, 17)]), PINK)
    up.flat(L([(13, 15), (10 - wave(1, 0.5), 24), (9 - wave(2, 1), 36)], 1), PINK_L)  # its sheen
    up.part(E((16, 5, 48, 37)), PINK)  # hair
    up.part(RR(FACE, FACE_R), SKIN)  # face
    # middle part: two curtains and two long side locks, mirrored about the face's centre line
    mid = (FACE[0] + FACE[2]) // 2
    curtain = [(mid, 10), (mid + 9, 9), (mid + 13, 14), (mid + 14, 23), (mid + 12, 23), (mid + 11, 19), (mid + 6, 15),
               (mid + 1, 14)]  # sweeps off the forehead
    drift = wave(2, 0.5)  # the side locks' ends drift with the breeze
    lock = [(mid + 10, 16), (mid + 15, 16), (mid + 16 - drift, 38), (mid + 12 - drift, 36)]
    for side in (1, -1):  # each curtain and its lock as one shape, so no line where the lock meets the curtain
        c_pts, l_pts = ([(mid + side * (x - mid), y) for x, y in pts] for pts in (curtain, lock))
        up.part(lambda d, f, c_pts=c_pts, l_pts=l_pts: (d.polygon(c_pts, f), d.polygon(l_pts, f)), PINK)  # shaded like the ponytail
        up.flat(L([(mid + side * 6, 11), (mid + side * 11, 15), (mid + side * 13, 24 - drift * side)], 1), PINK_L)  # sheen
    up.flat(L([(mid, 8), (mid, 13)], 1), MAROON)  # the parting
    up.part(lambda d, f: [d.ellipse((x - 2, y - 2, x + 2, y + 2), f) for x, y in
                          ((19, 4), (22, 6), (21, 9), (17, 9), (16, 6))], PINK_L)  # cherry blossom tying the ponytail
    up.dot(19, 7, YELLOW)
    big_eyes(up, EYES_Y, EYES_X, PINK, h=6)
    if not KO:
        for x, out in ((29, -1), (39, 4)):  # calm lids, lashes flicking out at the outer corners
            up.flat(R((x, 21, x + 3, 21)), OUTLINE)
            up.dot(x + out, 21, OUTLINE)
            up.dot(x + out + (1 if out > 0 else -1), 20, OUTLINE)
    up.flat(R((BLUSH[0], BLUSH[2], BLUSH[0] + 2, BLUSH[2])), PINK)  # pink blush
    up.flat(R((BLUSH[1], BLUSH[2], BLUSH[1] + 1, BLUSH[2])), PINK)
    up.flat(R((MOUTH[0], MOUTH[1], MOUTH[0] + 1, MOUTH[1])), MAROON)  # small mouth
    return low, up


def flint(step=None, t=0, heat=0.0):
    """Fire: a little fire elemental with a molten face, a scorched dark suit
    burning up from its hem (heat burns it off) over a glowing molten body and legs with veins and an ember heart, flames curling up him and wisps breaking off, and fists of fire. His flaming hair is drawn above the
    art box (CROWNS: flint_crown). `heat` 0..1 stokes him into his Inferno form:
    bigger hand flames, white-hot cracks, flames off his shoulders and blazing eyes trailing fire."""
    hot = heat >= 0.5
    crack = (ORANGE, YELLOW)[t % 2] if not hot else (YELLOW, WHITE)[t % 2]  # cracks pulse every tick
    low = Canvas()
    if heat > 0:  # a bonfire roaring up behind him (on the legs' canvas, so behind everything): jagged tongues all
        # licking upwards, flickering every tick, rising out of a rounded mass of fire; grows with heat
        rx, ry = 25 * heat, 9 * heat
        low.part(E((32 - rx, 49 - ry, 32 + rx, 49 + ry)), RED, shade=False, line=False)
        flame(low, 7, 57, 50, round(34 * heat), t, tongues=7, line=False)
        flame(low, 14, 50, 50, round(46 * heat), t + 1, tongues=5, line=False)
    for k, (x, dy) in enumerate(legs(low, ORANGE if hot else RED, RED, step)):  # molten legs and feet, on fire too
        low.flat(R((x + 2, 46 + dy, x + 3, 52 + dy)), YELLOW if hot else ORANGE)  # glowing inside
        low.flat(R((x + 2, 47 + dy, x + 2, 51 + dy)), crack)  # a vein of fire down each
        low.flat(R((x + 1, 54 + dy, x + 5, 55 + dy)), YELLOW if hot else ORANGE)  # hot toes
        for j, fx in enumerate((x - 2, x + 7)):  # little flames licking up beside each foot, flickering out of step
            h = 4 + (t + k + j) % 3 + round(heat * 3)
            low.part(P([(fx - 2, 57 + dy), (fx + SWAY[(t + j + k) % 4], 57 + dy - h), (fx + 2, 57 + dy)]), RED,
                     shade=False, line=False)
            low.part(P([(fx - 1, 57 + dy), (fx, 58 + dy - h + 1), (fx + 1, 57 + dy)]), YELLOW if h > 5 else ORANGE,
                     shade=False, line=False)
    up = Canvas()

    def fist(cx, k):  # a ball of fire for a hand, its flame licking up and flickering every tick
        hh = 7 + round(heat * 6) + (t + k) % 2
        flame(up, cx - 4, cx + 4, 46, hh, t + k, tongues=2)
        up.part(E((cx - 3, 41, cx + 3, 47)), ORANGE)
        up.flat(E((cx - 1, 43, cx + 1, 45)), YELLOW if not hot else WHITE)

    grow = lambda root, p: [r + (q - r) * heat for r, q in zip(root, p)]
    fist(17, 1)  # back hand, behind the body
    # glowing molten body under his suit: a hotter core inside, veins of fire pulsing every tick
    up.part(RR(BODY, 3), ORANGE if hot else RED)
    up.flat(RR((25, 37, 39, 45), 3) if hot else RR((23, 36, 41, 46), 3), YELLOW if hot else ORANGE)
    for k, pts in enumerate((((25, 35), (27, 39), (25, 43), (27, 47)), ((39, 34), (37, 38), (40, 42), (38, 46)),
                             ((32, 44), (31, 47)), ((22, 38), (24, 41)))):
        up.flat(L(pts, 1), WHITE if hot else (YELLOW, ORANGE)[(t + k) % 2] if k > 1 else YELLOW)  # veins, flickering
    up.flat(P([(32, 37), (35, 40), (32, 43), (29, 40)]), YELLOW)  # ember heart
    if t % 2 == 0 or hot:
        up.flat(R((31, 39, 33, 41)) if hot else R((32, 40, 32, 40)), WHITE)  # heartbeat
    # his dark suit, already scorched up from a ragged hem; heat burns it away until Inferno leaves nothing. Burnt
    # from the bottom up through blotchy char (FLINT_BURN), the edge glowing like embers, charred just inside it.
    suit = Canvas()
    suit.part(RR(BODY, 3), SHADOW)
    for side in (1, -1):  # lapels, open at the neck over his glowing chest
        suit.part(P([(32 + side * x, y) for x, y in ((4, 33), (1, 40), (7, 37), (8, 33))]), NAVY, shade=False)
    suit.flat(P([(29, 33), (32, 39), (35, 33)]), OUTLINE)  # the open collar (cut out below)
    for y in (42, 45):
        suit.dot(32, y, STEEL)  # buttons
    burn = 0.1 + heat * 1.05
    sp = suit.img.load()
    for y in range(BODY[1], BODY[3] + 1):
        for x in range(BODY[0], BODY[2] + 1):
            if sp[x, y][:3] == OUTLINE:  # the collar: the chest shows through
                sp[x, y] = (0, 0, 0, 0)
                continue
            left = flint_burn(x, y) - burn  # how far from burning through
            if sp[x, y][3] and left < 0:
                sp[x, y] = (0, 0, 0, 0)
            elif sp[x, y][3] and left < 0.07:
                sp[x, y] = (YELLOW if (x + y + t) % 3 == 0 else ORANGE) + (255,)  # embers along the burnt edge
            elif sp[x, y][3] and left < 0.13:
                sp[x, y] = MAROON + (255,)  # charred
    up.img.alpha_composite(suit.img)
    reach = 0.3 + 0.7 * heat  # flames curling up over the front of him as the suit burns, taller when hot
    for k, (root, ctrl, tip) in enumerate((((25, 48), (20, 42), (26, 33)), ((39, 48), (44, 43), (38, 35))) if heat else ()):
        flame_tongue(up, root, [r + (q - r) * reach for r, q in zip(root, ctrl)], [r + (q - r) * reach for r, q in zip(root, tip)],
               (t + k * 2) * math.pi / 2, wide=2.5 + heat)
    fist(47, 3)  # front hand
    # wisps of flame breaking off him: each rises and shrinks away over 4 ticks, out of step (more when hot)
    # wisps of flame breaking off his edges: each drifts up and out and shrinks away over 4 ticks, out of step
    # (more when hot)
    spots = [(21, 41, -1), (43, 39, 1), (22, 47, -1), (42, 46, 1)] + ([(20, 35, -1), (44, 34, 1)] if heat else [])
    for k, (wx, wy, out) in enumerate(spots):
        phase = (t + k * 2 + (k > 3)) % 4
        r = (3, 2, 1, 0)[phase]
        if r:
            wx, wy = wx + out * 2 * phase, wy - 3 * phase
            up.part(P([(wx - r, wy), (wx + SWAY[(t + k) % 4], wy - 2 * r - 1), (wx + r, wy), (wx, wy + r)]),
                    (YELLOW, ORANGE, RED)[phase], shade=False, line=False)
    # molten head, face turned right: a squared-off top (flat crown, tight corners) over a rounded jaw
    mid_y = (HEAD[1] + HEAD[3]) // 2
    up.part(lambda d, f: (d.rounded_rectangle((HEAD[0], HEAD[1], HEAD[2], mid_y + 2), 4, f), d.ellipse(HEAD, f),
                          d.rounded_rectangle(FACE, FACE_R, f)), ORANGE)
    up.part(E((MOUTH[0] - 6, 26, MOUTH[0] + 6, 34)), YELLOW, line=False)  # hot glow around the mouth
    if hot and not KO:  # blazing eyes: white-hot with flame trailing back off them
        for x in EYES_X:
            up.flat(R((x, EYES_Y, x + 3, EYES_Y + 5)), YELLOW)  # same eye shape, lit from inside
            up.flat(R((x + 1, EYES_Y + 1, x + 2, EYES_Y + 4)), WHITE)
            up.flat(L([(x + 1, EYES_Y - 1), (x - 1, EYES_Y - 3 - (t % 2))], 1), YELLOW)  # flame flicking up off it
    else:
        big_eyes(up, EYES_Y, EYES_X, YELLOW)
    up.flat(R((BLUSH[0], BLUSH[2], BLUSH[0] + 1, BLUSH[2])), RED)  # blush
    up.flat(R((BLUSH[1], BLUSH[2], BLUSH[1] + 1, BLUSH[2])), RED)
    up.flat(R((MOUTH[0] - 1, MOUTH[1] + 1, MOUTH[0] + 1, MOUTH[1] + 1)), MAROON)  # little grin
    # Tongues licking up from the forehead; orange rim so no red stripe runs across the face.
    mid = (HEAD[0] + HEAD[2]) // 2
    flame(up, mid - 13, mid + 13, FACE[1] + 5, 8, t + 2, tongues=5, line=False, rim=ORANGE)
    return low, up


def flint_burn(x: int, y: int) -> float:
    """How long Flint's suit holds out at art px (x, y), 0..1: the bottom goes first, through blotchy char (a fixed
    hash over 2 px blocks, so it's the same every frame)."""
    up_the_body = 1 - (y - BODY[1]) / (BODY[3] - BODY[1])
    blotch = ((x // 2 * 7919) ^ (y // 2 * 104729)) % 101 / 100
    return 0.65 * up_the_body + 0.35 * blotch


def flint_crown(t: int, dy: int, heat: float = 0.0) -> Canvas:
    """Flint's head on fire: an upright flame rising off his head, its tongues flickering every tick, taller and
    leaping with `heat`. A CELL canvas drawn behind the body before outlining (the face covers its base);
    `dy` = the head's bob."""
    c = Canvas(CELL)
    top = PAD + UPPER_DY + dy  # cell y of the art box's top, moving with the head
    mid = PAD + (HEAD[0] + HEAD[2]) // 2  # centred on the head
    base = top + FACE[1] + 9
    hw = 14  # as wide as the squared head's flat top, so the tufts sit along it like a crown
    n = 6 + round(heat * 2)
    sway = (-0.14, 0.1, 0.14, -0.1)  # the whole crown leans left and right as it flickers
    flame(c, mid - hw, mid + hw, base, 27 + round(heat * 3), t, tongues=n, lean=sway[t % 4])  # tall outer tufts of uneven height
    flame(c, mid - hw + 3, mid + hw - 3, base, 19 + round(heat * 6), t + 2, tongues=n - 2, line=False, rim=ORANGE, lean=-sway[t % 4])  # inner tufts, out of step, leaning the other way
    for k in range(3):  # tips breaking off into small flame wisps that rise and shrink over 4 ticks
        ph = (t + k * 2) % 4
        wx = mid - hw + 4 + k * (2 * hw - 8) // 2 + SWAY[(t + k) % 4] * 2
        wy = top + 4 - 3 * ph - round(heat * 2)
        r = (3, 2, 1, 0)[ph]
        if r:
            c.part(P([(wx - r, wy + r), (wx + SWAY[(t + k) % 4], wy - r - 1), (wx + r, wy + r), (wx, wy + r + 1)]),
                   (YELLOW, ORANGE, RED)[min(ph, 2)], shade=False, line=False)
    for k in range(3 + round(heat * 2)):  # tiny embers lifting off the tufts and dying out (period 4)
        ph = (t + k) % 4
        ex = mid - hw + 3 + (k * 11 + 5) % (2 * hw - 5) + SWAY[(t + k) % 4]
        c.dot(ex, top + 6 - 4 * ph - (k % 2) * 3 - round(heat * 3), (YELLOW, ORANGE, RED, MAROON)[ph])
    return c


def flint_embers(i: int, heat: float = 0.0) -> Canvas:
    """Sparks rising off Flint and fading out (period 4), twice as many in his Inferno form."""
    c = Canvas()
    for k, (x, y) in enumerate(((12, 30), (52, 26), (10, 44), (54, 40))):
        phase = (i + k) % 4
        c.dot(x + SWAY[(i + k) % 4], y - 3 * phase, (YELLOW, ORANGE, RED, MAROON)[phase])
    if heat > 0:  # more sparks thrown off the fire around him
        for k, (x, y) in enumerate(((8, 26), (56, 22), (16, 16), (48, 12))):
            phase = (i + k + 2) % 4
            c.dot(x - SWAY[(i + k) % 4], y - 3 * phase, (WHITE, YELLOW, ORANGE, RED)[phase])
    return c


def flint_inferno(step=None, t=0):
    return flint(step, t, heat=1.0)


INFERNO_MORPH_FRAMES = 24


def flint_inferno_morph() -> Image.Image:
    """Flint stoking up: his idle frame with heat rising 0 -> 1 over 24 frames (no growth: form_scale 1), flames licking up
    round him more and more and a spray of fire sparks building to a burst as he flares into Inferno."""
    out = []
    n = INFERNO_MORPH_FRAMES
    for k in range(n):
        h = k / (n - 1)
        low, up = flint(None, k % 4, heat=h)
        f = flint_inferno_aura(k % 4, h * h).img
        f.alpha_composite(low.img)
        f.alpha_composite(up.img, (0, UPPER_DY))
        cell_img = flint_crown(k % 4, 0, h).img
        cell_img.alpha_composite(f, (PAD, PAD))
        img = outline(cell_img)
        ov = Canvas(CELL)
        cx, cy = CELL // 2, PAD + 40
        spark_cloud(ov, 29, int(10 + 30 * h), k, lambda r: (cx + r.uniform(-12, 12), cy + r.uniform(-4, 16)), (0.8, 2.6),
                    (5, 9), n, angle=(-2.6, -0.55), g=0.06, trail=3, up=0.3 + h)
        if k >= n - 6:  # the flare: a burst flying out in every direction as he finishes
            spark_cloud(ov, 31, 36, k - (n - 6), (cx, cy), (1.5, 4.5), (4, 8), 3, g=0.1, trail=3)
        img.alpha_composite(ov.img)
        out.append(img)
    return strip(out)


def wukong(step=None, t=0, swing=False):
    """Dash: monkey king with a golden circlet, pheasant feathers and a lopsided cloud collar.
    `swing` (Vine Swing poses): tail curled up tight, no front arm (wukong_swing_frame raises it to the vine)."""
    low = Canvas()
    for x, dy in legs(low, RED, BROWN, step):
        low.flat(R((x, 50 + dy, x + 6, 50 + dy)), YELLOW)  # leg wraps
    up = Canvas()
    s = SWAY[t % 4]
    if swing:  # curled into a spiral so it doesn't snag
        up.part(L([(21, 44), (13, 47), (7, 43), (7, 36), (12, 33), (16, 36), (15, 41), (11, 41)], 3), BROWN)
    else:
        up.part(L([(21, 44), (11, 45), (6, 40), (7, 33), (11 + s, 31)], 3), BROWN)  # curly tail, tip wags
    arm(up, ARM_X[0], YELLOW, SKIN)
    up.part(RR(BODY, 3), YELLOW)  # golden armour
    up.flat(R((31, 36, 33, 44)), ORANGE)
    up.part(R((20, 44, 44, 46)), RED, line=False)  # sash
    up.part(P([(22, 45), (17, 52), (21, 52), (25, 46)]), RED)  # sash tail
    if not swing:
        arm(up, ARM_X[1], YELLOW, SKIN)
    up.part(L([(25, 10), (16, 4), (6, 6 + s)], 2), RED, shade=False)  # pheasant feathers sway
    up.part(L([(29, 9), (24, 3), (14 + s, 2)], 2), RED, shade=False)
    up.part(E((11, 17, 21, 28)), BROWN)  # ear
    up.flat(E((14, 20, 18, 25)), SKIN_D)
    for x in (24, 31, 38):
        up.part(P([(x, 9), (x + 3, 4), (x + 6, 9)]), BROWN)  # fur tufts
    up.part(E((15, 6, 49, 38)), BROWN)  # head fur
    up.part(RR(FACE, FACE_R), SKIN)  # human face
    up.part(P([(23, 16), (47, 16), (47, 18), (43, 19), (39, 17), (35, 19), (30, 17), (26, 19), (23, 18)]), BROWN,
            shade=False)  # spiky fringe
    up.part(R((17, 13, 47, 16)), YELLOW)  # golden circlet
    up.dot(32, 14, RED)
    up.dot(33, 14, RED)
    big_eyes(up, EYES_Y, EYES_X, YELLOW)
    face(up, BLUSH, MOUTH)
    # Lopsided on purpose: billows up over the back shoulder, just a wisp at the front.
    collar = ((11, 31, 3), (15, 35, 5), (21, 38, 4), (26, 39, 3), (43, 38, 3), (47, 36, 4))
    up.part(lambda d, f: [d.ellipse((x - r, y - r, x + r, y + r), f) for x, y, r in collar], WHITE,
            line=False)  # fluffy cloud collar on the shoulders
    return low, up


## Great Ape arm poses: "walk" = knuckle-walking, fists planted at his sides (idle / walk, like a gorilla); "raise" =
## both fists up beside his head; "smash" = both slammed into the ground in front, where the slam lands (the attack).
## Per pose: (shoulder, elbow, wrist) per arm, then (x, top, thumb dx) per fist. Back arm / fist first.
APE_POSES = {"walk": ((((15, 26), (13, 36), (17, 44)), ((49, 26), (51, 36), (47, 44))), ((11, 45, -2), (41, 45, 9))),
             "raise": ((((15, 26), (9, 18), (10, 13)), ((49, 26), (55, 18), (54, 13))), ((4, 2, -2), (48, 2, 9))),
             "smash": ((((15, 26), (28, 36), (40, 44)), ((49, 26), (54, 36), (54, 44))), ((35, 46, -2), (48, 46, 9)))}


## Wukong's golden armour breaking in the morph: (crack, chunk that then falls away), in the armour's 24x15 px.
APE_ARMOUR_BREAKS = [([(6, 0), (8, 4), (6, 7), (9, 10)], [(6, 0), (8, 4), (6, 7), (2, 6), (1, 1)]),
                     ([(18, 2), (16, 5), (19, 8)], [(18, 2), (16, 5), (19, 8), (23, 7), (23, 2)]),
                     ([(2, 9), (5, 11), (4, 15)], [(2, 9), (5, 11), (4, 15), (0, 15), (0, 10)]),
                     ([(12, 6), (14, 10), (12, 14)], [(12, 6), (14, 10), (12, 14), (9, 12), (9, 8)])]

## The Great Ape's circlet: Wukong's, tilted askew and cracked; the morph cracks it one line at a time.
APE_CIRCLET = [(23, 8), (47, 4), (47, 9), (23, 13)]
APE_CRACKS = [[(36, 5), (34, 8), (37, 9), (35, 12)], [(29, 7), (30, 9), (28, 11)], [(42, 5), (43, 7), (41, 9)],
              [(26, 8), (25, 10)]]


def wukong_ape(step=None, t=0, pose=None):
    """Great Ape (Wukong's special): an angry, dark-red brute. Hunched, broad-shouldered, long arms
    with big fists, glowing red eyes under a heavy scowl, golden circlet and bracers, storm clouds.
    A transformation form, drawn bigger in game (SkillData.form_scale). `pose` (attack frames): (from, to, mix)
    between two APE_POSES; None = knuckle-walking."""
    low = Canvas()
    air = pose is not None and pose[0] == "raise"  # mid-leap: knees tucked up under him
    land = pose is not None and pose[:2] == ("smash", "smash")  # landed: feet planted wide
    stance = ((1, -5), (-1, -5)) if air else ((-3, 0), (3, 0)) if land else None
    if land and pose is not None and step is None:
        for x, y, r in ((5, 53, 4), (11, 57, 4), (18, 59, 3), (31, 59, 3), (59, 56, 3)):  # dust kicked up by the landing
            low.part(E((x - r, y - r, x + r, y + r)), STEEL, line=False)
    for x, (dx, dy) in zip((21, 35), stance or (WALK_LEGS[step] if step is not None else ((0, 0), (0, 0)))):
        x += dx  # thick, slightly bowed ape legs with broad flat feet, on the same stride as everyone
        low.part(P([(x, 44 + dy), (x + 8, 44 + dy), (x + 9, 54 + dy), (x - 1, 54 + dy)]), MAROON)
        low.part(E((x - 5, 54 + dy, x, 58 + dy)), BROWN)  # big toe splayed out to the side
        low.part(RR((x - 2, 53 + dy, x + 10, 58 + dy), 2), BROWN)  # broad leathery foot
        for tx in (x + 4, x + 7):
            low.flat(R((tx, 56 + dy, tx, 58 + dy)), OUTLINE)  # toe creases
        low.flat(R((x - 1, 58 + dy, x + 9, 58 + dy)), SHADOW)
    up = Canvas()
    s = SWAY[t % 4]
    up.part(L([(14, 40), (6, 38), (4, 31), (8, 27 + s)], 3), MAROON)  # tail
    up.part(E((10, 14, 54, 45)), MAROON)  # hunched back and shoulders
    up.part(E((22, 26, 44, 43)), BROWN)  # chest
    for x, y in ((14, 18), (20, 13), (27, 11)):
        up.part(P([(x, y + 5), (x + 3, y), (x + 6, y + 5)]), MAROON)  # bristling back fur
    a, b, k = pose or ("walk", "walk", 0)
    (arms_a, fists_a), (arms_b, fists_b) = APE_POSES[a], APE_POSES[b]
    mix = lambda u, v: round(u + (v - u) * k)
    arms = [[(mix(p[0], q[0]), mix(p[1], q[1])) for p, q in zip(u, v)] for u, v in zip(arms_a, arms_b)]
    fists = [(mix(u[0], v[0]), mix(u[1], v[1]), u[2]) for u, v in zip(fists_a, fists_b)]
    if pose is not None:
        s = 0  # attack poses don't bob
    for (sx, sy), (ex, ey), (wx, wy) in arms:  # thick, muscular arms: shoulder, bicep and forearm bulge out
        up.part(L([(sx, sy), (ex, ey), (wx, wy)], 9), MAROON)
        up.part(E((sx - 6, sy - 6, sx + 6, sy + 6)), MAROON)  # deltoid
        bx, by = (sx + ex) // 2, (sy + ey) // 2
        up.part(E((bx - 6, by - 5, bx + 6, by + 5)), MAROON)  # bicep
        fx, fy = (ex * 2 + wx) // 3, (ey * 2 + wy) // 3
        up.part(E((fx - 5, fy - 4, fx + 5, fy + 4)), MAROON)  # forearm
    for i, (x, y, thumb) in enumerate(fists):  # clenched fists, knuckles down; they rock in turn with the stride
        s = -s if i else s
        by = y + 12 if y < 26 else y - 4  # golden bracers on the forearm: below a raised fist
        up.part(R((x + 2, by, x + 10, by + 3)), YELLOW)
        up.part(RR((x, y + s, x + 12, y + 11 + s), 3), MAROON)
        up.part(E((x + thumb, y + 1 + s, x + thumb + 5, y + 6 + s)), MAROON)  # thumb wrapped over the fingers
        up.flat(RR((x + 1, y + 6 + s, x + 11, y + 11 + s), 1), BROWN)  # curled fingers
        for kx in (x + 4, x + 7):
            up.flat(R((kx, y + 6 + s, kx, y + 11 + s)), OUTLINE)  # knuckle splits
        up.flat(R((x + 1, y + 6 + s, x + 11, y + 6 + s)), OUTLINE)
    up.part(E((24, 3, 50, 29)), MAROON)  # head, pushed forward
    up.part(E((28, 11, 50, 29)), BROWN)  # dark face
    up.part(P(APE_CIRCLET), YELLOW)  # Wukong's golden circlet (same shading and gem), knocked askew
    up.flat(R((35, 7, 36, 7)), RED)  # gem
    for crack in APE_CRACKS:
        up.flat(L(crack, 1), OUTLINE)
    up.flat(P([(43, 4), (47, 4), (47, 6)]), OUTLINE)  # chipped corner
    for x in (32, 42):  # glowing red eyes
        if KO:
            x_eye(up, x, 14, RED)
            continue
        up.flat(R((x, 14, x + 3, 17)), OUTLINE)
        up.flat(R((x, 15, x + 3, 16)), RED)
        up.dot(x + 1, 15, ORANGE)
    up.flat(P([(29, 11), (37, 14), (37, 12), (30, 10)]), OUTLINE)  # angry brows slant to the middle
    up.flat(P([(48, 11), (40, 14), (40, 12), (47, 10)]), OUTLINE)
    up.flat(R((38, 21, 39, 21)), OUTLINE)  # nostrils
    up.flat(R((42, 21, 43, 21)), OUTLINE)
    up.flat(R((34, 25, 46, 26)), OUTLINE)  # grim mouth
    for x in (35, 43):  # two lower fangs jutting up over the lip
        up.flat(P([(x, 27), (x + 3, 27), (x + 2, 23), (x + 1, 23)]), WHITE)
    return low, up


def ape_storm(i: int) -> Canvas:
    """Dark storm clouds churning around the Great Ape (thickest behind him); loops every 4 frames."""
    c = Canvas()
    s = SWAY[i % 4]
    back = ((9, 28 + s, 6), (14, 19, 5), (8, 39 - s, 5), (10, 48 + s, 4), (21, 11 + s, 4))
    c.part(lambda d, f: [d.ellipse((x - r, y - r, x + r, y + r), f) for x, y, r in back], SHADOW)
    front = ((55, 20 - s, 4), (58, 31, 3), (50, 12, 3))
    c.part(lambda d, f: [d.ellipse((x - r, y - r, x + r, y + r), f) for x, y, r in front], SHADOW)
    for k, (x, y) in enumerate(((5, 14), (29, 8), (57, 44), (7, 54), (45, 6))):
        phase = (i + k) % 4
        r = (1, 2, 3, 2)[phase]
        c.part(E((x - r, y - 2 * phase - r + 6, x + r, y - 2 * phase + r + 6)), SHADOW)
    return c


def wukong_clouds(i: int) -> Canvas:
    """Clouds gathered behind him (he faces right): a soft mass at his back, thin wisps peeling off
    and drifting back while they thin out, and a few puffs rising behind his head. Loops every 4 frames."""
    c = Canvas()
    s = SWAY[i % 4]
    mass = ((9, 35 + s, 4), (13, 31, 5), (16, 38, 4), (8, 42 - s, 3), (19, 27 + s, 3))
    c.part(lambda d, f: [d.ellipse((x - r, y - r, x + r, y + r), f) for x, y, r in mass], WHITE)
    for k, (x, y) in enumerate(((14, 22), (12, 47), (18, 51), (10, 28), (16, 44))):
        phase = (i + k) % 4
        length = (6, 5, 4, 2)[phase]  # thins out as it drifts back
        x -= 2 * phase
        c.part(E((x - length, y - 1 - phase % 2, x + length, y + 1 - phase % 2)), WHITE, shade=False)
    for k, (x, y) in enumerate(((7, 20), (22, 15), (12, 12))):
        phase = (i + k * 2) % 4
        r = (1, 2, 3, 2)[phase]
        c.part(E((x - r, y - 2 * phase - r, x + r, y - 2 * phase + r)), WHITE)
    return c



# --- weapons: 48x24 cells, pointing right, held at GRIP (Godot pivots there) -------

WEAPON_W, WEAPON_H = 48, 24
GRIP = (6, 12)  # keep in sync with Player.WEAPON_GRIP
WEAPON_OUT = OUT / "weapons"


def grip(c: Canvas, color=BROWN):
    c.part(P([(5, 12), (9, 12), (8, 18), (4, 18)]), color)


def blaster(c: Canvas, body):
    grip(c)
    c.part(R((3, 8, 17, 12)), body)
    c.part(R((17, 9, 21, 11)), STEEL, shade=False)


def pistol(c):
    blaster(c, STEEL_D)


def bot_blaster(c):
    blaster(c, RED)


def smg(c):
    c.part(R((2, 9, 4, 12)), BROWN)  # stub stock
    grip(c, NAVY)
    c.part(R((3, 8, 25, 13)), STEEL_D)
    c.part(R((14, 13, 17, 20)), NAVY)  # magazine
    c.part(R((25, 9, 31, 11)), STEEL, shade=False)
    c.flat(R((27, 8, 28, 8)), TEAL_L)  # sight


def shotgun(c):
    c.part(P([(2, 10), (9, 9), (9, 14), (2, 16)]), BROWN)  # stock
    c.part(R((9, 8, 25, 13)), STEEL_D)
    c.part(R((25, 8, 35, 13)), STEEL)
    c.flat(R((25, 10, 35, 10)), OUTLINE)  # double barrel split
    c.part(R((16, 13, 25, 15)), BROWN)  # pump
    c.flat(R((35, 9, 35, 12)), ORANGE)


def sniper(c):
    c.part(P([(2, 10), (10, 9), (10, 14), (3, 15)]), BROWN)
    c.part(R((10, 9, 24, 13)), NAVY)
    c.part(R((24, 10, 45, 11)), STEEL, shade=False)
    c.part(R((13, 5, 22, 8)), STEEL_D)  # scope
    c.flat(R((22, 6, 22, 7)), TEAL_L)
    c.flat(R((43, 9, 43, 9)), STEEL)


def rocket(c):
    grip(c)
    c.part(RR((2, 6, 36, 16), 2), STEEL_D)
    for x in (8, 28):
        c.flat(R((x, 6, x + 2, 16)), RED)
    c.part(P([(36, 7), (43, 11), (36, 15)]), RED)  # warhead


def grenade(c):
    grip(c)
    c.part(R((3, 8, 20, 14)), BROWN)
    c.part(E((12, 4, 25, 17)), STEEL_D)  # drum
    for x, y in ((15, 7), (20, 7), (15, 13), (20, 13)):
        c.flat(R((x, y, x + 1, y + 1)), YELLOW)
    c.part(R((25, 8, 34, 14)), STEEL)
    c.flat(R((34, 9, 34, 13)), OUTLINE)


def laser(c):
    grip(c, NAVY)
    c.part(R((3, 9, 22, 13)), NAVY)
    for x in (8, 12, 16):
        c.flat(R((x, 9, x, 13)), TEAL)  # coils
    c.part(P([(22, 8), (26, 6), (35, 11), (26, 16), (22, 14)]), TEAL_L)  # prism


def sword(c):
    c.part(E((2, 10, 5, 14)), YELLOW)  # pommel
    c.part(R((5, 10, 9, 13)), BROWN)
    c.part(R((9, 5, 11, 18)), YELLOW)  # crossguard
    c.part(P([(12, 9), (39, 9), (44, 11), (39, 13), (12, 13)]), WHITE)
    c.flat(R((13, 11, 37, 11)), STEEL)  # fuller


def kunai(c):
    c.part(E((2, 9, 7, 14)), STEEL_D)  # ring pommel
    c.dot(4, 11, OUTLINE)
    c.part(R((7, 10, 13, 13)), MAROON)
    for x in (8, 11):
        c.flat(R((x, 10, x, 13)), RED)  # wraps
    c.part(P([(13, 8), (17, 9), (27, 11), (17, 13), (13, 14)]), STEEL)


def hammer(c):
    c.part(R((2, 10, 30, 13)), BROWN)
    c.part(RR((29, 2, 43, 21), 2), STEEL)
    c.flat(R((29, 9, 43, 14)), YELLOW)
    c.flat(R((35, 10, 37, 13)), TEAL_L)  # oath gem


def staff(c):
    c.part(R((2, 10, 45, 13)), RED)
    for x in (2, 40):
        c.part(R((x, 9, x + 5, 14)), YELLOW)
    c.flat(R((20, 10, 21, 13)), YELLOW)


def revolver(c):
    grip(c)
    c.part(R((4, 8, 13, 12)), STEEL_D)
    c.part(RR((9, 7, 17, 13), 1), STEEL)  # cylinder
    c.flat(R((11, 9, 15, 9)), STEEL_D)
    c.part(R((17, 8, 29, 11)), STEEL, shade=False)
    c.dot(28, 7, YELLOW)  # front sight
    c.dot(5, 7, STEEL_D)  # hammer


def blossom_fan(c):  # Sakura: a folding fan, open, ribs fanning out from the rivet
    c.part(lambda d, f: d.pieslice((-6, -4, 30, 28), -38, 38, f), PINK_L)
    for a in (-30, -15, 0, 15, 30):
        r = math.radians(a)
        c.flat(L([(12, 12), (12 + round(17 * math.cos(r)), 12 + round(17 * math.sin(r)))], 1), PINK)
    c.flat(lambda d, f: d.arc((-6, -4, 30, 28), -38, 38, f, 2), RED)
    c.part(E((4, 9, 10, 15)), BROWN)  # rivet / guard end
    c.dot(7, 12, YELLOW)


def ember_palm(c, t=0):  # Flint: a fireball floating over his palm, drawn upright (WeaponData.upright), its flames rising
    flame(c, 7, 19, 14, 10, t, tongues=3)  # tongues rising off it, flickering every tick
    c.part(E((7, 9, 19, 21)), RED, shade=False, line=False)  # the ball
    c.part(E((8, 10, 18, 20)), ORANGE, shade=False, line=False)
    c.flat(E((10, 12, 16, 18)), YELLOW)
    c.flat(R((12, 14, 14, 16)) if t % 2 else R((13, 15, 13, 15)), WHITE)  # white-hot core pulses
    c.dot(16 - t % 2, 8 - 2 * (t % 4), YELLOW)  # a spark rising off the top


WEAPONS = {"pistol": pistol, "bot_blaster": bot_blaster, "smg": smg, "shotgun": shotgun, "sniper": sniper,
           "rocket": rocket, "grenade": grenade, "laser": laser, "sword": sword,
           "flicker_kunai": kunai, "warden_hammer": hammer, "twinshot_revolver": revolver, "wukong_staff": staff, "flint_palm": ember_palm,
           "sakura_fan": blossom_fan}


## In-world loops (WeaponData.held_frames): draw(c, t) for t in 0..3, written as <name>_anim.png strips.
WEAPON_ANIMS = {"flint_palm": ember_palm}


def weapon_image(draw) -> Image.Image:
    c = Canvas()
    draw(c)
    return outline(c.img).crop((0, 0, WEAPON_W, WEAPON_H))


# --- arenas: 32x32 tiles drawn at the characters' pixel scale (48 px world tiles) ---------
# Each theme writes assets/arenas/<theme>_tiles.png, one row of TILE cells in TILE_ORDER, and
# optionally <theme>_decal.png, a full-arena overlay painted over the floor (court lines).

TILE = 32
TILE_ORDER = ["floor_a", "floor_b", "floor_shadow", "wall_top", "wall_face", "crate", "crate_damaged"]
FACE_H = 12  # front face height on wall tiles above floor (3/4 view)
SHADOW_ROWS = 6  # floor rows darkened under a wall face
ARENA_W, ARENA_H = 40, 24  # layout size in tiles (ArenaLayouts); decals cover it exactly
ARENA_OUT = ROOT / "assets" / "arenas"


def tile_canvas(base) -> Canvas:
    c = Canvas()
    c.flat(R((0, 0, TILE - 1, TILE - 1)), base)
    return c


def crop_tile(c: Canvas) -> Image.Image:
    return c.img.crop((0, 0, TILE, TILE))


def darken_rows(img: Image.Image, rows: int) -> Image.Image:
    out = img.copy()
    px = out.load()
    for y in range(rows):
        for x in range(TILE):
            r, g, b, a = px[x, y]
            px[x, y] = DARKER[(r, g, b)] + (a,)
    return out


def with_face(top: Image.Image, face: Image.Image) -> Image.Image:
    """A wall tile seen from the front: its top, with the front face over the bottom FACE_H rows."""
    out = top.copy()
    out.paste(face.crop((0, TILE - FACE_H, TILE, TILE)), (0, TILE - FACE_H))
    return out


def object_tile(draw) -> Image.Image:
    c = Canvas()
    draw(c)
    return outline(c.img).crop((0, 0, TILE, TILE))


# Gym: hardwood court, padded blue walls, ball carts.
def gym_floor(variant: int):
    c = tile_canvas(SKIN_D)
    for x in range(0, TILE, 8):
        c.flat(R((x, 0, x, TILE - 1)), BROWN)  # plank seams
        joint = (x * 5 + variant * 13) % TILE
        c.flat(R((x, joint, x + 7, joint)), BROWN)  # staggered plank ends
    for x, y in ((3, 6), (19, 21), (12, 27), (27, 10)) if variant else ((5, 14), (22, 4), (14, 25)):
        c.flat(R((x, y, x + 2, y)), ORANGE)  # grain
    return crop_tile(c)


def gym_wall_top():
    c = tile_canvas(BLUE)
    for v in (0, 16):
        c.flat(R((v, 0, v, TILE - 1)), NAVY)
        c.flat(R((0, v, TILE - 1, v)), NAVY)
    for x, y in ((8, 8), (24, 8), (8, 24), (24, 24)):
        c.dot(x, y, STEEL)  # tufted buttons
    return crop_tile(c)


def gym_wall_face():
    c = tile_canvas(NAVY)
    c.flat(R((0, TILE - FACE_H, TILE - 1, TILE - FACE_H)), STEEL)  # top trim
    for x in (0, 16):
        c.flat(R((x, TILE - FACE_H + 1, x, TILE - 1)), SHADOW)
    c.flat(R((0, TILE - 1, TILE - 1, TILE - 1)), OUTLINE)
    return crop_tile(c)


def ball_cart(balls):
    def draw(c: Canvas):
        c.part(R((4, 12, 27, 27)), STEEL_D)  # cart
        c.flat(R((6, 14, 25, 25)), SHADOW)
        for x, y in balls:
            c.part(E((x, y, x + 9, y + 9)), ORANGE)
            c.flat(R((x + 4, y, x + 4, y + 9)), OUTLINE)  # seams
            c.flat(R((x, y + 4, x + 9, y + 4)), OUTLINE)
        for x in (5, 25):
            c.part(R((x, 27, x + 2, 29)), OUTLINE, shade=False)  # wheels
    return draw


# Pit: stone arena floor, stone block walls, wooden crates.
def pit_floor(variant: int):
    c = tile_canvas(SHADOW)
    for v in (0, 16):
        c.flat(R((0, v, TILE - 1, v)), OUTLINE)
    off = 8 if variant else 0
    for y0 in (0, 16):
        x = (off + (8 if y0 else 0)) % 16
        c.flat(R((x, y0, x, y0 + 15)), OUTLINE)
        c.flat(R((x + 16, y0, x + 16, y0 + 15)), OUTLINE)
    for x, y in ((5, 5), (20, 10), (11, 22), (27, 27)) if variant else ((9, 3), (25, 20), (3, 19)):
        c.dot(x, y, NAVY)
    return crop_tile(c)


def pit_wall_top():
    c = tile_canvas(STEEL_D)
    for y in (0, 11, 22):
        c.flat(R((0, y, TILE - 1, y)), SHADOW)
        x = 8 if y == 11 else 0
        c.flat(R((x, y, x, y + 10)), SHADOW)
        c.flat(R((x + 16, y, x + 16, y + 10)), SHADOW)
    c.flat(R((2, 2, 6, 2)), STEEL)
    c.flat(R((19, 13, 23, 13)), STEEL)
    return crop_tile(c)


def pit_wall_face():
    c = tile_canvas(SHADOW)
    c.flat(R((0, TILE - FACE_H, TILE - 1, TILE - FACE_H)), STEEL)
    for x in (0, 16):
        c.flat(R((x + 4, TILE - FACE_H + 1, x + 4, TILE - 1)), OUTLINE)
    c.flat(R((0, TILE - 6, TILE - 1, TILE - 6)), OUTLINE)
    c.flat(R((0, TILE - 1, TILE - 1, TILE - 1)), OUTLINE)
    return crop_tile(c)


def wood_crate(damaged):
    def draw(c: Canvas):
        c.part(R((4, 6, 27, 28)), BROWN)
        c.flat(R((7, 9, 24, 25)), SKIN_D)
        c.flat(L([(7, 9), (24, 25)], 2), BROWN)  # brace
        if damaged:
            c.flat(L([(18, 6), (15, 13), (19, 17)], 1), OUTLINE)
            c.flat(L([(6, 22), (11, 20)], 1), OUTLINE)
    return draw


# Foundry: riveted steel floor plates, brick walls, hazard-striped steel crates.
def foundry_floor(variant: int):
    c = tile_canvas(STEEL_D)
    c.flat(R((0, 0, TILE - 1, 0)), SHADOW)
    c.flat(R((0, 0, 0, TILE - 1)), SHADOW)
    for x, y in ((3, 3), (28, 3), (3, 28), (28, 28)):
        c.dot(x, y, STEEL)
    if variant:
        for y in range(10, 23, 3):
            c.flat(R((9, y, 22, y)), SHADOW)  # vent grill
    else:
        c.flat(R((12, 15, 19, 16)), STEEL)  # scuff
    return crop_tile(c)


def foundry_wall_top():
    c = tile_canvas(RED)
    for i, y in enumerate(range(0, TILE, 8)):
        c.flat(R((0, y, TILE - 1, y)), MAROON)
        x = 4 if i % 2 else 12
        c.flat(R((x, y, x, y + 7)), MAROON)
        c.flat(R((x + 16, y, x + 16, y + 7)), MAROON)
    return crop_tile(c)


def foundry_wall_face():
    c = tile_canvas(MAROON)
    c.flat(R((0, TILE - FACE_H, TILE - 1, TILE - FACE_H)), ORANGE)
    for i in range(0, TILE, 8):
        c.flat(P([(i, TILE - 6), (i + 4, TILE - 10), (i + 6, TILE - 10), (i + 2, TILE - 6)]), YELLOW)  # hazard
    c.flat(R((0, TILE - 5, TILE - 1, TILE - 2)), OUTLINE)
    c.flat(R((0, TILE - 1, TILE - 1, TILE - 1)), OUTLINE)
    return crop_tile(c)


def steel_crate(damaged):
    def draw(c: Canvas):
        c.part(R((4, 6, 27, 28)), STEEL)
        c.flat(R((4, 15, 27, 19)), YELLOW)
        for x in range(4, 27, 4):
            c.flat(P([(x, 19), (x + 2, 15), (x + 3, 15), (x + 1, 19)]), OUTLINE)
        if damaged:
            c.flat(L([(9, 6), (12, 12), (9, 14)], 1), OUTLINE)
            c.flat(E((19, 21, 24, 25)), STEEL_D)  # dent
    return draw


THEMES = {
    "gym": (gym_floor, gym_wall_top, gym_wall_face, ball_cart([(7, 8), (15, 6), (11, 14)]),
            ball_cart([(13, 12)])),
    "pit": (pit_floor, pit_wall_top, pit_wall_face, wood_crate(False), wood_crate(True)),
    "foundry": (foundry_floor, foundry_wall_top, foundry_wall_face, steel_crate(False), steel_crate(True)),
}


def theme_sheet(floor, wall_top, wall_face, crate, crate_damaged) -> Image.Image:
    a = floor(0)
    top = wall_top()
    tiles = [a, floor(1), darken_rows(a, SHADOW_ROWS), top, with_face(top, wall_face()),
             object_tile(crate), object_tile(crate_damaged)]
    sheet = Image.new("RGBA", (TILE * len(tiles), TILE), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * TILE, 0))
    return sheet


def gym_decal() -> Image.Image:
    """Court markings for the whole Gym (ARENA_W x ARENA_H tiles), hoops centred on the end walls."""
    w, h = ARENA_W * TILE, ARENA_H * TILE
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    paint, line = MAROON + (255,), WHITE + (255,)
    left, right, top, bottom = TILE + 10, w - TILE - 11, TILE + 10, h - TILE - 11
    d.ellipse((cx - 70, cy - 70, cx + 70, cy + 70), paint)  # centre circle
    for side in (1, -1):
        base = left if side == 1 else right
        hoop = base + side * 30
        lane = (min(base, base + side * 190), cy - 60, max(base, base + side * 190), cy + 60)
        d.rectangle(lane, paint)  # the key
        d.rectangle(lane, outline=line, width=2)
        ft = base + side * 190
        d.ellipse((ft - 60, cy - 60, ft + 60, cy + 60), outline=line, width=2)  # free-throw circle
        d.arc((hoop - 300, cy - 300, hoop + 300, cy + 300), -68 if side == 1 else 112, 68 if side == 1 else 248,
              line, 2)  # three-point arc
        for y in (cy - 278, cy + 276):
            x_end = hoop + side * 112
            d.rectangle((min(base, x_end), y, max(base, x_end), y + 1), line)
        d.rectangle((min(base, base + side * 6), cy - 22, max(base, base + side * 6), cy + 22), WHITE + (255,))  # backboard
        rim = base + side * 16
        d.ellipse((rim - 9, cy - 9, rim + 9, cy + 9), outline=ORANGE + (255,), width=2)
    d.ellipse((cx - 70, cy - 70, cx + 70, cy + 70), outline=line, width=2)
    d.ellipse((cx - 22, cy - 22, cx + 22, cy + 22), outline=line, width=2)
    d.rectangle((cx - 1, top, cx, bottom), line)  # half-court line
    d.rectangle((left, top, right, bottom), outline=line, width=2)  # boundary
    return img


DECALS = {"gym": gym_decal}


def pickup_art() -> dict[str, Image.Image]:
    """Shared pickup pad (32x32) and energy crystal (16x24)."""
    pad = Canvas()
    pad.part(E((2, 9, 29, 26)), STEEL_D)
    pad.flat(E((7, 12, 24, 23)), SHADOW)
    pad.flat(E((10, 14, 21, 21)), NAVY)
    crystal = Canvas()
    crystal.part(P([(8, 2), (13, 9), (8, 21), (3, 9)]), TEAL_L)
    crystal.flat(L([(8, 3), (8, 19)], 1), WHITE)
    crystal.flat(P([(9, 9), (12, 9), (8, 20)]), TEAL)
    return {"pad": outline(pad.img).crop((0, 0, 32, 32)), "energy": outline(crystal.img).crop((0, 0, 16, 24))}


# --- UI kit: 9-slice panels/buttons, round touch buttons, icons (assets/ui/) ---------------
# Drawn at UiStyle.UI_PX canvas units per art pixel. 9-slice margins: UiStyle.SLICE.

UI_OUT = ROOT / "assets" / "ui"
SLICE_SIZE = 16


def slice_box(fill, border, light, lip, lip_h: int = 0, edge=OUTLINE) -> Image.Image:
    """A 16x16 9-slice: `edge` outline, 1 px light bevel on top, `lip_h` px of `lip` at the bottom."""
    img = Image.new("RGBA", (SLICE_SIZE, SLICE_SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    n = SLICE_SIZE - 1
    d.rounded_rectangle((0, 0, n, n), 3, edge + (255,))
    d.rounded_rectangle((1, 1, n - 1, n - 1), 2, border + (255,))
    d.rectangle((2, 2, n - 2, n - 2 - lip_h), fill + (255,))
    d.rectangle((3, 2, n - 3, 2), light + (255,))
    if lip_h:
        d.rectangle((2, n - 1 - lip_h, n - 2, n - 2), lip + (255,))
    return img


def round_button(fill, light, lip, size: int = 32) -> Image.Image:
    c = Canvas()
    c.flat(E((1, 2, size - 2, size - 1)), lip)  # lip below
    c.flat(E((1, 1, size - 2, size - 3)), fill)
    c.flat(E((5, 3, size - 6, 9)), light)
    c.flat(E((7, 4, size - 8, 7)), fill)
    return outline(c.img).crop((0, 0, size + 1, size + 1))


def ring(size: int, color, width: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, size - 1, size - 1), OUTLINE + (255,))
    d.ellipse((1, 1, size - 2, size - 2), color + (255,))
    d.ellipse((1 + width, 1 + width, size - 2 - width, size - 2 - width), OUTLINE + (255,))
    d.ellipse((2 + width, 2 + width, size - 3 - width, size - 3 - width), (0, 0, 0, 0))
    return img


def icon(draw, size: int = 13) -> Image.Image:
    """`draw` paints into a size x size box; returned with a 1 px outline margin ((size + 2)^2)."""
    c = Canvas()
    draw(c)
    padded = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    padded.paste(c.img, (1, 1))
    return outline(padded).crop((0, 0, size + 2, size + 2))


ICONS = {
    "blaze_run": lambda c: (c.flat(L([(0, 3), (4, 3)], 1), ORANGE), c.flat(L([(0, 7), (5, 7)], 1), RED),
                            c.flat(L([(1, 10), (5, 10)], 1), ORANGE),
                            c.flat(P([(4, 11), (4, 5), (6, 6), (8, 0), (9, 5), (11, 4), (12, 8), (10, 11)]), RED),
                            c.flat(P([(6, 11), (6, 7), (8, 4), (9, 8), (10, 11)]), ORANGE),
                            c.flat(P([(7, 11), (8, 8), (9, 11)]), YELLOW)),
    "hp": lambda c: (c.flat(E((1, 2, 6, 7)), RED), c.flat(E((6, 2, 11, 7)), RED),
                     c.flat(P([(1, 5), (11, 5), (6, 11)]), RED), c.dot(3, 3, WHITE)),
    "armor": lambda c: (c.flat(P([(2, 1), (10, 1), (10, 6), (6, 11), (2, 6)]), STEEL),
                        c.flat(P([(6, 1), (10, 1), (10, 6), (6, 11)]), STEEL_D)),
    "energy": lambda c: c.flat(P([(7, 1), (3, 7), (6, 7), (5, 11), (10, 5), (7, 5), (8, 1)]), TEAL_L),
    "kills": lambda c: (c.flat(L([(2, 10), (10, 2)], 2), STEEL), c.flat(L([(2, 2), (10, 10)], 2), STEEL),
                        c.flat(R((2, 9, 3, 10)), BROWN), c.flat(R((9, 9, 10, 10)), BROWN)),
    "deaths": lambda c: (c.flat(E((2, 1, 10, 9)), WHITE), c.flat(R((4, 8, 8, 11)), WHITE),
                         c.flat(R((4, 4, 5, 6)), OUTLINE), c.flat(R((7, 4, 8, 6)), OUTLINE),
                         c.flat(R((5, 10, 5, 11)), OUTLINE), c.flat(R((7, 10, 7, 11)), OUTLINE)),
    "clock": lambda c: (c.flat(E((1, 1, 11, 11)), WHITE), c.flat(R((6, 3, 6, 6)), OUTLINE),
                        c.flat(R((6, 6, 8, 6)), OUTLINE)),
    "fire": lambda c: (c.flat(E((1, 1, 11, 11)), WHITE), c.flat(E((3, 3, 9, 9)), RED), c.flat(E((5, 5, 7, 7)), WHITE),
                       c.flat(R((6, 0, 6, 12)), WHITE), c.flat(R((0, 6, 12, 6)), WHITE)),
    "swap": lambda c: (c.flat(P([(1, 4), (8, 4), (8, 1), (12, 5), (8, 9), (8, 6), (1, 6)]), WHITE),
                       c.flat(P([(11, 8), (4, 8), (4, 11), (0, 7), (4, 3)]), WHITE)),
    "dash": lambda c: (c.flat(P([(5, 2), (11, 6), (5, 10), (7, 6)]), WHITE), c.flat(R((1, 3, 4, 3)), TEAL_L),
                       c.flat(R((0, 6, 4, 6)), TEAL_L), c.flat(R((1, 9, 4, 9)), TEAL_L)),
    "barrier": lambda c: (c.flat(RR((2, 1, 10, 11), 2), BLUE), c.flat(P([(6, 3), (8, 6), (6, 9), (4, 6)]), YELLOW)),
    "ape": lambda c: (c.flat(E((1, 1, 11, 11)), MAROON), c.flat(E((3, 5, 10, 11)), BROWN),
                      c.flat(R((2, 2, 10, 3)), YELLOW), c.flat(R((4, 6, 5, 7)), RED), c.flat(R((7, 6, 8, 7)), RED),
                      c.flat(R((5, 9, 8, 9)), OUTLINE)),
    "clones": lambda c: (c.flat(E((0, 2, 6, 8)), SHADOW), c.flat(R((1, 7, 5, 11)), SHADOW),
                         c.flat(E((6, 1, 12, 7)), NAVY), c.flat(R((7, 6, 11, 11)), NAVY),
                         c.flat(R((7, 3, 11, 4)), SKIN), c.flat(R((1, 4, 5, 5)), STEEL_D)),
    "grapple_kunai": lambda c: (c.flat(P([(12, 0), (10, 6), (8, 4), (6, 2)]), STEEL), c.flat(L([(8, 4), (11, 1)], 1), WHITE),
                                c.flat(L([(7, 5), (5, 7)], 2), RED), c.flat(E((3, 7, 6, 10)), STEEL_D), c.dot(4, 8, OUTLINE),
                                [c.dot(x, y, STEEL if x % 2 else STEEL_D) for x, y in ((3, 10), (2, 11), (1, 12), (2, 12), (0, 12))]),
    "smoke": lambda c: (c.flat(E((0, 5, 7, 12)), STEEL_D), c.flat(E((4, 2, 12, 10)), STEEL),
                        c.flat(E((6, 6, 12, 12)), STEEL_D), c.flat(R((4, 1, 5, 2)), RED)),
    "volley": lambda c: [c.flat(L([(6 + round(2 * dx), 6 + round(2 * dy)), (6 + round(6 * dx), 6 + round(6 * dy))], 1), STEEL)
                         for dx, dy in ((1, 0), (0.7, 0.7), (0, 1), (-0.7, 0.7), (-1, 0), (-0.7, -0.7), (0, -1), (0.7, -0.7))]
                        + [c.flat(E((4, 4, 8, 8)), RED)],
    "flare": lambda c: [c.flat(L([(6 + round(3 * dx), 6 + round(3 * dy)), (6 + round(6 * dx), 6 + round(6 * dy))], 1),
                               ORANGE) for dx, dy in ((1, 0), (0.7, 0.7), (0, 1), (-0.7, 0.7), (-1, 0), (-0.7, -0.7),
                                                      (0, -1), (0.7, -0.7))]
                       + [c.flat(E((3, 3, 9, 9)), RED), c.flat(E((4, 4, 8, 8)), YELLOW)],
    "petals": lambda c: [c.flat(P([(6, 6), (6 + round(5 * dx - 2 * dy), 6 + round(5 * dy + 2 * dx)),
                                    (6 + round(6 * dx), 6 + round(6 * dy)), (6 + round(5 * dx + 2 * dy), 6 + round(5 * dy - 2 * dx))]),
                                 PINK_L) for dx, dy in ((0, -1), (0.95, -0.31), (0.59, 0.81), (-0.59, 0.81), (-0.95, -0.31))]
                        + [c.flat(E((4, 4, 8, 8)), PINK), c.dot(6, 6, YELLOW)],
    "inferno": lambda c: (c.flat(P([(6, 0), (9, 4), (11, 2), (11, 8), (9, 11), (3, 11), (1, 8), (1, 3), (3, 5)]), RED),
                          c.flat(P([(6, 3), (9, 7), (8, 10), (4, 10), (3, 7)]), ORANGE), c.flat(E((5, 7, 7, 10)), YELLOW)),
    "inferno": lambda c: (c.flat(P([(6, 0), (9, 4), (11, 2), (11, 8), (9, 11), (3, 11), (1, 8), (1, 3), (3, 5)]), RED),
                          c.flat(P([(6, 3), (9, 7), (8, 10), (4, 10), (3, 7)]), ORANGE), c.flat(E((5, 7, 7, 10)), YELLOW)),
    # Blossom Snare: a blossom above a loop of vine.
    "blossom_snare": lambda c: [c.flat(lambda d, f: d.ellipse((1, 7, 11, 12), outline=f, width=2), PINK)]
                               + [c.flat(E((x - 2, y - 2, x + 2, y + 2)), PINK_L if i % 2 else WHITE)
                                  for i, (x, y) in enumerate(((6, 2), (9, 4), (8, 7), (4, 7), (3, 4)))]
                               + [c.flat(E((5, 3, 7, 5)), PINK), c.dot(6, 4, YELLOW)],
    "cherry_sapling": lambda c: [c.flat(R((5, 6, 6, 11)), BROWN), c.flat(R((3, 11, 8, 11)), BROWN),
                                 c.flat(E((1, 1, 7, 7)), PINK), c.flat(E((5, 1, 11, 7)), PINK),
                                 c.flat(E((3, 0, 9, 5)), PINK_L), c.dot(4, 3, WHITE), c.dot(8, 3, WHITE),
                                 c.dot(6, 5, WHITE)],
    "petal_drift": lambda c: [ward_petal(c, 6 + 4.5 * math.cos(a), 6 + 4.5 * math.sin(a), a + 1.8, 6, 1.0, col)
                              for a, col in ((0.3, PINK_L), (2.4, WHITE), (4.5, PINK_L))]
                             + [c.flat(E((4, 4, 8, 8)), PINK), c.dot(6, 6, YELLOW)],
    "blossom_ward": lambda c: [c.flat(lambda d, f: d.ellipse((1, 1, 11, 11), outline=f, width=1), PINK)]
                              + [c.flat(P([(6 + round(5 * dx), 6 + round(5 * dy)), (6 + round(5 * dx - 2 * dy), 6 + round(5 * dy + 2 * dx)),
                                           (6 + round(5 * dx + 2 * dy), 6 + round(5 * dy - 2 * dx))]),
                                        PINK_L if i % 2 else WHITE)
                                 for i, (dx, dy) in enumerate(((0, -1), (0.87, -0.5), (0.87, 0.5), (0, 1), (-0.87, 0.5), (-0.87, -0.5)))]
                              + [c.flat(E((4, 4, 8, 8)), PINK_L), c.dot(6, 6, YELLOW)],
    "vine_swing": lambda c: (c.flat(L([(2, 0), (2, 3), (4, 6), (7, 7)], 1), BROWN),  # vine, his head hanging off it
                             c.flat(P([(3, 1), (6, 0), (5, 3)]), TEAL_L), c.flat(P([(1, 4), (0, 7), (2, 6)]), TEAL),
                             c.flat(E((4, 5, 12, 12)), BROWN), c.flat(E((6, 7, 12, 12)), SKIN),
                             c.flat(R((4, 6, 12, 7)), YELLOW), c.dot(8, 9, OUTLINE), c.dot(10, 9, OUTLINE),
                             c.flat(L([(9, 0), (11, 1)], 1), RED)),
    "sky_pillar": lambda c: (c.flat(P([(1, 12), (4, 10), (8, 10), (12, 12)]), STEEL), c.flat(L([(5, 9), (8, 1)], 3), RED),
                             c.flat(R((5, 0, 9, 1)), YELLOW), c.flat(R((4, 6, 8, 7)), YELLOW), c.dot(7, 3, ORANGE),
                             c.flat(L([(0, 11), (2, 8)], 1), SHADOW), c.flat(L([(12, 11), (10, 8)], 1), SHADOW)),
    "staff_whirl": lambda c: (c.flat(lambda d, f: d.ellipse((0, 2, 12, 10), outline=f, width=1), YELLOW),
                              c.flat(L([(1, 10), (11, 2)], 3), RED), c.flat(R((0, 9, 2, 11)), YELLOW),
                              c.flat(R((10, 1, 12, 3)), YELLOW), c.dot(2, 3, WHITE), c.dot(10, 9, WHITE)),
    "eruption": lambda c: (c.flat(P([(0, 11), (4, 9), (8, 9), (12, 11)]), MAROON),
                           c.flat(P([(3, 10), (4, 3), (5, 5), (6, 0), (7, 4), (8, 2), (9, 10)]), RED),
                           c.flat(P([(4, 10), (5, 6), (6, 3), (7, 6), (8, 10)]), ORANGE),
                           c.flat(P([(5, 10), (6, 6), (7, 10)]), YELLOW),
                           c.flat(L([(1, 11), (3, 12)], 1), ORANGE), c.flat(L([(9, 12), (11, 11)], 1), ORANGE),
                           c.dot(2, 6, YELLOW), c.dot(10, 4, ORANGE), c.dot(11, 8, YELLOW)),
    "flare_burst": lambda c: (c.flat(lambda d, f: d.ellipse((0, 3, 12, 11), outline=f, width=1), RED),
                              c.flat(P([(1, 7), (2, 3), (3, 6), (4, 2), (5, 6), (7, 1), (8, 6), (9, 3), (10, 6), (11, 2), (12, 7)]), ORANGE),
                              c.flat(E((4, 5, 8, 9)), YELLOW), c.flat(E((5, 6, 7, 8)), WHITE),
                              c.dot(1, 11, YELLOW), c.dot(11, 12, ORANGE)),
    "trophy": lambda c: (c.flat(P([(2, 1), (10, 1), (9, 6), (3, 6)]), YELLOW), c.flat(R((5, 6, 7, 9)), YELLOW),
                         c.flat(R((3, 9, 9, 11)), ORANGE)),
}


UI_SLICE_SCALE = 2  # 9-slices are saved pre-scaled (StyleBoxTexture can't scale); keep in sync with UiStyle.SLICE


def ui_kit() -> dict[str, Image.Image]:
    slices = {
        "panel": slice_box(NAVY, SHADOW, STEEL_D, SHADOW, 2),
        "card": slice_box(SHADOW, STEEL_D, STEEL_D, OUTLINE, 2),
        "card_selected": slice_box(SHADOW, TEAL_L, TEAL_L, TEAL, 2),
        "card_gold": slice_box(SHADOW, YELLOW, YELLOW, ORANGE, 2),
        "button": slice_box(STEEL_D, STEEL_D, STEEL, SHADOW, 3),
        "button_pressed": slice_box(SHADOW, SHADOW, STEEL_D, SHADOW, 0),
        "button_primary": slice_box(TEAL, TEAL, TEAL_L, NAVY, 3),
        "button_primary_pressed": slice_box(NAVY, NAVY, TEAL, NAVY, 0),
        "button_disabled": slice_box(SHADOW, SHADOW, SHADOW, OUTLINE, 3, edge=SHADOW),
        "field": slice_box(OUTLINE, SHADOW, OUTLINE, OUTLINE, 0),
    }
    big = SLICE_SIZE * UI_SLICE_SCALE
    kit = {k: v.resize((big, big), Image.NEAREST) for k, v in slices.items()}
    kit |= {
        "round": round_button(STEEL_D, STEEL, SHADOW),
        "round_fire": round_button(RED, ORANGE, MAROON),
        "joy_base": ring(40, STEEL_D, 3),
        "joy_knob": round_button(STEEL, WHITE, STEEL_D, 18),
    }
    kit.update({f"icon_{k}": icon(v) for k, v in ICONS.items()})
    return kit


# --- effects: pixel-art animation strips for skills (assets/fx/), drawn at the sprite scale -----

FX_OUT = ROOT / "assets" / "fx"
POOF_FRAMES = 20
POOF_GROW_FRAMES = 6  # the cloud swells up over these, then bursts
SMOKE_FRAMES = 12


def poof_frame(size: int, k: int, color) -> Image.Image:
    """A cloud puff: lumps swell up into a full cloud (POOF_GROW_FRAMES) with a swirl curling inside it, then burst
    outward, drift up and break into wisps, sparkles flying off. A grey shadow layer under the lumps gives them depth.
    Lumps are uneven (seeded by size, so every frame of a strip agrees)."""
    rng = random.Random(size)
    lumps = [(rng.uniform(-0.3, 0.3), rng.uniform(0.8, 1.15), rng.uniform(0.8, 1.2)) for _ in range(9)]
    c = Canvas(size)
    m = size // 2
    grow = min(1.0, (k + 1) / POOF_GROW_FRAMES) ** 0.7  # eases in: quick at first, settling into the full cloud
    t = max(0.0, (k - POOF_GROW_FRAMES + 1) / (POOF_FRAMES - POOF_GROW_FRAMES))
    rise = size * 0.03 * t
    ring, wisps = [], []
    for i, (da, reach, rr) in enumerate(lumps):
        ang = math.tau * i / len(lumps) + 0.4 + da
        d = size * (0.06 + 0.13 * grow + 0.15 * t * reach)
        r = round(size * 0.13 * rr * grow * (1 - 0.8 * t))
        if r >= 1:
            ring.append((m + math.cos(ang) * d, m + math.sin(ang) * d - rise, r))
        if t > 0.2:  # trailing wisps between the lumps, lagging behind them
            ang += math.pi / len(lumps)
            d = size * (0.12 + 0.2 * t)
            wisps.append((m + math.cos(ang) * d, m + math.sin(ang) * d - rise, max(1, round(size * 0.04 * (1 - t)))))
    blob = lambda pts: lambda dr, f: [dr.ellipse((x - r, y - r, x + r, y + r), f) for x, y, r in pts]
    sh = max(1, round(size * 0.03))  # the shadow layer sits down and right of the lumps
    c.part(blob([(x + sh, y + sh, r) for x, y, r in ring]), STEEL, shade=False)
    c.part(blob(wisps + ring), color)
    core = round(size * 0.22 * grow * (1 - 1.3 * t))
    if core >= 2:  # drawn over the ring, outlined where it overlaps: reads as separate lumps
        c.part(blob([(m, m - rise, core)]), color)
        if core >= 5:  # a swirl curling round inside it, turning as it forms
            spin = 70 * k
            c.flat(lambda dr, f: dr.arc((m - core * 0.6, m - rise - core * 0.6, m + core * 0.6, m - rise + core * 0.6),
                                        spin, spin + 200, f, width=1), STEEL)
            c.flat(lambda dr, f: dr.arc((m - core * 0.3, m - rise - core * 0.3, m + core * 0.3, m - rise + core * 0.3),
                                        spin + 180, spin + 330, f, width=1), STEEL)
    if 0.0 < t < 0.85:  # sparkles flying off as it bursts, a little cross each
        for i in range(6):
            ang = math.tau * i / 6 + 0.2
            d = size * (0.2 + 0.28 * t)
            x, y = m + math.cos(ang) * d, m + math.sin(ang) * d - rise
            arm = 2 if t < 0.5 and size >= 64 else 1
            c.flat(R((x - arm, y, x + arm, y)), WHITE if i % 2 else STEEL)
            c.flat(R((x, y - arm, x, y + arm)), WHITE if i % 2 else STEEL)
    return outline(c.img)


## Vine Swing (Apex): his pose along the swing, a vine to hang it from, a leafy burst at takeoff, dust on landing.
SWING_FRAMES = 12
SWING_HAND = (65, 13)  # the gripping fist in a CELL frame; every frame pivots on it. Keep in sync with SpecialFx
SWING_TILT = (-20, 20)  # body angle (deg, + = legs swung forward) at takeoff and at landing
VINE_W, VINE_LEN = 19, 240
LEAF_FRAMES = 14
DUST_FRAMES = 12


def wukong_swing_frame(k: int) -> Image.Image:
    """Apex hanging from the vine by his raised front fist, legs tucked up and tail curled (12 frames). The body swings
    on the fist: trailing behind at takeoff, tucked tightest mid-air, legs reaching forward for the landing; the vine's
    end wraps his fist with a leaf fluttering off it, circlet tails and cloud stream behind, wind streaks mid-swing."""
    t = k / (SWING_FRAMES - 1)
    arc = math.sin(math.pi * t)
    low, up = wukong(None, k % 4, swing=True)
    c = Canvas(CELL)
    c.img.alpha_composite(wukong_clouds(k % 4).img, (PAD - round(3 * arc), PAD + 2))  # cloud trailing behind him
    # Legs trail at takeoff, knees tuck up in front mid-air, then reach forward and down for the landing.
    c.img.alpha_composite(low.img, (PAD + round(-3 + 7 * t + 3 * arc), PAD - round(1 + 4 * arc)))
    c.img.alpha_composite(up.img, (PAD, PAD + UPPER_DY))
    c.px = c.img.load()
    hx, hy = SWING_HAND
    ox, oy = PAD, PAD + UPPER_DY
    for i in range(7):  # circlet tails streaming back, longer in the fast part of the swing
        x = ox + 17 - 2 * i - round(2 * arc)
        y = oy + 14 + round((0.8 + 0.25 * i) * math.sin(0.9 * i + k * 1.1))
        c.flat(R((x - 1, y, x, y + 1)), RED if i < 5 else MAROON)
    sx, sy = ox + 45, oy + 38  # front shoulder
    ex, ey = sx + 4, sy - 16  # elbow beside his cheek
    c.part(L([(sx, sy), (ex, ey)], 5), YELLOW)  # golden sleeve
    c.flat(L([(sx + 1, sy + 2), (ex + 1, ey + 1)], 1), ORANGE)
    c.part(L([(ex, ey), (hx, hy + 3)], 4), SKIN)  # bare forearm reaching up past his head
    c.part(R((ex - 2, ey - 2, ex + 2, ey)), RED, shade=False)  # cuff wrap
    c.part(E((hx - 3, hy - 3, hx + 3, hy + 3)), SKIN)  # the fist
    for dy in (-3, 0):  # the vine's end wound round it
        c.flat(R((hx - 3, hy + dy, hx + 3, hy + dy + 1)), BROWN)
        c.dot(hx - 3, hy + dy, SKIN_D)
    flutter = round(2 * math.sin(k * 1.3))
    c.part(P([(hx + 3, hy - 3), (hx + 8, hy - 5 + flutter), (hx + 9, hy - 2 + flutter), (hx + 4, hy - 1)]), TEAL)  # leaf
    c.flat(L([(hx + 4, hy - 3), (hx + 8, hy - 4 + flutter)], 1), TEAL_L)
    for j in range(3):  # leaves shaken loose, drifting down behind
        ph = (t * 1.6 + j / 3) % 1.0
        x, y = hx - 5 - 12 * ph - j * 3, hy + 8 + 34 * ph + 3 * math.sin(ph * 9 + j)
        if ph < 0.85:
            c.flat(R((round(x), round(y), round(x) + 1, round(y))), TEAL_L if j % 2 else TEAL)
    if 0.12 < t < 0.88:  # wind streaks off his body, strongest at the bottom of the swing
        n = round(2 + 5 * arc)
        for j in range(n):
            y = PAD + UPPER_DY + 10 + j * 7 + (k % 2) * 2
            x = PAD - 2 - (j * 5 + k * 3) % 9
            c.flat(R((x - 4, y, x, y)), STEEL if j % 2 else WHITE)
    return outline(c.img)


## Staff Whirl (Apex): the spin pose loop (8 frames, staff blurring round him), a ring of motion arcs and dust puffs
## on the floor (WHIRL_R art px = whirl_radius / SPRITE_SCALE; keep in sync with SpecialFx), and hit sparks.
WHIRL_FRAMES = 12
WHIRL_HAND = (50, 59)  # his fists on the staff's middle, in a CELL frame
WHIRL_STAFF = 26  # half the staff's length
WHIRL_SQUASH = 0.5  # the spin is flat on the floor in the 3/4 view
WHIRL_R = 46
WHIRL_RING = 112
WHIRL_SPARK = 20
WHIRL_SPARK_FRAMES = 7


def whirl_ends(a: float, reach: float = 1.0):
    """The staff's two tips for spin angle `a` (radians) round WHIRL_HAND."""
    hx, hy = WHIRL_HAND
    dx, dy = math.cos(a) * WHIRL_STAFF * reach, math.sin(a) * WHIRL_STAFF * reach * WHIRL_SQUASH
    return (hx + dx, hy + dy), (hx - dx, hy - dy)


def staff_bar(c, p0, p1, thick: int = 3, caps: bool = True):
    """The Cloud Staff between two points: a lit red shaft (dark underside, orange highlight), gold bands and caps,
    and a white glint on each cap."""
    (x0, y0), (x1, y1) = p0, p1
    c.flat(L([(x0, y0 + 1), (x1, y1 + 1)], thick), MAROON)
    c.flat(L([(x0, y0), (x1, y1)], thick), RED)
    c.flat(L([(x0, y0 - 1), (x1, y1 - 1)], 1), ORANGE)
    ln = math.hypot(x1 - x0, y1 - y0) or 1
    for u in (0.25, 0.75):  # gold bands
        bx, by = x0 + (x1 - x0) * u, y0 + (y1 - y0) * u
        c.flat(R((round(bx) - 1, round(by) - 1, round(bx), round(by) + 1)), YELLOW)
    if caps:
        for x, y in ((x0, y0), (x1, y1)):
            c.flat(R((round(x) - 1, round(y) - 1, round(x) + 1, round(y) + 1)), YELLOW)
            c.dot(round(x) - 1, round(y) - 1, WHITE)


def wukong_whirl_frame(k: int) -> Image.Image:
    """Apex spinning his staff (12-frame loop): legs braced and stepping, body twisting side to side, circlet tails
    and collar cloud flying back, the staff a lit shaft with a dithered wedge of motion blur dissolving behind each tip,
    glints on the caps and loose sparks / dust thrown off."""
    _, up = wukong(None, k % 4, swing=True)
    tw = math.sin(math.tau * k / WHIRL_FRAMES)
    twist = round(3 * tw)
    c = Canvas(CELL)
    c.img.alpha_composite(wukong_clouds(k % 4).img, (PAD, PAD + 2))
    low, _ = wukong(k * 8 // WHIRL_FRAMES, k % 4, swing=True)  # legs stepping
    c.img.alpha_composite(low.img, (PAD, PAD))
    c.img.alpha_composite(up.img, (PAD + twist, PAD + UPPER_DY))
    c.px = c.img.load()
    ox, oy = PAD + twist, PAD + UPPER_DY
    hx, hy = WHIRL_HAND
    c.part(L([(ox + 45, oy + 38), (hx + 2, hy - 2)], 5), YELLOW)  # front sleeve reaching across to the staff
    c.flat(L([(ox + 45, oy + 41), (hx + 1, hy + 1)], 1), ORANGE)  # sleeve's shaded underside
    for t in range(7):  # circlet tails whipping back, rippling along their length
        x = ox + 17 - 2 * t
        y = oy + 14 + round((1.0 + 0.3 * t) * math.sin(0.9 * t + math.tau * k / WHIRL_FRAMES * 2))
        c.flat(R((x - 1, y, x, y + 1)), RED if t < 5 else MAROON)
    a0 = math.pi * k / WHIRL_FRAMES
    # motion blur: a dithered wedge sweeping back from the leading edge, thinning and cooling the further behind it is
    for step in range(1, 14):
        d = step * 0.045
        (x0, y0), (x1, y1) = whirl_ends(a0 - d)
        col = YELLOW if d < 0.3 else ORANGE if d < 0.65 else RED
        for i in range(0, 27):
            u = i / 26
            x, y = round(x0 + (x1 - x0) * u), round(y0 + (y1 - y0) * u)
            if abs(u - 0.5) > 0.22 and BAYER[y % 4][x % 4] / 16 < 0.8 - d * 1.2 and (x + y + step) % 2 == 0:
                c.dot(x, y, col)
    (x0, y0), (x1, y1) = whirl_ends(a0)
    staff_bar(c, (x0, y0), (x1, y1), 3)
    for i, (x, y) in enumerate(((x0, y0), (x1, y1))):  # glint flaring on whichever cap faces the light
        if (k + i * 3) % 6 < 2:
            xr, yr = round(x), round(y)
            c.flat(L([(xr - 3, yr), (xr + 3, yr)], 1), WHITE)
            c.flat(L([(xr, yr - 3), (xr, yr + 3)], 1), WHITE)
    c.part(E((hx - 4, hy - 4, hx + 4, hy + 3)), SKIN)  # fists gripping the middle
    c.flat(R((hx - 2, hy - 1, hx + 2, hy - 1)), SKIN_D)
    c.flat(R((hx - 4, hy + 1, hx + 3, hy + 1)), YELLOW)  # cuff
    rng = random.Random(33)
    for i in range(7):  # sparks shaken loose, flying off tangentially and cooling
        ph = (k / WHIRL_FRAMES + i / 7) % 1.0
        a = a0 + rng.uniform(0, math.tau)
        dist = WHIRL_STAFF * (0.6 + 0.9 * ph)
        x, y = hx + math.cos(a) * dist, hy + math.sin(a) * dist * WHIRL_SQUASH
        c.dot(round(x), round(y), (WHITE, YELLOW, YELLOW, ORANGE, RED)[min(4, int(ph * 5))])
    return outline(c.img)


## Sky Pillar (Apex): the plant / slam pose strip (CELL frames), the pillar strip itself (PILLAR_W x PILLAR_H frames: a
## gold-banded red staff that grows from his hand along the line, crashes down with dust and floor cracks, then shrinks
## away; drawn rotated along the line and cropped to its length by SpecialFx, so keep PILLAR_W in sync) and the icon.
PILLAR_POSE_FRAMES = 9
PILLAR_FRAMES = 18
PILLAR_W, PILLAR_H = 228, 64
PILLAR_X0 = 8  # the staff's base: the line's start sits here (SpecialFx PILLAR_BASE_X)
PILLAR_LEN = 213  # 320 px / SPRITE_SCALE
PILLAR_T = 24  # 36 px wide


PILLAR_HANDS = ((50, 52), (51, 53), (53, 55), (56, 58), (57, 58), (57, 58), (57, 58), (57, 58), (56, 57))
PILLAR_TIPS = ((50, 22, 50, 74), (50, 26, 52, 70), (42, 46, 76, 66), (30, 58, 90, 58), (28, 58, 91, 58),
               (28, 58, 91, 58), (28, 58, 91, 58), (28, 58, 91, 58), (30, 57, 90, 57))


def wukong_pillar_frame(k: int) -> Image.Image:
    """Apex planting the staff (9 frames): crouched with it held high, coiling, then thrusting it out along the aim (to
    the right, mirrored by SpecialFx) while his body leans into it, recoiling on the slam and settling. The shaft is lit,
    with gold bands, cap glints, speed lines on the thrust and sparks shed from the tip."""
    _, up = wukong(None, k % 4, swing=True)
    lean = (0, 0, 1, 2, 3, 3, 2, 2, 2)[k]
    crouch = 2 if k < 3 else 0
    c = Canvas(CELL)
    c.img.alpha_composite(wukong_clouds(k % 4).img, (PAD - (2 if 2 <= k <= 4 else 0), PAD + 2))
    low, _ = wukong(None, k % 4, swing=True)
    c.img.alpha_composite(low.img, (PAD, PAD + crouch))
    recoil = 1 if k == 4 else 0
    c.img.alpha_composite(up.img, (PAD + lean, PAD + UPPER_DY + crouch + recoil))
    c.px = c.img.load()
    ox, oy = PAD + lean, PAD + UPPER_DY + crouch + recoil
    hx, hy = PILLAR_HANDS[k]
    x0, y0, x1, y1 = PILLAR_TIPS[k]
    for i in range(6):  # circlet tails whipping back with the thrust
        x = ox + 17 - 2 * i - (2 if k in (3, 4) else 0)
        y = oy + 14 + round((0.8 + 0.3 * i) * math.sin(0.9 * i + k))
        c.flat(R((x - 1, y, x, y + 1)), RED if i < 4 else MAROON)
    c.part(L([(ox + 45, oy + 38), (hx, hy - 2)], 5), YELLOW)  # front sleeve reaching the staff
    c.flat(L([(ox + 45, oy + 41), (hx - 1, hy + 1)], 1), ORANGE)
    if k in (2, 3):  # speed lines streaking along the thrust
        for i in range(4):
            c.flat(R((x0 - 8 + i * 3, y0 + (i - 2) * 5 + 8, x0 - 3 + i * 3, y0 + (i - 2) * 5 + 8)), WHITE if i % 2 else STEEL)
    staff_bar(c, (x0, y0), (x1, y1), 3)
    c.part(E((hx - 4, hy - 4, hx + 4, hy + 3)), SKIN)  # fists gripping
    c.flat(R((hx - 2, hy - 1, hx + 2, hy - 1)), SKIN_D)
    c.flat(R((hx - 4, hy + 1, hx + 3, hy + 1)), YELLOW)
    if k >= 3:  # sparks shed from the tip as it leaves, rising and cooling
        for i, (dx, dy) in enumerate(((-3, -6), (2, 5), (-1, 8), (3, -3), (-4, 2))):
            ph = (k - 3 + i * 0.7) % 4
            c.dot(x1 + dx - 5 + round(ph), y1 + dy - round(ph), (WHITE, YELLOW, ORANGE, RED)[min(3, int(ph))])
    return outline(c.img)


# Sky Pillar strip (18 frames): the staff grows out of his hand lifting off the floor (0-5), slams down flat on frame 6
# (u = 1/3 of the skill: the windup), the impact rings out with dust, cracks and flying chips (7-9), then it shrinks
# away while cracks cool and dust settles (10-16), last wisps (17).
PILLAR_LEN_K = (36, 76, 116, 156, 196, PILLAR_LEN, PILLAR_LEN, PILLAR_LEN, PILLAR_LEN, PILLAR_LEN, 190, 160, 125, 90, 55, 25, 0, 0)
PILLAR_THICK_K = (5, 8, 11, 14, 18, 21, PILLAR_T, PILLAR_T, PILLAR_T, PILLAR_T, 20, 17, 14, 10, 7, 4, 0, 0)
PILLAR_LIFT_K = (12, 12, 12, 11, 9, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)


def sky_pillar_frame(k: int) -> Image.Image:
    n = PILLAR_W
    c = Canvas(n)
    m = n // 2
    length, thick, lift = PILLAR_LEN_K[k], PILLAR_THICK_K[k], PILLAR_LIFT_K[k]
    x0 = PILLAR_X0
    age = k - 6  # frames since the slam
    # cracks in the floor along both edges of the line, from the slam on: they glow, cool and fade out
    if age >= 0:
        rng = random.Random(11)
        reach = (4, 6, 8, 9, 9, 9, 8, 7, 6, 5, 4, 3)[age]
        for i in range(0, PILLAR_LEN - 6, 12):
            for side in (-1, 1):
                x = x0 + 8 + i + rng.randint(-3, 3)
                if age >= 5 and rng.random() < (age - 4) * 0.12:
                    continue
                y = m + side * (PILLAR_T // 2)
                pts = [(x, y)]
                for j in range(4):
                    x += rng.randint(-3, 3)
                    y += side * max(2, reach // 3)
                    pts.append((x, y))
                col = ORANGE if age < 2 else RED if age < 4 else SHADOW if age < 9 else STEEL_D
                c.flat(L(pts, 1), OUTLINE if age >= 4 else col)
                if age < 4:
                    c.flat(L(pts[:3], 1), YELLOW if age < 1 else col)
                if rng.random() < 0.3 and age < 8:  # a side crack
                    bx, by = pts[2]
                    c.flat(L([(bx, by), (bx + rng.randint(-4, 4), by + side * 3)], 1), OUTLINE if age >= 4 else RED)
        if age < 6:
            c.flat(R((x0, m - PILLAR_T // 2 - 1, x0 + PILLAR_LEN, m + PILLAR_T // 2 + 1)), SHADOW)  # scorched under the staff
    if length > 0:
        cy = m - lift
        top, bot = cy - thick // 2, cy + thick // 2 - 1
        if lift:  # the shadow it casts on the floor, shrinking as it comes down
            c.flat(R((x0 + 4, m - thick // 2 + 3, x0 + length - 4, m + thick // 2 + 3)), SHADOW)
        if k < 6:  # a trail of embers streaming behind the growing tip
            for i in range(9):
                tx = x0 + length - 6 - i * 9
                if tx > x0 + 6:
                    c.dot(tx, cy + ((i * 5 + k * 3) % 7) - 3, (WHITE, YELLOW, ORANGE, RED)[min(3, i // 2)])
        c.part(R((x0, top, x0 + length, bot)), RED)
        c.flat(R((x0 + 3, top + 2, x0 + length - 3, top + 3)), ORANGE)  # the light running along the top
        c.flat(R((x0 + 3, top + 4, x0 + length - 3, top + 4)), YELLOW) if thick >= 16 else None
        c.flat(R((x0 + 2, bot - 2, x0 + length - 2, bot - 1)), MAROON)  # shaded underside
        for x in range(x0 + 20, x0 + length - 10, 40):  # gold bands
            w = max(2, thick // 5)
            c.part(R((x, top - 1, x + w, bot + 1)), YELLOW)
            c.flat(R((x, top - 1, x, top - 1)), WHITE)
        c.part(R((x0 + length - 8, top - 1, x0 + length, bot + 1)), YELLOW)  # tip cap
        c.part(R((x0 - 6, top - 1, x0, bot + 1)), YELLOW)  # grip cap, where his fists were
        if 10 > k >= 6 and length == PILLAR_LEN:  # lightning crackling along the shaft after the slam
            rng = random.Random(k)
            for j in range(3):
                lx = x0 + 15 + j * 70 + rng.randint(-10, 10)
                pts = [(lx, top - 1)] + [(lx + rng.randint(-3, 3), top - 1 - s * 2) for s in range(1, 4)]
                if age < 3:
                    c.flat(L(pts, 1), WHITE if age < 1 else YELLOW)
        if k == 6:  # slam flash: white edges, bright staff and a burst at the tip
            c.flat(R((x0, top, x0 + length, top)), WHITE)
            c.flat(R((x0, bot, x0 + length, bot)), WHITE)
            c.flat(R((x0 + 3, top + 2, x0 + length - 3, top + 3)), WHITE)
            for i in range(8):
                c.dot(x0 + length + 2 + i % 2, cy - 8 + i * 2, WHITE if i % 2 else YELLOW)
    if age >= 0 and age <= 5:  # shock ring racing out of the tip, squashed for the 3/4 view
        rx, ry = 6 + 6 * age, 3 + 2 * age
        tipx = x0 + PILLAR_LEN - 4
        for a in range(0, 24):
            ang = math.tau * a / 24
            if tipx + math.cos(ang) * rx < n - 3:
                c.dot(round(tipx + math.cos(ang) * rx), round(m + math.sin(ang) * ry), (WHITE, YELLOW, STEEL, STEEL, STEEL_D, SHADOW)[age])
    if 0 <= age <= 8:  # dust kicked up along both sides, rising and thinning
        rng = random.Random(5)
        for i in range(0, PILLAR_LEN - 30, 20):
            for side in (-1, 1):
                r = round((5 + rng.randint(0, 3)) * (1.0 - age / 10))
                px = x0 + 10 + i + rng.randint(-4, 4)
                py = m + side * (PILLAR_T // 2 + 3 + age) - age * (2 if side < 0 else 1)
                py = min(max(py, m - PILLAR_H // 2 + r + 3), m + PILLAR_H // 2 - r - 4)
                if r >= 1:
                    c.part(blobs([(px, py, r), (px - r, py + 1, max(1, r - 2)), (px + r - 1, py + 1, max(1, r - 3))]),
                           WHITE if age < 3 else STEEL, shade=age > 1, line=False)
    if 0 <= age <= 5:  # chips of floor flung up from the cracks, arcing back down
        rng = random.Random(8)
        for j in range(12):
            bx = x0 + 12 + rng.randint(0, PILLAR_LEN - 30)
            side = 1 if j % 2 else -1
            up = 10 + rng.randint(0, 8)
            y = m + side * (PILLAR_T // 2 + 2) - side * (up * age - 2.2 * age * age) * 0.5
            if 8 < y < PILLAR_H + m - 8 and abs(y - m) < PILLAR_H // 2 - 4:
                c.dot(bx + age * side, round(y), BROWN if j % 3 else STEEL)
    if k == 17:  # last wisps
        for i in range(8):
            c.dot(x0 + 20 + i * 24, m - 14 + (i % 3) * 14, STEEL)
    return outline(c.img.crop((0, m - PILLAR_H // 2, n, m + PILLAR_H // 2)))


def whirl_ring_frame(k: int) -> Image.Image:
    """The spin seen from above, flat on the floor (12-frame loop): a scuffed floor ring, three tapering arcs racing
    round the rim with glints on their heads, a faint dashed inner ring turning the other way, and dust / cloud puffs
    kicked up that drift out, swell and thin. Loops: frame k+12 = frame 0."""
    size = WHIRL_RING
    c = Canvas(size)
    m = size // 2
    rx, ry = WHIRL_R, WHIRL_R * 0.8
    spin = math.tau * k / WHIRL_FRAMES
    for n in range(72):  # a dithered scuff band on the floor just inside the rim
        a = math.tau * n / 72
        if n % 2 == 0:
            c.dot(round(m + math.cos(a) * (rx - 5)), round(m + math.sin(a) * (ry - 4)), SHADOW)
    for i in range(3):  # arcs: a bright head with a tail fading behind it
        head = spin + math.tau * i / 3
        for j, col in enumerate((WHITE, YELLOW, YELLOW, ORANGE, ORANGE, RED)):
            for sub in range(6):
                a = head - (j * 6 + sub) * 0.035
                c.dot(round(m + math.cos(a) * rx), round(m + math.sin(a) * ry), col)
                c.dot(round(m + math.cos(a) * (rx - 1.5)), round(m + math.sin(a) * (ry - 1.5)), col)
                if j < 4:
                    c.dot(round(m + math.cos(a) * (rx + 1.5)), round(m + math.sin(a) * (ry + 1.5)), col)
        hxx, hyy = round(m + math.cos(head) * rx), round(m + math.sin(head) * ry)
        c.flat(L([(hxx - 2, hyy), (hxx + 2, hyy)], 1), WHITE)  # glint on the head
        c.dot(hxx, hyy - 2, WHITE)
        c.dot(hxx, hyy + 2, YELLOW)
    for n in range(24):  # inner dashes turning the other way
        if n % 2:
            continue
        a = -spin + math.tau * n / 24
        c.dot(round(m + math.cos(a) * rx * 0.72), round(m + math.sin(a) * ry * 0.72), STEEL if n % 4 else STEEL_D)
    for i in range(7):  # puffs: born at the rim, drift outward, swell then shrink; each lives the whole loop
        ph = ((k + WHIRL_FRAMES / 7 * i * 1.0) % WHIRL_FRAMES) / WHIRL_FRAMES
        a = 1.1 + math.tau * i / 7
        d = 0.85 + 0.22 * ph
        r = round(1 + 4 * math.sin(math.pi * min(1.0, ph * 1.15)))
        x, y = m + math.cos(a) * rx * d, m + math.sin(a) * ry * d + 4 - 7 * ph
        if r >= 1:
            c.part(blobs([(x + 1, y + 1, r)]), STEEL_D, shade=False, line=False)
            c.part(blobs([(x, y, r)]), WHITE if ph < 0.6 else STEEL, shade=r >= 3, line=False)
    return outline(c.img)


def whirl_spark_frame(k: int) -> Image.Image:
    """A hit spark (7 frames): a white flash and ring, then a burst of chips with tails flying out, dimming and falling."""
    c = Canvas(WHIRL_SPARK)
    m = WHIRL_SPARK // 2
    if k < 3:
        c.flat(E((m - 3 + k, m - 3 + k, m + 3 - k, m + 3 - k)), WHITE)
    col = (WHITE, WHITE, YELLOW, YELLOW, ORANGE, ORANGE, RED)[k]
    for j in range(8):
        ang = math.tau * j / 8 + 0.5
        d0, d1 = 1 + 0.5 * k, 2 + 0.6 * k
        fall = 0.06 * k * k
        c.flat(L([(m + math.cos(ang) * d0, m + math.sin(ang) * d0 + fall),
                  (m + math.cos(ang) * d1, m + math.sin(ang) * d1 + fall)], 1), col if j % 2 else (WHITE if k < 3 else col))
    return outline(c.img)


def vine() -> Image.Image:
    """A hanging jungle vine, top (pivot) to bottom: a twisting, lit brown stem (light edge on the left, dark on the
    right, knots and bark twist) with paired two-tone leaves, curling tendrils, and the odd red berry.
    Drawn from the pivot down to his fist, cropped to length."""
    c = Canvas(VINE_LEN + 2)
    m = VINE_W // 2
    sx = lambda y: m + round(1.5 * math.sin(y / 9))  # the stem wanders a little
    c.part(L([(sx(y), y) for y in range(3, VINE_LEN)], 3), BROWN, shade=False)
    for y in range(3, VINE_LEN):
        c.dot(sx(y) - 1, y, SKIN_D)  # light catching the left edge
        c.dot(sx(y) + 1, y, MAROON)  # shade down the right
    for y in range(4, VINE_LEN, 6):  # bark twist
        c.dot(sx(y) + (y // 6) % 2 - 1, y, MAROON)
        c.dot(sx(y) + (y // 6) % 2, y + 1, SKIN_D)
    for y in range(20, VINE_LEN - 10, 37):  # knots
        c.flat(R((sx(y) - 2, y, sx(y) + 2, y + 2)), BROWN)
        c.dot(sx(y) - 2, y, SKIN_D)
        c.dot(sx(y) + 2, y + 2, MAROON)
    for i, y in enumerate(range(10, VINE_LEN - 8, 17)):
        x = sx(y)
        side = 1 if i % 2 else -1
        tip = (x + side * 6, y + 5)
        c.part(P([(x, y), (x + side * 3, y - 2), tip, (x + side * 2, y + 4)]), TEAL)
        c.flat(P([(x + side, y), (x + side * 3, y - 1), (x + side * 5, y + 3), (x + side * 2, y + 1)]), TEAL_L)  # lit half
        c.flat(L([(x + side, y + 1), (x + side * 5, y + 4)], 1), TEAL_L if i % 2 else TEAL)  # leaf vein
        if i % 3 == 2:  # a tendril curling off the other side
            c.flat(L([(x - side, y + 6), (x - side * 3, y + 7), (x - side * 4, y + 5), (x - side * 3, y + 4)], 1), TEAL)
        if i % 4 == 1:  # a berry on a short stalk
            c.flat(L([(x - side, y + 3), (x - side * 3, y + 5)], 1), BROWN)
            c.flat(E((x - side * 5, y + 5, x - side * 3, y + 7)), RED)
            c.dot(x - side * 5, y + 5, ORANGE)
    return outline(c.img).crop((0, 0, VINE_W, VINE_LEN + 2))


def vine_top() -> Image.Image:
    """The leafy clump the vine hangs from, drawn over the pivot: a mass of leaves round a stub of branch."""
    c = Canvas(48)
    c.part(L([(4, 22), (18, 20), (30, 22), (44, 19)], 3), BROWN)
    rng = random.Random(7)
    clumps = [(24 + rng.randint(-16, 16), 21 + rng.randint(-6, 5), rng.randint(4, 7)) for _ in range(11)]
    c.part(blobs([(x + 1, y + 2, r) for x, y, r in clumps]), NAVY, shade=False)
    c.part(blobs(clumps), TEAL)
    for x, y, r in clumps[::2]:
        c.part(E((x - r // 2, y - r // 2 - 1, x + r // 3, y)), TEAL_L, shade=False, line=False)
    return outline(c.img).crop((0, 8, 48, 40))


def leaf_burst_frame(k: int) -> Image.Image:
    """Takeoff: a cloud puff swells where he pushes off, then bursts, flinging leaves out that tumble and drift
    down while the puff breaks into wisps."""
    size = 64
    rng = random.Random(11)
    leaves = [(math.tau * i / 14 + rng.uniform(-0.2, 0.2), rng.uniform(0.7, 1.1), rng.randint(0, 3)) for i in range(14)]
    c = Canvas(size)
    m = size // 2
    grow = min(1.0, (k + 1) / 3)
    burst = max(0.0, (k - 1) / (LEAF_FRAMES - 2))
    lumps = [(m + math.cos(a) * size * (0.1 + 0.18 * burst), m + 6 + math.sin(a) * size * (0.06 + 0.1 * burst),
              round(size * 0.12 * grow * (1 - 0.85 * burst))) for a in (0.3, 1.5, 2.6, 3.7, 4.9, 5.8)]
    lumps = [p for p in lumps if p[2] >= 1]
    if lumps:
        c.part(blobs(lumps), WHITE)
    if burst > 0.0:
        for a, reach, spin in leaves:
            d = size * (0.12 + 0.3 * reach * math.sqrt(burst))
            x, y = m + math.cos(a) * d, m + math.sin(a) * d * 0.8 + size * 0.12 * burst * burst  # flutter down
            if y > size - 6 or x < 5 or x > size - 6:
                continue
            if burst > 0.85 and spin % 2:
                continue  # the last ones drift off out of sight
            ang = a + (spin + k) * 0.9
            dx, dy = math.cos(ang), math.sin(ang)
            pts = [(x - dx * 3, y - dy * 3), (x - dy * 1.5, y + dx * 1.5), (x + dx * 3, y + dy * 3),
                   (x + dy * 1.5, y - dx * 1.5)]
            c.part(P([(round(px), round(py)) for px, py in pts]), TEAL_L if spin == 0 else TEAL, shade=False)
            c.dot(round(x), round(y), TEAL if spin == 0 else TEAL_L)  # vein / lit midrib
            if k < 4 and spin % 2:
                c.dot(round(x + dy * 3), round(y - dx * 3), WHITE if k % 2 else YELLOW)  # glints
    return outline(c.img)


def dust_frame(k: int) -> Image.Image:
    """Landing: a low ring of dust puffed out sideways along the floor from under his feet, a few pebbles hop out,
    and it thins away (squashed for the 3/4 view)."""
    size = 64
    rng = random.Random(3)
    puffs = [(rng.choice((-1, 1)) * rng.uniform(0.2, 1.0), rng.uniform(0.8, 1.2)) for _ in range(12)]
    c = Canvas(size)
    m = size // 2
    t = k / (DUST_FRAMES - 1)
    spread = size * (0.1 + 0.22 * math.sqrt(t))
    r = size * 0.1 * (1.15 - t) if k else size * 0.06
    pts = [(m + side * spread, m + 8 - size * 0.06 * t * abs(side), round(r * rr)) for side, rr in puffs]
    pts = [p for p in pts if p[2] >= 1]
    if pts:
        c.part(blobs([(x + 1, y + 1, rr) for x, y, rr in pts]), STEEL_D, shade=False)
        c.part(blobs(pts), STEEL)
        if t < 0.5:
            c.part(blobs([(x, y - 1, max(1, rr // 2)) for x, y, rr in pts[::2]]), WHITE, shade=False, line=False)
    if 0.0 < t < 0.8:
        for i, side in enumerate((-1, 1, -1, 1, -1, 1)):
            x = m + side * size * (0.12 + 0.1 * i / 5 + 0.18 * t)
            y = m + 6 - size * 0.25 * math.sin(math.pi * t) * (0.6 + 0.2 * i)
            c.flat(R((round(x), round(y), round(x) + 1, round(y))), BROWN)
    return outline(c.img)


def ape_morph(t: float, scale: float) -> Image.Image:
    """An in-between creature, `t` of the way from Wukong to the Great Ape, drawn crisp at `scale` x (a CELL
    frame centred like a scaled sprite): every body part's shape is interpolated between the two designs
    (legs thicken and splay, the torso swells into a hunched back, arms and fists sprout, the head pushes
    forward, the circlet tilts), and fur / face / eyes switch to the ape's halfway."""
    c = Canvas(CELL)
    k = CELL / 2

    def pt(p0, p1, dy=0):  # interpolate a point (art px) and map it into the scaled cell
        return (k + (p0[0] + (p1[0] - p0[0]) * t - 32) * scale, k + (p0[1] + (p1[1] - p0[1]) * t + dy - 32) * scale)

    def pts(a, b, dy=0):
        return [pt(p0, p1, dy) for p0, p1 in zip(a, b)]

    def box(a, b, dy=0):
        (x0, y0), (x1, y1) = pt(a[:2], b[:2], dy), pt(a[2:], b[2:], dy)
        return (x0, y0, x1, y1)

    def w(a, b):
        return max(1, round((a + (b - a) * t) * scale))

    ape = t >= 0.55  # face, eyes and chest turn; the fur darkens a step earlier so changes are staggered
    fur = MAROON if t >= 0.4 else BROWN
    face_c = BROWN if ape else SKIN
    u = UPPER_DY

    def shrink(points, r):  # Wukong-only bits shrink away towards their first point by t = r
        f = max(0.0, 1 - t / r)
        x0, y0 = points[0]
        return [pt((x0 + (x - x0) * f, y0 + (y - y0) * f), (x0 + (x - x0) * f, y0 + (y - y0) * f), u) for x, y in points]

    ape_face = (28, 11, 50, 29)

    def on_face(points, ape_side=False):  # face details ride the face as it slides and shrinks into the ape's
        fa, fb = (ape_face, FACE) if ape_side else (FACE, ape_face)
        other = [(fb[0] + (x - fa[0]) * (fb[2] - fb[0]) / (fa[2] - fa[0]),
                  fb[1] + (y - fa[1]) * (fb[3] - fb[1]) / (fa[3] - fa[1])) for x, y in points]
        return pts(other, points, u) if ape_side else pts(points, other, u)

    def sub_box(b, rel, size):  # rel = (x0, y0, x1, y1) inside a part `size` art px wide/high, mapped onto box b
        sx, sy = (b[2] - b[0]) / size[0], (b[3] - b[1]) / size[1]
        return (b[0] + rel[0] * sx, b[1] + rel[1] * sy, b[0] + rel[2] * sx, b[1] + rel[3] * sy)

    # dark storm clouds gather: ape_storm's puffs drift in from further out, swelling one after another
    for j, (x, y, r) in enumerate(((9, 28, 6), (14, 19, 5), (8, 39, 5), (10, 48, 4), (21, 11, 4), (55, 20, 4),
                                   (58, 31, 3), (50, 12, 3))):
        g = min(1.0, max(0.0, (t - 0.05 * j) / 0.6))  # this puff's growth
        if g > 0:
            push = (1 - g) * 10
            dx = push if x > 32 else -push  # drift in from the sides
            cx, cy = pt((x + dx, y), (x + dx, y))
            rr = max(1, r * g * scale)
            c.part(E((cx - rr, cy - rr, cx + rr, cy + rr)), SHADOW)
    if t < 0.45:  # pheasant feathers retract
        c.part(L(shrink([(25, 10), (16, 4), (6, 6)], 0.45), w(2, 2)), RED, shade=False)
        c.part(L(shrink([(29, 9), (24, 3), (14, 2)], 0.45), w(2, 2)), RED, shade=False)
    if t > 0.5:  # bristling back fur pushes up
        for x, y in ((14, 18), (20, 13), (27, 11)):
            c.part(P(pts([(x + 3, y + 7), (x + 3, y + 5), (x + 3, y + 7)], [(x, y + 5), (x + 3, y), (x + 6, y + 5)], u)),
                   MAROON)
    # tail: Wukong's curl stretches into the ape's
    c.part(L(pts([(21, 44), (11, 45), (6, 40), (7, 33), (11, 31)], [(14, 40), (9, 39), (6, 38), (4, 31), (8, 27)], u),
             w(3, 3)), fur)
    for x0, x1 in ((24, 21), (34, 35)):  # legs thicken and splay; feet broaden
        c.part(P(pts([(x0, 45), (x0 + 5, 45), (x0 + 5, 54), (x0, 54)],
                     [(x1, 44), (x1 + 8, 44), (x1 + 9, 54), (x1 - 1, 54)])), MAROON if ape else RED)
        if not ape:
            c.flat(R(box((x0, 50, x0 + 6, 50), (x1, 50, x1 + 8, 50))), YELLOW)  # leg wraps
        if t > 0.4:  # the big toe splays out
            c.part(E(box((x0 + 1, 54, x0 + 2, 57), (x1 - 5, 54, x1, 58))), BROWN)
        foot = box((x0 - 1, 53, x0 + 7, 57), (x1 - 2, 53, x1 + 10, 58))
        c.part(RR(foot, w(2, 2)), BROWN)
        c.flat(R((foot[0] + scale, foot[3], foot[2] - scale, foot[3])), SHADOW)  # sole
        if ape:
            for tx in (6, 9):  # toe creases
                c.flat(R(sub_box(foot, (tx, 3, tx, 5), (12, 5))), OUTLINE)
    # the hunched back swells out from behind the armour
    c.part(E(box((20, 31, 44, 48), (10, 14, 54, 45), u)), fur)
    # the golden armour shrinks into the ape's chest
    c.part(RR(box((20, 33, 44, 48), (22, 26, 44, 43), u), w(3, 8)), BROWN if ape else YELLOW)
    if not ape:
        armour = box((20, 33, 44, 48), (22, 26, 44, 43), u)
        on_armour = lambda q: [(armour[0] + x * (armour[2] - armour[0]) / 24, armour[1] + y * (armour[3] - armour[1]) / 15)
                               for x, y in q]
        c.flat(R(box((31, 36, 33, 44), (32, 30, 34, 39), u)), ORANGE)  # the armour's centre line
        # the armour cracks, then chunks break away one by one, showing the dark fur swelling underneath
        for j, (crack, chunk) in enumerate(APE_ARMOUR_BREAKS):
            if t > 0.15 + 0.07 * j:
                c.flat(L(on_armour(crack), max(1, round(scale))), OUTLINE)
            if t > 0.3 + 0.07 * j:
                c.part(P(on_armour(chunk)), BROWN if j % 2 else MAROON)
        c.part(R(box((20, 44, 44, 46), (22, 40, 44, 42), u)), RED, line=False)  # sash
        c.part(P(shrink([(22, 45), (17, 52), (21, 52), (25, 46)], 0.55)), RED)  # sash tail tucks away
    # arms and fists grow out from the sides of the body, poking out on the first in-between; the back arm
    # swings across the chest into the ape's knuckle-walk
    for start, arm in zip(([(21, 35), (16, 39), (15, 43)], [(43, 35), (48, 39), (49, 43)]), APE_POSES["walk"][0]):
        (sx, sy), (ex, ey), (wx, wy) = pts(start, arm, u)
        c.part(L([(sx, sy), (ex, ey), (wx, wy)], w(4, 9)), fur)
        # the muscles swell with it (wukong_ape's deltoid, bicep, forearm)
        for (mx, my), rx, ry in (((sx, sy), w(2, 6), w(2, 6)), (((sx + ex) / 2, (sy + ey) / 2), w(2, 6), w(2, 5)),
                                 (((ex * 2 + wx) / 3, (ey * 2 + wy) / 3), w(2, 5), w(2, 4))):
            c.part(E((mx - rx, my - ry, mx + rx, my + ry)), fur)
    for x0, (x1, y1, _thumb) in zip((11, 46), APE_POSES["walk"][1]):
        if ape:
            c.part(R(box((x0 + 1, 41, x0 + 6, 42), (x1 + 2, y1 - 4, x1 + 10, y1 - 1), u)), YELLOW)
        fist = box((x0, 42, x0 + 7, 48), (x1, y1, x1 + 12, y1 + 11), u)
        c.part(RR(fist, w(2, 3)), SKIN if t < 0.3 else fur)  # Wukong's hands, then furry fists
        if t >= 0.3:
            c.part(E(sub_box(fist, (_thumb, 1, _thumb + 5, 6), (12, 11))), fur)  # thumb over the fingers
        c.flat(RR(box((x0 + 1, 45, x0 + 6, 48), (x1 + 1, y1 + 6, x1 + 11, y1 + 11), u), w(1, 1)),
               SKIN_D if t < 0.3 else BROWN)  # curled fingers
        if ape:
            c.flat(R(sub_box(fist, (1, 6, 11, 6), (12, 11))), OUTLINE)
            for kx in (4, 7):  # knuckle splits
                c.flat(R(sub_box(fist, (kx, 6, kx, 11), (12, 11))), OUTLINE)
    # head: Wukong's round head pushes forward and shrinks into the ape's
    if t < 0.75:
        c.part(E(box((11, 17, 21, 28), (20, 10, 28, 20), u)), fur)  # ear tucks in
        c.flat(E(box((14, 20, 18, 25), (22, 13, 26, 17), u)), SKIN_D if t < 0.4 else BROWN)
    for x in (24, 31, 38):  # Wukong's fur tufts flatten into the ape's head
        c.part(P(shrink([(x + 3, 9), (x, 9), (x + 3, 4), (x + 6, 9)], 0.6)[1:]), fur) if t < 0.6 else None
    c.part(E(box((15, 6, 49, 38), (24, 3, 50, 29), u)), fur)
    fb = box(FACE, ape_face, u)
    c.part(RR(fb, w(FACE_R, FACE_R)), face_c)
    if not ape:  # red rises up his face from the chin as his rage builds, its edge dithered so it climbs smoothly
        level = fb[3] - (fb[3] - fb[1] + 4) * min(1.0, max(0.0, (t - 0.1) / 0.35))
        flush = {SKIN: RED, SKIN_D: MAROON, WHITE: ORANGE}
        px = c.img.load()
        for y in range(int(fb[1]), int(fb[3]) + 1):
            for x in range(int(fb[0]), int(fb[2]) + 1):
                col = px[x, y][:3]
                if px[x, y][3] and col in flush and y + 4 * BAYER[y % 4][x % 4] / 16 > level:
                    px[x, y] = flush[col] + (255,)
    if not ape:  # spiky fringe, blush and mouth ride the face
        c.part(P(on_face([(23, 16), (47, 16), (47, 18), (43, 19), (39, 17), (35, 19), (30, 17), (26, 19), (23, 18)])),
               fur, shade=False)
        if t < 0.15:  # his blush, until the anger takes over
            for bx in ((BLUSH[0], BLUSH[2], BLUSH[0] + 2, BLUSH[2]), (BLUSH[1], BLUSH[2], BLUSH[1] + 1, BLUSH[2])):
                c.flat(R(tuple(v for q in on_face([bx[:2], bx[2:]]) for v in q)), ORANGE)
        c.flat(R(tuple(v for q in on_face([MOUTH, (MOUTH[0] + 1, MOUTH[1])]) for v in q)), OUTLINE if t >= 0.3 else MAROON)
        if t > 0.2:  # angry brows come down, slanting in towards the middle
            for brow in ([(EYES_X[0] - 1, 18), (EYES_X[0] + 4, 20)], [(EYES_X[1] + 4, 18), (EYES_X[1] - 1, 20)]):
                c.flat(L(on_face(brow), w(1, 1)), OUTLINE)
    else:  # nostrils and grim mouth push in
        for bx in ((38, 21, 39, 21), (42, 21, 43, 21), (34, 25, 46, 26)):
            c.flat(R(tuple(v for q in on_face([bx[:2], bx[2:]], ape_side=True) for v in q)), OUTLINE)
    collar = ((11, 31, 3), (15, 35, 5), (21, 38, 4), (26, 39, 3), (43, 38, 3), (47, 36, 4))
    for x, y, r in collar:  # the cloud collar puffs away
        rr = r * scale * (1 - t / 0.5)
        if rr >= 1:
            cx, cy = pt((x, y), (x, y), u)
            c.part(E((cx - rr, cy - rr, cx + rr, cy + rr)), WHITE, line=False)
    # the circlet tilts askew, keeping its gold and gem, and cracks spread across it one by one
    c.part(P(pts([(17, 13), (47, 13), (47, 16), (17, 16)], APE_CIRCLET, u)), YELLOW)
    gx, gy = pt((32, 14), (35, 7), u)
    c.flat(R((gx, gy, gx + w(1, 1), gy)), RED)
    def on_wukong_band(x, y):  # the same spot on Wukong's straight band (17..47, 13..16)
        f = (x - 23) / 24
        return 17 + 30 * f, 13 + 3 * (y - (8 - 4 * f)) / 5

    for j, crack in enumerate(APE_CRACKS):
        if t > 0.25 + 0.15 * j:
            c.flat(L(pts([on_wukong_band(x, y) for x, y in crack], crack, u), max(1, round(scale))), OUTLINE)
    if t > 0.85:  # a corner chips off
        chip = [(43, 4), (47, 4), (47, 6)]
        c.flat(P(pts([on_wukong_band(x, y) for x, y in chip], chip, u)), OUTLINE)
    for x0, x1 in ((EYES_X[0], 32), (EYES_X[1], 42)):  # eyes slide and narrow; turn red and angry halfway
        ex, ey = pt((x0, 22), (x1, 14), u)
        eh = w(6, 3)
        ew = w(3, 3)
        if ape:
            c.flat(R((ex, ey, ex + ew, ey + eh)), OUTLINE)
            c.flat(R((ex, ey + 1, ex + ew, ey + eh - 1)), RED)
            c.dot(round(ex + scale), round(ey + 1), ORANGE)  # glow
        else:
            c.flat(R((ex, ey, ex + ew, ey + eh)), OUTLINE)
            c.flat(R((ex, ey + eh - 2, ex + ew, ey + eh - 1)), YELLOW)
            c.dot(round(ex), round(ey), WHITE)
    if ape:  # scowl and fangs push in
        for bx in ((29, 11, 37, 14), (48, 11, 40, 14)):
            c.flat(L(pts([bx[:2], bx[2:]], [bx[:2], bx[2:]], u), w(1, 2)), OUTLINE)
        for fx in (35, 43):
            c.flat(P(pts([(fx, 27), (fx + 3, 27), (fx + 2, 25), (fx + 1, 25)],
                         [(fx, 27), (fx + 3, 27), (fx + 2, 23), (fx + 1, 23)], u)), WHITE)
    return outline(c.img)


def morph_frames(a: Image.Image, b: Image.Image, b_scale: float, between) -> list[Image.Image]:
    """Transformation from a character's frame `a` into its form `b` (drawn `b_scale` x in game), in full colour:
    ten in-between creatures (`between(t, scale)`, e.g. ape_morph) that stretch, swell and grow, with gold sparks crackling. CELL-sized
    frames with the growth baked in, drawn at the normal sprite scale (SpecialFx) so pixels stay crisp."""
    rng = random.Random(7)

    def at(img, sc):  # img scaled (NEAREST) about the cell centre
        n = round(SIZE * sc)
        out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        out.alpha_composite(img.resize((n, n), Image.NEAREST), ((CELL - n) // 2, (CELL - n) // 2))
        return out

    def sparks(img, n=5):  # short gold crackles inside the body
        px = img.load()
        inside = [(x, y) for y in range(CELL) for x in range(CELL) if px[x, y][3]]
        for x, y in rng.sample(inside, n):
            dx, dy = rng.choice(((1, 0), (0, 1), (1, 1), (1, -1)))
            for j in range(3):
                if 1 < x + dx * j < CELL - 2 and 1 < y + dy * j < CELL - 2:
                    px[x + dx * j, y + dy * j] = YELLOW + (255,)
        return img

    steps = tuple((i + 1) / 11 for i in range(10))
    return [at(a, 1.0)] + [sparks(between(t, 1 + (b_scale - 1) * t)) for t in steps] + [at(b, b_scale)]


BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def smoke_frame(k: int, size: int = 136) -> Image.Image:
    """Smoke Bomb cloud, drawn like the clone poof but dark: lumps spread through the cloud over a darker shadow
    layer, each its own part drawn back to front (outlined where they overlap, so they read as separate puffs), light
    catching their tops, wisps rising off the top and thinning away. Loops over SMOKE_FRAMES: the outer ring turns two
    lumps' worth (big and small alternate, so one would pop), the inner lumps churn the other way, all breathing."""
    c = Canvas(size)
    m = size // 2
    phase = k / SMOKE_FRAMES  # 0..1 round the loop
    turn = math.tau / 10 * 2 * phase
    lumps = []  # spread through the whole cloud: an outer ring and a few inside, all breathing
    for i in range(10):
        ang = math.tau * i / 10 + turn
        reach = 34 + 4 * math.sin(math.tau * phase + i)
        lumps.append((m + math.cos(ang) * reach, m + math.sin(ang) * reach,
                      17 + 4 * (i % 2) + 2 * math.sin(math.tau * phase + i * 1.7)))
    for i in range(5):
        ang = math.tau * i / 5 - math.tau / 5 * phase + 0.3
        lumps.append((m + math.cos(ang) * 14, m + math.sin(ang) * 12, 16 + 2 * math.sin(math.tau * phase + i * 2)))
    blob = lambda pts: lambda dr, f: [dr.ellipse((x - r, y - r, x + r, y + r), f) for x, y, r in pts]
    sh = 4  # the shadow layer sits down and right of the lumps
    c.part(blob([(x + sh, y + sh, r) for x, y, r in lumps]), OUTLINE, shade=False)
    for x, y, r in sorted(lumps, key=lambda p: p[1]):  # back to front: lower lumps overlap the ones behind
        c.part(E((x - r, y - r, x + r, y + r)), SHADOW)
        if x + y < 2 * m + 10:  # light catching the tops facing up-left
            c.flat(E((x - r * 0.55, y - r * 0.7, x - r * 0.1, y - r * 0.45)), STEEL_D)
    for i in range(3):  # wisps rising off the top, shrinking as they go, one after another
        w = (phase + i / 3) % 1.0
        x = m - 24 + 24 * i + 4 * math.sin(math.tau * w)
        y = m - 46 - 18 * w
        r = round(6 * (1 - w))
        if r >= 1:
            c.part(E((x - r, y - r * 0.7, x + r, y + r * 0.7)), SHADOW, shade=False)
    return outline(c.img)


WARD_R = 46  # art px ring radius (x SPRITE_SCALE = SpecialFx.WARD_ART_RADIUS)
WARD_SIZE = 128
WARD_CLOSE_SIZE = 156
WARD_FRAMES = 8  # loop (SpecialFx.WARD_FPS keeps the old speed)
WARD_OPEN_FRAMES = 12
WARD_CLOSE_FRAMES = 12
WARD_OUTER = 16  # petals orbiting on the ring
WARD_INNER = 7  # smaller petals turning the other way just inside it
POP_SIZE = 28
POP_FRAMES = 10


def ramp(vals, t: float) -> float:
    """Piecewise-linear lookup: `vals` are evenly spaced keys over t = 0..1."""
    t = min(1.0, max(0.0, t)) * (len(vals) - 1)
    i = min(int(t), len(vals) - 2)
    return vals[i] + (vals[i + 1] - vals[i]) * (t - i)


def smooth(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def twinkle(c: Canvas, x: float, y: float, arm: int):
    """A white four-point glint (arm 1 = a plus, 2+ = longer arms with a pale core)."""
    if arm <= 0:
        return
    x, y = round(x), round(y)
    c.flat(R((x - arm, y, x + arm, y)), WHITE)
    c.flat(R((x, y - arm, x, y + arm)), WHITE)
    if arm >= 2:
        c.dot(x, y, PINK_L)


def ward_petal(c: Canvas, x: float, y: float, ang: float, length: float, flutter: float, color, base=PINK):
    """One cherry petal centred at (x, y), its tip along `ang`: a teardrop notched at the tip, a darker crease from the
    base and a bright fleck near the tip. `flutter` (-1..1) is how much of its face shows as it turns over: near 0 it's
    edge-on, below 0 its paler back shows."""
    ux, uy = math.cos(ang), math.sin(ang)
    w = max(0.5, length * 0.42 * abs(flutter))
    q = lambda a, b: (x + ux * a - uy * b, y + uy * a + ux * b)
    h = length / 2
    c.flat(P([q(-h, 0), q(-h * 0.4, w), q(h * 0.5, w), q(h, w * 0.45), q(h * 0.6, 0), q(h, -w * 0.45),
              q(h * 0.5, -w), q(-h * 0.4, -w)]), color)
    if length >= 5 and abs(flutter) > 0.3:
        c.flat(L([q(-h, 0), q(-h * 0.2, 0)], 1), MAROON if color == PINK else base)
        if length >= 6:  # the sheen near the tip, on the lit edge
            px_, py_ = q(h * 0.45, -w * 0.45)
            c.dot(round(px_), round(py_), WHITE if color != WHITE else PINK_L)


def ward_ring(n_outer: int, k: int):
    """Ring petals for loop frame `k` as (x, y, ang, length,
    flutter, colour) relative to the centre. Petal i's look is a function of n = F i + k (F = WARD_FRAMES), so after a
    loop petal i stands exactly where petal i + 1 started: the loop is seamless while each petal wobbles, tilts and
    turns over."""
    out = []
    span = WARD_FRAMES * n_outer
    for i in range(n_outer):
        n = WARD_FRAMES * i + k
        ang = math.tau * n / span
        r = WARD_R + 2.5 * math.sin(math.tau * 3 * n / span)
        flutter = math.cos(math.tau * (n_outer + 3) * n / span)
        tilt = 0.5 * math.sin(math.tau * 5 * n / span)
        length = 8 + round(math.sin(math.tau * 2 * n / span + 1))
        out.append((math.cos(ang) * r, math.sin(ang) * r, ang + math.pi / 2 + tilt, length, flutter,
                    PINK_L if flutter >= 0 else WHITE))
    span = WARD_FRAMES * WARD_INNER
    for i in range(WARD_INNER):  # turning the other way: petal i ends where petal i - 1 started
        n = WARD_FRAMES * i - k
        ang = math.tau * n / span + 0.2
        r = WARD_R - 8 + 1.5 * math.sin(math.tau * 2 * n / span)
        flutter = math.cos(math.tau * (WARD_INNER + 2) * n / span)
        out.append((math.cos(ang) * r, math.sin(ang) * r, ang - math.pi / 2, 5, flutter,
                    WHITE if flutter >= 0 else PINK_L))
    return out


def blossom_ward_frame(k: int) -> Image.Image:
    """Blossom Ward loop (period 8): petals orbit the ring, wobbling in and out, tilting and turning over (pink face,
    white back, a crease and sheen on each); a smaller band inside turns the other way; five petals peel off the ring,
    drift outward and sink, shrinking; glints twinkle round the ring and pollen motes float in from it."""
    c = Canvas(WARD_SIZE)
    m = WARD_SIZE / 2
    f = k / WARD_FRAMES
    for j in range(8):  # pollen motes drifting inwards off the ring and fading out
        u = (f + j / 8) % 1.0
        a = 0.3 + math.tau * j * 3 / 8 + 0.4 * u
        r = WARD_R - 3 - 15 * u
        if u < 0.85:
            c.dot(round(m + math.cos(a) * r), round(m + math.sin(a) * r + 2 * math.sin(math.tau * u)),
                  YELLOW if j % 4 == 0 else PINK_L)
    for j, a0 in enumerate((0.6, 1.9, 3.1, 4.4, 5.5)):  # drifters peel off the ring, one after another
        w = (f + j / 5) % 1.0
        ang = a0 + 0.35 * w
        r = WARD_R + 2 + 9 * w
        ward_petal(c, m + math.cos(ang) * r, m + math.sin(ang) * r + 5 * w * w + 2 * w, ang + 2.4 * w, 6.5 - 3.5 * w,
                   math.cos(math.pi * 2 * w + j), PINK_L if j % 2 else WHITE)
    for x, y, ang, length, flutter, col in ward_ring(WARD_OUTER, k):
        ward_petal(c, m + x, m + y, ang, length, flutter, col)
    for j in range(4):  # glints winking on the ring, out of step
        ph = (f * 2 + j / 4) % 1.0
        a = 0.8 + math.tau * j / 4
        if ph < 0.5:
            twinkle(c, m + math.cos(a) * (WARD_R + 1), m + math.sin(a) * (WARD_R + 1), (1, 2, 2, 1)[min(3, int(ph * 8))])
    return outline(c.img)


def blossom_bloom(c: Canvas, m: float, r: float, spin: float):
    """A five-petal cherry blossom at the centre, `r` art px across its petals, yellow stamens in its eye."""
    for i in range(5):
        a = spin + math.tau * i / 5
        ward_petal(c, m + math.cos(a) * r * 0.55, m + math.sin(a) * r * 0.55, a, r, 1.0, WHITE if i % 2 else PINK_L)
    c.flat(E((m - r * 0.25, m - r * 0.25, m + r * 0.25, m + r * 0.25)), PINK)
    c.dot(round(m), round(m), YELLOW)
    if r >= 9:
        for i in range(5):
            a = spin * 1.5 + math.tau * i / 5
            c.dot(round(m + math.cos(a) * r * 0.2), round(m + math.sin(a) * r * 0.2), YELLOW)


def blossom_ward_open_frame(k: int) -> Image.Image:
    """Opening bloom (12 frames): a blossom opens over her and bursts; its petals spiral out into the ring,
    overshooting a little, loose petals flung past it, glints winking on the ring. The last frame is the loop's first."""
    rng = random.Random(17)
    c = Canvas(WARD_SIZE)
    m = WARD_SIZE / 2
    n = WARD_OPEN_FRAMES
    if k <= 5:  # the bloom: opens, holds, bursts
        blossom_bloom(c, m, (3, 6, 9, 12, 13, 8)[k], 0.25 * k)
    e = min(1.0, max(0.0, (k - 1) / (n - 2)))
    e = 1 + 2.2 * (e - 1) ** 3 + 1.2 * (e - 1) ** 2 if e < 1 else 1.0  # ease out with a small overshoot
    if k >= 1:
        for x, y, ang, length, flutter, col in ward_ring(WARD_OUTER, 0):
            d = math.hypot(x, y)
            a = math.atan2(y, x) - 1.8 * (1 - e)
            rr = d * e
            ward_petal(c, m + math.cos(a) * rr, m + math.sin(a) * rr, ang - 1.8 * (1 - e), length * min(1.0, 0.5 + e),
                       flutter if e >= 1 else math.cos(k * 1.1 + a), col)
    for j in range(9):  # loose petals thrown out past the ring, then sinking away
        a0, spin, delay = rng.uniform(0, math.tau), rng.uniform(-1, 1), rng.uniform(2, 5)
        u = (k - delay) / 6
        if 0 <= u < 1:
            a = a0 + 0.5 * u
            rr = WARD_R * 0.5 + (WARD_R * 0.6) * math.sqrt(u)
            ward_petal(c, m + math.cos(a) * rr, m + math.sin(a) * rr + 6 * u * u, a + 3 * u * spin, 6 - 3 * u,
                       math.cos(6 * u + j), PINK_L if j % 2 else WHITE)
    if 3 <= k <= 9:  # sparkles winking on as the ring forms
        arm = (1, 2, 2, 2, 1, 1, 1)[k - 3]
        for j in range(5):
            a = 0.9 + math.tau * j / 5 + 0.35 * k
            twinkle(c, m + math.cos(a) * WARD_R * 0.85 * e, m + math.sin(a) * WARD_R * 0.85 * e, arm)
    return outline(c.img)


def blossom_ward_close_frame(k: int) -> Image.Image:
    """Closing scatter (12 frames): glints wink out, the ring loosens, petals fly outward with a twist and sink as they
    flutter, shrinking and dropping out one by one, a few small ones falling in the wake."""
    rng = random.Random(11)
    c = Canvas(WARD_CLOSE_SIZE)
    m = WARD_CLOSE_SIZE / 2
    t = k / (WARD_CLOSE_FRAMES - 1)
    for idx, (x, y, ang, length, flutter, col) in enumerate(ward_ring(WARD_OUTER, 0)):
        reach, spin, gone = rng.uniform(0.7, 1.3), rng.uniform(-1.0, 1.0), rng.uniform(0.55, 1.0)
        if t > gone:
            continue
        a = math.atan2(y, x) + 0.35 * t
        rr = math.hypot(x, y) + 14 * reach * t ** 0.7
        f = math.cos(math.atan2(flutter, 1) + 3.0 * t + spin * 2)
        ward_petal(c, m + math.cos(a) * rr, m + math.sin(a) * rr + 9 * t * t, ang + spin * 3 * t,
                   max(2.0, length * (1 - 0.6 * t)), f, col if f >= 0 else WHITE)
    for j in range(10):  # the wake: small petals shaken loose, falling
        a0, born, spin = rng.uniform(0, math.tau), rng.uniform(0.0, 0.45), rng.uniform(-1, 1)
        u = (t - born) / 0.5
        if 0 <= u < 1:
            rr = WARD_R + 4 + 10 * u
            ward_petal(c, m + math.cos(a0) * rr + 3 * math.sin(7 * u + j), m + math.sin(a0) * rr + 12 * u * u,
                       a0 + 4 * u * spin, 5 - 2 * u, math.cos(8 * u + j), PINK_L if j % 2 else WHITE)
    if k <= 4:
        for j in range(4):
            a = 0.8 + math.tau * j / 4
            twinkle(c, m + math.cos(a) * (WARD_R + 2), m + math.sin(a) * (WARD_R + 2), (2, 2, 1, 1, 0)[k] if k < 4 else 0)
    return outline(c.img)


def petal_pop_frame(k: int) -> Image.Image:
    """A shot caught on the ward: a white wink with a pink ring, and five tiny petals burst out and flutter down."""
    c = Canvas(POP_SIZE)
    m = POP_SIZE / 2
    t = k / (POP_FRAMES - 1)
    if k <= 3:
        arm = (2, 3, 3, 1)[k]
        c.flat(R((m - arm, m, m + arm, m)), WHITE)
        c.flat(R((m, m - arm, m, m + arm)), WHITE)
        c.dot(round(m), round(m), PINK_L)
    if 1 <= k <= 3:  # the shot's shock ring
        r = 2 + 2.5 * k
        c.flat(lambda d, f: d.ellipse((m - r, m - r, m + r, m + r), outline=f, width=1), PINK_L)
    for i, a in enumerate((0.5, 1.7, 2.9, 4.1, 5.3)):
        if t > 0.78 + 0.05 * i or k == 0:
            continue
        d = 2 + 6.5 * t ** 0.6
        ward_petal(c, m + math.cos(a) * d, m + math.sin(a) * d + 5 * t * t, a + 2.5 * t, max(2.0, 5.5 - 3 * t),
                   math.cos(4 * t + i), PINK_L if i % 2 else WHITE)
    return outline(c.img)


# --- Petal Drift (Sakura): she dissolves into a tight spiral of petals, glides, and gathers back ---
DRIFT_FRAMES = 16  # dissolve, reform and the swirl loop (SpecialFx.DRIFT_FPS keeps the old speed)
DRIFT_SEEDS = 28  # chunks of her that break off: the first DRIFT_PETALS become the swirl's petals, the rest motes
DRIFT_PETALS = 16  # petals in the swirl
DRIFT_TRAIL = 7  # petals streaming behind


def drift_body() -> Image.Image:
    return cell(frames(sakura)[0])


def swirl_items(k: int):
    """The swirl's petals at loop frame k: (depth, x, y, ang, length, flutter, slot colour); a tornado wider at the top,
    leaning back, turning twice per loop."""
    m = CELL / 2
    items = []
    for i in range(DRIFT_PETALS):
        h = -28 + 54 * ((i * 5) % DRIFT_PETALS) / DRIFT_PETALS
        r = 5 + 16 * (h + 28) / 54
        a = math.tau * (i / DRIFT_PETALS + 2 * k / DRIFT_FRAMES)
        x = m + r * math.cos(a) - 0.22 * (24 - h)
        y = m + h + 0.35 * r * math.sin(a)
        flutter = math.cos(math.tau * (3 * k / DRIFT_FRAMES + i / 4))
        items.append((math.sin(a), x, y, a + math.pi / 2 + 0.5, 9 - 2 * (h < -10), flutter, i))
    return items


def swirl_color(depth: float, flutter: float):
    return (PINK_L if flutter >= 0 else WHITE) if depth > 0 else PINK


def swirl_extras(c: Canvas, k: int, grow: float = 1.0, shed: bool = True):
    """The knot of petals at the foot, the stragglers streaming behind, a glint at the heart (`grow` 0..1 = how far
    they've formed) and petals shed off the tornado, falling."""
    m = CELL / 2
    f = k / DRIFT_FRAMES
    if grow > 0.2:
        r = 4 * grow
        c.flat(E((m - r - 1, m + 15 - r * 0.6, m + r - 1, m + 15 + r * 0.7)), PINK)
        c.flat(E((m - r * 0.5 - 1, m + 14 - r * 0.4, m + r * 0.4, m + 14 + r * 0.3)), PINK_L)
    for j in range(DRIFT_TRAIL):
        u = (f + j / DRIFT_TRAIL) % 1.0
        x = m - 17 - u * 21
        y = m + 4 + 12 * math.sin(math.tau * (u + j / DRIFT_TRAIL)) - 8 * u
        ln = (7 - 4 * u) * grow
        if ln >= 2:
            ward_petal(c, x, y, math.pi + 0.7 * math.sin(math.tau * u * 2 + j), ln,
                       math.cos(math.tau * (u * 2 + j / 3)), PINK_L if j % 2 else WHITE)
    if shed:
        for j in range(3):  # petals peeling off the tornado's top, spinning away and down
            u = (f + j / 3) % 1.0
            a = math.tau * j / 3 + 0.8
            ward_petal(c, m - 6 + math.cos(a) * (18 + 6 * u) - 6 * u, m - 22 + 26 * u * u + math.sin(a) * 4,
                       a + 5 * u, 6 - 3 * u, math.cos(7 * u + j), PINK_L if j % 2 else WHITE)
    ph = (f * 2) % 1.0  # the glint at the heart, twice per loop
    if ph < 0.5 and grow >= 1.0:
        twinkle(c, m - 4, m - 4, (1, 2, 2, 1)[min(3, int(ph * 8))])


def drift_swirl_frame(k: int) -> Image.Image:
    """The drift form (period 16, moving right): a tornado of petals wider at the top and leaning back, spinning two
    turns per loop (back petals pink, front ones pale and white, each with its crease and sheen), a knot at the foot,
    stragglers streaming behind and a few petals shed. SpecialFx mirrors it and tilts it with her motion."""
    c = Canvas(CELL)
    for depth, x, y, ang, length, flutter, _ in sorted(swirl_items(k)):
        ward_petal(c, x, y, ang, length, flutter, swirl_color(depth, flutter))
    swirl_extras(c, k)
    return outline(c.img)


def drift_dissolve_frame(k: int) -> Image.Image:
    """Dissolve (16 frames; the reform strip plays it backwards): her idle frame squeezes in towards the column, flashes
    pale and breaks into chunks, back (left) first. Each chunk turns into a petal and spirals in to its place in the
    swirl, tightening as it goes; the last frame is the swirl's first. Small motes scatter off and vanish."""
    rng = random.Random(5)
    body = drift_body()
    px = body.load()
    t = k / (DRIFT_FRAMES - 1)
    pts = [(x, y) for y in range(CELL) for x in range(CELL) if px[x, y][3]]
    seeds = [rng.choice(pts) for _ in range(DRIFT_SEEDS)]
    slots = sorted(swirl_items(0), key=lambda it: it[2])  # top to bottom
    heads = sorted(seeds[:DRIFT_PETALS], key=lambda p: p[1])
    seeds = heads + seeds[DRIFT_PETALS:]
    # a seed breaks off earlier the further back (left) it sits, so she peels away from the trailing side
    start = [min(max(0.06 + 0.42 * ((x - 28) / 40) + rng.uniform(0, 0.2), 0.06), 0.66) for x, y in seeds]
    sq = 1 - 0.4 * smooth(t / 0.7)  # she squeezes in towards the column as she dissolves
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    o = out.load()
    m = CELL // 2
    for x, y in pts:
        i = min(range(DRIFT_SEEDS), key=lambda s: (seeds[s][0] - x) ** 2 + (seeds[s][1] - y) ** 2)
        a = start[i] + rng.uniform(-0.04, 0.04)
        if t <= a:
            col = px[x, y][:3]
            if t > a - 0.09 and (x + y) % 2 == 0:  # about to go: flashes pale
                col = LIGHTER[col] if col in LIGHTER else col
            nx = round(m + (x - m) * sq)
            if 0 <= nx < CELL:
                o[nx, y] = col + (255,)
    out = outline(out)
    pc = Canvas(CELL)
    order = sorted(range(DRIFT_PETALS), key=lambda i: slots[i][0])  # back petals first
    for i in order:
        x0, y0 = seeds[i]
        depth, sx, sy, sang, slen, sflut, _ = slots[i]
        u = smooth((t - start[i]) / (1 - start[i] + 1e-6)) if t > start[i] else 0.0
        if t <= start[i] and u == 0.0:
            continue
        ox, oy = (x0 - sx) * (1 - u), (y0 - sy) * (1 - u)
        rot = -3.4 * (1 - u)  # spirals in: the offset turns round the slot as it closes
        px_ = sx + ox * math.cos(rot) - oy * math.sin(rot)
        py_ = sy + ox * math.sin(rot) + oy * math.cos(rot) - 5 * math.sin(math.pi * u)
        px_, py_ = min(max(px_, 7), CELL - 8), min(max(py_, 7), CELL - 8)
        fl = math.cos(math.acos(max(-1.0, min(1.0, sflut))) + 7 * (1 - u))
        length = 3 + (slen - 3) * u
        ward_petal(pc, px_, py_, sang + 4 * (1 - u), length, fl, swirl_color(depth, fl) if u > 0.5 else (PINK_L if i % 2 else WHITE))
    for j in range(DRIFT_PETALS, DRIFT_SEEDS):  # motes: scattered off, spinning away and vanishing
        x0, y0 = seeds[j]
        u = (t - start[j]) / 0.5
        if 0 <= u < 1:
            a = j * 2.4
            d = 6 + 20 * u
            ward_petal(pc, x0 - 5 * u + math.cos(a) * d * 0.4, y0 - 10 * u + math.sin(a) * d * 0.5 + 4 * u * u,
                       a + 5 * u, max(2.0, 5 - 4 * u), math.cos(6 * u + j), PINK_L if j % 2 else WHITE)
    if t > 0.55:  # the swirl's knot and stragglers form as the petals arrive
        swirl_extras(pc, 0, grow=smooth((t - 0.55) / 0.45), shed=False)
    out.alpha_composite(outline(pc.img))
    return out


def drift_reform_frame(k: int) -> Image.Image:
    """Reform (16 frames): the dissolve backwards, then a wink of white sparkles as she's whole again."""
    img = drift_dissolve_frame(DRIFT_FRAMES - 1 - k)
    n = DRIFT_FRAMES - 5  # the last five frames glint
    if k >= n:
        c = Canvas(CELL)
        for i, (x, y) in enumerate(((34, 30), (62, 38), (44, 66), (66, 62), (30, 52), (60, 24))):
            arm = (1, 2, 2, 1, 0)[k - n] if (i + k) % 2 == 0 else (0, 1, 1, 0, 0)[k - n]
            twinkle(c, x, y, arm)
        img.alpha_composite(outline(c.img))
    return img


SNARE_FRAMES = 8  # vines loop (period 8; SpecialFx.SNARE_FPS keeps the old speed)
SNARE_W = 40
SNARE_BASE_Y = 26  # row of the ground ring's centre (SpecialFx.SNARE_BASE_Y)
SNARE_BURST_SIZE = 64
SNARE_BURST_FRAMES = 12
SNARE_STRANDS = 2


def snare_vines_frame(k: int) -> Image.Image:
    """Snare loop (period 8): two pink vine ribbons spiral up round the ankles (the near side only; the sprite hides
    the far side), thorns and little leaves along them, a blossom at each tip, a ring of petals turning over on the
    ground and a few petals lifting off it. The strands swap places after a loop, so it loops seamlessly."""
    c = Canvas(SNARE_W)
    cx, rx, ry = SNARE_W / 2, 12.0, 5.0
    base = SNARE_BASE_Y
    turn = math.tau / SNARE_STRANDS
    for sidx in range(SNARE_STRANDS):
        pts = []
        for i in range(0, 41):
            u = i / 40
            a = sidx * turn + k * turn / SNARE_FRAMES + u * math.tau * 1.5
            near = math.sin(a)
            r = rx * (1 - 0.22 * u)
            pts.append((cx + math.cos(a) * r, base - 3 - u * 17 + near * ry, near, u))
        seg = []
        for x, y, near, u in pts + [(0, 0, -1, 1)]:
            if near > -0.15:
                seg.append((x, y))
            elif seg:
                if len(seg) > 1:
                    c.flat(L(seg, 2), PINK)
                    c.flat(L([(x_, y_ - 1) for x_, y_ in seg], 1), PINK_L)
                    c.flat(L([(x_ + 1, y_ + 1) for x_, y_ in seg[1:]], 1), MAROON)  # shaded underside
                seg = []
        for i in range(6, 40, 7):  # a thorn / leaf on the near side of each turn
            x, y, near, u = pts[i]
            if near > 0.3:
                ward_petal(c, x + 2, y - 2, -0.9, 4, 1.0, PINK_L if (i // 7) % 2 else WHITE)
    for sidx in range(SNARE_STRANDS):
        a = sidx * turn + k * turn / SNARE_FRAMES + math.tau * 1.5
        if math.sin(a) > 0:
            ward_petal(c, cx + math.cos(a) * rx * 0.78, base - 20 + math.sin(a) * ry, a, 5, 1.0, WHITE)
            c.dot(round(cx + math.cos(a) * rx * 0.78), round(base - 20 + math.sin(a) * ry), YELLOW)
    for i in range(6):  # petals lying on the ground ring, turning over as the loop runs
        a = math.tau * i / 6 + k * math.tau / 6 / SNARE_FRAMES
        ward_petal(c, cx + math.cos(a) * (rx + 2), base + math.sin(a) * (ry + 1) + 1, a + math.pi / 2, 5,
                   math.cos(a * 2 + k * 0.4), PINK_L if i % 2 else WHITE)
    for j in range(3):  # petals lifting off the ring, turning, and fading out at the top
        u = (k / SNARE_FRAMES + j / 3) % 1.0
        a = math.tau * j / 3 + 0.6
        if u < 0.8:
            ward_petal(c, cx + math.cos(a) * (rx + 3 + 2 * u) + 2 * math.sin(math.tau * u), base - 2 - 20 * u,
                       a + 3 * u, 4.5 - 2 * u, math.cos(math.tau * u * 1.5 + j), PINK_L if j % 2 else WHITE)
    return outline(c.img)


def snare_burst_frame(k: int) -> Image.Image:
    """A blossom bursts where the snare lands: a white flash and ring, then petals of both colours fly out spinning
    and flutter down, a few vine curls whipping round the centre and glints winking."""
    c = Canvas(SNARE_BURST_SIZE)
    m = SNARE_BURST_SIZE / 2
    n = SNARE_BURST_FRAMES
    t = k / (n - 1)
    if k <= 3:
        blossom_bloom(c, m, (6, 10, 12, 6)[k], 0.4 * k)
    if 1 <= k <= 4:  # shock ring
        r = 5 + 6 * k
        c.flat(lambda d, f: d.ellipse((m - r, m - r, m + r, m + r), outline=f, width=1), PINK_L if k > 2 else WHITE)
    for i in range(12):
        a = 0.4 + math.tau * i / 12
        if t > 0.8 + 0.015 * i or k == 0:
            continue
        d = 4 + (13 + 3 * (i % 3)) * t ** 0.55
        ward_petal(c, m + math.cos(a) * d, m + math.sin(a) * d + 6 * t * t, a + 3 * t, max(3.0, 7.5 - 3.5 * t),
                   math.cos(5 * t + i), PINK_L if i % 2 else WHITE)
    if 2 <= k <= 8:  # vine curls whip out and round, thinning at the end
        for j in range(3):
            a0 = 1.0 + math.tau * j / 3
            reach = 4 + 14 * min(1, 1.6 * t)
            pts = [(m + math.cos(a0 + 0.9 * u * (1 + t)) * (4 + (reach - 4) * u),
                    m + math.sin(a0 + 0.9 * u * (1 + t)) * (4 + (reach - 4) * u)) for u in (0, .2, .4, .6, .8, 1)]
            c.flat(L(pts, 2 if k <= 5 else 1), PINK)
            c.flat(L([(x, y - 1) for x, y in pts[1:-1]], 1), PINK_L)
    if 3 <= k <= 8:
        for j in range(3):
            a = 0.2 + math.tau * j / 3 + 0.3 * k
            twinkle(c, m + math.cos(a) * 20 * t ** 0.5, m + math.sin(a) * 20 * t ** 0.5, 1 + (k in (4, 5)))
    return outline(c.img)


BLAST_FRAMES = 10
BLAST_SIZE = 128  # art px; the fireball reaches ~BLAST_R, drawn scaled to the weapon's splash radius
BLAST_R = 56


def blobs(pts):
    return lambda dr, f: [dr.ellipse((x - r, y - r, x + r, y + r), f) for x, y, r in pts if r >= 1]


def blast_frame(k: int) -> Image.Image:
    """Rocket / grenade explosion: white flash, a fireball of lumpy layers (red rim, orange, yellow
    core) that billows out, then breaks into dark smoke puffs drifting up while embers fly out."""
    rng = random.Random(3)
    lumps = [(math.tau * i / 9 + rng.uniform(-0.25, 0.25), rng.uniform(0.85, 1.15), rng.uniform(0.8, 1.2))
             for i in range(9)]
    embers = [(rng.uniform(0, math.tau), rng.uniform(0.7, 1.0)) for _ in range(7)]
    c = Canvas(BLAST_SIZE)
    m = BLAST_SIZE // 2
    t = k / (BLAST_FRAMES - 1)
    g = min(1.0, (k + 1) / 3)  # swells over the first 3 frames
    rise = BLAST_R * 0.2 * max(0.0, t - 0.4)

    def ring(dist, size, color):
        c.part(blobs([(m + math.cos(a) * dist * d, m + math.sin(a) * dist * d - rise, round(size * r))
                      for a, d, r in lumps] + [(m, m - rise, round(dist * 0.9))]), color)

    if t < 0.45:  # fire
        ring(BLAST_R * 0.55 * g, BLAST_R * 0.36 * g, RED if k else YELLOW)
        if k:
            ring(BLAST_R * 0.35 * g * (1 - t), BLAST_R * 0.3 * g * (1 - t), ORANGE)
        core = round(BLAST_R * 0.35 * g * (1 - 2 * t))
        if core >= 2:
            c.part(blobs([(m, m - rise, core)]), YELLOW if k else WHITE)
        if k < 2:
            c.part(blobs([(m, m, round(BLAST_R * 0.18))]), WHITE)
    else:  # smoke: puffs drift out and up, shrinking; a last glow inside early on
        f = (t - 0.45) / 0.55
        c.part(blobs([(m + math.cos(a) * BLAST_R * (0.55 + 0.25 * f) * d, m + math.sin(a) * BLAST_R * (0.55 + 0.25 * f) * d
                       - rise, round(BLAST_R * 0.3 * r * (1 - 0.8 * f))) for a, d, r in lumps]), SHADOW)
        if f < 0.4:
            c.part(blobs([(m, m - rise, round(BLAST_R * 0.25 * (1 - 2 * f)))]), RED)
    if t > 0.15:  # embers streak out
        for a, d in embers:
            dist = BLAST_R * (0.4 + 0.75 * t) * d
            x, y = round(m + math.cos(a) * dist), round(m + math.sin(a) * dist - rise)
            if t < 0.9:
                c.flat(R((x, y, x + 1, y + 1)), YELLOW if t < 0.5 else ORANGE)
    return outline(c.img)


SLAM_FRAMES = 8


def slam_frame(k: int) -> Image.Image:
    """Melee slam (hammer, ape fists): an impact flash, cracks in the floor, and a ring of dust puffs
    rolling outward along the ground (squashed for the top-down 3/4 view)."""
    rng = random.Random(5)
    puffs = [(math.tau * i / 12 + rng.uniform(-0.15, 0.15), rng.uniform(0.85, 1.1), rng.uniform(0.8, 1.2))
             for i in range(12)]
    cracks = [math.tau * i / 5 + rng.uniform(-0.3, 0.3) for i in range(5)]
    c = Canvas(BLAST_SIZE)
    m = BLAST_SIZE // 2
    t = k / (SLAM_FRAMES - 1)
    if t < 0.85:  # cracks stay, then vanish with the dust
        for a in cracks:
            length = BLAST_R * min(0.5, 0.25 + t)
            pts = [(m, m)]
            for j in range(1, 4):
                rr = length * j / 3
                pts.append((m + math.cos(a + (0.15 if j % 2 else -0.15)) * rr, m + math.sin(a) * rr * 0.6))
            c.flat(L(pts, 1), OUTLINE)
    if k < 2:  # impact flash
        r = round(BLAST_R * (0.22 if k == 0 else 0.32))
        c.part(blobs([(m, m, r)]), WHITE if k == 0 else YELLOW)
    dist = BLAST_R * (0.25 + 0.7 * math.sqrt(t))
    size = BLAST_R * 0.2 * (1 - 0.75 * t)
    c.part(blobs([(m + math.cos(a) * dist * d, m + math.sin(a) * dist * d * 0.6 - BLAST_R * 0.08 * t,
                   round(size * r)) for a, d, r in puffs]), STEEL)
    return outline(c.img)


ERUPT_SIZE = 128  # telegraph frames, art px (the floor spot is the centre)
ERUPT_R = 53  # blast radius in art px (eruption_blast.tres splash 80 / SPRITE_SCALE 1.5): SpecialFx.ERUPTION_ART_RADIUS
ERUPT_SQUASH = 0.6  # the floor seen in 3/4 view
CRACK_FRAMES = 16  # the telegraph loop: a rocky mound over the cracked floor, lava pulsing in its cracks, rumbling
VOLC_SIZE = 256  # eruption strip frames, art px
ERUPT_BASE = 204  # eruption strip: the floor spot's y (the volcano grows from here); SpecialFx.ERUPTION_BASE_Y
ERUPT_FRAMES = 39  # designed in 26 frames (ERUPT_OLD) at 15 fps, sampled 1.5x finer: SpecialFx ERUPTION_FPS 22.5
ERUPT_STEP = 1.5
ERUPT_BLAST = 4  # the burst's frame in design time; the output lands on frame 6 (SpecialFx.ERUPTION_BLAST_FRAME), the ones before lead in from the telegraph
MOUND_W, MOUND_H = 26, 18  # the telegraph mound, which the strip's first frames grow on from
CONE_W, CONE_WT, CONE_H = 44, 15, 40  # the volcanic cone: foot half-width, crater half-width, height
POOL_R = 54  # the magma pool's reach
FIRE_H = (0, 0, 0, 12, 60, 100, 118, 126, 122, 114, 100, 86, 70, 56, 43, 32, 24, 15, 8, 4) + (0,) * 6
FIRE_HW = (0, 0, 0, 8, 22, 26, 26, 26, 25, 23, 21, 19, 17, 15, 13, 12, 10, 9, 7, 5) + (0,) * 6




def erupt_cracks(c: Canvas, cx: float, cy: float, reach: float, glow, rng_seed: int = 9, width: int = 2):
    """Jagged fissures in the floor running out from (cx, cy), lit from below: dark rim, `glow` inside (None = cold)."""
    rng = random.Random(rng_seed)
    for i in range(6):
        a = math.tau * i / 6 + rng.uniform(-0.35, 0.35)
        length = reach * rng.uniform(0.6, 1.0)
        pts = [(cx, cy)]
        for j in range(1, 5):
            rr = length * j / 4
            aa = a + rng.uniform(-0.3, 0.3)
            pts.append((cx + math.cos(aa) * rr, cy + math.sin(aa) * rr * ERUPT_SQUASH))
        c.flat(L(pts, width + 1), OUTLINE)
        if glow:
            c.flat(L(pts[:-1], 1), glow)


def fire_column(c: Canvas, cx: float, base: float, height: float, hw: float, t: int, hot: bool = False,
                lean: float = 0.0):
    """A pillar of fire rising `height` from `base`: wavy sides swaying (a wave rolls up them each tick), narrowing a
    little, crowned with wide licking tongues like his bonfire; red rim, orange, yellow core (a white-hot heart when
    `hot`)."""
    def shape(inset):
        w0 = hw - inset
        left, right = [], []
        for i in range(9):
            v = i / 8
            y = base - v * height * 0.72
            w = w0 * (1 - 0.5 * v ** 0.8)  # a bonfire: broad at the foot, drawing in up the flames
            wave = math.sin(v * math.pi * 2.4 - t * math.pi / 2) * hw * 0.2 * v + lean * height * v * v * 0.5
            left.append((cx - w + wave, y))
            right.append((cx + w + wave, y))
        (lx, ly), (rx, _) = left[-1], right[-1]
        span = (rx - lx) / 3
        crown = []
        for j in range(3):
            hx = lx + span * (j + 0.5)
            tall = max(1.0, height * 0.3 - inset * 1.5) * (0.75 + 0.35 * (((j * 7 + t) % 4) in (1, 2))) \
                * (1.25 if j == 1 else 1)
            crown += [(hx - span * 0.48, ly - tall * 0.35), (hx + SWAY[(t + j) % 4] * 2 + lean * height * 0.1, ly - tall),
                      (hx + span * 0.48, ly - tall * 0.35)]
        return left + crown + right[::-1]
    layers = [(RED, 0.0), (ORANGE, hw * 0.3), (YELLOW, hw * 0.58)] + ([(WHITE, hw * 0.8)] if hot else [])
    for col, inset in layers:
        if hw - inset >= 1:
            c.part(P(shape(inset)), col, shade=False, line=col == RED)


def lava_cols(heat: float):
    """(rim, middle, core or None) of lava at `heat` 1 (white-hot) .. 0 (crusted rock)."""
    for lim, cols in ((0.9, (ORANGE, YELLOW, WHITE)), (0.7, (RED, ORANGE, YELLOW)), (0.5, (MAROON, RED, ORANGE)),
                      (0.3, (BROWN, MAROON, RED)), (0.15, (BROWN, MAROON, None))):
        if heat >= lim:
            return cols
    return OUTLINE, BROWN, None


def lava_pool(c: Canvas, x: float, y: float, rx: float, ry: float, heat: float, seed: int = 0):
    """A lumpy puddle of lava (or, cooled, of crusted rock) on the floor."""
    if rx < 1.5:
        return
    rim, mid, core = lava_cols(heat)
    rng = random.Random(seed)
    lumps = [(rng.uniform(-0.5, 0.5), rng.uniform(-0.45, 0.45), rng.uniform(0.45, 0.6)) for _ in range(5)] \
        + [(0, 0, 0.9)]

    def blob(s):
        return lambda d, f: [d.ellipse((x + dx * rx * s - sz * rx * s, y + dy * ry * s - sz * ry * s,
                                        x + dx * rx * s + sz * rx * s, y + dy * ry * s + sz * ry * s), f)
                             for dx, dy, sz in lumps]
    c.part(blob(1.0), rim, shade=False)
    c.part(blob(0.72), mid, shade=False, line=False)
    if core and rx >= 6:
        c.part(blob(0.4), core, shade=False, line=False)


def rock_cone(c: Canvas, cx: float, b: float, wb: float, wt: float, h: float, dome: float, heat: float, seed: int = 3):
    """A rocky mound (dome > 0) or volcanic cone (dome < 0: a crater dips in the top): dark brown, jagged flanks, a
    maroon shadowed right side, strata, and veins of lava running down from the top at `heat`."""
    if h < 3:
        return
    rng = random.Random(seed)
    jit = [rng.uniform(-1, 1) * 1.6 for _ in range(8)]
    side = lambda sign: [(cx + sign * (wb + (wt - wb) * i / 4 + jit[i + (4 if sign > 0 else 0)]), b - h * i / 4)
                         for i in range(4)]
    left, right = side(-1), side(1)
    top = [(cx + wt * u, b - h + dome * u * u) for u in (-1, -0.5, 0, 0.5, 1)]
    foot = [(cx + wb * u, b + wb * 0.16 * (1 - u * u)) for u in (0.75, 0.4, 0, -0.4, -0.75)]
    c.part(P(left + top + right[::-1] + foot), BROWN)
    c.flat(P([(cx + wt * 0.15, b - h + dome * 0.02), top[-1]] + right[::-1] + foot[:3]), MAROON)
    for i in range(5):  # strata and chips of dark rock
        y = b - h * (0.12 + 0.17 * i) + rng.uniform(-1, 1)
        x = cx - wb * (0.55 - 0.15 * i) + rng.uniform(-3, 3)
        c.flat(L([(x, y), (x + rng.uniform(3, 7), y + rng.uniform(-1, 1))], 1), OUTLINE)
    if heat > 0.45:  # firelight on the left flank and the crater lip
        c.flat(L([(cx - wb * 0.9, b - 1)] + [(x + 1, y) for x, y in left[1:]] + [(cx - wt, b - h)], 1), RED)
        c.flat(L([(cx - wt * 0.9, b - h + 1), (cx + wt * 0.5, b - h + 1)], 1), ORANGE if heat > 0.7 else RED)
    rim, mid, core = lava_cols(heat)
    for j in range(4):  # lava veins from the top, forking down the flanks
        u = -0.75 + 0.5 * j + rng.uniform(-0.1, 0.1)
        pts = [(cx + wt * u, b - h + dome * u * u + 1)]
        for i in range(1, 5):
            v = i / 4
            pts.append((cx + (wt + (wb - wt) * v * 0.9) * u * (1 + 0.2 * v) + rng.uniform(-2, 2),
                        b - h * (1 - v) + wb * 0.1 * v))
        c.flat(L(pts, 3), rim)
        c.flat(L(pts, 2 if core else 1), mid)
        if core:
            c.flat(L(pts[:3], 1), core)


def erupt_smoke(c: Canvas, puffs, col=SHADOW, hi=STEEL_D):
    """Smoke: lumps over a darker shadow layer, light catching their tops."""
    pts = [(x, y, r) for x, y, r in puffs if r >= 1]
    if not pts:
        return
    c.part(blobs([(x + 2, y + 2, r) for x, y, r in pts]), OUTLINE, shade=False)
    c.part(blobs(pts), col)
    for x, y, r in pts:
        if r >= 4:  # lit on the upper left so each puff reads as a round billow
            c.flat(E((x - r * 0.75, y - r * 0.8, x - r * 0.05, y - r * 0.2)), hi)
        if r >= 8:
            c.flat(E((x - r * 0.55, y - r * 0.65, x - r * 0.2, y - r * 0.4)), STEEL)


def ash_plume(c: Canvas, k: int, cx: float, cy: float):
    """The ash cloud: lumps of dark smoke born at the crater one after another, each rising to its own height and
    swelling, so a billowing column grows into a wide cap; the low ones glow red from the fire under them; in the
    follow-through the whole thing thins, leans away with the wind and is gone."""
    rng = random.Random(7)
    n = 16
    cold, hot = [], []
    for i in range(n):
        a = k - (ERUPT_BLAST + 0.45 * i)
        spread = rng.uniform(-1, 1)
        if a < 0:
            continue
        v = i / n
        rise = (8 + 7 * i) * (1 - math.exp(-a / 4)) + max(0, k - 16) * 1.5
        r = min(24.0, 7 + 14 * v + 0.7 * a) * max(0.0, 1 - max(0, k - 16) / 12)
        x = cx + spread * (8 + 30 * v) + SWAY[int(k + i) % 4] + a * (0.35 + 0.3 * v) + max(0, k - 14) * 1.2
        (hot if a < 3.5 and i < 5 else cold).append((x, cy - 6 - rise, round(r)))
    erupt_smoke(c, cold)
    erupt_smoke(c, hot, MAROON, RED)


def lava_bomb(c: Canvas, x: float, y: float, r: float, heat: float, trail):
    """A glob of lava in flight, trailing cooling sparks."""
    for tx, ty, tr, th in trail:
        if tr >= 1:
            c.part(E((tx - tr, ty - tr, tx + tr, ty + tr)), lava_cols(th)[0], shade=False, line=False)
    rim, mid, core = lava_cols(heat)
    c.part(E((x - r, y - r, x + r, y + r)), rim, shade=False)
    c.flat(E((x - r * 0.55, y - r * 0.55, x + r * 0.55, y + r * 0.55)), mid)
    if core and r >= 3:
        c.dot(round(x), round(y), core)


def arc(x0: float, y0: float, x1: float, y1: float, apex: float, s: float):
    """Where something thrown from (x0, y0) to land on (x1, y1) with its path peaking `apex` px higher is at s 0..1."""
    return x0 + (x1 - x0) * s, y0 + (y1 - y0) * s - 4 * apex * s * (1 - s)


def eruption_crack_frame(k: int) -> Image.Image:
    """Eruption telegraph (period-8 loop at the marked spot): the floor split open in a star of glowing fissures over
    a scorch, a rocky mound heaving up out of it with lava pulsing in its cracks, small rocks hopping off it, dust
    and smoke rumbling up, and a ring of glowing embers marking where the blast will reach (squashed for 3/4 view)."""
    c = Canvas(ERUPT_SIZE)
    ov = Canvas(ERUPT_SIZE)
    m = ERUPT_SIZE // 2
    ph = math.tau * k / CRACK_FRAMES
    kh = k // 2  # the old 8-frame tick
    rx, ry = ERUPT_R, ERUPT_R * ERUPT_SQUASH
    for i in range(32):  # the reach: embers round the ring, marching every tick
        a = math.tau * i / 32
        x, y = round(m + math.cos(a) * rx), round(m + math.sin(a) * ry)
        if (i + kh) % 4 != 3:
            c.flat(R((x - 1, y, x + 1, y)), (RED, ORANGE, YELLOW, ORANGE)[(i + kh) % 4])
    c.part(E((m - 30, m - 17, m + 30, m + 17)), MAROON, shade=False)  # scorched floor
    heat = 0.62 + 0.3 * (0.5 + 0.5 * math.sin(ph)) + 0.05 * math.sin(3 * ph)
    glow = random.Random(6)
    for _ in range(46):  # a dithered halo of firelight on the floor round the mound, pulsing with the lava
        a, d = glow.uniform(0, math.tau), glow.uniform(0.0, 1.0) ** 0.7
        if d * 36 < 38 * (0.35 + 0.65 * heat):
            x, y = round(m + math.cos(a) * (14 + d * 36)), round(m + 2 + math.sin(a) * (7 + d * 20))
            if (x + y) % 2 == 0:
                c.flat(R((x, y, x + 1, y)), RED if d > 0.5 else ORANGE)
    erupt_cracks(c, m, m, ERUPT_R * 0.8, lava_cols(heat)[1])
    quake = (0, -1, 0, 0, -1, 0, 1, 0)[kh]  # the whole mound shudders
    rock_cone(c, m, m + 1 + quake, MOUND_W + (kh % 2), MOUND_W * 0.55, MOUND_H + quake, MOUND_H * 0.6, heat)
    rng = random.Random(4)
    for i in range(6):  # rocks shaken loose, hopping
        ang = math.tau * i / 6 + rng.uniform(-0.3, 0.3)
        hop = round(lerp_tab((0, 0, 2, 4, 5, 3, 1, 0, 0), ((k + i * 6) % 16) / 2))
        x = m + math.cos(ang) * (MOUND_W + 6 + rng.uniform(0, 6))
        y = m + 3 + math.sin(ang) * 11 - hop
        c.part(R((round(x) - 1, round(y) - 1, round(x) + 1, round(y))), BROWN if i % 2 else MAROON, shade=False)
    for i in range(5):  # dust and smoke puffing off the mound, each its own phase
        t = ((k + i * 4) % 16) / 15
        x = m + (i - 2) * 11 + SWAY[(kh + i) % 4] * 2
        r = round(1 + 2 * math.sin(math.pi * min(1.0, t * 1.1)))
        if r >= 1:
            c.part(E((x - r, m - 4 - 30 * t - r, x + r, m - 4 - 30 * t + r)), SHADOW if t < 0.5 else STEEL_D,
                   shade=False)
    spark_cloud(ov, 3, 26, k, lambda r: (m + r.uniform(-30, 30), m + r.uniform(-8, 5)), (0.0, 0.0), (8, 14), CRACK_FRAMES,
                loop=CRACK_FRAMES, up=1.7, g=0.03, trail=3)  # sparks popping off the cracks, rising and cooling
    spark_cloud(ov, 4, 10, k, lambda r: (m + r.uniform(-14, 14), m - MOUND_H + 4), (0.4, 1.0), (7, 12), CRACK_FRAMES,
                angle=(-2.5, -0.65), loop=CRACK_FRAMES, g=0.06, trail=3)  # and thrown off the heaving top
    return finish(c, ov)


def eruption_frame(kk: int) -> Image.Image:
    """Eruption, a one-shot growing from the floor spot (ERUPT_BASE): the telegraph's mound heaves up, cracks, glows and
    splits (frames 0-3), then bursts into a volcanic cone blasting a fountain of lava and fire, a ring of dust rolling
    out, lava bombs arcing out to splat and pool, a dark ash plume billowing up and magma flooding the base; it cools:
    the fire sinks, the cone crumbles, the lava darkens to crusted rock, embers fade and the smoke drifts away."""
    c = Canvas(VOLC_SIZE)
    ov = Canvas(VOLC_SIZE)
    m, b = VOLC_SIZE // 2, ERUPT_BASE
    k = kk / ERUPT_STEP  # design time; all the timings below are in it
    t = k - ERUPT_BLAST
    fade = 1.0 if k < 21 else max(0.0, (25 - k) / 5)  # the debris sinks into the floor at the end
    heat = 1.0 if k < 9 else max(0.0, 1 - (k - 8) / 15)
    # --- the cone / mound: its size and the lava in it
    if t < 0:
        p = (k + 1) / 4  # carries on from the telegraph's mound
        wb, wt, h, dome = MOUND_W + 8 * p, MOUND_W * 0.55 - 5 * p, MOUND_H + 18 * p, MOUND_H * 0.6 * (1 - p)
        cone_heat = 0.7 + 0.28 * p
    else:
        cr = min(1.0, max(0.0, (k - 12) / 12))  # the crumble
        wb, wt, dome = CONE_W + 8 * cr, CONE_WT + 10 * cr, -4 * (1 - cr) + 6 * cr
        h = (CONE_H + 5 * (abs(k - ERUPT_BLAST) < 0.4)) * (1 - cr ** 1.4)
        cone_heat = heat
    cy = b - h  # the crater: where fire and bombs come from
    rng = random.Random(21)
    bombs = [(rng.choice((-1, 1)) * rng.uniform(26, 98), rng.uniform(-6, 26), rng.uniform(60, 118),
              ERUPT_BLAST + rng.choice((0, 0, 1, 1, 2)), rng.randint(8, 12), (5, 4, 3, 4, 3, 5)[i % 6],
              rng.uniform(-5, 5)) for i in range(12)]
    rocks = [(rng.choice((-1, 1)) * rng.uniform(22, 86), rng.uniform(-2, 24), rng.uniform(40, 90), rng.randint(8, 12))
             for _ in range(8)]
    embers = [(rng.uniform(-70, 70), rng.uniform(-4, 28), rng.uniform(70, 140), rng.randint(0, 4), rng.randint(10, 18))
              for _ in range(22)]
    # --- the floor: scorch or magma pool, cracks, lava splats, rocks lying where they fell
    if t < 0:
        c.part(E((m - 30, b - 17, m + 30, b + 17)), MAROON, shade=False)
    else:
        pr = (26 + (POOL_R - 26) * min(1.0, t / 5)) * fade
        lava_pool(c, m, b + 2, pr, pr * 0.5, 1.0 if k < 9 else max(0.0, 1 - (k - 9) / 14), seed=2)
    erupt_cracks(c, m, b, ERUPT_R * (0.6 + 0.05 * min(k, 6)), lava_cols(cone_heat)[1] if heat > 0.15 else None)
    for i, (dx, ly, apex, k0, dur, r, x0) in enumerate(bombs):
        age = k - (k0 + dur)
        if age >= 0 and fade > 0:
            lava_pool(c, m + dx, b + ly, (r * 2.4 + 1) * fade, (r * 1.2 + 0.5) * fade, max(0.0, 0.9 - 0.065 * age),
                      seed=i)
    for dx, ly, apex, dur in rocks:
        if t >= dur and fade > 0.2:
            c.part(R((round(m + dx), round(b + ly), round(m + dx) + 2, round(b + ly) + 1)), BROWN, shade=False)
    if 0 <= t <= 5:  # the dust ring rolling out of the blast, puffs on a squashed ring
        erupt_smoke(c, [(m + math.cos(math.tau * i / 12 + 0.3) * (24 + 14 * t),
                         b + 8 + math.sin(math.tau * i / 12 + 0.3) * (24 + 14 * t) * ERUPT_SQUASH * 0.6,
                         round(max(0.0, 5 - 0.8 * t + (i % 2)))) for i in range(12)], STEEL_D, STEEL)
    elif 1 <= k < ERUPT_BLAST:  # the rumble before it: dust puffing up off the base
        erupt_smoke(c, [(m + math.cos(math.tau * i / 5 + 0.7) * (30 + k * 3), b + 6 + math.sin(math.tau * i / 5 + 0.7) * 9
                         - 3 * k, 3 + (i + int(k)) % 2) for i in range(5)])
    # --- the ash plume behind everything, then the cone and the fire it throws
    ash_plume(c, k, m, cy)
    rock_cone(c, m, b, wb, wt, h, dome, cone_heat)
    g = min(1.0, (19 - k) / 7)
    ki = int(kk)
    if lerp_tab(FIRE_H, k) > 0.5:
        hw, ht = lerp_tab(FIRE_HW, k), lerp_tab(FIRE_H, k)
        if t >= 0 and g > 0.1:  # the bonfire at the crater's foot
            c.part(E((m - 22 * g, cy - 6 * g, m + 22 * g, cy + 6 * g)), RED, shade=False, line=False)
        if ht > 40:
            for side in (-1, 1):  # smaller jets either side of the main fountain
                fire_column(c, m + side * hw * 0.8, cy + 2, ht * 0.6, hw * 0.6, ki + side, lean=side * 0.25)
        fire_column(c, m, cy + 2, ht, hw, ki, 4 <= k <= 8.5)
        if t >= 0:
            flame(c, round(m - 24 * g), round(m + 24 * g), round(cy + 5), max(4, round(30 * g)), ki, tongues=7, line=False)
    if abs(k - ERUPT_BLAST) < 0.4:  # the burst: a flash at the crater
        c.part(blobs([(m - 11, cy, 9), (m + 11, cy, 9), (m, cy - 6, 13)]), WHITE, shade=False)
    elif 0.4 <= k - ERUPT_BLAST < 1.4:
        c.part(blobs([(m - 8, cy - 2, 6), (m + 8, cy - 2, 6), (m, cy - 8, 8)]), YELLOW, shade=False, line=False)
    if 0 < k < ERUPT_BLAST:  # first sparks leaking out of the splitting top
        for i in range(int(k * 2)):
            sdot(ov, round(m - 8 + 4 * i + SWAY[(ki + i) % 4]), round(cy - 3 - (i * 5 + int(k * 3)) % 14),
                 (WHITE, YELLOW, ORANGE)[i % 3])
    # --- in the air: lava bombs, rocks, embers
    for dx, ly, apex, k0, dur, r, x0 in bombs:
        s = (k - k0) / dur
        if 0 <= s < 1:
            pos = lambda ss: arc(m + x0, cy, m + dx, b + ly, apex, ss)
            trail = [(*pos(max(0.0, s - 0.07 * j)), r * (0.55 - 0.15 * j), max(0.0, 0.8 - 0.2 * s - 0.15 * j))
                     for j in (1, 2)]
            lava_bomb(c, *pos(s), r, 1.0 - 0.3 * s, trail)
    for dx, ly, apex, dur in rocks:
        s = t / dur
        if 0 <= s < 1:
            x, y = arc(m, cy, m + dx, b + ly, apex, s)
            c.part(R((round(x) - 1, round(y) - 1, round(x) + 1, round(y) + 1)), BROWN if int(s * 6) % 2 else MAROON,
                   shade=False)
    for dx, ly, apex, k0, dur in embers:  # embers thrown up with the fountain: bright heads, cooling trails
        s = (t - k0) / dur
        if 0 <= s < 1:
            x, y = arc(m, cy, m + dx, b + ly, apex, s)
            col = SPARK_COLS[min(6, int(s * 7))]
            for j, tc in ((1, ORANGE), (2, RED), (3, MAROON)):
                tx, ty = arc(m, cy, m + dx, b + ly, apex, max(0.0, s - 0.045 * j))
                sdot(ov, round(tx), round(ty), tc if s < 0.7 else (RED, MAROON, MAROON)[j - 1])
            sdot(ov, round(x), round(y), col)
            if s < 0.4:
                sdot(ov, round(x) + 1, round(y), YELLOW)
    if k >= ERUPT_BLAST - 1:  # a spray of fine sparks off the fountain: fast, up and out, falling back cooling
        spark_cloud(ov, 88, 90, t, (m, cy - 2), (1.6, 5.2), (6, 12), 12.5, angle=(-2.55, -0.6), g=0.2, trail=3)
        spark_cloud(ov, 89, 30, t, lambda r: (m + r.uniform(-20, 20), cy + 4), (0.8, 2.2), (6, 11), 12.5,
                    angle=(-2.2, -0.9), g=0.1, trail=3, up=1.0)
        if 0 <= t < 14:  # the lava glows on the floor: firelight dithered round the pool
            gr = random.Random(2)
            for _ in range(70):
                a_, d_ = gr.uniform(0, math.tau), gr.uniform(0.3, 1.25)
                x, y = round(m + math.cos(a_) * POOL_R * d_), round(b + 2 + math.sin(a_) * POOL_R * d_ * 0.52)
                if (x + y) % 2 == 0 and d_ > 0.9 - 0.03 * t and d_ * (1 + 0.03 * t) < 1.25 and fade > 0.5:
                    sdot(ov, x, y, ORANGE if d_ < 1.0 else RED)
    return finish(c, ov)


SLASH_FRAMES = 6
SLASH_SIZE = 112
SLASH_R = 46  # outer radius of the arc in art px (drawn scaled to the weapon's reach)
SLASH_ARC = math.radians(150)


def slash_frame(k: int) -> Image.Image:
    """Sword swing smear, facing right, swept from top to bottom: a crescent whose leading edge races
    round the arc (thick at the head, tapering to the tail) while the tail catches up. White edge,
    light core: tinted to the weapon's colour in game."""
    c = Canvas(SLASH_SIZE)
    m = SLASH_SIZE // 2
    head = (0.45, 0.85, 1.0, 1.0, 1.0, 1.0)[k]
    tail = (0.0, 0.0, 0.15, 0.45, 0.7, 0.88)[k]

    def band(r_out, width, color):
        a0, a1 = -SLASH_ARC / 2 + SLASH_ARC * tail, -SLASH_ARC / 2 + SLASH_ARC * head
        n = 32
        outer, inner = [], []
        for i in range(n + 1):
            u = i / n
            a = a0 + (a1 - a0) * u
            w = max(1.0, width * math.sqrt(u) * (1 - 0.5 * tail))
            outer.append((m + math.cos(a) * r_out, m + math.sin(a) * r_out))
            inner.append((m + math.cos(a) * (r_out - w), m + math.sin(a) * (r_out - w)))
        c.flat(P(outer + inner[::-1]), color)

    band(SLASH_R, 20, STEEL)
    band(SLASH_R, 8, WHITE)
    return c.img


# --- projectiles: per-weapon bullets (assets/sprites/projectiles/<weapon id>.png) --------------
# 2-frame strips of PROJ x PROJ cells pointing right, centred; the game rotates them to the flight
# direction, alternates the frames (flicker / spin) and draws crits bigger and flashing.
PROJ = 20
PROJ_OUT = OUT / "projectiles"


def bolt_shot(core, glow, length, h):
    """Energy bolt: a glowing capsule with a hot core, the tail flickering longer on frame 1."""
    def draw(c, f):
        m = PROJ // 2
        tail = length + 2 * f
        c.part(RR((m - tail // 2, m - h, m + length // 2, m + h), h), glow, shade=False)
        c.flat(RR((m - tail // 2 + 2, m - h + 1, m + length // 2 - 1, m + h - 1), max(1, h - 1)), core)
    return draw


def tracer(c, f):  # sniper: a long white-hot needle with a cyan sheath
    m = PROJ // 2
    c.part(R((2, m - 1, PROJ - 3, m + 1)), TEAL_L, shade=False)
    c.flat(R((4 - 2 * f, m, PROJ - 3, m)), WHITE)


def pellet(c, f):  # shotgun: a hot lead ball
    m = PROJ // 2
    c.part(E((m - 3, m - 3, m + 3, m + 3)), ORANGE)
    c.dot(m - 1 + f, m - 1, YELLOW)


def kunai(c, f):  # Flicker's kunai: steel diamond blade, red-wrapped grip and a ring, point first
    m = PROJ // 2
    c.part(P([(PROJ - 3, m), (m + 2, m - 3), (m - 1, m), (m + 2, m + 3)]), STEEL)
    c.flat(L([(m, m), (PROJ - 4, m)], 1), WHITE)
    c.part(R((m - 4, m - 1, m - 1, m + 1)), RED, shade=False)
    c.part(E((m - 8, m - 2, m - 4, m + 2)), STEEL_D, shade=False)
    c.dot(m - 6, m, OUTLINE)  # ring hole
    if f:
        c.dot(PROJ - 4, m - 1, WHITE)


def brass(c, f):  # Twinshot's revolver: a brass bullet with a copper tip
    m = PROJ // 2
    c.part(RR((m - 5, m - 2, m + 3, m + 2), 1), YELLOW)
    c.part(P([(m + 3, m - 2), (m + 7, m), (m + 3, m + 2)]), ORANGE)
    if f:
        c.flat(R((m - 7, m - 1, m - 6, m + 1)), YELLOW)


def rocket_shot(c, f):  # rocket: steel body, red nose and fins, flickering exhaust
    m = PROJ // 2
    flame = ((m - 8, m - 2, m - 4, m + 2), (m - 8, m - 1, m - 5, m + 1))[f]
    c.part(E(flame), ORANGE, shade=False)
    c.flat(E((flame[0] + 2, m - 1, flame[2], m + 1)), YELLOW)
    c.part(P([(m - 5, m - 4), (m - 2, m - 2), (m - 2, m + 2), (m - 5, m + 4)]), RED)
    c.part(RR((m - 5, m - 2, m + 5, m + 2), 1), STEEL)
    c.part(P([(m + 5, m - 2), (m + 7, m), (m + 5, m + 2)]), RED)


def grenade_shot(c, f):  # bouncing grenade: teal shell, steel cap; the band rolls round
    m = PROJ // 2
    c.part(E((m - 5, m - 5, m + 5, m + 5)), TEAL)
    c.part(R((m - 2, m - 7, m + 2, m - 5)), STEEL, line=False)
    if f:
        c.flat(R((m - 5, m - 1, m + 5, m)), NAVY)
    else:
        c.flat(R((m - 1, m - 5, m, m + 5)), NAVY)
    c.dot(m - 2, m - 3, TEAL_L)


def fireball(c, f):  # Flint: a fireball with a licking tail that flickers
    m = PROJ // 2
    tail = (m - 8, m - 7)[f]
    c.part(P([(tail, m - 1 - f), (m, m - 4), (m, m + 4), (tail + 1, m + 2)]), RED, shade=False)
    c.part(E((m - 3, m - 4, m + 5, m + 4)), ORANGE)
    c.flat(E((m - 1, m - 2, m + 3, m + 2)), YELLOW)
    c.dot(m + 1, m - 1, WHITE)


def petal(c, f):  # Sakura: a cherry blossom petal, notched at the tip, tumbling (it flips each frame)
    m = PROJ // 2
    h = 4 if f else 2
    c.part(P([(m - 5, m), (m - 1, m - h), (m + 4, m - h + 1), (m + 6, m - 1), (m + 4, m), (m + 6, m + 1),
              (m + 4, m + h - 1), (m - 1, m + h)]), PINK_L)
    c.flat(L([(m - 4, m), (m + 2, m)], 1), PINK)


def blossom_shot(c, f):  # Blossom Snare: a big cherry blossom spinning as it flies (4 frames = a fifth of a turn)
    m = PROJ // 2
    spin = 0.31 * f
    for i in range(5):
        a = spin + math.tau * i / 5
        ward_petal(c, m + math.cos(a) * 4.0, m + math.sin(a) * 4.0, a, 7, 1.0, WHITE if i % 2 else PINK_L)
    c.flat(E((m - 2, m - 2, m + 2, m + 2)), PINK)
    c.dot(m, m, YELLOW)


def plasma(c, f):  # bot blaster: a wobbling pink-red plasma blob
    m = PROJ // 2
    r = 5 if f else 4
    c.part(E((m - r, m - 4, m + r, m + 4)), RED)
    c.flat(E((m - 2, m - 2, m + 2, m + 2)), WHITE)


PROJECTILES = {
    "pistol": bolt_shot(WHITE, YELLOW, 10, 2),
    "smg": bolt_shot(WHITE, TEAL_L, 8, 1),
    "shotgun": pellet,
    "sniper": tracer,
    "rocket": rocket_shot,
    "grenade": grenade_shot,
    "flicker_kunai": kunai,
    "blade_fan": kunai,
    "twinshot_revolver": brass,
    "bot_blaster": plasma,
    "flint_palm": fireball,
    "flare_ring": fireball,
    "sakura_fan": petal,
    "petal_storm": petal,
    "blossom_snare": blossom_shot,
}
## Strips with more than the usual 2 frames.
PROJECTILE_FRAMES = {"blossom_snare": 4}


def projectile_strip(draw, n: int = 2) -> Image.Image:
    frames_ = []
    for f in range(n):
        c = Canvas(PROJ)
        draw(c, f)
        frames_.append(outline(c.img))
    return strip(frames_)


## --- Fire sparks (Flint's FX): small bright embers that fly off a fire and cool as they go ---------------------------
## Sparks are drawn on their own canvas AFTER outline() (bright, unoutlined, `sdot` keeps them off the frame edge).
SPARK_COLS = (WHITE, YELLOW, YELLOW, ORANGE, ORANGE, RED, MAROON)


def finish(c: Canvas, ov: Canvas) -> Image.Image:
    """Outlines the drawn art, then lays the spark canvas on top."""
    img = outline(c.img)
    img.alpha_composite(ov.img)
    return img


def lerp_tab(tab, u: float) -> float:
    """tab[u] with linear interpolation (u clamped to the table)."""
    u = min(max(u, 0.0), len(tab) - 1.0)
    i = min(int(u), len(tab) - 2)
    return tab[i] + (tab[i + 1] - tab[i]) * (u - i)


def ember_spark(c: Canvas, x, y, vx, vy, age, life, g=0.0, trail=3):
    """One fire spark `age` into its `life` (same time unit as vx / vy per unit): a bright 1-2 px head (white, yellow, then
    cooling orange, red, maroon) with a trail of cooler dots along the path it just flew; gravity `g` (+ = falls)."""
    if age < 0 or age >= life:
        return
    f = age / life
    pos = lambda a: (x + vx * a, y + vy * a + 0.5 * g * a * a)
    for j in range(trail, 0, -1):
        a = age - j * 0.55
        if a >= 0:
            tx, ty = pos(a)
            sdot(c, round(tx), round(ty), (ORANGE, RED, MAROON, MAROON)[min(3, j - 1 + (f > 0.7))])
    hx, hy = pos(age)
    sdot(c, round(hx), round(hy), SPARK_COLS[min(6, int(f * 7))])
    if f < 0.45:  # still white-hot: a second px behind it along its flight
        vxa, vya = vx, vy + g * age
        n = math.hypot(vxa, vya) or 1.0
        sdot(c, round(hx - vxa / n), round(hy - vya / n), WHITE if f < 0.15 else YELLOW)


def spark_cloud(c: Canvas, seed: int, n: int, k: float, origin, speed, life, window, angle=(0.0, math.tau), g=0.0,
                loop: float = 0, squash: float = 1.0, up: float = 0.0, trail: int = 3):
    """`n` sparks born at random moments in [0, window) from `origin` ((x, y) or a callable(rng) -> (x, y)), flying at
    random angles in `angle` and speeds in `speed` (px per frame), each living `life` (a range) frames. With `loop` > 0 the
    births repeat every `loop` frames, so a loop strip stays seamless (window == loop, life < loop)."""
    rng = random.Random(seed)
    for _ in range(n):
        ox, oy = origin(rng) if callable(origin) else origin
        a, sp, lf, birth = rng.uniform(*angle), rng.uniform(*speed), rng.uniform(*life), rng.uniform(0, window)
        age = (k - birth) % loop if loop else k - birth
        ember_spark(c, ox, oy, math.cos(a) * sp, math.sin(a) * sp * squash - up, age, lf, g, trail)


## Flare Burst (Flint): his flames swell and brighten (FLARE_CHARGE_FRAMES CELL frames over the 0.25 s charge, embers
## streaming in to a white-hot heart), then a ring of fire races out along the floor (FLARE_FRAMES frames of FLARE_W x
## FLARE_W art px, centred on his feet; its reach FLARE_R = flare_burst_blast.tres splash 120 / SPRITE_SCALE 1.5 =
## SpecialFx.FLARE_ART_RADIUS) and leaves embers and smoke. The poof plays it over a fixed time, so more frames = smoother.
FLARE_CHARGE_FRAMES = 10
FLARE_FRAMES = 30
FLARE_W = 192
FLARE_R = 80
FLARE_SQUASH = 0.75  # the floor seen in 3/4 view


def flint_flare_frame(k: int) -> Image.Image:
    """Charging: his idle look stoked up (heat rises 0 -> 1) with a white-hot core swelling in his chest, a flickering
    halo round it and embers streaming in from all round to feed it."""
    n = FLARE_CHARGE_FRAMES
    h = k / (n - 1)
    low, up = flint(None, k % 4, heat=h)
    f = flint_embers(k % 4, h).img
    f.alpha_composite(low.img)
    f.alpha_composite(up.img, (0, UPPER_DY))
    r = 0
    core = Canvas()
    if k >= 3:  # the heart blazes through his suit
        r = 3 + round(8 * (k - 3) / (n - 4))
        core.flat(E((32 - r, 40 - r, 32 + r, 40 + r)), YELLOW)
        core.flat(E((32 - r + 2, 40 - r + 2, 32 + r - 2, 40 + r - 2)), WHITE)
        f.alpha_composite(core.img, (0, UPPER_DY))
    c = flint_crown(k % 4, 0, h).img
    c.alpha_composite(f, (PAD, PAD))
    img = outline(c)
    hx, hy = PAD + 32, PAD + UPPER_DY + 40
    ov = Canvas(CELL)
    px = img.load()
    if k >= 4:  # a flickering halo of heat round the heart, dithered, brighter as it swells
        for y in range(hy - r - 9, hy + r + 10):
            for x in range(hx - r - 9, hx + r + 10):
                d = math.hypot(x - hx, (y - hy) * 1.1)
                if r + 1 <= d <= r + 3 + 6 * h and (x + y + k) % 2 == 0 and not px[x, y][3]:
                    ov.dot(x, y, YELLOW if d < r + 3 + h else ORANGE)
    rng = random.Random(11)
    for i in range(34):  # embers gathering in: faint at the edge, white-hot as they reach the heart
        a, r0 = rng.uniform(0, math.tau), rng.uniform(20, 42)
        birth, life = rng.uniform(-3, n - 3), rng.uniform(4, 7)
        age = k - birth
        if not 0 <= age < life:
            continue
        s = age / life
        e = s * s * (3 - 2 * s * 0.5)  # accelerating inwards
        for back, col in ((0.12, RED), (0.06, ORANGE)):
            e2 = max(0.0, s - back)
            e2 = e2 * e2 * (3 - 2 * e2 * 0.5)
            q = r0 * (1 - e2)
            sdot(ov, round(hx + math.cos(a) * q), round(hy + math.sin(a) * q * 0.85), col)
        q = r0 * (1 - e)
        col = (RED, ORANGE, YELLOW, WHITE)[min(3, int(s * 4))]
        sdot(ov, round(hx + math.cos(a) * q), round(hy + math.sin(a) * q * 0.85), col)
        if s > 0.5:
            sdot(ov, round(hx + math.cos(a) * q) + 1, round(hy + math.sin(a) * q * 0.85), YELLOW)
    spark_cloud(ov, 12, 7, k, (hx, PAD + 12), (0.5, 1.2), (3, 6), n - 4, angle=(-2.4, -0.75), up=0.2, trail=2)
    img.alpha_composite(ov.img)
    return img


def flare_lick(c: Canvas, x: float, y: float, s: float, col_idx: int):
    """A detached lick of flame (a teardrop, red rim, orange, yellow heart) of size `s`, cooling with col_idx 0-2."""
    if s < 1.2:
        c.dot(round(x), round(y), (YELLOW, ORANGE, RED)[min(2, col_idx)])
        return
    rim = (RED, RED, MAROON)[min(2, col_idx)]
    mid = (ORANGE, ORANGE, RED)[min(2, col_idx)]
    c.part(P([(x - s * 0.55, y), (x - s * 0.3, y - s * 0.9), (x + SWAY[int(x) % 4] * 0.5, y - s * 1.9),
              (x + s * 0.35, y - s * 0.9), (x + s * 0.55, y)]), rim, shade=False, line=False)
    if s >= 2:
        c.flat(P([(x - s * 0.3, y), (x - s * 0.1, y - s * 0.8), (x, y - s * 1.4), (x + s * 0.2, y - s * 0.8),
                  (x + s * 0.3, y)]), mid)
    if s >= 3:
        c.flat(P([(x - s * 0.12, y), (x, y - s * 0.9), (x + s * 0.12, y)]), YELLOW)


def flare_tongues() -> list:
    """The wall's tongues, uneven on purpose: spacing, height (a few tall, many short), width, lean, when each catches
    and burns out, its flicker rate. Plus a low bed of small flames between them. (angle, height, width, lean, appear,
    burnout, rate, phase, big) sorted back to front."""
    rng = random.Random(77)
    out = []
    a = rng.uniform(0, 0.2)
    while a < math.tau - 0.08:
        roll = rng.random()
        hv = rng.uniform(1.35, 1.75) if roll < 0.22 else rng.uniform(0.5, 0.78) if roll < 0.5 else rng.uniform(0.86, 1.18)
        out.append((a, hv, rng.uniform(0.6, 1.5), rng.uniform(-0.18, 0.22), rng.uniform(0.6, 3.2), 8 + rng.uniform(0, 3.5),
                    rng.choice((1.0, 1.5, 2.0, 2.5)), rng.uniform(0, math.tau), True))
        if rng.random() < 0.4:  # a smaller lick leaning against it
            out.append((a + rng.choice((-1, 1)) * rng.uniform(0.05, 0.1), hv * rng.uniform(0.3, 0.5), rng.uniform(0.5, 0.8),
                        rng.uniform(-0.1, 0.3), rng.uniform(1.0, 3.6), 7.5 + rng.uniform(0, 3), 2.5, rng.uniform(0, math.tau),
                        False))
        a += rng.uniform(0.07, 0.27)
    for _ in range(40):  # the bed of low flames
        out.append((rng.uniform(0, math.tau), rng.uniform(0.17, 0.34), rng.uniform(0.45, 0.75), 0.0, rng.uniform(0.8, 3.0),
                    7 + rng.uniform(0, 3), 3.0, rng.uniform(0, math.tau), False))
    out.sort(key=lambda q: math.sin(q[0]))
    return out


def flare_ring_frame(k: int, floor_layer: bool = False) -> Image.Image:
    """Frame k of FLARE_FRAMES: a white flash, a wall of uneven flame tongues (tall and stubby, each catching, flickering
    and dying on its own beat, with a low bed of flame between and embers snapping off the tips) racing out along the
    floor over a scorched band while the flash cools in the middle; then the wall tears into free licks of flame that
    lift off, shrink and cool to embers, the scorch cracks glow and dither away, and smoke wisps and ash drift up and
    out, a spray of sparks flying all the way through. `floor_layer` returns just the flat floor parts (flash, scorch band,
    glow, cracks). Designed in 18 "old" frames (u) and sampled finer."""
    n = FLARE_W
    c = Canvas(n)
    fl = Canvas(n)  # the flat floor parts, split out so they draw under the players
    ov = Canvas(n)
    m = n // 2
    rng = random.Random(41)
    sq = FLARE_SQUASH
    u = k * 17 / (FLARE_FRAMES - 1)
    ui = int(u)
    ring_r = lambda uu: 10 + (FLARE_R - 10) * (1 - (1 - min(1.0, uu / 9)) ** 2) - max(0.0, uu - 9) * 0.6
    run = min(1.0, u / 9)
    r = ring_r(u)
    d_age = max(0.0, u - 9)
    if 2 <= u <= 14.99:  # a scorched band on the floor behind the front, thinning to dots as it cools
        band = 18 if u <= 9 else 7
        d = ImageDraw.Draw(fl.img)
        for rr, col in ((r, MAROON if u < 11 else SHADOW), (r - band, None)):
            if rr > 2:
                d.ellipse((m - rr, m - rr * sq, m + rr, m + rr * sq), fill=(col + (255,)) if col else (0, 0, 0, 0))
        if u >= 10:  # dither it away
            mod = 2 + int(u - 10) // 2
            for y in range(n):
                for x in range(n):
                    if fl.px[x, y][3] and (x + y * 2) % mod != 0:
                        fl.px[x, y] = (0, 0, 0, 0)
        if u < 7:  # the flash cooling at the middle
            fr = (26, 21, 16, 12, 8)[ui - 2] if ui - 2 < 5 else 5
            fl.flat(E((m - fr, m - fr * sq, m + fr, m + fr * sq)), (WHITE, WHITE, YELLOW, ORANGE, RED)[min(4, ui - 2)])
        if 3 <= u < 10:  # the inner edge glows, a hot highlight lower down on the far side
            ri = r - band + 3
            fl.flat(lambda dd, f: dd.ellipse((m - ri, m - ri * sq, m + ri, m + ri * sq), outline=f, width=2),
                   ORANGE if u < 8 else RED)
            if u < 9:
                fl.flat(lambda dd, f: dd.arc((m - ri + 2, m - (ri - 2) * sq, m + ri - 2, m + (ri - 2) * sq), 20, 160, fill=f,
                                            width=1), YELLOW)
        if 7 <= u < 14:  # glowing cracks in the scorch, cooling
            col = (YELLOW, ORANGE, ORANGE, RED, RED, MAROON, MAROON)[ui - 7]
            cr = random.Random(8)
            for _ in range(11):
                a = cr.uniform(0, math.tau)
                rad = cr.uniform(0.25, 0.95) * r
                x0, y0 = m + math.cos(a) * rad, m + math.sin(a) * rad * sq
                fl.flat(L([(x0, y0), (x0 + cr.uniform(-5, 5), y0 + cr.uniform(-2, 2)),
                          (x0 + cr.uniform(-9, 9), y0 + cr.uniform(-3, 3))], 1), col)
    if u < 2:  # the flash: a white-hot disc with rays
        fr = (16, 30)[ui]
        fl.flat(E((m - fr, m - fr * sq, m + fr, m + fr * sq)), YELLOW)
        fl.flat(E((m - fr + 5, m - (fr - 5) * sq, m + fr - 5, m + (fr - 5) * sq)), WHITE)
        if ui == 1:
            for a in range(0, 360, 45):
                ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
                fl.flat(L([(m + ca * (fr + 2), m + sa * (fr + 2) * sq), (m + ca * (fr + 16), m + sa * (fr + 16) * sq)], 2),
                       WHITE)
    tongues = flare_tongues()
    for a, hv, wv, lean_j, appear, burn, rate, ph0, big in tongues:  # the wall, back to front
        life = 1.0 if u <= burn else max(0.0, 1 - (u - burn) / 4)
        grow = min(1.0, max(0.0, (u - appear) / 2.4))
        if life <= 0 or grow <= 0:
            continue
        ca, sa = math.cos(a), math.sin(a)
        rr = ring_r(max(u, appear)) + (0 if big else 3 * math.sin(a * 5 + ph0))
        x, y = m + ca * rr, m + sa * rr * sq
        flick = 1 + 0.3 * math.sin(math.tau * u * rate / 8 + ph0) + 0.1 * math.sin(math.tau * u * rate / 3 + ph0 * 2)
        hgt = max(2.0, (24 + 10 * (1 - run)) * hv * life * (grow ** 0.7) * flick)
        hgt = min(hgt, y - 9)  # the far side's tall tongues stay inside the frame
        lean = ca * hgt * 0.2 * (1 + 0.5 * (1 - life)) + lean_j * hgt
        tipx = x + lean + SWAY[(k + int(a * 5)) % 4] + 2 * math.sin(math.tau * u / 5 + ph0)
        flame_tongue(c, (x, y), (x + lean * 0.5 + math.sin(ph0 + u) * 1.2, y - hgt * 0.55), (tipx, y - hgt),
                     math.tau * u / 4 + ph0, 1, (4.6 if big else 3.0) * wv * (0.55 + 0.45 * life) * min(1.0, 0.5 + grow), m)
    big_ones = [q for q in tongues if q[8]]
    if d_age > 0:  # free licks lifting off where the wall stood, cooling as they climb
        for a, hv, wv, lean_j, appear, burn, rate, ph0, big in big_ones:
            rs = (ph0 / math.tau)
            age = d_age - rs * 3
            if age < 0:
                continue
            ca, sa = math.cos(a), math.sin(a)
            rad = min(r + age * (1.6 + 1.0 * rs), 84)
            lift = 8 + age ** 1.25 * (3.0 + 1.6 * rs)
            x, y = m + ca * rad + SWAY[(k + int(a * 7)) % 4], m + sa * rad * sq - lift
            if y < 12:
                continue  # lifted clear out of the frame
            s = (4.2 - 0.5 * age) * min(hv, 1.3)
            if s > 0.7:
                flare_lick(c, x, y, s, min(2, int(age / 2.2)))
            elif age < 9:
                c.dot(round(x), round(y), (ORANGE, RED, MAROON)[min(2, int((age - 6) / 1.2)) if age > 6 else 0])
    if u >= 7:  # wisps of smoke: small lumps, dark under, lit on top, drifting up and out, thinning away
        for j in range(9):
            ang = rng.uniform(0, math.tau)
            rad = rng.uniform(0.25, 0.9) * FLARE_R
            age = u - 7 - j % 3
            if age < 0 or age > 9:
                continue
            px_, py_ = m + math.cos(ang) * (rad + age * 1.2), m + math.sin(ang) * rad * sq - 6 - age * 3.2
            if py_ < 12:
                continue
            sr = 1.2 + min(age, 5) * 0.5 + (j % 2) * 0.6
            if age > 6 and (j + k) % 2:
                continue  # breaks into fewer lumps
            c.part(blobs([(px_, py_, sr), (px_ + sr * 0.9, py_ + 1, sr * 0.7)]), SHADOW if age > 3 else STEEL_D,
                   shade=False)
            if sr >= 2:
                c.flat(E((px_ - sr * 0.6, py_ - sr * 0.7, px_ - sr * 0.05, py_ - sr * 0.2)),
                       STEEL if age < 5 else STEEL_D)
            if age <= 2:  # still lit red from the fire below
                c.dot(round(px_), round(py_ + sr * 0.6), RED)
    # --- sparks (old-frame units): snapping off the tips of the tall tongues, and a spray off the racing front
    sr_ = random.Random(5)
    for a, hv, wv, lean_j, appear, burn, rate, ph0, big in big_ones:
        for _ in range(2):
            birth = appear + 1.5 + sr_.uniform(0, 7)
            vx, vy, lf = sr_.uniform(-0.5, 0.5), -sr_.uniform(1.1, 2.4), sr_.uniform(4, 8)
            ca, sa = math.cos(a), math.sin(a)
            rb = ring_r(birth)
            ember_spark(ov, m + ca * rb, m + sa * rb * sq - 24 * hv, vx + ca * sr_.uniform(0.4, 1.2), vy, u - birth, lf,
                        0.08, 3)
    for _ in range(56):
        a, birth = sr_.uniform(0, math.tau), sr_.uniform(1.5, 12)
        sp, lf = sr_.uniform(0.8, 2.6), sr_.uniform(4, 9)
        rb = ring_r(birth) * sr_.uniform(0.7, 1.05)
        ca, sa = math.cos(a), math.sin(a)
        ember_spark(ov, m + ca * rb, m + sa * rb * sq - 4, ca * sp, sa * sp * sq - sr_.uniform(0.6, 2.0), u - birth, lf, 0.07, 3)
    if floor_layer:
        return finish(fl, Canvas(n))
    return finish(c, ov)


def strip(frames_: list[Image.Image]) -> Image.Image:
    w, h = frames_[0].size
    out = Image.new("RGBA", (w * len(frames_), h), (0, 0, 0, 0))
    for i, f in enumerate(frames_):
        out.paste(f, (i * w, 0))
    return out


FX = {
    "poof": lambda: strip([poof_frame(80, k, WHITE) for k in range(POOF_FRAMES)]),
    "poof_small": lambda: strip([poof_frame(48, k, WHITE) for k in range(POOF_FRAMES)]),
    "smoke": lambda: strip([smoke_frame(k) for k in range(SMOKE_FRAMES)]),
    "blast": lambda: strip([blast_frame(k) for k in range(BLAST_FRAMES)]),
    "slam": lambda: strip([slam_frame(k) for k in range(SLAM_FRAMES)]),
    "slash": lambda: strip([slash_frame(k) for k in range(SLASH_FRAMES)]),
    "eruption_crack": lambda: strip([eruption_crack_frame(k) for k in range(CRACK_FRAMES)]),
    "eruption": lambda: strip([eruption_frame(k) for k in range(ERUPT_FRAMES)]),
    # Transformation strips (SkillData.form_morph): the character's first idle frame into the form's.
    # 1.35 = great_ape.tres form_scale (keep in sync).
    "wukong_ape_morph": lambda: strip(morph_frames(frames(wukong, AURAS["wukong"])[0],
                                                   frames(wukong_ape, AURAS["wukong_ape"])[0], 1.35, ape_morph)),
    "flint_inferno_morph": flint_inferno_morph,
    "blossom_ward": lambda: strip([blossom_ward_frame(k) for k in range(WARD_FRAMES)]),
    "blossom_ward_open": lambda: strip([blossom_ward_open_frame(k) for k in range(WARD_OPEN_FRAMES)]),
    "blossom_ward_close": lambda: strip([blossom_ward_close_frame(k) for k in range(WARD_CLOSE_FRAMES)]),
    "snare_vines": lambda: strip([snare_vines_frame(k) for k in range(SNARE_FRAMES)]),
    "snare_burst": lambda: strip([snare_burst_frame(k) for k in range(SNARE_BURST_FRAMES)]),
    "petal_pop": lambda: strip([petal_pop_frame(k) for k in range(POP_FRAMES)]),
    "sakura_drift": lambda: strip([drift_swirl_frame(k) for k in range(DRIFT_FRAMES)]),
    "sakura_dissolve": lambda: strip([drift_dissolve_frame(k) for k in range(DRIFT_FRAMES)]),
    "sakura_reform": lambda: strip([drift_reform_frame(k) for k in range(DRIFT_FRAMES)]),
    # Grapple Kunai (SpecialFx): the zip pose loop, the bite spark, chain links.
    "flicker_zip": lambda: strip([flicker_zip(i) for i in range(ZIP_FRAMES)]),
    "grapple_spark": lambda: strip([grapple_spark(k) for k in range(GRAPPLE_SPARK_FRAMES)]),
    "grapple_chain": lambda: strip([grapple_chain(k) for k in range(8)]),
    "grapple_throw": lambda: strip([grapple_throw(k) for k in range(GRAPPLE_THROW_FRAMES)]),
    "grapple_land": lambda: strip([grapple_land(k) for k in range(GRAPPLE_LAND_FRAMES)]),
    "wukong_swing": lambda: strip([wukong_swing_frame(k) for k in range(SWING_FRAMES)]),
    "leaf_burst": lambda: strip([leaf_burst_frame(k) for k in range(LEAF_FRAMES)]),
    "swing_dust": lambda: strip([dust_frame(k) for k in range(DUST_FRAMES)]),
    "wukong_whirl": lambda: strip([wukong_whirl_frame(k) for k in range(WHIRL_FRAMES)]),
    "whirl_ring": lambda: strip([whirl_ring_frame(k) for k in range(WHIRL_FRAMES)]),
    "whirl_spark": lambda: strip([whirl_spark_frame(k) for k in range(WHIRL_SPARK_FRAMES)]),
    "wukong_pillar": lambda: strip([wukong_pillar_frame(k) for k in range(PILLAR_POSE_FRAMES)]),
    "flint_flare": lambda: strip([flint_flare_frame(k) for k in range(FLARE_CHARGE_FRAMES)]),
}
## Not square strips: single images (checked whole).
## (sky_pillar: frames are wider than tall, so it is checked whole; frames keep clear of their edges by construction.)
FX_IMAGES = {"vine": vine, "vine_top": vine_top,
             "sky_pillar": lambda: strip([sky_pillar_frame(k) for k in range(PILLAR_FRAMES)]),
             "flare_ring": lambda: strip([flare_ring_frame(k) for k in range(FLARE_FRAMES)]),
             "flare_ring_floor": lambda: strip([flare_ring_frame(k, True) for k in range(FLARE_FRAMES)])}


CHARACTERS = {"flicker": flicker, "warden": warden, "twinshot": twinshot, "wukong": wukong, "flint": flint,
              "sakura": sakura}
## Transformation sheets (SkillData.form_sprite_sheet): laid out like characters, no hands.
# --- Inferno (Flint's form): flames licking up round him and fire sparks flying off ----------------------------------
INFERNO_LICKS = ((8, 52, 15, -1), (56, 52, 16, 1), (5, 34, 12, -1), (59, 36, 13, 1), (14, 22, 10, -1), (50, 20, 11, 1))


def flint_inferno_aura(i: int, h: float = 1.0) -> Canvas:
    """Behind Inferno Flint (period 4): flames licking up on both sides of him, each on its own beat, with fire sparks
    (bright heads, cooling trails) streaming up and out. `h` 0..1 scales it for the morph."""
    c = flint_embers(i, h)
    ph = math.tau * i / 4
    for n, (x, y, height, side) in enumerate(INFERNO_LICKS):
        hh = height * h * (1 + 0.18 * math.sin(ph + n * 1.9))
        if hh < 4:
            continue
        sw = side * (1.2 + 1.5 * math.sin(ph + n)) + side * 1.5
        flame_tongue(c, (x, y), (x + sw * 0.5, y - hh * 0.55), (x + sw + side * 1.5, y - hh), ph + n * 2.3, 1, 3.2 * min(1.0, 0.4 + h) , 32)
    spark_cloud(c, 17, int(3 + 7 * h), i, lambda r: (r.choice((r.uniform(4, 14), r.uniform(50, 60))), r.uniform(20, 52)),
                (0.2, 0.8), (3, 4), 4, angle=(-2.4, -0.75), loop=4, up=1.4, trail=2)
    return c


# --- Supernova (Flint, VOLLEY of 16 fireballs): the burst the ring of fireballs leaves from -------------------
SUPERNOVA_W = 160
SUPERNOVA_FRAMES = 16
SUPERNOVA_R = 50  # the ring's reach in art px


def supernova_frame(k: int) -> Image.Image:
    """Supernova (SUPERNOVA_FRAMES, centred on him, a one-shot): embers rush in and a white-hot core flashes with rays,
    then a ring of fire races out - 16 long spokes of flame, one per fireball, between smaller uneven licks, round a thin
    ring of flame - while sparks fly off in every direction; the ring tears into embers and thins out."""
    n = SUPERNOVA_W
    c = Canvas(n)
    ov = Canvas(n)
    m = n // 2
    rng = random.Random(23)
    run = min(1.0, max(0.0, (k - 1) / 9))
    r = 6 + (SUPERNOVA_R - 6) * (1 - (1 - run) ** 2)
    life = 1.0 if k <= 9 else max(0.0, 1 - (k - 9) / 6)
    spokes = []
    for i in range(16):  # one spoke per fireball, uneven in length and timing
        spokes.append((math.tau * (i + 0.5) / 16, rng.uniform(0.7, 1.3), rng.uniform(0, math.tau), rng.uniform(0, 1.0)))
    for _ in range(18):  # smaller licks between
        spokes.append((rng.uniform(0, math.tau), rng.uniform(0.3, 0.55), rng.uniform(0, math.tau), rng.uniform(0, 1.0)))
    if k >= 1 and life > 0:
        for rr, col, w in ((r, RED, 5), (r - 1, ORANGE, 3), (r - 2, YELLOW, 1)):  # the ring of flame itself
            if k < 11 or col == RED:
                c.flat(lambda d, f, rr=rr, w=w: d.ellipse((m - rr, m - rr * 0.9, m + rr, m + rr * 0.9), outline=f,
                                                         width=max(1, round(w * life))), col)
    for a, lv, ph0, d in spokes:  # flame tongues pointing outward
        if k < 1 + d * 2 or life <= 0:
            continue
        ca, sa = math.cos(a), math.sin(a)
        length = (22 + 8 * (1 - run)) * lv * life * min(1.0, (k - d * 2) / 3) * (1 + 0.22 * math.sin(k * 1.1 + ph0))
        length = min(length, 70 - r)  # stays inside the frame
        if length < 3:
            continue
        bend = math.sin(k * 0.7 + ph0) * 3
        root = (m + ca * (r - 2), m + sa * (r - 2) * 0.9)
        ctrl = (m + ca * (r + length * 0.5) - sa * bend * 0.5, m + sa * (r + length * 0.5) * 0.9 + ca * bend * 0.5)
        tip = (m + ca * (r + length) - sa * bend, m + sa * (r + length) * 0.9 + ca * bend)
        flame_tongue(c, root, ctrl, tip, math.tau * k / 6 + ph0, 1, (4.2 if lv > 0.6 else 2.4) * (0.5 + 0.5 * life), m)
    if k <= 5:  # the core: white-hot, shrinking back as the ring leaves
        cr = (12, 20, 17, 13, 9, 5)[k]
        c.flat(E((m - cr, m - cr * 0.9, m + cr, m + cr * 0.9)), YELLOW if k else WHITE)
        c.flat(E((m - cr + 3, m - (cr - 3) * 0.9, m + cr - 3, m + (cr - 3) * 0.9)), WHITE)
        if k in (1, 2):  # rays
            for j in range(16):
                a = math.tau * (j + 0.5) / 16
                ln = (cr + 12 + (j % 3) * 5) * (1 + 0.3 * (k == 1))
                c.flat(L([(m + math.cos(a) * (cr + 2), m + math.sin(a) * (cr + 2) * 0.9),
                          (m + math.cos(a) * ln, m + math.sin(a) * ln * 0.9)], 1), WHITE if j % 2 else YELLOW)
    for _ in range(26):  # embers rushing in to the core
        a, r0, birth = rng.uniform(0, math.tau), rng.uniform(30, 52), rng.uniform(-2, 1.0)
        s = (k - birth) / 2.6
        if 0 <= s < 1:
            q = r0 * (1 - s * s)
            sdot(ov, round(m + math.cos(a) * q), round(m + math.sin(a) * q * 0.9), (RED, ORANGE, YELLOW, WHITE)[int(s * 4)])
            q2 = r0 * (1 - max(0.0, s - 0.2) ** 2)
            sdot(ov, round(m + math.cos(a) * q2), round(m + math.sin(a) * q2 * 0.9), ORANGE)
    # sparks: streaming off the spokes' tips and thrown out of the ring in every direction
    spark_cloud(ov, 5, 110, k, lambda rr: (m + math.cos(a_ := rr.uniform(0, math.tau)) * 22, m + math.sin(a_) * 20),
                (2.2, 6.0), (5, 10), 9, g=0.06, trail=3, squash=0.9)
    for j in range(16):  # a fast streak spark down each fireball's path
        a = math.tau * (j + 0.5) / 16
        ember_spark(ov, m + math.cos(a) * 12, m + math.sin(a) * 11, math.cos(a) * 5, math.sin(a) * 4.5, k - 1, 9, 0.0, 4)
    return finish(c, ov)


FX.update({"supernova_burst": lambda: strip([supernova_frame(k) for k in range(SUPERNOVA_FRAMES)])})


FORMS = {"wukong_ape": wukong_ape, "flint_inferno": flint_inferno}
AURAS = {"wukong": wukong_clouds, "wukong_ape": ape_storm, "flint": flint_embers,
         "flint_inferno": flint_inferno_aura}
## Optional per-frame art above the 64 px box (tall hair, flames), drawn on the CELL behind the frame:
## fn(tick, head_dy) -> Canvas(CELL). Not on death frames.
CROWNS = {"flicker": flicker_topknot, "flint": flint_crown, "flint_inferno": lambda t, dy: flint_crown(t, dy, 1.0)}  # optional per-frame effects drawn behind
KO_CROWNS = {"flicker"}  # crowns that stay on a knocked-out body (Flint's flame goes out)
## Optional melee attack strip after the death frames (CharacterData "attack"): (pose, body dy) per frame,
## build(None, i, pose). Fists go up over his head, then smash down in front on frame 3 (the hit lands then:
## ape_fists windup), the body squashed, and settle back into the knuckle-walk.
## Per frame: (pose, dy = upper body over the legs, + crouches, hop = whole body off the ground, - is up).
## The Great Ape crouches, leaps up raising his fists, and lands squashed as they slam down.
ATTACKS = {"wukong_ape": [(("walk", "raise", 0.6), 3, 0), (("raise", "raise", 0), -2, -9), (("raise", "smash", 0.5), -1, -12),
                          (("smash", "smash", 0), 3, 0), (("smash", "smash", 0), 2, 0), (("smash", "walk", 0.4), 1, 0),
                          (("smash", "walk", 0.8), 0, 0)]}


# --- Bolt: lightning runner (character, Arc Zapper, Overdrive FX) -------------------------------------------------
# Everything electric is built from jagged arcs: `zig` makes the points, `arc` draws one (cyan glow, white joints).
def zap_zig(rng, a, b, n=4, jit=2.5):
    """A jagged lightning path from a to b in n segments, kinks alternating sides."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / ln, dx / ln
    pts = [(round(a[0]), round(a[1]))]
    for k in range(1, n):
        j = jit * (1 if k % 2 else -1) * rng.uniform(0.6, 1.2)
        pts.append((round(a[0] + dx * k / n + nx * j), round(a[1] + dy * k / n + ny * j)))
    pts.append((round(b[0]), round(b[1])))
    return pts


def zap_arc(c: Canvas, pts, glow=TEAL_L, core=WHITE, tip=None, w=1):
    c.flat(L(pts, w), glow)
    for x, y in pts[1:-1]:
        sdot(c, x, y, core)
    if tip is not None:
        sdot(c, pts[-1][0], pts[-1][1], tip)


def arcs_from(c: Canvas, rng, roots, centre, n, reach, forks=0.6, glow=TEAL_L, tip=WHITE, jit=2.2):
    """n arcs leaping off random `roots` away from `centre`; long ones may fork."""
    size = c.size
    clamp = lambda v: min(max(v, 4), size - 5)
    for _ in range(n):
        x, y = rng.choice(roots)
        a = math.atan2(y - centre[1], x - centre[0]) + rng.uniform(-0.7, 0.7)
        ln = rng.uniform(*reach)
        end = (clamp(x + math.cos(a) * ln), clamp(y + math.sin(a) * ln))
        pts = zap_zig(rng, (x, y), end, 3 if ln < 10 else 4, jit)
        zap_arc(c, pts, glow, tip=tip)
        if ln > 12 and rng.random() < forks:
            fx, fy = pts[len(pts) // 2]
            a2 = a + rng.choice((-1, 1)) * 0.9
            e2 = (clamp(fx + math.cos(a2) * ln * 0.5), clamp(fy + math.sin(a2) * ln * 0.5))
            zap_arc(c, zap_zig(rng, (fx, fy), e2, 2, 1.6), glow, tip=YELLOW)


BOLT_ROOTS = ((19, 37), (46, 38), (17, 24), (47, 20), (23, 52), (41, 52), (26, 46), (40, 46), (32, 14), (30, 34))
BOLT_SKIN_ROOTS = ((22, 40), (42, 40), (18, 41), (45, 41), (30, 36), (37, 43))


def bolt_aura(i: int) -> Canvas:
    """Static crackling off his body (behind him; in AURAS): three short arcs and a few loose sparks that jump to new
    spots every tick, and every 4th tick one long flash with forks. Seeded by the tick, so each frame is fixed."""
    c = Canvas()
    rng = random.Random(7000 + i * 31)
    arcs_from(c, rng, BOLT_ROOTS, (32, 34), 5, (9, 16))
    if i % 4 == 3:  # the occasional bigger flash
        arcs_from(c, rng, BOLT_ROOTS, (32, 34), 1, (19, 25), forks=1.0, glow=YELLOW, tip=WHITE, jit=3.0)
    for _ in range(5):
        a, r = rng.uniform(0, math.tau), rng.uniform(21, 28)
        sdot(c, round(32 + math.cos(a) * r), round(34 + math.sin(a) * r * 0.9), rng.choice((WHITE, YELLOW, TEAL_L)))
    return c


def bolt(step=None, t=0):
    """Bolt: a lightning-quick runner. Swept-back yellow hair with a zig-zag lightning crest (drawn above the art box:
    CROWNS bolt_crown), goggles pushed up on the brow, a blue runner's suit with a yellow lightning flash on the chest
    and a belt, white gloves and boots with yellow cuffs, a cyan scarf streaming behind him. Small arcs crackle over
    the suit and flicker from tick to tick (bolt_aura throws bigger ones off him)."""
    low = Canvas()
    for x, dy in legs(low, NAVY, WHITE, step):
        low.flat(R((x, 52 + dy, x + 5, 52 + dy)), YELLOW)  # boot cuff
        low.dot(x + 3, 46 + dy, YELLOW)  # a lightning flash zig-zagging down the thigh
        low.dot(x + 2, 47 + dy, YELLOW)
        low.dot(x + 3, 48 + dy, YELLOW)
        low.dot(x + 2, 49 + dy, WHITE)
        low.flat(R((x + 5, 55 + dy, x + 6, 55 + dy)), YELLOW)  # toe cap
    up = Canvas()
    wave = lambda lag, amp: round(HAIR_FLOW[(t - lag) % 4] * amp)
    # scarf, streaming behind him in the wind (wave)
    up.part(P([(22, 35), (16 - wave(0, 1), 36), (11 - wave(1, 1.5), 39 + SWAY[t % 4]), (8 - wave(2, 2), 45),
               (13 - wave(2, 1.5), 44), (17 - wave(1, 1), 42), (22, 40)]), TEAL_L)
    up.flat(L([(18, 38), (12 - wave(1, 1.5), 42 + SWAY[t % 4])], 1), BLUE)  # its stripe
    arm(up, ARM_X[0], BLUE, WHITE)
    up.flat(R((ARM_X[0], 41, ARM_X[0] + 5, 41)), YELLOW)  # wrist band
    up.part(RR(BODY, 3), BLUE)  # suit
    up.flat(P([(36, 34), (29, 40), (33, 40), (30, 45), (39, 38), (35, 38), (38, 34)]), YELLOW)  # chest flash
    up.flat(L([(36, 35), (31, 39)], 1), WHITE)  # its lit edge
    up.flat(R((20, 46, 44, 47)), NAVY)  # belt
    up.flat(R((31, 46, 34, 47)), YELLOW)  # buckle
    up.flat(R((21, 33, 43, 33)), WHITE)  # high collar
    up.dot(24, 36, STEEL)  # suit sheen
    up.dot(24, 37, STEEL)
    arm(up, ARM_X[1], BLUE, WHITE)
    up.flat(R((ARM_X[1], 41, ARM_X[1] + 5, 41)), YELLOW)
    # hair: the head's back is a spiky yellow mass swept back, ending in jagged points
    up.part(lambda d, f: (d.ellipse((16, 6, 48, 37), f), d.polygon(
        [(16, 20), (11, 28), (16, 27), (13, 35), (19, 31), (20, 38), (24, 31), (24, 20)], f)), YELLOW)
    up.flat(L([(22, 9), (31, 7)], 1), WHITE)  # crown sheen
    up.flat(L([(17, 22), (16, 27)], 1), WHITE)
    up.part(RR(FACE, FACE_R), SKIN)  # face
    # goggles pushed up on the brow: a strap round the head and two lenses
    up.flat(R((18, 12, 48, 13)), NAVY)
    for x in (26, 37):
        up.part(RR((x, 8, x + 6, 14), 2), STEEL_D)
        up.flat(R((x + 1, 10, x + 4, 12)), TEAL_L)
        up.dot(x + 1, 10, WHITE)
    # zig-zag fringe stopping above the eyes
    up.part(P([(19, 15), (49, 15), (49, 19), (46, 17), (43, 20), (40, 17), (37, 20), (34, 17), (31, 20), (28, 17),
               (25, 19), (22, 17), (19, 19)]), YELLOW, shade=False)
    up.part(P([(FACE[2] - 1, 17), (51, 18), (52 + wave(2, 0.5), 28), (49, 25), (49, 27), (FACE[2], 24)]), YELLOW,
            shade=False)  # a side lock
    big_eyes(up, EYES_Y, EYES_X, TEAL_L, h=6)
    face(up, BLUSH, MOUTH)
    up.dot(MOUTH[0] + 2, MOUTH[1] - 1, MAROON)  # cocky grin
    if not KO:
        rng = random.Random(4100 + t * 17)  # tiny arcs crackling over the suit and the hair
        arcs_from(up, rng, BOLT_SKIN_ROOTS, (32, 40), 3, (4, 8), forks=0, jit=1.5)
        if t % 4 == 1:
            sdot(up, 40 + rng.randint(-5, 6), 8 + rng.randint(0, 2), WHITE)
    return low, up


def bolt_crown(t: int, dy: int) -> Canvas:
    """The lightning crest: three zig-zag spikes rising above the head (swept back, the tips sway with the wind), a
    spark skipping along them. A CELL canvas drawn behind the body; `dy` = the head's bob."""
    c = Canvas(CELL)
    wave = lambda lag, amp: round(HAIR_FLOW[(t - lag) % 4] * amp)
    at = lambda pts: [(PAD + x, PAD + UPPER_DY + dy + y) for x, y in pts]
    c.part(lambda d, f: (
        d.polygon(at([(29, 10), (28, 1), (32, 2), (30 - wave(1, 1), -13), (40, 0), (36, 0), (38, 10)]), f),  # tall centre
        d.polygon(at([(21, 11), (19, 4), (23, 5), (15 - wave(2, 1.5), -5), (28, 9)]), f),  # left, swept back
        d.polygon(at([(39, 10), (41, 3), (45, 5), (49 - wave(1, 1), -3), (47, 9)]), f)), YELLOW)  # right
    c.flat(L(at([(30, 9), (30, 3), (31, -4)]), 1), WHITE)  # lit edge of the tall spike
    spark = at([(31, -9), (36, -2), (21, -2), (16, 3)])[t % 4]
    sdot(c, spark[0], spark[1], WHITE)
    return c


# --- Arc Zapper (weapon) and its bolt ---
def arc_zapper(c: Canvas, t: int = 0) -> None:
    """A short electrode pistol: blue casing ringed with yellow coils, two steel prongs and a spark flickering between
    their tips (t = frame of the held loop)."""
    grip(c, NAVY)
    c.part(RR((3, 7, 21, 14), 2), BLUE)
    for x in (8, 12, 16):  # coil rings
        c.flat(R((x, 7, x, 13)), YELLOW)
    c.part(R((21, 9, 27, 12)), STEEL, shade=False)
    c.part(P([(27, 6), (40, 5), (40, 7), (29, 9)]), STEEL_D, shade=False)  # upper prong
    c.part(P([(27, 12), (40, 13), (40, 15), (29, 15)]), STEEL_D, shade=False)  # lower prong
    rng = random.Random(30 + t)
    zap_arc(c, zap_zig(rng, (40, 7), (40, 13), 3, 2.5 + t % 2), TEAL_L)  # the spark between the tips
    sdot(c, 41, 10, WHITE)
    c.dot(5, 8, TEAL_L)


def zap_shot(c: Canvas, f: int) -> None:  # Arc Zapper: a short zig-zag spark; the kinks flip each frame
    m = PROJ // 2
    s = -1 if f else 1
    pts = [(4, m), (6, m - 3 * s), (9, m + 3 * s), (11, m - 3 * s), (13, m + 2 * s), (15, m)]
    c.flat(L(pts, 2), TEAL_L)
    c.flat(L(pts, 1), WHITE)
    c.dot(15, m, YELLOW)
    c.dot(4, m, BLUE)


# --- Overdrive FX (SpecialFx draws them from synced state) ---
OVERDRIVE_FRAMES = 8
BOLT_CRACK_FRAMES = 14
BOLT_FIZZLE_FRAMES = 12
BOLT_SPARK_FRAMES = 6
BOLT_GHOST_FRAMES = 4


def overdrive_frame(k: int) -> Image.Image:
    """Overdrive loop (CELL px, centred on him, drawn over him): big arcs leaping off the whole body in every
    direction, forking, with loose sparks; every frame is a different crackle."""
    c = Canvas(CELL)
    rng = random.Random(8100 + k * 53)
    roots = [(48 + math.cos(a) * 13, 52 + math.sin(a) * 18) for a in (rng.uniform(0, math.tau) for _ in range(14))]
    arcs_from(c, rng, roots, (48, 52), 6, (14, 27), forks=0.8, jit=3.0)
    arcs_from(c, rng, roots, (48, 52), 2, (8, 12), forks=0, glow=YELLOW, jit=2.0)
    for _ in range(10):
        a, r = rng.uniform(0, math.tau), rng.uniform(24, 41)
        sdot(c, round(48 + math.cos(a) * r), round(52 + math.sin(a) * r * 0.9), rng.choice((WHITE, YELLOW, TEAL_L)))
    return outline(c.img)


@functools.lru_cache(maxsize=None)
def bolt_walk_frames() -> tuple:
    return tuple(frames(bolt, None, bolt_crown)[6:])


def bolt_ghost_frame(k: int) -> Image.Image:
    """An afterimage (CELL px): his walking silhouette dithered blue and cyan (hard pixels, the outline kept), with
    speed streaks dragging out behind (to the left; SpecialFx mirrors it when he runs left)."""
    src = bolt_walk_frames()[(k * 2) % 8].copy()
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) != OUTLINE:
                px[x, y] = (TEAL_L if (x + y + k) % 2 else BLUE) + (255,)
    rng = random.Random(900 + k)
    for y in rng.sample(range(34, 80, 2), 9):
        row = [x for x in range(src.width) if px[x, y][3]]
        if not row:
            continue
        x0, ln = min(row) - 2, rng.randint(7, 24)
        for x in range(max(x0 - ln, 3), x0):
            px[x, y] = (WHITE if x > x0 - 3 else TEAL_L if (x + k) % 3 else BLUE) + (255,)
    return src


def bolt_crack_frame(k: int) -> Image.Image:
    """Overdrive start (128 px, centred on him; his feet sit 25 art px below the centre): a bolt of lightning stabs down
    on him from above, flash and floor ring, forks leaping off, then the bolt is gone and sparks scatter."""
    n, m = 128, 64
    foot = (m, m + 25)
    c = Canvas(n)
    rng = random.Random(77)
    reach = (0.6, 1, 1, 1, 1, 1, 0.9)[k] if k < 7 else 0
    width = (1, 2, 4, 4, 3, 2, 1)[k] if k < 7 else 0
    if reach:
        end = (foot[0], 4 + (foot[1] - 4) * reach)
        pts = zap_zig(rng, (m + 4, 4), end, 8, 5)
        c.flat(L(pts, width + 2), TEAL_L)
        c.flat(L(pts, width), WHITE)
        for x, y in pts[1:-1:2]:
            sdot(c, x, y, YELLOW)
        for j in (2, 5):  # forks
            fx, fy = pts[j]
            side = 1 if j == 2 else -1
            e = (fx + side * rng.randint(12, 20), fy + rng.randint(6, 14))
            zap_arc(c, zap_zig(rng, (fx, fy), e, 3, 3), TEAL_L if k > 1 else WHITE, tip=YELLOW)
    if 1 <= k <= 9:  # flash at the feet, then a squashed ring racing out over the floor
        r = (0, 6, 11, 14, 11, 8, 5, 3, 2, 1)[k]
        if r:
            c.flat(E((foot[0] - r, foot[1] - r * 0.5, foot[0] + r, foot[1] + r * 0.5)), WHITE if k < 4 else TEAL_L)
        rr = 6 + k * 5
        c.flat(lambda d, f: d.ellipse((foot[0] - rr, foot[1] - rr * 0.35, foot[0] + rr, foot[1] + rr * 0.35),
                                      outline=f, width=2 if k < 6 else 1), TEAL_L if k < 6 else BLUE)
    for j in range(10 if k >= 1 else 0):  # sparks thrown out, fading with k
        a = rng.uniform(-3.1, 0.0)
        r = (k - 1) * rng.uniform(2.5, 6)
        life = max(0.0, 1 - k / BOLT_CRACK_FRAMES)
        if r > 0 and rng.random() < life + 0.2:
            sdot(c, round(foot[0] + math.cos(a) * r * 1.3), round(foot[1] + math.sin(a) * r * 0.9),
                 (WHITE, YELLOW, TEAL_L)[j % 3])
    return outline(c.img)


def bolt_fizzle_frame(k: int) -> Image.Image:
    """Overdrive end (CELL px, over him): the crackle shrinks and gutters out, little puffs of smoke rise off his
    shoulders and the last sparks drop."""
    n = BOLT_FIZZLE_FRAMES
    c = Canvas(CELL)
    rng = random.Random(55 + k)
    life = 1 - k / n
    roots = [(48 + math.cos(a) * 13, 52 + math.sin(a) * 18) for a in (rng.uniform(0, math.tau) for _ in range(10))]
    if life > 0.25:
        arcs_from(c, rng, roots, (48, 52), round(5 * life) + 1, (6 * life + 4, 16 * life + 6), forks=0.3, jit=2.0)
    for j in range(3):  # smoke puffs
        if k >= 2 + j:
            age = k - 2 - j
            px_, py_ = 36 + j * 12, 40 - age * 2
            r = 2 + min(age, 3)
            c.flat(E((px_ - r, py_ - r, px_ + r, py_ + r)), STEEL if age < 4 else STEEL_D)
    for _ in range(6):  # last sparks, dropping
        x, y = round(48 + rng.uniform(-24, 24)), round(40 + rng.uniform(-10, 14) + k * 2.2)
        if rng.random() < life + 0.15:
            sdot(c, x, y, rng.choice((YELLOW, TEAL_L, WHITE)) if k < n - 3 else YELLOW)
    return outline(c.img)


def bolt_spark_frame(k: int) -> Image.Image:
    """A single arc popping off him while he runs (48 px, one-shot): it lashes out, flickers and winks out."""
    c = Canvas(48)
    rng = random.Random(21 + k // 2)  # the shape holds for two frames
    ln = (7, 13, 16, 15, 9, 4)[k]
    pts = zap_zig(rng, (24, 24), (24 + ln, 24 - ln * 0.5), 3, 3)
    zap_arc(c, pts, TEAL_L if k < 4 else BLUE, tip=WHITE if k < 4 else None)
    if 1 <= k <= 3:
        zap_arc(c, zap_zig(rng, pts[1], (pts[1][0] - 6, pts[1][1] + 8), 2, 2), TEAL_L, tip=YELLOW)
    return outline(c.img)


CHARACTERS["bolt"] = bolt
CROWNS["bolt"] = bolt_crown
AURAS["bolt"] = bolt_aura
WEAPONS["bolt_zapper"] = arc_zapper
WEAPON_ANIMS["bolt_zapper"] = arc_zapper
PROJECTILES["bolt_zapper"] = zap_shot
ICONS["overdrive"] = lambda c: (c.flat(L([(0, 3), (4, 3)], 1), TEAL_L), c.flat(L([(0, 7), (3, 7)], 1), TEAL_L),
                                c.flat(L([(1, 10), (4, 10)], 1), TEAL_L),
                                c.flat(P([(9, 0), (4, 7), (7, 7), (5, 12), (12, 4), (8, 4), (11, 0)]), YELLOW),
                                c.flat(L([(9, 1), (6, 5)], 1), WHITE))
FX.update({
    "bolt_overdrive": lambda: strip([overdrive_frame(k) for k in range(OVERDRIVE_FRAMES)]),
    "bolt_ghost": lambda: strip([bolt_ghost_frame(k) for k in range(BOLT_GHOST_FRAMES)]),
    "bolt_crack": lambda: strip([bolt_crack_frame(k) for k in range(BOLT_CRACK_FRAMES)]),
    "bolt_fizzle": lambda: strip([bolt_fizzle_frame(k) for k in range(BOLT_FIZZLE_FRAMES)]),
    "bolt_spark": lambda: strip([bolt_spark_frame(k) for k in range(BOLT_SPARK_FRAMES)]),
})


# --- frame processing -------------------------------------------------------

def outline(img: Image.Image) -> Image.Image:
    """Adds a 1 px OUTLINE border around every opaque region (4-neighbour)."""
    src = img.load()
    out = img.copy()
    dst = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                    dst[x, y] = OUTLINE + (255,)
                    break
    return out


def recolor(img: Image.Image, fn) -> Image.Image:
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) != OUTLINE:
                px[x, y] = fn((r, g, b)) + (255,)
    return out


def frames(build, aura=None, crown=None) -> list[Image.Image]:
    """Idle, hit and walk frames: SIZE px, or CELL px with `crown` (CROWNS) composited behind before the
    single outline pass, so the crown and body share one silhouette with no line between them."""
    def frame(step, dy, i):
        low, up = build(step, i)
        f = aura(i).img if aura else Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        f.alpha_composite(low.img)
        f.alpha_composite(up.img, (0, UPPER_DY + dy))
        if crown:
            out = crown(i, dy).img
            out.alpha_composite(f, (PAD, PAD))
            f = out
        return outline(f)

    idle = [frame(None, dy, i) for i, dy in enumerate(IDLE_BOB)]
    hit = [recolor(idle[0], lambda _c: WHITE), recolor(idle[0], LIGHTER.__getitem__)]
    walk = [frame(i, dy, i) for i, dy in enumerate(WALK_BOB)]
    return idle + hit + walk


def attack_frames(build, aura, poses) -> list[Image.Image]:
    """CELL px attack frames (ATTACKS), composed like idle frames; a hop lifts the whole body (aura stays put)."""
    out = []
    for i, (pose, dy, hop) in enumerate(poses):
        low, up = build(None, i, pose)
        f = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        if aura:
            f.alpha_composite(aura(i).img, (PAD, PAD))
        f.alpha_composite(low.img, (PAD, PAD + hop))
        f.alpha_composite(up.img, (PAD, PAD + UPPER_DY + dy + hop))
        out.append(outline(f))
    return out


## Sheet cells are bigger than the art so the toppling death frames fit; frames are centred in them.
CELL = 96
PAD = (CELL - SIZE) // 2


def cell(img: Image.Image) -> Image.Image:
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    out.alpha_composite(img, (PAD, PAD))
    return out


def death_frames(build, crown=None) -> list[Image.Image]:
    """8 CELL-sized frames, knocked out (X eyes, no aura): white flash, pops up, topples backwards (it
    faces right, so the head lands on the left), bounces, lies dizzy under circling stars, then
    dissolves (ordered dither) before the respawn."""
    global KO
    KO = True
    try:
        low, up = build(None, 0)
    finally:
        KO = False
    ko = crown(0, 0).img if crown else Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    ko.alpha_composite(low.img, (PAD, PAD))
    ko.alpha_composite(up.img, (PAD, PAD + UPPER_DY))
    ground = ko.getbbox()[3]

    def pose(angle, lift=0, fade=0.0, stars=-1):
        r = ko.rotate(angle, Image.NEAREST, center=(CELL // 2, ground))
        left, top, right, low_ = r.getbbox()
        dx = (CELL - left - right) // 2 if angle else 0  # lying down: centre it on the spot
        dy = ground - low_ - lift
        f = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        f.alpha_composite(r.crop((-dx, -dy, CELL - dx, CELL - dy)))
        c = Canvas(CELL)
        c.img, c.px = f, f.load()
        if stars >= 0:  # three stars circling above the head end
            hx, hy = left + dx + 8, top + dy - 6
            for k in range(3):
                a = math.tau * k / 3 + stars * 0.9
                x, y = round(hx + math.cos(a) * 7), round(hy + math.sin(a) * 2)
                c.flat(R((x - 1, y, x + 1, y)), YELLOW)
                c.dot(x, y - 1, YELLOW)
                c.dot(x, y + 1, YELLOW)
        for y in range(CELL):
            for x in range(CELL):
                if BAYER[y % 4][x % 4] / 16 < fade:
                    c.px[x, y] = (0, 0, 0, 0)
        return outline(f)

    return [recolor(pose(0), lambda _c: WHITE), pose(0, 3), pose(35, 2), pose(70, 1),
            pose(90, 3), pose(90, stars=0), pose(90, 0, 0.45, stars=1), pose(90, 0, 0.8, stars=2)]


# --- Blaze Run (Flint): burning ground stamped along the trail, ignition, smoulder, flame streak -----------------

BLAZE_CELL = 48  # art px, square: one stamp of burning ground; its floor spot is (cell centre, BLAZE_FLOOR_Y)
BLAZE_FLOOR_Y = 36  # SpecialFx.BLAZE_FLOOR_Y
BLAZE_SQUASH = 0.32  # the floor seen in 3/4 view
BLAZE_IGNITE_FRAMES = 20
BLAZE_STREAK_CELL = 96


def blaze_scorch(c: Canvas, m: int, rx: float, seed: int, glow=None):
    """A small flat irregular scorch mark round (m, BLAZE_FLOOR_Y): wider than tall, ragged edge, never a disc.
    `glow` colours a couple of short cracks in it (None: cold)."""
    if rx < 3:
        return
    rng = random.Random(seed)
    y = BLAZE_FLOOR_Y
    ry = max(1.5, rx * 0.26)
    pts = []
    n = 14
    for i in range(n):
        a = 2 * math.pi * i / n
        j = rng.uniform(0.6, 1.2) if i % 2 else rng.uniform(0.85, 1.1)
        pts.append((m + math.cos(a) * rx * j, y + math.sin(a) * ry * j))
    c.flat(P(pts), SHADOW)
    c.flat(P([(m + (x - m) * 0.6, y + (yy - y) * 0.6) for x, yy in pts]), MAROON)
    if glow is not None:
        for _ in range(2):
            x0 = m + rng.uniform(-rx * 0.6, rx * 0.3)
            y0 = y + rng.uniform(-ry * 0.4, ry * 0.4)
            c.flat(L([(x0, y0), (x0 + rng.uniform(2, 4), y0 + rng.choice((-1, 0, 1))),
                      (x0 + rng.uniform(5, 7), y0 + rng.choice((-1, 0, 1)))], 1), glow)


BLAZE_LOOP = 16  # frames of a flame stamp's loop / of the streak (SpecialFx.BLAZE_FLAME_LOOP)
BLAZE_DIES = 10  # frames of the die-out (SpecialFx.BLAZE_FLAME_DIES)


def blaze_flames(c: Canvas, m: int, k: int, scale: float, xs=(-11, 0, 11), heights=(19, 27, 17), wide=4.5):
    """Tongues of fire rising from the floor (period BLAZE_LOOP in k): each breathes taller and shorter on its own beat
    (two harmonics, so no two match), sways side to side, a wave rolling up it; small licks leaning on the tall ones, a
    white-hot sliver in the heart and a glow on the floor under."""
    ph = math.tau * k / BLAZE_LOOP
    fy = BLAZE_FLOOR_Y
    gw = (max(abs(x) for x in xs) + 5) * min(1.0, 0.4 + scale)
    if scale > 0.3:  # the heat glow where the flames sit
        c.flat(E((m - gw, fy - 1, m + gw, fy + 2)), RED)
        c.flat(E((m - gw * 0.6, fy - 1, m + gw * 0.6, fy + 1)), ORANGE if (k // 2) % 2 else YELLOW)
    for i in sorted(range(len(xs)), key=lambda i: -heights[i]):  # tallest behind
        h = heights[i] * scale * (1 + 0.15 * math.sin(ph + i * 2.1) + 0.08 * math.sin(2 * ph + i * 1.3)
                                  + 0.04 * math.sin(3 * ph + i))
        if h < 3:
            continue
        x = m + xs[i]
        sw = math.sin(ph + i * 1.3) * 2.2 + math.sin(2 * ph + i) * 0.8
        flame_tongue(c, (x, fy), (x + sw * 0.4, fy - h * 0.55), (x + sw, fy - h),
                     ph + i * 2, 1, wide * min(1.0, 0.4 + scale), m)
        if h >= 12 and scale > 0.4:  # a small lick leaning on it, on its own beat
            side = -1 if xs[i] > 0 else 1  # leaning in towards the middle
            h2 = h * (0.38 + 0.1 * math.sin(2 * ph + i * 2.7))
            flame_tongue(c, (x + side * wide * 0.8, fy), (x + side * (wide + 2), fy - h2 * 0.5),
                         (x + side * (wide + 3 + sw * 0.5), fy - h2), 2 * ph + i, 1, wide * 0.55, m)
        if h >= 14:  # white-hot sliver low in the heart, a lit edge up the left side
            c.flat(L([(x - 0.5, fy - 1), (x + sw * 0.15 - 0.5, fy - h * 0.34)], 1), WHITE)
            c.flat(L([(x - wide * 0.55, fy - 2), (x - wide * 0.4 + sw * 0.3, fy - h * 0.4)], 1), YELLOW)


def blaze_embers(c: Canvas, ov: Canvas, m: int, k: int, n: int = 4, rise: int = 6, seed: int = 3):
    """Fire sparks (on `ov`, bright, with trails) and loose flame licks (on `c`) lifting off the fire (period BLAZE_LOOP),
    cooling as they rise, with a wisp of smoke above."""
    rng = random.Random(seed)
    spark_cloud(ov, seed * 7, n * 2 + 2, k, lambda r: (m + r.uniform(-15, 15), BLAZE_FLOOR_Y - 7 - r.uniform(0, 8)),
                (0.0, 0.0), (7, 12), BLAZE_LOOP, loop=BLAZE_LOOP, up=rise * 0.27, g=0.01, trail=3)
    for i in range(max(1, n // 2) + 1):  # tiny detached licks
        ph = (k + i * 5) % BLAZE_LOOP
        if ph >= 8:
            continue
        x = m + rng.randint(-13, 13) + round(math.sin(math.tau * (k + i) / BLAZE_LOOP) * 1.5)
        y = BLAZE_FLOOR_Y - 9 - ph * rise * 0.25 - rng.randint(0, 6)
        c.flat(P([(x - 1, y + 1), (x, y - 2 + (ph > 4)), (x + 1, y + 1)]), (YELLOW, YELLOW, ORANGE, ORANGE, RED, RED, RED, MAROON)[ph])
    for i in range(max(1, n // 2)):  # smoke wisps high above, rising, thin
        ph = (k + i * 8) % BLAZE_LOOP
        x = m + rng.randint(-8, 8) + round(math.sin(math.tau * (k + i * 6) / BLAZE_LOOP) * 2)
        y = BLAZE_FLOOR_Y - 22 - ph * 1.1
        if y > 2 and ph < 14:
            c.dot(x, y, STEEL_D if ph < 8 else SHADOW)
            if ph < 6:
                c.dot(x + 1, y, SHADOW)


# Flame stamp variants (tongue x offsets, heights, width): different cluster shapes and sizes so the trail never
# repeats; SpecialFx picks one per flame and offsets its phase.
BLAZE_FLAME_VARIANTS = (
    ((-10, 0, 10), (17, 26, 15), 4.5),
    ((-5, 6), (21, 14), 4.8),
    ((0, 9), (27, 10), 5.0),
    ((-8, 1, 9), (11, 18, 12), 3.8),
)
BLAZE_FLAME_DIE = (0.92, 0.82, 0.72, 0.62, 0.52, 0.42, 0.32, 0.22, 0.14, 0.07)  # flame scale per die-out frame
BLAZE_COOL = (ORANGE, ORANGE, ORANGE, RED, RED, RED, MAROON, MAROON, MAROON, MAROON)  # crack colour per die-out frame


def blaze_flame_frame(v: int, k: int, scale: float = 1.0, embers: bool = True) -> Image.Image:
    """One flame stamp (variant `v`): a few flowing tongues on the floor spot, breathing and swaying (period BLAZE_LOOP in
    k), sparks and licks lifting off; dying, it shrinks and cools (cracks in the scorch, smoke curling off)."""
    c = Canvas(BLAZE_CELL)
    ov = Canvas(BLAZE_CELL)
    m = BLAZE_CELL // 2
    xs, heights, wide = BLAZE_FLAME_VARIANTS[v]
    blaze_scorch(c, m, (max(abs(x) for x in xs) + 8) * min(1.0, scale + 0.15), 90 + v,
                 (ORANGE, YELLOW, YELLOW, ORANGE)[(k // 2) % 4] if embers else BLAZE_COOL[k % BLAZE_DIES])
    blaze_flames(c, m, k, scale, xs, heights, wide)
    if embers:
        blaze_embers(c, ov, m, k, 3, 6, 3 + v)
    else:  # a thread of smoke off the dying fire, climbing frame by frame, a last few sparks cooling
        for i in range(2):
            y = BLAZE_FLOOR_Y - 8 * scale - k * 1.8 - i * 5
            x = m + (-3 if i else 4) + SWAY[(k // 2 + i) % 4]
            if y > 2:
                c.dot(x, y, STEEL_D if k < 6 else SHADOW)
                c.dot(x, y + 1, SHADOW)
        spark_cloud(ov, 40 + v, 4, k, lambda r: (m + r.uniform(-8, 8), BLAZE_FLOOR_Y - 6), (0, 0), (5, 8), 3,
                    up=1.2 * scale + 0.3, g=0.04, trail=2)
    return finish(c, ov)


def blaze_ignite_frame(k: int) -> Image.Image:
    """Where he took off (BLAZE_IGNITE_FRAMES frames): a white-hot flash ring spreads over the floor with sparks and debris
    flung out, as the fire catches and flares up, then settles to the height of the trail's flames."""
    c = Canvas(BLAZE_CELL)
    ov = Canvas(BLAZE_CELL)
    m = BLAZE_CELL // 2
    u = k * 11 / (BLAZE_IGNITE_FRAMES - 1)  # designed in 12 frames
    if u <= 7.2:  # the flash
        rx = round(4 + 2.4 * u)
        ry = max(1, round(rx * BLAZE_SQUASH))
        col = (WHITE, WHITE, YELLOW, YELLOW, ORANGE, ORANGE, RED, MAROON)[int(u)]
        c.flat(lambda d, f: d.ellipse((m - rx, BLAZE_FLOOR_Y - ry, m + rx, BLAZE_FLOOR_Y + ry), outline=f, width=1), col)
        if u < 3:
            c.flat(E((m - rx + 2, BLAZE_FLOOR_Y - ry + 1, m + rx - 2, BLAZE_FLOOR_Y + ry - 1)), WHITE)
    blaze_scorch(c, m, min(19, 7 + 3 * u), 70 + k // 2, YELLOW if u < 7 else ORANGE)
    blaze_flames(c, m, k, lerp_tab((0.2, 0.45, 0.75, 1.0, 1.18, 1.15, 1.1, 1.05, 1.0, 1.0, 1.0, 1.0), u), wide=5.5)
    spark_cloud(ov, 12, 22, k, (m, BLAZE_FLOOR_Y - 3), (1.0, 2.6), (6, 11), 5, angle=(math.pi, math.tau), g=0.12,
                squash=0.8, up=0.6)
    blaze_embers(c, ov, m, k, 5, 7, 8)
    return finish(c, ov)


def blaze_streak_frame(k: int) -> Image.Image:
    """Flame streaming off a runner dashing to the right (period BLAZE_LOOP): three long tongues sweeping straight back
    from his shoulders and hips (the sprite's centre is the cell's centre), tapering, waves rolling down them, a
    white-hot sliver in the centre one, sparks with trails and licks flung off behind."""
    c = Canvas(BLAZE_STREAK_CELL)
    ov = Canvas(BLAZE_STREAK_CELL)
    m = BLAZE_STREAK_CELL // 2
    ph = math.tau * k / BLAZE_LOOP
    for i, (dy, length, wide) in enumerate(((-12, 24, 5.0), (12, 28, 5.0), (0, 31, 6.5), (-5, 17, 3.2), (7, 20, 3.4))):
        sw = math.sin(ph + i * 2.0) * 2.4 + math.sin(2 * ph + i) * 0.9
        ln = length * (1 + 0.07 * math.sin(2 * ph + i * 1.7) + 0.04 * math.sin(3 * ph + i))
        y = m + dy
        flame_tongue(c, (m - 10, y), (m - 10 - ln * 0.55, y + sw * 0.5), (m - 10 - ln, y + sw), ph + i * 2, 1, wide, m)
        if i == 2:
            c.flat(L([(m - 12, y), (m - 10 - ln * 0.45, y + sw * 0.3)], 1), WHITE)
    for i in range(4):  # loose licks flung off behind
        t = (k + i * 4) % BLAZE_LOOP
        if t < 10:
            x, y = m - 14 - t * 2.4, m - 20 + i * 12 + SWAY[(k // 2 + i) % 4]
            c.flat(P([(x, y - 1), (x - 3, y), (x, y + 1)]), (YELLOW, YELLOW, ORANGE, ORANGE, ORANGE, RED, RED, RED, MAROON, MAROON)[t])
    spark_cloud(ov, 31, 26, k, lambda r: (m - 10 - r.uniform(0, 18), m + r.uniform(-22, 22)), (1.4, 3.2), (7, 12),
                BLAZE_LOOP, angle=(math.pi - 0.35, math.pi + 0.35), loop=BLAZE_LOOP, up=0.2, g=0.04, trail=4)
    return finish(c, ov)


FX.update({
    # per variant: BLAZE_LOOP loop frames; then per variant the die-out (shrinking flames)
    "blaze_run_flames": lambda: strip([blaze_flame_frame(v, k) for v in range(len(BLAZE_FLAME_VARIANTS))
                                       for k in range(BLAZE_LOOP)]
                                      + [blaze_flame_frame(v, i, s, False) for v in range(len(BLAZE_FLAME_VARIANTS))
                                         for i, s in enumerate(BLAZE_FLAME_DIE)]),
    "blaze_run_ignite": lambda: strip([blaze_ignite_frame(k) for k in range(BLAZE_IGNITE_FRAMES)]),
    "blaze_run_streak": lambda: strip([blaze_streak_frame(k) for k in range(BLAZE_LOOP)]),
})


# --- Cherry Sapling (Sakura): a small cherry tree that grows from the floor, sways, flicks petals at enemies, wilts ---
SAPLING_W = 64  # square frames
SAPLING_BASE = 56  # row the trunk stands on (SpecialFx.SAPLING_BASE_Y)
SAPLING_TRUNK = 22
SAPLING_GROW_FRAMES = 16  # SpecialFx's SAPLING_*_FPS keep the old durations
SAPLING_WILT_FRAMES = 16
SAPLING_FIRE_FRAMES = 8
SAPLING_IDLE_FRAMES = 8
# canopy blobs (dx, dy from the canopy centre, radius); the lit lumps on top and the small white blossoms
SAPLING_BLOBS = [(-9, 3, 7), (9, 3, 7), (0, 5, 8), (-5, -5, 7), (6, -5, 7), (0, -9, 6)]
SAPLING_LUMPS = [(0, -9, 5), (-8, -2, 4), (4, -3, 4), (-3, -6, 3)]
SAPLING_BLOSSOMS = [(-9, 1), (-3, -8), (5, -6), (9, 3), (1, 4), (-5, 6), (8, -1)]


def sapling_frame(trunk: float = 1.0, canopy: float = 1.0, sway: float = 0.0, petals=(), burst: float = 0.0,
                  falling: float = 0.0, bud: float = 0.0, squash: float = 0.0, sparks=(), ground: float = 0.0,
                  twinkle_i: int = -1) -> Image.Image:
    """One frame. trunk/canopy 0..1 = how grown (canopy may overshoot); sway = how far the canopy leans in px (the top
    of the trunk follows half as far, so the tree bends); squash > 0 squeezes the canopy down and out (< 0 stretches
    it); petals = progress 0..1 of each petal drifting off the canopy; burst 0..1 = a flick of petals flung out;
    falling 0..1 = petals dropping to the ground (wilt); bud = size of the bud on the tip; sparks = (dx, dy, arm)
    glints round the canopy; ground = how many of the fallen petals still lie around the foot (0..1)."""
    c = Canvas(SAPLING_W)
    m = SAPLING_W // 2
    base = SAPLING_BASE
    h = round(SAPLING_TRUNK * trunk)
    c.flat(E((m - 9 * max(trunk, 0.3), base - 2, m + 9 * max(trunk, 0.3), base + 3)), SHADOW)  # shadow on the ground
    if ground > 0:  # fallen petals round the foot
        for i, dx in enumerate((-13, -8, 9, 13, 4)):
            if i / 5 < ground:
                ward_petal(c, m + dx, base + (i % 2) - 1, 0.3 * i, 4.5, 0.9, PINK_L if i % 2 else WHITE)
    lean = sway * 0.5
    if h >= 1:
        w = 2 if h < 8 else 3
        top_dx = lean * (h / SAPLING_TRUNK) ** 1.5
        c.part(P([(m - w - 1, base + 1), (m - w, base - 1), (m - w + 1 + top_dx, base - h), (m + w - 1 + top_dx, base - h),
                  (m + w, base - 1), (m + w + 1, base + 1)]), BROWN)
        if h >= 10:  # bark flecks
            c.dot(round(m - 1 + top_dx * 0.4), base - round(h * 0.35), MAROON)
            c.dot(round(m + top_dx * 0.7), base - round(h * 0.7), MAROON)
        if h >= 12 and canopy > 0:  # side branches up to the blossom clumps
            c.flat(L([(m + top_dx * 0.5, base - h * 0.5), (m + 7 * canopy + top_dx, base - h * 0.85)], 1), BROWN)
            c.flat(L([(m + top_dx * 0.6, base - h * 0.62), (m - 6 * canopy + top_dx, base - h * 0.9)], 1), BROWN)
    top = base - h
    top_x = m + lean * (h / SAPLING_TRUNK) ** 1.5
    if bud > 0:
        r = 1 + 2 * bud
        c.part(E((top_x - r, top - 2 * r - 1, top_x + r, top - 1)), PINK_L)
    if canopy > 0:
        cx, cy = top_x + lean, top - 6 * canopy
        wide, tall = 1 + 0.12 * squash, 1 - 0.18 * squash
        place = lambda dx, dy, r: (cx + dx * canopy * wide + sway * 0.25 * (-dy / 9 + 0.4) * 0.5,
                                   cy + dy * canopy * tall + (1 - tall) * 6, r * canopy)
        blobs = [place(*b) for b in SAPLING_BLOBS]
        c.part(lambda d, f: [d.ellipse((x - r * wide, y - r * tall, x + r * wide, y + r * tall), f) for x, y, r in blobs if r >= 1],
               PINK)
        lumps = [place(*b) for b in SAPLING_LUMPS]
        c.part(lambda d, f: [d.ellipse((x - r, y - r * 0.9, x + r, y + r * 0.9), f) for x, y, r in lumps if r >= 1],
               PINK_L)
        if canopy >= 0.6:
            for i, (dx, dy) in enumerate(SAPLING_BLOSSOMS):
                x, y, _ = place(dx, dy, 0)
                x, y = round(x), round(y)
                if canopy >= 0.9 and i % 3 == 0:  # an open blossom: white petals round a yellow eye
                    for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        c.dot(x + ox, y + oy, WHITE)
                    c.dot(x, y, YELLOW)
                else:
                    c.dot(x, y, WHITE)
                    if canopy >= 0.9 and i % 2 == 0:
                        c.dot(x, y + 1, WHITE)
        if twinkle_i >= 0:
            x, y, _ = place(*SAPLING_BLOSSOMS[twinkle_i], 0)
            twinkle(c, x, y, 1)
        for dx, dy, arm in sparks:
            twinkle(c, cx + dx * canopy, cy + dy * canopy, arm)
        for i, u in enumerate(petals):  # petals peel off the right side and drift down and away, tumbling
            if 0 < u < 1:
                ward_petal(c, cx + 10 + 8 * u + 2 * math.sin(7 * u + i), cy + 2 + 14 * u * u + 4 * u, 0.6 + 3 * u,
                           5.5 - 1.5 * u, math.cos(u * 7 + i), PINK_L if i % 2 else WHITE)
        if 0 < burst < 0.97:  # the flick: petals fly out and up in a fan, tumbling, then thin out
            for i, a in enumerate((-2.9, -2.5, -2.1, -1.7, -1.3, -0.9, -0.5, -0.1)):
                d = (4 + 11 * burst) * (0.85 + 0.15 * (i % 3))
                ward_petal(c, cx + math.cos(a) * (10 + d), cy + math.sin(a) * (8 + d) + 7 * burst * burst, a + 3 * burst,
                           max(2.5, 6.5 - 4 * burst), math.cos(4 * burst + i), WHITE if i % 2 else PINK_L)
        if falling > 0:
            for i in range(10):
                x0 = cx + (-15 + 3.3 * i) * canopy
                y0 = cy + 2 + (i % 3)
                fall = min(1.0, falling * 1.5 - 0.07 * i)
                if fall <= 0 or fall >= 1:
                    continue
                ward_petal(c, x0 + 4 * math.sin(fall * 7 + i), y0 + (base - y0 - 1) * fall, 1.5 + fall * 5, 5,
                           math.cos(fall * 9 + i), PINK_L if i % 2 else WHITE)
    elif falling > 0:  # the canopy's gone: the last petals are still on their way down
        for i in range(10):
            x0, y0 = m + (-15 + 3.3 * i) * 0.4, top - 4 + (i % 3)
            fall = min(1.0, falling * 1.5 - 0.07 * i)
            if 0 < fall < 1:
                ward_petal(c, x0 + 4 * math.sin(fall * 7 + i), y0 + (base - y0 - 1) * fall, 1.5 + fall * 5, 5,
                           math.cos(fall * 9 + i), PINK_L if i % 2 else WHITE)
    return outline(c.img)


def sapling_grow_frame(k: int) -> Image.Image:
    """Grow-in (16 frames): a sprout pushes up with a bud, the trunk thickens and bends, the canopy swells with a
    bounce, blooms, and a ring of glints and petals puffs off it."""
    trunk = (0.1, 0.2, 0.32, 0.46, 0.6, 0.74, 0.86, 0.95, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)[k]
    canopy = (0, 0, 0, 0, 0, 0.18, 0.38, 0.6, 0.82, 1.0, 1.1, 1.1, 1.03, 0.97, 1.0, 1.0)[k]
    squash = (0, 0, 0, 0, 0, 0, 0, 0, 0, -0.5, -0.9, 0, 0.5, 0.3, 0, 0)[k]
    sway = (0, 0.5, 0, -0.5, 0, 0.5, 0, 0, 0, 0, 1, 1.5, 0.5, -0.5, 0, 0)[k]
    bud = (0, 0.5, 1.0, 1.0, 0.8, 0.4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)[k]
    sparks = ()
    if 9 <= k <= 13:
        arm = (1, 2, 2, 1, 1)[k - 9]
        sparks = tuple((14 * math.cos(a + 0.3 * k), 12 * math.sin(a + 0.3 * k) - 3, arm)
                       for a in (0.4, 2.5, 4.4))
    puff = [(k - 9 - 1.5 * i) / 5 for i in range(5)] if k >= 10 else []
    img = sapling_frame(trunk, canopy, sway, petals=puff, bud=bud, squash=squash, sparks=sparks)
    return img


def sapling_idle_frame(k: int) -> Image.Image:
    """Idle loop (8 frames): the canopy sways, the top of the trunk bending after it, two petals drift off in turn
    and a blossom twinkles; everything is periodic so the loop closes."""
    f = k / SAPLING_IDLE_FRAMES
    return sapling_frame(sway=1.6 * math.sin(math.tau * f), petals=[(f * 1.0) % 1.0 * 1.0, ((f + 0.5) % 1.0)],
                         twinkle_i=(1, 3)[k // 4] if k % 4 in (1, 2) else -1)


def sapling_fire_frame(k: int) -> Image.Image:
    """Firing flourish (8 frames): the canopy winds back and squashes, snaps forward and flicks a fan of petals out,
    then rocks back to rest with fading wobbles."""
    sway = (-1.5, -3.0, 3.0, 2.0, -1.2, 0.8, -0.3, 0.0)[k]
    squash = (0.6, 1.0, -0.8, -0.3, 0.3, 0.1, 0, 0)[k]
    burst = (0.0, 0.0, 0.3, 0.5, 0.68, 0.82, 0.92, 1.0)[k]
    return sapling_frame(sway=sway, squash=squash, burst=burst)


def sapling_wilt_frame(k: int) -> Image.Image:
    """Wilt (16 frames): the tree shivers, petals drop in waves and pile up on the ground, the canopy thins and
    droops, then the trunk shrinks into the ground; the last petals fade."""
    t = k / (SAPLING_WILT_FRAMES - 1)
    canopy = max(0.0, 1.0 - t / 0.55)
    trunk = 1.0 if t < 0.5 else max(0.0, 1.0 - (t - 0.5) / 0.5)
    sway = 1.5 * math.sin(k * 1.7) * (1 - t) + 2 * t * (1 if canopy else 0)
    fallen = min(1.0, t / 0.6) * max(0.0, 1 - (t - 0.8) / 0.2)
    return sapling_frame(trunk, canopy, sway, falling=min(1.0, t / 0.7), squash=0.5 * t, ground=fallen)


FX.update({
    "sapling_grow": lambda: strip([sapling_grow_frame(k) for k in range(SAPLING_GROW_FRAMES)]),
    "sapling_idle": lambda: strip([sapling_idle_frame(k) for k in range(SAPLING_IDLE_FRAMES)]),
    "sapling_fire": lambda: strip([sapling_fire_frame(k) for k in range(SAPLING_FIRE_FRAMES)]),
    "sapling_wilt": lambda: strip([sapling_wilt_frame(k) for k in range(SAPLING_WILT_FRAMES)]),
})


# --- Storm Cloud (Apex): a dark thundercloud with a flickering gold heart, rain, lightning strikes ------------------

STORM_SIZE = 136  # art px square; the spot on the floor is (centre, STORM_FLOOR_Y), SpecialFx.STORM_FLOOR_Y
STORM_FLOOR_Y = 112
STORM_CLOUD_Y = 36  # row of the cloud's middle
STORM_FRAMES = 8  # forming / dispersing strips
STORM_LOOP = 12  # the raining loop
BOLT_W, BOLT_H, BOLT_FRAMES, BOLT_END_Y = 36, 144, 8, 136
STORM_SPARK, STORM_SPARK_FRAMES = 32, 8
STORM_RAIN_COLS = list(range(-44, 46, 9))


def storm_lumps(phase: float, grow: float, lift: float) -> list:
    """(x, y, r) of every lump, back to front. The outer ring turns two lumps' worth (big and small alternate) and the
    inner ring a quarter turn over a loop, so a loop is seamless; all breathing."""
    m = STORM_SIZE // 2
    cy = STORM_CLOUD_Y - lift
    lumps = []
    turn = math.tau / 8 * 2 * phase
    for i in range(8):
        a = math.tau * i / 8 + turn
        lumps.append((m + math.cos(a) * 40 * grow, cy + 4 + math.sin(a) * 12 * grow,
                      (15 + 3 * (i % 2) + 1.5 * math.sin(math.tau * phase + i * 1.7)) * grow))
    for i in range(4):
        a = math.tau * i / 4 - math.tau / 4 * phase + 0.4
        lumps.append((m + math.cos(a) * 17 * grow, cy + 3 + math.sin(a) * 6 * grow,
                      (14 + 1.5 * math.sin(math.tau * phase + i * 2.3)) * grow))
    for i, (dx, dy, r) in enumerate(((-19, -11, 13), (3, -16, 15), (22, -10, 12))):  # the heaped top
        lumps.append((m + dx * grow, cy + dy * grow, (r + 1.5 * math.sin(math.tau * phase + i * 2.9)) * grow))
    return sorted(lumps, key=lambda p: p[1])


def storm_cloud_art(k: int, grow: float = 1.0, rain: float = 1.0, lift: float = 0.0, fade: float = 0.0,
                    flash: int = 0, loop: int = STORM_LOOP, floor_layer: bool = False) -> Image.Image:
    """One frame of the cloud (loop frame `k` of `loop`): `grow` scales it, `rain` is the share of rain columns
    falling, `lift` raises it, `fade` dithers it away. One merged mass (no balloon outlines): lit crescents on the upper
    left of every billow, shadowed lower right, a flat dark underside, small puffs drifting off its edges, and gold light
    that flares inside it in the loop's flash frames (`flash`: 2 = bright, 1 = dim). `floor_layer` draws just the part
    on the floor (shadow, rain splashes), which the game puts under the players; otherwise the cloud and falling rain."""
    n = STORM_SIZE
    m = n // 2
    phase = k / loop
    lumps = storm_lumps(phase, grow, lift)
    cy = STORM_CLOUD_Y - lift
    base = round(cy + 4 + 22 * grow)
    for i in range(4):  # puffs shed from the edges, drifting up and out, each living one loop
        ph = (phase + i / 4) % 1.0
        side = 1 if i % 2 else -1
        lumps.append((m + side * (46 + 9 * ph) * grow, cy - 2 + (6 - 16 * ph) * grow, round((1 + 3.5 * math.sin(math.pi * ph)) * grow)))
    mass = Image.new("1", (n, n), 0)
    d = ImageDraw.Draw(mass)
    for x, y, r in lumps:
        if r >= 1:
            d.ellipse((x - r, y - r, x + r, y + r), fill=1)
    d.rectangle((0, base, n, n), fill=0)
    mp = mass.load()
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()

    def inside(x, y):
        return 0 <= x < n and 0 <= y < n and mp[x, y]

    def disc(x, y, r, dx=0.0, dy=0.0):
        return lambda xx, yy: (xx - x - dx) ** 2 + (yy - y - dy) ** 2 <= r * r

    for x, y, r in sorted(lumps, key=lambda p: p[1]):  # back to front
        if r < 2:
            continue
        me, hi, lo = disc(x, y, r), disc(x, y, r, 2.2, 2.2), disc(x, y, r, -3.2, -3.2)
        top = y < cy - 4
        for yy in range(max(0, int(y - r) - 1), min(n, int(y + r) + 2)):
            for xx in range(max(0, int(x - r) - 1), min(n, int(x + r) + 2)):
                if not (inside(xx, yy) and me(xx, yy)):
                    continue
                col = NAVY
                if not hi(xx, yy):
                    col = STEEL if top and not disc(x, y, r, 1.2, 1.2)(xx, yy) else STEEL_D
                elif not lo(xx, yy) and r >= 6:
                    col = SHADOW if (xx + yy) % 2 == 0 or yy > y else NAVY
                px[xx, yy] = col + (255,)
    for yy in range(n):  # the dark underside: dithered, then solid, with a ragged lower edge
        for xx in range(n):
            if inside(xx, yy):
                if yy >= base - 2 or (yy >= base - 5 and (xx + yy) % 2 == 0 and px[xx, yy][:3] == NAVY):
                    px[xx, yy] = SHADOW + (255,)
                if not inside(xx - 1, yy - 1) and yy < cy + 6 and px[xx, yy][:3] != SHADOW:
                    px[xx, yy] = STEEL + (255,)  # rim light along the top-left silhouette
    if flash and grow > 0.9:  # gold light flaring inside: a glow, a crackling arc, the underside lit up
        rng = random.Random(40 + k)
        gx, gy = m + (-16 if k % 6 < 3 else 18) + rng.randint(-2, 2), cy + 4
        for yy in range(n):
            for xx in range(n):
                if inside(xx, yy):
                    dd = math.hypot((xx - gx) * 0.8, (yy - gy) * 1.3)
                    if dd < (17 if flash > 1 else 10) and (dd < 9 or (xx + yy) % 2 == 0):
                        px[xx, yy] = (STEEL if dd < 6 and flash > 1 else STEEL_D) + (255,)
        c = Canvas(n)
        c.img, c.px = img, px
        pts, x, y = [(gx, gy - 8)], gx, gy - 8
        for _ in range(4):
            x += rng.randint(-4, 4)
            y += 5
            pts.append((x, y))
        if flash > 1:
            c.flat(L(pts, 2), YELLOW)
            c.flat(L(pts, 1), WHITE)
            for xx in range(int(gx) - 12, int(gx) + 13):  # the flat belly glowing
                if inside(xx, base - 1):
                    px[xx, base - 1] = (YELLOW if abs(xx - gx) < 7 else ORANGE) + (255,)
        else:
            c.flat(L(pts[:3], 1), YELLOW)
    cloud = outline(img)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    floor = STORM_FLOOR_Y
    if grow > 0.5:  # a dithered shadow on the floor under the rain, darker at its heart
        sh = Canvas(n)
        for y in range(floor - 8, floor + 9):
            for x in range(m - 46, m + 47):
                e = ((x - m) / 46) ** 2 + ((y - floor) / 8) ** 2
                if e <= 1 and ((x + y) % 2 == 0 or e < 0.35):
                    sh.dot(x, y, SHADOW)
        out.alpha_composite(outline(sh.img))
    rn = Canvas(n)
    fl = Canvas(n)
    cols = STORM_RAIN_COLS[:round(len(STORM_RAIN_COLS) * rain)]
    for j, dx in enumerate(cols):
        for rep, (speed, col, head, length) in enumerate(((5, STEEL, WHITE, 6), (5, STEEL_D, STEEL, 4))):
            y = 52 + (j * 17 + rep * 31 + k * speed * 12 // loop) % 60
            x = m + dx + (4 if rep else 0)
            if y + length < floor - 1:
                rn.flat(L([(x, y), (x - 2 * length // 6 - 1, y + length)], 1), col)
                rn.dot(x - 2 * length // 6 - 1, y + length, head)
            elif y < floor + 2 and rep == 0:  # lands: a little splash on the floor
                for sx, sy in ((-2, -1), (2, -1), (-3, 0), (3, 0)):
                    fl.dot(x + sx, floor - 2 + sy + (y > floor - 2), WHITE if abs(sx) < 3 else STEEL)
    if floor_layer:
        out.alpha_composite(fl.img)
    else:
        out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        out.alpha_composite(rn.img)
        out.alpha_composite(cloud)
    px = out.load()
    for y in range(n):
        for x in range(n):
            if BAYER[y % 4][x % 4] / 16 < fade:
                px[x, y] = (0, 0, 0, 0)
    return out


STORM_FLASH = {3: 2, 4: 1, 9: 2, 10: 1}  # loop frame -> flash strength


def storm_loop_frame(k: int, floor_layer: bool = False) -> Image.Image:
    return storm_cloud_art(k, flash=STORM_FLASH.get(k, 0), floor_layer=floor_layer)


def storm_form_frame(j: int, floor_layer: bool = False) -> Image.Image:
    t = (j + 1) / STORM_FRAMES
    e = 1 - (1 - t) ** 2
    img = storm_cloud_art(j * STORM_LOOP // STORM_FRAMES, 0.2 + 0.8 * e, max(0.0, (j - 3) / 4), 14 * (1 - e),
                          floor_layer=floor_layer)
    if j < 4 and not floor_layer:  # white vapour streaming in as it gathers, then a spark of gold as it takes hold
        c = Canvas(STORM_SIZE)
        m = STORM_SIZE // 2
        for a in range(8):
            ang = math.tau * a / 8 + j * 0.5
            d = (34 - 7 * j) if j < 3 else 8
            c.dot(round(m + math.cos(ang) * d), round(STORM_CLOUD_Y + math.sin(ang) * d * 0.4), WHITE if a % 2 else STEEL)
        img.alpha_composite(outline(c.img))
    return img


def storm_end_frame(j: int, floor_layer: bool = False) -> Image.Image:
    t = (j + 1) / STORM_FRAMES
    img = storm_cloud_art(j * STORM_LOOP // STORM_FRAMES, 1 - 0.45 * t, max(0.0, 1 - j / 3), -10 * t, t * 0.95,
                          floor_layer=floor_layer)
    if j < 5 and not floor_layer:  # a last rumble of gold light as it breaks up
        px = img.load()
        rng = random.Random(7 + j)
        for _ in range(4):
            x, y = STORM_SIZE // 2 + rng.randint(-24, 24), STORM_CLOUD_Y + 10 * t + rng.randint(-8, 6)
            if px[x, y][3]:
                px[x, y] = YELLOW + (255,)
    return img


def storm_bolt_frame(k: int) -> Image.Image:
    """A lightning bolt from the top of the frame to BOLT_END_Y (8 frames): strikes white and fat with a crackling
    jitter, a sheath of gold and orange round a white core, forks that grow and stab, then thins and flickers out
    into embers. Drawn bottom-anchored and cropped to length, never stretched."""
    rng = random.Random(21)
    x = BOLT_W // 2
    path = [(x, 7)]
    for y in range(14, BOLT_END_Y, 14):
        x = max(10, min(BOLT_W - 11, x + rng.randint(-7, 7)))
        path.append((x, y))
    path.append((BOLT_W // 2 + rng.randint(-3, 3), BOLT_END_Y))
    jit = random.Random(90 + k)
    if k < 4:  # crackle: the middle of the path wobbles a pixel or two from frame to frame
        path = [(px_ + (jit.randint(-1, 1) if 0 < i < len(path) - 1 else 0), py_) for i, (px_, py_) in enumerate(path)]
    reach = (0.5, 1.0, 1.0, 1.0, 0.9, 0.7, 0.4, 0.0)[k]  # how far the forks have stabbed
    forks = []
    for idx, side in ((3, 1), (6, -1), (8, 1)):
        a = path[idx]
        forks.append([a, (a[0] + side * round(7 * reach), a[1] + round(8 * reach)),
                      (a[0] + side * round(8 * reach), a[1] + round(17 * reach))])
    img = Image.new("RGBA", (BOLT_W, BOLT_H), (0, 0, 0, 0))
    c = Canvas(BOLT_H)
    c.img, c.px = img, img.load()
    halo = (ORANGE, YELLOW, YELLOW, ORANGE, ORANGE, RED, None, None)[k]
    mid = (YELLOW, WHITE, WHITE, YELLOW, YELLOW, ORANGE, ORANGE, None)[k]
    core = (WHITE, WHITE, WHITE, WHITE, YELLOW, YELLOW, ORANGE, ORANGE)[k]
    width = (7, 5, 4, 3, 2, 2, 1, 1)[k]
    if halo and k < 6:
        c.flat(L(path, width + 4), halo)
    if mid:
        c.flat(L(path, width + 2), mid)
        for f in forks:
            c.flat(L(f, max(1, width - 1)), mid)
    c.flat(L(path, max(1, width - 1)), core)
    for f in forks:
        c.flat(L(f, 1), core)
    if k >= 5:  # flicker out: gaps break the path, embers hang along it
        p = img.load()
        for yy in range(BOLT_H):
            for xx in range(BOLT_W):
                if p[xx, yy][3] and ((xx + yy // 3 + k) % (k - 3)) == 0:
                    p[xx, yy] = (0, 0, 0, 0)
        for i, (px_, py_) in enumerate(path[::2]):
            c.dot(px_ + (i % 3) - 1, py_ + k - 4, ORANGE if k < 7 else RED)
    if k < 6:  # the strike point: a flash that swells and sinks into a scorch
        rr = (8, 7, 6, 5, 4, 3)[k]
        c.flat(E((BOLT_W // 2 - rr, BOLT_END_Y - rr // 2, BOLT_W // 2 + rr, BOLT_END_Y + rr // 2)), WHITE if k < 2 else YELLOW if k < 4 else ORANGE)
        if k < 4:
            for i in range(6):
                a = math.tau * i / 6 + 0.3
                c.dot(round(BOLT_W // 2 + math.cos(a) * (rr + 3 + k)), round(BOLT_END_Y + math.sin(a) * (rr * 0.25 + 1 + k * 0.5)), WHITE)
    return outline(img)


def storm_spark_frame(k: int, floor_layer: bool = False) -> Image.Image:
    """Where a bolt struck (8 frames): a white flash and ring, chips flying out and falling under gravity, a puff of
    smoke rising off, over a dithered scorch mark that shrinks away."""
    n = STORM_SPARK
    m = n // 2
    c = Canvas(n)
    sc = 1 - 0.09 * k  # the scorch shrinks away: a solid pool with a dithered rim
    c.flat(E((m - 10 * sc, m - 3.5 * sc, m + 10 * sc, m + 3.5 * sc)), SHADOW)
    if floor_layer:  # the scorch alone, drawn under the players
        return outline(c.img)
    c = Canvas(n)
    if k < 3:  # flash and shock ring
        c.flat(E((m - 5 + k, m - 4 + k, m + 5 - k, m + 3 - k)), WHITE if k < 2 else YELLOW)
        rr = 5 + 3 * k
        for i in range(12):
            a = math.tau * i / 12
            c.dot(round(m + math.cos(a) * rr), round(m + math.sin(a) * rr * 0.55), YELLOW if k else WHITE)
    if k < 6:
        col = (WHITE, WHITE, YELLOW, YELLOW, ORANGE, RED)[k]
        for j in range(7):
            ang = math.tau * j / 7 + 0.4
            d = 3 + 1.8 * k
            x, y = m + math.cos(ang) * d, m + math.sin(ang) * d * 0.7 - 3 * k * 0.3 + 0.35 * k * k
            c.flat(L([(x - math.cos(ang) * 1.5, y - math.sin(ang)), (x, y)], 1), col)
    if 2 <= k <= 6:  # smoke curling up off the scorch
        for i in range(4):
            c.dot(m - 6 + i * 4 + (k + i) % 2, round(m - 1 - (k - 2) * 1.6 - i % 2 * 2), STEEL if k < 5 else STEEL_D)
    return outline(c.img)


FX.update({
    "storm_cloud": lambda: strip([storm_loop_frame(k) for k in range(STORM_LOOP)]),
    "storm_cloud_form": lambda: strip([storm_form_frame(j) for j in range(STORM_FRAMES)]),
    "storm_cloud_end": lambda: strip([storm_end_frame(j) for j in range(STORM_FRAMES)]),
    "storm_spark": lambda: strip([storm_spark_frame(k) for k in range(STORM_SPARK_FRAMES)]),
    "storm_floor": lambda: strip([storm_loop_frame(k, True) for k in range(STORM_LOOP)]),
    "storm_floor_form": lambda: strip([storm_form_frame(j, True) for j in range(STORM_FRAMES)]),
    "storm_floor_end": lambda: strip([storm_end_frame(j, True) for j in range(STORM_FRAMES)]),
    "storm_scorch": lambda: strip([storm_spark_frame(k, True) for k in range(STORM_SPARK_FRAMES)]),
})
FX_IMAGES["storm_bolt"] = lambda: strip([storm_bolt_frame(k) for k in range(BOLT_FRAMES)])
ICONS["storm_cloud"] = lambda c: (c.flat(E((0, 2, 7, 7)), NAVY), c.flat(E((4, 0, 12, 6)), NAVY),
                                  c.flat(E((2, 3, 12, 8)), NAVY), c.flat(R((3, 6, 10, 8)), SHADOW),
                                  c.flat(L([(3, 3), (5, 2)], 1), STEEL_D), c.flat(L([(7, 1), (9, 1)], 1), STEEL_D),
                                  c.flat(P([(8, 7), (4, 10), (7, 10), (5, 12), (11, 8), (8, 8), (10, 7)]), YELLOW),
                                  c.dot(7, 10, WHITE))


# --- Title screen art: logo (+ shine strip), parallax arena backdrop, vignette, light beam, boot splash ---

GLYPHS = {
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
}
LOGO_TEXT = "BRAWLBITS"
LOGO_K = 2  # art px per glyph px
LOGO_PAD = 5
LOGO_DEPTH = 3  # extrusion below the face
LOGO_SHINE_FRAMES = 14
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def logo_face() -> tuple[Image.Image, Image.Image]:
    """(face mask 'L' image, finished logo RGBA): chunky letters, yellow-to-red bands, extrusion, 2 px outline."""
    n = len(LOGO_TEXT)
    adv = 6 * LOGO_K
    w = n * adv - LOGO_K + 2 * LOGO_PAD
    h = 7 * LOGO_K + LOGO_DEPTH + 2 * LOGO_PAD
    face = Image.new("L", (w, h), 0)
    fp = face.load()
    for i, ch in enumerate(LOGO_TEXT):
        for gy, row in enumerate(GLYPHS[ch]):
            for gx, bit in enumerate(row):
                if bit == "1":
                    for dy in range(LOGO_K):
                        for dx in range(LOGO_K):
                            fp[LOGO_PAD + i * adv + gx * LOGO_K + dx, LOGO_PAD + gy * LOGO_K + dy] = 255
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):  # extrusion: MAROON up to DEPTH below every face pixel
        for x in range(w):
            if not fp[x, y] and any(fp[x, y - d] for d in range(1, LOGO_DEPTH + 1) if y - d >= 0):
                op[x, y] = MAROON + (255,)
    for y in range(h):
        for x in range(w):
            if not fp[x, y]:
                continue
            v = y - LOGO_PAD  # 0..13 down the letter
            c = WHITE if v == 0 else YELLOW if v < 6 else ORANGE if v < 10 else RED
            if v < 6 and x and not fp[x - 1, y]:  # lit left edge
                c = WHITE
            op[x, y] = c + (255,)
    return face, outline(outline(out))


def logo_shine() -> Image.Image:
    face, logo = logo_face()
    w, h = logo.size
    fp = face.load()
    frames_ = []
    for k in range(LOGO_SHINE_FRAMES):
        f = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        p = f.load()
        centre = -8 + (w + 24) * k / (LOGO_SHINE_FRAMES - 1)
        for y in range(h):
            for x in range(w):
                if fp[x, y] and abs((x + y * 0.8) - centre) <= 3.5:
                    p[x, y] = WHITE + (255,)
        frames_.append(f)
    return strip(frames_)


def dither_mix(a, b, t: float, x: int, y: int):
    """Ordered dither between two palette colours: t = 0 -> a, 1 -> b."""
    return b if t * 16 > BAYER4[y % 4][x % 4] + 0.5 else a


def title_far() -> Image.Image:
    w, h, horizon = 416, 200, 104
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    px = img.load()
    rng = random.Random(7)
    # night sky: flat bands, a 1-px dither row only where two bands meet
    bands = [(0, OUTLINE), (26, SHADOW), (46, NAVY), (66, BLUE), (84, STEEL_D)]
    for y in range(h):
        i = max(k for k, (y0, _) in enumerate(bands) if y >= y0)
        for x in range(w):
            c = bands[i][1]
            if i and y == bands[i][0] and x % 2:
                c = bands[i - 1][1]
            px[x, y] = c + (255,)
    for _ in range(26):  # a few stars
        sx, sy = rng.randrange(4, w - 4), rng.randrange(9, 60)
        px[sx, sy] = WHITE + (255,)
        if rng.random() < 0.2:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                px[sx + dx, sy + dy] = STEEL + (255,)
    for row, (base, col, amp) in enumerate(((horizon - 22, SHADOW, 5), (horizon - 10, OUTLINE, 6))):
        x = 0  # crowd: bumpy silhouettes in two rows, a few lit phones and flags
        while x < w:
            bw = rng.randint(4, 8)
            top = base - rng.randint(0, amp)
            for xx in range(x, min(w, x + bw)):
                for yy in range(top, horizon + 6):
                    px[xx, yy] = col + (255,)
            if row == 0 and rng.random() < 0.28:
                px[x + 1, top - 1] = rng.choice([YELLOW, PINK, TEAL_L, RED, WHITE]) + (255,)
            x += bw
    for x in range(w):  # truss
        for y in range(0, 7):
            px[x, y] = (OUTLINE if y in (0, 6) else SHADOW if y in (1, 5) else STEEL_D) + (255,)
        if x % 9 < 2:
            px[x, 3] = SHADOW + (255,)
    for cx in (50, 128, 208, 288, 366):  # stadium lights with a dithered spill
        for dx in range(-4, 5):
            for dy in range(7, 11):
                px[cx + dx, dy] = (OUTLINE if dy == 10 or abs(dx) == 4 else YELLOW if dy > 8 else WHITE) + (255,)
        for dx in range(-7, 8):
            for dy in range(11, 17):
                if abs(dx) <= 7 - (dy - 11) and BAYER4[dy % 4][dx % 4] < 5 - (dy - 11):
                    px[cx + dx, dy] = YELLOW + (255,)
    for y in range(horizon + 6, h):  # stage wall below the stands
        for x in range(w):
            c = SHADOW if (x // 26) % 2 == 0 else NAVY
            if y in (horizon + 6, horizon + 7):
                c = STEEL_D if y == horizon + 6 else OUTLINE
            px[x, y] = c + (255,)
    return img


def title_mid() -> Image.Image:
    """Foreground pillars with hanging banners (transparent)."""
    w, h = 416, 200
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x0 in (52, 340):
        d.rectangle([x0, 0, x0 + 24, h], fill=STEEL_D + (255,))
        d.rectangle([x0, 0, x0 + 5, h], fill=STEEL + (255,))
        d.rectangle([x0 + 19, 0, x0 + 24, h], fill=SHADOW + (255,))
        for y in range(10, h, 22):
            d.rectangle([x0, y, x0 + 24, y + 2], fill=OUTLINE + (255,))
            d.rectangle([x0, y + 3, x0 + 18, y + 3], fill=WHITE + (255,))
            for rx in (x0 + 4, x0 + 14):
                d.rectangle([rx, y + 9, rx + 1, y + 10], fill=OUTLINE + (255,))
        bx = x0 + (-22 if x0 < 200 else 26)  # banner
        d.rectangle([bx, 18, bx + 20, 62], fill=RED + (255,))
        d.polygon([(bx, 62), (bx + 20, 62), (bx + 10, 72)], fill=RED + (255,))
        d.rectangle([bx, 18, bx + 3, 62], fill=ORANGE + (255,))
        d.rectangle([bx + 17, 18, bx + 20, 62], fill=MAROON + (255,))
        d.rectangle([bx + 6, 30, bx + 14, 42], fill=YELLOW + (255,))
        d.rectangle([bx + 8, 32, bx + 12, 40], fill=ORANGE + (255,))
        d.rectangle([bx + 4, 52, bx + 15, 53], fill=MAROON + (255,))
    return outline(img)


def title_vignette() -> Image.Image:
    """Screen-edge darkening: a flat border band, then a thin 1-px pattern ramp (no big dither blocks)."""
    w, h = 320, 180
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            e = min(x, y, w - 1 - x, h - 1 - y)  # distance to the nearest screen edge
            if e < 5 or (e < 8 and (x + y) % 2 == 0) or (e < 11 and x % 2 == 0 and y % 2 == 0):
                px[x, y] = OUTLINE + (255,)
    return img


def title_beam() -> Image.Image:
    """Stage-light cone, apex top-centre; drawn with a low alpha tint."""
    w, h = 56, 120
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        half = 2 + y * 0.22
        for x in range(w):
            dx = abs(x - w / 2 + 0.5)
            if dx <= half:
                dens = (1 - y / h) * (1 - dx / (half + 1)) * 1.1
                if dens * 16 > BAYER4[y % 4][x % 4] + 0.5:
                    px[x, y] = WHITE + (255,)
    return img


def title_shadow() -> Image.Image:
    w, h = 40, 12
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse([1, 1, w - 2, h - 2], fill=OUTLINE + (255,))
    return img


def title_art() -> dict[str, tuple[Image.Image, bool]]:
    """name -> (image, check frame edges): everything the title screen draws."""
    return {
        "title_far": (title_far(), False), "title_mid": (title_mid(), False),
        "title_vignette": (title_vignette(), False), "title_beam": (title_beam(), False),
        "title_shadow": (title_shadow(), True), "logo": (logo_face()[1], True),
        "logo_shine": (logo_shine(), False),
    }


def check(sheet: Image.Image, frame_w: int = SIZE, edges: bool = True) -> None:
    """Self-check: palette-only colours, hard alpha, and (`edges`) the outline fits inside each frame."""
    allowed = set(PALETTE)
    px = sheet.load()
    w, h = sheet.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            assert a in (0, 255), f"soft alpha at {x},{y}"
            assert not a or (r, g, b) in allowed, f"off-palette colour {(r, g, b)} at {x},{y}"
            on_edge = y in (0, h - 1) or x % frame_w in (0, frame_w - 1)
            assert not (edges and a and on_edge), f"sprite touches frame edge at {x},{y}"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in (CHARACTERS | FORMS).items():
        if name in CROWNS:
            fs = frames(build, AURAS.get(name), CROWNS[name])
        else:
            fs = [cell(f) for f in frames(build, AURAS.get(name))]
        fs += death_frames(build, CROWNS.get(name) if name in KO_CROWNS else None)
        fs += attack_frames(build, AURAS.get(name), ATTACKS.get(name, []))
        sheet = Image.new("RGBA", (CELL * len(fs), CELL), (0, 0, 0, 0))
        for i, f in enumerate(fs):
            sheet.paste(f, (i * CELL, 0))
        check(sheet, CELL)
        sheet.save(OUT / f"{name}.png")
        print(f"wrote {OUT / f'{name}.png'} ({len(fs)} frames)")
    WEAPON_OUT.mkdir(exist_ok=True)
    for name, draw in WEAPONS.items():
        img = weapon_image(draw)
        check(img, WEAPON_W)
        img.save(WEAPON_OUT / f"{name}.png")
    for name, draw in WEAPON_ANIMS.items():
        anim = Image.new("RGBA", (WEAPON_W * 4, WEAPON_H), (0, 0, 0, 0))
        for t in range(4):
            anim.paste(weapon_image(lambda c, t=t: draw(c, t)), (t * WEAPON_W, 0))
        check(anim, WEAPON_W)
        anim.save(WEAPON_OUT / f"{name}_anim.png")
    print(f"wrote {len(WEAPONS)} weapons to {WEAPON_OUT}")
    PROJ_OUT.mkdir(exist_ok=True)
    for name, draw in PROJECTILES.items():
        img = projectile_strip(draw, PROJECTILE_FRAMES.get(name, 2))
        check(img, PROJ)
        img.save(PROJ_OUT / f"{name}.png")
    print(f"wrote {len(PROJECTILES)} projectiles to {PROJ_OUT}")
    ARENA_OUT.mkdir(exist_ok=True)
    for name, parts in THEMES.items():
        sheet = theme_sheet(*parts)
        check(sheet, edges=False)  # tiles fill their cells edge to edge
        sheet.save(ARENA_OUT / f"{name}_tiles.png")
    for name, decal in DECALS.items():
        img = decal()
        check(img, img.width)
        img.save(ARENA_OUT / f"{name}_decal.png")
    for name, img in pickup_art().items():
        check(img, img.width)
        img.save(ARENA_OUT / f"{name}.png")
    print(f"wrote {len(THEMES)} arena themes to {ARENA_OUT}")
    UI_OUT.mkdir(exist_ok=True)
    for name, img in ui_kit().items():
        check(img, img.width, edges=False)  # UI art is outlined right up to its box
        img.save(UI_OUT / f"{name}.png")
    print(f"wrote UI kit to {UI_OUT}")
    for name, (img, edges) in title_art().items():
        check(img, img.height if name == "logo_shine" else img.width, edges=edges)
        img.save(UI_OUT / f"{name}.png")
    splash = logo_face()[1]  # engine boot splash: the logo at 5x (project.godot sets the dark bg colour)
    splash.resize((splash.width * 5, splash.height * 5), Image.NEAREST).save(UI_OUT / "boot_splash.png")
    print("wrote title screen art")
    FX_OUT.mkdir(exist_ok=True)
    for name, make in FX.items():
        img = make()
        check(img, img.height)
        img.save(FX_OUT / f"{name}.png")
    for name, make in FX_IMAGES.items():
        img = make()
        check(img, img.width)
        img.save(FX_OUT / f"{name}.png")
    print(f"wrote {len(FX)} effect strips to {FX_OUT}")
    # App Store icons must be opaque.
    icon = Image.new("RGBA", (SIZE, SIZE), NAVY + (255,))
    icon.alpha_composite(frames(flicker)[0])  # the app icon follows Flicker's look
    icon.convert("RGB").resize((ICON_SIZE, ICON_SIZE), Image.NEAREST).save(ROOT / "assets" / "icon.png")
    print("wrote assets/icon.png")


if __name__ == "__main__":
    main()
