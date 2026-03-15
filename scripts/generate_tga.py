#!/usr/bin/env python3
"""Generates 16x16 TGA files with alpha channel for WoW addon icons.
TGA format: uncompressed RGBA, top-to-bottom, 32-bit."""

import struct
import os

def write_tga(filename, pixels):
    """Write a 16x16 RGBA TGA file. pixels is a list of 256 (r,g,b,a) tuples."""
    header = struct.pack('<BBBHHBHHHHBB',
        0,    # ID length
        0,    # Color map type
        2,    # Image type (uncompressed true-color)
        0, 0, # Color map spec (unused)
        0,    # Color map entry size
        0, 0, # X origin
        16, 16, # Width, Height
        32,   # Bits per pixel
        0x28, # Image descriptor: top-left origin (0x20) + 8 alpha bits (0x08)
    )
    data = b''
    for r, g, b, a in pixels:
        data += struct.pack('BBBB', b, g, r, a)  # TGA stores BGRA
    with open(filename, 'wb') as f:
        f.write(header + data)

def make_arrow_up():
    """Upward-pointing triangle, centered in 16x16."""
    pixels = []
    for y in range(16):
        for x in range(16):
            row = y - 3
            if row < 0 or row > 9:
                pixels.append((0, 0, 0, 0))
            else:
                spread = row * 12 / 9 / 2
                center = 7.5
                if center - spread <= x <= center + spread:
                    pixels.append((255, 255, 255, 255))
                else:
                    pixels.append((0, 0, 0, 0))
    return pixels

def make_arrow_down():
    """Downward-pointing triangle, centered in 16x16."""
    pixels = []
    for y in range(16):
        for x in range(16):
            row = (15 - y) - 3
            if row < 0 or row > 9:
                pixels.append((0, 0, 0, 0))
            else:
                spread = row * 12 / 9 / 2
                center = 7.5
                if center - spread <= x <= center + spread:
                    pixels.append((255, 255, 255, 255))
                else:
                    pixels.append((0, 0, 0, 0))
    return pixels

def make_lock():
    """Simple padlock silhouette, centered in 16x16."""
    pixels = []
    W = (255, 255, 255, 255)
    T = (0, 0, 0, 0)
    lock_rows = [
        "                ",
        "     ######     ",
        "    ##    ##    ",
        "    ##    ##    ",
        "    ##    ##    ",
        "   ##      ##   ",
        "  ############  ",
        "  ############  ",
        "  ############  ",
        "  ##### #####   ",
        "  #####  ####   ",
        "  #####  ####   ",
        "  ############  ",
        "  ############  ",
        "  ############  ",
        "                ",
    ]
    for row in lock_rows:
        for ch in row:
            if ch == '#':
                pixels.append(W)
            else:
                pixels.append(T)
    return pixels

def write_tga_sized(filename, width, height, pixels):
    """Write an arbitrary-sized RGBA TGA file."""
    header = struct.pack('<BBBHHBHHHHBB',
        0, 0, 2, 0, 0, 0, 0, 0,
        width, height, 32, 0x28,
    )
    data = b''
    for r, g, b, a in pixels:
        data += struct.pack('BBBB', b, g, r, a)
    with open(filename, 'wb') as f:
        f.write(header + data)

def make_gradient_h():
    """64x4 white-to-transparent horizontal gradient."""
    pixels = []
    for y in range(4):
        for x in range(64):
            alpha = int(255 * (1.0 - x / 63.0))
            pixels.append((255, 255, 255, alpha))
    return 64, 4, pixels

def _aa_pixel(dist, edge=0.0, spread=1.0):
    """Anti-aliased alpha from signed distance. Negative = inside."""
    t = max(0.0, min(1.0, (edge - dist) / spread + 0.5))
    return int(t * 255)

def _dist_circle(x, y, cx, cy, r):
    """Signed distance to circle edge (negative inside)."""
    import math
    return math.sqrt((x - cx)**2 + (y - cy)**2) - r

def _dist_rect(x, y, rx, ry, rw, rh, corner=0):
    """Signed distance to rounded rect (negative inside)."""
    # Clamp to rect, measure distance
    dx = max(rx + corner - x, 0, x - (rx + rw - corner))
    dy = max(ry + corner - y, 0, y - (ry + rh - corner))
    import math
    if corner > 0:
        d = math.sqrt(dx*dx + dy*dy) - corner
    else:
        d = max(dx, dy)
    # Check if inside
    if rx <= x <= rx + rw and ry <= y <= ry + rh:
        inner = min(x - rx, rx + rw - x, y - ry, ry + rh - y)
        return -inner if d <= 0 else d
    return max(dx, dy)

def make_icon_roster():
    """32x32 list/roster icon — three horizontal lines with dots."""
    S = 32
    pixels = []
    # Three rows: dot + line at y=8, y=16, y=24
    lines = [
        (6, 8, 4, 24),   # dot_x, y, dot_r_tenths, line_end_x
        (6, 16, 4, 24),
        (6, 16+8, 4, 24),
    ]
    for py in range(S):
        for px in range(S):
            alpha = 0
            for dot_x, ly, dot_r, line_end in lines:
                # Dot (small circle)
                d = _dist_circle(px + 0.5, py + 0.5, dot_x, ly, 1.8)
                a1 = _aa_pixel(d, spread=1.2)
                # Line (horizontal bar)
                d2 = _dist_rect(px + 0.5, py + 0.5, 11, ly - 1.5, 15, 3, corner=1.0)
                a2 = _aa_pixel(d2, spread=1.0)
                alpha = max(alpha, a1, a2)
            pixels.append((255, 255, 255, min(alpha, 255)))
    return S, S, pixels

def make_icon_groups():
    """32x32 2x2 grid icon — four rounded squares."""
    S = 32
    pixels = []
    rects = [
        (3, 3, 11, 11),    # top-left
        (18, 3, 11, 11),   # top-right
        (3, 18, 11, 11),   # bottom-left
        (18, 18, 11, 11),  # bottom-right
    ]
    for py in range(S):
        for px in range(S):
            alpha = 0
            for rx, ry, rw, rh in rects:
                d = _dist_rect(px + 0.5, py + 0.5, rx, ry, rw, rh, corner=2.0)
                a = _aa_pixel(d, spread=1.0)
                alpha = max(alpha, a)
            pixels.append((255, 255, 255, min(alpha, 255)))
    return S, S, pixels

def make_icon_settings():
    """32x32 gear/cog icon — outer ring with teeth + inner circle cutout."""
    import math
    S = 32
    cx, cy = 15.5, 15.5
    outer_r = 12.0
    inner_r = 5.0
    ring_r = 8.5
    teeth = 8
    tooth_width = 0.35  # radians half-width
    pixels = []
    for py in range(S):
        for px in range(S):
            x, y = px + 0.5, py + 0.5
            dist_outer = _dist_circle(x, y, cx, cy, outer_r)
            dist_inner = _dist_circle(x, y, cx, cy, inner_r)
            dist_ring = _dist_circle(x, y, cx, cy, ring_r)

            # Base: ring between inner_r and ring_r
            ring_alpha = _aa_pixel(max(-dist_ring, dist_inner), spread=1.0)

            # Teeth: bumps on the outer edge
            angle = math.atan2(y - cy, x - cx)
            tooth_dist = float('inf')
            for i in range(teeth):
                ta = i * 2 * math.pi / teeth
                ang_diff = abs(((angle - ta + math.pi) % (2 * math.pi)) - math.pi)
                if ang_diff < tooth_width * 1.5:
                    # Tooth shape: rectangle from ring_r to outer_r
                    radial_dist = math.sqrt((x - cx)**2 + (y - cy)**2)
                    if ring_r - 1 <= radial_dist <= outer_r + 1:
                        td = max(ang_diff - tooth_width, 0) * radial_dist
                        td = max(td, ring_r - radial_dist, radial_dist - outer_r)
                        tooth_dist = min(tooth_dist, td)

            tooth_alpha = _aa_pixel(tooth_dist, spread=1.0) if tooth_dist < 10 else 0

            alpha = max(ring_alpha, tooth_alpha)
            # Cut out inner circle
            inner_cut = _aa_pixel(-dist_inner, spread=1.0)
            alpha = max(0, alpha - inner_cut)

            pixels.append((255, 255, 255, min(alpha, 255)))
    return S, S, pixels

def make_icon_about():
    """32x32 circled 'i' icon — circle outline with 'i' inside."""
    import math
    S = 32
    cx, cy = 15.5, 15.5
    pixels = []
    for py in range(S):
        for px in range(S):
            x, y = px + 0.5, py + 0.5
            # Circle outline (ring)
            dist_outer = _dist_circle(x, y, cx, cy, 13.0)
            dist_inner = _dist_circle(x, y, cx, cy, 11.0)
            ring_a = _aa_pixel(max(-dist_outer, dist_inner), spread=1.0)

            # Dot of 'i' (small circle at top)
            dot_a = _aa_pixel(_dist_circle(x, y, cx, 9.5, 1.8), spread=1.0)

            # Stem of 'i' (vertical bar)
            stem_a = _aa_pixel(_dist_rect(x, y, cx - 1.5, 13, 3, 9, corner=1.0), spread=1.0)

            alpha = max(ring_a, dot_a, stem_a)
            pixels.append((255, 255, 255, min(alpha, 255)))
    return S, S, pixels

def make_logo_ks():
    """32x32 'KS' text with cyan glow."""
    import math
    W, H = 32, 32
    text_pixels = [[0]*W for _ in range(H)]

    # K shape (columns 4-14, rows 8-23)
    k_rows = [
        "##    ##",
        "##   ## ",
        "##  ##  ",
        "## ##   ",
        "####    ",
        "## ##   ",
        "##  ##  ",
        "##   ## ",
        "##    ##",
    ]
    for ry, row in enumerate(k_rows):
        for rx, ch in enumerate(row):
            if ch == '#':
                text_pixels[10 + ry][5 + rx] = 255

    # S shape (columns 16-25, rows 8-23)
    s_rows = [
        " #####  ",
        "##   ## ",
        "##      ",
        " ####   ",
        "   ###  ",
        "     ## ",
        "##   ## ",
        " #####  ",
    ]
    for ry, row in enumerate(s_rows):
        for rx, ch in enumerate(row):
            if ch == '#':
                text_pixels[10 + ry][17 + rx] = 255

    # Generate glow (gaussian blur of text)
    glow_radius = 3
    pixels = []
    for y in range(H):
        for x in range(W):
            if text_pixels[y][x] > 0:
                pixels.append((255, 255, 255, 255))
            else:
                glow = 0.0
                for dy in range(-glow_radius, glow_radius + 1):
                    for dx in range(-glow_radius, glow_radius + 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < H and 0 <= nx < W and text_pixels[ny][nx] > 0:
                            dist = math.sqrt(dx*dx + dy*dy)
                            if dist <= glow_radius:
                                glow += (1.0 - dist / glow_radius) * 0.6
                glow = min(glow, 1.0)
                if glow > 0.05:
                    a = int(glow * 200)
                    pixels.append((0, 204, 255, a))
                else:
                    pixels.append((0, 0, 0, 0))
    return W, H, pixels

def make_logo_full():
    """128x16 'KeySorter' text with cyan glow."""
    import math
    W, H = 128, 16
    text_pixels = [[0]*W for _ in range(H)]

    # Simple block letters for "KeySorter" starting at row 3
    letters = {
        'K': ["##  ##", "## ## ", "####  ", "## ## ", "##  ##"],
        'e': ["      ", " #### ", "##  ##", "######", "##    ", " #### "],
        'y': ["##  ##", "##  ##", " #### ", "  ##  ", " ##   "],
        'S': [" #### ", "##    ", " ###  ", "   ## ", "####  "],
        'o': [" #### ", "##  ##", "##  ##", "##  ##", " #### "],
        'r': ["      ", "## ## ", "###  #", "##    ", "##    "],
        't': [" ##   ", "#####", " ##  ", " ##  ", "  ## "],
    }

    # Positions for each character (x offset)
    chars = [
        ('K', 6), ('e', 14), ('y', 22),
        ('S', 34), ('o', 42), ('r', 50), ('t', 58),
        ('e', 64), ('r', 72),
    ]

    for ch, xoff in chars:
        if ch in letters:
            for ry, row in enumerate(letters[ch]):
                for rx, c in enumerate(row):
                    if c == '#':
                        px, py = xoff + rx, 5 + ry
                        if 0 <= px < W and 0 <= py < H:
                            text_pixels[py][px] = 255

    # Glow
    glow_radius = 2
    pixels = []
    for y in range(H):
        for x in range(W):
            if text_pixels[y][x] > 0:
                pixels.append((255, 255, 255, 255))
            else:
                glow = 0.0
                for dy in range(-glow_radius, glow_radius + 1):
                    for dx in range(-glow_radius, glow_radius + 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < H and 0 <= nx < W and text_pixels[ny][nx] > 0:
                            dist = math.sqrt(dx*dx + dy*dy)
                            if dist <= glow_radius:
                                glow += (1.0 - dist / glow_radius) * 0.5
                glow = min(glow, 1.0)
                if glow > 0.05:
                    a = int(glow * 180)
                    pixels.append((0, 204, 255, a))
                else:
                    pixels.append((0, 0, 0, 0))
    return W, H, pixels

if __name__ == '__main__':
    media_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'Media')
    os.makedirs(media_dir, exist_ok=True)

    # Original assets
    write_tga(os.path.join(media_dir, 'ArrowUp.tga'), make_arrow_up())
    write_tga(os.path.join(media_dir, 'ArrowDown.tga'), make_arrow_down())
    write_tga(os.path.join(media_dir, 'Lock.tga'), make_lock())

    # Sidebar icons (32x32 anti-aliased)
    for name, fn in [('IconRoster', make_icon_roster), ('IconGroups', make_icon_groups),
                     ('IconSettings', make_icon_settings), ('IconAbout', make_icon_about)]:
        w, h, px = fn()
        write_tga_sized(os.path.join(media_dir, f'{name}.tga'), w, h, px)

    # Gradient
    w, h, px = make_gradient_h()
    write_tga_sized(os.path.join(media_dir, 'GradientH.tga'), w, h, px)

    # Logos
    w, h, px = make_logo_ks()
    write_tga_sized(os.path.join(media_dir, 'LogoKS.tga'), w, h, px)

    w, h, px = make_logo_full()
    write_tga_sized(os.path.join(media_dir, 'LogoFull.tga'), w, h, px)

    print(f"Generated 10 TGA files in {media_dir}/")
