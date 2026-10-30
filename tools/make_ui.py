"""Draws the textures of the user interface into assets/ui/ (RGBA PNG), the way tools/tile_atlas.py draws the tiles:
no downloads, no licences. Everything is meant to look like an object from the kahvehane:

  tile_*        an okey tile as a button (cream bakelite, a visible thickness, raised on hover, pressed down on click)
  sign_*        an enamel shop sign (deep colour, white inner line, rivets, a few chips): titles and panels
  rack_back/front  the wooden okey rack the main menu's tiles stand in
  slip          a paper slip (the event feed)         paper   a sheet of paper (rules, ledger)
  keycap        a key on a keyboard                   switch_*  a switch with a tile-coloured knob
  bar_*         a groove and a felt-green fill        icon_*  simple white icons, tinted in the game

Sizes are for a 1920x1080 design; 9-slice margins are in scripts/ui/kahve_theme.gd.

    python tools/make_ui.py            (needs Pillow and numpy)
"""
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "ui"
rng = np.random.default_rng(1905)

CREAM = np.array([0.93, 0.89, 0.80])
GREEN = np.array([0x0F, 0x3A, 0x2B]) / 255.0
RED = np.array([0xA3, 0x23, 0x1A]) / 255.0
INK = np.array([0x1B, 0x14, 0x10]) / 255.0


# --- helpers -----------------------------------------------------------------------------------------------------

def grid(w, h):
    yy, xx = np.mgrid[0:h, 0:w]
    return xx + 0.5, yy + 0.5


def rrect(w, h, x0, y0, x1, y1, r):
    """Antialiased rounded-rectangle coverage (0..1) of a w x h canvas."""
    xx, yy = grid(w, h)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    qx = np.abs(xx - cx) - ((x1 - x0) / 2 - r)
    qy = np.abs(yy - cy) - ((y1 - y0) / 2 - r)
    d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r
    return np.clip(0.5 - d, 0, 1)


def disc(w, h, cx, cy, radius):
    xx, yy = grid(w, h)
    return np.clip(0.5 - (np.hypot(xx - cx, yy - cy) - radius), 0, 1)


def blur(a, radius):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(img).astype(np.float64) / 255.0


def canvas(w, h):
    return np.zeros((h, w, 4))


def paint(dst, colour, alpha):
    """Source-over of a colour (3-vector or h x w x 3) with an alpha mask onto a premultiplied-free RGBA float canvas."""
    alpha = alpha[..., None] if alpha.ndim == 2 else alpha
    colour = np.broadcast_to(np.asarray(colour, dtype=np.float64), dst.shape[:2] + (3,))
    out_a = alpha[..., 0] + dst[..., 3] * (1 - alpha[..., 0])
    safe = np.where(out_a > 1e-6, out_a, 1.0)[..., None]
    dst[..., :3] = (colour * alpha + dst[..., :3] * dst[..., 3:4] * (1 - alpha)) / safe
    dst[..., 3] = out_a


def vgrad(w, h, top, bottom, y0=0, y1=None):
    y1 = h if y1 is None else y1
    t = np.clip((np.arange(h) + 0.5 - y0) / max(y1 - y0, 1), 0, 1)[:, None, None]
    return np.asarray(top) * (1 - t) + np.asarray(bottom) * t + np.zeros((h, w, 3))


def grain(w, h, amount=0.03, scale=1):
    n = rng.standard_normal((h // scale + 2, w // scale + 2))
    if scale > 1:  # smooth, not blocky
        small = Image.fromarray(n.astype(np.float32), "F").resize((w, h), Image.BICUBIC)
        n = np.asarray(small, dtype=np.float64)
    else:
        n = n[:h, :w]
    return (1.0 + n * amount)[..., None]


def smooth_x(n, k):
    """Blur noise along x only, so it reads as wood grain."""
    pad = np.pad(n, ((0, 0), (k, k)), mode="wrap")
    c = np.cumsum(pad, axis=1)
    return (c[:, 2 * k:] - c[:, :-2 * k]) / (2 * k)


def save(name, a):
    OUT.mkdir(parents=True, exist_ok=True)
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")
    img.save(OUT / name)
    print("wrote", name, img.size)


# --- the tile button ----------------------------------------------------------------------------------------------

def tile_button(name, depth, face_top, face_bottom, side, shadow=0.5, desaturate=0.0, k=1.0):
    """A tile seen from the front: a face, its side below it (`depth`), a soft shadow under it. Every state ends at the
    same base line, so a button does not jump when it rises or sinks. `k` scales the whole drawing (small buttons)."""
    w = h = round(128 * k)
    base = 108 * k
    a = canvas(w, h)
    x0, x1 = 10 * k, 118 * k
    r = 16 * k
    depth = depth * k
    face_bottom_y = base - depth
    face_top_y = face_bottom_y - 84 * k
    # Shadow on the table under the tile.
    sh = blur(rrect(w, h, x0 + 2 * k, face_top_y + 20 * k, x1 - 2 * k, base + 8 * k, r), 7 * k) * shadow
    paint(a, np.zeros(3), sh)
    # The side (thickness): a darker slab from the face's lower edge down to the base.
    side_mask = rrect(w, h, x0, face_top_y + 20 * k, x1, base, r)
    paint(a, vgrad(w, h, side * 1.12, side * 0.78, face_top_y + 40 * k, base), side_mask)
    # The face.
    face_mask = rrect(w, h, x0, face_top_y, x1, face_bottom_y, r)
    face = vgrad(w, h, face_top, face_bottom, face_top_y, face_bottom_y) * grain(w, h, 0.012, 2)
    paint(a, face, face_mask)
    # A bevel: light on the top and left edges, shade on the bottom and right.
    inner = rrect(w, h, x0 + 2.5 * k, face_top_y + 2.5 * k, x1 - 2.5 * k, face_bottom_y - 2.5 * k, r - 2.5 * k)
    ring = np.clip(face_mask - inner, 0, 1)
    xx, yy = grid(w, h)
    light = np.clip(((face_top_y + (face_bottom_y - face_top_y) * 0.55) - yy) / (40.0 * k) + (60 * k - xx) / (200.0 * k), 0, 1)
    paint(a, np.array([1.0, 0.98, 0.93]), ring * light * 0.85)
    paint(a, side * 0.55, ring * (1 - light) * 0.5)
    # A fine engraved line inside the face, as on a real tile (only where it is big enough to read).
    if k >= 0.9:
        line = np.clip(rrect(w, h, x0 + 9, face_top_y + 9, x1 - 9, face_bottom_y - 9, 9)
                       - rrect(w, h, x0 + 10.5, face_top_y + 10.5, x1 - 10.5, face_bottom_y - 10.5, 8), 0, 1)
        paint(a, side * 0.7, line * 0.18)
    if desaturate:
        grey = a[..., :3].mean(axis=2, keepdims=True)
        a[..., :3] = a[..., :3] * (1 - desaturate) + grey * desaturate
    save(name, a)


def tiles():
    side = np.array([0.74, 0.67, 0.52])
    for prefix, k in (("tile_", 1.0), ("tilesm_", 0.6)):
        tile_button(prefix + "normal.png", 10, CREAM * 1.03, CREAM * 0.93, side, k=k)
        tile_button(prefix + "hover.png", 16, np.array([1.0, 0.97, 0.88]), np.array([0.96, 0.91, 0.80]), side * 1.02, 0.6, k=k)
        tile_button(prefix + "pressed.png", 4, CREAM * 0.97, CREAM * 0.87, side * 0.96, 0.3, k=k)
        tile_button(prefix + "disabled.png", 10, CREAM * 0.78, CREAM * 0.72, side * 0.75, 0.35, 0.55, k=k)
        # Keyboard / gamepad focus: a red line round the whole tile, drawn over whatever state it is in.
        n = round(128 * k)
        ring = np.clip(rrect(n, n, 3 * k, 1 * k, 125 * k, 114 * k, 22 * k) - rrect(n, n, 6.5 * k, 4.5 * k, 121.5 * k, 110.5 * k, 19 * k), 0, 1)
        f = canvas(n, n)
        paint(f, np.array([0.82, 0.2, 0.15]), ring)
        save(prefix + "focus.png", f)


# --- enamel signs --------------------------------------------------------------------------------------------------

def sign(name, colour, k=1.0):
    """An enamel sign. `k` scales it (0.5 for the small badges of the HUD)."""
    w = h = round(192 * k)
    a = canvas(w, h)
    paint(a, np.zeros(3), blur(rrect(w, h, 8 * k, 12 * k, w - 8 * k, h - 4 * k, 24 * k), 6 * k) * 0.55)
    outer = rrect(w, h, 6 * k, 4 * k, w - 6 * k, h - 12 * k, 24 * k)
    # The metal rim: light then dark, as the edge of a pressed enamel sheet.
    paint(a, np.array([0.62, 0.66, 0.64]), outer)
    paint(a, np.array([0.28, 0.30, 0.29]), rrect(w, h, 8 * k, 6 * k, w - 8 * k, h - 14 * k, 22 * k))
    body = rrect(w, h, 10 * k, 8 * k, w - 10 * k, h - 16 * k, 20 * k)
    fill = vgrad(w, h, colour * 1.35 + 0.02, colour * 0.85, 8 * k, h - 16 * k) * grain(w, h, 0.018, 3)
    # A faint sheen across the upper half, and a darkening towards the edges.
    xx, yy = grid(w, h)
    fill = fill * (1 - 0.18 * np.clip((np.hypot(xx - w / 2, yy - h / 2) / (130.0 * k)) ** 2, 0, 1)[..., None])
    paint(a, fill, body)
    paint(a, np.ones(3), body * np.clip((60 * k - yy) / (140.0 * k), 0, 1) * 0.08)
    # The white inner line.
    line = np.clip(rrect(w, h, 24 * k, 22 * k, w - 24 * k, h - 30 * k, 12 * k)
                   - rrect(w, h, 28 * k, 26 * k, w - 28 * k, h - 34 * k, 9 * k), 0, 1)
    paint(a, np.array([0.93, 0.91, 0.85]), line)
    # Rivets at the corners.
    for cx, cy in ((22, 20), (192 - 22, 20), (22, 192 - 28), (192 - 22, 192 - 28)):
        cx, cy = cx * k, cy * k
        paint(a, np.array([0.1, 0.1, 0.1]), disc(w, h, cx + 1 * k, cy + 2 * k, 7 * k) * 0.5)
        paint(a, np.array([0.58, 0.60, 0.58]), disc(w, h, cx, cy, 6.5 * k))
        paint(a, np.array([0.85, 0.87, 0.84]), disc(w, h, cx - 1.8 * k, cy - 2 * k, 3.0 * k) * 0.8)
    # Chips in the enamel near the rim, where it would wear first.
    for _ in range(int(26 * k)):
        edge = rng.integers(4)
        t = rng.uniform(14 * k, w - 14 * k)
        cx, cy = [(t, 13 * k), (t, h - 21 * k), (14 * k, t), (w - 14 * k, t)][edge]
        cy = min(cy, h - 21 * k)
        paint(a, np.array([0.7, 0.72, 0.7]), disc(w, h, cx, cy, rng.uniform(0.8, 2.0) * max(k, 0.7)) * 0.8)
    save(name, a)


def signs():
    for suffix, k in (("", 1.0), ("sm", 0.5)):
        sign("sign%s_green.png" % suffix if not suffix else "signsm_green.png", GREEN, k)
        sign("sign_red.png" if not suffix else "signsm_red.png", RED, k)
        sign("sign_dark.png" if not suffix else "signsm_dark.png", np.array([0.14, 0.10, 0.07]), k)


# --- the rack ----------------------------------------------------------------------------------------------------

def wood(w, h, dark, light):
    n = smooth_x(rng.standard_normal((h, w)), 40) * 1.6 + smooth_x(rng.standard_normal((h, w)), 6) * 0.5
    n = (n - n.min()) / (n.max() - n.min())
    return (np.asarray(dark) * (1 - n[..., None]) + np.asarray(light) * n[..., None])


def rack():
    w, h = 512, 200
    a = canvas(w, h)
    body = rrect(w, h, 0, 24, w, h - 6, 12)
    paint(a, wood(w, h, [0.17, 0.10, 0.06], [0.33, 0.21, 0.12]) * vgrad(w, h, [1.15] * 3, [0.8] * 3, 24, h), body)
    # The top edge catches the light.
    xx, yy = grid(w, h)
    paint(a, np.array([0.8, 0.6, 0.38]), body * np.clip((30 - yy) / 6.0, 0, 1) * np.clip((yy - 24) / 1.0, 0, 1) * 0.6)
    save("rack_back.png", a)

    w, h = 512, 92
    a = canvas(w, h)
    # A soft shadow on what stands behind it.
    sh = np.clip((22 - np.abs(np.arange(h) - 20)) / 22.0, 0, 1)[:, None] * np.ones((h, w))
    paint(a, np.zeros(3), sh * (np.arange(h)[:, None] < 22) * 0.45)
    lip = rrect(w, h, 0, 20, w, h - 4, 12)
    paint(a, wood(w, h, [0.2, 0.12, 0.07], [0.38, 0.24, 0.14]) * vgrad(w, h, [1.2] * 3, [0.78] * 3, 20, h), lip)
    xx, yy = grid(w, h)
    paint(a, np.array([0.85, 0.65, 0.42]), lip * np.clip((27 - yy) / 7.0, 0, 1) * 0.55)
    save("rack_front.png", a)


# --- paper, slips, keys, switches, bars ------------------------------------------------------------------------

def paper(name, w, h, tone, shadow, dog_ear=False):
    a = canvas(w, h)
    paint(a, np.zeros(3), blur(rrect(w, h, 14, 18, w - 12, h - 8, 6), 8) * shadow)
    body = rrect(w, h, 10, 8, w - 10, h - 14, 5)
    fibre = grain(w, h, 0.02, 1) * grain(w, h, 0.015, 6)
    xx, yy = grid(w, h)
    edge = np.clip(np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)) ** 3, 0, 1)[..., None]
    paint(a, np.asarray(tone) * fibre * (1 - 0.07 * edge), body)
    if dog_ear:
        corner = (xx > w - 40) & (yy < 40) & ((xx - (w - 40)) > (40 - yy))
        paint(a, np.zeros(3), body * corner)
        tri = (xx > w - 40) & (yy < 40) & ((xx - (w - 40)) < (40 - yy)) & ((xx - (w - 40)) + (40 - yy) > 38 - 0)
    save(name, a)


def keycap():
    w = h = 64
    a = canvas(w, h)
    paint(a, np.zeros(3), blur(rrect(w, h, 4, 8, w - 4, h - 2, 12), 3) * 0.6)
    paint(a, np.array([0.12, 0.11, 0.12]), rrect(w, h, 3, 3, w - 3, h - 8, 12))
    paint(a, vgrad(w, h, [0.30, 0.29, 0.31], [0.20, 0.19, 0.21], 5, h - 14), rrect(w, h, 6, 5, w - 6, h - 13, 9))
    xx, yy = grid(w, h)
    paint(a, np.ones(3), rrect(w, h, 6, 5, w - 6, h - 13, 9) * np.clip((14 - yy) / 8.0, 0, 1) * 0.10)
    save("keycap.png", a)


def switches():
    w, h = 112, 64
    for name, groove, glow in (("switch_off.png", [0.12, 0.08, 0.05], 0.0), ("switch_on.png", [0.10, 0.45, 0.28], 1.0)):
        a = canvas(w, h)
        paint(a, np.array([0.7, 0.55, 0.4]), rrect(w, h, 2, 4, w - 2, h - 2, 28) * 0.5)
        track = rrect(w, h, 3, 3, w - 3, h - 4, 28)
        paint(a, vgrad(w, h, np.array(groove) * 0.55, np.array(groove) * 1.1, 3, h - 4), track)
        xx, yy = grid(w, h)
        paint(a, np.zeros(3), track * np.clip((14 - yy) / 11.0, 0, 1) * 0.5)  # an inner shadow on top
        if glow:
            paint(a, np.array([0.6, 1.0, 0.75]), track * np.clip((yy - 40) / 20.0, 0, 1) * 0.18)
        save(name, a)
    w = h = 56
    a = canvas(w, h)
    paint(a, np.zeros(3), blur(disc(w, h, 28, 33, 21), 3) * 0.6)
    paint(a, np.array([0.70, 0.62, 0.46]), disc(w, h, 28, 30, 22))
    paint(a, vgrad(w, h, CREAM * 1.05, CREAM * 0.9, 8, 48), disc(w, h, 28, 27, 21))
    paint(a, np.ones(3), disc(w, h, 22, 20, 9) * 0.25)
    save("switch_knob.png", a)


def bars():
    w, h = 256, 36
    a = canvas(w, h)
    paint(a, np.array([0.7, 0.55, 0.4]), rrect(w, h, 0, 4, w, h, 17) * 0.4)
    groove = rrect(w, h, 1, 2, w - 1, h - 3, 16)
    paint(a, vgrad(w, h, [0.06, 0.04, 0.03], [0.16, 0.11, 0.08], 2, h - 3), groove)
    save("bar_groove.png", a)
    a = canvas(w, h)
    fill = rrect(w, h, 3, 4, w - 3, h - 5, 13)
    paint(a, vgrad(w, h, [0.22, 0.62, 0.40], [0.08, 0.34, 0.20], 4, h - 5) * grain(w, h, 0.02, 2), fill)
    xx, yy = grid(w, h)
    paint(a, np.ones(3), fill * np.clip((13 - yy) / 7.0, 0, 1) * 0.25)
    save("bar_fill.png", a)


# --- icons ------------------------------------------------------------------------------------------------------

def icon(name, draw, size=64):
    ss = 4
    img = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw(d, size * ss)
    img = img.resize((size, size), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / name)
    print("wrote", name, img.size)


def tile_shape(d, s, x, y, w, h, fill=(255, 255, 255, 255)):
    d.rounded_rectangle([x * s, y * s, (x + w) * s, (y + h) * s], radius=0.14 * w * s, fill=fill)


def icons():
    white = (255, 255, 255, 255)
    clear = (0, 0, 0, 0)

    def sets(d, s):  # three tiles rising: a seri
        for i, (x, y) in enumerate(((0.06, 0.40), (0.35, 0.28), (0.64, 0.16))):
            tile_shape(d, s, x, y, 0.30, 0.48)

    def pairs(d, s):  # two pairs
        for x in (0.10, 0.36):
            tile_shape(d, s, x, 0.12, 0.22, 0.34)
            tile_shape(d, s, x + 0.04, 0.54, 0.22, 0.34)

    def colour(d, s):  # the four tile colours as dots
        for cx, cy in ((0.30, 0.30), (0.70, 0.30), (0.30, 0.70), (0.70, 0.70)):
            d.ellipse([(cx - 0.17) * s, (cy - 0.17) * s, (cx + 0.17) * s, (cy + 0.17) * s], fill=white)

    def number(d, s):  # 1 2 3 as three bars of growing height
        for i, hgt in enumerate((0.30, 0.52, 0.74)):
            d.rounded_rectangle([(0.12 + i * 0.28) * s, (0.88 - hgt) * s, (0.32 + i * 0.28) * s, 0.88 * s], radius=0.04 * s, fill=white)

    def check(d, s):
        d.line([(0.18 * s, 0.54 * s), (0.42 * s, 0.76 * s), (0.82 * s, 0.26 * s)], fill=white, width=int(0.14 * s), joint="curve")

    def lock(d, s):
        d.rounded_rectangle([0.22 * s, 0.44 * s, 0.78 * s, 0.88 * s], radius=0.08 * s, fill=white)
        d.arc([0.30 * s, 0.12 * s, 0.70 * s, 0.62 * s], 180, 360, fill=white, width=int(0.09 * s))
        d.ellipse([0.44 * s, 0.56 * s, 0.56 * s, 0.68 * s], fill=clear)

    def hand(d, s):  # an open hand: four fingers, a palm and a thumb
        for x, top in ((0.22, 0.20), (0.38, 0.08), (0.54, 0.12), (0.70, 0.26)):
            d.rounded_rectangle([x * s, top * s, (x + 0.12) * s, 0.62 * s], radius=0.06 * s, fill=white)
        d.rounded_rectangle([0.22 * s, 0.44 * s, 0.82 * s, 0.90 * s], radius=0.16 * s, fill=white)
        d.polygon([(0.24 * s, 0.56 * s), (0.04 * s, 0.40 * s), (0.10 * s, 0.30 * s), (0.34 * s, 0.50 * s)], fill=white)

    def minus(d, s):
        d.rounded_rectangle([0.18 * s, 0.42 * s, 0.82 * s, 0.58 * s], radius=0.08 * s, fill=white)

    def plus(d, s):
        minus(d, s)
        d.rounded_rectangle([0.42 * s, 0.18 * s, 0.58 * s, 0.82 * s], radius=0.08 * s, fill=white)

    def reset(d, s):  # a turning arrow
        d.arc([0.16 * s, 0.16 * s, 0.84 * s, 0.84 * s], 40, 330, fill=white, width=int(0.12 * s))
        d.polygon([(0.62 * s, 0.10 * s), (0.92 * s, 0.30 * s), (0.58 * s, 0.40 * s)], fill=white)

    def close(d, s):
        d.line([(0.22 * s, 0.22 * s), (0.78 * s, 0.78 * s)], fill=white, width=int(0.13 * s))
        d.line([(0.78 * s, 0.22 * s), (0.22 * s, 0.78 * s)], fill=white, width=int(0.13 * s))

    def search(d, s):
        d.ellipse([0.14 * s, 0.14 * s, 0.60 * s, 0.60 * s], outline=white, width=int(0.10 * s))
        d.line([(0.54 * s, 0.54 * s), (0.86 * s, 0.86 * s)], fill=white, width=int(0.12 * s))

    def eye(d, s):
        d.ellipse([0.08 * s, 0.26 * s, 0.92 * s, 0.74 * s], fill=white)
        d.ellipse([0.36 * s, 0.34 * s, 0.64 * s, 0.66 * s], fill=clear)
        d.ellipse([0.43 * s, 0.41 * s, 0.57 * s, 0.55 * s], fill=white)

    for name, fn in (("sets", sets), ("pairs", pairs), ("color", colour), ("number", number), ("check", check), ("lock", lock),
                     ("hand", hand), ("minus", minus), ("plus", plus), ("reset", reset), ("close", close), ("search", search),
                     ("eye", eye)):
        icon("icon_%s.png" % name, fn)


def main():
    tiles()
    signs()
    rack()
    paper("slip.png", 192, 112, [0.95, 0.92, 0.84], 0.5, dog_ear=False)
    paper("paper.png", 256, 256, [0.94, 0.90, 0.80], 0.55)
    keycap()
    switches()
    bars()
    icons()


main()
