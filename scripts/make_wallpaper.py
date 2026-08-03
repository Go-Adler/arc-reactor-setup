#!/usr/bin/env python3
"""
Arc Reactor wallpaper generator — resolution independent.

Renders a supersampled arc-reactor / HUD wallpaper with additive glow, then
downscales to the requested resolution. Everything is drawn from the theme
palette so the wallpaper, shell theme and terminal share exactly the same
colours.

  ./make_wallpaper.py                             # auto-detect display
  ./make_wallpaper.py -w 2560 -H 1440
  ./make_wallpaper.py -w 3440 -H 1440 --geo 0.42  # smaller reactor on ultrawide
  ./make_wallpaper.py --out ~/Pictures

Outputs into --out (default ~/.arc-reactor/wallpapers):
  arc-reactor-<W>x<H>.png
  arc-reactor-lock-<W>x<H>.png      dimmed + softened, for the lock screen

Requires: numpy, pillow.
"""
import argparse
import math
import os
import subprocess
import sys

try:
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError as e:                                    # pragma: no cover
    sys.exit(f"missing dependency: {e}\n"
             "  pip3 install --user numpy pillow\n"
             "  or: sudo apt install python3-numpy python3-pil")

# ----------------------------------------------------------------- palette ---
BASE  = (0x0d, 0x0b, 0x0b)   # near-black, faintly warm
RED   = (0xe6, 0x24, 0x29)   # armour red
GOLD  = (0xf0, 0xa0, 0x20)   # armour gold
CYAN  = (0x55, 0xd9, 0xf0)   # reactor energy
WHITE = (0xea, 0xf8, 0xff)   # core white-hot

# Where the HUD fonts might live; falls back to PIL's builtin if absent.
FONT_DIRS = [
    os.path.expanduser("~/.local/share/fonts/ArcReactor"),
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "assets", "fonts"),
]

# Keep the supersampled buffer under this many pixels so we do not exhaust RAM
# on a high-resolution display. 1080p gets 3x, 1440p 3x, 4K 2x.
PIXEL_BUDGET = 40_000_000


def detect_resolution():
    """Best-effort primary display size; falls back to 1920x1080."""
    try:
        out = subprocess.run(["xrandr"], capture_output=True, text=True,
                             timeout=5).stdout
        for line in out.splitlines():
            if "*" in line:
                tok = line.split()[0]
                if "x" in tok:
                    w, h = tok.split("x")[:2]
                    return int(w), int(h)
    except Exception:
        pass
    return 1920, 1080


def load_font(name, size, unit):
    for d in FONT_DIRS:
        p = os.path.join(d, name)
        if os.path.isfile(p):
            try:
                return ImageFont.truetype(p, max(1, int(size * unit)))
            except Exception:
                pass
    return ImageFont.load_default()


def render(W, H, SS, GEO):
    """Return a PIL image of the wallpaper at W x H."""
    PW, PH = W * SS, H * SS
    CX, CY = PW // 2, int(PH * 0.44)
    U = H * SS / 1000.0          # screen unit: 1.0 == 0.1% of height
    R = U * GEO                  # reactor geometry unit

    canvas = np.zeros((PH, PW, 3), np.float32)

    def layer(draw_fn, color, blur=0.0, gain=1.0):
        m = Image.new("L", (PW, PH), 0)
        draw_fn(ImageDraw.Draw(m))
        if blur:
            m = m.filter(ImageFilter.GaussianBlur(blur * R))
        a = np.asarray(m, np.float32) * (gain / 255.0)
        for i in range(3):
            canvas[:, :, i] += a * color[i]

    def ring(r, width, span=(0, 360)):
        def f(d):
            bb = [CX - r * R, CY - r * R, CX + r * R, CY + r * R]
            d.arc(bb, span[0], span[1], fill=255, width=max(1, int(width * R)))
        return f

    def disc(r):
        return lambda d: d.ellipse(
            [CX - r * R, CY - r * R, CX + r * R, CY + r * R], fill=255)

    # --------------------------------------------------- 1. base gradient ---
    # Broadcast instead of mgrid: one H x W array rather than two.
    ys = np.arange(PH, dtype=np.float32)[:, None]
    xs = np.arange(PW, dtype=np.float32)[None, :]
    dist = np.sqrt((xs - CX) ** 2 + (ys - CY) ** 2) / (620 * U)
    del xs, ys

    for i in range(3):
        canvas[:, :, i] = BASE[i]
    lift = np.clip(1.0 - dist, 0, 1) ** 2.2
    canvas[:, :, 0] += lift * 26
    canvas[:, :, 1] += lift * 16
    canvas[:, :, 2] += lift * 14
    del lift

    # ------------------------------------- 2. distant technical circles ----
    for r, w, g in ((880, 1.1, 0.10), (760, 0.9, 0.07), (1180, 1.1, 0.05)):
        layer(ring(r, w), GOLD, blur=0.6, gain=g)

    def far_ticks(d):
        for a in range(0, 360, 2):
            t = math.radians(a)
            long_tick = (a % 30 == 0)
            r0, r1 = 690, 690 + (26 if long_tick else 11)
            d.line([CX + math.cos(t) * r0 * R, CY + math.sin(t) * r0 * R,
                    CX + math.cos(t) * r1 * R, CY + math.sin(t) * r1 * R],
                   fill=255, width=max(1, int(1.2 * R)))
    layer(far_ticks, GOLD, blur=0.5, gain=0.16)

    # ------------------------------------------------ 3. outer HUD frame ---
    layer(ring(520, 2.4), GOLD, blur=0.5, gain=0.55)
    layer(ring(520, 2.4), GOLD, blur=9.0, gain=0.30)
    layer(ring(498, 1.0), RED,  blur=0.6, gain=0.35)

    for span, col, g in (((-96, -12), CYAN, 0.55), ((14, 74), RED, 0.45),
                         ((104, 168), GOLD, 0.40), ((196, 248), CYAN, 0.35)):
        layer(ring(556, 3.4, span), col, blur=0.6,  gain=g)
        layer(ring(556, 3.4, span), col, blur=11.0, gain=g * 0.5)

    # ---------------------------------------------- 4. coil segment band ---
    SEG, GAP = 10, 5.0
    step = 360.0 / SEG
    for k in range(SEG):
        a0 = k * step + GAP / 2
        a1 = (k + 1) * step - GAP / 2
        layer(ring(432, 78, (a0, a1)), RED,  blur=0.8,  gain=0.26)
        layer(ring(432, 78, (a0, a1)), RED,  blur=14.0, gain=0.18)
        layer(ring(398, 5,  (a0, a1)), GOLD, blur=0.5,  gain=0.60)
        layer(ring(466, 5,  (a0, a1)), GOLD, blur=0.5,  gain=0.48)

        def windings(d, a0=a0, a1=a1):
            n = 7
            for j in range(n):
                a = math.radians(a0 + (a1 - a0) * (j + 0.5) / n)
                d.line([CX + math.cos(a) * 400 * R, CY + math.sin(a) * 400 * R,
                        CX + math.cos(a) * 464 * R, CY + math.sin(a) * 464 * R],
                       fill=255, width=max(1, int(1.6 * R)))
        layer(windings, GOLD, blur=0.6, gain=0.22)

    # ---------------------------------------------- 5. inner energy ring ---
    layer(ring(352, 3.0),  CYAN,  blur=0.5,  gain=0.95)
    layer(ring(352, 3.0),  CYAN,  blur=16.0, gain=0.65)
    layer(ring(330, 14.0), CYAN,  blur=3.0,  gain=0.30)
    layer(ring(306, 1.6),  WHITE, blur=0.5,  gain=0.45)

    # -------------------------------------------------------- 6. triangle ---
    def triangle(d, r=236, rot=-90):
        pts = [(CX + math.cos(math.radians(rot + i * 120)) * r * R,
                CY + math.sin(math.radians(rot + i * 120)) * r * R)
               for i in range(3)]
        d.polygon(pts, outline=255, width=max(1, int(4.0 * R)))
    layer(triangle, CYAN, blur=0.6,  gain=1.00)
    layer(triangle, CYAN, blur=18.0, gain=0.75)
    layer(lambda d: triangle(d, r=210), WHITE, blur=1.2, gain=0.22)

    # ------------------------------------------------------------ 7. core ---
    layer(disc(150), CYAN,  blur=40.0, gain=0.55)
    layer(disc(104), CYAN,  blur=16.0, gain=0.85)
    layer(disc(76),  WHITE, blur=7.0,  gain=1.00)
    layer(disc(44),  WHITE, blur=2.0,  gain=1.15)

    # -------------------------------------------------------- 8. HUD text ---
    mono = load_font("JetBrainsMonoNerdFont-Regular.ttf", 15, U)
    orb  = load_font("Orbitron-VF.ttf", 19, U)

    layer(lambda d: d.text((CX, CY + 620 * R), "ARC  REACTOR",
                           font=orb, fill=255, anchor="mm"),
          GOLD, blur=0.4, gain=0.42)
    layer(lambda d: d.text((CX, CY + 656 * R),
                           "MARK  VII   ·   PALLADIUM-FREE   ·   3.2 GJ/s",
                           font=mono, fill=255, anchor="mm"),
          CYAN, blur=0.4, gain=0.24)

    def corner_tl(d):
        x, y = 110 * U, 100 * U
        for i, s in enumerate(["SYS  ONLINE", "PWR  100%", "TEMP  NOMINAL"]):
            d.text((x, y + i * 26 * U), s, font=mono, fill=255)

    def corner_br(d):
        x, y = PW - 110 * U, PH - 168 * U
        for i, s in enumerate(["OUTPUT   STABLE", "FIELD    CONTAINED",
                               "DIAG     PASS"]):
            d.text((x, y + i * 26 * U), s, font=mono, fill=255, anchor="ra")

    layer(corner_tl, GOLD, blur=0.4, gain=0.20)
    layer(corner_br, GOLD, blur=0.4, gain=0.20)

    def brackets(d):
        m, L, w = 74 * U, 46 * U, max(1, int(2.0 * U))
        for (px, py, sx, sy) in ((m, m, 1, 1), (PW - m, m, -1, 1),
                                 (m, PH - m, 1, -1), (PW - m, PH - m, -1, -1)):
            d.line([px, py, px + sx * L, py], fill=255, width=w)
            d.line([px, py, px, py + sy * L], fill=255, width=w)
    layer(brackets, GOLD, blur=0.4, gain=0.30)

    # ----------------------------------------------------- 9. atmosphere ---
    vig = np.clip(dist / 2.05, 0, 1) ** 1.7
    canvas *= (1.0 - 0.78 * vig)[:, :, None]
    del dist, vig

    # film grain kills banding across the large dark areas
    rng = np.random.default_rng(7)
    canvas += rng.normal(0.0, 1.5, canvas.shape).astype(np.float32)

    frame = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGB")
    del canvas
    return frame.resize((W, H), Image.LANCZOS) if SS != 1 else frame


def main():
    dw, dh = detect_resolution()
    ap = argparse.ArgumentParser(description="Arc Reactor wallpaper generator")
    ap.add_argument("-w", "--width",  type=int, default=dw)
    ap.add_argument("-H", "--height", type=int, default=dh)
    ap.add_argument("--ss",  type=int, default=0,
                    help="supersample factor (0 = auto, from a pixel budget)")
    ap.add_argument("--geo", type=float, default=0.50,
                    help="reactor size relative to screen height "
                         "(default 0.50; lower it on ultrawide)")
    ap.add_argument("--out",
                    default=os.path.expanduser("~/.arc-reactor/wallpapers"))
    a = ap.parse_args()

    W, H = a.width, a.height
    SS = a.ss or max(1, min(3, int(math.sqrt(PIXEL_BUDGET / (W * H)))))

    os.makedirs(a.out, exist_ok=True)
    print(f"rendering {W}x{H} at {SS}x supersample "
          f"({W*SS}x{H*SS} = {W*SS*H*SS/1e6:.1f}M px), geo={a.geo}")

    hd = render(W, H, SS, a.geo)
    p1 = os.path.join(a.out, f"arc-reactor-{W}x{H}.png")
    hd.save(p1, optimize=True)
    print("wrote", p1)

    # lock screen: softer and darker so the password entry stays legible
    lock = hd.filter(ImageFilter.GaussianBlur(max(3, H // 154)))
    lock = Image.fromarray(
        (np.asarray(lock, np.float32) * 0.55).astype(np.uint8), "RGB")
    p2 = os.path.join(a.out, f"arc-reactor-lock-{W}x{H}.png")
    lock.save(p2, optimize=True)
    print("wrote", p2)


if __name__ == "__main__":
    main()
