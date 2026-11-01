"""Gloom Hound concepts, round 2: three small directions (A sleek, B shaggy smoke mane, C spectral with glowing ribs), each a
side run frame and a 3/4 view (the game camera is top-down 3/4) next to Shadow for scale, plus 1x / 2x insets.
Nothing is written into assets/. Run: tools/sprites/.venv/bin/python tools/sprites/hound_concepts2.py [out.png]
Silhouette first: the body is ONE mask (ellipses + tapered limbs, no seams), near-black indigo, then lit from the top left:
a violet rim on the top / left edges, dithered lift just inside it, glowing eyes with a 1 px glow, and the mane, tail and
paw tips dissolving into dithered smoke."""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw  # noqa: E402

from palette import OUTLINE, PINK_L, SHADOW, VIOLET, VIOLET_D, VIOLET_L, WHITE  # noqa: E402

N = 96
G = 70  # ground row
S = 0.64  # design coordinates (a ~50 px hound) are shrunk to this: ~65% of Shadow's height
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
INK = OUTLINE  # body: near-black indigo


def T(x: float, y: float) -> tuple[float, float]:
    """Design coordinates (paws on row 68, centre column 48) -> canvas."""
    return 48 + (x - 48) * S, G + (y - 68) * S


class Mask:
    def __init__(self):
        self.im = Image.new("L", (N, N), 0)
        self.d = ImageDraw.Draw(self.im)

    def ell(self, x0, y0, x1, y1):
        a, b = T(x0, y0), T(x1, y1)
        self.d.ellipse((a[0], a[1], b[0], b[1]), 255)

    def poly(self, pts):
        self.d.polygon([T(*p) for p in pts], 255)

    def limb(self, pts, radii):
        """A tapered limb: circles along the polyline, radius interpolated, so it is one smooth shape."""
        segs = []
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            segs.append(math.hypot(x1 - x0, y1 - y0))
        total = sum(segs) or 1.0
        steps = int(total * 1.6) + 1
        for i in range(steps + 1):
            u = i / steps
            dist = u * total
            k = 0
            while k < len(segs) - 1 and dist > segs[k]:
                dist -= segs[k]
                k += 1
            v = dist / (segs[k] or 1.0)
            x = pts[k][0] + (pts[k + 1][0] - pts[k][0]) * v
            y = pts[k][1] + (pts[k + 1][1] - pts[k][1]) * v
            r = radii[0] + (radii[-1] - radii[0]) * u
            self.ell(x - r, y - r, x + r, y + r)


def empty(m, x, y) -> bool:
    return not (0 <= x < N and 0 <= y < N) or m[x, y] == 0


def render(mask: Mask, fade_below: int | None, ridge=None, ribs=None, seed=1) -> Image.Image:
    """Lights the mask: INK body, a VIOLET rim on top-left edges, dithered lift just inside, VIOLET_D on bottom-right edges
    (so a near-black body still reads against the floor). Pixels below `fade_below` (the paws) dither away."""
    m = mask.im.load()
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    px = img.load()
    for y in range(N):
        for x in range(N):
            if not m[x, y]:
                continue
            if fade_below is not None and y > fade_below:  # paws dissolve into smoke
                f = (y - fade_below) / max(1, G - fade_below + 1)
                if BAYER[y % 4][x % 4] / 16 < f * 1.15:
                    continue
            up, left, upleft = empty(m, x, y - 1), empty(m, x - 1, y), empty(m, x - 1, y - 1)
            down, right = empty(m, x, y + 1), empty(m, x + 1, y)
            if up or left or upleft:
                col = VIOLET
            elif empty(m, x, y - 2) or empty(m, x - 2, y):
                col = SHADOW if (x + y) % 2 == 0 else VIOLET_D
            elif down or right:
                col = VIOLET_D if (x + y) % 3 == 0 else INK
            elif empty(m, x, y - 3) or empty(m, x - 3, y):
                col = SHADOW if (x + y) % 2 == 0 else INK
            else:
                col = INK
            px[x, y] = col + (255,)
    if ridge:
        for (x, y) in ridge:
            if 0 < x < N - 1 and 0 < y < N - 1 and px[x, y][3]:
                px[x, y] = VIOLET_L + (255,)
    return img


def smoke(img: Image.Image, spots, seed: int, wide: int = 1) -> None:
    """Dithered smoke wisps: each spot (x, y, dx, dy, length) drifts off along (dx, dy), thinning to nothing."""
    rng = random.Random(seed)
    px = img.load()
    for x, y, dx, dy, ln in spots:
        for i in range(ln):
            u = i / ln
            cx, cy = x + dx * i + rng.uniform(-0.6, 0.6), y + dy * i + rng.uniform(-0.6, 0.6)
            for ox in range(wide):
                for oy in range(wide):
                    X, Y = round(cx) + ox, round(cy) + oy
                    if 2 <= X < N - 2 and 2 <= Y < N - 2 and BAYER[Y % 4][X % 4] / 16 > u * 1.1 - 0.1 and not px[X, Y][3]:
                        px[X, Y] = (VIOLET if u < 0.45 else VIOLET_D) + (255,)


def eye(img: Image.Image, x: int, y: int, w: int = 2, glow: bool = True) -> None:
    px = img.load()
    for i in range(w):
        px[x + i, y] = WHITE + (255,)
        if glow:
            for gx, gy in ((x + i, y - 1), (x + i, y + 1)):
                if not px[gx, gy][3] or px[gx, gy][:3] in (INK, VIOLET_D, SHADOW):
                    px[gx, gy] = VIOLET_L + (255,)
    if glow:
        px[x - 1, y] = VIOLET_L + (255,)
        px[x + w, y] = VIOLET_L + (255,)


# --- side view (facing right) ---------------------------------------------------------------------------------------
def leg(m: Mask, hip, ph: float, front: bool, r0: float) -> tuple:
    swing, lift = math.sin(ph), max(0.0, math.cos(ph))
    paw = (hip[0] + 8 * swing, 68 - 6 * lift)
    mid = ((hip[0] + paw[0]) / 2 + (3 if front else -4) * (0.5 + 0.5 * lift), (hip[1] + paw[1]) / 2 - lift * 2)
    m.limb([hip, mid, paw], [r0, r0 * 0.55, r0 * 0.4])
    return paw


def side(variant: str, phase: float = 0.6) -> Image.Image:
    m = Mask()
    bob = -abs(math.sin(phase)) * 1.5
    g = 68 + bob  # paws
    b = g - 7  # the body rides higher: long legs
    m.ell(21, b - 33, 45, b - 9)  # haunch
    m.ell(51, b - 37, 73, b - 8)  # deep chest
    m.poly([(34, b - 31), (46, b - 33), (58, b - 34), (58, b - 15), (47, b - 17), (35, b - 11)])  # back and tucked waist
    m.poly([(58, b - 36), (67, b - 42), (72, b - 27), (62, b - 20)])  # neck
    m.ell(62, b - 44, 78, b - 29)  # skull
    m.poly([(72, b - 40), (91, b - 33), (92, b - 30), (90, b - 28), (74, b - 28)])  # long tapered muzzle
    m.poly([(63, b - 41), (59, b - 55), (70, b - 43)])  # ears, pointed and swept back
    m.poly([(69, b - 43), (70, b - 56), (77, b - 41)])
    m.limb([(25, b - 25), (16, b - 29), (11, b - 38), (13, b - 48)], [3.4, 2.3, 0.9])  # tail
    paws = [leg(m, (33, b - 12), phase + math.pi, False, 5.0), leg(m, (61, b - 12), phase + math.pi + 0.7, True, 4.4),
            leg(m, (30, b - 12), phase, False, 5.2), leg(m, (58, b - 12), phase + 0.7, True, 4.6)]
    ridge = []
    if variant == "A":  # sleek: a clean nape ridge
        for i in range(10):
            x, y = T(46 + i * 2.6, g - 42 - (1 if i % 3 == 0 else 0))
            ridge.append((round(x), round(y)))
    if variant == "B":  # shaggy: tufts of mane down neck and spine
        for k in range(6):
            m.poly([(62 - k * 5, g - 43 + (k % 2)), (66 - k * 5, g - 44), (60 - k * 5 - (k % 2) * 2, g - 53 - (k % 3) * 2)])
    img = render(m, fade_below=int(T(0, 68)[1]) - 2, ridge=ridge)
    px = img.load()
    if variant == "C":  # ribs glowing through the flank + a crack down the haunch
        for k in range(4):
            x0, y0 = T(48 + k * 3.6, g - 36 + k * 0.4)
            x1, y1 = T(47 + k * 3.6, g - 22)
            n = int(y1 - y0)
            for i in range(n + 1):
                x, y = round(x0 + (x1 - x0) * i / max(1, n) + math.sin(i * 0.9) * 0.6), round(y0 + i)
                if px[x, y][3] and px[x, y][:3] in (INK, SHADOW, VIOLET_D):
                    px[x, y] = (VIOLET_L if i % 3 else WHITE) + (255,)
        for i, (cx, cy) in enumerate(((27, g - 36), (29, g - 32), (28, g - 28), (30, g - 25))):
            x, y = T(cx, cy)
            if px[round(x), round(y)][3]:
                px[round(x), round(y)] = VIOLET_L + (255,)
    ex, ey = T(74, g - 42)
    eye(img, round(ex), round(ey), 2)
    nx, ny = T(90, g - 36)
    px[round(nx), round(ny)] = VIOLET + (255,)
    # smoke: tail tip, mane (B much more), paws
    tx, ty = T(13, g - 55)
    spots = [(tx, ty - 1, -0.5, -1.0, 7), (tx - 1, ty + 1, -1.0, -0.5, 5)]
    for p in paws:
        px_, py_ = T(*p)
        spots.append((px_, py_ - 1, -0.7 if p[0] < 50 else -0.4, 0.15, 6))
    if variant == "B":
        for k in range(7):
            x, y = T(62 - k * 4.5, g - 45 - (k % 3))
            spots.append((x, y, -0.8, -0.9 - 0.15 * (k % 2), 6 + k % 3))
    elif variant == "C":
        for k in range(4):
            x, y = T(40 + k * 7, g - 40)
            spots.append((x, y, -0.5, -1.0, 5))
    else:
        for k in range(2):
            x, y = T(54 + k * 6, g - 43)
            spots.append((x, y, -0.8, -0.8, 4))
    smoke(img, spots, seed=3 if variant == "A" else 7 if variant == "B" else 11)
    return img


# --- 3/4 view (top-down camera, facing down-right toward the viewer) ----------------------------------------------
def three_quarter(variant: str, phase: float = 0.6) -> Image.Image:
    m = Mask()
    bob = -abs(math.sin(phase)) * 1.2
    g = 68 + bob
    b = g - 7
    m.ell(23, b - 38, 46, b - 15)  # haunch, behind and up
    m.poly([(38, b - 36), (52, b - 34), (56, b - 16), (42, b - 15)])  # tucked waist
    m.ell(46, b - 36, 68, b - 8)  # chest toward us, narrower than a cat's
    m.poly([(54, b - 33), (62, b - 40), (66, b - 24), (56, b - 17)])  # neck
    m.ell(56, b - 40, 73, b - 21)  # skull
    m.poly([(61, b - 28), (71, b - 26), (70, b - 10), (63, b - 9)])  # long tapered muzzle pointing down at us
    m.poly([(57, b - 36), (53, b - 54), (63, b - 40)])  # ears
    m.poly([(66, b - 40), (74, b - 54), (74, b - 34)])
    m.limb([(30, b - 28), (20, b - 32), (15, b - 41), (16, b - 51)], [3.2, 2.2, 0.9])  # tail up behind
    paws = []
    for hip, ph, r in (((34, b - 12), phase + math.pi, 4.2), ((51, b - 8), phase + math.pi, 4.4), ((62, b - 8), phase, 4.8),
                       ((29, b - 12), phase, 4.0)):
        lift = max(0.0, math.cos(ph))
        paw = (hip[0] + 2 * math.sin(ph), 68 - 4 * lift + (0 if hip[0] > 45 else -5))
        m.limb([hip, ((hip[0] + paw[0]) / 2 + 1, (hip[1] + paw[1]) / 2), paw], [r, r * 0.6, r * 0.4])
        paws.append(paw)
    ridge = []
    if variant == "B":
        for k in range(6):
            m.poly([(54 - k * 4, g - 44 + k), (58 - k * 4, g - 44 + k), (52 - k * 4 - (k % 2), g - 53 + k - (k % 3))])
    if variant == "A":
        for i in range(8):
            x, y = T(34 + i * 2.8, g - 44 + i * 0.3)
            ridge.append((round(x), round(y)))
    img = render(m, fade_below=int(T(0, 68)[1]) - 2, ridge=ridge)
    px = img.load()
    if variant == "C":
        for k in range(3):
            x0, y0 = T(50 + k * 4, g - 35)
            x1, y1 = T(52 + k * 4, g - 22)
            n = int(y1 - y0)
            for i in range(n + 1):
                x, y = round(x0 + (x1 - x0) * i / max(1, n)), round(y0 + i)
                if px[x, y][3] and px[x, y][:3] in (INK, SHADOW, VIOLET_D):
                    px[x, y] = (VIOLET_L if i % 3 else WHITE) + (255,)
    for ex_ in (60, 69):  # two glowing eyes
        ex, ey = T(ex_, g - 35)
        eye(img, round(ex), round(ey), 1)
    nx, ny = T(67, g - 17)
    px[round(nx), round(ny)] = VIOLET + (255,)
    tx, ty = T(16, g - 58)
    spots = [(tx, ty - 1, -0.4, -1.0, 7)]
    for p in paws:
        x, y = T(*p)
        spots.append((x, y - 1, -0.6, 0.1, 5))
    if variant == "B":
        for k in range(6):
            x, y = T(54 - k * 4, g - 47 + k)
            spots.append((x, y, -0.7, -0.9, 7))
    smoke(img, spots, seed=5 if variant == "A" else 9 if variant == "B" else 13)
    return img


def main() -> None:
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("hound_concepts2.png")
    shadow = Image.open(Path(__file__).resolve().parents[2] / "assets/sprites/shadow.png").convert("RGBA").crop((0, 0, 96, 96))
    cells = [("Shadow", shadow)]
    for v, name in (("A", "A sleek"), ("B", "B shaggy smoke mane"), ("C", "C spectral ribs")):
        cells.append((f"{name}: side", side(v)))
        cells.append((f"{name}: 3/4", three_quarter(v)))
    S8 = 8
    box = (16, 18, 88, 78)  # 72 x 60
    w, h = box[2] - box[0], box[3] - box[1]
    bg = (58, 64, 74)
    cols = 7
    img = Image.new("RGB", (cols * w * S8 // 2 + 0, h * S8 + 180), bg)
    img = Image.new("RGB", (cols * w * 8, h * 8 + 190), bg)  # 8x per cell; 1x / 2x insets below
    d = ImageDraw.Draw(img)
    sc = 8
    for i, (label, im) in enumerate(cells):
        x0 = i * w * sc
        layer = Image.new("RGBA", (N, N), bg + (255,))
        sh = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        rx, ry = (20, 5) if label != "Shadow" else (14, 5)
        sd.ellipse((48 - rx, G + 1 - ry, 48 + rx, G + 1 + ry), fill=(0, 0, 0, 77))  # the fighters' soft 0.3 ellipse
        layer.alpha_composite(sh)
        layer.alpha_composite(im)
        cell = layer.convert("RGB").crop(box)
        img.paste(cell.resize((w * sc, h * sc), Image.NEAREST), (x0, 0))
        d.text((x0 + 4, h * sc + 2), label, fill=(255, 230, 120))
        img.paste(cell, (x0 + 4, h * sc + 20))  # 1x inset
        img.paste(cell.resize((w * 2, h * 2), Image.NEAREST), (x0 + 4 + w + 8, h * sc + 20))  # 2x inset
    img.save(out_path)
    print("wrote", out_path, img.size)


if __name__ == "__main__":
    main()
