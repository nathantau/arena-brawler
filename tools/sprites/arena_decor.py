"""Cosmetic arena dressing for the Pit and Foundry (the Gym has its own court decal).

Per theme two full-arena overlays (palette-only, hard alpha, 1 art px = 1 px like the tile sheets):
  <theme>_decal.png    painted over the floor, under the walls: slab joints, cracks, stains, puddles,
                       drains, painted rings / lanes, debris, lamp light pools.
  <theme>_overlay.png  painted over the walls, on wall cells only: pipe runs, cables, lamps, rebar, props.
Everything is derived from the ASCII layouts (parsed from arena_layouts.gd) so decorations keep clear of
spawns / pickups, never alter collision and the floor stays low contrast (bright paint only at the edges).
Floor effects are "lighten / darken the tile underneath" steps through the shared palette ramps, so the
shadow under walls is respected automatically.
"""

import math
import random
import re
from pathlib import Path

from PIL import Image

from palette import (BROWN, DARKER, LIGHTER, MAROON, NAVY, ORANGE, OUTLINE, RED, SHADOW, STEEL, STEEL_D, TEAL,
                     VIOLET_D, WHITE, YELLOW)

TILE = 32
SHADOW_ROWS = 6
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
LAYOUTS_GD = Path(__file__).resolve().parents[2] / "scripts" / "arena" / "arena_layouts.gd"


def load_layout(const: str) -> list[str]:
    text = LAYOUTS_GD.read_text()
    body = re.search(r"const %s: Array\[String\] = \[(.*?)\n\]" % const, text, re.S).group(1)
    return re.findall(r'"([^"]+)"', body)


class Deco:
    def __init__(self, rows: list[str], ref: Image.Image, seed: int):
        self.rows = rows
        self.cw, self.ch = len(rows[0]), len(rows)
        self.w, self.h = self.cw * TILE, self.ch * TILE
        self.ref = ref.convert("RGB")  # the plain tiled floor + walls, to lighten / darken
        self.rng = random.Random(seed)
        self.floor = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        self.over = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        self.fp = self.floor.load()
        self.op = self.over.load()
        self.rp = self.ref.load()
        self.special = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c in "SEW"]

    # --- cell queries -------------------------------------------------------------------------
    def wall(self, cx: int, cy: int) -> bool:
        return not (0 <= cx < self.cw and 0 <= cy < self.ch) or self.rows[cy][cx] == "#"

    def wall_px(self, x: int, y: int) -> bool:
        return self.wall(x // TILE, y // TILE)

    def shadowed(self, x: int, y: int) -> bool:
        return y % TILE < SHADOW_ROWS and self.wall(x // TILE, y // TILE - 1)

    def clear_px(self, x: int, y: int, r: float = 40.0) -> bool:
        """Not near a spawn / pickup (keeps bright or busy marks off the readable spots)."""
        return all(math.hypot(x - (sx + .5) * TILE, y - (sy + .5) * TILE) > r for sx, sy in self.special)

    def floor_ok(self, x: int, y: int) -> bool:
        return 0 <= x < self.w and 0 <= y < self.h and not self.wall_px(x, y)

    def crate_px(self, x: int, y: int) -> bool:
        return self.rows[y // TILE][x // TILE] == "C"

    # --- floor painting -----------------------------------------------------------------------
    def put(self, x: int, y: int, col: tuple) -> None:
        """Fixed colour on the floor (darker inside the wall shadow)."""
        if self.floor_ok(x, y):
            self.fp[x, y] = (DARKER[col] if self.shadowed(x, y) else col) + (255,)

    def shade(self, x: int, y: int, lighter: bool) -> None:
        """One palette step lighter / darker than the floor tile underneath."""
        if self.floor_ok(x, y):
            base = self.rp[x, y]
            if base in LIGHTER:
                self.fp[x, y] = (LIGHTER if lighter else DARKER)[base] + (255,)

    def hline(self, x0: int, x1: int, y: int, col: tuple) -> None:
        for x in range(x0, x1 + 1):
            self.put(x, y, col)

    def blob(self, cx: float, cy: float, rx: float, ry: float, paint, edge: float = 0.35, keep_clear: bool = True) -> None:
        """Ragged dithered ellipse; paint(x, y, depth) with depth 0 (rim) .. 1 (core)."""
        for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
            for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
                d = math.hypot((x - cx) / rx, (y - cy) / ry)
                noise = (math.sin(x * 0.7 + cy) + math.cos(y * 0.9 + cx)) * 0.08
                if d + noise < 1 and (not keep_clear or self.clear_px(x, y, 30)):
                    depth = 1 - (d + noise)
                    if depth > edge or BAYER[y % 4][x % 4] / 16 < depth / edge:
                        paint(x, y, depth)

    def crack(self, x: float, y: float, ang: float, length: int, branch: int = 2) -> None:
        for i in range(length):
            ang += self.rng.uniform(-0.45, 0.45)
            x += math.cos(ang)
            y += math.sin(ang)
            px, py = int(x), int(y)
            if self.floor_ok(px, py) and not self.crate_px(px, py):
                self.put(px, py, OUTLINE)
                if i % 3 == 0:
                    self.shade(px + 1, py + 1, True)  # chipped lip catching the light
            if branch and i > 6 and self.rng.random() < 0.07:
                self.crack(x, y, ang + self.rng.choice((-1, 1)) * self.rng.uniform(0.6, 1.1), length // 2, branch - 1)

    def free_spot(self, margin: float = 44.0) -> tuple[int, int]:
        """A random floor point away from walls, pickups and crates."""
        for _ in range(400):
            x, y = self.rng.randrange(self.w), self.rng.randrange(self.h)
            m = int(margin)
            if all(self.floor_ok(x + dx, y + dy) and not self.crate_px(x + dx, y + dy)
                   for dx in (-m, 0, m) for dy in (-m, 0, m) if 0 <= x + dx < self.w and 0 <= y + dy < self.h) \
                    and self.clear_px(x, y, 56):
                return x, y
        return self.w // 2, self.h // 2

    # --- shared floor elements ----------------------------------------------------------------
    def mottle(self, patches: int, light: float = 0.06) -> None:
        for _ in range(patches):
            x, y = self.rng.randrange(self.w), self.rng.randrange(self.h)
            lighter = self.rng.random() < light
            self.blob(x, y, self.rng.randint(14, 44), self.rng.randint(10, 30),
                      lambda px, py, d, lt=lighter: self.shade(px, py, lt) if d < .8 and (lt or BAYER[py % 4][px % 4] < 5) else None, edge=0.5, keep_clear=False)

    def speckle(self, count: int) -> None:
        for _ in range(count):
            self.shade(self.rng.randrange(self.w), self.rng.randrange(self.h), self.rng.random() < 0.5)

    def slab_joints(self, col_w: int, row_h: int) -> None:
        """Poured-concrete expansion joints: a staggered grid of dark lines with a lit lip."""
        for ri, y in enumerate(range(row_h, self.h, row_h)):
            for x in range(self.w):
                if (x + ri * 53) % 11 < 9:  # broken, not perfectly continuous
                    self.shade(x, y, False)
                    self.shade(x, y + 1, True)
        for ri, y0 in enumerate(range(0, self.h, row_h)):
            off = int((ri * col_w * 0.41) % col_w)
            for x in range(col_w - off, self.w, col_w):
                for y in range(y0, min(y0 + row_h, self.h)):
                    if (y + x) % 13 < 11:
                        self.shade(x, y, False)
                        self.shade(x + 1, y, True)

    def drain(self, cx: int, cy: int, w: int = 26, h: int = 18) -> None:
        x0, y0 = cx - w // 2, cy - h // 2
        for y in range(y0 - 1, y0 + h + 1):
            for x in range(x0 - 1, x0 + w + 1):
                self.put(x, y, SHADOW if (x0 <= x < x0 + w and y0 <= y < y0 + h) else OUTLINE)
        for y in range(y0 + 2, y0 + h - 2):
            for x in range(x0 + 2, x0 + w - 2):
                self.put(x, y, OUTLINE if (x - x0) % 4 in (0, 1) else STEEL_D)
        self.hline(x0, x0 + w - 1, y0, STEEL)
        for bx, by in ((x0 + 1, y0 + 1), (x0 + w - 2, y0 + 1), (x0 + 1, y0 + h - 2), (x0 + w - 2, y0 + h - 2)):
            self.put(bx, by, STEEL)

    def puddle(self, cx: int, cy: int, rx: int, ry: int) -> None:
        self.blob(cx, cy, rx, ry, lambda x, y, d: self.put(x, y, OUTLINE if d < 0.18 else NAVY), edge=0.12)
        self.hline(cx - rx // 2 + ry // 3, cx - rx // 2 + ry // 3 + rx // 2, cy - ry // 3, STEEL_D)  # sky glint
        self.hline(cx - rx // 3, cx - rx // 3 + rx // 4, cy - ry // 3 + 2, STEEL)
        self.put(cx - rx // 3, cy - ry // 3 + 2, WHITE)

    def oil(self, cx: int, cy: int, rx: int, ry: int) -> None:
        self.blob(cx, cy, rx, ry, lambda x, y, d: self.put(x, y, OUTLINE), edge=0.4)
        for k in range(3):  # rainbow sheen
            self.put(cx - rx // 3 + k * 3, cy - ry // 4 + k, VIOLET_D if k != 1 else TEAL)

    def debris(self, count: int) -> None:
        for _ in range(count):
            x, y = self.free_spot(margin=10)
            kind = self.rng.random()
            if kind < 0.4:  # bolt / nut
                self.put(x, y, STEEL)
                self.put(x + 1, y, STEEL_D)
                self.put(x + 1, y + 1, OUTLINE)
            elif kind < 0.8:  # concrete chip + shadow
                for dx, dy in ((0, 0), (1, 0), (0, 1)):
                    self.put(x + dx, y + dy, STEEL_D)
                self.put(x + 1, y + 1, STEEL)
                self.put(x + 2, y + 1, OUTLINE)
                self.put(x + 1, y + 2, OUTLINE)
            else:  # rubble pile
                for dx, dy, c in ((0, 0, STEEL_D), (1, 0, STEEL_D), (2, 0, SHADOW), (0, 1, SHADOW), (1, 1, STEEL),
                                  (2, 1, STEEL_D), (3, 1, OUTLINE), (1, 2, OUTLINE), (2, 2, OUTLINE)):
                    self.put(x + dx, y + dy, c)

    def stripes(self, x0: int, y0: int, x1: int, y1: int, a: tuple, b: tuple, period: int = 12) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, a if ((x - y) % period) < period // 2 else b)

    def ring(self, cx: int, cy: int, r_out: int, r_in: int, col: tuple) -> None:
        self.dash_ring(cx, cy, r_out, r_in, col, col, 2, 0, True)

    def dash_ring(self, cx: int, cy: int, r_out: int, r_in: int, a: tuple, b: tuple, segs: int, skip: int = 0,
                  solid: bool = False) -> None:
        for y in range(cy - r_out, cy + r_out + 1):
            for x in range(cx - r_out, cx + r_out + 1):
                if r_in <= math.hypot(x - cx, y - cy) <= r_out:
                    seg = int((math.atan2(y - cy, x - cx) + math.pi) / (2 * math.pi) * segs)
                    if not solid and skip and seg % skip == 0:
                        continue
                    self.put(x, y, a if seg % 2 == 0 else b)

    def lamp_pool(self, cx: int, cy: int, rx: int, ry: int) -> None:
        """Soft light on the floor: a Bayer-dithered one-step lightening that fades out."""
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                d = math.hypot((x - cx) / rx, (y - cy) / ry)
                if d < 1 and BAYER[y % 4][x % 4] / 16 < (1 - d) * 0.3 and self.clear_px(x, y, 20):
                    self.shade(x, y, True)

    # --- overlay painting (walls) ---------------------------------------------------------------
    def opt(self, x: int, y: int, col: tuple) -> None:
        if 0 <= x < self.w and 0 <= y < self.h and self.wall_px(x, y):
            self.op[x, y] = col + (255,)

    def orect(self, x0: int, y0: int, x1: int, y1: int, col: tuple) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.opt(x, y, col)

    def pipe_h(self, x0: int, x1: int, y: int, thick: int = 6, flange_every: int = 128) -> None:
        for x in range(x0, x1 + 1):
            self.opt(x, y, STEEL)
            for t in range(1, thick - 1):
                self.opt(x, y + t, STEEL_D if t < thick - 2 else SHADOW)
            self.opt(x, y + thick - 1, OUTLINE)
        for fx in range(x0 + flange_every // 2, x1, flange_every):
            self.orect(fx - 2, y - 2, fx + 2, y + thick + 1, STEEL)
            self.orect(fx - 2, y + thick, fx + 2, y + thick + 1, OUTLINE)
            self.opt(fx, y + thick // 2, OUTLINE)

    def pipe_v(self, x: int, y0: int, y1: int, thick: int = 6, flange_every: int = 128) -> None:
        for y in range(y0, y1 + 1):
            self.opt(x, y, STEEL)
            for t in range(1, thick - 1):
                self.opt(x + t, y, STEEL_D if t < thick - 2 else SHADOW)
            self.opt(x + thick - 1, y, OUTLINE)
        for fy in range(y0 + flange_every // 2, y1, flange_every):
            self.orect(x - 2, fy - 2, x + thick + 1, fy + 2, STEEL)
            self.orect(x + thick, fy - 2, x + thick + 1, fy + 2, OUTLINE)
            self.opt(x + thick // 2, fy, OUTLINE)

    def valve(self, cx: int, cy: int) -> None:
        self.orect(cx - 3, cy - 1, cx + 3, cy + 1, RED)
        self.orect(cx - 1, cy - 3, cx + 1, cy + 3, RED)
        self.opt(cx, cy, OUTLINE)
        self.opt(cx - 3, cy - 1, ORANGE)

    def cable(self, x0: int, x1: int, y: int, sag: int, col: tuple = OUTLINE) -> None:
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1, x1 - x0)
            self.opt(x, y + int(math.sin(t * math.pi) * sag), col)
        self.orect(x0, y - 1, x0 + 1, y + 1, STEEL_D)
        self.orect(x1 - 1, y - 1, x1, y + 1, STEEL_D)

    def lamp(self, cx: int, cy: int, glow: tuple = YELLOW) -> None:
        self.orect(cx - 4, cy - 2, cx + 4, cy + 2, STEEL_D)
        self.orect(cx - 4, cy + 2, cx + 4, cy + 2, OUTLINE)
        self.orect(cx - 3, cy - 1, cx + 3, cy + 1, glow)
        self.orect(cx - 1, cy - 1, cx + 1, cy, WHITE)

    def barrel(self, cx: int, cy: int, col: tuple = RED) -> None:
        for y in range(cy - 7, cy + 8):
            for x in range(cx - 7, cx + 8):
                d = math.hypot(x - cx, y - cy)
                if d <= 7.2:
                    self.opt(x, y, OUTLINE if d > 6.2 else col)
        for y in range(cy - 5, cy + 6):
            for x in range(cx - 5, cx + 6):
                if abs(math.hypot(x - cx, y - cy) - 4) < 0.7:
                    self.opt(x, y, STEEL)
        self.orect(cx - 2, cy - 2, cx + 1, cy + 1, DARKER[col])
        self.opt(cx - 4, cy - 4, LIGHTER[col])

    def tyres(self, cx: int, cy: int) -> None:
        for dx, dy in ((-5, 3), (5, 3), (0, -4)):
            for y in range(cy + dy - 6, cy + dy + 7):
                for x in range(cx + dx - 6, cx + dx + 7):
                    d = math.hypot(x - cx - dx, y - cy - dy)
                    if d <= 6.2:
                        self.opt(x, y, OUTLINE if d > 5 or d < 2.6 else SHADOW)
            self.opt(cx + dx - 3, cy + dy - 3, STEEL_D)

    def sandbags(self, cx: int, cy: int) -> None:
        for i, (dx, dy) in enumerate(((-9, 3), (0, 3), (9, 3), (-4, -3), (5, -3))):
            self.orect(cx + dx - 4, cy + dy - 2, cx + dx + 4, cy + dy + 2, BROWN)
            self.orect(cx + dx - 3, cy + dy - 2, cx + dx + 3, cy + dy - 1, ORANGE if i % 2 else YELLOW)
            self.orect(cx + dx - 4, cy + dy + 2, cx + dx + 4, cy + dy + 2, OUTLINE)
            self.opt(cx + dx, cy + dy, MAROON)

    def rebar(self, x: int, y: int) -> None:
        """Crumbled corner of a wall top with rusty rods sticking out."""
        for dx, dy in ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (0, 2)):
            self.opt(x + dx, y + dy, OUTLINE)
        for dx, h in ((3, 6), (6, 4), (9, 7)):
            for k in range(h):
                self.opt(x + dx + k // 4, y + 6 - k, BROWN if k < h - 1 else ORANGE)

    def drips(self, x: int, y: int, length: int, col: tuple) -> None:
        for k in range(length):
            self.opt(x, y + k, col)

    def scuffs(self, cells: list, density: float, cols: tuple) -> None:
        for (x, y) in cells:
            if self.rng.random() < density:
                px, py = x * TILE + self.rng.randint(4, 26), y * TILE + self.rng.randint(4, 26)
                for _ in range(self.rng.randint(8, 18)):
                    self.opt(px, py, self.rng.choice(cols))
                    px += self.rng.choice((-1, 0, 1))
                    py += self.rng.choice((0, 1))

    # --- wall cells helpers --------------------------------------------------------------------
    def face_cells(self) -> list:
        return [(x, y) for y in range(self.ch) for x in range(self.cw)
                if self.rows[y][x] == "#" and y + 1 < self.ch and self.rows[y + 1][x] != "#"]

    def top_cells(self) -> list:
        return [(x, y) for y in range(self.ch) for x in range(self.cw)
                if self.rows[y][x] == "#" and (y + 1 >= self.ch or self.rows[y + 1][x] == "#")]

    def wall_runs(self, lamps_x: tuple, lamps_y: tuple, glow: tuple, thick: int, valves_n: tuple, valves_s: tuple) -> None:
        """Shared border dressing: pipes along all four walls, valves, cables, lamps."""
        d = self
        d.pipe_h(TILE, d.w - TILE - 1, 6, thick)
        d.pipe_h(TILE, d.w - TILE - 1, d.h - TILE + 18, thick)
        d.pipe_v(11, TILE, d.h - TILE - 1, thick)
        d.pipe_v(d.w - 17, TILE, d.h - TILE - 1, thick)
        for vx in valves_n:
            d.valve(vx * TILE + 8, 6 + thick // 2)
        for vx in valves_s:
            d.valve(vx * TILE + 8, d.h - TILE + 18 + thick // 2)
        d.valve(14, 12 * TILE + 5)
        d.valve(d.w - 14, 10 * TILE + 5)
        for x0 in (2, 12, 22, 32):
            d.cable(x0 * TILE + 6, (x0 + 5) * TILE, 15, 4)
            d.cable(x0 * TILE + 18, (x0 + 4) * TILE, d.h - TILE + 8, 3, SHADOW)
        for lx in lamps_x:
            d.lamp(lx * TILE + 16, 23, glow)
            d.lamp(lx * TILE + 16, d.h - TILE + 11, glow)
        for ly in lamps_y:
            d.lamp(23, ly * TILE + 16, glow)
            d.lamp(d.w - 23, ly * TILE + 16, glow)

    def pools(self, lamps_x: tuple, lamps_y: tuple) -> None:
        d = self
        for lx in lamps_x:
            d.lamp_pool(lx * TILE + 16, TILE + 36, 92, 56)
            d.lamp_pool(lx * TILE + 16, d.h - TILE - 36, 92, 56)
        for ly in lamps_y:
            d.lamp_pool(TILE + 36, ly * TILE + 16, 56, 80)
            d.lamp_pool(d.w - TILE - 36, ly * TILE + 16, 56, 80)

    def save(self, out: Path, name: str) -> None:
        self.floor.save(out / f"{name}_decal.png")
        self.over.save(out / f"{name}_overlay.png")


LAMPS_X = (5, 15, 25, 35)
LAMPS_Y = (6, 17)


# ============================================================================================
def pit(rows: list, ref: Image.Image) -> Deco:
    """Underground fighting pit: poured concrete slabs, cracks, oil + puddles, drains, a painted ring,
    hazard-striped edges, pipe runs and lamps along the walls, barrels / tyres / sandbags on the wall tops."""
    d = Deco(rows, ref, 7)
    cx, cy = d.w // 2, d.h // 2
    d.mottle(110)
    d.speckle(5500)
    d.slab_joints(192, 160)
    # painted fighting ring: dashed hazard band between two thin lines, an inner circle and a cross-hair
    d.ring(cx, cy, 196, 194, STEEL_D)
    d.dash_ring(cx, cy, 191, 185, BROWN, OUTLINE, 48)
    d.dash_ring(cx, cy, 191, 185, YELLOW, OUTLINE, 24, skip=6)
    d.ring(cx, cy, 182, 180, STEEL_D)
    d.ring(cx, cy, 70, 68, STEEL_D)
    d.ring(cx, cy, 38, 36, STEEL_D)
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        for r in range(74, 120):
            for t in (0, 1):
                d.put(int(cx + math.cos(ang) * r) + t, int(cy + math.sin(ang) * r), STEEL_D)
    for k in range(-46, 47):
        d.shade(cx + k, cy, True)
        d.shade(cx, cy + k, True)
    # dull hazard stripes along the floor edge of the four borders
    for (x0, y0, x1, y1) in ((3 * TILE, TILE + 10, d.w - 3 * TILE, TILE + 15), (3 * TILE, d.h - TILE - 16, d.w - 3 * TILE, d.h - TILE - 11),
                             (TILE + 7, 4 * TILE, TILE + 12, d.h - 4 * TILE), (d.w - TILE - 13, 4 * TILE, d.w - TILE - 8, d.h - 4 * TILE)):
        d.stripes(x0, y0, x1, y1, BROWN, OUTLINE, 12)
    for _ in range(26):
        x, y = d.free_spot(16)
        d.crack(x, y, d.rng.uniform(0, 6.28), d.rng.randint(22, 70))
    d.debris(150)
    for _ in range(5):
        x, y = d.free_spot(24)
        d.oil(x, y, d.rng.randint(10, 20), d.rng.randint(7, 13))
    for _ in range(14):  # old rust / dried blood
        x, y = d.free_spot(20)
        d.blob(x, y, d.rng.randint(8, 18), d.rng.randint(6, 12),
               lambda px, py, dd: d.put(px, py, MAROON) if BAYER[py % 4][px % 4] % 2 else None, edge=0.8)
    for (tx, ty) in ((9, 5), (30, 18), (9, 18), (30, 5)):  # drains in symmetric pairs
        d.drain(tx * TILE + 16, ty * TILE + 16)
    d.puddle(330, 330, 30, 17)
    d.puddle(1280 - 330, 768 - 330, 30, 17)
    for _ in range(8):
        x, y = d.free_spot(30)
        d.puddle(x, y, d.rng.randint(14, 28), d.rng.randint(8, 15))
    d.pools(LAMPS_X, LAMPS_Y)

    d.wall_runs(LAMPS_X, LAMPS_Y, YELLOW, 6, (8, 21, 30), (11, 28))
    d.barrel(9 * TILE + 8, d.h - TILE + 9, RED)
    d.barrel(9 * TILE + 24, d.h - TILE + 15, ORANGE)
    d.sandbags(19 * TILE + 8, d.h - TILE + 18)
    d.tyres(30 * TILE, d.h - TILE + 14)
    d.barrel(31 * TILE + 8, 10, ORANGE)
    d.barrel(31 * TILE + 24, 14, RED)
    d.sandbags(16 * TILE + 16, 14)
    d.tyres(3 * TILE, 12)
    for (x, y) in d.top_cells():
        if 0 < x < d.cw - 1 and 0 < y < d.ch - 1 and d.rng.random() < 0.2:
            d.rebar(x * TILE + d.rng.randint(2, 18), y * TILE + 2)
    for (x, y) in d.face_cells():
        if 0 < x < d.cw - 1 and y > 0:
            for _ in range(d.rng.randint(0, 2)):
                d.drips(x * TILE + d.rng.randint(3, 28), y * TILE + 21, d.rng.randint(3, 8), NAVY)
    d.scuffs(d.top_cells(), 0.35, (SHADOW,))
    return d


def foundry(rows: list, ref: Image.Image) -> Deco:
    """Steel foundry: scorched, oily plate with painted lanes, grates, scrap, steam pipes, furnace vents."""
    d = Deco(rows, ref, 11)
    cx, cy = d.w // 2, d.h // 2
    d.mottle(110, 0.0)
    for _ in range(18):  # soot / scorch
        x, y = d.free_spot(20)
        d.blob(x, y, d.rng.randint(18, 40), d.rng.randint(12, 26), lambda px, py, dd: d.shade(px, py, False), edge=0.55)
    for _ in range(4):
        x, y = d.free_spot(24)
        d.oil(x, y, d.rng.randint(12, 24), d.rng.randint(8, 16))
    for _ in range(10):  # rust
        x, y = d.free_spot(16)
        d.blob(x, y, d.rng.randint(8, 16), d.rng.randint(5, 10),
               lambda px, py, dd: d.put(px, py, BROWN) if BAYER[py % 4][px % 4] % 2 else None, edge=0.8)
    for y in (4 * TILE + 16, d.h - 4 * TILE - 17):  # dashed walkway lanes
        for x in range(3 * TILE, d.w - 3 * TILE):
            if (x // 14) % 3 != 2:
                d.put(x, y, BROWN)
                d.put(x, y + 1, BROWN)
    for x in (4 * TILE + 16, d.w - 4 * TILE - 17):
        for y in range(5 * TILE, d.h - 5 * TILE):
            if (y // 14) % 3 != 2:
                d.put(x, y, BROWN)
                d.put(x + 1, y, BROWN)
    d.ring(cx, cy, 120, 118, STEEL_D)
    d.dash_ring(cx, cy, 112, 106, BROWN, SHADOW, 36)
    d.dash_ring(cx, cy, 112, 106, YELLOW, SHADOW, 18, skip=4)
    d.ring(cx, cy, 98, 96, STEEL_D)
    for a in range(4):  # four spokes with arrow heads
        ang = a * math.pi / 2
        ca, sa = math.cos(ang), math.sin(ang)
        for r in range(20, 70):
            d.put(int(cx + ca * r), int(cy + sa * r), STEEL_D)
        for k in range(1, 7):
            for t in (-k, k):
                d.put(int(cx + ca * (70 - k) - sa * t), int(cy + sa * (70 - k) + ca * t), STEEL_D)
    for (tx, ty) in ((3, 9), (36, 14), (11, 4), (28, 19), (19, 20), (20, 3)):
        d.drain(tx * TILE + 16, ty * TILE + 16, 30, 20)
    for _ in range(80):  # scrap, rivets, embers
        x, y = d.free_spot(10)
        for dx, dy, c in ((0, 0, STEEL_D), (1, 0, STEEL), (0, 1, SHADOW), (1, 1, OUTLINE)):
            d.put(x + dx, y + dy, c)
        if d.rng.random() < 0.25:
            d.put(x + 2, y, ORANGE)
    for _ in range(14):
        x, y = d.free_spot(16)
        d.crack(x, y, d.rng.uniform(0, 6.28), d.rng.randint(14, 40), 1)
    d.pools((6, 14, 26, 34), LAMPS_Y)

    d.wall_runs((6, 14, 26, 34), LAMPS_Y, ORANGE, 7, (4, 11, 19, 29, 36), (7, 17, 24, 33))
    d.barrel(14 * TILE + 8, d.h - TILE + 10, RED)
    d.barrel(14 * TILE + 24, d.h - TILE + 16, YELLOW)
    d.tyres(21 * TILE, d.h - TILE + 14)
    d.barrel(24 * TILE + 8, 12, RED)
    d.sandbags(6 * TILE + 16, d.h - TILE + 18)
    d.tyres(28 * TILE, 12)
    for (x, y) in d.face_cells():
        if 0 < x < d.cw - 1 and y > 0:
            for _ in range(d.rng.randint(0, 2)):
                d.drips(x * TILE + d.rng.randint(3, 28), y * TILE + 21, d.rng.randint(3, 8), OUTLINE)
    for (x, y) in d.top_cells():
        if 0 < x < d.cw - 1 and 0 < y < d.ch - 1 and d.rng.random() < 0.08:
            d.rebar(x * TILE + d.rng.randint(2, 18), y * TILE + 2)
    d.scuffs(d.top_cells(), 0.3, (MAROON, OUTLINE))
    return d
