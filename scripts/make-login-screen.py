#!/usr/bin/env python3
"""Build Group 2 OS login wallpaper + logo to match the signed design mockup.

Leaves the centre clear for the real GDM password field and Sign In button.
Date/time is drawn live by the GDM extension (not baked into this image).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "branding"
OUT_LOGIN = BRAND / "login-background.png"
OUT_LOGO = BRAND / "group2-os-logo.png"
SCENE = BRAND / "login-scene.png"
REF = Path(
    r"C:\Users\USER\.cursor\projects\c-Users-USER-GROUP-2-OS\assets"
    r"\c__Users_USER_AppData_Roaming_Cursor_User_workspaceStorage_"
    r"5ce25d479836d2f4da5f899886445f92_images_image-6087a987-a70b-4f7e-b2cd-919555cdcf1f.png"
)


def font(size: int, bold: bool = False):
    candidates = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/calibrib.ttf" if bold else "C:/Windows/Fonts/calibri.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def fit_cover(im: Image.Image, tw: int, th: int) -> Image.Image:
    scale = max(tw / im.width, th / im.height)
    nw, nh = int(im.width * scale), int(im.height * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return im.crop((left, top, left + tw, top + th))


def draw_group_icon(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int = 54):
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 230), width=3)
    # three simple people silhouettes
    for dx, sc in ((-22, 0.9), (0, 1.0), (22, 0.9)):
        hx = cx + dx
        hy = cy - int(14 * sc)
        hr = int(9 * sc)
        draw.ellipse((hx - hr, hy - hr, hx + hr, hy + hr), fill=(255, 255, 255, 230))
        body_top = hy + hr - 2
        draw.rounded_rectangle(
            (hx - int(12 * sc), body_top, hx + int(12 * sc), cy + int(28 * sc)),
            radius=8,
            fill=(255, 255, 255, 230),
        )


def draw_logo_mark(size: int = 128) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pad = 6
    d.ellipse((pad, pad, size - pad, size - pad), outline=(30, 167, 255, 255), width=5)
    d.ellipse((pad + 8, pad + 8, size - pad - 8, size - pad - 8), outline=(90, 120, 255, 180), width=3)
    f = font(int(size * 0.55), bold=True)
    text = "G"
    bbox = d.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((size - tw) / 2 - 2, (size - th) / 2 - 4), text, font=f, fill=(120, 200, 255, 255))
    return im


def main():
    tw, th = 1920, 1080
    # Prefer photographic lake scene. If missing, strip chrome from the signed mockup.
    if SCENE.is_file():
        base = fit_cover(Image.open(SCENE).convert("RGB"), tw, th)
    elif REF.is_file():
        base = fit_cover(Image.open(REF).convert("RGB"), tw, th)
    else:
        base = Image.new("RGB", (tw, th), (7, 20, 34))

    # Cover any baked mock UI / duplicate logos so only our chrome + real GDM controls show.
    scrub = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    sd = ImageDraw.Draw(scrub)
    # Top-left baked logo area
    sd.rectangle((0, 0, 520, 160), fill=(7, 20, 34, 120))
    # Centre password / Sign In mock controls
    sd.rounded_rectangle(
        (tw // 2 - 380, int(th * 0.38), tw // 2 + 380, int(th * 0.78)),
        radius=28,
        fill=(8, 24, 48, 165),
    )
    # Bottom baked slogan strip (we redraw)
    sd.rectangle((0, th - 120, tw, th), fill=(7, 20, 34, 100))
    base = Image.alpha_composite(base.convert("RGBA"), scrub).convert("RGB")

    # Gentle centre vignette for dialog readability
    overlay = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rectangle((0, 0, tw, int(th * 0.22)), fill=(5, 14, 28, 70))
    od.rectangle((0, int(th * 0.72), tw, th), fill=(5, 14, 28, 110))
    # Soft panel behind welcome text (above password zone)
    panel_top = int(th * 0.14)
    panel_bot = int(th * 0.42)
    od.rounded_rectangle(
        (tw // 2 - 320, panel_top, tw // 2 + 320, panel_bot),
        radius=28,
        fill=(8, 24, 48, 55),
    )
    base = Image.alpha_composite(base.convert("RGBA"), overlay)

    draw = ImageDraw.Draw(base)
    logo = draw_logo_mark(56)
    base.paste(logo, (48, 40), logo)
    f_brand = font(26, bold=True)
    draw.text((118, 50), "GROUP 2", font=f_brand, fill=(255, 255, 255, 245))
    bw = draw.textbbox((118, 50), "GROUP 2", font=f_brand)
    draw.text((bw[2] + 10, 50), "OS", font=f_brand, fill=(90, 200, 255, 255))

    cx = tw // 2
    icon_y = int(th * 0.20)
    draw_group_icon(draw, cx, icon_y, r=52)

    f_small = font(22)
    f_title = font(54, bold=True)
    f_sub = font(20)
    f_foot = font(18)

    y = icon_y + 70
    welcome = "Welcome to"
    wb = draw.textbbox((0, 0), welcome, font=f_small)
    draw.text((cx - (wb[2] - wb[0]) // 2, y), welcome, font=f_small, fill=(230, 240, 255, 230))
    y += 36
    g2 = "GROUP 2 "
    os_ = "OS"
    g2b = draw.textbbox((0, 0), g2, font=f_title)
    osb = draw.textbbox((0, 0), os_, font=f_title)
    total = (g2b[2] - g2b[0]) + (osb[2] - osb[0])
    x0 = cx - total // 2
    draw.text((x0, y), g2, font=f_title, fill=(255, 255, 255, 255))
    draw.text((x0 + (g2b[2] - g2b[0]), y), os_, font=f_title, fill=(80, 190, 255, 255))
    y += 62
    linux = "Linux"
    lb = draw.textbbox((0, 0), linux, font=f_sub)
    draw.text((cx - (lb[2] - lb[0]) // 2, y), linux, font=f_sub, fill=(180, 210, 235, 220))

    # Hint space: real GDM password + Sign In appear roughly here
    # Bottom slogan; live clock sits just above via GDM extension
    slogan = "Group 2  ·  Learn  ·  Build  ·  Create  ·  Together"
    sb = draw.textbbox((0, 0), slogan, font=f_foot)
    draw.text(
        (cx - (sb[2] - sb[0]) // 2, th - 78),
        slogan,
        font=f_foot,
        fill=(210, 230, 250, 230),
    )
    hint = "Date & time follow your time zone (Africa/Kigali)"
    hb = draw.textbbox((0, 0), hint, font=font(14))
    draw.text(
        (cx - (hb[2] - hb[0]) // 2, th - 48),
        hint,
        font=font(14),
        fill=(140, 175, 210, 180),
    )

    rgb = base.convert("RGB")
    rgb.save(OUT_LOGIN, "PNG", optimize=True)
    draw_logo_mark(256).save(OUT_LOGO, "PNG")
    print("Wrote", OUT_LOGIN)
    print("Wrote", OUT_LOGO)


if __name__ == "__main__":
    main()
