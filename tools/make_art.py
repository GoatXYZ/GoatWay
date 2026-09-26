"""Draw every GoatWay texture in the GoatQuest style.

GoatQuest's look: flat ink and slate surfaces, 1px hairlines, square corners,
no bevels, and one accent colour (GoatQuest gold #F5BF29, or the class colour
in the world). Waypoint UI's atlases are redrawn here at the same pixel
coordinates, so the UV rectangles in the Lua definitions stay valid.

Parts the game tints (the marker stroke, beam, chevrons, map pins) are drawn
white on transparent, with dark underlays that stay dark when multiplied by
the tint. Panels and controls are drawn in their final colours.

    py -3 tools/make_art.py            # writes the textures
    py -3 tools/make_art.py --preview  # also writes design/*.png previews

Textures are written as uncompressed BLP2 (BGRA, no mipmaps), the same format
Waypoint UI shipped, so every path in the code is unchanged.
"""
import math
import os
import struct
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, "Art", "Fonts")
SS = 4  # supersampling factor

# ---------------------------------------------------------------------------
# GoatQuest palette (Skins/Default/GoatQuest/Style.lua and Styles/Viewer.lua)
# ---------------------------------------------------------------------------
INK = (15, 17, 21)
SLATE = (21, 24, 29)
RIDGE = (27, 31, 37)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
TEXT = (236, 234, 230)
SOFT = (197, 200, 205)
MUTED = (141, 147, 156)
DIM = (111, 117, 126)
GOLD = (245, 191, 41)
GOLD_HOVER = (247, 204, 83)
GOLD_PRESS = (214, 164, 30)
# Quest kinds, tuned to sit next to the gold on ink.
BLUE = (122, 178, 235)
LILAC = (205, 160, 240)
ORANGE = (240, 150, 70)


# ---------------------------------------------------------------------------
# Canvas and masks
# ---------------------------------------------------------------------------
class Canvas:
    """RGBA drawing surface, supersampled; coordinates are in final texels."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

    def mask(self):
        return Image.new("L", self.img.size, 0)

    def paint(self, mask, rgb, alpha=1.0):
        layer = Image.new("RGBA", self.img.size, rgb + (0,))
        layer.putalpha(mask.point(lambda v: int(round(v * alpha))))
        self.img = Image.alpha_composite(self.img, layer)
        return self

    def fill(self, rgb, alpha=1.0):
        return self.paint(Image.new("L", self.img.size, 255), rgb, alpha)

    def result(self):
        # Premultiply before averaging so transparent texels do not bleed black.
        return self.img.convert("RGBa").resize((self.w, self.h), Image.BOX).convert("RGBA")


def S(v):
    return v * SS


def rect(m, x0, y0, x1, y1):
    ImageDraw.Draw(m).rectangle((S(x0), S(y0), S(x1) - 1, S(y1) - 1), fill=255)
    return m


def frame(m, x0, y0, x1, y1, t):
    """A rectangular ring t texels thick, inside the given bounds."""
    rect(m, x0, y0, x1, y1)
    inner = Image.new("L", m.size, 0)
    rect(inner, x0 + t, y0 + t, x1 - t, y1 - t)
    return ImageChops.subtract(m, inner)


def poly(m, pts):
    ImageDraw.Draw(m).polygon([(S(x), S(y)) for x, y in pts], fill=255)
    return m


def ellipse(m, cx, cy, rx, ry=None):
    ry = rx if ry is None else ry
    ImageDraw.Draw(m).ellipse((S(cx - rx), S(cy - ry), S(cx + rx), S(cy + ry)), fill=255)
    return m


def ring(m, cx, cy, r, t):
    ellipse(m, cx, cy, r)
    inner = Image.new("L", m.size, 0)
    ellipse(inner, cx, cy, r - t)
    return ImageChops.subtract(m, inner)


def diamond_pts(cx, cy, r):
    return [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]


def diamond(m, cx, cy, r):
    return poly(m, diamond_pts(cx, cy, r))


def diamond_ring(m, cx, cy, r, t):
    """Diamond outline whose stroke is t texels thick, measured square to the edge."""
    diamond(m, cx, cy, r)
    inner = Image.new("L", m.size, 0)
    diamond(inner, cx, cy, r - t * math.sqrt(2))
    return ImageChops.subtract(m, inner)


def stroke(m, pts, width, closed=False, round_caps=True):
    seq = [(S(x), S(y)) for x, y in pts]
    if closed:
        seq = seq + [seq[0]]
    d = ImageDraw.Draw(m)
    d.line(seq, fill=255, width=int(round(S(width))), joint="curve")
    if round_caps:
        r = S(width) / 2
        for x, y in seq:
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    return m


def arc(m, cx, cy, r, width, start, end, steps=64):
    pts = []
    for i in range(steps + 1):
        a = math.radians(start + (end - start) * i / steps)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return stroke(m, pts, width)


def grow(m, t):
    """Dilate a mask by roughly t texels."""
    size = int(S(t)) * 2 + 1
    return m.filter(ImageFilter.MaxFilter(size if size % 2 else size + 1))


def blur(m, t):
    return m.filter(ImageFilter.GaussianBlur(S(t)))


def union(*masks):
    out = masks[0]
    for m in masks[1:]:
        out = ImageChops.lighter(out, m)
    return out


def minus(a, b):
    return ImageChops.subtract(a, b)


def scale_mask(m, factor):
    return m.point(lambda v: int(v * factor))


def font(name, px):
    return ImageFont.truetype(os.path.join(FONTS, name), int(S(px)))


def glyph(m, text, cx, cy, px, face="AtkinsonHyperlegible-Bold.ttf"):
    ImageDraw.Draw(m).text((S(cx), S(cy)), text, font=font(face, px), fill=255, anchor="mm")
    return m


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
def save_blp(img, relpath):
    """Uncompressed BLP2: BGRA texels, no palette, one mip level."""
    img = img.convert("RGBA")
    w, h = img.size
    data = img.tobytes("raw", "BGRA")
    header = b"BLP2" + struct.pack("<IBBBB", 1, 3, 8, 8, 0) + struct.pack("<II", w, h)
    header += struct.pack("<16I", 1172, *([0] * 15))
    header += struct.pack("<16I", len(data), *([0] * 15))
    header += b"\0" * 1024
    path = os.path.join(ROOT, relpath)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(header + data)
    return img


def read_blp(path):
    """Decoder for the uncompressed BLP2 files this script writes (used by the tests)."""
    with open(path, "rb") as f:
        d = f.read()
    assert d[:4] == b"BLP2"
    _, enc, _, _, _ = struct.unpack("<IBBBB", d[4:12])
    w, h = struct.unpack("<II", d[12:20])
    off = struct.unpack("<I", d[20:24])[0]
    size = struct.unpack("<I", d[84:88])[0]
    assert enc == 3, "only uncompressed BLP2 is supported"
    return Image.frombytes("RGBA", (w, h), d[off:off + size], "raw", "BGRA")


class Atlas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def put(self, x, y, canvas_or_img):
        img = canvas_or_img.result() if isinstance(canvas_or_img, Canvas) else canvas_or_img
        self.img.paste(img, (x, y))


# ---------------------------------------------------------------------------
# Shared shapes
# ---------------------------------------------------------------------------
def chevron_mask(c, cx, tip_y, w, h, notch):
    """GoatQuest's filled chevron (Styles/Textures/chevron.tga), pointing up."""
    m = c.mask()
    return poly(m, [(cx, tip_y), (cx + w / 2, tip_y + h), (cx, tip_y + h - notch), (cx - w / 2, tip_y + h)])


def vchev_mask(c, cx, cy, w, h, t, down=True):
    """GoatQuest's stroke chevron (vchev.tga)."""
    m = c.mask()
    if down:
        pts = [(cx - w / 2, cy - h / 2), (cx, cy + h / 2), (cx + w / 2, cy - h / 2)]
    else:
        pts = [(cx - w / 2, cy + h / 2), (cx, cy - h / 2), (cx + w / 2, cy + h / 2)]
    return stroke(m, pts, t)


def tinted_with_underlay(c, shape, spread, soft, alpha=0.6):
    """White shape over a dark, slightly soft underlay, for tinted art."""
    c.paint(blur(grow(shape, spread), soft), BLACK, alpha)
    c.paint(shape, WHITE)


def goat_masks():
    """The goat head from GoatQuest's icon: (full-colour image, silhouette mask)."""
    src = Image.open(os.path.join(ROOT, "tools", "goat-mark-source.png")).convert("RGBA")
    px = src.load()
    w, h = src.size
    body = Image.new("L", src.size, 0)
    lit = Image.new("L", src.size, 0)
    bp, lp = body.load(), lit.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            chroma = max(r, g, b) - min(r, g, b)
            # The tile is a neutral near-black; the goat and its brown detail lines are warm.
            bp[x, y] = max(0, min(255, (chroma - 14) * 8))
            # The silhouette keeps the gold and drops the brown lines, so the
            # features (eyes, nose, ear insides) survive as cut-outs.
            lp[x, y] = max(0, min(255, (max(r, g, b) - 125) * 5)) if chroma > 40 else 0
    bbox = body.getbbox()
    colour = src.copy()
    colour.putalpha(body)
    return colour.crop(bbox), lit.crop(bbox)


def fit(img, box_w, box_h):
    w, h = img.size
    k = min(box_w / w, box_h / h)
    return img.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)


# ---------------------------------------------------------------------------
# Art/Waypoint/Waypoint: the in-world marker, beam, pinpoint and navigator
# ---------------------------------------------------------------------------
def waypoint_atlas():
    atlas = Atlas(1024, 1024)

    # Pinpoint card: ink at 94% with a hairline. Nine-slice inset 32 at scale
    # 0.25, so 4 texels are one screen unit. The accent rule along its top is
    # a separate tinted frame (Waypoint_UI.lua).
    c = Canvas(256, 128)
    c.fill(INK, 0.94)
    c.paint(frame(c.mask(), 0, 0, 256, 128, 4), WHITE, 0.10)
    atlas.put(0, 0, c)

    # Pinpoint arrow: one of three stroke chevrons that flow down to the spot.
    c = Canvas(128, 128)
    tinted_with_underlay(c, vchev_mask(c, 64, 60, 60, 30, 16), 7, 3, 0.55)
    atlas.put(256, 0, c)

    # Context icon, diamond: ink fill, white stroke (tinted to the accent) and
    # a dark keyline so it holds on bright ground. Shown at 32 to 44 units.
    c = Canvas(128, 128)
    c.paint(diamond(c.mask(), 64, 64, 63), BLACK, 0.55)
    c.paint(diamond(c.mask(), 64, 64, 59), INK, 0.92)
    c.paint(diamond_ring(c.mask(), 64, 64, 59, 7), WHITE)
    atlas.put(0, 128, c)

    # Context icon, circle.
    c = Canvas(128, 128)
    c.paint(ellipse(c.mask(), 64, 64, 62), BLACK, 0.55)
    c.paint(ellipse(c.mask(), 64, 64, 58), INK, 0.92)
    c.paint(ring(c.mask(), 64, 64, 58, 7), WHITE)
    atlas.put(0, 256, c)

    # Wave ring (unused by the current code; kept so the region is not empty).
    c = Canvas(128, 128)
    c.paint(ring(c.mask(), 64, 64, 58, 3), WHITE)
    atlas.put(128, 256, c)

    # Navigator arrow: GoatQuest's flat chevron at the top of the cell, so it
    # orbits the context icon as the texture rotates. Shown at 58 units.
    c = Canvas(128, 128)
    tinted_with_underlay(c, chevron_mask(c, 64, 5, 30, 26, 7), 2.5, 1.5, 0.7)
    atlas.put(0, 384, c)

    # Beam: a narrow line of light, strongest at the marker and gone at the
    # top. 3 texels per unit across (150 texels for 50 units). Drawn additive.
    c = Canvas(150, 1024)
    col = Image.new("L", (1, c.img.size[1]))
    for y in range(c.img.size[1]):
        t = y / (c.img.size[1] - 1)
        col.putpixel((0, y), int(255 * (t ** 1.6)))
    fade = col.resize(c.img.size)
    core = rect(c.mask(), 69, 0, 81, 1024)
    soft = blur(rect(c.mask(), 63, 0, 87, 1024), 6)
    c.paint(ImageChops.multiply(soft, fade), WHITE, 0.28)
    c.paint(ImageChops.multiply(core, fade), WHITE)
    atlas.put(693, 0, c)

    # Beam glint: a thin bright core that the moving mask reveals as a pulse.
    c = Canvas(128, 1024)
    c.paint(blur(rect(c.mask(), 58, 0, 70, 1024), 3), WHITE, 0.35)
    c.paint(rect(c.mask(), 62, 0, 66, 1024), WHITE, 0.9)
    atlas.put(896, 0, c)

    return save_blp(atlas.img, "Art/Waypoint/Waypoint.blp")


# ---------------------------------------------------------------------------
# Art/MapPinFrame/MapPinFrame: world map and minimap pins (tinted)
# ---------------------------------------------------------------------------
def mappin_atlas():
    atlas = Atlas(256, 128)

    def diamond_pin(highlight):
        c = Canvas(64, 64)
        c.paint(diamond(c.mask(), 32, 32, 31), BLACK, 0.5)
        c.paint(diamond(c.mask(), 32, 32, 28), INK, 0.92)
        if highlight:
            c.paint(diamond(c.mask(), 32, 32, 28), WHITE, 0.12)
        c.paint(diamond_ring(c.mask(), 32, 32, 28, 6.5 if highlight else 4.5), WHITE)
        return c

    def circle_pin(highlight):
        c = Canvas(64, 64)
        c.paint(ellipse(c.mask(), 32, 32, 30), BLACK, 0.5)
        c.paint(ellipse(c.mask(), 32, 32, 27), INK, 0.92)
        if highlight:
            c.paint(ellipse(c.mask(), 32, 32, 27), WHITE, 0.12)
        c.paint(ring(c.mask(), 32, 32, 27, 6.5 if highlight else 4.5), WHITE)
        return c

    atlas.put(0, 0, diamond_pin(False))
    atlas.put(64, 0, diamond_pin(True))
    atlas.put(128, 0, circle_pin(False))
    atlas.put(192, 0, circle_pin(True))

    # "Glow" is a flat selection ring; the code shows it scaled 1.5x behind the pin.
    c = Canvas(64, 64)
    c.paint(diamond_ring(c.mask(), 32, 32, 27, 2.5), WHITE, 0.9)
    atlas.put(0, 64, c)
    c = Canvas(64, 64)
    c.paint(ring(c.mask(), 32, 32, 26, 2.5), WHITE, 0.9)
    atlas.put(128, 64, c)

    # Minimap pins: a solid tinted mark with a dark keyline.
    c = Canvas(64, 64)
    c.paint(diamond(c.mask(), 32, 32, 26), BLACK, 0.8)
    c.paint(diamond(c.mask(), 32, 32, 21), WHITE)
    atlas.put(64, 64, c)
    c = Canvas(64, 64)
    c.paint(ellipse(c.mask(), 32, 32, 24), BLACK, 0.8)
    c.paint(ellipse(c.mask(), 32, 32, 19), WHITE)
    atlas.put(192, 64, c)

    return save_blp(atlas.img, "Art/MapPinFrame/MapPinFrame.blp")


# ---------------------------------------------------------------------------
# Art/Icons: quest glyphs, pin icons and the GoatWay mark
# ---------------------------------------------------------------------------
QUEST_KIND = {
    # kind: (colour, frame)
    "": (GOLD, None),
    "Campaign": (GOLD, "shield"),
    "Important": (LILAC, "triangle"),
    "Legendary": (ORANGE, "hexagon"),
    "Artifact": (ORANGE, None),
    "Calling": (BLUE, "shield"),
    "Meta": (GOLD, "octagon"),
    "Recurring": (BLUE, "cycle"),
    "Weekly": (BLUE, "circle"),
    "Repeatable": (BLUE, None),
}


def kind_frame(c, shape):
    m = c.mask()
    if shape == "shield":
        stroke(m, [(13, 9), (51, 9), (51, 33), (32, 56), (13, 33)], 4, closed=True)
    elif shape == "triangle":
        stroke(m, [(9, 11), (55, 11), (32, 56)], 4, closed=True)
    elif shape == "hexagon":
        pts = [(32 + 24 * math.cos(math.radians(a)), 32 + 24 * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
        stroke(m, pts, 4, closed=True)
    elif shape == "octagon":
        pts = [(32 + 24 * math.cos(math.radians(a)), 32 + 24 * math.sin(math.radians(a))) for a in range(-112, 248, 45)]
        stroke(m, pts, 4, closed=True)
    elif shape == "circle":
        m = ring(m, 32, 32, 25, 4)
    elif shape == "cycle":
        arc(m, 32, 32, 22, 4, -60, 225)
        poly(m, [(32 + 22 * math.cos(math.radians(-60)) + 7, 32 + 22 * math.sin(math.radians(-60)) + 3),
                 (32 + 22 * math.cos(math.radians(-60)) - 5, 32 + 22 * math.sin(math.radians(-60)) - 9),
                 (32 + 22 * math.cos(math.radians(-60)) - 6, 32 + 22 * math.sin(math.radians(-60)) + 7)])
    return m


def quest_icon(status, kind):
    colour, shape = QUEST_KIND[kind]
    if status == "Incomplete":
        colour = SOFT
    text = "!" if status == "Available" else "?"
    c = Canvas(64, 64)
    frame_mask = kind_frame(c, shape) if shape else c.mask()
    g = glyph(c.mask(), text, 32, 33 if shape else 32, 34 if shape else 58)
    ink = union(frame_mask, g)
    c.paint(blur(grow(ink, 3), 1), BLACK, 0.85)
    c.paint(frame_mask, colour)
    c.paint(g, colour)
    return c


def icon_with_keyline(shape_fn, spread=3):
    c = Canvas(64, 64)
    m = shape_fn(c)
    c.paint(blur(grow(m, spread), 1), BLACK, 0.8)
    c.paint(m, WHITE)
    return c


def map_pin_shape(c):
    # GoatQuest's location pin: a teardrop with a hole.
    m = c.mask()
    ellipse(m, 32, 25, 17)
    poly(m, [(17.5, 32), (46.5, 32), (32, 58)])
    return minus(m, ellipse(c.mask(), 32, 25, 7))


def navigation_shape(c):
    return chevron_mask(c, 32, 8, 38, 46, 12)


def redirect_shape(c):
    m = c.mask()
    arc(m, 34, 36, 16, 6, 180, 330)
    tip = (34 + 16 * math.cos(math.radians(330)), 36 + 16 * math.sin(math.radians(330)))
    poly(m, [(tip[0] + 9, tip[1] + 8), (tip[0] - 1, tip[1] - 12), (tip[0] - 12, tip[1] + 4)])
    stroke(m, [(18, 36), (18, 52)], 6)
    return m


def tomtom_shape(c):
    m = chevron_mask(c, 32, 6, 34, 30, 9)
    stroke(m, [(32, 30), (32, 56)], 7, round_caps=False)
    return m


def star_shape(c):
    pts = []
    for i in range(8):
        r = 26 if i % 2 == 0 else 8
        a = math.radians(-90 + i * 45)
        pts.append((32 + r * math.cos(a), 32 + r * math.sin(a)))
    return poly(c.mask(), pts)


def logo_images():
    colour, lit = goat_masks()

    def mark(size, mode):
        c = Canvas(size, size)
        k = size / 128
        if mode == "colour":
            # GoatQuest's dark tile, a hairline, and the gold waypoint diamond.
            m = c.mask()
            ImageDraw.Draw(m).rounded_rectangle((S(4 * k), S(4 * k), S(124 * k) - 1, S(124 * k) - 1), radius=S(26 * k), fill=255)
            c.paint(m, (20, 21, 24))
        img = c.result()
        goat = colour if mode == "colour" else lit
        head = fit(goat, int(92 * k), int(86 * k))
        if mode != "colour":
            tint = Image.new("RGBA", head.size, WHITE + (0,) if mode == "white" else BLACK + (0,))
            tint.putalpha(head if head.mode == "L" else head.getchannel("A"))
            head = tint
        img.alpha_composite(head, (int((size - head.size[0]) / 2), int(10 * k)))
        # Waypoint diamond badge under the chin: ink keyline, gold fill.
        b = Canvas(size, size)
        cx, cy, r = 98 * k, 100 * k, 18 * k
        b.paint(diamond(b.mask(), cx, cy, r + 5 * k), (20, 21, 24) if mode == "colour" else BLACK, 1.0 if mode == "colour" else 0.0)
        if mode == "colour":
            b.paint(diamond(b.mask(), cx, cy, r), GOLD)
            b.paint(diamond(b.mask(), cx, cy, r * 0.42), (20, 21, 24))
        else:
            fg = WHITE if mode == "white" else BLACK
            b.paint(diamond_ring(b.mask(), cx, cy, r, 5 * k), fg)
            b.paint(diamond(b.mask(), cx, cy, r * 0.36), fg)
        img.alpha_composite(b.result())
        return img

    return mark(128, "colour"), mark(128, "white"), mark(128, "black"), lit


def icons():
    out = {}
    for status in ("Available", "Complete", "Incomplete"):
        for kind in QUEST_KIND:
            name = f"{status}{kind}Quest"
            out[name] = save_blp(quest_icon(status, kind).result(), f"Art/Icons/{name}.blp")
    out["MapPin"] = save_blp(icon_with_keyline(map_pin_shape).result(), "Art/Icons/MapPin.blp")
    out["Navigation"] = save_blp(icon_with_keyline(navigation_shape).result(), "Art/Icons/Navigation.blp")
    out["Redirect"] = save_blp(icon_with_keyline(redirect_shape).result(), "Art/Icons/Redirect.blp")
    out["TomTomArrow"] = save_blp(icon_with_keyline(tomtom_shape).result(), "Art/Icons/TomTomArrow.blp")
    out["VignetteElite"] = save_blp(icon_with_keyline(star_shape).result(), "Art/Icons/VignetteElite.blp")

    # Chat separator shown inline with /way help.
    c = Canvas(256, 256)
    c.paint(stroke(c.mask(), [(128, 40), (128, 216)], 18), MUTED)
    out["Pipe"] = save_blp(c.result(), "Art/Icons/Pipe.blp")

    logo, logo_white, logo_black, lit = logo_images()
    out["Logo"] = save_blp(logo, "Art/Icons/Logo.blp")
    out["Logo-White"] = save_blp(logo_white, "Art/Icons/Logo-White.blp")
    out["Logo-Black"] = save_blp(logo_black, "Art/Icons/Logo-Black.blp")

    # GoatQuest waypoints: the goat in white so the marker can tint it.
    c = Canvas(64, 64)
    head = fit(lit, 56, 56)
    m = Image.new("L", (64 * SS, 64 * SS), 0)
    big = head.resize((head.size[0] * SS, head.size[1] * SS), Image.LANCZOS)
    m.paste(big, ((64 * SS - big.size[0]) // 2, (64 * SS - big.size[1]) // 2))
    c.paint(blur(grow(m, 2), 1), BLACK, 0.8)
    c.paint(m, WHITE)
    out["GoatQuest"] = save_blp(c.result(), "Art/Icons/GoatQuest.blp")
    return out


# ---------------------------------------------------------------------------
# Art/Settings: tabs, containers and the row highlight
# ---------------------------------------------------------------------------
def settings_art():
    # Tabs: nine-slice inset 16 at scale 0.6. Selected tabs carry a gold bar
    # on the left edge (inside the left slice, so it never stretches sideways).
    atlas = Atlas(256, 128)

    def tab(fill_alpha, selected):
        c = Canvas(64, 64)
        c.fill(WHITE, fill_alpha)
        if selected:
            c.paint(rect(c.mask(), 0, 0, 4, 64), GOLD)
        return c

    atlas.put(0, 0, tab(0.06, False))    # highlighted
    atlas.put(64, 0, tab(0.035, False))  # pushed
    atlas.put(0, 64, tab(0.08, True))    # selected
    atlas.put(64, 64, tab(0.11, True))   # selected, highlighted
    atlas.put(128, 64, tab(0.065, True))  # selected, pushed
    save_blp(atlas.img, "Art/Settings/TabButton.blp")

    # Containers: nine-slice inset 18 at scale 1, so the hairline is one texel.
    atlas = Atlas(128, 64)
    c = Canvas(64, 64)
    c.fill(WHITE, 0.03)
    c.paint(frame(c.mask(), 0, 0, 64, 64, 1), WHITE, 0.07)
    atlas.put(0, 0, c)
    c = Canvas(64, 64)
    c.fill(WHITE, 0.025)
    c.paint(frame(c.mask(), 0, 0, 64, 64, 1), WHITE, 0.05)
    atlas.put(64, 0, c)
    save_blp(atlas.img, "Art/Settings/Widget-Container.blp")

    # Row highlight: flat white at 5%.
    c = Canvas(64, 64)
    c.fill(WHITE, 0.05)
    save_blp(c.result(), "Art/Settings/Widget-Background.blp")

    # Item slot frame (tinted by item quality): a square keyline.
    c = Canvas(64, 64)
    c.paint(frame(c.mask(), 4, 4, 60, 60, 4), WHITE)
    c.paint(frame(c.mask(), 8, 8, 56, 56, 1.5), BLACK, 0.6)
    save_blp(c.result(), "Art/Shared/ItemSlot.blp")


# ---------------------------------------------------------------------------
# packages/uic-common/resources/common: buttons, inputs, checks, sliders,
# scroll bars, menus and prompts. Same coordinates as Waypoint UI's atlas.
# ---------------------------------------------------------------------------
def flat_box(w, h, fill, fill_alpha, edge, edge_alpha, t):
    c = Canvas(w, h)
    c.fill(fill, fill_alpha)
    if edge_alpha:
        c.paint(frame(c.mask(), 0, 0, w, h, t), edge, edge_alpha)
    return c


def common_atlas():
    atlas = Atlas(512, 512)
    T = 1.5  # one unit at the buttons' 0.7 slice scale

    # Neutral buttons: white fill and edge over the dark settings ground.
    for x, fa, ea in ((7, 0.08, 0.12), (106, 0.14, 0.22), (205, 0.11, 0.18), (304, 0.04, 0.07)):
        atlas.put(x, 7, flat_box(93, 41, WHITE, fa, WHITE, ea, T))
    for x, fa, ea in ((7, 0.08, 0.12), (54, 0.14, 0.22), (101, 0.11, 0.18), (148, 0.04, 0.07)):
        atlas.put(x, 101, flat_box(41, 41, WHITE, fa, WHITE, ea, T))

    # Primary buttons ("red" in the code): GoatQuest gold, ink text.
    for x, fill in ((7, GOLD), (106, GOLD_HOVER), (205, GOLD_PRESS)):
        atlas.put(x, 54, flat_box(93, 41, fill, 1, fill, 0, T))
    atlas.put(304, 54, flat_box(93, 41, WHITE, 0.04, WHITE, 0.07, T))
    for x, fill in ((7, GOLD), (54, GOLD_HOVER), (101, GOLD_PRESS)):
        atlas.put(x, 148, flat_box(41, 41, fill, 1, fill, 0, T))
    atlas.put(148, 148, flat_box(41, 41, WHITE, 0.04, WHITE, 0.07, T))

    # Check buttons, 47px cells shown at 25 units: a 1-unit box; checked is a
    # gold fill with an ink check (GoatQuest's checkradio-flat).
    def check(x, checked, enabled):
        c = Canvas(47, 47)
        box = rect(c.mask(), 6, 6, 41, 41)
        if checked:
            c.paint(box, GOLD if enabled else DIM, 1 if enabled else 0.6)
            c.paint(stroke(c.mask(), [(14, 24), (21, 31), (34, 16)], 4.5), INK)
        else:
            c.paint(box, INK, 0.7)
            c.paint(frame(c.mask(), 6, 6, 41, 41, 2), WHITE, 0.24 if enabled else 0.1)
        atlas.put(x, 192, c)

    check(4, False, True)
    check(51, True, True)
    check(98, False, False)
    check(145, True, False)

    # Text and colour inputs: ink well with an edge.
    atlas.put(7, 242, flat_box(93, 41, INK, 0.85, WHITE, 0.14, T))
    atlas.put(106, 242, flat_box(93, 41, INK, 0.5, WHITE, 0.06, T))
    # Colour swatch fills (tinted with the chosen colour), stretched over the input.
    for x, inset, alpha in ((202, 5, 1), (292, 7, 1), (382, 5, 0.3)):
        c = Canvas(90, 39)
        c.paint(rect(c.mask(), inset, inset, 90 - inset, 39 - inset), WHITE, alpha)
        atlas.put(x, 243, c)

    # Prompt: ridge panel at 97%, hairline, gold rule along the top.
    c = Canvas(42, 42)
    c.fill(RIDGE, 0.97)
    c.paint(frame(c.mask(), 0, 0, 42, 42, 1), WHITE, 0.12)
    c.paint(rect(c.mask(), 0, 0, 42, 2), GOLD)
    atlas.put(4, 330, c)

    # Slider thumbs: a gold disc with an ink keyline (GoatQuest radio).
    for x, fill in ((92, GOLD), (128, GOLD_HOVER), (164, TEXT), (200, DIM)):
        c = Canvas(36, 36)
        c.paint(ellipse(c.mask(), 18, 18, 14.5), INK, 0.9)
        c.paint(ellipse(c.mask(), 18, 18, 11.5), fill)
        atlas.put(x, 376, c)

    # Slider track: a 2-unit line; the nine-slice squeezes the cell around it.
    c = Canvas(54, 25)
    c.paint(rect(c.mask(), 4, 11, 50, 14), WHITE, 0.16)
    atlas.put(90, 474, c)

    # Stepper arrows (the cells overlap by 2px, so glyphs stay inside the middle).
    for i, colour in enumerate((MUTED, TEXT, GOLD, DIM)):
        alpha = 0.6 if colour == DIM else 1
        c = Canvas(25, 25)
        c.paint(stroke(c.mask(), [(15, 7), (9.5, 12.5), (15, 18)], 3), colour, alpha)
        atlas.put(92 + i * 23, 415, c)
        c = Canvas(25, 25)
        c.paint(stroke(c.mask(), [(10, 7), (15.5, 12.5), (10, 18)], 3), colour, alpha)
        atlas.put(90 + i * 23, 446, c)

    # Scroll bar: faint track, thin flat thumb.
    c = Canvas(12, 121)
    c.fill(WHITE, 0.05)
    atlas.put(78, 378, c)
    for x, alpha in ((4, 0.2), (28, 0.32), (52, 0.45)):
        c = Canvas(24, 125)
        c.paint(rect(c.mask(), 7, 4, 17, 121), WHITE, alpha)
        atlas.put(x, 376, c)

    # Selection menu panel: same inner rectangle as before (25,14)-(103,54)
    # of a 127x94 cell, with a soft shadow in the margin.
    c = Canvas(127, 94)
    c.paint(blur(rect(c.mask(), 25, 18, 103, 60), 6), BLACK, 0.45)
    c.paint(rect(c.mask(), 25, 14, 103, 54), RIDGE)
    c.paint(frame(c.mask(), 25, 14, 103, 54, 1.2), WHITE, 0.12)
    atlas.put(192, 98, c)

    # Menu row highlight (coloured in code).
    c = Canvas(32, 16)
    c.fill(WHITE)
    atlas.put(401, 102, c)

    # Scroll edge fades in the menu colour: top fade is opaque at the top.
    for x, top_opaque in ((321, True), (361, False)):
        c = Canvas(32, 32)
        grad = Image.new("L", (1, 32 * SS))
        for y in range(32 * SS):
            t = y / (32 * SS - 1)
            grad.putpixel((0, y), int(255 * ((1 - t) if top_opaque else t)))
        c.paint(grad.resize(c.img.size), RIDGE)
        atlas.put(x, 102, c)

    # Menu scroll arrow (points up) in three states.
    for x, colour in ((319, MUTED), (349, TEXT), (380, GOLD)):
        c = Canvas(26, 26)
        c.paint(vchev_mask(c, 13, 13, 12, 6, 2.8, down=False), colour)
        atlas.put(x, 137, c)

    # Close (drawn on gold, so ink) and the dropdown button's up/down glyph.
    c = Canvas(25, 26)
    m = stroke(c.mask(), [(7, 7), (18, 18)], 3)
    stroke(m, [(18, 7), (7, 18)], 3)
    c.paint(m, INK)
    atlas.put(319, 185, c)
    c = Canvas(25, 26)
    m = union(vchev_mask(c, 12.5, 8.5, 11, 5, 2.6, down=False), vchev_mask(c, 12.5, 17.5, 11, 5, 2.6, down=True))
    c.paint(m, SOFT)
    atlas.put(345, 186, c)

    return save_blp(atlas.img, "packages/uic-common/resources/common.blp")


# ---------------------------------------------------------------------------
# Previews
# ---------------------------------------------------------------------------
def preview(results):
    out = os.path.join(ROOT, "design")
    os.makedirs(out, exist_ok=True)

    def on(bg, img, scale=1):
        img = img.resize((int(img.size[0] * scale), int(img.size[1] * scale)), Image.LANCZOS)
        base = Image.new("RGBA", img.size, bg + (255,))
        base.alpha_composite(img)
        return base

    # Every icon on ink, at 2x.
    names = sorted(results["icons"])
    cols = 8
    cell = 136
    sheet = Image.new("RGBA", (cols * cell, ((len(names) + cols - 1) // cols) * (cell + 18)), INK + (255,))
    d = ImageDraw.Draw(sheet)
    small = font("Archivo-Regular.ttf", 2.6)
    for i, n in enumerate(names):
        img = results["icons"][n]
        k = 96 / max(img.size)
        x, y = (i % cols) * cell + 20, (i // cols) * (cell + 18) + 10
        sheet.alpha_composite(img.resize((int(img.size[0] * k), int(img.size[1] * k)), Image.LANCZOS), (x, y))
        d.text((x - 12, y + 102), n, font=small, fill=MUTED)
    sheet.save(os.path.join(out, "icons.png"))

    # Atlases on a mid grey so white and ink parts both show.
    for key, bg in (("waypoint", (78, 84, 90)), ("mappin", (78, 84, 90)), ("common", SLATE)):
        on(bg, results[key], 2 if key == "mappin" else 1).save(os.path.join(out, f"atlas-{key}.png"))


def main():
    results = {
        "waypoint": waypoint_atlas(),
        "mappin": mappin_atlas(),
        "icons": icons(),
        "common": common_atlas(),
    }
    settings_art()
    if "--preview" in sys.argv:
        preview(results)
    print("GoatWay art written.")


if __name__ == "__main__":
    main()
