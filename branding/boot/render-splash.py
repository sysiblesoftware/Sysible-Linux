#!/usr/bin/env python3
"""Render the Sysible Linux boot splash screens.

Produces two assets from one design so the boot experience is consistent:
  * A high-resolution GRUB background (UEFI, incl. arm64) — crisp on real panels.
  * A safe 640x480 isolinux background (BIOS/amd64) — the widely-supported mode.

Design: dark #0d1117 field, a faint hexagon-mesh texture and a soft blue-green
glow behind the hexagon-prompt logo, the SYSIBLE LINUX wordmark with letter
spacing, and a gradient accent underline (green->blue, matching the logo).
The artwork is confined to the TOP band; the boot menu renders in the clear
lower band. No tagline.
"""
import io
import math
import cairosvg
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = "live-build/config/includes.chroot/usr/share/pixmaps/sysible-logo-dark.svg"
BG = (13, 17, 23)
FG = (233, 240, 247)
GREEN = (99, 200, 105)
BLUE = (85, 128, 238)


def _lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _hex_mesh(W, H, r, alpha):
    """Faint pointy-top hexagon outline mesh, brand texture."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    dx = r * math.sqrt(3)
    dy = r * 1.5
    col = (120, 150, 210, alpha)
    row = 0
    y = -r
    while y < H + r:
        offset = (dx / 2) if (row % 2) else 0
        x = -dx
        while x < W + dx:
            cx, cy = x + offset, y
            pts = [(cx + r * math.sin(math.radians(a)),
                    cy - r * math.cos(math.radians(a))) for a in range(0, 360, 60)]
            d.line(pts + [pts[0]], fill=col, width=1)
            x += dx
        y += dy
        row += 1
    return layer


def _glow(W, H, cx, cy, radius, color, peak):
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    steps = 48
    for i in range(steps, 0, -1):
        rr = radius * i / steps
        a = round(peak * (1 - i / steps) ** 2)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (a,))
    return g.filter(ImageFilter.GaussianBlur(radius / 12))


def _wordmark(draw, text, font, cx, y, fill, tracking):
    widths = [draw.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = cx - total / 2
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=font, fill=fill)
        x += w + tracking


def render(W, H, out):
    s = H / 480.0                      # scale factor vs the 480px reference
    logo_h = int(150 * s)
    canvas = Image.new("RGBA", (W, H), BG + (255,))

    # centre of the artwork band (top ~40% of the screen)
    band_cy = int(H * 0.30)

    canvas.alpha_composite(_hex_mesh(W, H, int(26 * s), 16))
    canvas.alpha_composite(_glow(W, H, W // 2, band_cy, int(230 * s), BLUE, 60))
    canvas.alpha_composite(_glow(W, H, W // 2, band_cy, int(150 * s), GREEN, 42))

    png = cairosvg.svg2png(url=HERE, output_height=logo_h)
    logo = Image.open(io.BytesIO(png)).convert("RGBA")
    ly = band_cy - logo.height // 2 - int(24 * s)
    canvas.alpha_composite(logo, ((W - logo.width) // 2, ly))

    draw = ImageDraw.Draw(canvas)
    fsize = int(42 * s)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", fsize)
    wy = ly + logo.height + int(20 * s)
    _wordmark(draw, "SYSIBLE LINUX", font, W / 2, wy, FG, tracking=int(6 * s))

    # gradient accent underline (green -> blue), matching the logo stroke
    uw = int(300 * s)
    uh = max(2, int(3 * s))
    ux = (W - uw) // 2
    uy = wy + fsize + int(14 * s)
    bar = Image.new("RGBA", (uw, uh), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bar)
    for i in range(uw):
        bd.line([(i, 0), (i, uh)], fill=_lerp(GREEN, BLUE, i / uw) + (255,))
    canvas.alpha_composite(bar, (ux, uy))

    canvas.convert("RGB").save(out)
    print("wrote %s (%dx%d)" % (out, W, H))


if __name__ == "__main__":
    # GRUB / UEFI (incl. arm64): high-res, scaled by firmware to the panel.
    render(1920, 1080, "live-build/config/branding/splash.png")
    # isolinux / BIOS: the safe, universally supported VESA mode.
    render(640, 480, "live-build/config/bootloaders/isolinux/splash.png")
