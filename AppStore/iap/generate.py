#!/usr/bin/env python3
"""In-app purchase artwork for Just Nurikabe.

    python3 AppStore/iap/generate.py

Writes two files next to this script:

  nurikabe-full.png                1024x1024 promotional image
  review-screenshot-2048x2732.png  2048x2732 IAP review screenshot

Both draw the baked 7x7 board (Engine/BakedPuzzles.swift), solved, in the
app's chart palette (Design/Theme.swift, light): so the image is a true board
from the game, not decoration. SF Pro Expanded for display text and SF
Rounded for numerals, as in the app.

RGB with no alpha: App Store artwork with transparency is rejected under
ITMS-90717. The review screenshot must be exactly 2048x2732 or it is refused
with "the dimensions of one or more screenshots are wrong".
"""

import os
from PIL import Image, ImageDraw, ImageFont

GROUND = (0xEF, 0xEA, 0xE0)
LAND = (0xFB, 0xF8, 0xF1)
SEA = (0x23, 0x3A, 0x5E)
NUMERAL = (0x1B, 0x2C, 0x49)
TEXT = (0x1C, 0x24, 0x33)
OCHRE = (0xC9, 0x8A, 0x1B)

SFNS = "/System/Library/Fonts/SFNS.ttf"
ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"

# BakedPuzzles.seven: '#' sea, '.' land, a digit a clue on land.
BOARD = [
    ".#2.#2.",
    "2######",
    "##2.#1#",
    "#3##1##",
    "#..##.#",
    "####.3#",
    ".2#1###",
]
N = len(BOARD)

# ≤55 characters: the IAP localization's description field.
IAP_DESCRIPTION = "Advanced lessons, 10×10 boards and hints that explain"


def font(path, size, weight, width=None):
    f = ImageFont.truetype(path, size=int(size))
    values = []
    for a in f.get_variation_axes():
        if a["name"] == b"Weight":
            values.append(weight)
        elif a["name"] == b"Width" and width is not None:
            values.append(width)
        else:
            values.append(a["default"])
    f.set_variation_by_axes(values)
    return f


def centered(draw, cx, cy, text, f, fill):
    box = draw.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.text((cx - w / 2 - box[0], cy - h / 2 - box[1]), text, font=f, fill=fill)


def draw_board(draw, ox, oy, cell):
    """Land cells as cards on the sea, with a hairline of sea between them,
    like BoardView."""
    gap = max(2, cell // 40)
    draw.rectangle([ox, oy, ox + N * cell, oy + N * cell], fill=SEA)
    numerals = font(ROUNDED, cell * 0.62, 600)
    for r, row in enumerate(BOARD):
        for c, ch in enumerate(row):
            if ch == "#":
                continue
            x0, y0 = ox + c * cell + gap, oy + r * cell + gap
            draw.rectangle([x0, y0, x0 + cell - 2 * gap, y0 + cell - 2 * gap], fill=LAND)
            if ch != ".":
                centered(draw, x0 + cell / 2 - gap, y0 + cell / 2 - gap, ch, numerals, NUMERAL)
            else:
                d = cell * 0.09
                cx, cy = x0 + cell / 2 - gap, y0 + cell / 2 - gap
                draw.ellipse([cx - d, cy - d, cx + d, cy + d], fill=NUMERAL)
    draw.rectangle([ox, oy, ox + N * cell, oy + N * cell], outline=SEA, width=gap * 2)


def make_promo(out_dir):
    SIZE, SCALE = 1024, 4
    r = SIZE * SCALE
    image = Image.new("RGB", (r, r), GROUND)
    draw = ImageDraw.Draw(image)
    cell = 112 * SCALE
    ox = (r - N * cell) // 2
    oy = (r - N * cell) // 2
    draw_board(draw, ox, oy, cell)
    image = image.resize((SIZE, SIZE), Image.LANCZOS)
    out = os.path.join(out_dir, "nurikabe-full.png")
    image.save(out)
    return out


def make_screenshot(out_dir):
    W, H, SCALE = 2048, 2732, 2
    rw, rh = W * SCALE, H * SCALE
    image = Image.new("RGB", (rw, rh), GROUND)
    draw = ImageDraw.Draw(image)

    # The sea band, as on Home.
    draw.rectangle([0, 0, rw, 700 * SCALE], fill=SEA)
    centered(draw, rw / 2, 300 * SCALE, "just", font(SFNS, 70 * SCALE, 500), LAND)
    centered(draw, rw / 2, 440 * SCALE, "NURIKABE", font(SFNS, 150 * SCALE, 700, width=150), LAND)

    cell = 180 * SCALE
    ox = (rw - N * cell) // 2
    oy = 860 * SCALE
    draw_board(draw, ox, oy, cell)

    y = oy + N * cell + 180 * SCALE
    centered(draw, rw / 2, y, "The Full Chart", font(SFNS, 84 * SCALE, 700, width=125), TEXT)
    centered(draw, rw / 2, y + 130 * SCALE, "One purchase", font(SFNS, 52 * SCALE, 500), OCHRE)
    centered(draw, rw / 2, y + 240 * SCALE, IAP_DESCRIPTION, font(SFNS, 50 * SCALE, 400), TEXT)

    image = image.resize((W, H), Image.LANCZOS)
    out = os.path.join(out_dir, "review-screenshot-2048x2732.png")
    image.save(out)
    return out


def main():
    assert len(IAP_DESCRIPTION) <= 55, len(IAP_DESCRIPTION)
    out_dir = os.path.dirname(os.path.abspath(__file__))
    for out in (make_promo(out_dir), make_screenshot(out_dir)):
        check = Image.open(out)
        print(f"wrote {out}  {check.size} {check.mode}  {os.path.getsize(out)} bytes")


if __name__ == "__main__":
    main()
