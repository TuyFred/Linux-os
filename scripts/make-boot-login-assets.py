#!/usr/bin/env python3
"""Build Group 2 OS boot splash and login background from the mockups."""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(r"/mnt/c/Users/USER/GROUP 2 OS")
BRANDING = ROOT / "branding"
ASSETS = Path(
    r"/mnt/c/Users/USER/.cursor/projects/c-Users-USER-GROUP-2-OS/assets"
)
PLYMOUTH = ROOT / "installer/overlay/usr/share/plymouth/themes/group2-os"
PIXMAPS = ROOT / "installer/overlay/usr/share/pixmaps"

BOOT_SRC = ASSETS / "c__Users_USER_AppData_Roaming_Cursor_User_workspaceStorage_5ce25d479836d2f4da5f899886445f92_images_image-f3e487fd-1f92-43d8-af74-13c7e88799e7.png"
LOGIN_SRC = ASSETS / "c__Users_USER_AppData_Roaming_Cursor_User_workspaceStorage_5ce25d479836d2f4da5f899886445f92_images_Screenshot_2026-09-15_235053-0f197582-65ea-4aef-889e-762181adb30c.png"
TARGET = (1920, 1080)


def fit_contain(im: Image.Image, size=TARGET, fill=(5, 11, 20)) -> Image.Image:
    tw, th = size
    im = im.convert("RGB")
    sw, sh = im.size
    scale = min(tw / sw, th / sh)
    nw, nh = max(1, int(sw * scale)), max(1, int(sh * scale))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, fill)
    canvas.paste(im, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def crop_frac(im: Image.Image, left=0.0, top=0.0, right=0.0, bottom=0.0) -> Image.Image:
    w, h = im.size
    return im.crop((int(w * left), int(h * top), int(w * (1 - right)), int(h * (1 - bottom))))


def gradient_bar(size: tuple[int, int], filled: bool) -> Image.Image:
    w, h = size
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 2, fill=(18, 36, 64, 220))
    if filled:
        for x in range(w):
            t = x / max(1, w - 1)
            r = int(30 + (180 - 30) * t)
            g = int(167 + (80 - 167) * t)
            b = int(255 + (255 - 255) * t)
            d.line([(x, 1), (x, h - 2)], fill=(r, g, b, 255))
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 2, fill=255)
        color = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        cd = ImageDraw.Draw(color)
        for x in range(w):
            t = x / max(1, w - 1)
            cd.line([(x, 0), (x, h)], fill=(int(30 + 150 * t), int(170 - 70 * t), 255, 255))
        im = Image.composite(color, Image.new("RGBA", (w, h), (18, 36, 64, 220)), mask)
    return im


def main() -> None:
    if not BOOT_SRC.is_file():
        raise SystemExit(f"missing boot mockup: {BOOT_SRC}")
    if not LOGIN_SRC.is_file():
        raise SystemExit(f"missing login mockup: {LOGIN_SRC}")

    BRANDING.mkdir(parents=True, exist_ok=True)
    PLYMOUTH.mkdir(parents=True, exist_ok=True)
    PIXMAPS.mkdir(parents=True, exist_ok=True)

    boot = fit_contain(Image.open(BOOT_SRC), fill=(5, 10, 20))
    boot.save(BRANDING / "boot-background.png", "PNG", optimize=True)
    boot.save(PLYMOUTH / "background.png", "PNG", optimize=True)
    print("boot", boot.size)

    login = Image.open(LOGIN_SRC)
    login = crop_frac(login, bottom=0.11)
    login = fit_contain(login, fill=(7, 20, 34))
    login.save(BRANDING / "login-background.png", "PNG", optimize=True)
    print("login", login.size)

    empty = gradient_bar((840, 18), filled=False)
    full = gradient_bar((840, 18), filled=True)
    empty.save(PLYMOUTH / "progress-empty.png", "PNG")
    full.save(PLYMOUTH / "progress-full.png", "PNG")

    # People/welcome mark for GDM, cropped from the login mockup.
    w, h = login.size
    logo = login.crop((int(w * 0.38), int(h * 0.06), int(w * 0.62), int(h * 0.42)))
    logo.save(PIXMAPS / "group2-login-logo.png", "PNG")
    print("login logo", logo.size)

    raw = BRANDING / "raw-mockups"
    raw.mkdir(parents=True, exist_ok=True)
    shutil.copy2(BOOT_SRC, raw / "boot-mockup.png")
    shutil.copy2(LOGIN_SRC, raw / "login-mockup.png")
    print("Group 2 OS boot and login assets ready.")


if __name__ == "__main__":
    main()
