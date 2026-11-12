#!/usr/bin/env python3
"""Mac, Apple TV and Vision Pro icons for Just Nurikabe, from the iOS icon.

    swiftc -o /tmp/nurikabe-icon Tools/AppIcon/make_icon.swift && /tmp/nurikabe-icon
    python3 Tools/AppIcon/make_platform_icons.py

The iOS icon is a 5x5 chart: indigo sea, paper islands, rounded numerals.
That splits into two layers on its own: Back is the sea, Front is the islands
with their numbers (the sea keyed out of the iOS icon), so on Apple TV and
Vision Pro the islands float over the water as the icon tilts.

* Mac: the rounded tile is part of the artwork (824px on a 1024 canvas,
  radius 22.37%), written as mac-*.png into AppIcon.appiconset.
* Apple TV: 5:3 layered stacks plus Top Shelf images, never masked; the art
  stays inside 90% of the height because tvOS crops as the icon tilts.
* Vision Pro: cut into a circle; the chart's corners would fall outside it,
  so the front layer is drawn at 84%.

Requires Pillow.
"""
import json
import pathlib
import shutil

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
ASSETS = ROOT / "Nurikabe/Assets.xcassets"
SOURCE = ASSETS / "AppIcon.appiconset/AppIcon.png"
SEA = (0x23, 0x3A, 0x5E)
INFO = {"author": "xcode", "version": 1}
ORDER = ["Front", "Back"]


def front_layer():
    """The iOS icon with the sea keyed out: alpha grows with the distance from
    the sea colour, so the islands' antialiased edges stay soft."""
    icon = Image.open(SOURCE).convert("RGB")
    out = Image.new("RGBA", icon.size)
    px, po = icon.load(), out.load()
    for y in range(icon.height):
        for x in range(icon.width):
            r, g, b = px[x, y]
            d = max(abs(r - SEA[0]), abs(g - SEA[1]), abs(b - SEA[2]))
            a = min(255, d * 255 // 120)
            po[x, y] = (r, g, b, a)
    return out


FRONT = None


def layer(name, width, height, art):
    if name == "Back":
        return Image.new("RGB", (width, height), SEA)
    piece = FRONT.resize((art, art), Image.LANCZOS)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.paste(piece, ((width - art) // 2, (height - art) // 2), piece)
    return canvas


def write_json(path, obj):
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(obj, indent=2) + "\n")


def write_stack(root, scales, width, height, art, idiom, solid=False):
    ext = "solidimagestacklayer" if solid else "imagestacklayer"
    write_json(root, {"info": INFO, "layers": [{"filename": f"{n}.{ext}"} for n in ORDER]})
    for name in ORDER:
        folder = root / f"{name}.{ext}"
        write_json(folder, {"info": INFO})
        images = []
        (folder / "Content.imageset").mkdir(parents=True, exist_ok=True)
        for scale in scales:
            filename = f"{name.lower()}.png" if solid else f"{name.lower()}@{scale}.png"
            layer(name, width * scale, height * scale, art * scale).save(folder / "Content.imageset" / filename)
            images.append({"filename": filename, "idiom": idiom, "scale": "2x" if solid else f"{scale}x"})
        write_json(folder / "Content.imageset", {"images": images, "info": INFO})


def top_shelf(width, height):
    image = Image.new("RGBA", (width, height), SEA + (255,))
    art = int(height * 0.86)
    piece = FRONT.resize((art, art), Image.LANCZOS)
    image.alpha_composite(piece, (int(width * 0.36 - art / 2), (height - art) // 2))
    return image.convert("RGB")


def tv():
    root = ASSETS / "TVAppIcon.brandassets"
    shutil.rmtree(root, ignore_errors=True)
    write_json(root, {"info": INFO, "assets": [
        {"filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"},
        {"filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"},
        {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"},
        {"filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"},
    ]})
    write_stack(root / "App Icon - App Store.imagestack", [1], 1280, 768, int(768 * 0.9), "tv")
    write_stack(root / "App Icon.imagestack", [1, 2], 400, 240, int(240 * 0.9), "tv")
    for name, width, stem in (("Top Shelf Image", 1920, "top-shelf"), ("Top Shelf Image Wide", 2320, "top-shelf-wide")):
        folder = root / f"{name}.imageset"
        folder.mkdir(parents=True, exist_ok=True)
        images = []
        for scale in (1, 2):
            top_shelf(width * scale, 720 * scale).save(folder / f"{stem}@{scale}.png")
            images.append({"filename": f"{stem}@{scale}.png", "idiom": "tv", "scale": f"{scale}x"})
        write_json(folder, {"images": images, "info": INFO})
    print(f"wrote {root.name}")


def vision():
    root = ASSETS / "VisionAppIcon.solidimagestack"
    shutil.rmtree(root, ignore_errors=True)
    write_stack(root, [1], 1024, 1024, int(1024 * 0.84), "vision", solid=True)
    print(f"wrote {root.name}")


MAC_SLOTS = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]


def mac():
    flat = Image.open(SOURCE).convert("RGBA")
    folder = ASSETS / "AppIcon.appiconset"
    for px in sorted({s * k for s, k in MAC_SLOTS}):
        big = px * 4
        tile = round(big * 824 / 1024)
        mask = Image.new("L", (tile, tile), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile - 1, tile - 1], radius=tile * 0.2237, fill=255)
        canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        canvas.paste(flat.resize((tile, tile), Image.LANCZOS), ((big - tile) // 2,) * 2, mask)
        canvas.resize((px, px), Image.LANCZOS).save(folder / f"mac-{px}.png")
    contents = json.loads((folder / "Contents.json").read_text())
    contents["images"] = [i for i in contents["images"] if i.get("idiom") != "mac"] + [
        {"filename": f"mac-{s * k}.png", "idiom": "mac", "scale": f"{k}x", "size": f"{s}x{s}"} for s, k in MAC_SLOTS]
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print("wrote mac icons into AppIcon.appiconset")


if __name__ == "__main__":
    FRONT = front_layer()
    tv()
    vision()
    mac()
