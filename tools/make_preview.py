"""Render design/preview.png: GoatWay's look, composed from its real textures
and fonts. Left: the world (marker and beam, pinpoint card, halo, edge
arrow). Right: the settings window.

    py -3 tools/make_preview.py

A mock-up for reviewing the design outside the game; layout and sizes follow
the Lua (Waypoint_UI.lua, Halo.lua, Settings_UI.lua) at a UI scale of 1.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

import make_art

ROOT = make_art.ROOT
OUT = os.path.join(ROOT, "design", "preview.png")
FONTS = make_art.FONTS

INK, SLATE, RIDGE = (15, 17, 21), (21, 24, 29), (27, 31, 37)
TEXT, SOFT, MUTED, DIM = (236, 234, 230), (197, 200, 205), (141, 147, 156), (111, 117, 126)
GOLD = (245, 191, 41)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def tint(img, rgb, alpha=1.0):
    r, g, b, a = img.split()
    out = Image.merge("RGBA", (
        r.point(lambda v: v * rgb[0] // 255),
        g.point(lambda v: v * rgb[1] // 255),
        b.point(lambda v: v * rgb[2] // 255),
        a.point(lambda v: int(v * alpha)),
    ))
    return out


def crop(atlas, box, size=None):
    img = atlas.crop(box)
    if size:
        img = img.resize(size, Image.LANCZOS)
    return img


def paste(base, img, center):
    base.alpha_composite(img, (int(center[0] - img.size[0] / 2), int(center[1] - img.size[1] / 2)))


def add(base, img, center):
    """Additive blend, as the beam is drawn."""
    x0, y0 = int(center[0] - img.size[0] / 2), int(center[1] - img.size[1] / 2)
    region = base.crop((x0, y0, x0 + img.size[0], y0 + img.size[1])).convert("RGB")
    a = img.getchannel("A")
    glow = Image.composite(img.convert("RGB"), Image.new("RGB", img.size, (0, 0, 0)), a)
    from PIL import ImageChops
    base.paste(ImageChops.add(region, glow), (x0, y0))


def text(draw, xy, s, f, fill, anchor="la", shadow=True):
    if shadow:
        draw.text((xy[0] + 1, xy[1] + 1), s, font=f, fill=(0, 0, 0, 230), anchor=anchor)
    draw.text(xy, s, font=f, fill=fill, anchor=anchor)


def world(w, h):
    # Dusk sky over rolling ground, softly blurred like a distant scene.
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    horizon = int(h * 0.46)
    for y in range(h):
        if y < horizon:
            t = y / horizon
            c = (int(58 + 70 * t), int(86 + 60 * t), int(120 + 40 * t))
        else:
            t = (y - horizon) / (h - horizon)
            c = (int(92 - 40 * t), int(112 - 50 * t), int(64 - 30 * t))
        d.line([(0, y), (w, y)], fill=c + (255,))
    hills = Image.new("L", (w, h), 0)
    hd = ImageDraw.Draw(hills)
    pts = [(0, horizon + 30)] + [(x, horizon + 12 * math.sin(x / 90) + 8 * math.sin(x / 37)) for x in range(0, w + 20, 20)] + [(w, h), (0, h)]
    hd.polygon(pts, fill=255)
    img.paste((70, 88, 52, 255), (0, 0), hills.filter(ImageFilter.GaussianBlur(3)))
    for i in range(40):
        x = (i * 173) % w
        y = horizon + 60 + (i * 97) % (h - horizon - 60)
        r = 18 + (i * 7) % 26
        d.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6), fill=(48 + i % 20, 64 + i % 24, 40, 255))
    return img.filter(ImageFilter.GaussianBlur(1.2))


def scene():
    W, H = 1100, 720
    img = world(W, H)
    d = ImageDraw.Draw(img)
    wp = make_art.read_blp(os.path.join(ROOT, "Art/Waypoint/Waypoint.blp"))

    # Marker, far away: Complete quest, accent gold. Waypoint frame 46 at scale 1.
    cx, cy = 360, 300
    beam = tint(crop(wp, (693, 0, 843, 1024), (50, 340)), GOLD)
    add(img, beam, (cx, cy - 25 - 170))
    fx = tint(crop(wp, (896, 0, 1024, 1024), (50, 340)), GOLD)
    fxmask = Image.new("L", fx.size, 0)
    ImageDraw.Draw(fxmask).rectangle((0, 150, 50, 200), fill=255)
    fx.putalpha(Image.composite(fx.getchannel("A"), Image.new("L", fx.size, 0), fxmask.filter(ImageFilter.GaussianBlur(14))))
    add(img, fx, (cx, cy - 25 - 170))
    paste(img, tint(crop(wp, (0, 128, 128, 256), (34, 34)), GOLD), (cx, cy))
    icon = make_art.read_blp(os.path.join(ROOT, "Art/Icons/CompleteQuest.blp")).resize((15, 15), Image.LANCZOS)
    paste(img, icon, (cx, cy))
    d = ImageDraw.Draw(img)
    text(d, (cx, cy + 22), "Hope Is a Fragile Thing", font("Archivo-SemiBold.ttf", 12), TEXT, "mt")
    text(d, (cx, cy + 38), "412 yds", font("ArchivoNarrow-SemiBold.ttf", 12), GOLD, "mt")
    text(d, (cx, cy + 53), "0:48", font("ArchivoNarrow-SemiBold.ttf", 12), MUTED, "mt")

    # Pinpoint, close by: GoatQuest waypoint (the goat), accent class colour.
    accent = (64, 199, 235)
    px, py = 760, 250
    lines = [("Kill Defias Trappers", TEXT), ("Westfall · 9/15", MUTED)]
    f = font("Archivo-Regular.ttf", 13)
    tw = max(d.textlength(s, font=f) for s, _ in lines)
    cw, ch = int(tw + 26), 52
    x0, y0 = px - cw // 2, py
    d.rectangle((x0, y0, x0 + cw, y0 + ch), fill=INK + (240,), outline=(255, 255, 255, 26))
    d.rectangle((x0, y0, x0 + cw, y0 + 1), fill=accent + (255,))
    for i, (s, c) in enumerate(lines):
        text(d, (x0 + 13, y0 + 11 + i * 17), s, f, c, shadow=False)
    paste(img, tint(crop(wp, (0, 128, 128, 256), (44, 44)), accent), (px, py - 34))
    goat = make_art.read_blp(os.path.join(ROOT, "Art/Icons/GoatQuest.blp")).resize((20, 20), Image.LANCZOS)
    paste(img, tint(goat, accent), (px, py - 34))
    chev = tint(crop(wp, (256, 0, 384, 128), (15, 15)), accent)
    for i, a in enumerate((1, 0.7, 0.4)):
        paste(img, tint(chev, (255, 255, 255), a), (px, py + ch + 14 + i * 10))

    # Halo at the character's feet, notch toward the marker (ahead-left).
    ring_img = Image.open(os.path.join(ROOT, "Art/Halo/ring.tga")).convert("RGBA").resize((280, 70), Image.LANCZOS)
    shadow = Image.open(os.path.join(ROOT, "Art/Halo/ring-shadow.tga")).convert("RGBA").resize((280, 70), Image.LANCZOS)
    hx, hy = 550, 560
    paste(img, tint(shadow, (255, 255, 255), 0.8), (hx, hy))
    paste(img, tint(ring_img, (247, 245, 240), 0.62), (hx, hy))
    rx, ry = 280 * (250 - 2.25) / 512, 70 * (58 - 2.25) / 128
    angle = 0.55
    dot = Image.open(os.path.join(ROOT, "Art/Halo/dot.tga")).convert("RGBA")
    vchev = Image.open(os.path.join(ROOT, "Art/Halo/vchev.tga")).convert("RGBA")
    for k in range(-4, 5):
        t = angle + k * 5 / math.hypot(rx * math.cos(angle), ry * math.sin(angle))
        x, y = -math.sin(t) * rx, math.cos(t) * ry
        paste(img, tint(dot.resize((10, 10)), (0, 0, 0), 0.55), (hx + x, hy - y))
        paste(img, tint(dot.resize((6, 6)), GOLD), (hx + x, hy - y))
    s, c = math.sin(angle), math.cos(angle)
    nx, ny = -s / rx, c / ry
    n = math.hypot(nx, ny)
    nx, ny = nx / n, ny / n
    px0, py0 = -s * rx, c * ry
    rot = math.degrees(math.atan2(ny, nx) - math.pi / 2)
    for off, a in ((12, 1), (24, 0.75)):
        ch_img = vchev.resize((24, 24)).rotate(rot, resample=Image.BICUBIC, expand=True)
        paste(img, tint(ch_img, (0, 0, 0), 0.6), (hx + px0 + nx * off, hy - (py0 + ny * off)))
        paste(img, tint(ch_img, GOLD, a), (hx + px0 + nx * off, hy - (py0 + ny * off)))
    d = ImageDraw.Draw(img)
    tx, ty = hx + px0 + nx * 44, hy - (py0 + ny * 44)
    fnt = font("AtkinsonHyperlegible-Bold.ttf", 16)
    for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)):
        d.text((tx + ox, ty + oy), "412 yds", font=fnt, fill=(0, 0, 0, 255), anchor="mm")
    d.text((tx, ty), "412 yds", font=fnt, fill=(255, 255, 255, 255), anchor="mm")

    # Edge arrow for a destination off to the right.
    ex, ey = W - 60, 420
    arrow = tint(crop(wp, (0, 384, 128, 512), (58, 58)), GOLD).rotate(-90, resample=Image.BICUBIC)
    paste(img, tint(crop(wp, (0, 128, 128, 256), (32, 32)), GOLD), (ex, ey))
    paste(img, make_art.read_blp(os.path.join(ROOT, "Art/Icons/Navigation.blp")).resize((13, 13), Image.LANCZOS), (ex, ey))
    paste(img, arrow, (ex, ey))

    d = ImageDraw.Draw(img)
    text(d, (24, 22), "In the world", font("Archivo-SemiBold.ttf", 15), TEXT)
    text(d, (24, 42), "Marker and beam, pinpoint card, Halo navigator, edge arrow", font("Archivo-Regular.ttf", 12), SOFT)
    return img


def settings():
    W, H = 760, 560
    img = Image.new("RGBA", (W, H), SLATE + (255,))
    d = ImageDraw.Draw(img)
    side = 212
    d.rectangle((0, 0, side, H), fill=INK + (255,))
    d.line([(side, 0), (side, H)], fill=(35, 37, 41, 255))
    d.rectangle((0, 0, W, 1), fill=GOLD + (255,))
    logo = make_art.read_blp(os.path.join(ROOT, "Art/Icons/Logo.blp")).resize((34, 34), Image.LANCZOS)
    img.alpha_composite(logo, (18, 17))
    text(d, (60, 18), "GoatWay", font("Archivo-SemiBold.ttf", 16), TEXT, shadow=False)
    text(d, (60, 38), "1.0.0", font("Archivo-Regular.ttf", 11), MUTED, shadow=False)
    tabs = ["General", "Waypoint", "Map", "Navigation", "Appearance", "Audio", "Extensions"]
    f12 = font("Archivo-Regular.ttf", 12)
    for i, name in enumerate(tabs):
        y = 76 + i * 38
        if name == "Waypoint":
            d.rectangle((12, y, side - 12, y + 30), fill=(35, 37, 41, 255))
            d.rectangle((12, y, 14, y + 30), fill=GOLD + (255,))
        text(d, (26, y + 15), name, f12, TEXT if name == "Waypoint" else MUTED, "lm", shadow=False)
    text(d, (26, H - 40), "About", f12, MUTED, "lm", shadow=False)

    x0 = side + 24
    text(d, (x0, 26), "Navigator", font("Archivo-SemiBold.ttf", 14), TEXT, shadow=False)
    d.rectangle((x0 - 6, 50, W - 30, 340), fill=(26, 29, 34, 255), outline=(40, 43, 48, 255))

    def row(y, title, desc=None, indent=0):
        text(d, (x0 + 10 + indent, y), title, f12, TEXT, shadow=False)
        if desc:
            text(d, (x0 + 10 + indent, y + 17), desc, font("Archivo-Regular.ttf", 11), MUTED, shadow=False)

    def check(y, on):
        bx = W - 70
        if on:
            d.rectangle((bx, y - 2, bx + 18, y + 16), fill=GOLD + (255,))
            d.line([(bx + 4, y + 7), (bx + 8, y + 11), (bx + 14, y + 3)], fill=INK + (255,), width=3)
        else:
            d.rectangle((bx, y - 2, bx + 18, y + 16), fill=(20, 22, 26, 255), outline=(70, 72, 76, 255))

    def dropdown(y, label):
        bx = W - 200
        d.rectangle((bx, y - 4, W - 52, y + 18), fill=(37, 40, 45, 255), outline=(52, 55, 60, 255))
        text(d, (bx + 10, y + 7), label, f12, SOFT, "lm", shadow=False)
        d.line([(W - 70, y + 3), (W - 66, y), (W - 62, y + 3)], fill=SOFT + (255,), width=2)
        d.line([(W - 70, y + 9), (W - 66, y + 12), (W - 62, y + 9)], fill=SOFT + (255,), width=2)

    row(66, "Show", "Shows the Navigator when the destination is off-screen.")
    check(66, True)
    row(116, "Style", "Arrow at the screen edge, or GoatQuest's Halo.", 15)
    dropdown(118, "Halo")
    row(166, "Use GoatQuest's Ring Position", "Puts the ring where you placed GoatQuest's halo.", 30)
    check(166, True)
    row(216, "Accent", "Match GoatQuest uses the GoatQuest viewer's accent.")
    dropdown(218, "Match GoatQuest")
    row(266, "Size")
    tx0, tx1 = W - 250, W - 90
    text(d, (tx0 - 12, 272), "100%", font("Archivo-Regular.ttf", 11), SOFT, "rm", shadow=False)
    d.rectangle((tx0, 271, tx1, 273), fill=(60, 63, 68, 255))
    d.ellipse((tx0 + 70, 264, tx0 + 86, 280), fill=INK + (255,))
    d.ellipse((tx0 + 72, 266, tx0 + 84, 278), fill=GOLD + (255,))
    d.rectangle((W - 200, 300, W - 52, 326), fill=GOLD + (255,))
    text(d, ((W - 200 + W - 52) / 2, 313), "Reset All Settings", f12, INK, "mm", shadow=False)

    # A GoatQuest dialog: ridge panel, gold rule, gold primary and neutral secondary.
    px, py, pw, ph = x0 + 40, 380, 400, 130
    d.rectangle((px + 4, py + 6, px + pw + 4, py + ph + 6), fill=(0, 0, 0, 90))
    d.rectangle((px, py, px + pw, py + ph), fill=RIDGE + (255,), outline=(52, 55, 60, 255))
    d.rectangle((px, py, px + pw, py + 1), fill=GOLD + (255,))
    msg = ["Do you want to replace your current waypoint", "with GoatQuest's waypoint \"Kill Defias Trappers\"?"]
    for i, s in enumerate(msg):
        text(d, (px + pw / 2, py + 30 + i * 18), s, f12, TEXT, "mm", shadow=False)
    d.rectangle((px + 70, py + 80, px + 190, py + 105), fill=GOLD + (255,))
    text(d, (px + 130, py + 92), "Replace", f12, INK, "mm", shadow=False)
    d.rectangle((px + 210, py + 80, px + 330, py + 105), fill=(40, 43, 48, 255), outline=(60, 63, 68, 255))
    text(d, (px + 270, py + 92), "Cancel", f12, SOFT, "mm", shadow=False)
    return img


def main():
    left, right = scene(), settings()
    pad = 24
    out = Image.new("RGBA", (left.size[0] + right.size[0] + pad * 3, max(left.size[1], right.size[1]) + pad * 2 + 40), (10, 11, 14, 255))
    d = ImageDraw.Draw(out)
    d.text((pad, 18), "GoatWay: in-world waypoints in the GoatQuest look", font=font("Archivo-SemiBold.ttf", 18), fill=TEXT)
    out.alpha_composite(left, (pad, pad + 40))
    out.alpha_composite(right, (left.size[0] + pad * 2, pad + 40))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.convert("RGB").save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
