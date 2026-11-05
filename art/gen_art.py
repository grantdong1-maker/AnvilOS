#!/usr/bin/env python3
"""Generate GrantOS anvil branding art: wallpapers + logo (Pillow only)."""
from PIL import Image, ImageDraw, ImageFilter
import math, os

OUT = "/home/grant/Downloads/forge-linux/art"
os.makedirs(OUT, exist_ok=True)

FACETS = {
    "topface": (186, 190, 194),
    "horn":    (126, 132, 138),
    "body":    (150, 155, 161),
    "side":    (108, 114, 121),
    "base":    (140, 145, 152),
    "stepsh":  (86, 92, 100),
}

def bg_gradient(size, top=(46, 51, 55), center=(56, 62, 66), bottom=(36, 40, 44), vignette=0.55):
    """Smooth vertical gradient + radial vignette, built small then upscaled."""
    w, h = size
    gw, gh = 64, 36
    g = Image.new("RGB", (gw, gh))
    px = g.load()
    cx, cy = gw / 2, gh * 0.42
    maxd = math.hypot(cx, cy) + 0.001
    for y in range(gh):
        for x in range(gw):
            t = y / (gh - 1)
            r = int(top[0] + (bottom[0] - top[0]) * t)
            gg = int(top[1] + (bottom[1] - top[1]) * t)
            b = int(top[2] + (bottom[2] - top[2]) * t)
            d = math.hypot(x - cx, y - cy) / maxd
            ring = max(0.0, d - (1 - vignette)) / vignette if vignette > 0 else 0
            ring = min(1.0, ring) * 0.35
            # subtle center lift
            lift = max(0.0, 1.0 - d) * 0.10
            px[x, y] = (
                int(r * (1 - ring) + center[0] * lift),
                int(gg * (1 - ring) + center[1] * lift),
                int(b * (1 - ring) + center[2] * lift),
            )
    return g.resize(size, Image.BILINEAR)

def anvil_layers(canvas, scale=1.0, ox=0, oy=0, single=(150, 155, 161), ember=False):
    """Return list of (polygon, color, blur) draw items for the anvil."""
    S = lambda pts: [(int((x + ox) * scale), int((y + oy) * scale)) for x, y in pts]
    W = int(canvas[0] / scale if False else 1)
    items = []
    body = single or FACETS["body"]

    # ---- side-profile silhouette (horn left) ----
    body_outline = S([
        (150, 350),   # horn tip
        (1258, 330),  # top face right
        (1258, 418),  # right edge
        (1060, 440),  # step toward waist
        (948, 660),   # body right taper
        (652, 660),   # body left taper
        (612, 440),   # left step
    ])
    items.append((body_outline, FACETS["body"], 0))

    # right-side shading overlay (darker right half of the body)
    items.append((S([
        (920, 336), (1258, 334), (1258, 418), (1060, 440), (948, 655), (920, 440),
    ]), FACETS["side"], 0))

    # top-face sliver
    items.append((S([
        (150, 350), (1258, 328), (1258, 344), (176, 362),
    ]), FACETS["topface"], 0))

    # under-horn step shadow
    items.append((S([
        (150, 350), (612, 440), (560, 470), (176, 372),
    ]), FACETS["stepsh"], 0))

    # pedestal (waist -> base top)
    items.append((S([
        (700, 655), (900, 655), (930, 745), (670, 745),
    ]), FACETS["base"], 0))
    items.append((S([
        (800, 700), (930, 745), (930, 748), (800, 748),
    ]), FACETS["side"], 0))

    # base slab with side shading
    items.append((S([
        (556, 742), (1044, 742), (1104, 830), (496, 830),
    ]), FACETS["base"], 0))
    items.append((S([
        (760, 742), (1044, 742), (1104, 830), (840, 830),
    ]), FACETS["side"], 0))

    # top-view small quench hole
    items.append((S([
        (1010, 348), (1108, 346), (1114, 386), (1016, 388),
    ]), FACETS["side"], 0))

    if ember:
        # ember glow beneath the anvil base
        gx, gy = int(800 * scale + ox * 0 + (2048 / 2 - 800) * 0)+140, 0
        glow = Image.new("RGB", canvas, (0, 0, 0))
        gd = ImageDraw.Draw(glow)
        cx = int(0.5 * canvas[0]); cy = int(0.905 * canvas[1])
        for rr in range(9, 0, -1):
            alpha = int(255 / 9 * (10 - rr) / 9 * 1.4)
            gd.ellipse([cx - rr * 90, cy - rr * 26, cx + rr * 90, cy + rr * 26],
                       fill=(alpha, alpha // 3, 0))
        glow = glow.filter(ImageFilter.GaussianBlur(28))
        items.append(("__glow__", glow, 0))
    return items

def composite(items, base, mode="lighten"):
    img = base
    for poly, color, blur in items:
        if poly == "__glow__":
            lay = Image.new("L", img.size, 0)
            lay.paste(color.split()[0], (0, 0))
            lay = Image.eval(lay, lambda v: v)
            lay = lay.point(lambda v: v)
            warm = Image.new("RGB", img.size, (212, 122, 52))
            mask = color.split()[1] if False else None
            # use glow image itself as the warm layer via screen blend
            arr = Image.blend(img, warm, 0)
            from PIL import ImageChops
            scr = ImageChops.screen(img, color)
            img = Image.blend(img, scr, 0.85)
            continue
        layer = Image.new("RGB", img.size, color)
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        if blur:
            mask = mask.filter(ImageFilter.GaussianBlur(blur))
        img = Image.composite(layer, img, mask)
    return img

def wallpaper(kind, path, size=(1920, 1080)):
    bg = bg_gradient(size)
    scale = size[0] / 1600.0
    ox = size[0] / 2 / scale - 800  # center horizontally
    oy = 0.52 * size[1] / scale - 560  # center vertically
    items = anvil_layers((size[0], size[1]), scale=scale, ox=ox, oy=oy,
                         ember=(kind == "ember"))
    img = composite(items, bg)
    # remove stray warm placeholder if any
    img.save(path)
    print("saved", path)

# wallpaper A: minimal (faithful to user's reference)
wallpaper("minimal", f"{OUT}/wallpaper-anvil-minimal.png")
# wallpaper B: ember variant
wallpaper("ember", f"{OUT}/wallpaper-anvil-ember.png")

# ---- logo (transparent) ----
lg = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
d = ImageDraw.Draw(lg)
sc = 512 / 1600
ox, oy = 40, 40
S = lambda pts: [(int((x + ox) * sc), int((y + oy) * sc)) for x, y in pts]
d.polygon(S([(150, 350), (1258, 330), (1258, 418), (1060, 440), (948, 660),
             (652, 660), (612, 440)]), fill=(70, 76, 82, 255))
d.polygon(S([(150, 350), (1258, 328), (1258, 344), (176, 362)]),
          fill=(196, 200, 204, 255))
d.polygon(S([(700, 655), (900, 655), (930, 745), (670, 745)]),
          fill=(90, 96, 103, 255))
d.polygon(S([(556, 742), (1044, 742), (1104, 830), (496, 830)]),
          fill=(120, 126, 134, 255))
# ember accent sliver on base
d.polygon(S([(556, 742), (620, 742), (620, 830), (496, 830)]),
          fill=(214, 122, 52, 255))
lg.save(f"{OUT}/logo.png")
print("saved", f"{OUT}/logo.png")

# preview sheet: side-by-side thumbnails for review
th = []
for p in [f"{OUT}/wallpaper-anvil-minimal.png", f"{OUT}/wallpaper-anvil-ember.png", f"{OUT}/logo.png"]:
    im = Image.open(p).convert("RGB")
    im.thumbnail((640, 640))
    th.append(im)
sheet = Image.new("RGB", (sum(t.width for t in th) + 20 * (len(th) + 1), max(t.height for t in th) + 20), (24, 26, 28))
xx = 20
for t in th:
    sheet.paste(t, (xx, 20)); xx += t.width + 20
sheet.save(f"{OUT}/preview-sheet.png")
print("saved", f"{OUT}/preview-sheet.png")
