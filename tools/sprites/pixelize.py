"""Illustration -> clean pixel art (style POC, scratchpad only; never shipped).
Line-art aware: anime lines survive the downscale instead of averaging into mush."""
import sys
from PIL import Image, ImageFilter, ImageEnhance, ImageChops

def pixelize(src, width, colors):
    im = (src if isinstance(src, Image.Image) else Image.open(src)).convert("RGB")
    im = ImageEnhance.Color(im).enhance(1.2)
    k = im.width / width                       # source px per art px
    h = round(im.height / k)
    gray = im.convert("L")
    local = gray.filter(ImageFilter.BoxBlur(max(2, int(k))))
    # line mask: clearly darker than the neighbourhood
    line = ImageChops.subtract(local, gray).point(lambda v: 255 if v > 28 else 0)
    frac = line.resize((width, h), Image.BOX)  # share of each art px that is line
    soft = im.resize((width, h), Image.BOX)
    ink = im.filter(ImageFilter.MinFilter(3 if k < 6 else 5)).resize((width, h), Image.BOX)
    ink = ImageEnhance.Brightness(ink).enhance(0.6)
    mixed = Image.composite(ink, soft, frac.point(lambda v: 255 if v > 50 else 0))
    q = mixed.quantize(colors, method=Image.Quantize.MEDIANCUT, kmeans=3, dither=Image.Dither.NONE)
    return q.convert("RGB")

if __name__ == "__main__":
    out_path = sys.argv[1]
    rows = []
    for src in sys.argv[2:]:
        tiles = [pixelize(src, w, c) for w, c in ((40, 16), (48, 20), (60, 24))]
        rows.append([t.resize((384, round(t.height * 384 / t.width)), Image.NEAREST) for t in tiles])
    sheet = Image.new("RGB", (384 * 3 + 16, sum(r[0].height for r in rows) + 8 * len(rows)), (20, 18, 30))
    y = 0
    for r in rows:
        for i, t in enumerate(r):
            sheet.paste(t, (i * (384 + 8), y))
        y += r[0].height + 8
    sheet.save(out_path)
