#!/usr/bin/env python3
"""Generate the Programma 101 application icon.

Draws a stylised Olivetti Programma 101 (cream body, printer tape, keyboard
and magnetic card) at high resolution, then writes the macOS .iconset and
converts it to Resources/AppIcon.icns with iconutil.

Requires Pillow. Run from anywhere:

    python3 Tools/generate_icon.py
"""
import os
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Resources")
ICONSET = os.path.join(RES, "AppIcon.iconset")
ICNS = os.path.join(RES, "AppIcon.icns")
PREVIEW = os.path.join(RES, "AppIcon-1024.png")

S = 2  # supersampling factor (draw at 2048, downsample to 1024)
SIZE = 1024
W = SIZE * S

FONT_DIR = "/System/Library/Fonts/Supplemental"
FUTURA = os.path.join(FONT_DIR, "Futura.ttc")
COURIER_BOLD = os.path.join(FONT_DIR, "Courier New Bold.ttf")

CREAM_TOP = (248, 242, 227)
CREAM_BOTTOM = (214, 203, 181)
DECK_TOP = (252, 247, 235)
DECK_BOTTOM = (232, 222, 201)
INK = (34, 32, 28)
RED = (211, 66, 43)


def sc(v):
    return int(round(v * S))


def box(b):
    return tuple(sc(v) for v in b)


def font(path, size, index=0):
    return ImageFont.truetype(path, sc(size), index=index)


def drop_shadow(base, b, radius, blur=18, dy=14, color=(0, 0, 0, 120)):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box(b)
    d.rounded_rectangle((x0, y0 + sc(dy), x1, y1 + sc(dy)), sc(radius), fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(sc(blur)))
    base.alpha_composite(layer)


def vertical_gradient(top, bottom, width, height):
    img = Image.new("RGBA", (width, height))
    d = ImageDraw.Draw(img)
    for y in range(height):
        t = y / max(1, height - 1)
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (width, y)], fill=c + (255,))
    return img


def gradient_rounded(base, b, radius, top, bottom):
    x0, y0, x1, y1 = box(b)
    w, h = x1 - x0, y1 - y0
    grad = vertical_gradient(top, bottom, w, h)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), sc(radius), fill=255)
    grad.putalpha(mask)
    base.alpha_composite(grad, (x0, y0))


def rounded(d, b, radius, fill, outline=None, width=0):
    d.rounded_rectangle(box(b), sc(radius), fill=fill, outline=outline, width=sc(width))


def text_center(base, xy, text, fnt, fill, tracking=0):
    """Draw text centred on xy, with optional letter spacing (1024-space px)."""
    if tracking == 0:
        layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.text((sc(xy[0]), sc(xy[1])), text, font=fnt, fill=fill, anchor="mm")
        base.alpha_composite(layer)
        return

    widths = []
    for ch in text:
        bb = fnt.getbbox(ch)
        widths.append(fnt.getlength(ch))
    total = sum(widths) + sc(tracking) * (len(text) - 1)
    x = sc(xy[0]) - total / 2
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for ch, w in zip(text, widths):
        d.text((x, sc(xy[1])), ch, font=fnt, fill=fill, anchor="lm")
        x += w + sc(tracking)
    base.alpha_composite(layer)


def draw_card():
    """A cream magnetic card, drawn at 2x and rotated."""
    cw, ch = sc(104), sc(168)
    pad = sc(24)
    img = Image.new("RGBA", (cw + 2 * pad, ch + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0 = pad, pad
    x1, y1 = pad + cw, pad + ch
    d.rounded_rectangle((x0, y0, x1, y1), sc(10), fill=(247, 241, 227, 255))
    d.rounded_rectangle((x0, y0, x1, y1), sc(10), outline=(188, 177, 156, 255), width=sc(1.5))
    # two magnetic stripes
    d.rounded_rectangle((x0 + sc(9), y0 + sc(22), x1 - sc(9), y0 + sc(40)), sc(3),
                        fill=(62, 55, 44, 255))
    d.rounded_rectangle((x0 + sc(9), y0 + sc(50), x1 - sc(9), y0 + sc(60)), sc(2),
                        fill=(94, 82, 63, 255))
    # printed label lines and a red corner
    d.rounded_rectangle((x0 + sc(14), y0 + sc(92), x1 - sc(14), y0 + sc(97)), sc(2),
                        fill=(120, 110, 90, 180))
    d.rounded_rectangle((x0 + sc(14), y0 + sc(106), x0 + sc(64), y0 + sc(111)), sc(2),
                        fill=(120, 110, 90, 180))
    d.polygon([(x1 - sc(30), y0), (x1, y0), (x1, y0 + sc(30))], fill=RED + (255,))
    return img.rotate(-11, resample=Image.BICUBIC, expand=False)


def build_master():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    # --- app tile -----------------------------------------------------------
    tile = (92, 88, 932, 928)
    drop_shadow(img, tile, 196, blur=18, dy=10, color=(0, 0, 0, 90))
    gradient_rounded(img, tile, 196, (72, 67, 58), (25, 23, 20))

    # warm spotlight behind the machine
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((sc(250), sc(170), sc(830), sc(700)), fill=(140, 106, 64, 78))
    glow = glow.filter(ImageFilter.GaussianBlur(sc(90)))
    img.alpha_composite(glow)

    # --- paper tape (behind the machine) -----------------------------------
    tape_w, tape_h = 112, 330
    tw, th = tape_w + 56, tape_h + 56
    tape_local = Image.new("RGBA", (sc(tw), sc(th)), (0, 0, 0, 0))
    tmask = Image.new("L", (sc(tw), sc(th)), 0)
    ImageDraw.Draw(tmask).rounded_rectangle(
        (sc(28), sc(22), sc(28 + tape_w), sc(22 + tape_h)), sc(8), fill=255)
    paper = vertical_gradient((252, 249, 240), (232, 225, 209), sc(tw), sc(th))
    paper.putalpha(tmask)
    tape_local.alpha_composite(paper)
    ld = ImageDraw.Draw(tape_local)
    for y in range(50, tape_h + 20, 20):
        ld.line((sc(28), sc(y), sc(28 + tape_w), sc(y)),
                fill=(80, 70, 55, 20), width=sc(1))
    tfont = font(COURIER_BOLD, 50)
    ImageDraw.Draw(tape_local).text(
        (sc(28 + tape_w / 2), sc(122)), "101", font=tfont,
        fill=(43, 40, 34, 255), anchor="mm")
    tape_local = tape_local.rotate(-4, resample=Image.BICUBIC, expand=False)

    # soft shadow for the tape
    tsh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    tsh.paste((0, 0, 0, 70), (sc(334), sc(248)), tape_local.getchannel("A"))
    tsh = tsh.filter(ImageFilter.GaussianBlur(sc(8)))
    img.alpha_composite(tsh)
    img.alpha_composite(tape_local, (sc(326), sc(228)))

    # --- printer deck -------------------------------------------------------
    deck = (232, 398, 792, 574)
    drop_shadow(img, deck, 28, blur=12, dy=8, color=(0, 0, 0, 90))
    gradient_rounded(img, deck, 28, DECK_TOP, DECK_BOTTOM)

    # paper slot lip
    rounded(ImageDraw.Draw(img), (292, 400, 524, 434), 12, (198, 186, 163, 255))
    rounded(ImageDraw.Draw(img), (300, 408, 516, 428), 9, (30, 28, 24, 255))
    # deck switch + indicator
    rounded(ImageDraw.Draw(img), (690, 420, 762, 440), 7, (48, 44, 37, 255))
    rounded(ImageDraw.Draw(img), (698, 425, 754, 435), 4, (26, 25, 22, 255))
    ind = Image.new("RGBA", img.size, (0, 0, 0, 0))
    idr = ImageDraw.Draw(ind)
    idr.ellipse((sc(770), sc(418), sc(786), sc(434)), fill=(230, 82, 52, 255))
    ind = ind.filter(ImageFilter.GaussianBlur(sc(1.2)))
    img.alpha_composite(ind)

    # --- machine body -------------------------------------------------------
    body = (200, 536, 824, 800)
    drop_shadow(img, body, 34, blur=20, dy=14, color=(0, 0, 0, 120))
    gradient_rounded(img, body, 34, CREAM_TOP, CREAM_BOTTOM)
    # thin highlight along the top lip of the front panel
    lip = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lip).line((sc(232), sc(541), sc(792), sc(541)),
                             fill=(255, 255, 255, 120), width=sc(2))
    img.alpha_composite(lip)

    # --- keyboard -----------------------------------------------------------
    rounded(ImageDraw.Draw(img), (242, 590, 706, 742), 18, (37, 34, 29, 255))
    rounded(ImageDraw.Draw(img), (248, 596, 700, 736), 14, (28, 26, 22, 255))

    key_w, key_h = 42, 32
    gap_x = (700 - 248 - 2 * 18 - 8 * key_w) / 7
    for row in range(3):
        y = 610 + row * 42
        for col in range(8):
            x = 248 + 18 + col * (key_w + gap_x)
            is_red = row == 2 and col == 7
            fill = RED + (255,) if is_red else (241, 233, 216, 255)
            rounded(ImageDraw.Draw(img), (x, y, x + key_w, y + key_h), 8, fill)
            if not is_red:
                ImageDraw.Draw(img).line(
                    (sc(x + 5), sc(y + 4), sc(x + key_w - 5), sc(y + 4)),
                    fill=(255, 255, 255, 90), width=sc(1.5))

    # --- magnetic card in the slot -----------------------------------------
    card = draw_card()
    img.alpha_composite(card, (sc(700), sc(470)))

    # --- card slot on the right --------------------------------------------
    rounded(ImageDraw.Draw(img), (716, 604, 792, 742), 12, (40, 37, 31, 255))
    rounded(ImageDraw.Draw(img), (724, 614, 784, 732), 8, (24, 23, 20, 255))
    rounded(ImageDraw.Draw(img), (728, 620, 780, 630), 4, (12, 12, 11, 255))

    # --- feet ---------------------------------------------------------------
    for fx in (252, 696):
        rounded(ImageDraw.Draw(img), (fx, 788, fx + 76, 806), 7, (32, 30, 25, 255))

    # --- brand --------------------------------------------------------------
    bfont = font(FUTURA, 25, index=0)
    text_center(img, (512, 770), "programma 101", bfont, (72, 66, 55, 255), tracking=2.6)

    # --- tile rim -----------------------------------------------------------
    rim = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(box(tile), sc(196),
                                          outline=(255, 255, 255, 26), width=sc(1.6))
    img.alpha_composite(rim)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    master = build_master()
    master.save(PREVIEW)
    if os.path.isdir(ICONSET):
        shutil.rmtree(ICONSET)
    os.makedirs(ICONSET)

    sizes = [
        ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
    ]
    for name, px in sizes:
        master.resize((px, px), Image.LANCZOS).save(os.path.join(ICONSET, name))

    subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", ICNS], check=True)
    shutil.rmtree(ICONSET)
    print("wrote", ICNS, os.path.getsize(ICNS), "bytes")
    print("wrote", PREVIEW)


if __name__ == "__main__":
    main()
