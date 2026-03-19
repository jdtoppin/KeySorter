#!/usr/bin/env python3
"""Generate a high-resolution KeySorter logo PNG for CurseForge (400x400).
Requires: pip install Pillow"""

import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 400
BG = (18, 18, 18, 255)
CYAN = (0, 204, 255)
WHITE = (255, 255, 255)

# Font config — try bold fonts in order of preference
FONT_PATHS = [
    ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
    ("/System/Library/Fonts/Helvetica.ttc", 1),  # Bold index
    ("/System/Library/Fonts/Supplemental/Impact.ttf", 0),
]

def get_font(size):
    for path, idx in FONT_PATHS:
        try:
            return ImageFont.truetype(path, size, index=idx)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()

def draw_key(draw, cx, cy, scale):
    """Draw a key icon using vector-like shapes."""
    # Key head (ring)
    head_r = scale * 0.30
    hole_r = scale * 0.14
    head_cy = cy - scale * 0.12

    # Draw filled circle then cut out the hole
    draw.ellipse(
        [cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r],
        fill=WHITE
    )
    draw.ellipse(
        [cx - hole_r, head_cy - hole_r, cx + hole_r, head_cy + hole_r],
        fill=(0, 0, 0, 0)
    )

    # Shaft
    shaft_w = scale * 0.055
    shaft_top = head_cy + head_r * 0.65
    shaft_bottom = cy + scale * 0.44
    draw.rectangle(
        [cx - shaft_w, shaft_top, cx + shaft_w, shaft_bottom],
        fill=WHITE
    )

    # Teeth (two notches on the right)
    tooth_w = scale * 0.10
    tooth_h = scale * 0.035
    for i, ty in enumerate([shaft_bottom - scale * 0.14, shaft_bottom - scale * 0.06]):
        draw.rectangle(
            [cx, ty - tooth_h, cx + tooth_w, ty + tooth_h],
            fill=WHITE
        )

def generate_logo():
    # Create base image with transparent background for compositing
    img = Image.new("RGBA", (SIZE, SIZE), BG)

    # Create a separate layer for the key + text (for glow effect)
    content = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    content_draw = ImageDraw.Draw(content)

    # Draw key icon
    draw_key(content_draw, SIZE // 2, int(SIZE * 0.34), SIZE * 0.48)

    # Draw "KeySorter" text
    font = get_font(56)
    text = "KeySorter"
    bbox = content_draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = (SIZE - text_w) // 2
    text_y = int(SIZE * 0.76)
    content_draw.text((text_x, text_y), text, fill=WHITE, font=font)

    # Create glow layer: blur the content and tint cyan
    glow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # Extract alpha from content as the glow source
    content_alpha = content.split()[3]

    # Create cyan-colored version
    cyan_layer = Image.new("RGBA", (SIZE, SIZE), (*CYAN, 255))
    cyan_layer.putalpha(content_alpha)

    # Blur for glow effect (multiple passes for wider glow)
    glow = cyan_layer.filter(ImageFilter.GaussianBlur(radius=8))
    glow2 = cyan_layer.filter(ImageFilter.GaussianBlur(radius=16))

    # Composite: background → outer glow → inner glow → sharp content
    img = Image.alpha_composite(img, glow2)
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, content)

    # Subtle border
    border_draw = ImageDraw.Draw(img)
    border_color = (40, 40, 40, 255)
    border_draw.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=border_color, width=1)

    return img

if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "Media")
    out_path = os.path.join(out_dir, "logo_curseforge.png")

    img = generate_logo()
    img.save(out_path, "PNG")
    print(f"Generated {out_path} ({SIZE}x{SIZE})")
