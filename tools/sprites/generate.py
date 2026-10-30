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


# All characters use a 6 px gap between eyes (left eye x, then left x + 10).
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
        c.part(R((x + dx, 45 + dy, x + dx + 5, 54 + dy)), pants)
        xs.append((x + dx, dy))
    for x, dy in xs:  # small rounded shoe with the toe forward, dark sole
        c.part(RR((x - 1, 53 + dy, x + 7, 57 + dy), 2), boots)
        c.flat(R((x, 57 + dy, x + 6, 57 + dy)), SHADOW)
    return xs


# --- characters: each returns (legs canvas, upper canvas), facing right ------

def flicker(step=None, t=0):
    """Dash: hooded scout with a trailing scarf and a dagger on the back."""
    low = Canvas()
    for x, dy in legs(low, NAVY, BROWN, step):
        low.flat(R((x, 50 + dy, x + 6, 51 + dy)), SKIN_D)  # boot cuffs
    up = Canvas()
    s = SWAY[t % 4]
    up.part(P([(21, 33), (4, 27 + s), (2, 34 + s), (9, 40 + s), (21, 39)]), ORANGE)  # scarf tails flutter
    up.part(P([(9, 33 + s), (2, 34 + s), (9, 40 + s)]), RED, shade=False)
    up.part(L([(13, 25), (25, 45)], 4), BROWN)  # dagger sheath on the back
    up.part(RR((9, 21, 15, 27), 1), STEEL)  # dagger pommel
    up.part(RR((20, 33, 44, 48), 3), NAVY)  # tunic
    up.part(L([(23, 35), (40, 46)], 2), BROWN, shade=False, line=False)  # strap
    up.part(R((20, 44, 44, 46)), BROWN, line=False)  # belt
    up.part(R((30, 43, 34, 47)), YELLOW)
    up.dot(32, 45, ORANGE)
    up.part(P([(18, 12), (7, 19), (17, 27)]), TEAL)  # hood point
    up.part(E((15, 4, 49, 38)), TEAL)  # hood
    up.part(E((23, 15, 47, 35)), SKIN)  # face
    up.part(P([(23, 13), (47, 13), (47, 19), (41, 21), (36, 17), (30, 21), (23, 19)]), TEAL)  # fringe
    up.flat(E((20, 8, 27, 13)), TEAL_L)  # hood shine
    big_eyes(up, 22, (31, 41), TEAL)
    face(up, (28, 45, 29), (37, 29))
    up.part(RR((19, 31, 45, 37), 2), ORANGE)  # scarf
    up.part(RR((17, 32, 24, 39), 2), RED)  # scarf knot
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


def wukong_ape(step=None, t=0):
    """Great Ape (Wukong's special): an angry, dark-red brute. Hunched, broad-shouldered, long arms
    with big fists, glowing red eyes under a heavy scowl, golden circlet and bracers, storm clouds.
    A transformation form, drawn bigger in game (SkillData.form_scale)."""
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
    up.part(L([(15, 26), (11, 36), (11, 44)], 7), MAROON)  # back arm
    up.part(L([(49, 26), (53, 36), (53, 44)], 7), MAROON)  # front arm
    for x, thumb in ((5, -2), (47, 9)):  # clenched fists, knuckles down; they bob with the stride
        up.part(R((x + 2, 38, x + 10, 41)), YELLOW)  # golden bracers
        up.part(RR((x, 42 + s, x + 12, 53 + s), 3), MAROON)
        up.part(E((x + thumb, 43 + s, x + thumb + 5, 48 + s)), MAROON)  # thumb wrapped over the fingers
        up.flat(RR((x + 1, 48 + s, x + 11, 53 + s), 1), BROWN)  # curled fingers
        for kx in (x + 4, x + 7):
            up.flat(R((kx, 48 + s, kx, 53 + s)), OUTLINE)  # knuckle splits
        up.flat(R((x + 1, 48 + s, x + 11, 48 + s)), OUTLINE)
    up.part(E((24, 3, 50, 29)), MAROON)  # head, pushed forward
    up.part(E((28, 11, 50, 29)), BROWN)  # dark face
    up.part(P([(23, 8), (47, 4), (47, 9), (23, 13)]), YELLOW, shade=False)  # golden circlet, knocked askew
    up.flat(L([(23, 12), (47, 8)], 1), ORANGE)  # its lower rim
    up.flat(L([(36, 5), (34, 8), (37, 9), (35, 12)], 1), OUTLINE)  # crack
    up.flat(P([(43, 4), (47, 4), (47, 6)]), OUTLINE)  # chipped corner
    up.flat(R((28, 9, 29, 10)), RED)  # gem
    for x in (32, 42):  # glowing red eyes
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


# Hands are drawn by the game on the weapon's grip (they follow the aim), not baked into the sheets.
HANDS = {"flicker": SKIN, "warden": STEEL, "twinshot": BROWN, "wukong": SKIN}
HAND_SIZE = 10


def hand_image(color) -> Image.Image:
    c = Canvas()
    c.part(E((2, 2, 7, 7)), color)
    return outline(c.img).crop((0, 0, HAND_SIZE, HAND_SIZE))


WEAPONS = {"pistol": pistol, "bot_blaster": bot_blaster, "smg": smg, "shotgun": shotgun, "sniper": sniper,
           "rocket": rocket, "grenade": grenade, "laser": laser, "sword": sword,
           "flicker_kunai": kunai, "warden_hammer": hammer, "twinshot_revolver": revolver, "wukong_staff": staff}


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


CHARACTERS = {"flicker": flicker, "warden": warden, "twinshot": twinshot, "wukong": wukong}
## Transformation sheets (SkillData.form_sprite_sheet): laid out like characters, no hands.
FORMS = {"wukong_ape": wukong_ape}
AURAS = {"wukong": wukong_clouds, "wukong_ape": ape_storm}  # optional per-frame effects drawn behind


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


def frames(build, aura=None) -> list[Image.Image]:
    def frame(step, dy, i):
        low, up = build(step, i)
        f = aura(i).img if aura else Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        f.alpha_composite(low.img)
        f.alpha_composite(up.img, (0, UPPER_DY + dy))
        return outline(f)

    idle = [frame(None, dy, i) for i, dy in enumerate(IDLE_BOB)]
    hit = [recolor(idle[0], lambda _c: WHITE), recolor(idle[0], LIGHTER.__getitem__)]
    walk = [frame(i, dy, i) for i, dy in enumerate(WALK_BOB)]
    return idle + hit + walk


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
        fs = frames(build, AURAS.get(name))
        sheet = Image.new("RGBA", (SIZE * len(fs), SIZE), (0, 0, 0, 0))
        for i, f in enumerate(fs):
            sheet.paste(f, (i * SIZE, 0))
        check(sheet)
        sheet.save(OUT / f"{name}.png")
        print(f"wrote {OUT / f'{name}.png'} ({len(fs)} frames)")
    WEAPON_OUT.mkdir(exist_ok=True)
    for name, draw in WEAPONS.items():
        img = weapon_image(draw)
        check(img, WEAPON_W)
        img.save(WEAPON_OUT / f"{name}.png")
    print(f"wrote {len(WEAPONS)} weapons to {WEAPON_OUT}")
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
    # App Store icons must be opaque.
    icon = Image.new("RGBA", (SIZE, SIZE), NAVY + (255,))
    icon.alpha_composite(frames(flicker)[0])
    icon.convert("RGB").resize((ICON_SIZE, ICON_SIZE), Image.NEAREST).save(ROOT / "assets" / "icon.png")
    print("wrote assets/icon.png")


if __name__ == "__main__":
    main()
