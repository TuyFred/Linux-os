#!/usr/bin/env python3
"""Build real Plymouth pieces: logo + progress bars. No fake loading screenshot."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(r"/mnt/c/Users/USER/GROUP 2 OS")
BRANDING = ROOT / "branding"
PLYMOUTH = ROOT / "installer/overlay/usr/share/plymouth/themes/group2-os"
GRUB = ROOT / "installer/overlay/boot/grub"
ASSETS = Path(
    r"/mnt/c/Users/USER/.cursor/projects/c-Users-USER-GROUP-2-OS/assets"
)
BOOT_SRC = ASSETS / "c__Users_USER_AppData_Roaming_Cursor_User_workspaceStorage_5ce25d479836d2f4da5f899886445f92_images_image-f3e487fd-1f92-43d8-af74-13c7e88799e7.png"
PLYMOUTH.mkdir(parents=True, exist_ok=True)
GRUB.mkdir(parents=True, exist_ok=True)


def rounded_bar(size, fill, outline=None) -> Image.Image:
    w, h = size
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=max(1, h // 2), fill=fill, outline=outline)
    return im


def gradient_fill(size) -> Image.Image:
    w, h = size
    base = rounded_bar(size, (18, 36, 64, 255))
    color = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(color)
    for x in range(w):
        t = x / max(1, w - 1)
        cd.line([(x, 0), (x, h)], fill=(int(30 + 150 * t), int(170 - 40 * t), 255, 255))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=max(1, h // 2), fill=255)
    return Image.composite(color, base, mask)


def main() -> None:
    src = BOOT_SRC if BOOT_SRC.is_file() else BRANDING / "boot-background.png"
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    # Keep only the G mark, not the painted loading bar.
    logo = im.crop((int(w * 0.28), int(h * 0.14), int(w * 0.72), int(h * 0.52)))
    logo = logo.resize((420, 360), Image.Resampling.LANCZOS)
    logo.save(PLYMOUTH / "logo.png", "PNG")

    empty = rounded_bar((840, 18), (18, 36, 64, 230), outline=(40, 90, 150, 180))
    full = gradient_fill((840, 18))
    empty.save(PLYMOUTH / "progress-empty.png", "PNG")
    full.save(PLYMOUTH / "progress-full.png", "PNG")

    # Solid dark GRUB backdrop — not a fake loading screenshot.
    grub = Image.new("RGB", (1920, 1080), (5, 10, 20))
    mark = logo.convert("RGB").resize((220, 188), Image.Resampling.LANCZOS)
    grub.paste(mark, ((1920 - 220) // 2, 220))
    grub.save(BRANDING / "grub-background.png", "PNG")
    grub.save(GRUB / "group2-boot.png", "PNG")
    print("plymouth logo", (PLYMOUTH / "logo.png").stat().st_size)
    print("real Plymouth assets ready")


if __name__ == "__main__":
    main()
