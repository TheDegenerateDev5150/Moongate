#!/usr/bin/env python3
"""Render the Moongate icon assets from the approved shape: a red "moon gate"
ring + crescent on near-black.

Outputs:
  assets/icon/icon_full.png        1024 square, near-black bg (legacy launcher source)
  assets/icon/icon_foreground.png  1024, transparent, mark in the adaptive safe zone
  android/.../res/drawable/ic_stat_moongate.png
                                   96px white-on-transparent status-bar / notification icon

Then `dart run flutter_launcher_icons` turns the first two into every mipmap
density + the adaptive icon. Deps: Pillow. Re-run if the shape/colours change.
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(__file__)
ICON_DIR = os.path.join(HERE, "..", "assets", "icon")
DRAWABLE = os.path.join(HERE, "..", "android", "app", "src", "main", "res", "drawable")
os.makedirs(ICON_DIR, exist_ok=True)

RED = (255, 59, 48, 255)    # #FF3B30
BG = (14, 14, 16, 255)      # #0E0E10
WHITE = (255, 255, 255, 255)


def render(size, fg, bg, ring_rf, ring_wf, cres_rf):
    """Ring + crescent in colour `fg` on background `bg` (None = transparent)."""
    img = Image.new("RGBA", (size, size), bg if bg else (0, 0, 0, 0))
    c = size / 2
    ring_r, ring_w = size * ring_rf, max(1, round(size * ring_wf))
    cres_r = size * cres_rf
    dx, dy, carve_r = cres_r * 0.43, -cres_r * 0.20, cres_r * 0.84

    ImageDraw.Draw(img).ellipse(
        [round(c - ring_r), round(c - ring_r), round(c + ring_r), round(c + ring_r)],
        outline=fg, width=ring_w)

    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([round(c - cres_r), round(c - cres_r),
                round(c + cres_r), round(c + cres_r)], fill=255)
    md.ellipse([round(c + dx - carve_r), round(c + dy - carve_r),
                round(c + dx + carve_r), round(c + dy + carve_r)], fill=0)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.paste(Image.new("RGBA", (size, size), fg), (0, 0), mask)
    return Image.alpha_composite(img, layer)


render(1024, RED, BG, 0.32, 0.065, 0.15).save(os.path.join(ICON_DIR, "icon_full.png"))
render(1024, RED, None, 0.26, 0.052, 0.122).save(os.path.join(ICON_DIR, "icon_foreground.png"))
if os.path.isdir(DRAWABLE):
    render(96, WHITE, None, 0.40, 0.085, 0.19).save(
        os.path.join(DRAWABLE, "ic_stat_moongate.png"))
print("icons written")
