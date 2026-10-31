"""Procedural pixel art for Brawlbit's original characters.

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

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

from palette import (BLUE, BROWN, DARKER, LIGHTER, MAROON, NAVY, ORANGE, OUTLINE, PALETTE, RED, SHADOW,
                     SKIN, SKIN_D, STEEL, STEEL_D, TEAL, TEAL_L, WHITE, YELLOW)

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

        if line:
            for y in range(n):
                for x in range(n):
                    if not inside(x, y) and self.px[x, y][3] and any(
                            inside(nx, ny) for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                        self.px[x, y] = OUTLINE + (255,)
        for y in range(n):
            for x in range(n):
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
def big_eyes(c: Canvas, y: int, xs: tuple[int, int], iris, h: int = 6):
    for x in xs:
        if KO:
            x_eye(c, x, y + 1)
            continue
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
        c.part(R((x + dx, 45 + dy, x + dx + 5, 54 + dy)), pants)
        xs.append((x + dx, dy))
    for x, dy in xs:  # small rounded shoe with the toe forward, dark sole
        c.part(RR((x - 1, 53 + dy, x + 7, 57 + dy), 2), boots)
        c.flat(R((x, 57 + dy, x + 6, 57 + dy)), SHADOW)
    return xs


# --- characters: each returns (legs canvas, upper canvas), facing right ------

def flicker(step=None, t=0):
    """Ninja: black shroud and hood, masked face (just the eyes show), steel forehead plate,
    a red scarf trailing behind and a ninjato on the back."""
    low = Canvas()
    for x, dy in legs(low, SHADOW, NAVY, step):
        low.flat(R((x, 49 + dy, x + 5, 49 + dy)), NAVY)  # leg wraps
        low.flat(R((x, 51 + dy, x + 5, 51 + dy)), NAVY)
    up = Canvas()
    s = SWAY[t % 4]
    up.part(P([(21, 33), (4, 27 + s), (2, 34 + s), (9, 40 + s), (21, 39)]), RED)  # scarf tails flutter
    up.part(P([(9, 33 + s), (2, 34 + s), (9, 40 + s)]), MAROON, shade=False)
    up.part(L([(13, 25), (25, 45)], 4), OUTLINE)  # ninjato on the back
    up.part(RR((9, 21, 15, 27), 1), STEEL)  # its guard and pommel
    up.part(RR((20, 33, 44, 48), 3), SHADOW)  # shroud
    up.part(P([(22, 34), (32, 41), (42, 34), (42, 37), (32, 44), (22, 37)]), NAVY, shade=False, line=False)  # wrap fold
    up.part(R((20, 44, 44, 46)), RED, line=False)  # sash
    up.part(P([(18, 12), (7, 19), (17, 27)]), SHADOW)  # hood point
    up.part(E((15, 4, 49, 38)), SHADOW)  # hood
    up.part(RR((22, 18, 47, 27), 3), SKIN)  # eye slit
    up.part(R((22, 13, 47, 17)), STEEL)  # forehead plate
    up.flat(R((32, 14, 36, 15)), STEEL_D)  # its engraving
    up.part(E((21, 26, 48, 37)), SHADOW)  # mask over the lower face
    up.flat(E((20, 8, 27, 13)), NAVY)  # hood sheen
    big_eyes(up, 20, (31, 41), RED, h=5)
    up.part(RR((19, 31, 45, 37), 2), RED)  # scarf
    up.part(RR((17, 32, 24, 39), 2), MAROON)  # scarf knot
    return low, up


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
    up.part(E((20, 14, 44, 37)), SKIN)  # face
    big_eyes(up, 23, (29, 39), BLUE)
    up.flat(R((29, 21, 32, 21)), BROWN)  # brows
    up.flat(R((39, 21, 42, 21)), BROWN)
    face(up, (25, 43, 30))
    up.part(RR((20, 32, 44, 37), 2), RED)  # bandana
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


def flint(step=None, t=0):
    """Fire: a soot-black little fire elemental with glowing ember cracks and a molten face. His
    flaming hair is drawn above the art box (CROWNS: flint_crown)."""
    low = Canvas()
    for x, dy in legs(low, SHADOW, MAROON, step):
        low.flat(R((x + 2, 47 + dy, x + 2, 50 + dy)), ORANGE)  # ember crack down each leg
    up = Canvas()
    up.part(RR((20, 33, 44, 48), 3), SHADOW)  # sooty body
    for pts in (((25, 35), (28, 39), (26, 43), (28, 47)), ((38, 34), (36, 38), (39, 42)), ((32, 44), (34, 47))):
        up.flat(L(pts, 1), ORANGE)  # glowing cracks
    up.flat(P([(32, 37), (35, 40), (32, 43), (29, 40)]), YELLOW)  # ember heart
    up.dot(32, 40, WHITE)
    up.part(E((20, 14, 44, 37)), ORANGE)  # molten face
    up.part(E((27, 27, 39, 35)), YELLOW, line=False)  # hot glow around the mouth
    big_eyes(up, 23, (29, 39), YELLOW)
    up.flat(R((25, 30, 26, 30)), RED)  # blush
    up.flat(R((42, 30, 43, 30)), RED)
    up.flat(R((33, 31, 35, 31)), MAROON)  # little grin
    # Tongues licking up from the forehead; orange rim so no red stripe runs across the face.
    flame(up, 20, 44, 18, 7, t + 2, tongues=4, line=False, rim=ORANGE)
    return low, up


def flint_crown(t: int, dy: int) -> Canvas:
    """Flint's head on fire: an upright flame rising off his head, its tongues flickering every tick.
    A CELL canvas drawn behind the body before outlining (the face covers its base); `dy` = the head's bob."""
    c = Canvas(CELL)
    top = PAD + UPPER_DY + dy  # cell y of the art box's top, moving with the head
    flame(c, PAD + 21, PAD + 43, top + 24, 26, t, tongues=4)  # no wider than the face (20..44), or the side tongues read as horns
    return c


def wukong(step=None, t=0):
    """Dash: monkey king with a golden circlet, pheasant feathers and a lopsided cloud collar."""
    low = Canvas()
    for x, dy in legs(low, RED, BROWN, step):
        low.flat(R((x, 50 + dy, x + 6, 50 + dy)), YELLOW)  # leg wraps
    up = Canvas()
    s = SWAY[t % 4]
    up.part(L([(21, 44), (11, 45), (6, 40), (7, 33), (11 + s, 31)], 3), BROWN)  # curly tail, tip wags
    up.part(RR((20, 33, 44, 48), 3), YELLOW)  # golden armour
    up.flat(R((31, 36, 33, 44)), ORANGE)
    up.part(R((20, 44, 44, 46)), RED, line=False)  # sash
    up.part(P([(22, 45), (17, 52), (21, 52), (25, 46)]), RED)  # sash tail
    up.part(L([(25, 10), (16, 4), (6, 6 + s)], 2), RED, shade=False)  # pheasant feathers sway
    up.part(L([(29, 9), (24, 3), (14 + s, 2)], 2), RED, shade=False)
    up.part(E((11, 17, 21, 28)), BROWN)  # ear
    up.flat(E((14, 20, 18, 25)), SKIN_D)
    for x in (24, 31, 38):
        up.part(P([(x, 9), (x + 3, 4), (x + 6, 9)]), BROWN)  # fur tufts
    up.part(E((15, 6, 49, 38)), BROWN)  # head fur
    up.part(E((23, 15, 47, 36)), SKIN)  # round, human face
    up.part(P([(23, 16), (47, 16), (47, 18), (43, 19), (39, 17), (35, 19), (30, 17), (26, 19), (23, 18)]), BROWN,
            shade=False)  # spiky fringe
    up.part(R((17, 13, 47, 16)), YELLOW)  # golden circlet
    up.dot(32, 14, RED)
    up.dot(33, 14, RED)
    big_eyes(up, 22, (31, 41), YELLOW)
    face(up, (27, 45, 29), (37, 30))
    # Lopsided on purpose: billows up over the back shoulder, just a wisp at the front.
    collar = ((11, 31, 3), (15, 35, 5), (21, 38, 4), (26, 39, 3), (43, 38, 3), (47, 36, 4))
    up.part(lambda d, f: [d.ellipse((x - r, y - r, x + r, y + r), f) for x, y, r in collar], WHITE,
            line=False)  # fluffy cloud collar on the shoulders
    return low, up


## Great Ape arm poses: "walk" = knuckle-walking, fists planted in front (idle / walk, like a gorilla); "raise" =
## fists up high at the sides; "pound" = fists slammed into the ground wide at both sides (the attack).
## Per pose: (shoulder, elbow, wrist) per arm, then (x, top, thumb dx) per fist. Back arm / fist first.
APE_POSES = {"walk": ((((15, 26), (28, 36), (36, 44)), ((49, 26), (53, 36), (52, 44))), ((30, 45, -2), (46, 45, 9))),
             "raise": ((((15, 26), (9, 18), (8, 13)), ((49, 26), (55, 18), (56, 13))), ((2, 2, -2), (50, 2, 9))),
             "pound": ((((15, 26), (8, 36), (7, 43)), ((49, 26), (56, 36), (57, 43))), ((2, 47, -2), (50, 47, 9)))}


def wukong_ape(step=None, t=0, pose=None):
    """Great Ape (Wukong's special): an angry, dark-red brute. Hunched, broad-shouldered, long arms
    with big fists, glowing red eyes under a heavy scowl, golden circlet and bracers, storm clouds.
    A transformation form, drawn bigger in game (SkillData.form_scale). `pose` (attack frames): (from, to, mix)
    between two APE_POSES; None = knuckle-walking."""
    low = Canvas()
    for x, (dx, dy) in zip((21, 35), WALK_LEGS[step] if step is not None else ((0, 0), (0, 0))):
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
    up.part(P([(23, 8), (47, 4), (47, 9), (23, 13)]), YELLOW, shade=False)  # golden circlet, knocked askew
    up.flat(L([(23, 12), (47, 8)], 1), ORANGE)  # its lower rim
    up.flat(L([(36, 5), (34, 8), (37, 9), (35, 12)], 1), OUTLINE)  # crack
    up.flat(P([(43, 4), (47, 4), (47, 6)]), OUTLINE)  # chipped corner
    up.flat(R((28, 9, 29, 10)), RED)  # gem
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


def ember_palm(c):  # Flint: a burning orb held in the palm, a tongue of fire licking forward
    c.part(P([(10, 8), (24, 11), (10, 15)]), RED, shade=False)
    c.part(P([(11, 10), (20, 11), (11, 13)]), YELLOW, shade=False, line=False)
    c.part(E((3, 6, 14, 17)), ORANGE)
    c.flat(E((6, 9, 11, 14)), YELLOW)
    c.dot(7, 10, WHITE)


# Hands are drawn by the game on the weapon's grip (they follow the aim), not baked into the sheets.
HANDS = {"flicker": NAVY, "warden": STEEL, "twinshot": BROWN, "wukong": SKIN, "flint": ORANGE}
HAND_SIZE = 10


def hand_image(color) -> Image.Image:
    c = Canvas()
    c.part(E((2, 2, 7, 7)), color)
    return outline(c.img).crop((0, 0, HAND_SIZE, HAND_SIZE))


WEAPONS = {"pistol": pistol, "bot_blaster": bot_blaster, "smg": smg, "shotgun": shotgun, "sniper": sniper,
           "rocket": rocket, "grenade": grenade, "laser": laser, "sword": sword,
           "flicker_kunai": kunai, "warden_hammer": hammer, "twinshot_revolver": revolver, "wukong_staff": staff, "flint_palm": ember_palm}


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
    "dual": lambda c: (c.flat(R((1, 3, 8, 5)), STEEL), c.flat(R((1, 5, 3, 8)), BROWN),
                       c.flat(R((4, 7, 11, 9)), STEEL), c.flat(R((9, 9, 11, 12)), BROWN)),
    "ape": lambda c: (c.flat(E((1, 1, 11, 11)), MAROON), c.flat(E((3, 5, 10, 11)), BROWN),
                      c.flat(R((2, 2, 10, 3)), YELLOW), c.flat(R((4, 6, 5, 7)), RED), c.flat(R((7, 6, 8, 7)), RED),
                      c.flat(R((5, 9, 8, 9)), OUTLINE)),
    "clones": lambda c: (c.flat(E((0, 2, 6, 8)), SHADOW), c.flat(R((1, 7, 5, 11)), SHADOW),
                         c.flat(E((6, 1, 12, 7)), NAVY), c.flat(R((7, 6, 11, 11)), NAVY),
                         c.flat(R((7, 3, 11, 4)), SKIN), c.flat(R((1, 4, 5, 5)), STEEL_D)),
    "blink": lambda c: (c.flat(P([(6, 0), (8, 4), (12, 6), (8, 8), (6, 12), (4, 8), (0, 6), (4, 4)]), TEAL_L),
                        c.flat(E((5, 5, 7, 7)), WHITE)),
    "smoke": lambda c: (c.flat(E((0, 5, 7, 12)), STEEL_D), c.flat(E((4, 2, 12, 10)), STEEL),
                        c.flat(E((6, 6, 12, 12)), STEEL_D), c.flat(R((4, 1, 5, 2)), RED)),
    "volley": lambda c: [c.flat(L([(6 + round(2 * dx), 6 + round(2 * dy)), (6 + round(6 * dx), 6 + round(6 * dy))], 1), STEEL)
                         for dx, dy in ((1, 0), (0.7, 0.7), (0, 1), (-0.7, 0.7), (-1, 0), (-0.7, -0.7), (0, -1), (0.7, -0.7))]
                        + [c.flat(E((4, 4, 8, 8)), RED)],
    "flare": lambda c: [c.flat(L([(6 + round(3 * dx), 6 + round(3 * dy)), (6 + round(6 * dx), 6 + round(6 * dy))], 1),
                               ORANGE) for dx, dy in ((1, 0), (0.7, 0.7), (0, 1), (-0.7, 0.7), (-1, 0), (-0.7, -0.7),
                                                      (0, -1), (0.7, -0.7))]
                       + [c.flat(E((3, 3, 9, 9)), RED), c.flat(E((4, 4, 8, 8)), YELLOW)],
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
POOF_FRAMES = 10
SMOKE_FRAMES = 4
BOLT_VARIANTS = 3
BOLT_W, BOLT_H = 24, 88


def poof_frame(size: int, k: int, color) -> Image.Image:
    """A cloud puff: lumps swell up into a full cloud (3 frames), then burst outward, drift up and
    break into wisps. Lumps are uneven (seeded by size, so every frame of a strip agrees)."""
    rng = random.Random(size)
    lumps = [(rng.uniform(-0.3, 0.3), rng.uniform(0.8, 1.15), rng.uniform(0.8, 1.2)) for _ in range(9)]
    c = Canvas(size)
    m = size // 2
    grow = min(1.0, (k + 1) / 3)
    t = max(0.0, (k - 2) / (POOF_FRAMES - 3))
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
    c.part(blob(wisps + ring), color)
    core = round(size * 0.22 * grow * (1 - 1.3 * t))
    if core >= 2:  # drawn over the ring, outlined where it overlaps: reads as separate lumps
        c.part(blob([(m, m - rise, core)]), color)
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
        c.part(RR(box((x0 - 1, 53, x0 + 7, 57), (x1 - 2, 53, x1 + 10, 58)), w(2, 2)), BROWN)
    # the hunched back swells out from behind the armour
    c.part(E(box((20, 31, 44, 48), (10, 14, 54, 45), u)), fur)
    # the golden armour shrinks into the ape's chest
    c.part(RR(box((20, 33, 44, 48), (22, 26, 44, 43), u), w(3, 8)), BROWN if ape else YELLOW)
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
        c.part(RR(box((x0, 42, x0 + 7, 48), (x1, y1, x1 + 12, y1 + 11), u), w(2, 3)), fur)
        c.flat(RR(box((x0 + 1, 45, x0 + 6, 48), (x1 + 1, y1 + 6, x1 + 11, y1 + 11), u), w(1, 1)), BROWN)  # curled fingers
    # head: Wukong's round head pushes forward and shrinks into the ape's
    if t < 0.75:
        c.part(E(box((11, 17, 21, 28), (20, 10, 28, 20), u)), fur)  # ear tucks in
    c.part(E(box((15, 6, 49, 38), (24, 3, 50, 29), u)), fur)
    c.part(E(box((23, 15, 47, 36), (28, 11, 50, 29), u)), face_c)
    collar = ((11, 31, 3), (15, 35, 5), (21, 38, 4), (26, 39, 3), (43, 38, 3), (47, 36, 4))
    for x, y, r in collar:  # the cloud collar puffs away
        rr = r * scale * (1 - t / 0.5)
        if rr >= 1:
            cx, cy = pt((x, y), (x, y), u)
            c.part(E((cx - rr, cy - rr, cx + rr, cy + rr)), WHITE, line=False)
    # the circlet tilts askew
    c.part(P(pts([(17, 13), (47, 13), (47, 16), (17, 16)], [(23, 8), (47, 4), (47, 9), (23, 13)], u)), YELLOW,
           shade=False)
    for x0, x1 in ((31, 32), (41, 42)):  # eyes slide and narrow; turn red and angry halfway
        ex, ey = pt((x0, 22), (x1, 14), u)
        eh = w(6, 3)
        ew = w(3, 3)
        if ape:
            c.flat(R((ex, ey, ex + ew, ey + eh)), OUTLINE)
            c.flat(R((ex, ey + 1, ex + ew, ey + eh - 1)), RED)
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
    six in-between creatures (`between(t, scale)`, e.g. ape_morph) that stretch, swell and grow, with gold sparks crackling. CELL-sized
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

    steps = (0.15, 0.3, 0.45, 0.6, 0.75, 0.9)
    return [at(a, 1.0)] + [sparks(between(t, 1 + (b_scale - 1) * t)) for t in steps] + [at(b, b_scale)]


BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def bolt(variant: int) -> Image.Image:
    """A jagged lightning bolt, top to bottom: gold glow with a white core."""
    rng = random.Random(variant)
    c = Canvas(BOLT_H)
    m = BOLT_H // 2
    pts, x, y = [(m, 2)], m, 2
    while y < BOLT_H - 14:  # uneven drops, sideways jolts that can double back
        y += rng.randint(6, 15)
        x = max(m - 9, min(m + 9, x + rng.choice((-1, 1)) * rng.randint(3, 8)))
        pts.append((x, y))
    pts.append((m + rng.randint(-2, 2), BOLT_H - 3))
    kink = pts[len(pts) // 2]
    fork = [kink, (kink[0] + (8 if kink[0] < m else -8), kink[1] + 8), (kink[0] + (5 if kink[0] < m else -5), kink[1] + 14)]
    c.part(lambda dr, f: (dr.line(pts, f, 5), dr.line(fork, f, 3)), YELLOW, shade=False)
    c.flat(L(pts, 1), WHITE)
    return outline(c.img).crop((m - BOLT_W // 2, 0, m + BOLT_W // 2, BOLT_H))


def smoke_frame(k: int, size: int = 136) -> Image.Image:
    """Smoke Bomb cloud: a dark mass with puffs churning around it (loops)."""
    c = Canvas(size)
    m = size // 2
    puffs = [(m, m, 40)]
    for i in range(10):
        ang = math.tau * i / 10 + k * 0.16
        reach = 34 + 6 * math.sin(k * math.pi / 2 + i)
        puffs.append((m + math.cos(ang) * reach, m + math.sin(ang) * reach, 20 + 4 * (i % 2)))
    c.part(lambda dr, f: [dr.ellipse((x - r, y - r, x + r, y + r), f) for x, y, r in puffs], SHADOW)
    for i in range(0, 10, 3):  # a few lighter wisps on top
        ang = math.tau * i / 10 + k * 0.16 + 0.3
        x, y = m + math.cos(ang) * 30, m + math.sin(ang) * 30
        c.flat(E((x - 5, y - 2, x + 5, y + 2)), STEEL_D)
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
}


def projectile_strip(draw) -> Image.Image:
    frames_ = []
    for f in range(2):
        c = Canvas(PROJ)
        draw(c, f)
        frames_.append(outline(c.img))
    return strip(frames_)


def strip(frames_: list[Image.Image]) -> Image.Image:
    w, h = frames_[0].size
    out = Image.new("RGBA", (w * len(frames_), h), (0, 0, 0, 0))
    for i, f in enumerate(frames_):
        out.paste(f, (i * w, 0))
    return out


FX = {
    "poof": lambda: strip([poof_frame(80, k, WHITE) for k in range(POOF_FRAMES)]),
    "poof_small": lambda: strip([poof_frame(48, k, WHITE) for k in range(POOF_FRAMES)]),
    "poof_dark": lambda: strip([poof_frame(64, k, SHADOW) for k in range(POOF_FRAMES)]),
    "bolt": lambda: strip([bolt(v) for v in range(BOLT_VARIANTS)]),
    "smoke": lambda: strip([smoke_frame(k) for k in range(SMOKE_FRAMES)]),
    "blast": lambda: strip([blast_frame(k) for k in range(BLAST_FRAMES)]),
    "slam": lambda: strip([slam_frame(k) for k in range(SLAM_FRAMES)]),
    "slash": lambda: strip([slash_frame(k) for k in range(SLASH_FRAMES)]),
    # Transformation strips (SkillData.form_morph): the character's first idle frame into the form's.
    # 1.35 = great_ape.tres form_scale (keep in sync).
    "wukong_ape_morph": lambda: strip(morph_frames(frames(wukong, AURAS["wukong"])[0],
                                                   frames(wukong_ape, AURAS["wukong_ape"])[0], 1.35, ape_morph)),
}


CHARACTERS = {"flicker": flicker, "warden": warden, "twinshot": twinshot, "wukong": wukong, "flint": flint}
## Transformation sheets (SkillData.form_sprite_sheet): laid out like characters, no hands.
FORMS = {"wukong_ape": wukong_ape}
AURAS = {"wukong": wukong_clouds, "wukong_ape": ape_storm}
## Optional per-frame art above the 64 px box (tall hair, flames), drawn on the CELL behind the frame:
## fn(tick, head_dy) -> Canvas(CELL). Not on death frames.
CROWNS = {"flint": flint_crown}  # optional per-frame effects drawn behind
## Optional melee attack strip after the death frames (CharacterData "attack"): (pose, body dy) per frame,
## build(None, i, pose). Wind up high, then smash down with the body squashed.
ATTACKS = {"wukong_ape": [(("walk", "raise", 0.5), -1), (("raise", "raise", 0), -2), (("raise", "raise", 0), -3),
                          (("raise", "pound", 0.35), -2), (("raise", "pound", 0.7), 0), (("pound", "pound", 0), 2),
                          (("pound", "pound", 0), 2), (("pound", "walk", 0.5), 1)]}


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
    """SIZE px attack frames (ATTACKS), composed like idle frames."""
    out = []
    for i, (pose, dy) in enumerate(poses):
        low, up = build(None, i, pose)
        f = aura(i).img if aura else Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        f.alpha_composite(low.img)
        f.alpha_composite(up.img, (0, UPPER_DY + dy))
        out.append(outline(f))
    return out


## Sheet cells are bigger than the art so the toppling death frames fit; frames are centred in them.
CELL = 96
PAD = (CELL - SIZE) // 2


def cell(img: Image.Image) -> Image.Image:
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    out.alpha_composite(img, (PAD, PAD))
    return out


def death_frames(build) -> list[Image.Image]:
    """8 CELL-sized frames, knocked out (X eyes, no aura): white flash, pops up, topples backwards (it
    faces right, so the head lands on the left), bounces, lies dizzy under circling stars, then
    dissolves (ordered dither) before the respawn."""
    global KO
    KO = True
    try:
        low, up = build(None, 0)
    finally:
        KO = False
    ko = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
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
        fs += death_frames(build)
        fs += [cell(f) for f in attack_frames(build, AURAS.get(name), ATTACKS.get(name, []))]
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
    print(f"wrote {len(WEAPONS)} weapons to {WEAPON_OUT}")
    PROJ_OUT.mkdir(exist_ok=True)
    for name, draw in PROJECTILES.items():
        img = projectile_strip(draw)
        check(img, PROJ)
        img.save(PROJ_OUT / f"{name}.png")
    print(f"wrote {len(PROJECTILES)} projectiles to {PROJ_OUT}")
    assert HANDS.keys() == CHARACTERS.keys(), "every character needs a hand colour"
    for name, color in HANDS.items():
        img = hand_image(color)
        check(img, HAND_SIZE)
        img.save(OUT / f"{name}_hand.png")
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
    FX_OUT.mkdir(exist_ok=True)
    for name, make in FX.items():
        img = make()
        check(img, img.height if name != "bolt" else BOLT_W, edges=name != "bolt")
        img.save(FX_OUT / f"{name}.png")
    print(f"wrote {len(FX)} effect strips to {FX_OUT}")
    # App Store icons must be opaque.
    icon = Image.new("RGBA", (SIZE, SIZE), NAVY + (255,))
    icon.alpha_composite(frames(flicker)[0])  # the app icon follows Flicker's look
    icon.convert("RGB").resize((ICON_SIZE, ICON_SIZE), Image.NEAREST).save(ROOT / "assets" / "icon.png")
    print("wrote assets/icon.png")


if __name__ == "__main__":
    main()
