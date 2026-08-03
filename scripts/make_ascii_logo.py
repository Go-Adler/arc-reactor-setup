#!/usr/bin/env python3
"""
Rasterise the arc reactor into a coloured character grid for fastfetch.

Hand-drawing never stays symmetric, and one-char-per-ring sampling aliases the
thin rings away. So: render a proper bitmap at 2x vertical resolution and emit
half-block glyphs, using foreground for the upper pixel and background for the
lower one. A half-cell is then almost exactly square, so circles come out round.

Output: ~/.config/fastfetch/arc-reactor.txt  (fastfetch logo.type = file-raw)
"""
import math
import os

# ------------------------------------------------------------------ palette ---
RED   = (0xe6, 0x24, 0x29)
GOLD  = (0xf0, 0xa0, 0x20)
CYAN  = (0x55, 0xd9, 0xf0)
WHITE = (0xea, 0xf8, 0xff)
DIM   = (0x8a, 0x3a, 0x34)

COLS = 46                 # character columns
ROWS = 23                 # character rows  -> 46x46 pixel bitmap
PW, PH = COLS, ROWS * 2

CX, CY = (PW - 1) / 2.0, (PH - 1) / 2.0
RMAX = PW / 2.0
ASPECT = 1.025            # half-cell is ~1.025x taller than wide


def polar(px, py):
    dx = px - CX
    dy = (py - CY) * ASPECT
    return math.hypot(dx, dy) / RMAX, math.degrees(math.atan2(dy, dx)) % 360


def tri_depth(px, py, circumradius):
    """
    Signed 'insideness' for an up-pointing equilateral triangle.
    Returns max over edges of dot(p, n_k) / inradius; <=1 means inside.
    Edge outward normals sit at 90, 210, 330 degrees; inradius = R/2.
    """
    dx = px - CX
    dy = (py - CY) * ASPECT
    R = circumradius * RMAX
    inr = R / 2.0
    worst = -1e9
    for k in range(3):
        a = math.radians(90 + k * 120)
        worst = max(worst, (dx * math.cos(a) + dy * math.sin(a)) / inr)
    return worst


def near_spoke(a, seg, half_width):
    """
    True within half_width degrees of a multiple of seg. Centring the gaps on
    sector boundaries (rather than starting them there) is what makes the coil
    band mirror-symmetric about both axes.
    """
    m = a % seg
    return min(m, seg - m) < half_width


def pixel(px, py):
    """Colour of one bitmap pixel, or None."""
    r, _a = polar(px, py)
    a = _a

    # core, hottest at the centre
    if r < 0.135:
        return WHITE
    if r < 0.195:
        return CYAN

    # triangle outline, sitting between the core and the inner ring
    d = tri_depth(px, py, 0.44)
    if 0.87 <= d <= 1.0:
        return CYAN

    # inner energy ring
    if 0.50 <= r < 0.60:
        return CYAN

    # coil band: ten electromagnet sectors, gaps centred on the boundaries
    if 0.66 <= r < 0.84:
        return None if near_spoke(a, 36.0, 5.2) else RED

    # gold rim
    if 0.88 <= r < 0.96:
        return GOLD

    return None


def main():
    bmp = [[pixel(x, y) for x in range(PW)] for y in range(PH)]

    lines = []
    for cy in range(ROWS):
        parts, cur_fg, cur_bg = [], None, None
        for cx in range(COLS):
            top, bot = bmp[cy * 2][cx], bmp[cy * 2 + 1][cx]

            if top is None and bot is None:
                ch, fg, bg = " ", None, None
            elif top is not None and bot is None:
                ch, fg, bg = "▀", top, None
            elif top is None and bot is not None:
                ch, fg, bg = "▄", bot, None
            elif top == bot:
                ch, fg, bg = "█", top, None
            else:
                ch, fg, bg = "▀", top, bot

            if fg != cur_fg:
                parts.append("\033[39m" if fg is None
                             else "\033[38;2;{};{};{}m".format(*fg))
                cur_fg = fg
            if bg != cur_bg:
                parts.append("\033[49m" if bg is None
                             else "\033[48;2;{};{};{}m".format(*bg))
                cur_bg = bg
            parts.append(ch)

        parts.append("\033[0m")
        line = "".join(parts)
        lines.append("" if not line.replace("\033[0m", "").strip() else line)

    while lines and lines[0] == "":
        lines.pop(0)
    while lines and lines[-1] == "":
        lines.pop()

    d = os.path.expanduser("~/.config/fastfetch")
    os.makedirs(d, exist_ok=True)
    p = f"{d}/arc-reactor.txt"
    with open(p, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {p}  ({len(lines)} rows, {COLS} cols)\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
